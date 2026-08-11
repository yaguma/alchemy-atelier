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


func _inject_plant(slot_index: int, grown_turns: int, is_matured: bool) -> void:
	GameState._inject_plant_for_test(
		PlantState.new(slot_index, &"seed_herb", grown_turns, is_matured)
	)


# 正常系


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


# 異常系（防御的コピー）


func test_harvestの戻り値のMaterialInstanceを変更してもinventory内部状態は変化しない() -> void:
	GameState._set_masters_for_test({&"seed_herb": _make_seed_master(&"seed_herb")}, {})
	_inject_plant(0, 3, true)

	var result := GameState.harvest(0)
	var material: MaterialInstance = result.value
	material.quality_score = 999

	var state := GameState.get_state()
	var inventory: Array[MaterialInstance] = state["inventory"]
	assert_int(inventory[0].quality_score).is_not_equal(999)


# 異常系


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


func test_harvestは該当seed_idのSeedMasterが見つからない場合master_data_missingで失敗する() -> void:
	monitor_signals(GameState, false)
	GameState._set_masters_for_test({}, {})
	_inject_plant(0, 3, true)

	var result := GameState.harvest(0)

	assert_bool(result.success).is_false()
	assert_that(result.error_code).is_equal(&"master_data_missing")
	await assert_signal(GameState).is_emitted(GameState.harvest_failed, 0, &"master_data_missing")
