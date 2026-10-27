extends GdUnitTestSuite

## 🔵 Issue #66（FR-713）。中間素材の組み立てを検証する。


func _make_material(quality: int, trait_tags: Array[StringName] = []) -> MaterialInstance:
	return MaterialInstance.new("mat_in", &"material_herb", quality, trait_tags)


func _make_recipe(max_traits: int = 1) -> RecipeMaster:
	var recipe := RecipeMaster.new()
	recipe.id = &"recipe_holy_water"
	recipe.kind = RecipeMaster.KIND_INTERMEDIATE
	recipe.output_material_id = &"material_holy_water"
	recipe.max_concentrated_traits = max_traits
	return recipe


# 正常系


func test_build_trait_tagsは各特性を凝縮数ぶん並べる() -> void:
	var traits: Array[StringName] = [&"holy", &"gold"]

	var tags := IntermediateCrafter.build_trait_tags(traits)

	assert_array(tags).contains_exactly([&"holy", &"holy", &"gold", &"gold"] as Array[StringName])


func test_select_concentrated_traitsは投入数の多い特性を優先する() -> void:
	var materials: Array[MaterialInstance] = [
		_make_material(3, [&"gold"]),
		_make_material(3, [&"holy"]),
		_make_material(3, [&"holy"]),
		_make_material(3, [&"gold"]),
		_make_material(3, [&"holy"]),
	]
	var activated: Array[StringName] = [&"gold", &"holy"]

	var selected := IntermediateCrafter.select_concentrated_traits(materials, activated, 1)

	assert_array(selected).contains_exactly([&"holy"] as Array[StringName])


func test_select_concentrated_traitsは同数なら発現順で先の特性を優先する() -> void:
	var materials: Array[MaterialInstance] = [
		_make_material(3, [&"gold"]),
		_make_material(3, [&"holy"]),
		_make_material(3, [&"gold"]),
		_make_material(3, [&"holy"]),
	]
	var activated: Array[StringName] = [&"gold", &"holy"]

	var selected := IntermediateCrafter.select_concentrated_traits(materials, activated, 1)

	assert_array(selected).contains_exactly([&"gold"] as Array[StringName])


func test_craftは調合品質と凝縮特性を持つ中間素材を返す() -> void:
	var materials: Array[MaterialInstance] = [
		_make_material(4, [&"holy"]),
		_make_material(2, [&"holy"]),
	]

	var crafted := IntermediateCrafter.craft(materials, _make_recipe(), true, "mat_0042")

	assert_str(crafted.instance_id).is_equal("mat_0042")
	assert_that(crafted.material_id).is_equal(&"material_holy_water")
	assert_int(crafted.quality_score).is_equal(3)
	assert_array(crafted.trait_tags).contains_exactly([&"holy", &"holy"] as Array[StringName])
	assert_int(crafted.freshness_elapsed_turns).is_equal(0)


# 異常系


func test_特性が発現しなければ無特性の中間素材になる() -> void:
	var materials: Array[MaterialInstance] = [_make_material(3, [&"holy"]), _make_material(3)]

	var crafted := IntermediateCrafter.craft(materials, _make_recipe(), true, "mat_0001")

	assert_array(crafted.trait_tags).is_empty()


func test_特性封印中は凝縮されない() -> void:
	var materials: Array[MaterialInstance] = [
		_make_material(3, [&"holy"]),
		_make_material(3, [&"holy"]),
	]

	var crafted := IntermediateCrafter.craft(materials, _make_recipe(), false, "mat_0001")

	assert_array(crafted.trait_tags).is_empty()


func test_触媒タグは凝縮の対象にならない() -> void:
	var materials: Array[MaterialInstance] = [
		_make_material(3, [&"catalyst"]),
		_make_material(3, [&"catalyst"]),
	]

	var crafted := IntermediateCrafter.craft(materials, _make_recipe(), true, "mat_0001")

	assert_array(crafted.trait_tags).is_empty()


# 境界値


func test_凝縮できる特性数の上限が2なら2特性とも凝縮される() -> void:
	var materials: Array[MaterialInstance] = [
		_make_material(3, [&"holy"]),
		_make_material(3, [&"holy"]),
		_make_material(3, [&"gold"]),
		_make_material(3, [&"gold"]),
	]

	var crafted := IntermediateCrafter.craft(materials, _make_recipe(2), true, "mat_0001")

	assert_array(crafted.trait_tags).contains_exactly_in_any_order(
		[&"holy", &"holy", &"gold", &"gold"] as Array[StringName]
	)


func test_凝縮できる特性数が0以下なら凝縮しない() -> void:
	var materials: Array[MaterialInstance] = [
		_make_material(3, [&"holy"]),
		_make_material(3, [&"holy"]),
	]
	var activated: Array[StringName] = [&"holy"]

	assert_array(IntermediateCrafter.select_concentrated_traits(materials, activated, 0)).is_empty()
