extends GdUnitTestSuite


func before_test() -> void:
	GameState.reset_for_test()


# 正常系


func test_reset_for_test直後はgarden_stateのplantsが空配列である() -> void:
	var state := GameState.get_state()
	assert_int((state["garden_state"] as GardenState).plants.size()).is_equal(0)


func test_reset_for_test直後はseed_inventoryが初期セットになっている() -> void:
	var state := GameState.get_state()
	var seed_inventory: Array[Dictionary] = state["seed_inventory"]

	assert_int(seed_inventory.size()).is_equal(1)
	assert_that(seed_inventory[0]["seed_id"]).is_equal(GameBalance.INITIAL_SEED_ID)
	assert_int(seed_inventory[0]["count"]).is_equal(GameBalance.INITIAL_SEED_COUNT)


func test_load_garden_master_dataで実データからseed_herbとseed_oreがロードされる() -> void:
	GameState.load_garden_master_data()

	var state := GameState.get_state()
	assert_bool(GameState._seed_masters.has(&"seed_herb")).is_true()
	assert_bool(GameState._seed_masters.has(&"seed_ore")).is_true()
	(
		assert_that((GameState._seed_masters[&"seed_herb"] as SeedMaster).produces_material_id)
		. is_equal(&"material_herb")
	)
	assert_bool(state.has("garden_state")).is_true()


# 異常系（防御的コピー）


func test_get_state戻り値のgarden_state_plantsを変更しても内部状態は変化しない() -> void:
	var state := GameState.get_state()
	(state["garden_state"] as GardenState).plants.append(PlantState.new(0, &"seed_herb"))

	var state_after := GameState.get_state()
	assert_int((state_after["garden_state"] as GardenState).plants.size()).is_equal(0)


func test_get_state戻り値のinventoryを変更しても内部状態は変化しない() -> void:
	var state := GameState.get_state()
	var inventory: Array[MaterialInstance] = state["inventory"]
	inventory.append(MaterialInstance.new("mat_0001", &"material_herb", 3, []))

	var state_after := GameState.get_state()
	assert_int((state_after["inventory"] as Array[MaterialInstance]).size()).is_equal(0)


# 境界値


func test_reset_for_testを複数回連続で呼んでも庭関連フィールドが初期状態に戻り続ける() -> void:
	GameState.reset_for_test()
	GameState.reset_for_test()
	GameState.reset_for_test()

	var state := GameState.get_state()
	var seed_inventory: Array[Dictionary] = state["seed_inventory"]
	assert_int((state["garden_state"] as GardenState).plants.size()).is_equal(0)
	assert_int(seed_inventory.size()).is_equal(1)
	assert_int(seed_inventory[0]["count"]).is_equal(GameBalance.INITIAL_SEED_COUNT)
