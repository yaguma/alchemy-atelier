class_name AlchemySlotView
extends Control

## 調合の投入枠1件を表示する表示専用コンポーネント（AC-003, AC-005）。
## 空き/投入済みの2状態を色とテキストの併記で表示し、投入済み枠のみクリア操作を受け付ける。
## GameStateには依存せず、MaterialInstanceをsetup()で直接受け取る（表示専用の読み取りのみ）。

signal clear_requested(slot_index: int)  # 🔵 FR-102

enum Status { EMPTY, FILLED }

const STATUS_TEXTS := {
	Status.EMPTY: "空き",
	Status.FILLED: "投入済み",
}  # 🟡 ui-design/screens/alchemy.mdが未作成のため、FR-102の状態名から妥当な推測で新規決定

var _slot_index: int = -1
var _status: Status = Status.EMPTY
var _material_text: String = ""

@onready var _status_label: Label = %StatusLabel
@onready var _material_label: Label = %MaterialLabel
@onready var _clear_button: Button = %ClearButton


func _ready() -> void:
	_clear_button.pressed.connect(_on_clear_pressed)
	_apply_display()


## 空きスロットとして表示する。🔵 FR-102
func setup_empty(slot_index: int) -> void:
	_slot_index = slot_index
	_status = Status.EMPTY
	_material_text = ""
	_apply_display()


## 投入済みスロットとして表示する。material_idを暫定名称としてそのまま表示する。
## 🟡 MaterialMaster辞書がGameState.get_state()に未公開のため、本Planでは名称解決を行わない
func setup(slot_index: int, material: MaterialInstance) -> void:
	_slot_index = slot_index
	_status = Status.FILLED
	_material_text = format_material(material)
	_apply_display()


## 現在の表示状態を返す。🔵
func get_status() -> Status:
	return _status


## 現在表示中のスロット番号を返す。🔵
func get_slot_index() -> int:
	return _slot_index


## 状態に対応する表示テキストを返す。🔵 NFR-201（色以外でも判別可能にするため）
static func status_text(status: Status) -> String:
	return STATUS_TEXTS[status]


## 状態に対応する表示色を返す。🔵 NFR-201
static func status_color(status: Status) -> Color:
	match status:
		Status.EMPTY:
			return UiTheme.COLOR_ALCHEMY_SLOT_EMPTY
		_:
			return UiTheme.COLOR_ALCHEMY_SLOT_FILLED


## 投入素材の表示文字列を組み立てる。🟡 material_idを暫定名称として使う（名称解決はスコープ外）
static func format_material(material: MaterialInstance) -> String:
	var text := "%s Q%d" % [String(material.material_id), material.quality_score]
	if material.trait_tags.is_empty():
		return text
	var tags: PackedStringArray = []
	for tag in material.trait_tags:
		tags.append(String(tag))
	return "%s [%s]" % [text, ", ".join(tags)]


func _apply_display() -> void:
	if _status_label == null:
		return
	_status_label.text = status_text(_status)
	_material_label.text = _material_text
	self_modulate = status_color(_status)
	_clear_button.disabled = _status == Status.EMPTY


# 🔵 空き枠のクリアは無効操作のため、ボタンのdisabledに加えて発行側でもガードする
func _on_clear_pressed() -> void:
	if _status == Status.EMPTY:
		return
	clear_requested.emit(_slot_index)
