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


func test_試験中に呼ぶとexam_elapsed_turnが1増加しResultが成功を返す() -> void:
	GameState._set_exam_state_for_test(_make_exam_state(10.0, 50.0, 3, 20))

	var result := GameState.advance_exam_turn()

	assert_bool(result.success).is_true()
	assert_int(GameState.get_state().exam_elapsed_turn).is_equal(4)


# 異常系（FR-104）


func test_試験外に呼ぶと状態を変更せず失敗のResultを返す() -> void:
	GameState._set_exam_state_for_test(_make_exam_state(10.0, 50.0, 3, 20), false)

	var result := GameState.advance_exam_turn()

	assert_bool(result.success).is_false()
	assert_str(result.error_code).is_equal("not_in_exam")
	assert_int(GameState.get_state().exam_elapsed_turn).is_equal(3)
	assert_bool(GameState.get_state().in_exam).is_false()


# 境界値


func test_残り1ターンの状態から実行するとちょうど制限ターンに到達する() -> void:
	GameState._set_exam_state_for_test(_make_exam_state(10.0, 50.0, 4, 5))

	var result := GameState.advance_exam_turn()

	assert_bool(result.success).is_true()
	assert_int(GameState.get_state().exam_elapsed_turn).is_equal(5)
	assert_int(GameState.get_state().exam_turn_limit).is_equal(5)


# 副作用範囲の確認


func test_試験状態以外のフィールドに影響しない() -> void:
	GameState._set_exam_state_for_test(_make_exam_state(10.0, 50.0, 3, 20))
	var rank_state := RankState.new()
	rank_state.quota = 42.0
	rank_state.elapsed_turn = 7
	GameState._set_rank_state_for_test(rank_state)
	var product := ProductInstance.new(&"healing_potion", 3, [] as Array[StringName], 10.0, 20.0)
	GameState._inject_pending_product_for_test(product)

	var before := GameState.get_state()

	GameState.advance_exam_turn()

	var after := GameState.get_state()
	assert_int(after.gold).is_equal(before.gold)
	assert_float(after.rank_state.quota).is_equal_approx(before.rank_state.quota, FLOAT_TOLERANCE)
	assert_int(after.rank_state.elapsed_turn).is_equal(before.rank_state.elapsed_turn)
	assert_int(after.pending_products.size()).is_equal(before.pending_products.size())
	assert_str(after.current_phase).is_equal(before.current_phase)
	assert_int(after.current_turn).is_equal(before.current_turn)
