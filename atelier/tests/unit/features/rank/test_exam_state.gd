extends GdUnitTestSuite


# 正常系
func test_newしたExamStateのデフォルト値は4フィールドすべてが0である() -> void:
	var exam_state := ExamState.new()

	assert_float(exam_state.exam_quota).is_equal(0.0)
	assert_float(exam_state.exam_quota_max).is_equal(0.0)
	assert_int(exam_state.exam_elapsed_turn).is_equal(0)
	assert_int(exam_state.exam_turn_limit).is_equal(0)


# 正常系
func test_設定した値がcloneで複製したインスタンスにも引き継がれる() -> void:
	var exam_state := ExamState.new()
	exam_state.exam_quota = 240.5
	exam_state.exam_quota_max = 300.0
	exam_state.exam_elapsed_turn = 3
	exam_state.exam_turn_limit = 5

	var cloned := exam_state.clone()

	assert_float(cloned.exam_quota).is_equal(240.5)
	assert_float(cloned.exam_quota_max).is_equal(300.0)
	assert_int(cloned.exam_elapsed_turn).is_equal(3)
	assert_int(cloned.exam_turn_limit).is_equal(5)


# 正常系
func test_cloneの戻り値は元のインスタンスとは別インスタンスである() -> void:
	var exam_state := ExamState.new()
	exam_state.exam_quota = 100.0

	var cloned := exam_state.clone()

	assert_object(cloned).is_not_same(exam_state)
	assert_bool(cloned == exam_state).is_false()


# 異常系
func test_cloneで複製したインスタンスを変更しても元のインスタンスは影響を受けない() -> void:
	var exam_state := ExamState.new()
	exam_state.exam_quota = 100.0
	exam_state.exam_quota_max = 150.0
	exam_state.exam_elapsed_turn = 2
	exam_state.exam_turn_limit = 4

	var cloned := exam_state.clone()
	cloned.exam_quota = 0.0
	cloned.exam_quota_max = 999.0
	cloned.exam_elapsed_turn = 99
	cloned.exam_turn_limit = 88

	assert_float(exam_state.exam_quota).is_equal(100.0)
	assert_float(exam_state.exam_quota_max).is_equal(150.0)
	assert_int(exam_state.exam_elapsed_turn).is_equal(2)
	assert_int(exam_state.exam_turn_limit).is_equal(4)


# 境界値
func test_全フィールドが0のExamStateもcloneで正しく複製される() -> void:
	var exam_state := ExamState.new()

	var cloned := exam_state.clone()

	assert_object(cloned).is_not_same(exam_state)
	assert_float(cloned.exam_quota).is_equal(0.0)
	assert_float(cloned.exam_quota_max).is_equal(0.0)
	assert_int(cloned.exam_elapsed_turn).is_equal(0)
	assert_int(cloned.exam_turn_limit).is_equal(0)
