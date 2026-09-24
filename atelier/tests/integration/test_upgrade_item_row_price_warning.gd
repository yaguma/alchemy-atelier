extends GdUnitTestSuite

## UpgradeItemRow.setup()が所持ゴールド不足時に価格テキストを警告色にすることを検証する
## （docs/design/atelier-alchemy-core/ui-design/screens/workshop-shop.md L62）


func _make_row() -> UpgradeItemRow:
	var runner := scene_runner("res://features/workshop/ui/upgrade_item_row.tscn")
	return runner.scene() as UpgradeItemRow


func _make_upgrade(price: int, max_purchase_count: int = 1) -> UpgradeMaster:
	var master := UpgradeMaster.new()
	master.id = &"upgrade_test"
	master.name = "テストアイテム"
	master.price = price
	master.max_purchase_count = max_purchase_count
	return master


func _find_price_label(row: UpgradeItemRow) -> Label:
	return row.find_child("PriceLabel", true, false) as Label


# 正常系


func test_所持ゴールドが価格未満の場合価格テキストが警告色になる() -> void:
	var row := _make_row()

	row.setup(_make_upgrade(100), 50, 0, false)

	var price_label := _find_price_label(row)
	assert_bool(price_label.has_theme_color_override("font_color")).is_true()
	assert_object(price_label.get_theme_color("font_color")).is_equal(UiTheme.COLOR_TOAST_WARNING)


func test_所持ゴールドが価格以上の場合価格テキストは通常色のままである() -> void:
	var row := _make_row()

	row.setup(_make_upgrade(100), 150, 0, false)

	var price_label := _find_price_label(row)
	assert_bool(price_label.has_theme_color_override("font_color")).is_false()


func test_ゴールド増減によりsetup再呼び出しで警告色表示が更新される() -> void:
	var row := _make_row()
	var upgrade := _make_upgrade(100)

	row.setup(upgrade, 50, 0, false)
	assert_bool(_find_price_label(row).has_theme_color_override("font_color")).is_true()

	row.setup(upgrade, 150, 0, false)
	assert_bool(_find_price_label(row).has_theme_color_override("font_color")).is_false()


# 境界値


func test_所持ゴールドが価格とちょうど等しい場合は購入可能扱いで警告色にならない() -> void:
	var row := _make_row()

	row.setup(_make_upgrade(100), 100, 0, false)

	assert_bool(_find_price_label(row).has_theme_color_override("font_color")).is_false()
