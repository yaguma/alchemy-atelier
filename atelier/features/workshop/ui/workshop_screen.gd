class_name WorkshopScreen
extends Control

## 工房強化・ショップ画面本体。UpgradeItemList×2（恒久/消耗）・タブ切替・ゴールド表示を統合し、
## GameStateのsignalではなく都度get_state()のスナップショットのみで表示を構築する（CON-002）。
## 🔵 本タスクの完了をもって「購入フロー・閉じるボタンは別task」とするスコープ境界を厳守する。

signal screen_closed  # 🔵 FR-104（task 006で発行処理を実装する。シグナル自体は本タスクで宣言）

const TAB_PERMANENT: StringName = &"permanent"
const TAB_CONSUMABLE: StringName = &"consumable"

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
	_refresh()


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
