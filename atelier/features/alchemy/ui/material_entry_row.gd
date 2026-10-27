class_name MaterialEntryRow
extends PanelContainer

## 素材在庫一覧の1行分を表示するコンポーネント。MaterialInventoryListから動的に生成・破棄される。
## garden/ui/seed_entry_row.gdと同型のパターン（専用シーン化＋setup()による値注入）に揃えている。
## 🟡 garden-alchemy-visual-refresh Planタスク008。root型をHBoxContainerからPanelContainerへ変更し、
## UiTheme共通カードパネルスタイルボックスを適用してカード化する（実際の横並びレイアウトは
## 内側のContent（HBoxContainer）が担う）

signal place_pressed(material_instance_id: String)

const NO_TRAIT_TEXT := "-"  # 🟡 特性なしを空欄と区別するための暫定表記（ui-design未確定）
const FRESHNESS_TEXT_FORMAT := "劣化まで%dT"  # 🟡 Issue #64。ui-design未確定の暫定表記
# 🟡 PR #72レビュー指摘対応。品質1の素材は次の劣化タイミングで品質が下がるのではなく腐敗して
# 在庫から消えるため、「劣化まで」では失う重さが伝わらない。表記を分ける（ui-design未確定の暫定表記）
const ROT_TEXT_FORMAT := "腐敗まで%dT"
const FRESHNESS_WARNING_TURNS := 1  # 🟡 この残りターン以下なら次のターン終了で劣化するため警告色にする
const NO_DECAY := -1

var _material_instance_id: String = ""

@onready var _name_label: Label = %NameLabel
@onready var _quality_label: Label = %QualityLabel
@onready var _trait_label: Label = %TraitLabel
@onready var _freshness_label: Label = %FreshnessLabel
@onready var _place_button: Button = %PlaceButton


# 🔵 PlaceButtonは「素材を調合枠へ配置する」操作であり、調合フェーズの確定操作である
# ExecuteButton（PRIMARY）とは区別する。garden/ui/seed_entry_row.gdのPlantButton
# （種を庭スロットへ配置する、同じく「スロットへの配置」操作）とSECONDARYで揃える
func _ready() -> void:
	UiTheme.apply_panel_style(self)
	ButtonStyleApplier.apply_button_style(_place_button, UiTheme.ButtonVariant.SECONDARY)
	UiTheme.apply_pixel_font(_place_button)
	for label: Label in [_name_label, _quality_label, _trait_label, _freshness_label]:
		UiTheme.apply_pixel_font(label)
	_place_button.pressed.connect(_on_place_pressed)


## 素材1件の表示内容を設定する。add_child()後に呼ぶこと（@onready参照の解決後である必要がある）。🔵 US-001
## 🟡 名称はMaterialMasterによる解決を行わずmaterial_idをそのまま表示する（AlchemySlotViewと同方針）
## turns_until_decayは次の劣化までの残りターン（🔵 Issue #64、FR-711-007）。劣化しない素材は-1で、鮮度ラベルを出さない
func setup(material: MaterialInstance, turns_until_decay: int = NO_DECAY) -> void:
	_material_instance_id = material.instance_id
	_name_label.text = String(material.material_id)
	_quality_label.text = "Q%d" % material.quality_score
	_trait_label.text = format_traits(material.trait_tags)
	_apply_freshness(material, turns_until_decay)


func _apply_freshness(material: MaterialInstance, turns_until_decay: int) -> void:
	_freshness_label.visible = turns_until_decay >= 0
	if not _freshness_label.visible:
		return
	var text_format := (
		ROT_TEXT_FORMAT if FreshnessResolver.rots_at_next_decay(material) else FRESHNESS_TEXT_FORMAT
	)
	_freshness_label.text = text_format % turns_until_decay
	var color := (
		UiTheme.COLOR_FRESHNESS_DECAY_SOON
		if turns_until_decay <= FRESHNESS_WARNING_TURNS
		else UiTheme.COLOR_FRESHNESS_NORMAL
	)
	_freshness_label.add_theme_color_override("font_color", color)


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
