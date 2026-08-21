class_name MaterialInventoryList
extends Control

## 在庫素材を一覧表示し、投入枠への配置操作の起点となる表示専用コンポーネント（US-001, AC-002, AC-004）。
## GameStateには依存せず、表示対象のMaterialInstance配列をsetup()で受け取る。
## 🟡 「投入済み素材の除外」は本コンポーネントでは行わない。投入済みはドメイン層にもGameStateにも
## 存在しないUIローカルな一時状態のため、呼び出し元（AlchemyScreen）が除外済み配列を渡す契約とする。

signal material_place_requested(material_instance_id: String)  # 🔵 FR-101

const MaterialEntryRowScene = preload("res://features/alchemy/ui/material_entry_row.tscn")
const ENTRY_SEPARATION := 8

var _materials: Array[MaterialInstance] = []

@onready var _entry_container: VBoxContainer = %EntryContainer


## 表示対象のMaterialInstance配列を受け取り一覧を再構築する。🔵 US-001
func setup(materials: Array[MaterialInstance]) -> void:
	_materials = materials
	_rebuild()


## 現在表示している素材エントリの件数を返す。🔵
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

	for material in _materials:
		if material == null:
			continue
		_add_entry_row(material)


# 🔵 MaterialEntryRowの@onready変数はadd_child()によるシーンツリー追加後の_ready()で解決されるため、
# setup()は必ずadd_child()の後に呼ぶ（先に呼ぶとラベル参照がnullのままクラッシュする）
func _add_entry_row(material: MaterialInstance) -> void:
	var row: MaterialEntryRow = MaterialEntryRowScene.instantiate()
	row.name = "MaterialEntry_%s" % material.instance_id
	_entry_container.add_child(row)
	row.setup(material)
	row.place_pressed.connect(_on_place_pressed)


func _on_place_pressed(material_instance_id: String) -> void:
	material_place_requested.emit(material_instance_id)
