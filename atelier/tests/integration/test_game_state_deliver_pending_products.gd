extends GdUnitTestSuite

const FLOAT_TOLERANCE := 0.0001
const RECIPE_ID := &"recipe_test"

var _delivered_payloads: Array = []


func before_test() -> void:
	GameState.reset_for_test()
	_delivered_payloads = []
	GameState.delivered.connect(_on_delivered)


func after_test() -> void:
	# GameStateはAutoloadで購読側テストより寿命が長いため明示的に解除する
	if GameState.delivered.is_connected(_on_delivered):
		GameState.delivered.disconnect(_on_delivered)


func _on_delivered(results: Array[DeliveryResult]) -> void:
	_delivered_payloads.append(results)


func _make_product(
	recipe_id: StringName, contribution: float, reward: float, traits: Array[StringName] = []
) -> ProductInstance:
	return ProductInstance.new(recipe_id, 3, traits, contribution, reward)


func _inject_product(product: ProductInstance) -> void:
	GameState._inject_pending_product_for_test(product)


func _pending_count() -> int:
	return (GameState.get_state()["pending_products"] as Array[ProductInstance]).size()


func _gold() -> int:
	return GameState.get_state()["gold"]


## RECIPE_IDに合致する日替わり指定調合物を設定する（合致時に倍率が掛かる状況を作る）
func _set_matching_order(multiplier: float) -> void:
	var order := DailyOrderMaster.new()
	order.id = "order_test"
	order.condition_type = DeliveryResolver.CONDITION_TYPE_ITEM
	order.target_recipe_id = String(RECIPE_ID)
	order.match_bonus_multiplier = multiplier
	GameState._set_current_daily_order_for_test(order)


# 正常系


func test_投入した3件がすべて納品されキューが空になる() -> void:
	_inject_product(_make_product(RECIPE_ID, 10.0, 5.0))
	_inject_product(_make_product(RECIPE_ID, 20.0, 6.0))
	_inject_product(_make_product(RECIPE_ID, 30.0, 7.0))

	var result := GameState.deliver_pending_products()

	assert_bool(result.success).is_true()
	assert_int((result.value as Array[DeliveryResult]).size()).is_equal(3)
	assert_int(_pending_count()).is_equal(0)


func test_戻り値の順序がキューへの投入順と一致する() -> void:
	_inject_product(_make_product(RECIPE_ID, 10.0, 1.0))
	_inject_product(_make_product(RECIPE_ID, 20.0, 2.0))
	_inject_product(_make_product(RECIPE_ID, 30.0, 3.0))

	var results: Array[DeliveryResult] = GameState.deliver_pending_products().value

	assert_float(results[0].final_contribution).is_equal_approx(10.0, FLOAT_TOLERANCE)
	assert_float(results[1].final_contribution).is_equal_approx(20.0, FLOAT_TOLERANCE)
	assert_float(results[2].final_contribution).is_equal_approx(30.0, FLOAT_TOLERANCE)


func test_合致ボーナス適用後の報酬がroundiで丸められてgoldへ加算される() -> void:
	_set_matching_order(1.3)
	_inject_product(_make_product(RECIPE_ID, 10.0, 5.0))

	GameState.deliver_pending_products()

	# 5.0 × 1.3 = 6.5 → roundi() で 7
	assert_int(_gold()).is_equal(7)


func test_加算前のgoldが0でない場合も上書きされず加算される() -> void:
	_inject_product(_make_product(RECIPE_ID, 0.0, 10.0))
	GameState.deliver_pending_products()
	assert_int(_gold()).is_equal(10)

	_inject_product(_make_product(RECIPE_ID, 0.0, 4.0))
	GameState.deliver_pending_products()

	assert_int(_gold()).is_equal(14)


func test_納品1件分の貢献度がaccumulated_contributionへ加算される() -> void:
	_inject_product(_make_product(RECIPE_ID, 10.0, 0.0))

	GameState.deliver_pending_products()

	assert_float(GameState.get_state()["accumulated_contribution"]).is_equal_approx(
		10.0, FLOAT_TOLERANCE
	)


func test_納品を複数回実行すると貢献度がリセットされず累積する() -> void:
	_inject_product(_make_product(RECIPE_ID, 10.0, 0.0))
	GameState.deliver_pending_products()

	_inject_product(_make_product(RECIPE_ID, 25.0, 0.0))
	GameState.deliver_pending_products()

	assert_float(GameState.get_state()["accumulated_contribution"]).is_equal_approx(
		35.0, FLOAT_TOLERANCE
	)


func test_deliveredシグナルが1回だけ発行され件別のorder_matchedが正しい() -> void:
	_set_matching_order(1.5)
	_inject_product(_make_product(RECIPE_ID, 10.0, 2.0))
	_inject_product(_make_product(&"recipe_other", 10.0, 2.0))

	GameState.deliver_pending_products()

	assert_int(_delivered_payloads.size()).is_equal(1)
	var results: Array[DeliveryResult] = _delivered_payloads[0]
	assert_int(results.size()).is_equal(2)
	assert_bool(results[0].order_matched).is_true()
	assert_bool(results[1].order_matched).is_false()
	assert_float(results[0].final_contribution).is_equal_approx(15.0, FLOAT_TOLERANCE)
	assert_float(results[1].final_contribution).is_equal_approx(10.0, FLOAT_TOLERANCE)


func test_monitor_signalsでdeliveredシグナルの発行を検証できる() -> void:
	# AutoloadのGameStateがテスト終了時に自動解放されないよう第2引数falseを明示する
	monitor_signals(GameState, false)
	_inject_product(_make_product(RECIPE_ID, 10.0, 2.0))

	var results: Array[DeliveryResult] = GameState.deliver_pending_products().value

	# deliveredは results 1引数を伴うため、期待引数を明示しないと0引数シグネチャ扱いで一致しない
	await assert_signal(GameState).is_emitted("delivered", [results])


## コードレビュー指摘: delivered.emit(results)とReturn.ok(results)が同一配列を共有していると、
## 購読側が配列を書き換えた場合に戻り値まで汚染される。emit側には独立した配列を渡す
func test_deliveredで受け取った配列を変更してもResultの戻り値は汚染されない() -> void:
	_inject_product(_make_product(RECIPE_ID, 10.0, 2.0))
	_inject_product(_make_product(RECIPE_ID, 20.0, 3.0))

	var results: Array[DeliveryResult] = GameState.deliver_pending_products().value
	_delivered_payloads[0].clear()

	assert_int(results.size()).is_equal(2)


func test_gold_changedシグナルがgold加算後に発行される() -> void:
	monitor_signals(GameState, false)
	_inject_product(_make_product(RECIPE_ID, 10.0, 5.0))

	GameState.deliver_pending_products()

	await assert_signal(GameState).is_emitted(GameState.gold_changed, 0, 5, 5)


func test_goldに変化がない場合はgold_changedシグナルが発行されない() -> void:
	var emit_count := 0
	var handler := func(_previous: int, _new_amount: int, _delta: int) -> void: emit_count += 1
	GameState.gold_changed.connect(handler)

	_inject_product(_make_product(RECIPE_ID, 10.0, 0.0))
	GameState.deliver_pending_products()

	GameState.gold_changed.disconnect(handler)
	assert_int(emit_count).is_equal(0)


# 異常系・エッジケース


func test_キューが空の状態で呼ぶと状態を一切変更せず成功を返す() -> void:
	var result := GameState.deliver_pending_products()

	assert_bool(result.success).is_true()
	assert_int((result.value as Array[DeliveryResult]).size()).is_equal(0)
	assert_int(_gold()).is_equal(0)
	assert_float(GameState.get_state()["accumulated_contribution"]).is_equal(0.0)
	assert_int(_pending_count()).is_equal(0)
	assert_int(_delivered_payloads.size()).is_equal(0)


func test_連続2回呼び出すと2回目は空配列で二重納品されない() -> void:
	_inject_product(_make_product(RECIPE_ID, 10.0, 5.0))
	GameState.deliver_pending_products()
	var gold_after_first: int = GameState.get_state()["gold"]

	var second := GameState.deliver_pending_products()

	assert_bool(second.success).is_true()
	assert_int((second.value as Array[DeliveryResult]).size()).is_equal(0)
	assert_int(GameState.get_state()["gold"]).is_equal(gold_after_first)


# 統合（execute_alchemy との連携）


## 調合レシピと素材を仕込み、execute_alchemy が実行できる状態にする
func _setup_alchemy() -> void:
	var recipe := RecipeMaster.new()
	recipe.id = RECIPE_ID
	recipe.name = "テストレシピ"
	recipe.base_contribution = 10.0
	recipe.base_reward = 5.0
	GameState._set_recipe_masters_for_test({RECIPE_ID: recipe})
	GameState._set_unlocked_recipe_ids_for_test([RECIPE_ID] as Array[StringName])
	GameState._inject_material_for_test(
		MaterialInstance.new("mat_1", &"material_herb", 4, [] as Array[StringName])
	)
	GameState._inject_material_for_test(
		MaterialInstance.new("mat_2", &"material_herb", 2, [] as Array[StringName])
	)


func test_調合から納品までの一連で合致ボーナスが1回だけ適用される() -> void:
	_setup_alchemy()
	_set_matching_order(1.3)

	var product: ProductInstance = (
		GameState.execute_alchemy(RECIPE_ID, ["mat_1", "mat_2"] as Array[String]).value
	)
	var results: Array[DeliveryResult] = GameState.deliver_pending_products().value

	# 品質 (4+2)/2=3 → 品質倍率1.5、特性ボーナスなし
	# 貢献度: 10.0 × 1.5 = 15.0（この時点では合致ボーナス未適用）
	assert_float(product.contribution).is_equal_approx(15.0, FLOAT_TOLERANCE)
	assert_float(product.reward).is_equal_approx(7.5, FLOAT_TOLERANCE)
	# 納品時に合致ボーナス1.3を1回だけ乗算する（二重乗算していないこと）
	assert_float(results[0].final_contribution).is_equal_approx(19.5, FLOAT_TOLERANCE)
	assert_float(results[0].final_reward).is_equal_approx(9.75, FLOAT_TOLERANCE)
	assert_int(_gold()).is_equal(10)


func test_get_stateのpending_productsを変更しても内部キューは汚染されない() -> void:
	_inject_product(_make_product(RECIPE_ID, 10.0, 2.0))
	_inject_product(_make_product(RECIPE_ID, 20.0, 3.0))

	var before_copy: Array[ProductInstance] = GameState.get_state()["pending_products"]
	before_copy.append(_make_product(RECIPE_ID, 999.0, 999.0))
	var results: Array[DeliveryResult] = GameState.deliver_pending_products().value

	assert_int(results.size()).is_equal(2)

	var after_copy: Array[ProductInstance] = GameState.get_state()["pending_products"]
	after_copy.append(_make_product(RECIPE_ID, 999.0, 999.0))

	assert_int(_pending_count()).is_equal(0)


# 境界値


func test_報酬の四捨五入境界で切り捨てと切り上げが分かれる(
	reward: float,
	expected_gold: int,
	_test_parameters := [
		[6.4, 6],  # 端数0.5未満は切り捨て
		[6.5, 7],  # 端数0.5ちょうどは切り上げ
		[0.0, 0],  # 報酬0は加算されない
	]
) -> void:
	_inject_product(_make_product(RECIPE_ID, 0.0, reward))

	GameState.deliver_pending_products()

	assert_int(_gold()).is_equal(expected_gold)
