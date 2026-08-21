class_name MaterialEntryRow
extends HBoxContainer

## 素材在庫一覧の1行分を表示するコンポーネント。MaterialInventoryListから動的に生成・破棄される。
## garden/ui/seed_entry_row.gdと同型のパターン（専用シーン化＋setup()による値注入）に揃えている。

signal place_pressed(material_instance_id: String)

const NO_TRAIT_TEXT := "-"  # 🟡 特性なしを空欄と区別するための暫定表記（ui-design未確定）

var _material_instance_id: String = ""

@onready var _name_label: Label = %NameLabel
@onready var _quality_label: Label = %QualityLabel
@onready var _trait_label: Label = %TraitLabel
@onready var _place_button: Button = %PlaceButton


func _ready() -> void:
	_place_button.pressed.connect(_on_place_pressed)


## 素材1件の表示内容を設定する。add_child()後に呼ぶこと（@onready参照の解決後である必要がある）。🔵 US-001
## 🟡 名称はMaterialMasterによる解決を行わずmaterial_idをそのまま表示する（AlchemySlotViewと同方針）
func setup(material: MaterialInstance) -> void:
	_material_instance_id = material.instance_id
	_name_label.text = String(material.material_id)
	_quality_label.text = "Q%d" % material.quality_score
	_trait_label.text = format_traits(material.trait_tags)


## 特性タグ配列を表示文字列へ変換する。🔵 AC-004
static func format_traits(trait_tags: Array[StringName]) -> String:
	if trait_tags.is_empty():
		return NO_TRAIT_TEXT
	var tags: PackedStringArray = []
	for tag in trait_tags:
		tags.append(String(tag))
	return ", ".join(tags)


func _on_place_pressed() -> void:
	place_pressed.emit(_material_instance_id)
