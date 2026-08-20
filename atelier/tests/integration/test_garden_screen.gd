extends GdUnitTestSuite


func before_test() -> void:
	GameState.reset_for_test()


func _make_seed_master(
	seed_id: StringName, maturity_turns: int = 3, death_grace_turns: int = 2
) -> SeedMaster:
	var master := SeedMaster.new()
	master.id = seed_id
	master.name = "薬草の種"
	master.produces_material_id = &"material_herb"
	master.maturity_turns = maturity_turns
	master.death_grace_turns = death_grace_turns
	master.base_quality = 2
	master.trait_pool = [&"trait_fresh"]
	return master


func _make_screen() -> GardenScreen:
	var runner := scene_runner("res://features/garden/ui/garden_screen.tscn")
	return runner.scene() as GardenScreen


func _find_slot_view(screen: GardenScreen, slot_index: int) -> PlantSlotView:
	var container := screen.find_child("SlotsContainer", true, false) as Container
	return container.get_child(slot_index) as PlantSlotView


func _find_seed_plant_button(screen: GardenScreen, seed_id: StringName) -> Button:
	var row := screen.find_child("SeedEntry_%s" % seed_id, true, false) as Control
	return row.get_node("PlantButton") as Button


# 正常系（種植えフロー）


func test_種植え要求でplant_seedが呼ばれスロット表示が生育中になる() -> void:
	GameState._set_masters_for_test({&"seed_herb": _make_seed_master(&"seed_herb")}, {})
	GameState._set_seed_inventory_for_test([{"seed_id": &"seed_herb", "count": 1}])
	var screen := _make_screen()

	_find_seed_plant_button(screen, &"seed_herb").pressed.emit()

	assert_int(_find_slot_view(screen, 0).get_status()).is_equal(PlantSlotView.Status.GROWING)


# 正常系（ターン終了フロー）


func test_ターン終了ボタンでadvance_turn_growthが呼ばれ生育が進行する() -> void:
	GameState._set_masters_for_test({&"seed_herb": _make_seed_master(&"seed_herb")}, {})
	GameState._inject_plant_for_test(PlantState.new(0, &"seed_herb", 0, false))
	var screen := _make_screen()
	var end_turn_button := screen.find_child("EndTurnButton", true, false) as Button

	end_turn_button.pressed.emit()

	var plant := (GameState.get_state()["garden_state"] as GardenState).plants[0]
	assert_int(plant.grown_turns).is_equal(1)
	assert_int(_find_slot_view(screen, 0).get_status()).is_equal(PlantSlotView.Status.GROWING)


# 正常系（収穫フロー）


func test_収穫ボタンでharvestが呼ばれスロットが空き表示に戻り通知される() -> void:
	GameState._set_masters_for_test({&"seed_herb": _make_seed_master(&"seed_herb")}, {})
	GameState._inject_plant_for_test(PlantState.new(0, &"seed_herb", 3, true))
	var screen := _make_screen()

	_find_slot_view(screen, 0).harvest_pressed.emit(0)

	assert_int(_find_slot_view(screen, 0).get_status()).is_equal(PlantSlotView.Status.EMPTY)
	assert_str(screen.get_toast_text()).is_not_empty()


# 正常系（枯死通知）


func test_plants_witheredシグナル受信でスロット表示と枯死通知が更新される() -> void:
	GameState._set_masters_for_test({&"seed_herb": _make_seed_master(&"seed_herb")}, {})
	GameState._inject_plant_for_test(PlantState.new(0, &"seed_herb", 5, true))
	var screen := _make_screen()

	GameState.advance_turn_growth()

	assert_int(_find_slot_view(screen, 0).get_status()).is_equal(PlantSlotView.Status.EMPTY)
	assert_str(screen.get_toast_text()).is_not_empty()


# 正常系（ショップ導線）


func test_ショップボタン押下でshop_requestedが発行され状態が変化しない() -> void:
	var screen := _make_screen()
	monitor_signals(screen)
	var shop_button := screen.find_child("ShopButton", true, false) as Button
	var before_state := GameState.get_state()

	shop_button.pressed.emit()

	await assert_signal(screen).is_emitted("shop_requested")
	var after_state := GameState.get_state()
	assert_int((after_state["garden_state"] as GardenState).plants.size()).is_equal(
		(before_state["garden_state"] as GardenState).plants.size()
	)
	assert_int(after_state["current_turn"]).is_equal(before_state["current_turn"])


# 異常系


func test_種在庫切れで植え付け失敗するとトーストが表示される() -> void:
	GameState._set_masters_for_test({&"seed_herb": _make_seed_master(&"seed_herb")}, {})
	GameState._set_seed_inventory_for_test([{"seed_id": &"seed_herb", "count": 0}])
	var screen := _make_screen()

	GameState.plant_seed(&"seed_herb")

	assert_str(screen.get_toast_text()).is_not_empty()


# 保守性確認


func test_GardenScreenのソースがexam_stateとin_examを参照していない() -> void:
	var source := FileAccess.get_file_as_string("res://features/garden/ui/garden_screen.gd")

	assert_bool(source.contains("exam_state")).is_false()
	assert_bool(source.contains("in_exam")).is_false()
