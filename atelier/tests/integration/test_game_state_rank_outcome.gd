extends GdUnitTestSuite

const RANK_ID: StringName = &"rank_g"
const RECIPE_ID := &"recipe_test"
const FLOAT_TOLERANCE := 0.0001

var _confirmed_outcomes: Array = []
var _game_over_payloads: Array = []


func before_test() -> void:
	GameState.reset_for_test()
	_confirmed_outcomes = []
	_game_over_payloads = []
	GameState.rank_outcome_confirmed.connect(_on_rank_outcome_confirmed)
	GameState.game_over.connect(_on_game_over)
	_setup_rank(100.0, 30)


func after_test() -> void:
	# GameStateはAutoloadで購読側テストより寿命が長いため明示的に解除する
	if GameState.rank_outcome_confirmed.is_connected(_on_rank_outcome_confirmed):
		GameState.rank_outcome_confirmed.disconnect(_on_rank_outcome_confirmed)
	if GameState.game_over.is_connected(_on_game_over):
		GameState.game_over.disconnect(_on_game_over)


func _on_rank_outcome_confirmed(outcome: RankOutcome.Value) -> void:
	_confirmed_outcomes.append(outcome)


func _on_game_over(demotion_count: int) -> void:
	_game_over_payloads.append(demotion_count)


func _make_rank(quota_max: float, limit_turn: int) -> RankMaster:
	var rank := RankMaster.new()
	rank.id = String(RANK_ID)
	rank.display_name = "テストランク"
	rank.quota_max = quota_max
	rank.limit_turn = limit_turn
	rank.traits_unlocked = false
	return rank


func _setup_rank(quota_max: float, limit_turn: int) -> void:
	GameState._set_rank_masters_for_test({RANK_ID: _make_rank(quota_max, limit_turn)})
	GameState._set_current_rank_id_for_test(RANK_ID)


func _set_rank_state(quota: float, elapsed_turn: int) -> void:
	var state := RankState.new()
	state.quota = quota
	state.elapsed_turn = elapsed_turn
	GameState._set_rank_state_for_test(state)


func _inject_product(contribution: float, reward: float = 0.0) -> void:
	GameState._inject_pending_product_for_test(
		ProductInstance.new(RECIPE_ID, 3, [] as Array[StringName], contribution, reward)
	)


# 正常系（AC-009）: 納品時のノルマ消費


func test_納品した貢献度分だけランクノルマが減少する() -> void:
	_set_rank_state(100.0, 0)
	_inject_product(30.0)

	GameState.deliver_pending_products()

	assert_float(GameState._rank_state.quota).is_equal_approx(70.0, FLOAT_TOLERANCE)


func test_複数件の納品で貢献度が合算されノルマから減算される() -> void:
	_set_rank_state(100.0, 0)
	_inject_product(30.0)
	_inject_product(25.0)

	GameState.deliver_pending_products()

	assert_float(GameState._rank_state.quota).is_equal_approx(45.0, FLOAT_TOLERANCE)


func test_納品を複数回実行してもノルマ残量は累積して減少する() -> void:
	_set_rank_state(100.0, 0)
	_inject_product(30.0)
	GameState.deliver_pending_products()

	_inject_product(25.0)
	GameState.deliver_pending_products()

	assert_float(GameState._rank_state.quota).is_equal_approx(45.0, FLOAT_TOLERANCE)


func test_ノルマ残量を超える貢献度でも0未満にはならない() -> void:
	_set_rank_state(10.0, 0)
	_inject_product(999.0)

	GameState.deliver_pending_products()

	assert_float(GameState._rank_state.quota).is_equal(0.0)


func test_キューが空の納品ではノルマ残量が変化しない() -> void:
	_set_rank_state(50.0, 0)

	GameState.deliver_pending_products()

	assert_float(GameState._rank_state.quota).is_equal_approx(50.0, FLOAT_TOLERANCE)


# 異常系（AC-009, FR-408）: 暫定フィールドの削除


func test_accumulated_contributionフィールドが削除されている() -> void:
	assert_bool("_accumulated_contribution" in GameState).is_false()


func test_get_stateがaccumulated_contributionキーを含まない() -> void:
	assert_bool(GameState.get_state().has("accumulated_contribution")).is_false()


# 正常系（AC-010）: evaluate_rank_outcome


func test_ノルマ達成かつ制限ターン到達でPROMOTION_ELIGIBLEを返す() -> void:
	_set_rank_state(0.0, 30)

	assert_int(GameState.evaluate_rank_outcome()).is_equal(RankOutcome.Value.PROMOTION_ELIGIBLE)


func test_ノルマ未達成かつ制限ターン到達でDEMOTIONを返す() -> void:
	_set_rank_state(20.0, 30)

	assert_int(GameState.evaluate_rank_outcome()).is_equal(RankOutcome.Value.DEMOTION)


func test_制限ターン未到達ならノルマ達成済みでもCONTINUEを返す() -> void:
	_set_rank_state(0.0, 29)

	assert_int(GameState.evaluate_rank_outcome()).is_equal(RankOutcome.Value.CONTINUE)


func test_evaluate_rank_outcomeを複数回呼んでも状態が変化しない() -> void:
	_set_rank_state(20.0, 30)

	for _i in range(3):
		assert_int(GameState.evaluate_rank_outcome()).is_equal(RankOutcome.Value.DEMOTION)

	assert_float(GameState._rank_state.quota).is_equal_approx(20.0, FLOAT_TOLERANCE)
	assert_int(GameState._rank_state.elapsed_turn).is_equal(30)
	assert_int(GameState._demotion_count).is_equal(0)
	assert_int(_confirmed_outcomes.size()).is_equal(0)


# 正常系（AC-011）: commit_rank_outcome の DEMOTION 確定処理


func test_DEMOTION確定でdemotion_countが1増えrank_stateが再挑戦用に差し替わる() -> void:
	_set_rank_state(20.0, 30)

	var result := GameState.commit_rank_outcome()

	assert_bool(result.success).is_true()
	assert_int(result.value).is_equal(RankOutcome.Value.DEMOTION)
	assert_int(GameState._demotion_count).is_equal(1)
	assert_float(GameState._rank_state.quota).is_equal_approx(100.0, FLOAT_TOLERANCE)
	assert_int(GameState._rank_state.elapsed_turn).is_equal(0)


func test_CONTINUE確定では状態が一切変化しない() -> void:
	_set_rank_state(20.0, 10)

	var result := GameState.commit_rank_outcome()

	assert_int(result.value).is_equal(RankOutcome.Value.CONTINUE)
	assert_int(GameState._demotion_count).is_equal(0)
	assert_float(GameState._rank_state.quota).is_equal_approx(20.0, FLOAT_TOLERANCE)
	assert_int(GameState._rank_state.elapsed_turn).is_equal(10)


# 境界値（AC-011）: ゲームオーバー成立


func test_初期状態ではゲームオーバーではない() -> void:
	assert_bool(GameState.is_game_over()).is_false()


func test_降格回数が上限直前からDEMOTION確定でゲームオーバーになる() -> void:
	GameState._set_demotion_count_for_test(GameBalance.MAX_DEMOTION_COUNT - 1)
	_set_rank_state(20.0, 30)

	GameState.commit_rank_outcome()

	assert_int(GameState._demotion_count).is_equal(GameBalance.MAX_DEMOTION_COUNT)
	assert_bool(GameState.is_game_over()).is_true()


func test_降格回数が上限の1つ手前ならまだゲームオーバーにならない() -> void:
	GameState._set_demotion_count_for_test(GameBalance.MAX_DEMOTION_COUNT - 2)
	_set_rank_state(20.0, 30)

	GameState.commit_rank_outcome()

	assert_int(GameState._demotion_count).is_equal(GameBalance.MAX_DEMOTION_COUNT - 1)
	assert_bool(GameState.is_game_over()).is_false()


# 異常系（AC-011, FR-202）: 冪等性


func test_ゲームオーバー後にcommitを再度呼んでも状態が変化しない() -> void:
	GameState._set_demotion_count_for_test(GameBalance.MAX_DEMOTION_COUNT - 1)
	_set_rank_state(20.0, 30)
	GameState.commit_rank_outcome()

	_set_rank_state(20.0, 30)
	var result := GameState.commit_rank_outcome()

	assert_bool(result.success).is_true()
	assert_int(GameState._demotion_count).is_equal(GameBalance.MAX_DEMOTION_COUNT)
	assert_float(GameState._rank_state.quota).is_equal_approx(20.0, FLOAT_TOLERANCE)
	assert_int(GameState._rank_state.elapsed_turn).is_equal(30)


func test_ゲームオーバー後の再commitではgame_overシグナルが再発行されない() -> void:
	GameState._set_demotion_count_for_test(GameBalance.MAX_DEMOTION_COUNT - 1)
	_set_rank_state(20.0, 30)
	GameState.commit_rank_outcome()

	GameState.commit_rank_outcome()

	assert_int(_game_over_payloads.size()).is_equal(1)


# 正常系（AC-012）: シグナル発行


func test_commit時にrank_outcome_confirmedが確定結果を伴い1回発行される() -> void:
	_set_rank_state(20.0, 30)

	GameState.commit_rank_outcome()

	assert_int(_confirmed_outcomes.size()).is_equal(1)
	assert_int(_confirmed_outcomes[0]).is_equal(RankOutcome.Value.DEMOTION)


func test_monitor_signalsでrank_outcome_confirmedの発行を検証できる() -> void:
	# AutoloadのGameStateがテスト終了時に自動解放されないよう第2引数falseを明示する
	monitor_signals(GameState, false)
	_set_rank_state(0.0, 30)

	GameState.commit_rank_outcome()

	await (assert_signal(GameState).is_emitted(
		"rank_outcome_confirmed", [RankOutcome.Value.PROMOTION_ELIGIBLE]
	))


func test_ゲームオーバー成立の瞬間にgame_overシグナルが降格回数を伴い発行される() -> void:
	GameState._set_demotion_count_for_test(GameBalance.MAX_DEMOTION_COUNT - 1)
	_set_rank_state(20.0, 30)

	GameState.commit_rank_outcome()

	assert_int(_game_over_payloads.size()).is_equal(1)
	assert_int(_game_over_payloads[0]).is_equal(GameBalance.MAX_DEMOTION_COUNT)


func test_ゲームオーバー未成立のDEMOTIONではgame_overシグナルが発行されない() -> void:
	_set_rank_state(20.0, 30)

	GameState.commit_rank_outcome()

	assert_int(_game_over_payloads.size()).is_equal(0)


## FR-404: 次ランクへの遷移はpromotion-exam planの責務のため、本planでは状態を進めない
func test_PROMOTION_ELIGIBLE確定ではランク状態も降格回数も変化しない() -> void:
	_set_rank_state(0.0, 30)

	var result := GameState.commit_rank_outcome()

	assert_int(result.value).is_equal(RankOutcome.Value.PROMOTION_ELIGIBLE)
	assert_that(GameState._current_rank_id).is_equal(RANK_ID)
	assert_float(GameState._rank_state.quota).is_equal(0.0)
	assert_int(GameState._rank_state.elapsed_turn).is_equal(30)
	assert_int(GameState._demotion_count).is_equal(0)
	assert_int(_game_over_payloads.size()).is_equal(0)
