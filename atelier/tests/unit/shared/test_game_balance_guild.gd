extends GdUnitTestSuite


func test_指定合致ボーナス倍率が1_3である() -> void:
	assert_float(GameBalance.DAILY_ORDER_MATCH_BONUS_MULTIPLIER).is_equal(1.3)


func test_指定合致ボーナス倍率がfloat型である() -> void:
	assert_int(typeof(GameBalance.DAILY_ORDER_MATCH_BONUS_MULTIPLIER)).is_equal(TYPE_FLOAT)


## DailyOrderMasterの既定値がGameBalance定数を参照しており、2箇所の1.3が独立して
## ずれることがないことを保証する（コードレビュー指摘: マジックナンバーの二重管理防止）
func test_DailyOrderMasterの既定倍率とGameBalance定数が一致する() -> void:
	var order := DailyOrderMaster.new()

	assert_float(order.match_bonus_multiplier).is_equal(
		GameBalance.DAILY_ORDER_MATCH_BONUS_MULTIPLIER
	)
