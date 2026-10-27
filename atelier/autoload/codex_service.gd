extends Node

## 🔵 Issue #69（FR-716）。ひらめいたレシピの図鑑をセーブスロットとは別のファイルに永続化するAutoload。
## GameStateのrecipe_inspiredを購読し、記録が増えるたびに即座に保存する。新規ゲーム開始・スロット切り替えの
## 影響を受けない（ひらめいたレシピ自体はラン間で持ち越さないが、発見の記録だけは残す）。
## 記録の登録規則・ファイル形式の検証はCodexCodec（Functional Core）が担い、本ノードはI/Oのみを担う。

signal codex_updated

const DEFAULT_FILE_PATH := "user://codex.json"

var _file_path: String = DEFAULT_FILE_PATH
var _entries: Array[Dictionary] = []


func _ready() -> void:
	_load()
	# 🔵 GameStateはAutoloadで本ノードと同じくアプリ終了まで生存するため、切断処理は_exit_tree()で行う
	GameState.recipe_inspired.connect(_on_recipe_inspired)


func _exit_tree() -> void:
	if GameState.recipe_inspired.is_connected(_on_recipe_inspired):
		GameState.recipe_inspired.disconnect(_on_recipe_inspired)


## 図鑑の記録一覧（防御的コピー）
func get_entries() -> Array[Dictionary]:
	return _entries.duplicate(true)


func is_discovered(recipe_id: StringName) -> bool:
	return CodexCodec.is_discovered(_entries, recipe_id)


## ひらめいたレシピを記録して保存する。登録済みなら何もしない
func record(
	recipe_id: StringName, source_recipe_id: StringName, trigger_traits: Array[StringName]
) -> void:
	if is_discovered(recipe_id):
		return
	_entries = CodexCodec.register(
		_entries,
		recipe_id,
		source_recipe_id,
		trigger_traits,
		Time.get_datetime_string_from_system()
	)
	_save()
	codex_updated.emit()


## 🟡 テスト専用。保存先を差し替えて記録を空にする（本番の図鑑ファイルを汚さないため）
func reset_for_test(file_path: String) -> void:
	assert(OS.is_debug_build(), "reset_for_test() must not be called in release builds")
	if not OS.is_debug_build():
		push_error("CodexService.reset_for_test() must not be called in release builds")
		return
	_file_path = file_path
	_entries = []


## 🟡 テスト専用。保存先ファイルから読み込み直す（アプリ再起動相当）
func reload_for_test() -> void:
	_load()


func _on_recipe_inspired(
	result_recipe_id: StringName, source_recipe_id: StringName, traits: Array
) -> void:
	var trigger_traits: Array[StringName] = []
	for trait_tag in traits:
		trigger_traits.append(StringName(trait_tag))
	record(result_recipe_id, source_recipe_id, trigger_traits)


func _load() -> void:
	_entries = []
	if not FileAccess.file_exists(_file_path):
		return
	var file := FileAccess.open(_file_path, FileAccess.READ)
	if file == null:
		push_warning("図鑑ファイルを開けませんでした: %s" % error_string(FileAccess.get_open_error()))
		return
	# 🔵 FR-716-003。壊れたJSON・チェックサム不一致は空の図鑑として扱い、クラッシュさせない
	_entries = CodexCodec.unwrap(JSON.parse_string(file.get_as_text()))


func _save() -> void:
	var file := FileAccess.open(_file_path, FileAccess.WRITE)
	if file == null:
		push_warning("図鑑ファイルを保存できませんでした: %s" % error_string(FileAccess.get_open_error()))
		return
	file.store_string(JSON.stringify(CodexCodec.wrap(_entries)))
