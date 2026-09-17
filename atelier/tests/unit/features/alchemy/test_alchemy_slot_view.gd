extends GdUnitTestSuite

const AlchemySlotViewScene = preload("res://features/alchemy/ui/alchemy_slot_view.tscn")


func _make_view() -> AlchemySlotView:
	var view: AlchemySlotView = auto_free(AlchemySlotViewScene.instantiate())
	add_child(view)
	return view


func _make_material(quality_score: int, trait_tags: Array[StringName]) -> MaterialInstance:
	return MaterialInstance.new("mat_test_1", &"herb_common", quality_score, trait_tags)


func _find_label(view: AlchemySlotView, node_name: String) -> Label:
	return view.find_child(node_name) as Label


func _find_button(view: AlchemySlotView, node_name: String) -> Button:
	return view.find_child(node_name) as Button


func _find_panel(view: AlchemySlotView) -> PanelContainer:
	return view.find_child("SlotPanel") as PanelContainer


# 正常系


func test_setup_emptyで空き状態になりクリアボタンが無効化される() -> void:
	var view := _make_view()

	view.setup_empty(0)

	assert_int(view.get_status()).is_equal(AlchemySlotView.Status.EMPTY)
	assert_bool(_find_button(view, "ClearButton").disabled).is_true()
	assert_str(_find_label(view, "StatusLabel").text).is_equal(
		AlchemySlotView.status_text(AlchemySlotView.Status.EMPTY)
	)
	assert_str(_find_label(view, "StatusLabel").text).is_not_empty()


func test_setupで投入済み状態になりクリアボタンが有効化される() -> void:
	var view := _make_view()
	var tags: Array[StringName] = [&"holy"]

	view.setup(1, _make_material(3, tags))

	assert_int(view.get_status()).is_equal(AlchemySlotView.Status.FILLED)
	assert_bool(_find_button(view, "ClearButton").disabled).is_false()
	assert_str(_find_label(view, "StatusLabel").text).is_equal(
		AlchemySlotView.status_text(AlchemySlotView.Status.FILLED)
	)


func test_投入済み状態では素材IDと品質と特性が表示される() -> void:
	var view := _make_view()
	var tags: Array[StringName] = [&"holy"]

	view.setup(1, _make_material(3, tags))

	var material_text := _find_label(view, "MaterialLabel").text
	assert_str(material_text).contains("herb_common")
	assert_str(material_text).contains("3")
	assert_str(material_text).contains("holy")


func test_投入済み状態でクリアボタン押下時にclear_requestedが発行される() -> void:
	var view := _make_view()
	var tags: Array[StringName] = []
	view.setup(2, _make_material(1, tags))
	monitor_signals(view)

	_find_button(view, "ClearButton").pressed.emit()

	await assert_signal(view).is_emitted("clear_requested", [2])


func test_空きと投入済みで異なる表示色とテキストが割り当てられている() -> void:
	# NFR-201: 色だけに依存せずテキストでも2状態を判別できること
	var empty_color := AlchemySlotView.status_color(AlchemySlotView.Status.EMPTY)
	var filled_color := AlchemySlotView.status_color(AlchemySlotView.Status.FILLED)

	assert_bool(empty_color == filled_color).is_false()
	assert_str(AlchemySlotView.status_text(AlchemySlotView.Status.EMPTY)).is_not_equal(
		AlchemySlotView.status_text(AlchemySlotView.Status.FILLED)
	)


# 🟡 garden-alchemy-visual-refresh Planタスク008。背景が無く無効化されていたルートControlの
# self_modulateではなく、新設%SlotPanel（カード化された前面パネル）へ状態色を適用する
func test_setup_emptyでSlotPanelのself_modulateがEMPTY色になる() -> void:
	var view := _make_view()

	view.setup_empty(0)

	var panel := _find_panel(view)
	assert_object(panel).is_not_null()
	assert_bool(panel.self_modulate == UiTheme.COLOR_ALCHEMY_SLOT_EMPTY).is_true()
	# ルートControl自体の色は状態に依存して変化しないこと（旧実装からの移設確認）
	assert_bool(view.self_modulate == UiTheme.COLOR_ALCHEMY_SLOT_EMPTY).is_false()


func test_setupでSlotPanelのself_modulateがFILLED色になる() -> void:
	var view := _make_view()
	var tags: Array[StringName] = []

	view.setup(0, _make_material(3, tags))

	var panel := _find_panel(view)
	assert_bool(panel.self_modulate == UiTheme.COLOR_ALCHEMY_SLOT_FILLED).is_true()


func test_SlotPanelにUiThemeの共通カードパネルスタイルボックスが適用されている() -> void:
	var view := _make_view()

	var panel := _find_panel(view)

	assert_object(panel.get_theme_stylebox("panel")).is_same(UiTheme.make_panel_stylebox())


# 異常系


func test_空き状態ではクリアボタン押下を試みてもclear_requestedが発行されない() -> void:
	var view := _make_view()
	view.setup_empty(0)
	monitor_signals(view)

	# ボタンはdisabledのため実操作では発行されないが、
	# 内部ガードでも空き状態のクリアを弾くことを検証する
	_find_button(view, "ClearButton").pressed.emit()

	await assert_signal(view).is_not_emitted("clear_requested")


func test_setup後にsetup_emptyを呼ぶと空き状態へ戻り素材表示がクリアされる() -> void:
	var view := _make_view()
	var tags: Array[StringName] = [&"holy"]
	view.setup(1, _make_material(3, tags))

	view.setup_empty(1)

	assert_int(view.get_status()).is_equal(AlchemySlotView.Status.EMPTY)
	assert_str(_find_label(view, "MaterialLabel").text).is_empty()
	assert_bool(_find_button(view, "ClearButton").disabled).is_true()


# 境界値


func test_get_slot_indexがsetupとsetup_emptyに渡した値と一致する() -> void:
	var view := _make_view()
	var tags: Array[StringName] = []

	view.setup_empty(0)
	assert_int(view.get_slot_index()).is_equal(0)

	view.setup(GameBalance.ALCHEMY_SLOT_COUNT_DEFAULT - 1, _make_material(1, tags))
	assert_int(view.get_slot_index()).is_equal(GameBalance.ALCHEMY_SLOT_COUNT_DEFAULT - 1)
