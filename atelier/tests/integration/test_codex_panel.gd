extends GdUnitTestSuite

## 🔵 Issue #69（FR-716-005）。図鑑画面がひらめき対応表の全レシピを並べ、未発見を「？？？」で表示することを検証する。

const SCENE_PATH := "res://shared/ui/codex_panel.tscn"
const TEST_PATH := "user://test_codex_panel.json"


func before_test() -> void:
	_remove_test_file()
	CodexService.reset_for_test(TEST_PATH)


func after_test() -> void:
	_remove_test_file()
	CodexService.reset_for_test(TEST_PATH)


func _remove_test_file() -> void:
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))


func _make_panel() -> CodexPanel:
	var runner := scene_runner(SCENE_PATH)
	return runner.scene() as CodexPanel


# 正常系


func test_ひらめき対応表の全レシピぶんの枠が並ぶ() -> void:
	var panel := _make_panel()

	var inspirations := MasterDataLoader.load_all(&"inspirations")
	assert_int(panel.get_entry_count()).is_equal(inspirations.size())


func test_未発見のレシピはハテナで表示される() -> void:
	var panel := _make_panel()

	assert_array(panel.get_entry_texts()).contains([CodexPanel.UNKNOWN_TEXT])


func test_発見済みのレシピは名前と元レシピと特性が表示される() -> void:
	CodexService.record(
		&"recipe_holy_water", &"recipe_healing_potion", [&"holy"] as Array[StringName]
	)

	var panel := _make_panel()

	var discovered := ""
	for text in panel.get_entry_texts():
		if text.contains("聖水"):
			discovered = text
	assert_str(discovered).contains("回復薬")
	assert_str(discovered).contains("holy")


func test_発見数と総数が見出しに表示される() -> void:
	CodexService.record(
		&"recipe_holy_water", &"recipe_healing_potion", [&"holy"] as Array[StringName]
	)

	var panel := _make_panel()

	var total := MasterDataLoader.load_all(&"inspirations").size()
	assert_str(panel.get_summary_text()).contains("1/%d" % total)


## 🔵 閉じると自身をqueue_free()するため、monitor_signals()ではなく直接接続で発行回数を数える
## （test_pause_menu.gdと同じ方式）
func test_閉じるボタンでclosedが発行される() -> void:
	var panel := _make_panel()
	var closed_count := [0]
	panel.closed.connect(func() -> void: closed_count[0] += 1)

	(panel.find_child("CloseButton", true, false) as Button).pressed.emit()

	assert_int(closed_count[0]).is_equal(1)


# 異常系


func test_open_singletonは開いている間は同じインスタンスを返す() -> void:
	var parent: Control = auto_free(Control.new())
	add_child(parent)

	var first := CodexPanel.open_singleton(null, parent, func() -> void: pass)
	var second := CodexPanel.open_singleton(first, parent, func() -> void: pass)

	assert_object(second).is_same(first)
