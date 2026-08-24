extends GdUnitTestSuite


func before_test() -> void:
	GameState.reset_for_test()


func _make_screen() -> WorkshopScreen:
	var runner := scene_runner("res://features/workshop/ui/workshop_screen.tscn")
	return runner.scene() as WorkshopScreen


func _find_gold_label(screen: WorkshopScreen) -> Label:
	return screen.find_child("GoldLabel", true, false) as Label


func _find_permanent_tab_button(screen: WorkshopScreen) -> Button:
	return screen.find_child("PermanentTabButton", true, false) as Button


func _find_consumable_tab_button(screen: WorkshopScreen) -> Button:
	return screen.find_child("ConsumableTabButton", true, false) as Button


func _find_permanent_list(screen: WorkshopScreen) -> UpgradeItemList:
	return screen.find_child("PermanentList", true, false) as UpgradeItemList


func _find_consumable_list(screen: WorkshopScreen) -> UpgradeItemList:
	return screen.find_child("ConsumableList", true, false) as UpgradeItemList


func _make_upgrade(upgrade_id: StringName, is_permanent: bool, price: int) -> UpgradeMaster:
	var master := UpgradeMaster.new()
	master.id = upgrade_id
	master.name = String(upgrade_id)
	master.is_permanent = is_permanent
	master.price = price
	master.max_purchase_count = 1
	return master


# 正常系（ゴールド表示）


func test_ゴールドが正しく表示される() -> void:
	GameState.load_workshop_master_data()
	GameState._set_gold_for_test(1000)

	var screen := _make_screen()

	assert_str(_find_gold_label(screen).text).is_equal("1000 G")


# 正常系（初期タブ選択）


func test_can_purchase_permanentがfalseの場合初期タブは消耗投資でPermanentTabButtonが非活性になる() -> void:
	GameState.load_workshop_master_data()

	var screen := _make_screen()

	assert_that(screen.get_active_tab()).is_equal(WorkshopScreen.TAB_CONSUMABLE)
	assert_bool(_find_permanent_tab_button(screen).disabled).is_true()


func test_can_purchase_permanentがtrueの場合初期タブは恒久投資でPermanentTabButtonが活性になる() -> void:
	GameState.load_workshop_master_data()
	GameState._set_can_purchase_permanent_for_test(true)

	var screen := _make_screen()

	assert_that(screen.get_active_tab()).is_equal(WorkshopScreen.TAB_PERMANENT)
	assert_bool(_find_permanent_tab_button(screen).disabled).is_false()


# 正常系（タブ切替）


func test_消耗投資タブ押下でリスト表示が切り替わる() -> void:
	GameState.load_workshop_master_data()
	GameState._set_can_purchase_permanent_for_test(true)
	var screen := _make_screen()
	_find_permanent_tab_button(screen).pressed.emit()

	_find_consumable_tab_button(screen).pressed.emit()

	assert_that(screen.get_active_tab()).is_equal(WorkshopScreen.TAB_CONSUMABLE)
	assert_bool(_find_consumable_list(screen).visible).is_true()
	assert_bool(_find_permanent_list(screen).visible).is_false()


func test_can_purchase_permanentがtrueの場合恒久投資タブ押下でタブが切り替わる() -> void:
	GameState.load_workshop_master_data()
	GameState._set_can_purchase_permanent_for_test(true)
	var screen := _make_screen()

	_find_permanent_tab_button(screen).pressed.emit()

	assert_that(screen.get_active_tab()).is_equal(WorkshopScreen.TAB_PERMANENT)


func test_can_purchase_permanentがfalseの場合恒久投資タブ押下が無視される() -> void:
	GameState.load_workshop_master_data()
	var screen := _make_screen()

	_find_permanent_tab_button(screen).pressed.emit()

	assert_that(screen.get_active_tab()).is_equal(WorkshopScreen.TAB_CONSUMABLE)


# 正常系（振り分け）


func test_恒久投資と消耗投資のアイテムが正しい件数で振り分けられる() -> void:
	GameState.load_workshop_master_data()

	var screen := _make_screen()

	assert_int(_find_permanent_list(screen).get_entry_count()).is_equal(3)
	assert_int(_find_consumable_list(screen).get_entry_count()).is_equal(2)


# 正常系（ソート順）


func test_filter_and_sortが価格降順id昇順で並べる() -> void:
	var upgrades: Array[UpgradeMaster] = [
		_make_upgrade(&"upgrade_b", true, 800),
		_make_upgrade(&"upgrade_a", true, 800),
		_make_upgrade(&"upgrade_c", true, 2000),
	]

	var result := WorkshopScreen._filter_and_sort(upgrades, true)

	assert_int(result.size()).is_equal(3)
	assert_that(result[0].id).is_equal(&"upgrade_c")
	assert_that(result[1].id).is_equal(&"upgrade_a")
	assert_that(result[2].id).is_equal(&"upgrade_b")


# 正常系（購入フロー）


func test_ゴールドが十分な状態で消耗投資アイテムを購入するとゴールドが減りGoldLabelが更新される() -> void:
	GameState.load_workshop_master_data()
	GameState._set_gold_for_test(100)
	var screen := _make_screen()

	_find_consumable_list(screen).purchase_requested.emit(&"upgrade_seed_name_purchase_ore")

	assert_int(GameState.get_state()["gold"]).is_equal(50)
	assert_str(_find_gold_label(screen).text).is_equal("50 G")


func test_購入成功後にget_toast_textが購入したアイテム名を含む成功メッセージを返す() -> void:
	GameState.load_workshop_master_data()
	GameState._set_gold_for_test(100)
	var screen := _make_screen()

	_find_consumable_list(screen).purchase_requested.emit(&"upgrade_seed_name_purchase_ore")

	assert_str(screen.get_toast_text()).contains("種の指名買い：鉱石の種")


func test_購入成功後にpurchased_countが1増加し購入済み表示になる() -> void:
	GameState.load_workshop_master_data()
	GameState._set_gold_for_test(1000)
	GameState._set_can_purchase_permanent_for_test(true)
	var screen := _make_screen()

	_find_permanent_list(screen).purchase_requested.emit(&"upgrade_recipe_unlock_mana_tonic")

	assert_int(GameState.get_purchased_count(&"upgrade_recipe_unlock_mana_tonic")).is_equal(1)

	var permanent_list := _find_permanent_list(screen)
	var row := (
		permanent_list.find_child("UpgradeItem_upgrade_recipe_unlock_mana_tonic", true, false)
		as UpgradeItemRow
	)
	assert_str(row.get_purchase_button_text()).is_equal(UpgradeItemRow.LABEL_MAX_REACHED)
	assert_bool(row.is_purchase_button_disabled()).is_true()


# 異常系（購入失敗）


func test_ゴールド不足の状態で購入するとゴールドが変化せず失敗トーストが表示される() -> void:
	GameState.load_workshop_master_data()
	GameState._set_gold_for_test(10)
	var screen := _make_screen()

	screen._on_purchase_requested(&"upgrade_seed_name_purchase_ore")

	assert_int(GameState.get_state()["gold"]).is_equal(10)
	assert_str(screen.get_toast_text()).contains("購入できませんでした")


func test_購入済み上限到達の状態で購入すると状態が変化せず失敗トーストが表示される() -> void:
	GameState.load_workshop_master_data()
	GameState._set_gold_for_test(1000)
	GameState._set_purchased_upgrade_counts_for_test({&"upgrade_seed_name_purchase_ore": 999})
	var screen := _make_screen()

	screen._on_purchase_requested(&"upgrade_seed_name_purchase_ore")

	assert_int(GameState.get_state()["gold"]).is_equal(1000)
	assert_int(GameState.get_purchased_count(&"upgrade_seed_name_purchase_ore")).is_equal(999)
	assert_str(screen.get_toast_text()).contains("購入できませんでした")


func test_恒久投資タブが非活性の状態で恒久投資アイテムを購入要求すると状態が変化せず失敗トーストが表示される() -> void:
	GameState.load_workshop_master_data()
	GameState._set_gold_for_test(1000)
	var screen := _make_screen()

	screen._on_purchase_requested(&"upgrade_recipe_unlock_mana_tonic")

	assert_int(GameState.get_state()["gold"]).is_equal(1000)
	assert_int(GameState.get_purchased_count(&"upgrade_recipe_unlock_mana_tonic")).is_equal(0)
	assert_str(screen.get_toast_text()).contains("購入できませんでした")


# 境界値


func test_upgrade_mastersが空でもクラッシュせず件数0になる() -> void:
	var screen := _make_screen()

	assert_int(_find_permanent_list(screen).get_entry_count()).is_equal(0)
	assert_int(_find_consumable_list(screen).get_entry_count()).is_equal(0)


func test_マスター未登録のupgrade_idで購入要求してもクラッシュせず状態が変化しない() -> void:
	GameState.load_workshop_master_data()
	GameState._set_gold_for_test(1000)
	var screen := _make_screen()

	screen._on_purchase_requested(&"upgrade_nonexistent")

	assert_int(GameState.get_state()["gold"]).is_equal(1000)
	assert_str(screen.get_toast_text()).is_equal("")
