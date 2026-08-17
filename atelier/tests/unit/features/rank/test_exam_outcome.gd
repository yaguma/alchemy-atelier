extends GdUnitTestSuite


# 正常系
func test_3値がすべて定義されている() -> void:
	var keys: Array = ExamOutcome.Value.keys()

	assert_array(keys).contains(["CONTINUE", "SUCCESS", "FAILURE"])


# 正常系
func test_3値それぞれが一意な値である() -> void:
	var values: Array = ExamOutcome.Value.values()

	assert_int(values.size()).is_equal(3)
	assert_int(ExamOutcome.Value.CONTINUE).is_not_equal(ExamOutcome.Value.SUCCESS)
	assert_int(ExamOutcome.Value.SUCCESS).is_not_equal(ExamOutcome.Value.FAILURE)
	assert_int(ExamOutcome.Value.FAILURE).is_not_equal(ExamOutcome.Value.CONTINUE)


# 正常系
func test_同じ値同士は等値比較で一致する() -> void:
	var outcome: ExamOutcome.Value = ExamOutcome.Value.SUCCESS

	assert_bool(outcome == ExamOutcome.Value.SUCCESS).is_true()
	assert_bool(outcome == ExamOutcome.Value.CONTINUE).is_false()


# 正常系
func test_RankOutcomeとは独立した型として定義されている() -> void:
	var exam_keys: Array = ExamOutcome.Value.keys()
	var rank_keys: Array = RankOutcome.Value.keys()

	assert_array(exam_keys).is_not_equal(rank_keys)
	assert_array(rank_keys).not_contains(["SUCCESS"])


# 境界値
func test_定義順が期待どおりの整数値に対応する() -> void:
	assert_int(ExamOutcome.Value.CONTINUE).is_equal(0)
	assert_int(ExamOutcome.Value.SUCCESS).is_equal(1)
	assert_int(ExamOutcome.Value.FAILURE).is_equal(2)


# 境界値
func test_定義済み3値以外の要素を持たない() -> void:
	var keys: Array = ExamOutcome.Value.keys()

	assert_int(keys.size()).is_equal(3)


# 異常系
func test_未定義の名前は列挙に含まれない() -> void:
	var keys: Array = ExamOutcome.Value.keys()

	assert_array(keys).not_contains(["UNKNOWN"])
