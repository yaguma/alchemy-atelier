extends GdUnitTestSuite

const RECIPE_ID := &"recipe_test"
const BASE_CONTRIBUTION := 10.0
const BASE_REWARD := 5.0
const FLOAT_TOLERANCE := 0.0001

var _crafted_products: Array[ProductInstance] = []
var _failed_error_codes: Array[StringName] = []


func before_test() -> void:
	GameState.reset_for_test()
	GameState._set_recipe_masters_for_test({RECIPE_ID: _make_recipe(RECIPE_ID)})
	GameState._set_unlocked_recipe_ids_for_test([RECIPE_ID] as Array[StringName])
	_crafted_products = []
	_failed_error_codes = []
	GameState.product_crafted.connect(_on_product_crafted)
	GameState.execute_alchemy_failed.connect(_on_execute_alchemy_failed)


func after_test() -> void:
	# GameStateはAutoloadで購読側テストより寿命が長いため明示的に解除する
	if GameState.product_crafted.is_connected(_on_product_crafted):
		GameState.product_crafted.disconnect(_on_product_crafted)
	if GameState.execute_alchemy_failed.is_connected(_on_execute_alchemy_failed):
		GameState.execute_alchemy_failed.disconnect(_on_execute_alchemy_failed)


func _on_product_crafted(product: ProductInstance) -> void:
	_crafted_products.append(product)


func _on_execute_alchemy_failed(_recipe_id: StringName, error_code: StringName) -> void:
	_failed_error_codes.append(error_code)


func _make_recipe(id: StringName) -> RecipeMaster:
	var recipe := RecipeMaster.new()
	recipe.id = id
	recipe.name = "テストレシピ"
	recipe.base_contribution = BASE_CONTRIBUTION
	recipe.base_reward = BASE_REWARD
	return recipe


func _inject_material(instance_id: String, quality: int, tags: Array[StringName]) -> void:
	GameState._inject_material_for_test(
		MaterialInstance.new(instance_id, &"material_herb", quality, tags)
	)


func _inventory_ids() -> Array[String]:
	var ids: Array[String] = []
	for material in GameState.get_state()["inventory"] as Array[MaterialInstance]:
		ids.append(material.instance_id)
	return ids


func _pending_count() -> int:
	return (GameState.get_state()["pending_products"] as Array[ProductInstance]).size()


# 正常系


func test_特性なしの単純ケースで貢献度と報酬が式通りに算出される() -> void:
	_inject_material("mat_1", 4, [] as Array[StringName])
	_inject_material("mat_2", 2, [] as Array[StringName])

	var result := GameState.execute_alchemy(RECIPE_ID, ["mat_1", "mat_2"] as Array[String])

	assert_bool(result.success).is_true()
	var product: ProductInstance = result.value
	# 平均(4+2)/2=3 → 品質倍率1.5、特性ボーナスなし（1.0）
	assert_int(product.quality_score).is_equal(3)
	assert_float(product.contribution).is_equal_approx(15.0, FLOAT_TOLERANCE)
	assert_float(product.reward).is_equal_approx(7.5, FLOAT_TOLERANCE)


func test_調合成功時に投入した素材だけがinventoryから消費される() -> void:
	_inject_material("mat_1", 3, [] as Array[StringName])
	_inject_material("mat_2", 3, [] as Array[StringName])
	_inject_material("mat_3", 3, [] as Array[StringName])

	GameState.execute_alchemy(RECIPE_ID, ["mat_1", "mat_3"] as Array[String])

	assert_array(_inventory_ids()).contains_exactly(["mat_2"] as Array[String])


func test_調合成功時にpending_products追加とproduct_craftedシグナル発行が行われる() -> void:
	_inject_material("mat_1", 3, [] as Array[StringName])

	var result := GameState.execute_alchemy(RECIPE_ID, ["mat_1"] as Array[String])

	var product: ProductInstance = result.value
	assert_int(_pending_count()).is_equal(1)
	assert_int(_crafted_products.size()).is_equal(1)
	assert_float(_crafted_products[0].contribution).is_equal_approx(
		product.contribution, FLOAT_TOLERANCE
	)
	assert_float(_crafted_products[0].reward).is_equal_approx(product.reward, FLOAT_TOLERANCE)
	assert_int(_crafted_products[0].quality_score).is_equal(product.quality_score)


func test_生成されたProductInstanceのrecipe_idが投入したrecipe_idと一致する() -> void:
	_inject_material("mat_1", 3, [] as Array[StringName])

	var result := GameState.execute_alchemy(RECIPE_ID, ["mat_1"] as Array[String])

	assert_that((result.value as ProductInstance).recipe_id).is_equal(RECIPE_ID)


func test_特性未解禁では触媒と特性の両ボーナスが無効になる() -> void:
	GameState._set_traits_unlocked_for_test(false)
	_inject_material("mat_1", 3, [&"catalyst", &"heal"] as Array[StringName])
	_inject_material("mat_2", 3, [&"heal"] as Array[StringName])

	var result := GameState.execute_alchemy(RECIPE_ID, ["mat_1", "mat_2"] as Array[String])

	var product: ProductInstance = result.value
	assert_int(product.quality_score).is_equal(3)
	assert_array(product.activated_traits).is_empty()
	assert_float(product.contribution).is_equal_approx(15.0, FLOAT_TOLERANCE)


func test_特性解禁後は同じ素材構成で触媒と特性の両ボーナスが有効になる() -> void:
	GameState._set_traits_unlocked_for_test(true)
	_inject_material("mat_1", 3, [&"catalyst", &"heal"] as Array[StringName])
	_inject_material("mat_2", 3, [&"heal"] as Array[StringName])

	var result := GameState.execute_alchemy(RECIPE_ID, ["mat_1", "mat_2"] as Array[String])

	var product: ProductInstance = result.value
	# 触媒で品質3→4（倍率1.75）、heal×2で貢献度系ボーナス1.3が発現
	assert_int(product.quality_score).is_equal(4)
	assert_array(product.activated_traits).contains_exactly([&"heal"] as Array[StringName])
	assert_float(product.contribution).is_equal_approx(22.75, FLOAT_TOLERANCE)
	assert_float(product.reward).is_equal_approx(8.75, FLOAT_TOLERANCE)


func test_投入枠数ちょうどの件数なら調合に成功する() -> void:
	for i in range(GameBalance.ALCHEMY_SLOT_COUNT_DEFAULT):
		_inject_material("mat_%d" % i, 3, [] as Array[StringName])

	var result := GameState.execute_alchemy(RECIPE_ID, _inventory_ids())

	assert_bool(result.success).is_true()
	assert_int(_inventory_ids().size()).is_equal(0)


# 異常系


func test_未知のrecipe_idで失敗し状態が変化しない() -> void:
	_inject_material("mat_1", 3, [] as Array[StringName])

	var result := GameState.execute_alchemy(&"recipe_unknown", ["mat_1"] as Array[String])

	assert_bool(result.success).is_false()
	assert_that(result.error_code).is_equal(&"unknown_recipe_id")
	assert_array(_failed_error_codes).contains_exactly([&"unknown_recipe_id"] as Array[StringName])
	assert_array(_inventory_ids()).contains_exactly(["mat_1"] as Array[String])
	assert_int(_pending_count()).is_equal(0)


func test_未解禁のrecipe_idで失敗し状態が変化しない() -> void:
	GameState._set_recipe_masters_for_test(
		{RECIPE_ID: _make_recipe(RECIPE_ID), &"recipe_locked": _make_recipe(&"recipe_locked")}
	)
	_inject_material("mat_1", 3, [] as Array[StringName])

	var result := GameState.execute_alchemy(&"recipe_locked", ["mat_1"] as Array[String])

	assert_bool(result.success).is_false()
	assert_that(result.error_code).is_equal(&"recipe_not_unlocked")
	assert_array(_failed_error_codes).contains_exactly(
		[&"recipe_not_unlocked"] as Array[StringName]
	)
	assert_array(_inventory_ids()).contains_exactly(["mat_1"] as Array[String])
	assert_int(_pending_count()).is_equal(0)


func test_未所持のinstance_idが混ざると失敗し状態が変化しない() -> void:
	_inject_material("mat_1", 3, [] as Array[StringName])

	var result := GameState.execute_alchemy(RECIPE_ID, ["mat_1", "mat_missing"] as Array[String])

	assert_bool(result.success).is_false()
	assert_that(result.error_code).is_equal(&"material_not_owned")
	assert_array(_failed_error_codes).contains_exactly([&"material_not_owned"] as Array[StringName])
	assert_array(_inventory_ids()).contains_exactly(["mat_1"] as Array[String])
	assert_int(_pending_count()).is_equal(0)


func test_同一instance_idを重複指定すると失敗し状態が変化しない() -> void:
	_inject_material("mat_1", 3, [] as Array[StringName])

	var result := GameState.execute_alchemy(RECIPE_ID, ["mat_1", "mat_1"] as Array[String])

	assert_bool(result.success).is_false()
	assert_that(result.error_code).is_equal(&"duplicate_material_in_slot")
	assert_array(_failed_error_codes).contains_exactly(
		[&"duplicate_material_in_slot"] as Array[StringName]
	)
	assert_array(_inventory_ids()).contains_exactly(["mat_1"] as Array[String])
	assert_int(_pending_count()).is_equal(0)


func test_投入枠数を超える件数で失敗し状態が変化しない() -> void:
	for i in range(GameBalance.ALCHEMY_SLOT_COUNT_DEFAULT + 1):
		_inject_material("mat_%d" % i, 3, [] as Array[StringName])
	var ids := _inventory_ids()

	var result := GameState.execute_alchemy(RECIPE_ID, ids)

	assert_bool(result.success).is_false()
	assert_that(result.error_code).is_equal(&"slot_execution_invalid")
	assert_array(_failed_error_codes).contains_exactly(
		[&"slot_execution_invalid"] as Array[StringName]
	)
	assert_array(_inventory_ids()).contains_exactly(ids)
	assert_int(_pending_count()).is_equal(0)


func test_0個投入で失敗し状態が変化しない() -> void:
	_inject_material("mat_1", 3, [] as Array[StringName])

	var result := GameState.execute_alchemy(RECIPE_ID, [] as Array[String])

	assert_bool(result.success).is_false()
	assert_that(result.error_code).is_equal(&"slot_execution_invalid")
	assert_array(_failed_error_codes).contains_exactly(
		[&"slot_execution_invalid"] as Array[StringName]
	)
	assert_array(_inventory_ids()).contains_exactly(["mat_1"] as Array[String])
	assert_int(_pending_count()).is_equal(0)


func test_失敗時はproduct_craftedシグナルが発行されない() -> void:
	_inject_material("mat_1", 3, [] as Array[StringName])

	GameState.execute_alchemy(&"recipe_unknown", ["mat_1"] as Array[String])
	GameState.execute_alchemy(RECIPE_ID, ["mat_missing"] as Array[String])
	GameState.execute_alchemy(RECIPE_ID, [] as Array[String])

	assert_array(_crafted_products).is_empty()
	assert_int(_failed_error_codes.size()).is_equal(3)
