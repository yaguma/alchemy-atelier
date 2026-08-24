extends GdUnitTestSuite

const UpgradeItemListScene = preload("res://features/workshop/ui/upgrade_item_list.tscn")


func _make_upgrade(
	id: StringName, name: String, price: int, max_purchase_count: int
) -> UpgradeMaster:
	var upgrade := UpgradeMaster.new()
	upgrade.id = id
	upgrade.name = name
	upgrade.price = price
	upgrade.max_purchase_count = max_purchase_count
	return upgrade


func _make_list() -> UpgradeItemList:
	var list: UpgradeItemList = auto_free(UpgradeItemListScene.instantiate())
	add_child(list)
	return list


func _find_row(list: UpgradeItemList, upgrade_id: StringName) -> Control:
	return list.find_child("UpgradeItem_%s" % upgrade_id, true, false) as Control


# 正常系
func test_空配列でsetupするとエントリ件数が0になる() -> void:
	var list := _make_list()

	list.setup([], 0, {}, false)

	assert_int(list.get_entry_count()).is_equal(0)


# 正常系
func test_2件の配列でsetupすると渡した順序で2件の行が生成される() -> void:
	var list := _make_list()
	var upgrade_a := _make_upgrade(&"slot_up_a", "調合枠拡張A", 100, 1)
	var upgrade_b := _make_upgrade(&"slot_up_b", "調合枠拡張B", 200, 1)

	list.setup([upgrade_a, upgrade_b], 500, {}, false)

	assert_int(list.get_entry_count()).is_equal(2)
	assert_object(_find_row(list, &"slot_up_a")).is_not_null()
	assert_object(_find_row(list, &"slot_up_b")).is_not_null()


# 正常系
func test_setupを再実行すると前回の行がすべて破棄される() -> void:
	var list := _make_list()
	var upgrade_a := _make_upgrade(&"slot_up_a", "調合枠拡張A", 100, 1)
	var upgrade_b := _make_upgrade(&"slot_up_b", "調合枠拡張B", 200, 1)
	list.setup([upgrade_a, upgrade_b], 500, {}, false)

	list.setup([upgrade_b], 500, {}, false)

	assert_int(list.get_entry_count()).is_equal(1)
	assert_object(_find_row(list, &"slot_up_a")).is_null()
	assert_object(_find_row(list, &"slot_up_b")).is_not_null()


# 正常系
func test_行の購入ボタン押下でpurchase_requestedシグナルが対応するupgrade_idで発行される() -> void:
	var list := _make_list()
	var upgrade := _make_upgrade(&"slot_up", "調合枠拡張", 100, 1)
	list.setup([upgrade], 500, {}, false)
	monitor_signals(list, false)

	var button := _find_row(list, &"slot_up").find_child("PurchaseButton", true, false) as Button
	button.pressed.emit()

	await assert_signal(list).is_emitted("purchase_requested", [&"slot_up"])


# 異常系
func test_lockedがtrueだと全行の購入ボタンが強制disabledになる() -> void:
	var list := _make_list()
	var upgrade_a := _make_upgrade(&"slot_up_a", "調合枠拡張A", 100, 1)
	var upgrade_b := _make_upgrade(&"slot_up_b", "調合枠拡張B", 200, 1)

	list.setup([upgrade_a, upgrade_b], 500, {}, true)

	var row_a := _find_row(list, &"slot_up_a") as UpgradeItemRow
	var row_b := _find_row(list, &"slot_up_b") as UpgradeItemRow
	assert_bool(row_a.is_purchase_button_disabled()).is_true()
	assert_bool(row_b.is_purchase_button_disabled()).is_true()


# 境界値
func test_ready前にsetupを呼んでもクラッシュせずready後に反映される() -> void:
	var list: UpgradeItemList = auto_free(UpgradeItemListScene.instantiate())
	var upgrade := _make_upgrade(&"slot_up", "調合枠拡張", 100, 1)

	list.setup([upgrade], 500, {}, false)
	add_child(list)

	assert_int(list.get_entry_count()).is_equal(1)
	assert_object(_find_row(list, &"slot_up")).is_not_null()
