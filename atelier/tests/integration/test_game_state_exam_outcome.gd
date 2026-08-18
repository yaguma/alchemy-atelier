extends GdUnitTestSuite

const RANK_ID: StringName = &"rank_g"
const NEXT_RANK_ID: StringName = &"rank_f"
const LAST_RANK_ID: StringName = &"rank_s"
const FLOAT_TOLERANCE := 0.0001

var _confirmed_outcomes: Array = []
var _game_over_payloads: Array = []


func before_test() -> void:
	GameState.reset_for_test()
	_confirmed_outcomes = []
	_game_over_payloads = []
	GameState.exam_outcome_confirmed.connect(_on_exam_outcome_confirmed)
	GameState.game_over.connect(_on_game_over)
	_setup_rank(100.0, 30)


func after_test() -> void:
	# GameStateはAutoloadで購読側テストより寿命が長いため明示的に解除する
	if GameState.exam_outcome_confirmed.is_connected(_on_exam_outcome_confirmed):
		GameState.exam_outcome_confirmed.disconnect(_on_exam_outcome_confirmed)
	if GameState.game_over.is_connected(_on_game_over):
		GameState.game_over.disconnect(_on_game_over)


func _on_exam_outcome_confirmed(outcome: ExamOutcome.Value) -> void:
	_confirmed_outcomes.append(outcome)


func _on_game_over(demotion_count: int) -> void:
	_game_over_payloads.append(demotion_count)


func _make_rank(rank_id: StringName, quota_max: float, limit_turn: int) -> RankMaster:
	var rank := RankMaster.new()
	rank.id = String(rank_id)
	rank.display_name = "テストランク"
	rank.quota_max = quota_max
	rank.limit_turn = limit_turn
	rank.traits_unlocked = false
	return rank


func _setup_rank(quota_max: float, limit_turn: int) -> void:
	GameState._set_rank_masters_for_test({RANK_ID: _make_rank(RANK_ID, quota_max, limit_turn)})
	GameState._set_current_rank_id_for_test(RANK_ID)


## 現在ランク(RANK_ID)と次ランク(NEXT_RANK_ID)の両方をマスター登録し、現在ランクをRANK_IDにする
func _setup_rank_and_next_rank() -> void:
	var masters: Dictionary = {
		RANK_ID: _make_rank(RANK_ID, 100.0, 30),
		NEXT_RANK_ID: _make_rank(NEXT_RANK_ID, 200.0, 40),
	}
	GameState._set_rank_masters_for_test(masters)
	GameState._set_current_rank_id_for_test(RANK_ID)


func _set_rank_state(quota: float, elapsed_turn: int) -> void:
	var state := RankState.new()
	state.quota = quota
	state.elapsed_turn = elapsed_turn
	GameState._set_rank_state_for_test(state)


func _set_exam_state(
	quota: float, quota_max: float, elapsed_turn: int, turn_limit: int, in_exam: bool = true
) -> void:
	var state := ExamState.new()
	state.exam_quota = quota
	state.exam_quota_max = quota_max
	state.exam_elapsed_turn = elapsed_turn
	state.exam_turn_limit = turn_limit
	GameState._set_exam_state_for_test(state, in_exam)


# 正常系・異常系（FR-107）: evaluate_exam_outcome


func test_試験中でノルマ達成でSUCCESSを返す() -> void:
	_set_exam_state(0.0, 100.0, 10, 20)

	assert_int(GameState.evaluate_exam_outcome()).is_equal(ExamOutcome.Value.SUCCESS)


func test_試験中で制限ターン到達かつノルマ未達成でFAILUREを返す() -> void:
	_set_exam_state(10.0, 100.0, 20, 20)

	assert_int(GameState.evaluate_exam_outcome()).is_equal(ExamOutcome.Value.FAILURE)


func test_試験中でなければ常にCONTINUEを返す() -> void:
	_set_exam_state(0.0, 100.0, 20, 20, false)

	assert_int(GameState.evaluate_exam_outcome()).is_equal(ExamOutcome.Value.CONTINUE)


func test_evaluate_exam_outcomeを複数回呼んでも状態が変化しない() -> void:
	_set_rank_state(100.0, 0)
	_set_exam_state(10.0, 100.0, 20, 20)
	var gold_before := GameState._gold

	for _i in range(3):
		assert_int(GameState.evaluate_exam_outcome()).is_equal(ExamOutcome.Value.FAILURE)

	assert_bool(GameState._in_exam).is_true()
	assert_float(GameState._exam_state.exam_quota).is_equal_approx(10.0, FLOAT_TOLERANCE)
	assert_int(GameState._exam_state.exam_elapsed_turn).is_equal(20)
	assert_float(GameState._rank_state.quota).is_equal_approx(100.0, FLOAT_TOLERANCE)
	assert_int(GameState._gold).is_equal(gold_before)


# 正常系・異常系（FR-108, FR-109, NFR-101）: commit_exam_outcome の SUCCESS（次ランクあり）確定処理


func test_SUCCESS確定で次ランクに昇格しrank_stateが次ランクのquota_maxで初期化される() -> void:
	_setup_rank_and_next_rank()
	_set_exam_state(0.0, 50.0, 5, 20)

	var result := GameState.commit_exam_outcome()

	assert_bool(result.success).is_true()
	assert_int(result.value).is_equal(ExamOutcome.Value.SUCCESS)
	assert_that(GameState._current_rank_id).is_equal(NEXT_RANK_ID)
	assert_int(GameState._demotion_count).is_equal(0)
	assert_float(GameState._rank_state.quota).is_equal_approx(200.0, FLOAT_TOLERANCE)
	assert_bool(GameState._in_exam).is_false()


func test_SUCCESS確定で次ランクへの昇格時にrank_state_initializedがtrueになる() -> void:
	_setup_rank_and_next_rank()
	_set_exam_state(0.0, 50.0, 5, 20)

	GameState.commit_exam_outcome()

	assert_bool(GameState._rank_state_initialized).is_true()


func test_SUCCESS確定でexam_outcome_confirmedがSUCCESSを伴い発行される() -> void:
	_setup_rank_and_next_rank()
	_set_exam_state(0.0, 50.0, 5, 20)

	GameState.commit_exam_outcome()

	assert_int(_confirmed_outcomes.size()).is_equal(1)
	assert_int(_confirmed_outcomes[0]).is_equal(ExamOutcome.Value.SUCCESS)


func test_次ランクのマスターデータが未登録ならcurrent_rank_idとrank_stateが変更されない() -> void:
	# _rank_mastersにはRANK_IDのみ登録し、NEXT_RANK_IDは意図的に未登録のままにする
	GameState._set_rank_masters_for_test({RANK_ID: _make_rank(RANK_ID, 100.0, 30)})
	GameState._set_current_rank_id_for_test(RANK_ID)
	_set_rank_state(100.0, 0)
	_set_exam_state(0.0, 50.0, 5, 20)

	var result := GameState.commit_exam_outcome()

	assert_bool(result.success).is_true()
	assert_int(result.value).is_equal(ExamOutcome.Value.SUCCESS)
	assert_that(GameState._current_rank_id).is_equal(RANK_ID)
	assert_float(GameState._rank_state.quota).is_equal_approx(100.0, FLOAT_TOLERANCE)


## 🔴 コードレビュー指摘対応。以前は次ランクのマスターデータ未登録時にin_examがtrueのまま
## 残り続け、以降のcommit_exam_outcome()呼び出しのたびに同じSUCCESS判定・push_errorが
## 無限に繰り返される「解決不能な幽霊試験状態」になっていた。in_examが必ずfalseへ戻り、
## 以降の呼び出しではCONTINUE（試験外の既定値）が返ることを確認する
func test_次ランクのマスターデータが未登録ならin_examがfalseに戻り再呼び出しでもSUCCESSが繰り返されない() -> void:
	GameState._set_rank_masters_for_test({RANK_ID: _make_rank(RANK_ID, 100.0, 30)})
	GameState._set_current_rank_id_for_test(RANK_ID)
	_set_rank_state(100.0, 0)
	_set_exam_state(0.0, 50.0, 5, 20)

	var first_result := GameState.commit_exam_outcome()
	assert_bool(GameState._in_exam).is_false()

	var second_result := GameState.commit_exam_outcome()

	assert_int(first_result.value).is_equal(ExamOutcome.Value.SUCCESS)
	assert_int(second_result.value).is_equal(ExamOutcome.Value.CONTINUE)


# 境界値・異常系（FR-404）: commit_exam_outcome の SUCCESS（次ランクなし＝ゲームクリア）確定処理


func test_RANK_ORDER末尾でSUCCESS確定してもcurrent_rank_idとrank_stateが不変のままin_examが終了する() -> void:
	GameState._set_rank_masters_for_test({LAST_RANK_ID: _make_rank(LAST_RANK_ID, 100.0, 30)})
	GameState._set_current_rank_id_for_test(LAST_RANK_ID)
	_set_rank_state(100.0, 0)
	_set_exam_state(0.0, 50.0, 5, 20)

	var result := GameState.commit_exam_outcome()

	assert_int(result.value).is_equal(ExamOutcome.Value.SUCCESS)
	assert_that(GameState._current_rank_id).is_equal(LAST_RANK_ID)
	assert_float(GameState._rank_state.quota).is_equal_approx(100.0, FLOAT_TOLERANCE)
	assert_bool(GameState._in_exam).is_false()


# 正常系・境界値（FR-110, FR-111）: commit_exam_outcome の FAILURE（ゲームオーバー境界含む）確定処理


func test_FAILURE確定でrank_stateがリセットされdemotion_countが1増えin_examが終了する() -> void:
	_set_rank_state(20.0, 30)
	_set_exam_state(10.0, 100.0, 20, 20)

	var result := GameState.commit_exam_outcome()

	assert_bool(result.success).is_true()
	assert_int(result.value).is_equal(ExamOutcome.Value.FAILURE)
	assert_int(GameState._demotion_count).is_equal(1)
	assert_float(GameState._rank_state.quota).is_equal_approx(100.0, FLOAT_TOLERANCE)
	assert_int(GameState._rank_state.elapsed_turn).is_equal(0)
	assert_bool(GameState._in_exam).is_false()


func test_降格回数が上限直前からFAILURE確定でゲームオーバーになる() -> void:
	GameState._set_demotion_count_for_test(GameBalance.MAX_DEMOTION_COUNT - 1)
	_set_exam_state(10.0, 100.0, 20, 20)

	GameState.commit_exam_outcome()

	assert_int(GameState._demotion_count).is_equal(GameBalance.MAX_DEMOTION_COUNT)
	assert_bool(GameState.is_game_over()).is_true()
	assert_int(_game_over_payloads.size()).is_equal(1)
	assert_int(_game_over_payloads[0]).is_equal(GameBalance.MAX_DEMOTION_COUNT)


func test_降格回数が上限の1つ手前ならFAILURE確定してもゲームオーバーにならない() -> void:
	GameState._set_demotion_count_for_test(GameBalance.MAX_DEMOTION_COUNT - 2)
	_set_exam_state(10.0, 100.0, 20, 20)

	GameState.commit_exam_outcome()

	assert_int(GameState._demotion_count).is_equal(GameBalance.MAX_DEMOTION_COUNT - 1)
	assert_bool(GameState.is_game_over()).is_false()
	assert_int(_game_over_payloads.size()).is_equal(0)


# 正常系・異常系（FR-112, FR-113）: commit_exam_outcome の CONTINUE・冪等性


func test_CONTINUE確定では状態が一切変化しない() -> void:
	_set_rank_state(20.0, 10)
	_set_exam_state(10.0, 100.0, 5, 20)

	var result := GameState.commit_exam_outcome()

	assert_int(result.value).is_equal(ExamOutcome.Value.CONTINUE)
	assert_bool(GameState._in_exam).is_true()
	assert_float(GameState._exam_state.exam_quota).is_equal_approx(10.0, FLOAT_TOLERANCE)
	assert_int(GameState._exam_state.exam_elapsed_turn).is_equal(5)
	assert_float(GameState._rank_state.quota).is_equal_approx(20.0, FLOAT_TOLERANCE)
	assert_int(GameState._demotion_count).is_equal(0)


func test_ゲームオーバー後にcommitを再度呼んでも状態が変化せず直近結果が冪等に返る() -> void:
	GameState._set_demotion_count_for_test(GameBalance.MAX_DEMOTION_COUNT - 1)
	_set_exam_state(10.0, 100.0, 20, 20)
	GameState.commit_exam_outcome()

	_set_exam_state(10.0, 100.0, 20, 20)
	var result := GameState.commit_exam_outcome()

	assert_bool(result.success).is_true()
	assert_int(result.value).is_equal(ExamOutcome.Value.FAILURE)
	assert_int(GameState._demotion_count).is_equal(GameBalance.MAX_DEMOTION_COUNT)
	assert_int(_game_over_payloads.size()).is_equal(1)
