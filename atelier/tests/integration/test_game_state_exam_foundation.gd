extends GdUnitTestSuite

const FLOAT_TOLERANCE := 0.0001


func before_test() -> void:
	GameState.reset_for_test()


func _make_exam_state(
	quota: float, quota_max: float, elapsed_turn: int, turn_limit: int
) -> ExamState:
	var exam_state := ExamState.new()
	exam_state.exam_quota = quota
	exam_state.exam_quota_max = quota_max
	exam_state.exam_elapsed_turn = elapsed_turn
	exam_state.exam_turn_limit = turn_limit
	return exam_state


# 正常系


func test_reset_for_test直後は試験関連フィールドが初期値である() -> void:
	assert_bool(GameState._in_exam).is_false()
	assert_float(GameState._exam_state.exam_quota).is_equal(0.0)
	assert_float(GameState._exam_state.exam_quota_max).is_equal(0.0)
	assert_int(GameState._exam_state.exam_elapsed_turn).is_equal(0)
	assert_int(GameState._exam_state.exam_turn_limit).is_equal(0)


func test_get_stateが試験関連キーを含む() -> void:
	var state := GameState.get_state()

	assert_bool(state.has("in_exam")).is_true()
	assert_bool(state.has("exam_quota")).is_true()
	assert_bool(state.has("exam_quota_max")).is_true()
	assert_bool(state.has("exam_elapsed_turn")).is_true()
	assert_bool(state.has("exam_turn_limit")).is_true()
	assert_bool(state["in_exam"]).is_false()
	assert_float(state["exam_quota"]).is_equal(0.0)


func test_set_exam_state_for_testで注入した値が状態に反映される() -> void:
	var exam_state := _make_exam_state(10.0, 50.0, 3, 20)

	GameState._set_exam_state_for_test(exam_state)

	assert_bool(GameState._in_exam).is_true()
	assert_float(GameState._exam_state.exam_quota).is_equal_approx(10.0, FLOAT_TOLERANCE)
	assert_float(GameState._exam_state.exam_quota_max).is_equal_approx(50.0, FLOAT_TOLERANCE)
	assert_int(GameState._exam_state.exam_elapsed_turn).is_equal(3)
	assert_int(GameState._exam_state.exam_turn_limit).is_equal(20)

	var state := GameState.get_state()
	assert_bool(state["in_exam"]).is_true()
	assert_float(state["exam_quota"]).is_equal_approx(10.0, FLOAT_TOLERANCE)
	assert_float(state["exam_quota_max"]).is_equal_approx(50.0, FLOAT_TOLERANCE)
	assert_int(state["exam_elapsed_turn"]).is_equal(3)
	assert_int(state["exam_turn_limit"]).is_equal(20)


func test_set_exam_state_for_testでin_examをfalseに指定できる() -> void:
	var exam_state := _make_exam_state(10.0, 50.0, 3, 20)

	GameState._set_exam_state_for_test(exam_state, false)

	assert_bool(GameState._in_exam).is_false()
	assert_float(GameState._exam_state.exam_quota).is_equal_approx(10.0, FLOAT_TOLERANCE)


func test_reset_for_testで試験関連フィールドが初期状態に戻る() -> void:
	var exam_state := _make_exam_state(10.0, 50.0, 3, 20)
	GameState._set_exam_state_for_test(exam_state)

	GameState.reset_for_test()

	assert_bool(GameState._in_exam).is_false()
	assert_float(GameState._exam_state.exam_quota).is_equal(0.0)
	assert_float(GameState._exam_state.exam_quota_max).is_equal(0.0)
	assert_int(GameState._exam_state.exam_elapsed_turn).is_equal(0)
	assert_int(GameState._exam_state.exam_turn_limit).is_equal(0)
	assert_int(GameState._last_exam_outcome).is_equal(ExamOutcome.Value.CONTINUE)


# 異常系


## テスト専用APIガード: デバッグビルド外からの実行は禁止される（既存パターン踏襲の確認）。
## CIはデバッグビルドで実行されるため、この呼び出し自体は成功する前提で
## GameStateTestSupport.guard()が例外を投げずfalseを返す実装であることを間接的に確認する
func test_set_exam_state_for_testはデバッグビルドで正常に動作する() -> void:
	assert_bool(OS.is_debug_build()).is_true()

	var exam_state := _make_exam_state(1.0, 2.0, 0, 5)
	GameState._set_exam_state_for_test(exam_state)

	assert_bool(GameState._in_exam).is_true()


# 境界値・エッジケース


## FR-410相当: get_state()の試験フィールドは値型のみのため、戻り値を書き換えても
## GameState内部の正本は汚染されない
func test_get_stateの試験関連フィールドを変更しても内部状態は汚染されない() -> void:
	var exam_state := _make_exam_state(10.0, 50.0, 3, 20)
	GameState._set_exam_state_for_test(exam_state)

	var returned := GameState.get_state()
	returned["exam_quota"] = 999.0
	returned["in_exam"] = false

	var again := GameState.get_state()
	assert_float(again["exam_quota"]).is_equal_approx(10.0, FLOAT_TOLERANCE)
	assert_bool(again["in_exam"]).is_true()


## _set_exam_state_for_test()は内部でExamStateをコピーするため、
## 注入後に引数を変更しても内部状態は汚染されない
func test_set_exam_state_for_test注入後に引数を変更しても内部状態は汚染されない() -> void:
	var exam_state := _make_exam_state(10.0, 50.0, 3, 20)

	GameState._set_exam_state_for_test(exam_state)
	exam_state.exam_quota = 999.0

	assert_float(GameState._exam_state.exam_quota).is_equal_approx(10.0, FLOAT_TOLERANCE)


func test_last_exam_outcomeの初期値はCONTINUEである() -> void:
	assert_int(GameState._last_exam_outcome).is_equal(ExamOutcome.Value.CONTINUE)
