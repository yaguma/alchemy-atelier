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
@onready var _empty_state_label: Label = %EmptyStateLabel


## 表示対象のMaterialInstance配列を受け取り一覧を再構築する。🔵 US-001
func setup(materials: Array[MaterialInstance]) -> void:
	_materials = materials
	_rebuild()


## 現在表示している素材エントリの件数を返す。🔵
func get_entry_count() -> int:
	if _entry_container == null:
		return 0
	return _entry_container.get_child_count()


## instance_idに対応する在庫行のglobal_positionを返す。🔵 ui-polish Plan タスク006。
## 見つからない場合（行が既に破棄済み等）はリスト自体のglobal_positionをフォールバック値として返す
func find_row_global_position(instance_id: String) -> Vector2:
	if _entry_container == null:
		return global_position
	var row := _entry_container.get_node_or_null("MaterialEntry_%s" % instance_id)
	if row is Control:
		return (row as Control).global_position
	return global_position


## 🔴 コードレビュー指摘対応。MaterialInventoryListはextends Controlであり、素のControlの
## get_minimum_size()は常に(0,0)を返す（子の内容を自動集計しない）。alchemy_screen.tscnの
## 親VBoxContainerはこれをそのまま採用し本コンポーネントの行を0高さにしてしまい、
## _entry_container内の実際の在庫行は表示上あふれ出るだけで、行の確保領域自体は0のまま
## 直前のAlchemyPreviewPanel等とほぼ同じY座標に重なって描画される不具合があった
## （plant_slot_view.gdと同根）。在庫あり時は_entry_container、空状態時は_empty_state_labelの
## どちらか大きい方を転送する（どちらが表示中でも親に正しい行高を伝えるため、可視状態で分岐せず
## 常にmaxを取る）
func _get_minimum_size() -> Vector2:
	if _entry_container == null or _empty_state_label == null:
		return Vector2.ZERO
	var entry_min := _entry_container.get_combined_minimum_size()
	var empty_min := _empty_state_label.get_combined_minimum_size()
	return Vector2(maxf(entry_min.x, empty_min.x), maxf(entry_min.y, empty_min.y))


func _ready() -> void:
	_entry_container.add_theme_constant_override("separation", ENTRY_SEPARATION)
	UiTheme.apply_pixel_font(_empty_state_label)
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

	_empty_state_label.visible = _entry_container.get_child_count() == 0


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
