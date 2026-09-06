extends GdUnitTestSuite

## PauseMenu（閉じる／設定／タイトルに戻る）単体の開閉・SettingsPanel多重起動防止・
## タイトルへの遷移要求を検証する。MainSceneからの結線（RankHud.menu_requested経由）は
## test_main_scene_pause_menu.gdが、SettingsPanel自体の挙動はtest_settings_panel.gdが
## カバー済みのため、本ファイルは「PauseMenu単体としての振る舞い」のみを扱う。

const PAUSE_MENU_SCENE_PATH := "res://shared/ui/pause_menu.tscn"

## 🔴 GDScriptのラムダはローカル変数を値渡しでキャプチャするため、ラムダ内でのインクリメントは
## 呼び出し元スコープへ反映されない。メンバ変数へカウントすることで確実に観測する
var _closed_count := 0


func before_test() -> void:
	_remove_settings_file()
	SettingsService.reset_for_test()
	_closed_count = 0


func _on_closed_for_test() -> void:
	_closed_count += 1


func after_test() -> void:
	_remove_settings_file()
	SettingsService.reset_for_test()


# 正常系: メニュー構成


func test_初期状態では遷移が要求されていない() -> void:
	var menu := _make_pause_menu()

	assert_str(menu.get_requested_next_scene_path()).is_empty()


func test_ボタンは閉じる設定タイトルに戻るの3つ存在する() -> void:
	var menu := _make_pause_menu()

	var texts := _collect_button_texts(menu)

	assert_array(texts).contains_exactly_in_any_order(["閉じる", "せってい", "タイトルに戻る"])


# 正常系: 閉じる


func test_閉じる押下でclosedシグナルが発行される() -> void:
	var menu := _make_pause_menu()
	menu.closed.connect(_on_closed_for_test)

	_find_button(menu, "閉じる").pressed.emit()

	assert_int(_closed_count).is_equal(1)


# 正常系: 設定


func test_せってい押下でSettingsPanelが1つ表示される() -> void:
	var menu := _make_pause_menu()

	_find_button(menu, "せってい").pressed.emit()

	assert_array(_collect_settings_panels(menu)).has_size(1)


func test_せってい押下ではシーン遷移が要求されない() -> void:
	var menu := _make_pause_menu()

	_find_button(menu, "せってい").pressed.emit()

	assert_str(menu.get_requested_next_scene_path()).is_empty()


func test_せっていを連続押下してもSettingsPanelは1つのままである() -> void:
	var menu := _make_pause_menu()
	var settings_button := _find_button(menu, "せってい")

	settings_button.pressed.emit()
	settings_button.pressed.emit()

	assert_array(_collect_settings_panels(menu)).has_size(1)


# 正常系: タイトルに戻る


func test_タイトルに戻る押下でタイトル画面への遷移を要求する() -> void:
	var menu := _make_pause_menu()

	_find_button(menu, "タイトルに戻る").pressed.emit()

	assert_str(menu.get_requested_next_scene_path()).is_equal(PauseMenu.TITLE_SCENE_PATH)


# ヘルパー


## PauseMenuはscene_transition_enabled=falseにしないと、タイトルに戻る押下時の
## change_scene_to_fileがGdUnit4のテストランナー自身のcurrent_sceneを差し替えてしまう
## （title_screen.gd/boot.gdのテストと同方針）
func _make_pause_menu() -> PauseMenu:
	var menu := auto_free(load(PAUSE_MENU_SCENE_PATH).instantiate()) as PauseMenu
	menu.scene_transition_enabled = false
	add_child(menu)
	return menu


func _collect_buttons(node: Node, result: Array[Button] = []) -> Array[Button]:
	for child in node.get_children():
		if child is Button:
			result.append(child as Button)
		_collect_buttons(child, result)
	return result


func _collect_button_texts(menu: PauseMenu) -> Array[String]:
	var texts: Array[String] = []
	for button in _collect_buttons(menu):
		texts.append(button.text)
	return texts


func _find_button(menu: PauseMenu, text: String) -> Button:
	for button in _collect_buttons(menu):
		if button.text == text:
			return button
	return null


func _collect_settings_panels(menu: PauseMenu) -> Array[SettingsPanel]:
	var panels: Array[SettingsPanel] = []
	for node in _collect_descendants(menu):
		if node is SettingsPanel and not node.is_queued_for_deletion():
			panels.append(node as SettingsPanel)
	return panels


func _collect_descendants(node: Node, result: Array[Node] = []) -> Array[Node]:
	for child in node.get_children():
		result.append(child)
		_collect_descendants(child, result)
	return result


func _remove_settings_file() -> void:
	if FileAccess.file_exists(SettingsService.SETTINGS_PATH):
		DirAccess.remove_absolute(SettingsService.SETTINGS_PATH)
