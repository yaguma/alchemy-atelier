extends GdUnitTestSuite

## GameStateのデバッグ支援API（debug_add_gold/debug_force_end_turn/debug_jump_to_next_rank）の
## 統合テスト。debug-playtest-support Plan タスク001。

const RANK_ID: StringName = &"rank_g"
const NEXT_RANK_ID: StringName = &"rank_f"
const LAST_RANK_ID: StringName = &"rank_s"
const RECIPE_ID: StringName = &"recipe_test"
const FLOAT_TOLERANCE := 0.0001


func before_test() -> void:
	GameState.reset_for_test()


func _make_rank(rank_id: StringName, quota_max: float, limit_turn: int) -> RankMaster:
	var rank := RankMaster.new()
	rank.id = String(rank_id)
	rank.display_name = "テストランク"
	rank.quota_max = quota_max
	rank.limit_turn = limit_turn
	rank.traits_unlocked = false
	rank.exam_turn_limit = 10
	return rank


func _make_product(recipe_id: StringName) -> ProductInstance:
	return ProductInstance.new(recipe_id, 3, [] as Array[StringName], 10.0, 5.0)


# 正常系


func test_debug_add_goldは所持ゴールドを固定量増加させる() -> void:
	GameState._set_gold_for_test(500)

	GameState.debug_add_gold()

	assert_int(GameState.get_state()["gold"]).is_equal(1500)


func test_debug_add_goldはgold_changedシグナルを発行する() -> void:
	monitor_signals(GameState, false)
	GameState._set_gold_for_test(0)

	GameState.debug_add_gold()

	await assert_signal(GameState).is_emitted(GameState.gold_changed, 0, 1000, 1000)


func test_debug_force_end_turnは納品待ちキューを決算して空にする() -> void:
	GameState._set_rank_masters_for_test({RANK_ID: _make_rank(RANK_ID, 100.0, 30)})
	GameState._set_current_rank_id_for_test(RANK_ID)
	GameState._inject_pending_product_for_test(_make_product(RECIPE_ID))

	GameState.debug_force_end_turn()

	assert_int(GameState.get_state()["pending_products"].size()).is_equal(0)


## TurnLimitResolver.resolve_rank_outcome()はturn_limit_reached=trueの場合のみPROMOTION_ELIGIBLEを
## 判定するため、elapsed_turnをlimit_turnと同値にしてノルマ達成済み＆制限ターン到達の状態を作る
func test_debug_force_end_turnはノルマ達成済みかつ制限ターン到達で昇格試験を開始する() -> void:
	GameState._set_rank_masters_for_test({RANK_ID: _make_rank(RANK_ID, 100.0, 30)})
	GameState._set_current_rank_id_for_test(RANK_ID)
	var rank_state := RankState.new()
	rank_state.quota = 0.0
	rank_state.elapsed_turn = 30
	GameState._set_rank_state_for_test(rank_state)

	var result: Result = GameState.debug_force_end_turn()

	assert_bool(result.success).is_true()
	assert_bool(GameState.get_state()["in_exam"]).is_true()


func test_debug_jump_to_next_rankは次ランクへ即座に進む() -> void:
	GameState._set_rank_masters_for_test(
		{RANK_ID: _make_rank(RANK_ID, 100.0, 30), NEXT_RANK_ID: _make_rank(NEXT_RANK_ID, 200.0, 40)}
	)
	GameState._set_current_rank_id_for_test(RANK_ID)
	var rank_state := RankState.new()
	rank_state.quota = 30.0
	rank_state.elapsed_turn = 5
	GameState._set_rank_state_for_test(rank_state)

	GameState.debug_jump_to_next_rank()

	var state := GameState.get_state()
	assert_that(state["current_rank_id"]).is_equal(NEXT_RANK_ID)
	assert_float(state["rank_state"].quota).is_equal_approx(200.0, FLOAT_TOLERANCE)


# 異常系・境界値


## 現在ランクがRANK_ORDER末尾（真の最終ランク）の場合は何もしない
func test_debug_jump_to_next_rankは末尾ランクでは現在ランクを変化させない() -> void:
	GameState._set_rank_masters_for_test({LAST_RANK_ID: _make_rank(LAST_RANK_ID, 100.0, 30)})
	GameState._set_current_rank_id_for_test(LAST_RANK_ID)
	assert_bool(RankProgression.is_true_final_rank(LAST_RANK_ID)).is_true()

	GameState.debug_jump_to_next_rank()

	assert_that(GameState.get_state()["current_rank_id"]).is_equal(LAST_RANK_ID)


## 次ランクのRankMasterが未登録の場合も現在ランクを変化させない（NFR-101）
func test_debug_jump_to_next_rankは次ランクマスター未登録では現在ランクを変化させない() -> void:
	GameState._set_rank_masters_for_test({RANK_ID: _make_rank(RANK_ID, 100.0, 30)})
	GameState._set_current_rank_id_for_test(RANK_ID)

	GameState.debug_jump_to_next_rank()

	assert_that(GameState.get_state()["current_rank_id"]).is_equal(RANK_ID)


## テスト専用APIガードと同型の確認。CIはデバッグビルドで実行されるため、この呼び出し自体は
## 成功する前提でGameStateTestSupport.guard()を再利用していることを間接的に確認する
## （test_game_state_workshop_fields.gd等の既存パターン踏襲）
func test_デバッグ支援APIはデバッグビルドで正常に動作する() -> void:
	assert_bool(OS.is_debug_build()).is_true()

	GameState._set_gold_for_test(0)
	GameState.debug_add_gold()

	assert_int(GameState.get_state()["gold"]).is_equal(1000)
