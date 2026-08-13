extends GdUnitTestSuite


func _make_materials(count: int) -> Array[MaterialInstance]:
	var empty_tags: Array[StringName] = []
	var materials: Array[MaterialInstance] = []
	for i in count:
		materials.append(MaterialInstance.new("mat_%d" % i, &"material_herb", 3, empty_tags))
	return materials


# 正常系
func test_レシピ選択済みで素材が枠数以内なら実行可能である() -> void:
	var slot := SlotState.new()
	slot.materials = _make_materials(1)
	slot.max_slots = 4
	slot.selected_recipe_id = &"recipe_healing_potion"

	assert_bool(slot.can_execute()).is_true()


# 異常系
func test_レシピ未選択なら実行不可である() -> void:
	var slot := SlotState.new()
	slot.materials = _make_materials(1)
	slot.max_slots = 4
	slot.selected_recipe_id = &""

	assert_bool(slot.can_execute()).is_false()


# 異常系
func test_素材が0個なら実行不可である() -> void:
	var slot := SlotState.new()
	slot.max_slots = 4
	slot.selected_recipe_id = &"recipe_healing_potion"

	assert_bool(slot.can_execute()).is_false()


# 異常系
func test_初期状態では実行不可である() -> void:
	var slot := SlotState.new()

	assert_bool(slot.can_execute()).is_false()


# 境界値
func test_素材が枠数ちょうどなら実行可能である() -> void:
	var slot := SlotState.new()
	slot.materials = _make_materials(4)
	slot.max_slots = 4
	slot.selected_recipe_id = &"recipe_healing_potion"

	assert_bool(slot.can_execute()).is_true()


# 境界値
func test_素材が枠数を1超えると実行不可である() -> void:
	var slot := SlotState.new()
	slot.materials = _make_materials(5)
	slot.max_slots = 4
	slot.selected_recipe_id = &"recipe_healing_potion"

	assert_bool(slot.can_execute()).is_false()


func test_materialsに設定した配列を後から変更してもSlotStateは影響を受けない() -> void:
	var empty_tags: Array[StringName] = []
	var materials := _make_materials(2)
	var slot := SlotState.new()
	slot.materials = materials

	materials.append(MaterialInstance.new("mat_extra", &"material_herb", 3, empty_tags))

	assert_int(slot.materials.size()).is_equal(2)
