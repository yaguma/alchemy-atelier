extends GdUnitTestSuite

const SCENE_PATH := "res://shared/ui/settings_panel.tscn"


func before_test() -> void:
	_remove_settings_file()
	SettingsService.reset_for_test()


func after_test() -> void:
	_remove_settings_file()
	SettingsService.reset_for_test()


func _remove_settings_file() -> void:
	if FileAccess.file_exists(SettingsService.SETTINGS_PATH):
		DirAccess.remove_absolute(SettingsService.SETTINGS_PATH)


func _make_runner() -> GdUnitSceneRunner:
	return scene_runner(SCENE_PATH)


func _make_panel() -> SettingsPanel:
	return _make_runner().scene() as SettingsPanel


func _find_bgm_slider(panel: SettingsPanel) -> HSlider:
	return panel.find_child("BgmSlider", true, false) as HSlider


func _find_se_slider(panel: SettingsPanel) -> HSlider:
	return panel.find_child("SeSlider", true, false) as HSlider


func _find_window_mode_toggle(panel: SettingsPanel) -> CheckButton:
	return panel.find_child("WindowModeToggle", true, false) as CheckButton


func _find_reduced_effects_toggle(panel: SettingsPanel) -> CheckButton:
	return panel.find_child("ReducedEffectsToggle", true, false) as CheckButton


func _find_close_button(panel: SettingsPanel) -> Button:
	return panel.find_child("CloseButton", true, false) as Button


## closedシグナルの発行を同期的に観測する。_on_close_pressed()がqueue_free()まで行うため、
## awaitを挟むmonitor_signals/assert_signalでは解放済みノードへアクセスしうる
func _watch_closed(panel: SettingsPanel) -> Array[bool]:
	var received: Array[bool] = []
	panel.closed.connect(func() -> void: received.append(true))
	return received


## 保存済みのuser://settings.jsonを読み戻す（保存内容の検証用）
func _read_saved_settings() -> SettingsData:
	var file := FileAccess.open(SettingsService.SETTINGS_PATH, FileAccess.READ)
	assert_object(file).is_not_null()
	var raw_text := file.get_as_text()
	file.close()

	var json := JSON.new()
	assert_int(json.parse(raw_text)).is_equal(OK)
	return SettingsCodec.parse(json.data)


# 正常系（初期表示）


func test_ready直後の各項目がSettingsServiceの現在値と一致する() -> void:
	SettingsService.set_bgm_volume(0.25)
	SettingsService.set_se_volume(0.75)
	SettingsService.set_window_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	SettingsService.set_reduced_effects(true)

	var panel := _make_panel()

	assert_float(panel.get_bgm_slider_value()).is_equal(0.25)
	assert_float(panel.get_se_slider_value()).is_equal(0.75)
	assert_bool(_find_window_mode_toggle(panel).button_pressed).is_true()
	assert_bool(_find_reduced_effects_toggle(panel).button_pressed).is_true()


func test_初期化時にSettingsServiceの値が書き換えられない() -> void:
	SettingsService.set_bgm_volume(0.25)
	SettingsService.set_se_volume(0.75)

	var _panel := _make_panel()

	assert_float(SettingsService.get_bgm_volume()).is_equal(0.25)
	assert_float(SettingsService.get_se_volume()).is_equal(0.75)


# 正常系（各項目の操作）


func test_BGM音量スライダーの操作がSettingsServiceへ反映される() -> void:
	var panel := _make_panel()

	_find_bgm_slider(panel).value = 0.5

	assert_float(SettingsService.get_bgm_volume()).is_equal(0.5)


func test_SE音量スライダーの操作がSettingsServiceへ反映される() -> void:
	var panel := _make_panel()

	_find_se_slider(panel).value = 0.5

	assert_float(SettingsService.get_se_volume()).is_equal(0.5)


func test_ウィンドウモードトグルONでフルスクリーンになる() -> void:
	var panel := _make_panel()

	_find_window_mode_toggle(panel).button_pressed = true

	assert_int(SettingsService.get_window_mode()).is_equal(DisplayServer.WINDOW_MODE_FULLSCREEN)


func test_ウィンドウモードトグルOFFでウィンドウモードへ戻る() -> void:
	SettingsService.set_window_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	var panel := _make_panel()

	_find_window_mode_toggle(panel).button_pressed = false

	assert_int(SettingsService.get_window_mode()).is_equal(DisplayServer.WINDOW_MODE_WINDOWED)


func test_演出簡略化トグルONでreduced_effectsがtrueになる() -> void:
	var panel := _make_panel()

	_find_reduced_effects_toggle(panel).button_pressed = true

	assert_bool(SettingsService.get_reduced_effects()).is_true()


# 正常系（閉じる）


func test_閉じるボタン押下でclosedが発行され現在値が保存される() -> void:
	var panel := _make_panel()
	var closed_events := _watch_closed(panel)
	_find_bgm_slider(panel).value = 0.5
	_find_reduced_effects_toggle(panel).button_pressed = true

	_find_close_button(panel).pressed.emit()

	assert_array(closed_events).has_size(1)
	var saved := _read_saved_settings()
	assert_float(saved.bgm_volume).is_equal(0.5)
	assert_bool(saved.reduced_effects).is_true()


func test_閉じるボタン押下でパネル自身が解放予約される() -> void:
	var panel := _make_panel()

	_find_close_button(panel).pressed.emit()

	assert_bool(panel.is_queued_for_deletion()).is_true()


# 正常系（open_singleton、TitleScreen/MainSceneの多重起動防止共通ヘルパー）
# 🔴 コードレビュー指摘対応。TitleScreen/MainSceneに重複していたオーバーレイ開閉ロジックを
# SettingsPanel.open_singleton()へ集約したための単体テスト


func test_open_singletonは現在参照がなければ新規生成しparentへ追加する() -> void:
	var parent: Control = auto_free(Control.new())
	add_child(parent)

	var panel := SettingsPanel.open_singleton(null, parent, func() -> void: pass)

	assert_object(panel).is_not_null()
	assert_bool(parent.get_children().has(panel)).is_true()


func test_open_singletonは既存インスタンスがあれば新規生成しない() -> void:
	var parent: Control = auto_free(Control.new())
	add_child(parent)
	var existing := SettingsPanel.open_singleton(null, parent, func() -> void: pass)

	var result := SettingsPanel.open_singleton(existing, parent, func() -> void: pass)

	assert_object(result).is_same(existing)
	assert_int(parent.get_children().size()).is_equal(1)


func test_open_singletonが生成したパネルのclosedでon_closedが呼ばれる() -> void:
	var parent: Control = auto_free(Control.new())
	add_child(parent)
	var closed_events: Array[bool] = []
	var panel := SettingsPanel.open_singleton(
		null, parent, func() -> void: closed_events.append(true)
	)

	_find_close_button(panel).pressed.emit()

	assert_array(closed_events).has_size(1)


# 異常系・境界値


func test_閉じる操作を連続で行ってもclosedは1度しか発行されない() -> void:
	var panel := _make_panel()
	var closed_events := _watch_closed(panel)
	var close_button := _find_close_button(panel)

	close_button.pressed.emit()
	close_button.pressed.emit()

	assert_array(closed_events).has_size(1)


func test_Escapeキーで閉じるボタンと同じ結果になる() -> void:
	var runner := _make_runner()
	var panel := runner.scene() as SettingsPanel
	var closed_events := _watch_closed(panel)
	_find_bgm_slider(panel).value = 0.5

	runner.simulate_action_pressed("ui_cancel")

	assert_array(closed_events).has_size(1)
	assert_bool(panel.is_queued_for_deletion()).is_true()
	assert_float(_read_saved_settings().bgm_volume).is_equal(0.5)


func test_BGM音量スライダーの端点操作が正しく反映される(
	value: float,
	_test_parameters := [
		[0.0],
		[1.0],
	]
) -> void:
	SettingsService.set_bgm_volume(0.5)
	var panel := _make_panel()

	_find_bgm_slider(panel).value = value

	assert_float(SettingsService.get_bgm_volume()).is_equal(value)


func test_SE音量スライダーの端点操作が正しく反映される(
	value: float,
	_test_parameters := [
		[0.0],
		[1.0],
	]
) -> void:
	SettingsService.set_se_volume(0.5)
	var panel := _make_panel()

	_find_se_slider(panel).value = value

	assert_float(SettingsService.get_se_volume()).is_equal(value)
