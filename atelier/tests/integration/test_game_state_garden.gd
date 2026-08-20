extends GdUnitTestSuite


func before_test() -> void:
	GameState.reset_for_test()


## maturity_turns=3 / death_grace_turns=2 のため grown_turns>=6 で枯死する
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


func _find_plant(garden_state: GardenState, slot_index: int) -> PlantState:
	for plant in garden_state.plants:
		if plant.slot_index == slot_index:
			return plant
	return null


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


func test_advance_turn_growthは未成熟スロットのgrown_turnsを1進める() -> void:
	GameState._set_masters_for_test({&"seed_herb": _make_seed_master(&"seed_herb")}, {})
	_inject_plant(0, 0, false)

	GameState.advance_turn_growth()

	var plant := _find_plant(GameState.get_state()["garden_state"] as GardenState, 0)
	assert_int(plant.grown_turns).is_equal(1)
	assert_bool(plant.is_matured).is_false()


func test_advance_turn_growthはmaturity_turns到達時にis_maturedをtrueへ更新する() -> void:
	GameState._set_masters_for_test({&"seed_herb": _make_seed_master(&"seed_herb")}, {})
	_inject_plant(0, 2, false)

	GameState.advance_turn_growth()

	var plant := _find_plant(GameState.get_state()["garden_state"] as GardenState, 0)
	assert_int(plant.grown_turns).is_equal(3)
	assert_bool(plant.is_matured).is_true()


func test_advance_turn_growthは成熟後の株もgrown_turnsを進め猶予超過株のみ除去する() -> void:
	GameState._set_masters_for_test({&"seed_herb": _make_seed_master(&"seed_herb")}, {})
	_inject_plant(0, 1, false)  # 未成熟
	_inject_plant(1, 4, true)  # 成熟済み・猶予内（進行後 grown=5, waited=2）
	_inject_plant(2, 5, true)  # 成熟済み・進行後に猶予超過（grown=6, waited=3）

	GameState.advance_turn_growth()

	var garden_state := GameState.get_state()["garden_state"] as GardenState
	assert_int(garden_state.plants.size()).is_equal(2)
	assert_int(_find_plant(garden_state, 0).grown_turns).is_equal(2)
	assert_int(_find_plant(garden_state, 1).grown_turns).is_equal(5)
	assert_object(_find_plant(garden_state, 2)).is_null()


func test_advance_turn_growthは枯死除去時にplants_witheredをslot_index一覧付きで発行する() -> void:
	monitor_signals(GameState, false)
	GameState._set_masters_for_test({&"seed_herb": _make_seed_master(&"seed_herb")}, {})
	_inject_plant(1, 5, true)
	_inject_plant(3, 5, true)

	GameState.advance_turn_growth()

	# 🔴 is_emitted()の可変長引数は先頭要素がArrayの場合それ自体を「引数リスト」として解釈するため
	# （GdUnitSignalAssertImpl._wrap_arguments）、配列1個を渡す本シグナルでは二重に包む必要がある
	await assert_signal(GameState).is_emitted(GameState.plants_withered, [[1, 3]])


func test_advance_turn_growthはcurrent_turnを1増やしturn_growth_advancedを発行する() -> void:
	monitor_signals(GameState, false)

	GameState.advance_turn_growth()

	assert_int(GameState.get_state()["current_turn"]).is_equal(2)
	await assert_signal(GameState).is_emitted(GameState.turn_growth_advanced, 2)


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


func test_advance_turn_growthは庭が空でもエラーにならずcurrent_turnだけ進む() -> void:
	GameState._set_masters_for_test({&"seed_herb": _make_seed_master(&"seed_herb")}, {})

	GameState.advance_turn_growth()

	var state := GameState.get_state()
	assert_int((state["garden_state"] as GardenState).plants.size()).is_equal(0)
	assert_int(state["current_turn"]).is_equal(2)


func test_advance_turn_growthはSeedMaster欠落株を除去せずgrown_turnsのみ進める() -> void:
	GameState._set_masters_for_test({}, {})
	_inject_plant(0, 5, true)

	GameState.advance_turn_growth()

	var garden_state := GameState.get_state()["garden_state"] as GardenState
	assert_int(garden_state.plants.size()).is_equal(1)
	assert_int(_find_plant(garden_state, 0).grown_turns).is_equal(6)


# 境界値


func test_advance_turn_growthは猶予ちょうどでは除去せず超過した次ターンで除去する() -> void:
	GameState._set_masters_for_test({&"seed_herb": _make_seed_master(&"seed_herb")}, {})
	_inject_plant(0, 4, true)  # 進行後 grown=5, waited=2（death_grace_turns と同値のため生存）

	GameState.advance_turn_growth()

	assert_int((GameState.get_state()["garden_state"] as GardenState).plants.size()).is_equal(1)

	GameState.advance_turn_growth()  # 進行後 grown=6, waited=3 で枯死

	assert_int((GameState.get_state()["garden_state"] as GardenState).plants.size()).is_equal(0)


func test_reset_for_testを複数回連続で呼んでも庭関連フィールドが初期状態に戻り続ける() -> void:
	GameState.reset_for_test()
	GameState.reset_for_test()
	GameState.reset_for_test()

	var state := GameState.get_state()
	var seed_inventory: Array[Dictionary] = state["seed_inventory"]
	assert_int((state["garden_state"] as GardenState).plants.size()).is_equal(0)
	assert_int(seed_inventory.size()).is_equal(1)
	assert_int(seed_inventory[0]["count"]).is_equal(GameBalance.INITIAL_SEED_COUNT)
