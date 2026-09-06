extends GdUnitTestSuite


func before_test() -> void:
	_remove_settings_file()
	SettingsService.reset_for_test()


func after_test() -> void:
	_remove_settings_file()
	SettingsService.reset_for_test()


## 設定ファイルを削除し、「未作成」状態へ戻す
func _remove_settings_file() -> void:
	if FileAccess.file_exists(SettingsService.SETTINGS_PATH):
		DirAccess.remove_absolute(SettingsService.SETTINGS_PATH)


## 検証用に任意の生テキストを設定ファイルへ書き込む（破損ケースの再現用）
func _write_raw_settings_file(text: String) -> void:
	var file := FileAccess.open(SettingsService.SETTINGS_PATH, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _assert_all_defaults() -> void:
	var defaults := SettingsData.new()
	assert_float(SettingsService.get_bgm_volume()).is_equal(defaults.bgm_volume)
	assert_float(SettingsService.get_se_volume()).is_equal(defaults.se_volume)
	assert_int(SettingsService.get_window_mode()).is_equal(defaults.window_mode)
	assert_bool(SettingsService.get_reduced_effects()).is_equal(defaults.reduced_effects)


# 正常系


func test_設定ファイルが未作成ならload_settings後もデフォルト値を返す() -> void:
	SettingsService.load_settings()

	_assert_all_defaults()


## 🔴 コードレビュー指摘対応。load_settings()がAutoloadのどのライフサイクルからも
## 呼ばれておらず、保存済み設定が起動時に一切復元されない不具合があった。
## _ready()実装がload_settings()を呼ぶことを固定する回帰テスト
func test_readyがload_settingsを呼び保存済み設定を復元する() -> void:
	SettingsService.set_bgm_volume(0.4)
	SettingsService.save_settings()
	SettingsService.reset_for_test()

	SettingsService._ready()

	assert_float(SettingsService.get_bgm_volume()).is_equal(0.4)


func test_set_bgm_volumeで設定した値を取得できる() -> void:
	SettingsService.set_bgm_volume(0.5)

	assert_float(SettingsService.get_bgm_volume()).is_equal(0.5)


func test_set_se_volumeで設定した値を取得できる() -> void:
	SettingsService.set_se_volume(0.25)

	assert_float(SettingsService.get_se_volume()).is_equal(0.25)


func test_set_window_modeで設定した値を取得できる() -> void:
	SettingsService.set_window_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

	assert_int(SettingsService.get_window_mode()).is_equal(DisplayServer.WINDOW_MODE_FULLSCREEN)


func test_set_reduced_effectsで設定した値を取得できる() -> void:
	SettingsService.set_reduced_effects(true)

	assert_bool(SettingsService.get_reduced_effects()).is_true()


func test_保存して再読込しても音量が保持される() -> void:
	SettingsService.set_bgm_volume(0.5)
	SettingsService.save_settings()

	SettingsService.reset_for_test()
	SettingsService.load_settings()

	assert_float(SettingsService.get_bgm_volume()).is_equal(0.5)


func test_4値すべてを変更しても保存と再読込で一致する() -> void:
	SettingsService.set_bgm_volume(0.0)
	SettingsService.set_se_volume(1.0)
	SettingsService.set_window_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	SettingsService.set_reduced_effects(true)
	SettingsService.save_settings()

	SettingsService.reset_for_test()
	SettingsService.load_settings()

	assert_float(SettingsService.get_bgm_volume()).is_equal(0.0)
	assert_float(SettingsService.get_se_volume()).is_equal(1.0)
	assert_int(SettingsService.get_window_mode()).is_equal(DisplayServer.WINDOW_MODE_FULLSCREEN)
	assert_bool(SettingsService.get_reduced_effects()).is_true()


func test_reset_for_testが全値をデフォルトへ戻す() -> void:
	SettingsService.set_bgm_volume(0.1)
	SettingsService.set_se_volume(0.2)
	SettingsService.set_window_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	SettingsService.set_reduced_effects(true)

	SettingsService.reset_for_test()

	_assert_all_defaults()


# 異常系・境界値


func test_JSONとして壊れた設定ファイルはデフォルト値へフォールバックする() -> void:
	_write_raw_settings_file("{ this is not json")

	SettingsService.load_settings()

	_assert_all_defaults()


func test_キーが欠けた設定ファイルはデフォルト値へフォールバックする() -> void:
	_write_raw_settings_file('{"bgm_volume": 0.5}')

	SettingsService.load_settings()

	_assert_all_defaults()


func test_型が不正な設定ファイルはデフォルト値へフォールバックする() -> void:
	var invalid := {
		"bgm_volume": "loud",
		"se_volume": 0.5,
		"window_mode": 0,
		"reduced_effects": false,
	}
	_write_raw_settings_file(JSON.stringify(invalid))

	SettingsService.load_settings()

	_assert_all_defaults()


func test_範囲外の音量は0から1へクランプされる(
	value: float,
	expected: float,
	_test_parameters := [
		[-1.0, 0.0],
		[0.0, 0.0],
		[1.0, 1.0],
		[2.0, 1.0],
	]
) -> void:
	SettingsService.set_bgm_volume(value)
	SettingsService.set_se_volume(value)

	assert_float(SettingsService.get_bgm_volume()).is_equal(expected)
	assert_float(SettingsService.get_se_volume()).is_equal(expected)


func test_音量バスが未定義でも音量変更でクラッシュしない() -> void:
	# 🔵 現状のプロジェクトにはAudioBusLayoutが無く、BGM/SEバスは未定義（get_bus_index()が-1）。
	# その環境でもAudioServerへの反映をno-opにして値の保持だけは行うことを確認する。
	assert_int(AudioServer.get_bus_index(SettingsService.BUS_BGM)).is_equal(-1)
	assert_int(AudioServer.get_bus_index(SettingsService.BUS_SE)).is_equal(-1)

	SettingsService.set_bgm_volume(0.3)
	SettingsService.set_se_volume(0.7)

	assert_float(SettingsService.get_bgm_volume()).is_equal(0.3)
	assert_float(SettingsService.get_se_volume()).is_equal(0.7)
