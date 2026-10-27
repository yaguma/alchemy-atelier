# 🔵 図鑑（ひらめいたレシピの発見記録）の登録・永続化形式を扱う純粋関数群（FR-716）。
# 副作用なし、ファイルI/O・GameState参照禁止（Functional Core原則）。ファイルの読み書きはCodexServiceが担う。
# 記録1件は {recipe_id, source_recipe_id, trigger_traits, first_discovered_at} のJSON化可能なDictionary。
class_name CodexCodec

const FORMAT_VERSION := 1


## 🔵 ひらめいたレシピを登録した新しい記録一覧を返す（FR-716-001）。
## 同じレシピが登録済みなら最初の記録を残して何も追加しない（FR-716-004）
static func register(
	entries: Array[Dictionary],
	recipe_id: StringName,
	source_recipe_id: StringName,
	trigger_traits: Array[StringName],
	discovered_at: String
) -> Array[Dictionary]:
	var updated := entries.duplicate(true)
	if is_discovered(entries, recipe_id):
		return updated

	var traits: Array[String] = []
	for trait_tag in trigger_traits:
		traits.append(String(trait_tag))
	var entry := {
		"recipe_id": String(recipe_id),
		"source_recipe_id": String(source_recipe_id),
		"trigger_traits": traits,
		"first_discovered_at": discovered_at,
	}
	updated.append(entry)
	return updated


static func is_discovered(entries: Array[Dictionary], recipe_id: StringName) -> bool:
	return not find_entry(entries, recipe_id).is_empty()


## 登録内容を返す。未登録なら空のDictionary
static func find_entry(entries: Array[Dictionary], recipe_id: StringName) -> Dictionary:
	for entry in entries:
		if StringName(entry["recipe_id"]) == recipe_id:
			return entry
	return {}


## 🔵 図鑑に枠を並べるレシピID（ひらめき対応表の結果のレシピ、初出順）を返す（FR-716-005）。
## 🔵 PR #77レビュー指摘対応。同じレシピへ複数の経路（元レシピ×特性）でひらめける場合も、
## 記録はレシピ単位のため枠は1つにまとめる（でないと「発見 x/y」の両方が二重に数えられる）
static func codex_recipe_ids(inspiration_masters: Array) -> Array[StringName]:
	var recipe_ids: Array[StringName] = []
	for master: InspirationMaster in inspiration_masters:
		if not recipe_ids.has(master.result_recipe_id):
			recipe_ids.append(master.result_recipe_id)
	return recipe_ids


## 🔵 保存用にチェックサム付きでラップする（FR-716-003）。チェックサム方式はセーブデータと共通
static func wrap(entries: Array[Dictionary]) -> Dictionary:
	var data := {"version": FORMAT_VERSION, "entries": entries.duplicate(true)}
	return {"data": data, "checksum": SaveDataCodec.calculate_checksum(data)}


## 🔵 JSON.parse_string()の結果を検証して記録一覧を返す。破損・不正な形式は空の図鑑として扱い、
## 形の不正な要素は読み飛ばす（FR-716-003、security.mdのセーブデータ検証方針）
static func unwrap(raw: Variant) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if not (raw is Dictionary):
		return entries
	var data: Variant = (raw as Dictionary).get("data")
	var checksum: Variant = (raw as Dictionary).get("checksum")
	if not (data is Dictionary) or not (checksum is String):
		return entries
	if checksum != SaveDataCodec.calculate_checksum(data):
		return entries

	var saved: Variant = (data as Dictionary).get("entries")
	if not (saved is Array):
		return entries
	for entry: Variant in saved:
		if _is_valid_entry(entry):
			entries.append(entry)
	return entries


static func _is_valid_entry(entry: Variant) -> bool:
	if not (entry is Dictionary):
		return false
	var d: Dictionary = entry
	return (
		d.get("recipe_id") is String
		and d.get("source_recipe_id") is String
		and d.get("trigger_traits") is Array
		and d.get("first_discovered_at") is String
	)
