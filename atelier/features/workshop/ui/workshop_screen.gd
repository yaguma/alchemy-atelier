class_name WorkshopScreen
extends Control

## 工房強化・ショップ画面本体。UpgradeItemList×2（恒久/消耗）・タブ切替・ゴールド表示を統合し、
## GameStateのsignalではなく都度get_state()のスナップショットのみで表示を構築する（CON-002）。
## 🔵 本タスクの完了をもって「購入フロー・閉じるボタンは別task」とするスコープ境界を厳守する。

signal screen_closed  # 🔵 FR-104（task 006で発行処理を実装する。シグナル自体は本タスクで宣言）

const TAB_PERMANENT: StringName = &"permanent"
const TAB_CONSUMABLE: StringName = &"consumable"
const TOAST_PURCHASE_SUCCESS_FORMAT := "購入しました：%s"  # 🟡 文言は暫定
const TOAST_PURCHASE_FAILURE_FORMAT := "購入できませんでした（%s）"  # 🟡 文言は暫定。%sはResult.error_code

var _active_tab: StringName = TAB_CONSUMABLE  # 🟡 既定値。初回_refresh()で状態に応じ上書きされうる
var _has_refreshed_once: bool = false  # 🟡 初期タブ選択を「初回表示時のみ」に限定するためのガード

@onready var _gold_label: Label = %GoldLabel  # 🔵 txt-gold
@onready var _permanent_tab_button: Button = %PermanentTabButton  # 🔵 tab-permanent
@onready var _consumable_tab_button: Button = %ConsumableTabButton  # 🔵 tab-consumable
@onready var _permanent_list: UpgradeItemList = %PermanentList  # 🔵
@onready var _consumable_list: UpgradeItemList = %ConsumableList  # 🔵
@onready var _close_button: Button = %CloseButton  # 🔵 btn-close（本タスクでは未接続）
@onready var _toast_label: Label = %ToastLabel  # 🔵（本タスクでは未使用、task 005で使用開始）


func _ready() -> void:
	_permanent_tab_button.pressed.connect(_on_permanent_tab_pressed)
	_consumable_tab_button.pressed.connect(_on_consumable_tab_pressed)
	# 🔵 本タスクで追加: 両リストからの購入要求を受ける
	_permanent_list.purchase_requested.connect(_on_purchase_requested)
	_consumable_list.purchase_requested.connect(_on_purchase_requested)
	_close_button.pressed.connect(_on_close_pressed)  # 🔵 本タスクで追加
	_refresh()


## 現在表示中のトーストメッセージを返す（テスト用）。🔵 GardenScreen.get_toast_text()踏襲
func get_toast_text() -> String:
	if _toast_label == null:
		return ""
	return _toast_label.text


## GameState.get_state()を再取得し、ゴールド表示・タブ活性/非活性・両リストを再構築する。🔵 FR-105
func _refresh() -> void:
	if _permanent_list == null:
		return

	var state := GameState.get_state()
	var gold: int = state["gold"]
	var upgrade_masters: Dictionary = state["upgrade_masters"]
	var purchased_counts: Dictionary = state["purchased_upgrade_counts"]
	var can_purchase_permanent: bool = state["can_purchase_permanent"]

	_gold_label.text = "%d G" % gold

	_permanent_tab_button.disabled = not can_purchase_permanent  # 🔵 FR-201, FR-202

	# 🟡 初回表示時のみ、can_purchase_permanentに応じて初期選択タブを決める
	# （workshop-shop.md「昇格直後の強制表示状態」で恒久投資タブが活性化する記述からの推測）。
	# 2回目以降のリフレッシュ（購入後の再構築等）ではプレイヤーが選択中のタブを維持する
	if not _has_refreshed_once:
		_active_tab = TAB_PERMANENT if can_purchase_permanent else TAB_CONSUMABLE
		_has_refreshed_once = true
	elif not can_purchase_permanent and _active_tab == TAB_PERMANENT:
		# 🟡 表示中に非活性化された場合（close_workshop()後の再構築等）、非活性タブに
		# 留まらせない防御的フォールバック
		_active_tab = TAB_CONSUMABLE

	_update_tab_visibility()

	var permanent_upgrades := _filter_and_sort(upgrade_masters.values(), true)
	var consumable_upgrades := _filter_and_sort(upgrade_masters.values(), false)

	_permanent_list.setup(permanent_upgrades, gold, purchased_counts, not can_purchase_permanent)
	_consumable_list.setup(consumable_upgrades, gold, purchased_counts, false)  # 🔵 FR-203常時活性


func _update_tab_visibility() -> void:
	_permanent_list.visible = _active_tab == TAB_PERMANENT
	_consumable_list.visible = _active_tab == TAB_CONSUMABLE


## FR-004: is_permanentで絞り込み、price降順→id昇順でソートする。🔵 挙動自体は要件確定。
## Presentation層内に閉じる先出し処理として静的関数に切り出す（architecture.md
## 「Presentationは先出しフィードバックのみ」に整合、Domain層には置かない）
static func _filter_and_sort(upgrades: Array, want_permanent: bool) -> Array[UpgradeMaster]:
	var filtered: Array[UpgradeMaster] = []
	for u: Variant in upgrades:
		if u is UpgradeMaster and (u as UpgradeMaster).is_permanent == want_permanent:
			filtered.append(u as UpgradeMaster)
	filtered.sort_custom(_compare_upgrades)
	return filtered


static func _compare_upgrades(a: UpgradeMaster, b: UpgradeMaster) -> bool:
	if a.price != b.price:
		return a.price > b.price
	return String(a.id) < String(b.id)


func _on_permanent_tab_pressed() -> void:
	if _permanent_tab_button.disabled:
		return
	_active_tab = TAB_PERMANENT
	_update_tab_visibility()


func _on_consumable_tab_pressed() -> void:
	_active_tab = TAB_CONSUMABLE
	_update_tab_visibility()


## 現在表示中のタブを返す（テスト用）。🟡 GardenScreen.get_toast_text()同様のテスト用ゲッター新規補完
func get_active_tab() -> StringName:
	return _active_tab


## FR-101: 購入要求を受けてGameState.apply_upgrade()を呼び出す。
## upgrade_idからUpgradeMasterへの解決に失敗した場合（マスター未登録ID）は状態変更を一切行わず
## 早期returnする（🟡 UpgradeItemList/UpgradeItemRowは常にGameState.get_state()由来の
## upgrade.idしか発行しないため実運用では起こらないが、防御的分岐として残す）
func _on_purchase_requested(upgrade_id: StringName) -> void:
	var state := GameState.get_state()
	var upgrade_masters: Dictionary = state["upgrade_masters"]
	var upgrade: Variant = upgrade_masters.get(upgrade_id)
	if not (upgrade is UpgradeMaster):
		return

	var result := GameState.apply_upgrade(upgrade as UpgradeMaster)
	if result.success:
		_refresh()  # 🔵 FR-102
		_show_toast(TOAST_PURCHASE_SUCCESS_FORMAT % (upgrade as UpgradeMaster).name)
	else:
		_show_toast(TOAST_PURCHASE_FAILURE_FORMAT % result.error_code)  # 🔵 FR-103


func _show_toast(message: String) -> void:
	if _toast_label == null:
		return
	_toast_label.text = message


## FR-104: close_workshop()呼び出し後にscreen_closedを発行する。
## close_workshop()は_can_purchase_permanentをfalseに戻すだけの冪等操作のため、
## 通常アクセス状態（既にfalse）で呼んでも副作用はない（design doc「閉じるボタンは
## 恒久投資強制表示時も含め常に閉じる/次へとして機能する」に対応）。
## 🔴 コードレビュー指摘対応。_refresh()を挟まないと、MainScene常駐+visible切替パターンで
## 本画面が再表示された際にタブのdisabled状態が古いまま（can_purchase_permanentがtrueだった
## 頃の表示）になりうるため、close_workshop()直後に_refresh()して表示を最新化してからemitする
func _on_close_pressed() -> void:  # 🟡 FR-104
	GameState.close_workshop()
	_refresh()
	screen_closed.emit()
