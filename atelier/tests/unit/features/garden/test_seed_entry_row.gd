extends GdUnitTestSuite

## garden-alchemy-visual-refresh Plan タスク007: SeedEntryRowのカード化（PanelContainer化）を検証する。

const SeedEntryRowScene = preload("res://features/garden/ui/seed_entry_row.tscn")


func _make_row() -> SeedEntryRow:
	var row: SeedEntryRow = auto_free(SeedEntryRowScene.instantiate())
	add_child(row)
	return row


# 正常系


func test_ルートのpanelスタイルボックスがmake_panel_styleboxと同一である() -> void:
	var row := _make_row()

	assert_object(row.get_theme_stylebox("panel")).is_equal(UiTheme.make_panel_stylebox())


func test_PlantButtonにNEARESTのtexture_filterが設定されている() -> void:
	var row := _make_row()
	var button := row.find_child("PlantButton", true, false) as Button

	assert_int(button.texture_filter).is_equal(CanvasItem.TEXTURE_FILTER_NEAREST)


func test_setupで表示名と在庫数が反映される() -> void:
	var row := _make_row()

	row.setup(&"seed_herb", "薬草の種", 3)

	var name_label := row.find_child("NameLabel", true, false) as Label
	var count_label := row.find_child("CountLabel", true, false) as Label
	assert_str(name_label.text).is_equal("薬草の種")
	assert_str(count_label.text).is_equal("x3")


func test_植えるボタン押下でplant_pressedがseed_id付きで発行される() -> void:
	var row := _make_row()
	row.setup(&"seed_herb", "薬草の種", 3)
	monitor_signals(row)

	(row.find_child("PlantButton", true, false) as Button).pressed.emit()

	await assert_signal(row).is_emitted("plant_pressed", [&"seed_herb"])


# 異常系


func test_在庫数0では植えるボタンが無効化される() -> void:
	var row := _make_row()

	row.setup(&"seed_herb", "薬草の種", 0)

	var button := row.find_child("PlantButton", true, false) as Button
	assert_bool(button.disabled).is_true()
