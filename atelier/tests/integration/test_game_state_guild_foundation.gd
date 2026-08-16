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
	assert_object(GameState._current_daily_order).is_null()


## FR-408: 貢献度はランクノルマ（_rank_state.quota）へ直接反映されるため、暫定フィールドは削除済み
func test_get_stateがaccumulated_contributionを含まない() -> void:
	var state := GameState.get_state()

	assert_bool(state.has("accumulated_contribution")).is_false()


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


func test_gold_changedシグナルが宣言されている() -> void:
	assert_bool(GameState.has_signal("gold_changed")).is_true()


## コードレビュー指摘: get_state()がcurrent_daily_orderを参照のまま返すと、
## 戻り値側の変更がGameState内部の正本を汚染してしまう（state-management.md防御的コピー要件）
func test_get_stateのcurrent_daily_orderを変更しても内部状態は汚染されない() -> void:
	GameState._set_current_daily_order_for_test(_make_daily_order("order_test"))

	var order: DailyOrderMaster = GameState.get_state()["current_daily_order"]
	order.match_bonus_multiplier = 99.0

	var order_again: DailyOrderMaster = GameState.get_state()["current_daily_order"]
	assert_float(order_again.match_bonus_multiplier).is_equal(1.5)


## コードレビュー指摘: _set_current_daily_order_for_testが引数を参照のまま保持すると、
## 呼び出し元（テストコード）が注入後に引数を変更した際GameStateの内部状態まで汚染される
func test_set_current_daily_order_for_test注入後に引数を変更しても内部状態は汚染されない() -> void:
	var order := _make_daily_order("order_test")
	GameState._set_current_daily_order_for_test(order)

	order.match_bonus_multiplier = 99.0

	var stored: DailyOrderMaster = GameState.get_state()["current_daily_order"]
	assert_float(stored.match_bonus_multiplier).is_equal(1.5)


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

	assert_object(GameState._current_daily_order).is_null()
