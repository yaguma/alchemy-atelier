extends GdUnitTestSuite

## MainSceneがRankHud.menu_requestedを受けてPauseMenuをオーバーレイ表示することと、
## その開閉・タイトルへの遷移要求が現在のフェーズ表示・GameState・SaveServiceへ
## 一切影響しないことを検証する（AC-005, AC-011, FR-103, FR-201, FR-402, FR-403, FR-407）。
## 🟡 title-settings-screens-extension Planで、旧test_main_scene_settings_overlay.gd
## （RankHudの歯車ボタンがSettingsPanelを直接開いていた構成）をPauseMenu経由に置き換えた。
## PauseMenu自体の開閉・タイトル遷移要求の単体挙動はtest_pause_menu.gdが、
## SettingsPanel自体の挙動はtest_settings_panel.gdがカバー済みのため、
## 本ファイルは「MainSceneからPauseMenu経由でSettingsPanelまで到達できるか」を扱う。

const SaveSlotTestHelpers = preload("res://tests/mocks/save_slot_test_helpers.gd")

const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const TEST_SLOT := 0


func before_test() -> void:
	GameState.reset_for_test()
	SaveService.reset_for_test()
	SaveSlotTestHelpers.cleanup_slots()
	_remove_settings_file()
	SettingsService.reset_for_test()


func after_test() -> void:
	SaveService.reset_for_test()
	SaveSlotTestHelpers.cleanup_slots()
	_remove_settings_file()
	SettingsService.reset_for_test()


# 正常系


func test_menu_requestedでPauseMenuが1つ表示される() -> void:
	var main := _make_main()

	_request_menu(main)

	assert_array(_collect_pause_menus(main)).has_size(1)


func test_PauseMenu表示中も庭フェーズの画面が可視のままである() -> void:
	var main := _make_main()

	_request_menu(main)

	assert_that(main.get_visible_phase()).is_equal(&"garden")
	assert_bool(_find_screen(main, "GardenScreen").visible).is_true()


func test_PauseMenuの設定押下でSettingsPanelが1つ表示される() -> void:
	var main := _make_main()

	_request_menu(main)
	_press_settings(_collect_pause_menus(main)[0])

	assert_array(_collect_settings_panels(main)).has_size(1)


func test_PauseMenuの開閉前後でcurrent_phaseが変化しない() -> void:
	var main := _make_main()
	GameState.set_phase(&"alchemy")
	var before: StringName = GameState.get_state()["current_phase"]

	_request_menu(main)
	_close_pause_menu(_collect_pause_menus(main)[0])
	await get_tree().process_frame

	assert_that(GameState.get_state()["current_phase"]).is_equal(before)
	assert_that(main.get_visible_phase()).is_equal(&"alchemy")


func test_PauseMenuの開閉ではオートセーブが発生しない() -> void:
	var main := _make_main()
	SaveService.active_slot = TEST_SLOT

	_request_menu(main)
	_close_pause_menu(_collect_pause_menus(main)[0])
	await get_tree().process_frame

	assert_bool(FileAccess.file_exists(SaveService._slot_path(TEST_SLOT))).is_false()


func test_昇格試験中でもPauseMenuが表示される() -> void:
	var main := _make_main()
	GameState._set_exam_state_for_test(ExamState.new(), true)

	_request_menu(main)

	assert_array(_collect_pause_menus(main)).has_size(1)
	assert_bool(bool(GameState.get_state()["in_exam"])).is_true()


func test_タイトルに戻る押下でタイトル画面への遷移が要求される() -> void:
	var main := _make_main()

	_request_menu(main)
	var pause_menu := _collect_pause_menus(main)[0]
	pause_menu.scene_transition_enabled = false
	_press_title(pause_menu)

	assert_str(pause_menu.get_requested_next_scene_path()).is_equal(PauseMenu.TITLE_SCENE_PATH)


# 異常系・境界値


func test_menu_requestedを連続発火してもPauseMenuは1つのままである() -> void:
	var main := _make_main()

	_request_menu(main)
	_request_menu(main)

	assert_array(_collect_pause_menus(main)).has_size(1)


func test_closed後の再要求で新しいPauseMenuが生成される() -> void:
	var main := _make_main()
	_request_menu(main)
	var first_id := _collect_pause_menus(main)[0].get_instance_id()
	_close_pause_menu(_collect_pause_menus(main)[0])
	await get_tree().process_frame

	_request_menu(main)

	var menus := _collect_pause_menus(main)
	assert_array(menus).has_size(1)
	assert_int(menus[0].get_instance_id()).is_not_equal(first_id)


# ヘルパー


func _make_main() -> MainScene:
	var runner := scene_runner(MAIN_SCENE_PATH)
	return runner.scene() as MainScene


## RankHudのメニューボタン押下と同じ経路（menu_requested発行）を再現する
func _request_menu(main: MainScene) -> void:
	var hud := main.find_child("RankHud", true, false) as RankHud
	hud.menu_requested.emit()


func _find_screen(main: MainScene, node_name: String) -> Control:
	return main.find_child(node_name, true, false) as Control


func _collect_pause_menus(main: MainScene) -> Array[PauseMenu]:
	var menus: Array[PauseMenu] = []
	for node in _collect_descendants(main):
		if node is PauseMenu and not node.is_queued_for_deletion():
			menus.append(node as PauseMenu)
	return menus


func _collect_settings_panels(main: MainScene) -> Array[SettingsPanel]:
	var panels: Array[SettingsPanel] = []
	for node in _collect_descendants(main):
		if node is SettingsPanel and not node.is_queued_for_deletion():
			panels.append(node as SettingsPanel)
	return panels


func _collect_descendants(node: Node, result: Array[Node] = []) -> Array[Node]:
	for child in node.get_children():
		result.append(child)
		_collect_descendants(child, result)
	return result


func _press_settings(pause_menu: PauseMenu) -> void:
	(pause_menu.find_child("SettingsButton", true, false) as Button).pressed.emit()


func _press_title(pause_menu: PauseMenu) -> void:
	(pause_menu.find_child("TitleButton", true, false) as Button).pressed.emit()


func _close_pause_menu(pause_menu: PauseMenu) -> void:
	(pause_menu.find_child("CloseButton", true, false) as Button).pressed.emit()


func _remove_settings_file() -> void:
	if FileAccess.file_exists(SettingsService.SETTINGS_PATH):
		DirAccess.remove_absolute(SettingsService.SETTINGS_PATH)
