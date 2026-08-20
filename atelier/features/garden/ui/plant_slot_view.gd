class_name PlantSlotView
extends Control

## 庭の1スロットを表示する表示専用コンポーネント（FR-201〜204, NFR-201, AC-010）。
## 空き/生育中/収穫可能/枯死警告の4状態を色・アイコン・テキストの併記で表示する。
## GameStateには依存せず、PlantState/SeedMasterをsetup()で直接受け取る（表示専用の読み取りのみ）。

signal harvest_pressed(slot_index: int)  # 🔵 US-004
signal wait_pressed(slot_index: int)  # 🟡 FR-302（任意要件、実質何もしない操作の明示ボタン）

# 🔵 FR-201〜204の4状態 + 🔴 DATA_ERRORはコードレビュー指摘対応で新規追加
enum Status { EMPTY, GROWING, HARVESTABLE, WITHER_WARNING, DATA_ERROR }

const STATUS_TEXTS := {
	Status.EMPTY: "空き",
	Status.GROWING: "生育中",
	Status.HARVESTABLE: "収穫可能",
	Status.WITHER_WARNING: "枯死警告",
	Status.DATA_ERROR: "データ異常",
}  # 🟡 ui-design/screens/garden.mdが未作成のため、FR-201〜204の状態名から妥当な推測で新規決定

const STATUS_ICONS := {
	Status.EMPTY: "➕",
	Status.GROWING: "🌱",
	Status.HARVESTABLE: "🌾",
	Status.WITHER_WARNING: "⚠",
	Status.DATA_ERROR: "❓",
}  # 🟡 NFR-201（色以外でも判別可能）を満たすためのアイコン割り当て、具体的な絵柄は暫定案

var _slot_index: int = -1
var _status: Status = Status.EMPTY
var _harvest_enabled: bool = false

@onready var _status_label: Label = %StatusLabel
@onready var _status_icon: Label = %StatusIcon
@onready var _harvest_button: Button = %HarvestButton
@onready var _wait_button: Button = %WaitButton


func _ready() -> void:
	_harvest_button.pressed.connect(_on_harvest_pressed)
	_wait_button.pressed.connect(_on_wait_pressed)
	_apply_display()


## 空きスロットとして表示する。🔵 FR-201
func setup_empty(slot_index: int) -> void:
	_slot_index = slot_index
	_status = Status.EMPTY
	_harvest_enabled = false
	_apply_display()


## SeedMasterが欠落した占有スロットとして表示する（コードレビュー指摘対応で新規追加）。
## 🔴 GameState.harvest()が同状況をmaster_data_missingという専用エラーで区別しているのに、
## GardenScreen側がsetup_empty()で「空き」表示していたバグの修正。株は存在するが情報を
## 解決できないため、植付可能な空きとは区別し収穫も待機も不可とする
func setup_data_error(slot_index: int) -> void:
	_slot_index = slot_index
	_status = Status.DATA_ERROR
	_harvest_enabled = false
	_apply_display()


## PlantState/SeedMasterを基に4状態のいずれかを算出し表示する。
## 🟡 UI層からDomain層static funcを直接呼ぶ設計（表示専用の読み取りのみ、状態変更を伴わないため
## architecture.md「Presentation層→Domain層参照可」に合致すると判断）
func setup(plant: PlantState, master: SeedMaster) -> void:
	_slot_index = plant.slot_index
	_status = _resolve_status(plant, master)
	var status_allows_harvest := _status != Status.EMPTY and _status != Status.GROWING
	_harvest_enabled = status_allows_harvest and not Harvest.is_dead(plant, master)
	_apply_display()


## 現在の表示状態を返す。🔵
func get_status() -> Status:
	return _status


## 現在表示中のスロット番号を返す。🔵
func get_slot_index() -> int:
	return _slot_index


## 収穫ボタンが有効な状態かどうかを返す。🔵 FR-203
func is_harvest_enabled() -> bool:
	return _harvest_enabled


## 状態に対応する表示テキストを返す。🔵 NFR-201
static func status_text(status: Status) -> String:
	return STATUS_TEXTS[status]


## 状態に対応するアイコン文字を返す。🔵 NFR-201
static func status_icon(status: Status) -> String:
	return STATUS_ICONS[status]


## 状態に対応する表示色を返す。🔵 NFR-201
static func status_color(status: Status) -> Color:
	match status:
		Status.EMPTY:
			return UiTheme.COLOR_SLOT_EMPTY
		Status.GROWING:
			return UiTheme.COLOR_SLOT_GROWING
		Status.HARVESTABLE:
			return UiTheme.COLOR_SLOT_HARVESTABLE
		Status.DATA_ERROR:
			return UiTheme.COLOR_SLOT_DATA_ERROR
		_:
			return UiTheme.COLOR_SLOT_WITHER_WARNING


## 成熟までの残りターン数を返す（0未満にはならない）。🔵
static func remaining_growth_turns(plant: PlantState, master: SeedMaster) -> int:
	return maxi(0, master.maturity_turns - plant.grown_turns)


## 枯死までの残りターン数を返す（0未満にはならない）。🔵 FR-204
static func remaining_wither_turns(plant: PlantState, master: SeedMaster) -> int:
	var waited_turns := plant.grown_turns - master.maturity_turns
	return maxi(0, master.death_grace_turns - waited_turns)


## 成熟済みの株について、既に枯死しているか枯死警告閾値以下かを判定してWITHER_WARNINGを返す。
## 未成熟ならGROWING、成熟済みで警告閾値より残りターンがあればHARVESTABLEを返す。🔵 FR-202〜204
func _resolve_status(plant: PlantState, master: SeedMaster) -> Status:
	if not Harvest.is_matured(plant, master):
		return Status.GROWING
	if Harvest.is_dead(plant, master):
		return Status.WITHER_WARNING
	if remaining_wither_turns(plant, master) <= GameBalance.WITHER_WARNING_REMAINING_TURNS:
		return Status.WITHER_WARNING
	return Status.HARVESTABLE


func _apply_display() -> void:
	if _status_label == null:
		return
	_status_label.text = status_text(_status)
	_status_icon.text = status_icon(_status)
	self_modulate = status_color(_status)
	_harvest_button.disabled = not _harvest_enabled


func _on_harvest_pressed() -> void:
	harvest_pressed.emit(_slot_index)


func _on_wait_pressed() -> void:
	wait_pressed.emit(_slot_index)
