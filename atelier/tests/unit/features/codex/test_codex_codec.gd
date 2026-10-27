extends GdUnitTestSuite

## 🔵 Issue #69（FR-716）。図鑑データの登録・永続化形式・破損時の扱いを検証する。


func _holy() -> Array[StringName]:
	return [&"holy"]


# 正常系


func test_ひらめいたレシピを元レシピと特性とあわせて登録する() -> void:
	var entries := CodexCodec.register(
		[], &"recipe_holy_water", &"recipe_healing_potion", _holy(), "2026-10-27T12:00:00"
	)

	assert_int(entries.size()).is_equal(1)
	var entry: Dictionary = entries[0]
	assert_str(entry["recipe_id"]).is_equal("recipe_holy_water")
	assert_str(entry["source_recipe_id"]).is_equal("recipe_healing_potion")
	assert_array(entry["trigger_traits"]).contains_exactly(["holy"])
	assert_str(entry["first_discovered_at"]).is_equal("2026-10-27T12:00:00")


func test_登録済みかどうかを判定できる() -> void:
	var entries := CodexCodec.register([], &"recipe_a", &"recipe_src", _holy(), "t")

	assert_bool(CodexCodec.is_discovered(entries, &"recipe_a")).is_true()
	assert_bool(CodexCodec.is_discovered(entries, &"recipe_b")).is_false()


func test_ラップしてから復元すると同じ記録に戻る() -> void:
	var entries := CodexCodec.register([], &"recipe_a", &"recipe_src", _holy(), "t")

	var raw: Variant = JSON.parse_string(JSON.stringify(CodexCodec.wrap(entries)))
	var restored := CodexCodec.unwrap(raw)

	assert_int(restored.size()).is_equal(1)
	assert_bool(CodexCodec.is_discovered(restored, &"recipe_a")).is_true()


func test_registerは引数の配列を書き換えない() -> void:
	var original: Array[Dictionary] = []

	CodexCodec.register(original, &"recipe_a", &"recipe_src", _holy(), "t")

	assert_array(original).is_empty()


func test_find_entryは登録内容を返す() -> void:
	var entries := CodexCodec.register([], &"recipe_a", &"recipe_src", _holy(), "t")

	var entry := CodexCodec.find_entry(entries, &"recipe_a")

	assert_str(entry["source_recipe_id"]).is_equal("recipe_src")
	assert_dict(CodexCodec.find_entry(entries, &"recipe_none")).is_empty()


# 異常系


func test_同じレシピを再度ひらめいても記録は重複せず最初の記録を残す() -> void:
	var entries := CodexCodec.register([], &"recipe_a", &"recipe_src", _holy(), "first")
	var gold: Array[StringName] = [&"gold"]

	entries = CodexCodec.register(entries, &"recipe_a", &"recipe_other", gold, "second")

	assert_int(entries.size()).is_equal(1)
	assert_str(entries[0]["first_discovered_at"]).is_equal("first")


func test_チェックサムが一致しなければ空の図鑑として扱う() -> void:
	var wrapped := CodexCodec.wrap(
		CodexCodec.register([], &"recipe_a", &"recipe_src", _holy(), "t")
	)
	wrapped["checksum"] = "broken"

	assert_array(CodexCodec.unwrap(wrapped)).is_empty()


func test_Dictionary以外を復元しようとしても空の図鑑として扱う() -> void:
	assert_array(CodexCodec.unwrap(null)).is_empty()
	assert_array(CodexCodec.unwrap("not a dictionary")).is_empty()


func test_記録の形が不正な要素は読み飛ばす() -> void:
	var data := {"version": 1, "entries": [{"recipe_id": 42}, "garbage"]}
	var raw := {"data": data, "checksum": SaveDataCodec.calculate_checksum(data)}

	assert_array(CodexCodec.unwrap(raw)).is_empty()


# 境界値


func test_空の図鑑もラップして復元できる() -> void:
	var empty: Array[Dictionary] = []

	var raw: Variant = JSON.parse_string(JSON.stringify(CodexCodec.wrap(empty)))

	assert_array(CodexCodec.unwrap(raw)).is_empty()
