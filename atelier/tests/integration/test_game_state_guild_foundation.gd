extends GdUnitTestSuite


func before_test() -> void:
	GameState.reset_for_test()


func _make_daily_order(id: String) -> DailyOrderMaster:
	var order := DailyOrderMaster.new()
	order.id = id
	order.condition_type = "item"
	order.target_recipe_id = "recipe_healing_potion"
	order.match_bonus_multiplier = 1.5
	return order


# 正常系


func test_reset_for_test直後はギルド納品関連フィールドが初期値である() -> void:
	assert_float(GameState._accumulated_contribution).is_equal(0.0)
	assert_object(GameState._current_daily_order).is_null()


func test_get_stateがaccumulated_contributionを含み内部値と一致する() -> void:
	var state := GameState.get_state()

	assert_bool(state.has("accumulated_contribution")).is_true()
	assert_float(state["accumulated_contribution"]).is_equal(GameState._accumulated_contribution)


func test_get_stateがcurrent_daily_orderを含む() -> void:
	var state := GameState.get_state()

	assert_bool(state.has("current_daily_order")).is_true()
	assert_object(state["current_daily_order"]).is_null()


func test_set_current_daily_order_for_testで注入した指定調合物が状態に反映される() -> void:
	var order := _make_daily_order("order_test")

	GameState._set_current_daily_order_for_test(order)

	var state := GameState.get_state()
	var stored: DailyOrderMaster = state["current_daily_order"]
	assert_object(stored).is_not_null()
	assert_str(stored.id).is_equal("order_test")
	assert_str(stored.condition_type).is_equal("item")
	assert_float(stored.match_bonus_multiplier).is_equal(1.5)


func test_deliveredシグナルが宣言されている() -> void:
	assert_bool(GameState.has_signal("delivered")).is_true()


# 異常系・エッジケース


func test_set_current_daily_order_for_testを呼ばない場合はnullのままである() -> void:
	assert_object(GameState._current_daily_order).is_null()
	assert_object(GameState.get_state()["current_daily_order"]).is_null()


func test_set_current_daily_order_for_testにnullを渡すと未設定状態へ戻る() -> void:
	GameState._set_current_daily_order_for_test(_make_daily_order("order_test"))

	GameState._set_current_daily_order_for_test(null)

	assert_object(GameState.get_state()["current_daily_order"]).is_null()


# 境界値


func test_reset_for_testでギルド納品関連フィールドが初期状態に戻る() -> void:
	GameState._set_current_daily_order_for_test(_make_daily_order("order_test"))

	GameState.reset_for_test()

	assert_float(GameState._accumulated_contribution).is_equal(0.0)
	assert_object(GameState._current_daily_order).is_null()
