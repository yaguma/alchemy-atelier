extends GdUnitTestSuite


func test_指定合致ボーナス倍率が1_3である() -> void:
	assert_float(GameBalance.DAILY_ORDER_MATCH_BONUS_MULTIPLIER).is_equal(1.3)


func test_指定合致ボーナス倍率がfloat型である() -> void:
	assert_int(typeof(GameBalance.DAILY_ORDER_MATCH_BONUS_MULTIPLIER)).is_equal(TYPE_FLOAT)
