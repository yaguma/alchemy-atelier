extends GdUnitTestSuite

const AlchemyPreviewPanelScene = preload("res://features/alchemy/ui/alchemy_preview_panel.tscn")


func _make_panel() -> AlchemyPreviewPanel:
	var panel: AlchemyPreviewPanel = auto_free(AlchemyPreviewPanelScene.instantiate())
	add_child(panel)
	return panel


func _find_label(panel: AlchemyPreviewPanel, node_name: String) -> Label:
	return panel.find_child(node_name) as Label


func _find_panel_container(panel: AlchemyPreviewPanel) -> PanelContainer:
	return panel.find_child("PreviewPanel") as PanelContainer


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


# 🟡 garden-alchemy-visual-refresh Planタスク008。プレビュー全体を1枚のカードで囲む新設%PreviewPanel
func test_PreviewPanelにUiThemeの共通カードパネルスタイルボックスが適用されている() -> void:
	var panel := _make_panel()

	var container := _find_panel_container(panel)

	assert_object(container).is_not_null()
	assert_object(container.get_theme_stylebox("panel")).is_same(UiTheme.make_panel_stylebox())


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


## 🔴 コードレビュー指摘対応の回帰テスト。AlchemyPreviewPanelはextends Controlのため、
## _get_minimum_size()をPreviewPanelへ転送する対応をしないと親のVBoxContainer
## （alchemy_screen.tscn）へ常に(0,0)を報告し、行が0高さに潰れて他の行と重なって描画される
## 不具合があった。
func test_get_minimum_sizeがPreviewPanelの内容に応じて0より大きくなる() -> void:
	var panel := _make_panel()

	var min_size := panel.get_combined_minimum_size()

	assert_float(min_size.y).is_greater(0.0)


## 🔴 コードレビュー指摘対応（PR #62フォローアップ）。表示中にshow_preview()が
## 再呼び出しされOrderMatchLabelが非表示→表示に切り替わっても、ForwardingControl経由で
## PreviewPanelのminimum_size_changedを購読しているため、ノードをツリーから外さずに
## get_combined_minimum_size()が追従することを確認する（VBoxContainerは非表示の子を
## 最小サイズ計算から除外するため、表示切替でPreviewPanel全体の必要高さが変わる）。
func test_get_minimum_sizeがOrderMatchLabelの表示切替に追従する() -> void:
	var panel := _make_panel()
	var traits: Array[StringName] = []
	panel.show_preview(1, traits, 1.0, 1.0, false)
	var min_size_before := panel.get_combined_minimum_size()

	panel.show_preview(1, traits, 1.0, 1.0, true)
	var min_size_after := panel.get_combined_minimum_size()

	assert_float(min_size_after.y).is_greater(min_size_before.y)
