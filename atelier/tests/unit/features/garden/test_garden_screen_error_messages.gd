extends GdUnitTestSuite


func before_test() -> void:
	GameState.reset_for_test()


func _make_seed_master(seed_id: StringName) -> SeedMaster:
	var master := SeedMaster.new()
	master.id = seed_id
	master.name = "薬草の種"
	master.produces_material_id = &"material_herb"
	master.maturity_turns = 3
	master.death_grace_turns = 2
	master.base_quality = 2
	master.trait_pool = [&"trait_fresh"]
	return master


func _make_screen() -> GardenScreen:
	var runner := scene_runner("res://features/garden/ui/garden_screen.tscn")
	return runner.scene() as GardenScreen


# 正常系


func test_slot_fullのエラーコードはユーザー向け文言に変換される() -> void:
	assert_str(GardenScreen.error_message(&"slot_full")).is_equal("庭スロットに空きがありません")


# 異常系


func test_未知のerror_codeはコードをそのままフォールバック表示する() -> void:
	assert_str(GardenScreen.error_message(&"unknown_code")).contains("unknown_code")


# 境界値（回帰確認: 辞書未登録の既存error_codeも引き続きコードを提示する）


func test_seed_not_ownedのエラーコードは引き続きコードを含めて表示される() -> void:
	assert_str(GardenScreen.error_message(&"seed_not_owned")).contains("seed_not_owned")


func test_unknown_seed_idのエラーコードは引き続きコードを含めて表示される() -> void:
	assert_str(GardenScreen.error_message(&"unknown_seed_id")).contains("unknown_seed_id")


# 統合確認（トースト表示、実際のplant_seed()失敗経路から検証する）


func test_庭スロット満杯で植え付け失敗するとユーザー向け文言のトーストが表示される() -> void:
	GameState._set_masters_for_test({&"seed_herb": _make_seed_master(&"seed_herb")}, {})
	GameState._set_seed_inventory_for_test([{"seed_id": &"seed_herb", "count": 1}])
	for slot_index in range(GameBalance.GARDEN_SLOT_COUNT):
		GameState._inject_plant_for_test(PlantState.new(slot_index, &"seed_herb", 0, false))
	var screen := _make_screen()

	GameState.plant_seed(&"seed_herb")

	assert_str(screen.get_toast_text()).is_equal("庭スロットに空きがありません")
	assert_bool(screen.get_toast_text().contains("slot_full")).is_false()
