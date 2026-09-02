extends GdUnitTestSuite


func before_test() -> void:
	GameState.reset_for_test()


func after_test() -> void:
	GameState.reset_for_test()


func _make_daily_order(id: String) -> DailyOrderMaster:
	var order := DailyOrderMaster.new()
	order.id = id
	return order


## _daily_order_mastersを注入するテスト専用APIが存在しないため直接代入する
## （GDScriptはprivate-by-conventionのフィールドへの外部アクセスを許す）
func _set_daily_order_masters(orders: Array[DailyOrderMaster]) -> void:
	GameState._daily_order_masters = orders


# 正常系


func test_収集したデータを復元すると主要フィールドが一致する() -> void:
	GameState._set_gold_for_test(1234)
	GameState._inject_material_for_test(
		MaterialInstance.new("mat_0007", &"herb_common", 4, [&"catalyst"])
	)
	GameState._inject_plant_for_test(PlantState.new(2, &"seed_common", 1, true))
	GameState._set_unlocked_recipe_ids_for_test([&"healing_potion", &"antidote"])
	GameState._set_current_rank_id_for_test(&"F")
	GameState._set_demotion_count_for_test(1)
	var data := GameStateSaveDelegate.collect_save_data(GameState)

	GameState.reset_for_test()
	GameStateSaveDelegate.restore_save_data(GameState, data)

	var state := GameState.get_state()
	assert_int(state["gold"]).is_equal(1234)
	assert_int(state["current_turn"]).is_equal(1)
	assert_str(String(state["current_phase"])).is_equal("garden")
	assert_str(String(state["current_rank_id"])).is_equal("F")
	assert_int(state["demotion_count"]).is_equal(1)

	var inventory: Array = state["inventory"]
	assert_int(inventory.size()).is_equal(1)
	var material: MaterialInstance = inventory[0]
	assert_str(material.instance_id).is_equal("mat_0007")
	assert_str(String(material.material_id)).is_equal("herb_common")
	assert_int(material.quality_score).is_equal(4)
	assert_array(material.trait_tags).contains_exactly([&"catalyst"])

	var garden: GardenState = state["garden_state"]
	assert_int(garden.plants.size()).is_equal(1)
	assert_int(garden.plants[0].slot_index).is_equal(2)
	assert_str(String(garden.plants[0].seed_id)).is_equal("seed_common")
	assert_int(garden.plants[0].grown_turns).is_equal(1)
	assert_bool(garden.plants[0].is_matured).is_true()

	assert_array(state["unlocked_recipe_ids"]).contains_exactly([&"healing_potion", &"antidote"])


func test_current_daily_order_idが既知IDなら該当マスターが復元される() -> void:
	_set_daily_order_masters([_make_daily_order("order_a"), _make_daily_order("order_b")])
	var data := GameStateSaveDelegate.collect_save_data(GameState)
	data["current_daily_order_id"] = "order_b"

	GameStateSaveDelegate.restore_save_data(GameState, data)

	assert_object(GameState._current_daily_order).is_not_null()
	assert_str(GameState._current_daily_order.id).is_equal("order_b")


func test_pending_productsのdaily_order_snapshotがIDから復元される() -> void:
	var order := _make_daily_order("order_c")
	_set_daily_order_masters([order])
	var product := ProductInstance.new(&"healing_potion", 3, [&"sweet"], 10.0, 20.0)
	product.has_daily_order_snapshot = true
	product.daily_order_snapshot = order
	GameState._inject_pending_product_for_test(product)
	var data := GameStateSaveDelegate.collect_save_data(GameState)

	GameStateSaveDelegate.restore_save_data(GameState, data)

	var restored: ProductInstance = GameState._pending_products[0]
	assert_str(String(restored.recipe_id)).is_equal("healing_potion")
	assert_int(restored.quality_score).is_equal(3)
	assert_array(restored.activated_traits).contains_exactly([&"sweet"])
	assert_float(restored.contribution).is_equal(10.0)
	assert_float(restored.reward).is_equal(20.0)
	assert_bool(restored.has_daily_order_snapshot).is_true()
	assert_object(restored.daily_order_snapshot).is_not_null()
	assert_str(restored.daily_order_snapshot.id).is_equal("order_c")


func test_last_rank_outcomeとlast_exam_outcomeがenumへ復元される() -> void:
	var data := GameStateSaveDelegate.collect_save_data(GameState)
	data["last_rank_outcome"] = int(RankOutcome.Value.DEMOTION)
	data["last_exam_outcome"] = int(ExamOutcome.Value.SUCCESS)

	GameStateSaveDelegate.restore_save_data(GameState, data)

	assert_int(GameState._last_rank_outcome).is_equal(RankOutcome.Value.DEMOTION)
	assert_int(GameState._last_exam_outcome).is_equal(ExamOutcome.Value.SUCCESS)


func test_ランク状態と試験状態が復元される() -> void:
	var rank_state := RankState.new()
	rank_state.quota = 12.5
	rank_state.elapsed_turn = 3
	GameState._set_rank_state_for_test(rank_state)
	var exam_state := ExamState.new()
	exam_state.exam_quota = 4.0
	exam_state.exam_quota_max = 8.0
	exam_state.exam_elapsed_turn = 2
	exam_state.exam_turn_limit = 5
	GameState._set_exam_state_for_test(exam_state, true)
	var data := GameStateSaveDelegate.collect_save_data(GameState)

	GameState.reset_for_test()
	GameStateSaveDelegate.restore_save_data(GameState, data)

	assert_float(GameState._rank_state.quota).is_equal(12.5)
	assert_int(GameState._rank_state.elapsed_turn).is_equal(3)
	assert_bool(GameState._rank_state_initialized).is_true()
	assert_bool(GameState._in_exam).is_true()
	assert_float(GameState._exam_state.exam_quota).is_equal(4.0)
	assert_float(GameState._exam_state.exam_quota_max).is_equal(8.0)
	assert_int(GameState._exam_state.exam_elapsed_turn).is_equal(2)
	assert_int(GameState._exam_state.exam_turn_limit).is_equal(5)


func test_種インベントリと工房購入数が復元される() -> void:
	var seed_inventory: Array[Dictionary] = [{"seed_id": &"seed_rare", "count": 7}]
	GameState._set_seed_inventory_for_test(seed_inventory)
	GameState._set_purchased_upgrade_counts_for_test({&"slot_up": 2})
	var data := GameStateSaveDelegate.collect_save_data(GameState)

	GameState.reset_for_test()
	GameStateSaveDelegate.restore_save_data(GameState, data)

	assert_int(GameState._seed_inventory.size()).is_equal(1)
	assert_str(String(GameState._seed_inventory[0]["seed_id"])).is_equal("seed_rare")
	assert_int(GameState._seed_inventory[0]["count"]).is_equal(7)
	assert_int(GameState.get_purchased_count(&"slot_up")).is_equal(2)


# 異常系


func test_current_daily_order_idが空文字列なら復元後はnullになる() -> void:
	_set_daily_order_masters([_make_daily_order("order_a")])
	var data := GameStateSaveDelegate.collect_save_data(GameState)
	data["current_daily_order_id"] = ""

	GameStateSaveDelegate.restore_save_data(GameState, data)

	assert_object(GameState._current_daily_order).is_null()


func test_current_daily_order_idが未知IDでも例外を投げずnullになる() -> void:
	_set_daily_order_masters([_make_daily_order("order_a")])
	var data := GameStateSaveDelegate.collect_save_data(GameState)
	data["current_daily_order_id"] = "order_removed"

	GameStateSaveDelegate.restore_save_data(GameState, data)

	assert_object(GameState._current_daily_order).is_null()


func test_daily_order_snapshot_idが未知IDでも例外を投げずnullになる() -> void:
	var order := _make_daily_order("order_c")
	var product := ProductInstance.new(&"healing_potion", 3, [], 10.0, 20.0)
	product.has_daily_order_snapshot = true
	product.daily_order_snapshot = order
	GameState._inject_pending_product_for_test(product)
	var data := GameStateSaveDelegate.collect_save_data(GameState)

	# マスターデータ側からorder_cが消えたケースを模す
	_set_daily_order_masters([])
	GameStateSaveDelegate.restore_save_data(GameState, data)

	var restored: ProductInstance = GameState._pending_products[0]
	assert_object(restored.daily_order_snapshot).is_null()


# 境界値・防御的コピー


func test_JSON往復でfloat化された数値もint型へ復元される() -> void:
	GameState._set_gold_for_test(500)
	GameState._inject_material_for_test(MaterialInstance.new("mat_0000", &"herb_common", 3, []))
	var parsed: Variant = JSON.parse_string(
		JSON.stringify(GameStateSaveDelegate.collect_save_data(GameState))
	)

	GameState.reset_for_test()
	GameStateSaveDelegate.restore_save_data(GameState, parsed as Dictionary)

	assert_int(GameState._gold).is_equal(500)
	assert_int(GameState._current_turn).is_equal(1)
	assert_int(GameState._inventory[0].quality_score).is_equal(3)
	assert_int(GameState._material_instance_seq).is_equal(0)


func test_復元後にdata側の配列を変更してもstateへ影響しない() -> void:
	GameState._inject_material_for_test(MaterialInstance.new("mat_0000", &"herb_common", 3, []))
	GameState._inject_plant_for_test(PlantState.new(0, &"seed_common"))
	var data := GameStateSaveDelegate.collect_save_data(GameState)

	GameStateSaveDelegate.restore_save_data(GameState, data)
	(data["inventory"] as Array).clear()
	((data["garden_state"] as Dictionary)["plants"] as Array).clear()

	assert_int(GameState._inventory.size()).is_equal(1)
	assert_int(GameState._garden_state.plants.size()).is_equal(1)
