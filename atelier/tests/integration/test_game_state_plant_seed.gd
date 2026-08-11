extends GdUnitTestSuite


func before_test() -> void:
	GameState.reset_for_test()


func _make_seed_master(seed_id: StringName) -> SeedMaster:
	var master := SeedMaster.new()
	master.id = seed_id
	master.produces_material_id = &"mat_%s" % seed_id
	master.maturity_turns = 3
	master.death_grace_turns = 2
	master.base_quality = 2
	master.trait_pool = [&"trait_fresh"]
	return master


# 正常系


func test_plant_seedは空きスロットと種在庫ありで成功しseed_plantedシグナルが発行される() -> void:
	monitor_signals(GameState, false)
	GameState._set_masters_for_test({&"seed_herb": _make_seed_master(&"seed_herb")}, {})

	var result := GameState.plant_seed(&"seed_herb")

	assert_bool(result.success).is_true()
	await assert_signal(GameState).is_emitted(GameState.seed_planted, 0, &"seed_herb")


func test_plant_seed成功後にgarden_stateとseed_inventoryが更新される() -> void:
	GameState._set_masters_for_test({&"seed_herb": _make_seed_master(&"seed_herb")}, {})

	GameState.plant_seed(&"seed_herb")

	var state := GameState.get_state()
	var seed_inventory: Array[Dictionary] = state["seed_inventory"]
	assert_int((state["garden_state"] as GardenState).plants.size()).is_equal(1)
	assert_int(seed_inventory[0]["count"]).is_equal(GameBalance.INITIAL_SEED_COUNT - 1)


# 境界値


func test_plant_seedはcountが1の種を植えると0になる() -> void:
	GameState._set_masters_for_test({&"seed_herb": _make_seed_master(&"seed_herb")}, {})
	GameState._set_seed_inventory_for_test([{"seed_id": &"seed_herb", "count": 1}])

	var result := GameState.plant_seed(&"seed_herb")

	assert_bool(result.success).is_true()
	var seed_inventory: Array[Dictionary] = GameState.get_state()["seed_inventory"]
	assert_int(seed_inventory[0]["count"]).is_equal(0)


# 異常系


func test_plant_seedは庭スロット満杯のとき失敗しシグナルが発行される() -> void:
	GameState._set_masters_for_test({&"seed_herb": _make_seed_master(&"seed_herb")}, {})
	GameState._set_seed_inventory_for_test(
		[{"seed_id": &"seed_herb", "count": GameBalance.GARDEN_SLOT_COUNT + 1}]
	)
	for i in range(GameBalance.GARDEN_SLOT_COUNT):
		GameState.plant_seed(&"seed_herb")

	monitor_signals(GameState, false)
	var result := GameState.plant_seed(&"seed_herb")

	assert_bool(result.success).is_false()
	assert_that(result.error_code).is_equal(&"slot_full")
	await assert_signal(GameState).is_emitted(
		GameState.plant_seed_failed, &"seed_herb", &"slot_full"
	)
	var state := GameState.get_state()
	assert_int((state["garden_state"] as GardenState).plants.size()).is_equal(
		GameBalance.GARDEN_SLOT_COUNT
	)


func test_plant_seedは在庫にない種をPlanting_plantを呼ばずにseed_not_ownedで失敗する() -> void:
	GameState._set_masters_for_test({&"seed_herb": _make_seed_master(&"seed_herb")}, {})
	GameState._set_seed_inventory_for_test([])

	var result := GameState.plant_seed(&"seed_herb")

	assert_bool(result.success).is_false()
	assert_that(result.error_code).is_equal(&"seed_not_owned")
	var state := GameState.get_state()
	assert_int((state["garden_state"] as GardenState).plants.size()).is_equal(0)


func test_plant_seedはcountが0の種をseed_not_ownedで失敗する() -> void:
	GameState._set_masters_for_test({&"seed_herb": _make_seed_master(&"seed_herb")}, {})
	GameState._set_seed_inventory_for_test([{"seed_id": &"seed_herb", "count": 0}])

	var result := GameState.plant_seed(&"seed_herb")

	assert_bool(result.success).is_false()
	assert_that(result.error_code).is_equal(&"seed_not_owned")


func test_plant_seedは未知のseed_idでunknown_seed_idで失敗する() -> void:
	var result := GameState.plant_seed(&"seed_unknown")

	assert_bool(result.success).is_false()
	assert_that(result.error_code).is_equal(&"unknown_seed_id")
