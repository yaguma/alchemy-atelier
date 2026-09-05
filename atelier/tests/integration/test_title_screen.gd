extends GdUnitTestSuite

## TitleScreenの2項目メニュー（はじめる／せってい）と、
## 「せってい」のSettingsPanel多重起動防止（FR-407）を検証する。
## SettingsPanel自体の挙動はtest_settings_panel.gdがカバー済みのため、
## 本ファイルは「TitleScreenからの起動・再起動可否」のみを扱う。

const TITLE_SCENE_PATH := "res://features/title/ui/title_screen.tscn"
const SLOT_SELECT_SCENE_PATH := "res://features/save_load/ui/slot_select_screen.tscn"

const LABEL_START := "はじめる"
const LABEL_SETTINGS := "せってい"

## 🔵 FR-406。終了系ボタンが混入していないことを検出するための語彙
const FORBIDDEN_BUTTON_KEYWORDS: Array[String] = ["終了", "やめる", "quit", "exit"]


func before_test() -> void:
	_remove_settings_file()
	SettingsService.reset_for_test()


func after_test() -> void:
	_remove_settings_file()
	SettingsService.reset_for_test()


# 正常系: メニュー構成


func test_ボタンははじめるとせっていの2つのみ存在する() -> void:
	var title := _make_title()

	var texts := _collect_button_texts(title)

	assert_array(texts).contains_exactly_in_any_order([LABEL_START, LABEL_SETTINGS])


func test_終了に相当するボタンが存在しない() -> void:
	var title := _make_title()

	for text in _collect_button_texts(title):
		for keyword in FORBIDDEN_BUTTON_KEYWORDS:
			assert_bool(text.to_lower().contains(keyword.to_lower())).is_false()


func test_初期状態では遷移が要求されていない() -> void:
	var title := _make_title()

	assert_str(title.get_requested_next_scene_path()).is_empty()


# 正常系: はじめる


func test_はじめる押下でスロット選択画面への遷移を要求する() -> void:
	var title := _make_title()

	_find_button(title, LABEL_START).pressed.emit()

	assert_str(title.get_requested_next_scene_path()).is_equal(SLOT_SELECT_SCENE_PATH)


# 正常系: せってい


func test_せってい押下でSettingsPanelが1つ表示される() -> void:
	var title := _make_title()

	_find_button(title, LABEL_SETTINGS).pressed.emit()

	assert_array(_collect_settings_panels(title)).has_size(1)


func test_せってい押下ではシーン遷移が要求されない() -> void:
	var title := _make_title()

	_find_button(title, LABEL_SETTINGS).pressed.emit()

	assert_str(title.get_requested_next_scene_path()).is_empty()


# 異常系・境界値


func test_せっていを連続押下してもSettingsPanelは1つのままである() -> void:
	var title := _make_title()
	var settings_button := _find_button(title, LABEL_SETTINGS)

	settings_button.pressed.emit()
	settings_button.pressed.emit()

	assert_array(_collect_settings_panels(title)).has_size(1)


func test_closed後の再押下で新しいSettingsPanelが生成される() -> void:
	var title := _make_title()
	var settings_button := _find_button(title, LABEL_SETTINGS)
	settings_button.pressed.emit()
	var first_panel: SettingsPanel = _collect_settings_panels(title)[0]
	var first_id := first_panel.get_instance_id()
	_close_panel(first_panel)
	await get_tree().process_frame

	settings_button.pressed.emit()

	var panels := _collect_settings_panels(title)
	assert_array(panels).has_size(1)
	assert_int(panels[0].get_instance_id()).is_not_equal(first_id)


# ヘルパー


## TitleScreenはscene_runner()で起動すると「はじめる」押下時のchange_scene_to_fileが
## GdUnit4のテストランナー自身のcurrent_sceneを差し替えてしまうため、
## boot.gdのテストと同様に手動インスタンス化して遷移抑止フラグを立ててから追加する
func _make_title() -> TitleScreen:
	var title := auto_free(load(TITLE_SCENE_PATH).instantiate()) as TitleScreen
	title.scene_transition_enabled = false
	add_child(title)
	return title


func _collect_buttons(node: Node, result: Array[Button] = []) -> Array[Button]:
	for child in node.get_children():
		if child is Button:
			result.append(child as Button)
		_collect_buttons(child, result)
	return result


func _collect_button_texts(title: TitleScreen) -> Array[String]:
	var texts: Array[String] = []
	for button in _collect_buttons(title):
		texts.append(button.text)
	return texts


func _find_button(title: TitleScreen, text: String) -> Button:
	for button in _collect_buttons(title):
		if button.text == text:
			return button
	return null


func _collect_settings_panels(title: TitleScreen) -> Array[SettingsPanel]:
	var panels: Array[SettingsPanel] = []
	for node in _collect_descendants(title):
		if node is SettingsPanel and not node.is_queued_for_deletion():
			panels.append(node as SettingsPanel)
	return panels


func _collect_descendants(node: Node, result: Array[Node] = []) -> Array[Node]:
	for child in node.get_children():
		result.append(child)
		_collect_descendants(child, result)
	return result


func _close_panel(panel: SettingsPanel) -> void:
	(panel.find_child("CloseButton", true, false) as Button).pressed.emit()


func _remove_settings_file() -> void:
	if FileAccess.file_exists(SettingsService.SETTINGS_PATH):
		DirAccess.remove_absolute(SettingsService.SETTINGS_PATH)
