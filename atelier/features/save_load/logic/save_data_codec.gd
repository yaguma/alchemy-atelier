# 🔵 セーブデータの永続化形式（チェックサム付きラップ）を扱う純粋関数群。
# 副作用なし、Node非継承、ファイルI/O・GameState参照禁止（Functional Core原則）。
class_name SaveDataCodec

## 🔴 将来のセーブフォーマット変更時のマイグレーション判定用に予約。
## 現スコープでは書き込むのみで、読み込み側はこの値を検証しない。
const SAVE_FORMAT_VERSION := 1


## 🔵 dataのSHA-256チェックサムを返す（security.md「セーブデータの破損検出」準拠）。
## 秘密鍵を持たない素のSHA-256のため、検出できるのは偶発的破損のみで意図的な改ざんは検出できない。
## 🔴 バグ修正: GodotのJSONは数値を常にfloatとして復元するため、保存前（int）と
## 読込後（JSON.parse()経由で必ずfloat化された同一データ）で素のJSON.stringify(data)は
## 異なる文字列になり（例: 100 → "100" だがパース後は100.0 → "100.0"）、チェックサムが
## 常に不一致になってしまう実障害があった（task 005のSaveServiceファイルI/O統合テストで発覚）。
## そのため計算前に一度JSON往復させてint/StringName等をfloat/String等のJSON表現へ
## 正規化してからハッシュ化し、書き込み時と読込検証時で同じ文字列表現に揃える。
static func calculate_checksum(data: Dictionary) -> String:
	var normalized: Variant = JSON.parse_string(JSON.stringify(data))
	return JSON.stringify(normalized).sha256_text()


## 🔵 dataをバージョン・チェックサム付きの永続化用Dictionaryにラップして返す。
## 🔴 コードレビュー指摘対応。SAVE_FORMAT_VERSIONを実際にファイルへ書き込む
## （従来はコメント上の予約のみで実装が伴わず、既存の全セーブファイルにバージョン情報が
## 一切残らないまま蓄積してしまっていた）。読み込み側（validate_and_unwrap）は
## 引き続きこの値を検証しない（現スコープの割り切りは変えない）。
static func wrap_with_checksum(data: Dictionary) -> Dictionary:
	return {"version": SAVE_FORMAT_VERSION, "data": data, "checksum": calculate_checksum(data)}


## 🔵 JSON.parse()が返した生のVariantを検証し、正当ならdata部分のDictionaryを返す。
## 不正・破損時は空Dictionaryを返す（呼び出し元は空判定でエラー扱いする）。
## checksum照合で検出できるのは偶発的な破損のみで、意図的な改ざんは検出できない
## （security.md「セーブデータの破損検出」の割り切りをそのまま継承する）。
static func validate_and_unwrap(raw: Variant) -> Dictionary:
	if not (raw is Dictionary):
		return {}
	var wrapper: Dictionary = raw

	var data: Variant = wrapper.get("data")
	if not (data is Dictionary):
		return {}

	var checksum: Variant = wrapper.get("checksum")
	if not (checksum is String):
		return {}
	if checksum != calculate_checksum(data):
		return {}

	if not _is_valid_save_data(data):
		return {}
	return data


## 🟡 保存用Dictionaryとして最低限の構造を満たすかを返す。
## トップレベルキーの型のみ検証し、inventory等の配列要素やネストDictionaryの内部までは検証しない
## （個人開発規模の割り切り。security.mdの_is_valid_save_data()と同水準の検証範囲）。
## GodotのJSONパーサは数値を常にfloatとして返すため、数値キーはintとfloatの両方を許容する。
static func _is_valid_save_data(data: Variant) -> bool:
	if not (data is Dictionary):
		return false
	var d: Dictionary = data

	for key in [
		"current_phase",
		"current_daily_order_id",
		"current_rank_id",
	]:
		if not (d.get(key) is String):
			return false

	for key in [
		"gold",
		"current_turn",
		"material_instance_seq",
		"garden_slot_count",
		"alchemy_slot_count",
		"demotion_count",
		"last_rank_outcome",
		"last_exam_outcome",
		"saved_at_unix",
	]:
		var value: Variant = d.get(key)
		if not (value is int or value is float):
			return false

	for key in [
		"garden_state",
		"rank_state",
		"exam_state",
		"purchased_upgrade_counts",
	]:
		if not (d.get(key) is Dictionary):
			return false

	for key in [
		"seed_inventory",
		"inventory",
		"unlocked_recipe_ids",
		"pending_products",
	]:
		if not (d.get(key) is Array):
			return false

	for key in [
		"rank_state_initialized",
		"in_exam",
		"has_cleared_game",
		"can_purchase_permanent",
	]:
		if not (d.get(key) is bool):
			return false

	return true
