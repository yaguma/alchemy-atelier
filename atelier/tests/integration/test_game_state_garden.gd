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


# --- タスク013: plant_seed ---


func _make_seed_master(seed_id: StringName) -> SeedMaster:
	var master := SeedMaster.new()
	master.id = seed_id
	master.produces_material_id = &"mat_%s" % seed_id
	master.maturity_turns = 3
	master.death_grace_turns = 2
	master.base_quality = 2
	master.trait_pool = [&"trait_fresh"]
	return master


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


func test_plant_seedはcountが1の種を植えると0になる() -> void:
	GameState._set_masters_for_test({&"seed_herb": _make_seed_master(&"seed_herb")}, {})
	GameState._seed_inventory = [{"seed_id": &"seed_herb", "count": 1}]

	var result := GameState.plant_seed(&"seed_herb")

	assert_bool(result.success).is_true()
	var seed_inventory: Array[Dictionary] = GameState.get_state()["seed_inventory"]
	assert_int(seed_inventory[0]["count"]).is_equal(0)


func test_plant_seedは庭スロット満杯のとき失敗しシグナルが発行される() -> void:
	GameState._set_masters_for_test({&"seed_herb": _make_seed_master(&"seed_herb")}, {})
	GameState._seed_inventory = [
		{"seed_id": &"seed_herb", "count": GameBalance.GARDEN_SLOT_COUNT + 1}
	]
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
	GameState._seed_inventory = []

	var result := GameState.plant_seed(&"seed_herb")

	assert_bool(result.success).is_false()
	assert_that(result.error_code).is_equal(&"seed_not_owned")
	var state := GameState.get_state()
	assert_int((state["garden_state"] as GardenState).plants.size()).is_equal(0)


func test_plant_seedはcountが0の種をseed_not_ownedで失敗する() -> void:
	GameState._set_masters_for_test({&"seed_herb": _make_seed_master(&"seed_herb")}, {})
	GameState._seed_inventory = [{"seed_id": &"seed_herb", "count": 0}]

	var result := GameState.plant_seed(&"seed_herb")

	assert_bool(result.success).is_false()
	assert_that(result.error_code).is_equal(&"seed_not_owned")


func test_plant_seedは未知のseed_idでunknown_seed_idで失敗する() -> void:
	var result := GameState.plant_seed(&"seed_unknown")

	assert_bool(result.success).is_false()
	assert_that(result.error_code).is_equal(&"unknown_seed_id")


# --- タスク014: harvest ---


func _inject_plant(slot_index: int, grown_turns: int, is_matured: bool) -> void:
	GameState._garden_state.plants.append(
		PlantState.new(slot_index, &"seed_herb", grown_turns, is_matured)
	)


func test_harvestは成熟直後のスロットを収穫しmaterial_harvestedシグナルが発行される() -> void:
	monitor_signals(GameState, false)
	GameState._set_masters_for_test({&"seed_herb": _make_seed_master(&"seed_herb")}, {})
	_inject_plant(0, 3, true)

	var result := GameState.harvest(0)

	assert_bool(result.success).is_true()
	var material: MaterialInstance = result.value
	assert_int(material.quality_score).is_equal(2)
	await assert_signal(GameState).is_emitted(GameState.material_harvested, material, 0)


func test_harvest成功後にinventoryへ追加されgarden_stateから除去される() -> void:
	GameState._set_masters_for_test({&"seed_herb": _make_seed_master(&"seed_herb")}, {})
	_inject_plant(0, 3, true)

	GameState.harvest(0)

	var state := GameState.get_state()
	assert_int((state["inventory"] as Array[MaterialInstance]).size()).is_equal(1)
	assert_int((state["garden_state"] as GardenState).plants.size()).is_equal(0)


func test_harvestは収穫のたびにinstance_idが一意に採番される() -> void:
	GameState._set_masters_for_test({&"seed_herb": _make_seed_master(&"seed_herb")}, {})
	_inject_plant(0, 3, true)
	_inject_plant(1, 3, true)

	var first := GameState.harvest(0)
	var second := GameState.harvest(1)

	var first_material: MaterialInstance = first.value
	var second_material: MaterialInstance = second.value
	assert_that(first_material.instance_id).is_not_equal(second_material.instance_id)


func test_harvestは存在しないslot_indexでslot_not_foundで失敗する() -> void:
	monitor_signals(GameState, false)

	var result := GameState.harvest(99)

	assert_bool(result.success).is_false()
	assert_that(result.error_code).is_equal(&"slot_not_found")
	await assert_signal(GameState).is_emitted(GameState.harvest_failed, 99, &"slot_not_found")


func test_harvestは枯死済みスロットをwitheredで失敗させ状態を変化させない() -> void:
	GameState._set_masters_for_test({&"seed_herb": _make_seed_master(&"seed_herb")}, {})
	_inject_plant(0, 6, true)

	var result := GameState.harvest(0)

	assert_bool(result.success).is_false()
	assert_that(result.error_code).is_equal(&"withered")
	var state := GameState.get_state()
	assert_int((state["garden_state"] as GardenState).plants.size()).is_equal(1)
	assert_int((state["inventory"] as Array[MaterialInstance]).size()).is_equal(0)


func test_harvestは収穫済みスロットを再度収穫するとslot_not_foundで失敗する() -> void:
	GameState._set_masters_for_test({&"seed_herb": _make_seed_master(&"seed_herb")}, {})
	_inject_plant(0, 3, true)
	GameState.harvest(0)

	var result := GameState.harvest(0)

	assert_bool(result.success).is_false()
	assert_that(result.error_code).is_equal(&"slot_not_found")
