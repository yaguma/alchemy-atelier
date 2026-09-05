extends GdUnitTestSuite


# 正常系
func test_初期値はBGM音量1_0とSE音量1_0とウィンドウモードと演出簡略化OFF() -> void:
	var data := SettingsData.new()

	assert_float(data.bgm_volume).is_equal(1.0)
	assert_float(data.se_volume).is_equal(1.0)
	assert_int(data.window_mode).is_equal(DisplayServer.WINDOW_MODE_WINDOWED)
	assert_bool(data.reduced_effects).is_false()


# 正常系
func test_to_dictは4つの設定キーを持つDictionaryを返す() -> void:
	var data := SettingsData.new()
	data.bgm_volume = 0.4
	data.se_volume = 0.6
	data.window_mode = DisplayServer.WINDOW_MODE_FULLSCREEN
	data.reduced_effects = true

	var dict := SettingsCodec.to_dict(data)

	assert_dict(dict).contains_key_value("bgm_volume", 0.4)
	assert_dict(dict).contains_key_value("se_volume", 0.6)
	assert_dict(dict).contains_key_value("window_mode", DisplayServer.WINDOW_MODE_FULLSCREEN)
	assert_dict(dict).contains_key_value("reduced_effects", true)


# 正常系
func test_to_dictはチェックサムをラップしない() -> void:
	var dict := SettingsCodec.to_dict(SettingsData.new())

	assert_dict(dict).not_contains_keys(["checksum", "data", "version"])


# 正常系
func test_to_dictとparseのラウンドトリップで値が一致する() -> void:
	var original := SettingsData.new()
	original.bgm_volume = 0.25
	original.se_volume = 0.75
	original.window_mode = DisplayServer.WINDOW_MODE_FULLSCREEN
	original.reduced_effects = true

	var restored := SettingsCodec.parse(SettingsCodec.to_dict(original))

	assert_float(restored.bgm_volume).is_equal(0.25)
	assert_float(restored.se_volume).is_equal(0.75)
	assert_int(restored.window_mode).is_equal(DisplayServer.WINDOW_MODE_FULLSCREEN)
	assert_bool(restored.reduced_effects).is_true()


# 正常系
func test_JSON往復後のDictionaryもparseできる() -> void:
	var original := SettingsData.new()
	original.bgm_volume = 0.5
	original.se_volume = 0.25
	original.window_mode = DisplayServer.WINDOW_MODE_FULLSCREEN
	original.reduced_effects = true
	var raw: Variant = JSON.parse_string(JSON.stringify(SettingsCodec.to_dict(original)))

	var restored := SettingsCodec.parse(raw)

	assert_float(restored.bgm_volume).is_equal(0.5)
	assert_float(restored.se_volume).is_equal(0.25)
	assert_int(restored.window_mode).is_equal(DisplayServer.WINDOW_MODE_FULLSCREEN)
	assert_bool(restored.reduced_effects).is_true()


# 異常系
func test_Dictionary以外を渡すとデフォルト値が返る(
	raw: Variant,
	_test_parameters := [
		[null],
		["not a dictionary"],
		[[]],
		[42],
	]
) -> void:
	_assert_is_default(SettingsCodec.parse(raw))


# 異常系
func test_キーが欠損していればデフォルト値が返る(
	missing_key: String,
	_test_parameters := [
		["bgm_volume"],
		["se_volume"],
		["window_mode"],
		["reduced_effects"],
	]
) -> void:
	var dict := _make_non_default_dict()
	dict.erase(missing_key)

	_assert_is_default(SettingsCodec.parse(dict))


# 異常系
func test_型が不正な値を渡すとデフォルト値が返る(
	key: String,
	invalid_value: Variant,
	_test_parameters := [
		["bgm_volume", "0.5"],
		["se_volume", []],
		["window_mode", "windowed"],
		["reduced_effects", 1],
	]
) -> void:
	var dict := _make_non_default_dict()
	dict[key] = invalid_value

	_assert_is_default(SettingsCodec.parse(dict))


# 異常系
# 🔴 コードレビュー指摘対応。window_modeは型（int/float）だけでなく
# DisplayServer.WindowModeの有効範囲（0〜4）チェックも必要（手動編集・破損したJSON対策）
func test_window_modeが範囲外の値だとデフォルト値が返る(
	invalid_mode: float,
	_test_parameters := [
		[-1.0],
		[9999.0],
	]
) -> void:
	var dict := _make_non_default_dict()
	dict["window_mode"] = invalid_mode

	_assert_is_default(SettingsCodec.parse(dict))


# 境界値
func test_window_modeの有効範囲の両端は正しく解釈される(
	mode: int,
	_test_parameters := [
		[DisplayServer.WINDOW_MODE_WINDOWED],
		[DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN],
	]
) -> void:
	var dict := _make_non_default_dict()
	dict["window_mode"] = mode

	var result := SettingsCodec.parse(dict)

	assert_int(result.window_mode).is_equal(mode)


# 境界値
func test_音量は0_0から1_0にクランプされる(
	raw_volume: float,
	expected: float,
	_test_parameters := [
		[-0.5, 0.0],
		[0.0, 0.0],
		[1.0, 1.0],
		[1.5, 1.0],
	]
) -> void:
	var dict := _make_non_default_dict()
	dict["bgm_volume"] = raw_volume
	dict["se_volume"] = raw_volume

	var result := SettingsCodec.parse(dict)

	assert_float(result.bgm_volume).is_equal(expected)
	assert_float(result.se_volume).is_equal(expected)


# 境界値
func test_window_modeがfloatで渡されてもintとして解釈される() -> void:
	var dict := _make_non_default_dict()
	dict["window_mode"] = 1.0

	var result := SettingsCodec.parse(dict)

	assert_int(result.window_mode).is_equal(1)


# 境界値
func test_音量がintで渡されてもfloatとして解釈される() -> void:
	var dict := _make_non_default_dict()
	dict["bgm_volume"] = 1
	dict["se_volume"] = 0

	var result := SettingsCodec.parse(dict)

	assert_float(result.bgm_volume).is_equal(1.0)
	assert_float(result.se_volume).is_equal(0.0)


## デフォルト値と全項目が一致することを検証する（テスト用ヘルパー）。
func _assert_is_default(data: SettingsData) -> void:
	assert_float(data.bgm_volume).is_equal(1.0)
	assert_float(data.se_volume).is_equal(1.0)
	assert_int(data.window_mode).is_equal(DisplayServer.WINDOW_MODE_WINDOWED)
	assert_bool(data.reduced_effects).is_false()


## デフォルト値と全項目が異なる正当なDictionaryを生成する（テスト用フィクスチャ）。
## デフォルトへのフォールバックが起きたことを確実に判別するために使う。
func _make_non_default_dict() -> Dictionary:
	return {
		"bgm_volume": 0.3,
		"se_volume": 0.7,
		"window_mode": DisplayServer.WINDOW_MODE_FULLSCREEN,
		"reduced_effects": true,
	}
