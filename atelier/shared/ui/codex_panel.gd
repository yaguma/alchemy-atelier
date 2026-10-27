class_name CodexPanel
extends Control

## 🔵 Issue #69（FR-716-005/006）。ひらめいたレシピの図鑑。ひらめき対応表の全レシピを並べ、
## 未発見のものは「？？？」で枠だけ表示する。タイトル画面と一時停止メニューの両方から開くため、
## SettingsPanel/PauseMenuと同じくshared/ui/に置く。
## タイトル画面ではGameStateのマスターデータが未ロードのため、表示用のマスターデータは
## MasterDataLoaderから直接読む（Infrastructure層の参照のみで、状態は変更しない）。

signal closed

const UNKNOWN_TEXT := "？？？"  # 🔵 FR-716-005
const DISCOVERED_FORMAT := "%s（%s × %s）"  # 🟡 ui-design未確定の暫定表記: 結果（元レシピ × 特性）
const SUMMARY_FORMAT := "発見 %d/%d"
const NO_TRAITS_TEXT := "特性なし"
const MAIN_THEME := preload("res://shared/theme/main_theme.tres")

var _entry_texts: Array[String] = []
var _discovered_count: int = 0

@onready var _dialog_panel: PanelContainer = %DialogPanel
@onready var _root_container: VBoxContainer = %RootContainer
@onready var _title_label: Label = %TitleLabel
@onready var _summary_label: Label = %SummaryLabel
@onready var _entry_container: VBoxContainer = %EntryContainer
@onready var _close_button: Button = %CloseButton


func _ready() -> void:
	_apply_theme()
	_close_button.pressed.connect(_on_close_pressed)
	_rebuild()


func get_entry_count() -> int:
	return _entry_texts.size()


## 表示中の各枠の文字列（🔵 テスト用）
func get_entry_texts() -> Array[String]:
	return _entry_texts.duplicate()


func get_summary_text() -> String:
	return _summary_label.text


## 🔵 PauseMenu.open_singleton()と同型の多重起動防止パターン
static func open_singleton(
	current: CodexPanel, overlay_parent: Node, on_closed: Callable
) -> CodexPanel:
	if is_instance_valid(current):
		return current
	var panel: CodexPanel = (
		(preload("res://shared/ui/codex_panel.tscn") as PackedScene).instantiate()
	)
	panel.closed.connect(on_closed)
	overlay_parent.add_child(panel)
	return panel


func _apply_theme() -> void:
	theme = MAIN_THEME
	_root_container.add_theme_constant_override("separation", UiTheme.SPACING_LIST_ENTRY)
	UiTheme.apply_panel_style(_dialog_panel)
	for label: Label in [_title_label, _summary_label]:
		UiTheme.apply_pixel_font(label)
	UiTheme.apply_pixel_font(_close_button)
	ButtonStyleApplier.apply_button_style(_close_button, UiTheme.ButtonVariant.SECONDARY)


func _rebuild() -> void:
	var recipe_names := _load_recipe_names()
	var entries := CodexService.get_entries()
	_entry_texts.clear()
	_discovered_count = 0
	for child in _entry_container.get_children():
		_entry_container.remove_child(child)
		child.queue_free()

	for master: InspirationMaster in MasterDataLoader.load_all(&"inspirations"):
		var entry := CodexCodec.find_entry(entries, master.result_recipe_id)
		var text := UNKNOWN_TEXT
		if not entry.is_empty():
			_discovered_count += 1
			text = _format_discovered(entry, recipe_names)
		_entry_texts.append(text)
		_add_entry_label(text)

	_summary_label.text = SUMMARY_FORMAT % [_discovered_count, _entry_texts.size()]


func _format_discovered(entry: Dictionary, recipe_names: Dictionary) -> String:
	var traits: Array = entry["trigger_traits"]
	var traits_text := NO_TRAITS_TEXT if traits.is_empty() else ", ".join(PackedStringArray(traits))
	var result_name: String = recipe_names.get(StringName(entry["recipe_id"]), entry["recipe_id"])
	var source_id: String = entry["source_recipe_id"]
	var source_name: String = recipe_names.get(StringName(source_id), source_id)
	return DISCOVERED_FORMAT % [result_name, source_name, traits_text]


func _add_entry_label(text: String) -> void:
	var label := Label.new()
	label.text = text
	UiTheme.apply_pixel_font(label)
	_entry_container.add_child(label)


static func _load_recipe_names() -> Dictionary:
	var names: Dictionary = {}
	for recipe: RecipeMaster in MasterDataLoader.load_all(&"recipes"):
		names[recipe.id] = recipe.name
	return names


func _on_close_pressed() -> void:
	closed.emit()
	queue_free()
