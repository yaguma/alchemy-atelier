extends GdUnitTestSuite


# 正常系
func test_3値がすべて定義されている() -> void:
	var keys: Array = RankOutcome.Value.keys()

	assert_array(keys).contains(["CONTINUE", "PROMOTION_ELIGIBLE", "DEMOTION"])


# 正常系
func test_3値それぞれが一意な値である() -> void:
	var values: Array = RankOutcome.Value.values()

	assert_int(values.size()).is_equal(3)
	assert_int(RankOutcome.Value.CONTINUE).is_not_equal(RankOutcome.Value.PROMOTION_ELIGIBLE)
	assert_int(RankOutcome.Value.PROMOTION_ELIGIBLE).is_not_equal(RankOutcome.Value.DEMOTION)
	assert_int(RankOutcome.Value.DEMOTION).is_not_equal(RankOutcome.Value.CONTINUE)


# 正常系
func test_同じ値同士は等値比較で一致する() -> void:
	var outcome: RankOutcome.Value = RankOutcome.Value.PROMOTION_ELIGIBLE

	assert_bool(outcome == RankOutcome.Value.PROMOTION_ELIGIBLE).is_true()
	assert_bool(outcome == RankOutcome.Value.CONTINUE).is_false()


# 境界値
func test_定義済み3値以外の要素を持たない() -> void:
	var keys: Array = RankOutcome.Value.keys()

	assert_int(keys.size()).is_equal(3)


# 異常系
func test_未定義の名前は列挙に含まれない() -> void:
	var keys: Array = RankOutcome.Value.keys()

	assert_array(keys).not_contains(["UNKNOWN"])
