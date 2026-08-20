class_name SeedInventoryList
extends Control

## 手持ちの種一覧を表示し、植え付け操作の起点となる表示専用コンポーネント。
## GameStateに依存せず、seed_inventoryとseed_mastersをsetup()で受け取る
## （ui-design/screens/garden.md「手持ちの種一覧」／plan.md参照）。

signal seed_plant_requested(seed_id: StringName)  # 🔵 US-001

const SeedEntryRowScene = preload("res://features/garden/ui/seed_entry_row.tscn")
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
		_add_entry_row(entry as Dictionary)


## 🔴 コードレビュー指摘対応（.new()からのシーン化）で新規追加。SeedEntryRowの@onready変数は
## add_child()によるシーンツリー追加後の_ready()で解決されるため、setup()は必ずadd_child()の
## 後に呼ぶ（先に呼ぶとラベル参照がnullのままクラッシュする）
func _add_entry_row(entry: Dictionary) -> void:
	var seed_id := StringName(entry.get("seed_id", &""))
	var count := int(entry.get("count", 0))

	var row: SeedEntryRow = SeedEntryRowScene.instantiate()
	row.name = "SeedEntry_%s" % seed_id
	_entry_container.add_child(row)
	row.setup(seed_id, _resolve_display_name(seed_id), count)
	row.plant_pressed.connect(_on_plant_pressed)


## seed_mastersにseed_idが存在しない場合（マスター未ロード等）でもクラッシュさせず、
## seed_id自体を表示名にフォールバックする。🔵 NFR-101
func _resolve_display_name(seed_id: StringName) -> String:
	var master: Variant = _seed_masters.get(seed_id)
	if master is SeedMaster:
		return (master as SeedMaster).name
	return String(seed_id)


func _on_plant_pressed(seed_id: StringName) -> void:
	seed_plant_requested.emit(seed_id)
