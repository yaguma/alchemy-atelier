extends GdUnitTestSuite


func before_test() -> void:
	GameState.reset_for_test()


func _make_recipe(id: StringName) -> RecipeMaster:
	var recipe := RecipeMaster.new()
	recipe.id = id
	recipe.name = "テストレシピ"
	recipe.base_contribution = 1.0
	recipe.base_reward = 2.0
	return recipe


# 正常系


func test_reset_for_test直後は調合関連フィールドが初期値である() -> void:
	assert_int(GameState._recipe_masters.size()).is_equal(0)
	assert_array(GameState._unlocked_recipe_ids).contains_exactly(
		[GameBalance.INITIAL_RECIPE_ID] as Array[StringName]
	)
	assert_int(GameState._pending_products.size()).is_equal(0)
	assert_int(GameState._alchemy_slot_count).is_equal(GameBalance.ALCHEMY_SLOT_COUNT_DEFAULT)


func test_load_alchemy_master_dataで実データからrecipe_healing_potionがロードされる() -> void:
	GameState.load_alchemy_master_data()

	assert_bool(GameState._recipe_masters.has(&"recipe_healing_potion")).is_true()
	var recipe: RecipeMaster = GameState._recipe_masters[&"recipe_healing_potion"]
	assert_str(recipe.name).is_equal("回復薬")
	assert_float(recipe.base_contribution).is_equal(10.0)
	assert_float(recipe.base_reward).is_equal(5.0)


func test_get_stateがpending_productsとunlocked_recipe_idsを含む() -> void:
	var state := GameState.get_state()

	assert_bool(state.has("pending_products")).is_true()
	assert_bool(state.has("unlocked_recipe_ids")).is_true()
	assert_int((state["pending_products"] as Array[ProductInstance]).size()).is_equal(0)
	assert_array(state["unlocked_recipe_ids"]).contains_exactly(
		[GameBalance.INITIAL_RECIPE_ID] as Array[StringName]
	)


func test_inject_material_for_testで注入した素材がinventoryに反映される() -> void:
	var material := MaterialInstance.new(
		"mat_9999", &"material_herb", 4, [&"heal"] as Array[StringName]
	)

	GameState._inject_material_for_test(material)

	var inventory: Array[MaterialInstance] = GameState.get_state()["inventory"]
	assert_int(inventory.size()).is_equal(1)
	assert_str(inventory[0].instance_id).is_equal("mat_9999")
	assert_that(inventory[0].material_id).is_equal(&"material_herb")
	assert_int(inventory[0].quality_score).is_equal(4)


func test_テスト専用APIで注入した調合関連フィールドが状態に反映される() -> void:
	GameState._set_recipe_masters_for_test({&"recipe_test": _make_recipe(&"recipe_test")})
	GameState._set_unlocked_recipe_ids_for_test([&"recipe_a", &"recipe_b"] as Array[StringName])
	GameState._set_alchemy_slot_count_for_test(6)

	var state := GameState.get_state()
	assert_bool(GameState._recipe_masters.has(&"recipe_test")).is_true()
	assert_array(state["unlocked_recipe_ids"]).contains_exactly(
		[&"recipe_a", &"recipe_b"] as Array[StringName]
	)
	assert_int(GameState._alchemy_slot_count).is_equal(6)


# 異常系（防御的コピー）


func test_get_state戻り値のpending_productsを変更しても内部状態は変化しない() -> void:
	var state := GameState.get_state()
	var pending: Array[ProductInstance] = state["pending_products"]
	pending.append(
		ProductInstance.new(&"recipe_healing_potion", 3, [] as Array[StringName], 1.0, 2.0)
	)

	var state_after := GameState.get_state()
	assert_int((state_after["pending_products"] as Array[ProductInstance]).size()).is_equal(0)


func test_get_state戻り値のunlocked_recipe_idsを変更しても内部状態は変化しない() -> void:
	var state := GameState.get_state()
	var ids: Array[StringName] = state["unlocked_recipe_ids"]
	ids.append(&"recipe_injected")

	var state_after := GameState.get_state()
	assert_array(state_after["unlocked_recipe_ids"]).contains_exactly(
		[GameBalance.INITIAL_RECIPE_ID] as Array[StringName]
	)


# 境界値


func test_reset_for_testを複数回呼んでも調合関連フィールドが初期状態に戻り続ける() -> void:
	GameState._set_alchemy_slot_count_for_test(99)
	GameState._set_unlocked_recipe_ids_for_test([&"recipe_a"] as Array[StringName])

	GameState.reset_for_test()
	GameState.reset_for_test()

	assert_int(GameState._alchemy_slot_count).is_equal(GameBalance.ALCHEMY_SLOT_COUNT_DEFAULT)
	assert_array(GameState._unlocked_recipe_ids).contains_exactly(
		[GameBalance.INITIAL_RECIPE_ID] as Array[StringName]
	)


func test_load_alchemy_master_dataを複数回呼んでも重複せず同じ件数になる() -> void:
	GameState.load_alchemy_master_data()
	var first_size: int = GameState._recipe_masters.size()

	GameState.load_alchemy_master_data()

	assert_int(GameState._recipe_masters.size()).is_equal(first_size)
	assert_int(first_size).is_greater(0)
