extends GdUnitTestSuite

const UpgradeItemRowScene = preload("res://features/workshop/ui/upgrade_item_row.tscn")


func _make_upgrade(
	id: StringName, name: String, price: int, max_purchase_count: int
) -> UpgradeMaster:
	var upgrade := UpgradeMaster.new()
	upgrade.id = id
	upgrade.name = name
	upgrade.price = price
	upgrade.max_purchase_count = max_purchase_count
	return upgrade


func _make_row() -> UpgradeItemRow:
	var row: UpgradeItemRow = auto_free(UpgradeItemRowScene.instantiate())
	add_child(row)
	return row


func _find_label(row: UpgradeItemRow, node_name: String) -> Label:
	return row.find_child(node_name, true, false) as Label


# 正常系


func test_setup後に名称ラベルへupgradeのnameがそのまま表示される() -> void:
	var row := _make_row()
	var upgrade := _make_upgrade(&"slot_up", "調合枠拡張", 100, 1)

	row.setup(upgrade, 200, 0, false)

	assert_str(_find_label(row, "NameLabel").text).is_equal("調合枠拡張")


func test_setup後に価格ラベルがG付き形式で表示される() -> void:
	var row := _make_row()
	var upgrade := _make_upgrade(&"slot_up", "調合枠拡張", 100, 1)

	row.setup(upgrade, 200, 0, false)

	assert_str(_find_label(row, "PriceLabel").text).is_equal("100 G")


func test_購入可能な条件を満たすと購入ボタンが有効かつ購入するラベルになる() -> void:
	var row := _make_row()
	var upgrade := _make_upgrade(&"slot_up", "調合枠拡張", 100, 1)

	row.setup(upgrade, 200, 0, false)

	assert_bool(row.is_purchase_button_disabled()).is_false()
	assert_str(row.get_purchase_button_text()).is_equal(UpgradeItemRow.LABEL_PURCHASE)


func test_所持ゴールドが価格未満だとボタンが無効でゴールド不足表示になる() -> void:
	var row := _make_row()
	var upgrade := _make_upgrade(&"slot_up", "調合枠拡張", 100, 1)

	row.setup(upgrade, 99, 0, false)

	assert_bool(row.is_purchase_button_disabled()).is_true()
	assert_str(row.get_purchase_button_text()).is_equal(UpgradeItemRow.LABEL_GOLD_SHORTAGE)


func test_購入済み回数が上限以上だとボタンが無効で購入済み表示になる() -> void:
	var row := _make_row()
	var upgrade := _make_upgrade(&"slot_up", "調合枠拡張", 100, 1)

	row.setup(upgrade, 200, 1, false)

	assert_bool(row.is_purchase_button_disabled()).is_true()
	assert_str(row.get_purchase_button_text()).is_equal(UpgradeItemRow.LABEL_MAX_REACHED)


func test_lockedがtrueで購入可能条件を満たしていてもボタンは無効だがラベルは購入するのまま() -> void:
	var row := _make_row()
	var upgrade := _make_upgrade(&"slot_up", "調合枠拡張", 100, 1)

	row.setup(upgrade, 200, 0, true)

	assert_bool(row.is_purchase_button_disabled()).is_true()
	assert_str(row.get_purchase_button_text()).is_equal(UpgradeItemRow.LABEL_PURCHASE)


func test_購入ボタン押下でupgrade_idを引数にpurchase_pressedシグナルが発行される() -> void:
	var row := _make_row()
	var upgrade := _make_upgrade(&"slot_up", "調合枠拡張", 100, 1)
	row.setup(upgrade, 200, 0, false)
	monitor_signals(row, false)

	row.find_child("PurchaseButton", true, false).pressed.emit()

	await assert_signal(row).is_emitted("purchase_pressed", [&"slot_up"])


# 異常系


func test_setupを再実行すると前回の無効状態が残らない() -> void:
	var row := _make_row()
	var upgrade := _make_upgrade(&"slot_up", "調合枠拡張", 100, 1)
	row.setup(upgrade, 0, 0, false)

	row.setup(upgrade, 200, 0, false)

	assert_bool(row.is_purchase_button_disabled()).is_false()
	assert_str(row.get_purchase_button_text()).is_equal(UpgradeItemRow.LABEL_PURCHASE)


# 境界値


func test_所持ゴールドが価格とちょうど同額なら購入可能になる() -> void:
	var row := _make_row()
	var upgrade := _make_upgrade(&"slot_up", "調合枠拡張", 100, 1)

	row.setup(upgrade, 100, 0, false)

	assert_bool(row.is_purchase_button_disabled()).is_false()
	assert_str(row.get_purchase_button_text()).is_equal(UpgradeItemRow.LABEL_PURCHASE)


func test_購入済み回数が上限マイナス1なら購入可能になる() -> void:
	var row := _make_row()
	var upgrade := _make_upgrade(&"slot_up", "調合枠拡張", 100, 3)

	row.setup(upgrade, 200, 2, false)

	assert_bool(row.is_purchase_button_disabled()).is_false()
	assert_str(row.get_purchase_button_text()).is_equal(UpgradeItemRow.LABEL_PURCHASE)


func test_購入済み回数が上限ちょうどなら購入済み扱いになる() -> void:
	var row := _make_row()
	var upgrade := _make_upgrade(&"slot_up", "調合枠拡張", 100, 3)

	row.setup(upgrade, 200, 3, false)

	assert_bool(row.is_purchase_button_disabled()).is_true()
	assert_str(row.get_purchase_button_text()).is_equal(UpgradeItemRow.LABEL_MAX_REACHED)


func test_ゴールド不足かつ購入済み上限到達の両方に該当する場合は購入済み表示が優先される() -> void:
	var row := _make_row()
	var upgrade := _make_upgrade(&"slot_up", "調合枠拡張", 100, 1)

	row.setup(upgrade, 0, 1, false)

	assert_bool(row.is_purchase_button_disabled()).is_true()
	assert_str(row.get_purchase_button_text()).is_equal(UpgradeItemRow.LABEL_MAX_REACHED)
