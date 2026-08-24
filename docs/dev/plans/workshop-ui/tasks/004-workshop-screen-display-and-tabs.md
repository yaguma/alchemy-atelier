---
id: "004"
title: "WorkshopScreenの表示基盤とタブ切替を実装する"
status: pending
priority: 2
dependencies: ["001", "003"]
estimated_complexity: medium
---

# Task: WorkshopScreenの表示基盤とタブ切替を実装する

## Goal

`WorkshopScreen`（`Control`継承）を新規作成し、`.tscn`にシーン全体の骨格（ゴールド表示・タブボタン2つ・`UpgradeItemList`2つ・トーストラベル・閉じるボタン、後続task向けのノードも含む）を配置する。`_refresh()`で`GameState.get_state()`を取得し、ゴールド表示・タブの活性/非活性・タブの排他表示切替・各`UpgradeItemList`へのフィルタ済みソート済み配列受け渡しを実装する（FR-001〜FR-006, FR-201〜FR-203, FR-105, FR-403）。購入フロー（task 005）・閉じるボタン（task 006）はこのタスクでは実装しない。

## Interfaces

```gdscript
# atelier/features/workshop/ui/workshop_screen.gd
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

@onready var _gold_label: Label = %GoldLabel                       # 🔵 txt-gold
@onready var _permanent_tab_button: Button = %PermanentTabButton   # 🔵 tab-permanent
@onready var _consumable_tab_button: Button = %ConsumableTabButton # 🔵 tab-consumable
@onready var _permanent_list: UpgradeItemList = %PermanentList     # 🔵
@onready var _consumable_list: UpgradeItemList = %ConsumableList   # 🔵
@onready var _close_button: Button = %CloseButton                  # 🔵 btn-close（本タスクでは未接続）
@onready var _toast_label: Label = %ToastLabel                     # 🔵（本タスクでは未使用、task 005で使用開始）

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
```

`.tscn`構造（想定、`unique_name_in_owner=true`を各ノードに設定）:
```
Control (WorkshopScreen)
└ VBoxContainer
   ├ HBoxContainer               # ヘッダー: タイトルLabel + %GoldLabel
   ├ HBoxContainer               # タブバー: %PermanentTabButton, %ConsumableTabButton
   ├ %PermanentList (UpgradeItemList instance, upgrade_item_list.tscn)
   ├ %ConsumableList (UpgradeItemList instance, upgrade_item_list.tscn)
   ├ %ToastLabel (Label)         # 本タスクでは空文字のまま、task 005で使用開始
   └ %CloseButton (Button)       # 本タスクでは未接続、task 006で接続する
```

## Test Strategy

`GdUnit4`の`scene_runner()`によるシーンレベル統合テスト。

- [ ] `GameState.reset_for_test()` → `load_workshop_master_data()`（または`_set_purchased_upgrade_counts_for_test`等でマスター注入）→ `_set_gold_for_test(1000)`した状態でシーンを起動すると、`%GoldLabel`が`"1000 G"`を表示する
- [ ] `can_purchase_permanent`がfalse（既定）の場合、初期表示は消耗投資タブが選択され（`get_active_tab() == &"consumable"`）、`%PermanentTabButton`が`disabled == true`になる
- [ ] `_set_can_purchase_permanent_for_test(true)`後にシーンを起動すると、初期表示は恒久投資タブが選択され（`get_active_tab() == &"permanent"`）、`%PermanentTabButton`が`disabled == false`になる
- [ ] `%ConsumableTabButton`を押下すると、`get_active_tab()`が`&"consumable"`になり`%ConsumableList.visible == true`かつ`%PermanentList.visible == false`になる
- [ ] `_set_can_purchase_permanent_for_test(true)`の状態で`%PermanentTabButton`を押下すると、タブが切り替わる（`get_active_tab() == &"permanent"`）
- [ ] `can_purchase_permanent`がfalseの間、`%PermanentTabButton`押下は無視される（disabledのため`_on_permanent_tab_pressed()`が呼ばれてもタブは切り替わらない、`get_active_tab()`が`&"consumable"`のまま）
- [ ] 恒久投資タブ（`is_permanent == true`）と消耗投資タブ（`is_permanent == false`）それぞれに、マスターデータの区分通りのアイテムだけが振り分けられる（`%PermanentList.get_entry_count()`/`%ConsumableList.get_entry_count()`が実データ5件の内訳と一致することを確認する）
- [ ] `_filter_and_sort()`（static関数の直接呼び出しで検証可）が、同一`is_permanent`区分内で価格降順に並べ、同価格の場合はid文字列昇順でタイブレークする
- [ ] 境界値: `upgrade_masters`が空Dictionaryの場合、`%PermanentList`/`%ConsumableList`とも`get_entry_count() == 0`でクラッシュしない

## Implementation Notes

- 参照すべき既存コード: `atelier/features/garden/ui/garden_screen.gd`（Screen層の`_refresh()`パターン、`@onready`宣言の並び）、`atelier/features/guild/ui/guild_delivery_screen.gd`（`_refresh_rank_quota()`のようなGameState参照ヘルパーの書き方）、`atelier/tests/integration/test_garden_screen.gd`（`scene_runner()`を使ったシーンテストの実例）
- 実装のヒント: `%PermanentList`/`%ConsumableList`は`upgrade_item_list.tscn`（task 003で作成済み）のインスタンスとして`.tscn`エディタ上に配置する。`GameState.gold_changed`等のsignal購読は行わない（本画面の操作以外でgoldが変わる経路が現状の本番コードパスに存在しないため、`_exit_tree()`での購読解除も不要）
- 注意事項: `apply_upgrade()`/`close_workshop()`の呼び出しはこのタスクでは実装しない。`%CloseButton`は`.tscn`に配置するが`_ready()`では接続しない（task 006で接続）。`%ToastLabel`は配置するが本タスクでは使用しない（task 005で`_show_toast()`を追加する際に使用開始）

## Files

- 新規: `atelier/features/workshop/ui/workshop_screen.gd`
- 新規: `atelier/features/workshop/ui/workshop_screen.tscn`
- テスト: `atelier/tests/integration/test_workshop_screen.gd`
