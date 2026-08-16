extends GdUnitTestSuite


# 正常系
func test_生成時に指定した全フィールドを読み出せる() -> void:
	var result := DeliveryResult.new(13.0, 6.5, true)

	assert_float(result.final_contribution).is_equal(13.0)
	assert_float(result.final_reward).is_equal(6.5)
	assert_bool(result.order_matched).is_true()


# 正常系
func test_指定依頼に不一致でも貢献度と報酬は保持される() -> void:
	var result := DeliveryResult.new(10.0, 5.0, false)

	assert_float(result.final_contribution).is_equal(10.0)
	assert_float(result.final_reward).is_equal(5.0)
	assert_bool(result.order_matched).is_false()


# 境界値
func test_貢献度と報酬がゼロでも保持される() -> void:
	var result := DeliveryResult.new(0.0, 0.0, false)

	assert_float(result.final_contribution).is_equal(0.0)
	assert_float(result.final_reward).is_equal(0.0)


# 異常系
func test_同一引数で生成した2つのインスタンスは全フィールドが一致する() -> void:
	var first := DeliveryResult.new(13.0, 6.5, true)
	var second := DeliveryResult.new(13.0, 6.5, true)

	assert_float(second.final_contribution).is_equal(first.final_contribution)
	assert_float(second.final_reward).is_equal(first.final_reward)
	assert_bool(second.order_matched).is_equal(first.order_matched)
