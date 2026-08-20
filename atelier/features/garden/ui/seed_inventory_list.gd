class_name SeedInventoryList
extends Control

## 手持ちの種一覧を表示し、植え付け操作の起点となる表示専用コンポーネント。
## GameStateに依存せず、seed_inventoryとseed_mastersをsetup()で受け取る
## （ui-design/screens/garden.md「手持ちの種一覧」／plan.md参照）。

signal seed_plant_requested(seed_id: StringName)  # 🔵 US-001

const PLANT_BUTTON_TEXT := "植える"
const ENTRY_SEPARATION := 8

var _seed_inventory: Array = []
var _seed_masters: Dictionary = {}

@onready var _entry_container: VBoxContainer = %EntryContainer


## 種在庫（[{seed_id: StringName, count: int}]）と表示名解決用のマスター辞書
## （seed_id -> SeedMaster）を受け取り、一覧を再構築する。🔵 US-001
func setup(seed_inventory: Array, seed_masters: Dictionary) -> void:
	_seed_inventory = seed_inventory
	_seed_masters = seed_masters
	_rebuild()


## 現在表示している種エントリの件数を返す。🔵
func get_entry_count() -> int:
	if _entry_container == null:
		return 0
	return _entry_container.get_child_count()


func _ready() -> void:
	_entry_container.add_theme_constant_override("separation", ENTRY_SEPARATION)
	_rebuild()


func _rebuild() -> void:
	# setup()がシーンツリー追加前に呼ばれた場合は、_ready()で改めて構築する
	if _entry_container == null:
		return

	for child in _entry_container.get_children():
		_entry_container.remove_child(child)
		child.queue_free()

	for entry: Variant in _seed_inventory:
		if not (entry is Dictionary):
			continue
		_entry_container.add_child(_create_entry_row(entry as Dictionary))


func _create_entry_row(entry: Dictionary) -> HBoxContainer:
	var seed_id := StringName(entry.get("seed_id", &""))
	var count := int(entry.get("count", 0))

	var row := HBoxContainer.new()
	row.name = "SeedEntry_%s" % seed_id

	var name_label := Label.new()
	name_label.name = "NameLabel"
	name_label.text = _resolve_display_name(seed_id)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)

	var count_label := Label.new()
	count_label.name = "CountLabel"
	count_label.text = "x%d" % count
	row.add_child(count_label)

	var plant_button := Button.new()
	plant_button.name = "PlantButton"
	plant_button.text = PLANT_BUTTON_TEXT
	plant_button.disabled = count <= 0
	plant_button.pressed.connect(_on_plant_pressed.bind(seed_id))
	row.add_child(plant_button)

	return row


## seed_mastersにseed_idが存在しない場合（マスター未ロード等）でもクラッシュさせず、
## seed_id自体を表示名にフォールバックする。🔵 NFR-101
func _resolve_display_name(seed_id: StringName) -> String:
	var master: Variant = _seed_masters.get(seed_id)
	if master is SeedMaster:
		return (master as SeedMaster).name
	return String(seed_id)


func _on_plant_pressed(seed_id: StringName) -> void:
	seed_plant_requested.emit(seed_id)
