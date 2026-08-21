extends GdUnitTestSuite

const AlchemyPreviewPanelScene = preload("res://features/alchemy/ui/alchemy_preview_panel.tscn")


func _make_panel() -> AlchemyPreviewPanel:
	var panel: AlchemyPreviewPanel = auto_free(AlchemyPreviewPanelScene.instantiate())
	add_child(panel)
	return panel


func _find_label(panel: AlchemyPreviewPanel, node_name: String) -> Label:
	return panel.find_child(node_name) as Label


# 正常系


func test_show_previewで品質と特性と貢献度と報酬が表示に反映される() -> void:
	var panel := _make_panel()
	var traits: Array[StringName] = [&"holy"]

	panel.show_preview(3, traits, 12.5, 8.0, false)

	assert_str(_find_label(panel, "QualityLabel").text).contains("3")
	assert_str(_find_label(panel, "TraitsLabel").text).contains("holy")
	var value_text := _find_label(panel, "ValueLabel").text
	assert_str(value_text).contains("12.5")
	assert_str(value_text).contains("8.0")


func test_order_matchedがtrueのとき指定合致の強調表示が行われる() -> void:
	var panel := _make_panel()
	var traits: Array[StringName] = [&"holy"]

	panel.show_preview(3, traits, 12.5, 8.0, true)

	var order_label := _find_label(panel, "OrderMatchLabel")
	assert_bool(panel.is_order_matched()).is_true()
	assert_bool(order_label.visible).is_true()
	assert_str(order_label.text).is_not_empty()


func test_order_matchedがfalseのとき指定合致の強調表示が行われない() -> void:
	var panel := _make_panel()
	var traits: Array[StringName] = [&"holy"]

	panel.show_preview(3, traits, 12.5, 8.0, false)

	assert_bool(panel.is_order_matched()).is_false()
	assert_bool(_find_label(panel, "OrderMatchLabel").visible).is_false()


func test_発現特性が空でもクラッシュせず特性なし相当の表示になる() -> void:
	var panel := _make_panel()
	var traits: Array[StringName] = []

	panel.show_preview(2, traits, 4.0, 3.0, false)

	assert_str(_find_label(panel, "TraitsLabel").text).contains(
		AlchemyPreviewPanel.TRAITS_NONE_TEXT
	)
	assert_str(_find_label(panel, "QualityLabel").text).contains("2")


func test_複数の発現特性がすべて表示される() -> void:
	var panel := _make_panel()
	var traits: Array[StringName] = [&"holy", &"golden"]

	panel.show_preview(5, traits, 30.0, 20.0, true)

	var traits_text := _find_label(panel, "TraitsLabel").text
	assert_str(traits_text).contains("holy")
	assert_str(traits_text).contains("golden")


# 異常系


func test_show_emptyで全表示がプレースホルダーに戻る() -> void:
	var panel := _make_panel()
	var traits: Array[StringName] = [&"holy"]
	panel.show_preview(3, traits, 12.5, 8.0, true)

	panel.show_empty()

	assert_str(_find_label(panel, "QualityLabel").text).contains(
		AlchemyPreviewPanel.EMPTY_PLACEHOLDER
	)
	assert_str(_find_label(panel, "TraitsLabel").text).contains(
		AlchemyPreviewPanel.EMPTY_PLACEHOLDER
	)
	assert_str(_find_label(panel, "ValueLabel").text).contains(
		AlchemyPreviewPanel.EMPTY_PLACEHOLDER
	)
	assert_bool(_find_label(panel, "OrderMatchLabel").visible).is_false()
	assert_bool(panel.is_order_matched()).is_false()


func test_show_emptyの表示にはshow_previewの数値が残らない() -> void:
	var panel := _make_panel()
	var traits: Array[StringName] = [&"holy"]
	panel.show_preview(3, traits, 12.5, 8.0, true)

	panel.show_empty()

	assert_str(_find_label(panel, "TraitsLabel").text).not_contains("holy")
	assert_str(_find_label(panel, "ValueLabel").text).not_contains("12.5")


# 境界値


func test_品質スコアの下限と上限が表示できる() -> void:
	var panel := _make_panel()
	var traits: Array[StringName] = []

	panel.show_preview(GameBalance.QUALITY_SCORE_MIN, traits, 0.0, 0.0, false)
	assert_str(_find_label(panel, "QualityLabel").text).contains(str(GameBalance.QUALITY_SCORE_MIN))

	panel.show_preview(GameBalance.QUALITY_SCORE_MAX, traits, 0.0, 0.0, false)
	assert_str(_find_label(panel, "QualityLabel").text).contains(str(GameBalance.QUALITY_SCORE_MAX))


func test_貢献度と報酬が0でも表示される() -> void:
	var panel := _make_panel()
	var traits: Array[StringName] = []

	panel.show_preview(1, traits, 0.0, 0.0, false)

	var value_text := _find_label(panel, "ValueLabel").text
	assert_str(value_text).contains("0.0")
	assert_str(value_text).not_contains(AlchemyPreviewPanel.EMPTY_PLACEHOLDER)


func test_指定合致の強調表示はshow_previewの呼び直しで切り替わる() -> void:
	var panel := _make_panel()
	var traits: Array[StringName] = []

	panel.show_preview(1, traits, 1.0, 1.0, true)
	assert_bool(_find_label(panel, "OrderMatchLabel").visible).is_true()

	panel.show_preview(1, traits, 1.0, 1.0, false)
	assert_bool(_find_label(panel, "OrderMatchLabel").visible).is_false()
