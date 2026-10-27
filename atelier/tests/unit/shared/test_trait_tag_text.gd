extends GdUnitTestSuite

## 🔵 Issue #66。特性タグの表示文字列（凝縮された重複タグを「×N」でまとめる）を検証する。


func test_重複のないタグは区切り文字で並べる() -> void:
	var tags: Array[StringName] = [&"holy", &"gold"]

	assert_str(TraitTagText.format(tags)).is_equal("holy, gold")


func test_重複したタグは個数をまとめて表示する() -> void:
	var tags: Array[StringName] = [&"holy", &"holy", &"gold", &"gold"]

	assert_str(TraitTagText.format(tags)).is_equal("holy×2, gold×2")


func test_空配列は空文字を返す() -> void:
	var tags: Array[StringName] = []

	assert_str(TraitTagText.format(tags)).is_empty()
