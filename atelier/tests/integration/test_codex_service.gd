extends GdUnitTestSuite

## 🔵 Issue #69（FR-716）。ひらめきを図鑑に記録し、セーブスロットとは別のファイルに永続化することを検証する。

const TEST_PATH := "user://test_codex.json"


func before_test() -> void:
	_remove_test_file()
	CodexService.reset_for_test(TEST_PATH)
	GameState.reset_for_test()


func after_test() -> void:
	_remove_test_file()
	CodexService.reset_for_test(TEST_PATH)
	GameState.reset_for_test()


func _remove_test_file() -> void:
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))


func _inspire(recipe_id: StringName) -> void:
	var traits: Array[StringName] = [&"holy"]
	GameState.recipe_inspired.emit(recipe_id, &"recipe_healing_potion", traits)


# 正常系


func test_ひらめくと図鑑に記録される() -> void:
	_inspire(&"recipe_holy_water")

	assert_bool(CodexService.is_discovered(&"recipe_holy_water")).is_true()


func test_記録はファイルに保存され読み込み直しても残る() -> void:
	_inspire(&"recipe_holy_water")

	CodexService.reload_for_test()

	assert_bool(FileAccess.file_exists(TEST_PATH)).is_true()
	assert_bool(CodexService.is_discovered(&"recipe_holy_water")).is_true()


func test_新規ゲームを始めても図鑑の記録は消えない() -> void:
	_inspire(&"recipe_holy_water")

	GameState.reset_for_new_game()

	assert_bool(CodexService.is_discovered(&"recipe_holy_water")).is_true()


func test_記録が増えるとcodex_updatedが発行される() -> void:
	monitor_signals(CodexService, false)

	_inspire(&"recipe_holy_water")

	await assert_signal(CodexService).is_emitted("codex_updated")


# 異常系


func test_同じレシピを再度ひらめいても記録は1件のまま() -> void:
	_inspire(&"recipe_holy_water")
	_inspire(&"recipe_holy_water")

	assert_int(CodexService.get_entries().size()).is_equal(1)


func test_破損したファイルは空の図鑑として読み込まれる() -> void:
	var file := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	file.store_string("{ broken json")
	file.close()

	CodexService.reload_for_test()

	assert_array(CodexService.get_entries()).is_empty()


func test_get_entriesの戻り値を書き換えても図鑑は変わらない() -> void:
	_inspire(&"recipe_holy_water")

	CodexService.get_entries().clear()

	assert_int(CodexService.get_entries().size()).is_equal(1)
