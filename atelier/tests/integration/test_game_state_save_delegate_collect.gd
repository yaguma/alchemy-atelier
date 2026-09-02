extends GdUnitTestSuite


func before_test() -> void:
	GameState.reset_for_test()


# 正常系


func test_reset_for_test直後のcollect_save_dataは初期値を含む() -> void:
	var data := GameStateSaveDelegate.collect_save_data(GameState)

	assert_str(data["current_phase"]).is_equal("garden")
	assert_int(data["gold"]).is_equal(0)
	assert_int(data["current_turn"]).is_equal(1)
	assert_array(data["inventory"] as Array).is_empty()
	assert_array(data["pending_products"] as Array).is_empty()
	assert_str(data["current_daily_order_id"]).is_equal("")


func test_在庫に注入した素材がinventoryへ反映される() -> void:
	var material := MaterialInstance.new("mat_0000", &"herb_common", 3, [&"catalyst"])
	GameState._inject_material_for_test(material)

	var data := GameStateSaveDelegate.collect_save_data(GameState)
	var inventory: Array = data["inventory"]

	assert_int(inventory.size()).is_equal(1)
	var entry: Dictionary = inventory[0]
	assert_str(entry["instance_id"]).is_equal("mat_0000")
	assert_str(entry["material_id"]).is_equal("herb_common")
	assert_int(entry["quality_score"]).is_equal(3)
	assert_array(entry["trait_tags"] as Array).contains_exactly(["catalyst"])


func test_庭に注入した苗がgarden_stateへ反映される() -> void:
	var plant := PlantState.new(1, &"seed_common", 2, false)
	GameState._inject_plant_for_test(plant)

	var data := GameStateSaveDelegate.collect_save_data(GameState)
	var plants: Array = (data["garden_state"] as Dictionary)["plants"]

	assert_int(plants.size()).is_equal(1)
	var entry: Dictionary = plants[0]
	assert_int(entry["slot_index"]).is_equal(1)
	assert_str(entry["seed_id"]).is_equal("seed_common")
	assert_int(entry["grown_turns"]).is_equal(2)
	assert_bool(entry["is_matured"]).is_false()


func test_daily_order_snapshotなしの調合物は空文字列になる() -> void:
	var product := ProductInstance.new(&"healing_potion", 3, [], 10.0, 20.0)
	GameState._inject_pending_product_for_test(product)

	var data := GameStateSaveDelegate.collect_save_data(GameState)
	var products: Array = data["pending_products"]

	assert_int(products.size()).is_equal(1)
	var entry: Dictionary = products[0]
	assert_bool(entry["has_daily_order_snapshot"]).is_false()
	assert_str(entry["daily_order_snapshot_id"]).is_equal("")


func test_daily_order_snapshotありの調合物はIDが反映される() -> void:
	var order := DailyOrderMaster.new()
	order.id = "order_a"
	var product := ProductInstance.new(&"healing_potion", 3, [], 10.0, 20.0)
	product.has_daily_order_snapshot = true
	product.daily_order_snapshot = order
	GameState._inject_pending_product_for_test(product)

	var data := GameStateSaveDelegate.collect_save_data(GameState)
	var entry: Dictionary = (data["pending_products"] as Array)[0]

	assert_bool(entry["has_daily_order_snapshot"]).is_true()
	assert_str(entry["daily_order_snapshot_id"]).is_equal("order_a")


func test_current_daily_orderが設定されている場合はIDが反映される() -> void:
	var order := DailyOrderMaster.new()
	order.id = "order_b"
	GameState._set_current_daily_order_for_test(order)

	var data := GameStateSaveDelegate.collect_save_data(GameState)

	assert_str(data["current_daily_order_id"]).is_equal("order_b")


func test_current_daily_orderが未設定の場合は空文字列になる() -> void:
	GameState._set_current_daily_order_for_test(null)

	var data := GameStateSaveDelegate.collect_save_data(GameState)

	assert_str(data["current_daily_order_id"]).is_equal("")


# 境界値・型検証


func test_current_phaseとcurrent_rank_idはString型で格納される() -> void:
	var data := GameStateSaveDelegate.collect_save_data(GameState)

	assert_bool(data["current_phase"] is String).is_true()
	assert_bool(data["current_rank_id"] is String).is_true()


func test_unlocked_recipe_idsの各要素はString型で格納される() -> void:
	GameState._set_unlocked_recipe_ids_for_test([&"healing_potion", &"antidote"])

	var data := GameStateSaveDelegate.collect_save_data(GameState)
	var ids: Array = data["unlocked_recipe_ids"]

	for id in ids:
		assert_bool(id is String).is_true()
