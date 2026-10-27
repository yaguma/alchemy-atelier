extends GdUnitTestSuite

## 🔵 Issue #65（FR-712）。納品のたびに相場が下がり、ターン終了で回復することを検証する。

const FLOAT_TOLERANCE := 0.0001
const RECIPE_A := &"recipe_a"
const RECIPE_B := &"recipe_b"


func before_test() -> void:
	GameState.reset_for_test()


func after_test() -> void:
	GameState.reset_for_test()


func _inject_product(recipe_id: StringName, contribution: float = 10.0) -> void:
	var no_traits: Array[StringName] = []
	GameState._inject_pending_product_for_test(
		ProductInstance.new(recipe_id, 3, no_traits, contribution, 10.0)
	)


func _market_rate(recipe_id: StringName) -> float:
	return MarketRateResolver.get_rate(GameState.get_state()["market_rates"], recipe_id)


func _deliver() -> Array:
	return GameState.deliver_pending_products().value


# 正常系


func test_同じレシピを続けて納品すると2回目から価値が下がる() -> void:
	_inject_product(RECIPE_A)
	var first: DeliveryResult = _deliver()[0]
	_inject_product(RECIPE_A)
	var second: DeliveryResult = _deliver()[0]

	assert_float(first.market_multiplier).is_equal_approx(1.0, FLOAT_TOLERANCE)
	assert_float(second.market_multiplier).is_equal_approx(
		1.0 - GameBalance.MARKET_DROP_STEP, FLOAT_TOLERANCE
	)
	assert_float(second.final_contribution).is_less(first.final_contribution)
	assert_float(second.final_reward).is_less(first.final_reward)


func test_同じターンに同じレシピを2つ納品すると2つ目には下落後の倍率が掛かる() -> void:
	_inject_product(RECIPE_A)
	_inject_product(RECIPE_A)

	var results := _deliver()

	assert_float((results[0] as DeliveryResult).market_multiplier).is_equal_approx(
		1.0, FLOAT_TOLERANCE
	)
	assert_float((results[1] as DeliveryResult).market_multiplier).is_equal_approx(
		1.0 - GameBalance.MARKET_DROP_STEP, FLOAT_TOLERANCE
	)


func test_ターン終了で納品しなかったレシピの相場が回復する() -> void:
	_inject_product(RECIPE_A)
	_deliver()
	GameState.advance_turn_growth()  # このターンは納品済みのため回復しない
	var after_delivered_turn := _market_rate(RECIPE_A)

	GameState.advance_turn_growth()  # 納品しなかったターン

	assert_float(after_delivered_turn).is_equal_approx(
		1.0 - GameBalance.MARKET_DROP_STEP, FLOAT_TOLERANCE
	)
	assert_float(_market_rate(RECIPE_A)).is_equal_approx(
		1.0 - GameBalance.MARKET_DROP_STEP + GameBalance.MARKET_RECOVER_STEP, FLOAT_TOLERANCE
	)


func test_別のレシピの納品は相場に影響しない() -> void:
	_inject_product(RECIPE_A)
	_deliver()

	assert_float(_market_rate(RECIPE_B)).is_equal_approx(1.0, FLOAT_TOLERANCE)


func test_昇格試験中の納品にも相場倍率が適用される() -> void:
	var exam_state := ExamState.new()
	exam_state.exam_quota = 100.0
	exam_state.exam_turn_limit = 2
	GameState._set_exam_state_for_test(exam_state, true)
	_inject_product(RECIPE_A)
	_deliver()
	_inject_product(RECIPE_A)

	var result: DeliveryResult = _deliver()[0]

	assert_float(result.market_multiplier).is_equal_approx(
		1.0 - GameBalance.MARKET_DROP_STEP, FLOAT_TOLERANCE
	)


func test_昇格試験のターン進行でも納品しなかったレシピの相場が回復する() -> void:
	_inject_product(RECIPE_A)
	_deliver()
	GameState.advance_turn_growth()
	var exam_state := ExamState.new()
	exam_state.exam_turn_limit = 3
	GameState._set_exam_state_for_test(exam_state, true)

	GameState.advance_exam_turn()

	assert_float(_market_rate(RECIPE_A)).is_equal_approx(
		1.0 - GameBalance.MARKET_DROP_STEP + GameBalance.MARKET_RECOVER_STEP, FLOAT_TOLERANCE
	)


# 異常系


func test_納品待ちが空なら相場は変化しない() -> void:
	_deliver()

	assert_dict(GameState.get_state()["market_rates"]).is_empty()


func test_get_stateの相場を書き換えてもGameStateの相場は変わらない() -> void:
	_inject_product(RECIPE_A)
	_deliver()
	var rates: Dictionary = GameState.get_state()["market_rates"]

	rates[RECIPE_A] = 99.0

	assert_float(_market_rate(RECIPE_A)).is_less(1.0)


func test_reset_for_new_gameで相場が初期化される() -> void:
	_inject_product(RECIPE_A)
	_deliver()

	GameState.reset_for_new_game()

	assert_dict(GameState.get_state()["market_rates"]).is_empty()


# セーブ/ロード（FR-717）


func test_相場はセーブして復元しても保持される() -> void:
	_inject_product(RECIPE_A)
	_deliver()
	var data := GameStateSaveDelegate.collect_save_data(GameState)

	GameState.reset_for_test()
	GameStateSaveDelegate.restore_save_data(GameState, data)

	assert_float(_market_rate(RECIPE_A)).is_equal_approx(
		1.0 - GameBalance.MARKET_DROP_STEP, FLOAT_TOLERANCE
	)


func test_そのターンに納品したレシピもセーブして復元すると回復対象から外れたまま() -> void:
	_inject_product(RECIPE_A)
	_deliver()
	var data := GameStateSaveDelegate.collect_save_data(GameState)
	GameState.reset_for_test()
	GameStateSaveDelegate.restore_save_data(GameState, data)

	GameState.advance_turn_growth()

	assert_float(_market_rate(RECIPE_A)).is_equal_approx(
		1.0 - GameBalance.MARKET_DROP_STEP, FLOAT_TOLERANCE
	)


func test_相場のない旧形式のセーブデータは空の相場として復元される() -> void:
	var data := GameStateSaveDelegate.collect_save_data(GameState)
	data.erase("market_rates")
	data.erase("delivered_recipe_ids_this_turn")

	GameStateSaveDelegate.restore_save_data(GameState, data)

	assert_dict(GameState.get_state()["market_rates"]).is_empty()
