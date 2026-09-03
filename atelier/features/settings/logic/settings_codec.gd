# 🔵 設定値の永続化形式（素のDictionary）を扱う純粋関数群。
# 副作用なし、Node非継承、ファイルI/O・GameState参照禁止（Functional Core原則）。
# SaveDataCodecと異なりチェックサムでラップしない。設定値はゲームバランスに影響せず、
# 改ざんされても不利益がないため破損検出のコストに見合わない（FR-404）。
# 破損・型不正な入力に対しては例外を投げず、デフォルト値のSettingsDataへフォールバックする。
class_name SettingsCodec

const MIN_VOLUME := 0.0
const MAX_VOLUME := 1.0


## 🔵 SettingsDataを永続化用Dictionaryへ変換する。
static func to_dict(data: SettingsData) -> Dictionary:
	return {
		"bgm_volume": data.bgm_volume,
		"se_volume": data.se_volume,
		"window_mode": data.window_mode,
		"reduced_effects": data.reduced_effects,
	}


## 🔵 JSON.parse()が返した生のVariantを検証し、正当ならSettingsDataへ復元して返す。
## 不正・破損時はデフォルト値のSettingsDataを返す（NFR-101, FR-005, FR-008, AC-010）。
static func parse(raw: Variant) -> SettingsData:
	var data := SettingsData.new()
	if not _is_valid(raw):
		return data
	var d: Dictionary = raw

	data.bgm_volume = clampf(float(d["bgm_volume"]), MIN_VOLUME, MAX_VOLUME)
	data.se_volume = clampf(float(d["se_volume"]), MIN_VOLUME, MAX_VOLUME)
	data.window_mode = int(d["window_mode"])
	data.reduced_effects = d["reduced_effects"]
	return data


## 🟡 rawがトップレベルキーの型を満たすかを返す
## （save_data_codec.gdの_is_valid_save_data()と同水準の検証範囲）。
## GodotのJSONパーサは数値を常にfloatとして返すため、数値キーはintとfloatの両方を許容する。
static func _is_valid(raw: Variant) -> bool:
	if not (raw is Dictionary):
		return false
	var d: Dictionary = raw

	for key in ["bgm_volume", "se_volume", "window_mode"]:
		var value: Variant = d.get(key)
		if not (value is int or value is float):
			return false

	return d.get("reduced_effects") is bool
