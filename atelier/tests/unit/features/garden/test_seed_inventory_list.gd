extends GdUnitTestSuite

const SeedInventoryListScene = preload("res://features/garden/ui/seed_inventory_list.tscn")


func _make_seed_master(id: StringName, display_name: String) -> SeedMaster:
	var master := SeedMaster.new()
	master.id = id
	master.name = display_name
	return master


func _make_list() -> SeedInventoryList:
	var list: SeedInventoryList = auto_free(SeedInventoryListScene.instantiate())
	add_child(list)
	return list


func _find_row(list: SeedInventoryList, seed_id: StringName) -> Control:
	return list.find_child("SeedEntry_%s" % seed_id, true, false) as Control


func _find_plant_button(list: SeedInventoryList, seed_id: StringName) -> Button:
	var row := _find_row(list, seed_id)
	return row.get_node("PlantButton") as Button


func _find_name_label(list: SeedInventoryList, seed_id: StringName) -> Label:
	var row := _find_row(list, seed_id)
	return row.get_node("NameLabel") as Label


# 正常系
func test_2種類の種在庫を渡すと2件のエントリが表示される() -> void:
	var list := _make_list()

	(
		list
		. setup(
			[{"seed_id": &"seed_herb", "count": 3}, {"seed_id": &"seed_ore", "count": 1}],
			{
				&"seed_herb": _make_seed_master(&"seed_herb", "薬草の種"),
				&"seed_ore": _make_seed_master(&"seed_ore", "鉱石の種"),
			}
		)
	)

	assert_int(list.get_entry_count()).is_equal(2)


# 正常系
func test_エントリの表示名がSeedMasterのnameと一致する() -> void:
	var list := _make_list()

	list.setup(
		[{"seed_id": &"seed_herb", "count": 3}],
		{&"seed_herb": _make_seed_master(&"seed_herb", "薬草の種")}
	)

	assert_str(_find_name_label(list, &"seed_herb").text).is_equal("薬草の種")


# 正常系
func test_植えるボタン押下で対応するseed_idのシグナルが発行される() -> void:
	var list := _make_list()
	(
		list
		. setup(
			[{"seed_id": &"seed_herb", "count": 3}, {"seed_id": &"seed_ore", "count": 2}],
			{
				&"seed_herb": _make_seed_master(&"seed_herb", "薬草の種"),
				&"seed_ore": _make_seed_master(&"seed_ore", "鉱石の種"),
			}
		)
	)
	monitor_signals(list, false)

	_find_plant_button(list, &"seed_ore").pressed.emit()

	await assert_signal(list).is_emitted("seed_plant_requested", [&"seed_ore"])


# 正常系
func test_setupを再実行すると前回のエントリが残らない() -> void:
	var list := _make_list()
	var masters := {
		&"seed_herb": _make_seed_master(&"seed_herb", "薬草の種"),
		&"seed_ore": _make_seed_master(&"seed_ore", "鉱石の種"),
	}
	list.setup(
		[{"seed_id": &"seed_herb", "count": 1}, {"seed_id": &"seed_ore", "count": 1}], masters
	)

	list.setup([{"seed_id": &"seed_ore", "count": 1}], masters)

	assert_int(list.get_entry_count()).is_equal(1)
	assert_object(_find_row(list, &"seed_herb")).is_null()


# 異常系
func test_在庫数0の種は植えるボタンが無効化される() -> void:
	var list := _make_list()

	list.setup(
		[{"seed_id": &"seed_herb", "count": 0}],
		{&"seed_herb": _make_seed_master(&"seed_herb", "薬草の種")}
	)

	assert_bool(_find_plant_button(list, &"seed_herb").disabled).is_true()


# 異常系
func test_在庫数が1以上の種は植えるボタンが有効になる() -> void:
	var list := _make_list()

	list.setup(
		[{"seed_id": &"seed_herb", "count": 1}],
		{&"seed_herb": _make_seed_master(&"seed_herb", "薬草の種")}
	)

	assert_bool(_find_plant_button(list, &"seed_herb").disabled).is_false()


# 異常系
func test_seed_mastersに存在しないseed_idでもクラッシュせずidが表示される() -> void:
	var list := _make_list()

	list.setup([{"seed_id": &"seed_unknown", "count": 2}], {})

	assert_int(list.get_entry_count()).is_equal(1)
	assert_str(_find_name_label(list, &"seed_unknown").text).is_equal("seed_unknown")


# 境界値
func test_空のseed_inventoryでもエントリが0件で正常に表示される() -> void:
	var list := _make_list()

	list.setup([], {})

	assert_int(list.get_entry_count()).is_equal(0)
