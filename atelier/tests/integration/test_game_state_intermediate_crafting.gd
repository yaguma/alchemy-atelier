extends GdUnitTestSuite

## 🔵 Issue #66（FR-713）。中間素材レシピの調合で、納品されずに素材として在庫へ加わることを検証する。

const INTERMEDIATE_RECIPE_ID := &"recipe_holy_water"
const PRODUCT_RECIPE_ID := &"recipe_healing_potion"
const RANK_ID := &"rank_test"


func before_test() -> void:
	GameState.reset_for_test()
	var recipes := {
		INTERMEDIATE_RECIPE_ID: _make_intermediate_recipe(),
		PRODUCT_RECIPE_ID: _make_product_recipe(),
	}
	GameState._set_recipe_masters_for_test(recipes)
	GameState._set_unlocked_recipe_ids_for_test(
		[INTERMEDIATE_RECIPE_ID, PRODUCT_RECIPE_ID] as Array[StringName]
	)
	GameState._set_alchemy_slot_count_for_test(4)
	_set_rank(true)


func after_test() -> void:
	GameState.reset_for_test()


func _make_intermediate_recipe() -> RecipeMaster:
	var recipe := RecipeMaster.new()
	recipe.id = INTERMEDIATE_RECIPE_ID
	recipe.name = "聖水"
	recipe.kind = RecipeMaster.KIND_INTERMEDIATE
	recipe.output_material_id = &"material_holy_water"
	recipe.max_concentrated_traits = 1
	return recipe


func _make_product_recipe() -> RecipeMaster:
	var recipe := RecipeMaster.new()
	recipe.id = PRODUCT_RECIPE_ID
	recipe.name = "回復薬"
	recipe.base_contribution = 10.0
	recipe.base_reward = 5.0
	return recipe


func _set_rank(traits_unlocked: bool) -> void:
	var rank := RankMaster.new()
	rank.id = String(RANK_ID)
	rank.traits_unlocked = traits_unlocked
	GameState._set_rank_masters_for_test({RANK_ID: rank})
	GameState._set_current_rank_id_for_test(RANK_ID)


func _inject(instance_id: String, quality: int, tags: Array[StringName] = []) -> void:
	GameState._inject_material_for_test(
		MaterialInstance.new(instance_id, &"material_herb", quality, tags)
	)


func _inventory() -> Array:
	return GameState.get_state()["inventory"]


func _find_in_inventory(material_id: StringName) -> MaterialInstance:
	for material: MaterialInstance in _inventory():
		if material.material_id == material_id:
			return material
	return null


# 正常系


func test_中間素材の調合で凝縮特性を持つ素材が在庫に加わり納品されない() -> void:
	_inject("mat_a", 3, [&"holy"])
	_inject("mat_b", 3, [&"holy"])

	var result := GameState.execute_alchemy(INTERMEDIATE_RECIPE_ID, ["mat_a", "mat_b"])

	assert_bool(result.success).is_true()
	assert_int((GameState.get_state()["pending_products"] as Array).size()).is_equal(0)
	var crafted := _find_in_inventory(&"material_holy_water")
	assert_object(crafted).is_not_null()
	assert_array(crafted.trait_tags).contains_exactly([&"holy", &"holy"] as Array[StringName])
	assert_int(_inventory().size()).is_equal(1)


func test_中間素材の調合ではintermediate_craftedが発行されproduct_craftedは発行されない() -> void:
	_inject("mat_a", 3, [&"holy"])
	_inject("mat_b", 3, [&"holy"])
	monitor_signals(GameState, false)

	GameState.execute_alchemy(INTERMEDIATE_RECIPE_ID, ["mat_a", "mat_b"])

	await assert_signal(GameState).is_emitted("intermediate_crafted", [any_object()])
	await assert_signal(GameState).wait_until(50).is_not_emitted("product_crafted")


func test_中間素材1個で納品用の調合に特性が宿る() -> void:
	_inject("mat_a", 3, [&"holy"])
	_inject("mat_b", 3, [&"holy"])
	GameState.execute_alchemy(INTERMEDIATE_RECIPE_ID, ["mat_a", "mat_b"])
	var holy_water := _find_in_inventory(&"material_holy_water")
	_inject("mat_c", 3)

	var result := GameState.execute_alchemy(PRODUCT_RECIPE_ID, [holy_water.instance_id, "mat_c"])

	var product: ProductInstance = result.value
	assert_array(product.activated_traits).contains_exactly([&"holy"] as Array[StringName])


func test_中間素材には既存素材と重複しないinstance_idが採番される() -> void:
	_inject("mat_0000", 3, [&"holy"])
	_inject("mat_b", 3, [&"holy"])
	_inject("mat_c", 3)

	GameState.execute_alchemy(INTERMEDIATE_RECIPE_ID, ["mat_0000", "mat_b"])

	var crafted := _find_in_inventory(&"material_holy_water")
	assert_str(crafted.instance_id).is_not_equal("mat_c")
	assert_str(crafted.instance_id).is_not_empty()


func test_昇格試験中の中間素材の調合も試験ターンを1消費する() -> void:
	var exam_state := ExamState.new()
	exam_state.exam_turn_limit = 3
	GameState._set_exam_state_for_test(exam_state, true)
	_inject("mat_a", 3, [&"holy"])
	_inject("mat_b", 3, [&"holy"])

	GameState.execute_alchemy(INTERMEDIATE_RECIPE_ID, ["mat_a", "mat_b"])

	assert_int(GameState.get_state()["exam_elapsed_turn"]).is_equal(1)


# 異常系


func test_特性封印中の中間素材は無特性になる() -> void:
	_set_rank(false)
	_inject("mat_a", 3, [&"holy"])
	_inject("mat_b", 3, [&"holy"])

	GameState.execute_alchemy(INTERMEDIATE_RECIPE_ID, ["mat_a", "mat_b"])

	assert_array(_find_in_inventory(&"material_holy_water").trait_tags).is_empty()


func test_出力素材IDが未設定の中間素材レシピは失敗し在庫が変わらない() -> void:
	var broken := _make_intermediate_recipe()
	broken.output_material_id = &""
	GameState._set_recipe_masters_for_test({INTERMEDIATE_RECIPE_ID: broken})
	_inject("mat_a", 3, [&"holy"])
	_inject("mat_b", 3, [&"holy"])

	var result := GameState.execute_alchemy(INTERMEDIATE_RECIPE_ID, ["mat_a", "mat_b"])

	assert_bool(result.success).is_false()
	assert_that(result.error_code).is_equal(&"intermediate_output_missing")
	assert_int(_inventory().size()).is_equal(2)


# セーブ/ロード


func test_凝縮された特性はセーブして復元しても保持される() -> void:
	_inject("mat_a", 3, [&"holy"])
	_inject("mat_b", 3, [&"holy"])
	GameState.execute_alchemy(INTERMEDIATE_RECIPE_ID, ["mat_a", "mat_b"])
	var data := GameStateSaveDelegate.collect_save_data(GameState)

	GameState.reset_for_test()
	GameStateSaveDelegate.restore_save_data(GameState, data)

	assert_array(_find_in_inventory(&"material_holy_water").trait_tags).contains_exactly(
		[&"holy", &"holy"] as Array[StringName]
	)
