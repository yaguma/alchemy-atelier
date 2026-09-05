extends GdUnitTestSuite

## BootScene → TitleScreen → SlotSelectScreen → MainSceneという起動フロー全体と、
## タイトル画面・ゲーム中の両方から開いた設定パネルの操作結果がuser://settings.jsonへ
## 永続化されること（かつゲーム進行状態へ影響しないこと）を結合確認する。
## 各画面単体の挙動はtest_boot_scene.gd / test_title_screen.gd /
## test_slot_select_screen.gd / test_settings_panel.gdがカバー済みのため、
## 本ファイルは「画面を跨いで結線されているか」のみを扱う。

const SaveSlotTestHelpers = preload("res://tests/mocks/save_slot_test_helpers.gd")

const BOOT_SCENE_PATH := "res://scenes/boot.tscn"
const TITLE_SCENE_PATH := "res://features/title/ui/title_screen.tscn"
const SLOT_SELECT_SCENE_PATH := "res://features/save_load/ui/slot_select_screen.tscn"
const MAIN_SCENE_PATH := "res://scenes/main.tscn"

const LABEL_START := "はじめる"
const LABEL_SETTINGS := "せってい"

const TEST_SLOT := 0
## SettingsServiceのデフォルト値（1.0）と区別できる値を使う
const CHANGED_BGM_VOLUME := 0.25
const CHANGED_SE_VOLUME := 0.75


func before_test() -> void:
	GameState.reset_for_test()
	SaveService.reset_for_test()
	SaveSlotTestHelpers.cleanup_slots()
	_remove_settings_file()
	SettingsService.reset_for_test()


func after_test() -> void:
	GameState.reset_for_test()
	SaveService.reset_for_test()
	SaveSlotTestHelpers.cleanup_slots()
	_remove_settings_file()
	SettingsService.reset_for_test()


# 正常系: 起動フローの結線


func test_起動フローがBootからMainSceneまで一続きに到達する() -> void:
	var boot := _make_boot()
	var title_path := boot.get_requested_next_scene_path()
	assert_str(title_path).is_equal(TITLE_SCENE_PATH)

	var title := _make_title(title_path)
	_find_button(title, LABEL_START).pressed.emit()
	var slot_select_path := title.get_requested_next_scene_path()
	assert_str(slot_select_path).is_equal(SLOT_SELECT_SCENE_PATH)

	var slot_select := _make_slot_select(slot_select_path)
	slot_select.get_slot_button(TEST_SLOT).pressed.emit()
	assert_bool(slot_select.has_requested_transition()).is_true()
	assert_str(SlotSelectScreen.MAIN_SCENE_PATH).is_equal(MAIN_SCENE_PATH)

	var main := _make_main()
	assert_that(main.get_visible_phase()).is_equal(&"garden")
	assert_int(SaveService.active_slot).is_equal(TEST_SLOT)


func test_BootSceneの遷移先を実際に読み込むとTitleScreenが得られる() -> void:
	var boot := _make_boot()

	var title := _make_title(boot.get_requested_next_scene_path())

	assert_object(title).is_not_null()


func test_TitleScreenの遷移先を実際に読み込むとSlotSelectScreenが得られる() -> void:
	var title := _make_title(TITLE_SCENE_PATH)
	_find_button(title, LABEL_START).pressed.emit()

	var slot_select := _make_slot_select(title.get_requested_next_scene_path())

	assert_object(slot_select).is_not_null()


# 正常系: タイトル画面からの設定操作


func test_タイトルで変更した音量が閉じた後に設定ファイルへ保存される() -> void:
	var title := _make_title(TITLE_SCENE_PATH)
	_find_button(title, LABEL_SETTINGS).pressed.emit()
	var panel := _collect_settings_panels(title)[0]

	_set_slider_value(panel, "BgmSlider", CHANGED_BGM_VOLUME)
	_set_slider_value(panel, "SeSlider", CHANGED_SE_VOLUME)
	_close_panel(panel)

	var saved := _read_saved_settings()
	assert_float(saved.bgm_volume).is_equal(CHANGED_BGM_VOLUME)
	assert_float(saved.se_volume).is_equal(CHANGED_SE_VOLUME)


func test_タイトルで保存した設定が読み直し後のSettingsServiceへ復元される() -> void:
	var title := _make_title(TITLE_SCENE_PATH)
	_find_button(title, LABEL_SETTINGS).pressed.emit()
	_set_slider_value(_collect_settings_panels(title)[0], "BgmSlider", CHANGED_BGM_VOLUME)
	_close_panel(_collect_settings_panels(title)[0])

	SettingsService.reset_for_test()
	SettingsService.load_settings()

	assert_float(SettingsService.get_bgm_volume()).is_equal(CHANGED_BGM_VOLUME)


func test_タイトルでの設定操作はスロット選択状態へ影響しない() -> void:
	var title := _make_title(TITLE_SCENE_PATH)
	_find_button(title, LABEL_SETTINGS).pressed.emit()

	_close_panel(_collect_settings_panels(title)[0])

	assert_int(SaveService.active_slot).is_equal(-1)


# 正常系: ゲーム中の設定操作


func test_歯車ボタン押下で設定パネルが開きフェーズが変化しない() -> void:
	var main := _make_main()
	GameState.set_phase(&"alchemy")
	var before: StringName = GameState.get_state()["current_phase"]

	_press_hud_settings_button(main)
	assert_array(_collect_settings_panels(main)).has_size(1)
	_close_panel(_collect_settings_panels(main)[0])
	await get_tree().process_frame

	assert_that(GameState.get_state()["current_phase"]).is_equal(before)
	assert_that(main.get_visible_phase()).is_equal(&"alchemy")


func test_ゲーム中に変更した設定が閉じた後に設定ファイルへ保存される() -> void:
	var main := _make_main()
	_press_hud_settings_button(main)
	var panel := _collect_settings_panels(main)[0]

	_set_slider_value(panel, "SeSlider", CHANGED_SE_VOLUME)
	_close_panel(panel)

	assert_float(_read_saved_settings().se_volume).is_equal(CHANGED_SE_VOLUME)


# 異常系・境界値


func test_設定パネル開閉の前後でゴールドとターンが変化しない() -> void:
	var main := _make_main()
	var before := GameState.get_state()

	_press_hud_settings_button(main)
	_close_panel(_collect_settings_panels(main)[0])
	await get_tree().process_frame

	var after := GameState.get_state()
	assert_int(after["gold"]).is_equal(before["gold"])
	assert_int(after["current_turn"]).is_equal(before["current_turn"])


func test_タイトルとゲーム中で開いた設定は同じファイルを共有する() -> void:
	var title := _make_title(TITLE_SCENE_PATH)
	_find_button(title, LABEL_SETTINGS).pressed.emit()
	_set_slider_value(_collect_settings_panels(title)[0], "BgmSlider", CHANGED_BGM_VOLUME)
	_close_panel(_collect_settings_panels(title)[0])

	var main := _make_main()
	_press_hud_settings_button(main)
	var panel := _collect_settings_panels(main)[0]

	assert_float(panel.get_bgm_slider_value()).is_equal(CHANGED_BGM_VOLUME)


func test_設定ファイルが無い状態でも起動フローが完走する() -> void:
	assert_bool(FileAccess.file_exists(SettingsService.SETTINGS_PATH)).is_false()

	var boot := _make_boot()
	var title := _make_title(boot.get_requested_next_scene_path())
	_find_button(title, LABEL_START).pressed.emit()
	var slot_select := _make_slot_select(title.get_requested_next_scene_path())
	slot_select.get_slot_button(TEST_SLOT).pressed.emit()

	assert_bool(slot_select.has_requested_transition()).is_true()


# ヘルパー


## Boot/Title/SlotSelectはscene_runner()で起動するとchange_scene_to_fileが
## GdUnit4のテストランナー自身のcurrent_sceneを差し替えてしまうため、
## 手動インスタンス化して遷移抑止フラグを立ててからツリーへ追加する
func _make_boot() -> BootScene:
	var boot := auto_free(load(BOOT_SCENE_PATH).instantiate()) as BootScene
	boot.scene_transition_enabled = false
	add_child(boot)
	return boot


func _make_title(scene_path: String) -> TitleScreen:
	var title := auto_free(load(scene_path).instantiate()) as TitleScreen
	title.scene_transition_enabled = false
	add_child(title)
	return title


func _make_slot_select(scene_path: String) -> SlotSelectScreen:
	var screen := auto_free(load(scene_path).instantiate()) as SlotSelectScreen
	screen.scene_transition_enabled = false
	add_child(screen)
	return screen


func _make_main() -> MainScene:
	return scene_runner(MAIN_SCENE_PATH).scene() as MainScene


func _press_hud_settings_button(main: MainScene) -> void:
	var hud := main.find_child("RankHud", true, false) as RankHud
	hud.get_settings_button().pressed.emit()


func _collect_buttons(node: Node, result: Array[Button] = []) -> Array[Button]:
	for child in node.get_children():
		if child is Button:
			result.append(child as Button)
		_collect_buttons(child, result)
	return result


func _find_button(root: Node, text: String) -> Button:
	for button in _collect_buttons(root):
		if button.text == text:
			return button
	return null


func _collect_settings_panels(root: Node) -> Array[SettingsPanel]:
	var panels: Array[SettingsPanel] = []
	for node in _collect_descendants(root):
		if node is SettingsPanel and not node.is_queued_for_deletion():
			panels.append(node as SettingsPanel)
	return panels


func _collect_descendants(node: Node, result: Array[Node] = []) -> Array[Node]:
	for child in node.get_children():
		result.append(child)
		_collect_descendants(child, result)
	return result


func _set_slider_value(panel: SettingsPanel, slider_name: String, value: float) -> void:
	(panel.find_child(slider_name, true, false) as HSlider).value = value


func _close_panel(panel: SettingsPanel) -> void:
	(panel.find_child("CloseButton", true, false) as Button).pressed.emit()


## 保存済みのuser://settings.jsonを読み戻す（永続化内容の検証用）
func _read_saved_settings() -> SettingsData:
	var file := FileAccess.open(SettingsService.SETTINGS_PATH, FileAccess.READ)
	assert_object(file).is_not_null()
	var raw_text := file.get_as_text()
	file.close()

	var json := JSON.new()
	assert_int(json.parse(raw_text)).is_equal(OK)
	return SettingsCodec.parse(json.data)


func _remove_settings_file() -> void:
	if FileAccess.file_exists(SettingsService.SETTINGS_PATH):
		DirAccess.remove_absolute(SettingsService.SETTINGS_PATH)
