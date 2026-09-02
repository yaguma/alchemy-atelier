class_name SlotSelectScreen
extends Control

## 🔵 3固定スロットの状況（新規/続き/破損）を提示し、選択されたスロットを
## SaveService.select_slot_and_restore()へ渡してからmain.tscnへ遷移する画面。
## 実際の復元（GameStateへの適用）はマスターデータロード後にMainSceneが
## SaveService.apply_pending_restore()を呼んで行うため、本画面は選択までを担う。

## 🔵 破損スロット選択時の観測点。UIテストおよび将来の警告演出の接続先。
signal slot_selection_failed(slot: int, error_code: StringName)

const MAIN_SCENE_PATH := "res://scenes/main.tscn"

## 🟡 文言は暫定（正式なコピーライティングは未確定）。
const LABEL_NEW_GAME := "新規開始"
const LABEL_CONTINUE_FORMAT := "つづきから（%s / %d G / %dターン / %s）"
## 🟡 破損時のUX方針: 選択自体は許可し、新規ゲーム扱いでそのスロットを上書きさせる。
## 「破損スロットを選ばせない」方針とどちらを採るかは要再確認事項。
const LABEL_CORRUPTED := "セーブデータが壊れています（新規開始で上書き）"
const SLOT_BUTTON_TEXT_FORMAT := "スロット %d"

## 🟡 スロット確定後にmain.tscnへ遷移するか。統合テストでは実際のシーン差し替えが
## テストランナー自身のcurrent_sceneを巻き込むため、テスト側でfalseにして選択結果のみ検証する。
var scene_transition_enabled: bool = true

var _transition_requested: bool = false
var _slot_buttons: Array[Button] = []
var _slot_info_labels: Array[Label] = []

@onready var _slot_container: VBoxContainer = %SlotContainer


func _ready() -> void:
	_build_slot_rows()
	_refresh_slot_buttons()


## 🔵 slotに対応する選択ボタンを返す（テスト・外部からの操作用）。範囲外はnull。
func get_slot_button(slot: int) -> Button:
	if slot < 0 or slot >= _slot_buttons.size():
		return null
	return _slot_buttons[slot]


## 🔵 slotに対応する情報ラベルの表示文字列を返す（テスト用の観測点）。範囲外は空文字。
func get_slot_info_text(slot: int) -> String:
	if slot < 0 or slot >= _slot_info_labels.size():
		return ""
	return _slot_info_labels[slot].text


## 🔵 main.tscnへの遷移が要求済みかを返す。破損スロット選択で遷移しないことの検証点。
func has_requested_transition() -> bool:
	return _transition_requested


## 🔵 SaveService.get_slot_summary()を全スロット分取得し、各行の表示へ反映する。
func _refresh_slot_buttons() -> void:
	for slot in range(_slot_info_labels.size()):
		_slot_info_labels[slot].text = _format_summary(SaveService.get_slot_summary(slot))


## SLOT_COUNT分の「ボタン＋情報ラベル」の行を生成する。
## スロット数はSaveService.SLOT_COUNTを単一の情報源とするため、.tscn側には置かない。
func _build_slot_rows() -> void:
	for slot in range(SaveService.SLOT_COUNT):
		var row := HBoxContainer.new()
		row.name = "SlotRow%d" % slot

		var button := Button.new()
		button.name = "SlotButton%d" % slot
		button.text = SLOT_BUTTON_TEXT_FORMAT % (slot + 1)
		button.pressed.connect(_on_slot_button_pressed.bind(slot))
		row.add_child(button)

		var info_label := Label.new()
		info_label.name = "SlotInfoLabel%d" % slot
		row.add_child(info_label)

		_slot_container.add_child(row)
		_slot_buttons.append(button)
		_slot_info_labels.append(info_label)


static func _format_summary(summary: SaveSlotSummary) -> String:
	if summary.is_empty:
		return LABEL_NEW_GAME
	if summary.is_corrupted:
		return LABEL_CORRUPTED
	return (
		LABEL_CONTINUE_FORMAT
		% [
			summary.current_rank_id,
			summary.gold,
			summary.current_turn,
			Time.get_datetime_string_from_unix_time(summary.saved_at_unix, true),
		]
	)


## 🔵 選択スロットをSaveServiceへ確定させ、成功時のみmain.tscnへ遷移する。
## 破損（ERROR_SAVE_DATA_CORRUPTED）時は遷移せず、シグナル発行のうえ表示を作り直して留まる。
func _on_slot_button_pressed(slot: int) -> void:
	var result: Result = SaveService.select_slot_and_restore(slot)
	if not result.success:
		slot_selection_failed.emit(slot, result.error_code)
		_refresh_slot_buttons()
		return

	_transition_requested = true
	if scene_transition_enabled:
		get_tree().change_scene_to_file.call_deferred(MAIN_SCENE_PATH)
