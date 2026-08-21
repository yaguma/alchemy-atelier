---
id: "005"
title: "AlchemyScreen（調合画面本体）を実装する"
status: pending
priority: 4
dependencies: ["001", "002", "003", "004"]
estimated_complexity: high
---

# Task: AlchemyScreen（調合画面本体）を実装する

## Goal

`AlchemySlotView`・`MaterialInventoryList`・`AlchemyPreviewPanel`・レシピ選択（`OptionButton`）・調合実行/ターン終了/ショップボタンを統合した`AlchemyScreen`を実装する。`GameState`のsignalを購読して画面を更新し、単体（`MainScene`非組み込み）でGdUnit4シーンテストによりレシピ選択→投入→プレビュー確認→調合実行の一連フローが検証できる状態にする（US-001〜US-203, US-301〜US-302, AC-001, AC-004〜AC-014）。

## Interfaces

```gdscript
# atelier/features/alchemy/ui/alchemy_screen.gd
class_name AlchemyScreen
extends Control

signal shop_requested  # 🔵 FR-110（プレースホルダー導線。GardenScreen.shop_requested踏襲）

const AlchemySlotViewScene = preload("res://features/alchemy/ui/alchemy_slot_view.tscn")

var _slot_state: SlotState = SlotState.new()
var _placed_material_ids: Array[String] = []      # 🔵 投入順=スロット表示順の唯一のソース・オブ・トゥルース
var _recipe_masters: Dictionary = {}                # 🔵 StringName -> RecipeMaster、get_state()から都度キャッシュ
var _inventory: Array[MaterialInstance] = []        # 🔵 get_state()から都度キャッシュ
var _slot_views: Array[AlchemySlotView] = []

@onready var _recipe_option_button: OptionButton = %RecipeOptionButton
@onready var _slots_container: Container = %SlotsContainer
@onready var _material_inventory_list: MaterialInventoryList = %MaterialInventoryList
@onready var _preview_panel: AlchemyPreviewPanel = %AlchemyPreviewPanel
@onready var _execute_button: Button = %ExecuteButton
@onready var _end_turn_button: Button = %EndTurnButton
@onready var _shop_button: Button = %ShopButton
@onready var _toast_label: Label = %ToastLabel

func _ready() -> void:
	pass

func _exit_tree() -> void:
	pass

## GameState.get_state()を再取得し、レシピ一覧・スロット一覧・在庫一覧・プレビューを再構築する 🔵
func _refresh() -> void:
	pass

## ローカルキャッシュのみでプレビュー再計算とボタン活性状態を更新する（GameStateへ問い合わせない） 🟡
func _on_preview_inputs_changed() -> void:
	pass

## QualityCalculator -> TraitActivation -> ProductValueCalculator -> DeliveryResolver の
## 4段階パイプラインを同期呼び出しし、AlchemyPreviewPanel.show_preview()/show_empty()を呼ぶ 🔵
func _recompute_preview(materials: Array[MaterialInstance]) -> void:
	pass

func get_toast_text() -> String:  # テスト用。GardenScreen.get_toast_text()踏襲 🔵
	pass
```

## Test Strategy

GdUnit4の`scene_runner("res://features/alchemy/ui/alchemy_screen.tscn")`を用いたシーンテスト（`.claude/rules/testing.md`「E2E相当のテスト」参照）:

- [ ] **正常系（レシピ選択〜プレビュー）**: レシピを選択し在庫カードを1件クリックすると投入枠へ配置され、プレビューパネルに`QualityCalculator`〜`DeliveryResolver`の計算結果が反映される（AC-004, AC-007, US-001, US-101）
- [ ] **正常系（投入取り消し）**: 投入済み枠のクリアボタン押下で素材が在庫へ戻り、在庫一覧に再表示される（AC-005, US-002）
- [ ] **正常系（調合実行成功）**: レシピ選択・1件以上投入済みの状態で「調合実行」ボタンを押下すると`GameState.execute_alchemy()`が呼ばれ、`product_crafted`受信後に投入枠がリセットされ在庫が再取得され、完了トーストが表示される（AC-008, US-201）
- [ ] **異常系（調合実行失敗）**: `execute_alchemy_failed`シグナル受信時、`error_code`（`unknown_recipe_id`/`recipe_not_unlocked`/`material_not_owned`/`duplicate_material_in_slot`/`slot_execution_invalid`のいずれか）に応じたメッセージがトースト表示され、投入枠・在庫が変更されない（AC-009, US-202）
- [ ] **境界値（ボタン活性制御）**: レシピ未選択、または投入0個の間は「調合実行」ボタンが無効化され、レシピ選択済み・1件以上投入で活性化する（AC-010, US-203）
- [ ] **境界値（投入枠上限）**: 投入枠が全て埋まっている状態で追加の在庫クリックをしても新規配置が発生しない（AC-004異常系, US-004）
- [ ] **正常系（ターン終了）**: 「ターンを終了する」ボタン押下で`GameState.deliver_pending_products()`が呼ばれ、`delivered`受信後に納品完了トーストが表示される（AC-011, US-301）
- [ ] **正常系（ショップ導線）**: 「ショップ」ボタン押下で`shop_requested`シグナルが発行され、`GameState`の状態は変化しない（AC-012, US-302）
- [ ] **保守性確認（禁止要件）**: `AlchemyScreen`のソースに`_get_drag_data()`/`_drop_data()`のオーバーライド、`deliver_pending_products()`呼び出しを含む「調合実行」ハンドラ、`change_scene_to_file()`呼び出し、未発現特性の残り必要数算出ロジック、`main.tscn`への配線・タブ切り替えUIのいずれも存在しないことを`grep`で確認する（AC-013）
- [ ] **signal購読解除確認**: `AlchemyScreen`を`queue_free()`で破棄後に`GameState`の各シグナル（`product_crafted`, `execute_alchemy_failed`, `delivered`）を発行しても例外・警告が発生しない（AC-014）

## Implementation Notes

- 参照すべき既存コード: `atelier/features/garden/ui/garden_screen.gd`（`_ready()`でのsignal購読・`_exit_tree()`での`disconnect()`パターン、`_refresh()`パターン）、`docs/design/atelier-alchemy-core/ui-design/screens/alchemy.md`（画面構成・イベント一覧）、`atelier/autoload/game_state_alchemy_delegate.gd`（`execute_alchemy`のエラーコード一覧: `unknown_recipe_id`, `recipe_not_unlocked`, `material_not_owned`, `duplicate_material_in_slot`, `slot_execution_invalid`）
- 実装のヒント:
  - `_ready()`で`GameState.product_crafted` / `execute_alchemy_failed` / `delivered`の3signalを購読し、`_exit_tree()`で`is_connected()`確認の上`disconnect()`する（`GameState`はAutoloadのため必須）
  - `_recompute_preview()`は`_slot_state.selected_recipe_id == &""`または`materials.is_empty()`の場合`_preview_panel.show_empty()`を呼ぶだけで計算を行わない（AC-007異常系）。それ以外は`GameState.is_current_rank_traits_unlocked()`（タスク001）を取得し、`QualityCalculator.calculate_quality` → `QualityCalculator.quality_multiplier` → `TraitActivation.resolve_traits` → `ProductValueCalculator.calculate_contribution/calculate_reward`（`ProductValueCalculator.resolve_contribution_bonus/resolve_reward_bonus`経由）→ `ProductInstance.new(...)`を仮組み → `DeliveryResolver.resolve(provisional, GameState.get_state()["current_daily_order"])`の順で呼び出し、結果を`_preview_panel.show_preview()`へ渡す
  - `_on_material_place_requested(material_instance_id)`は`_placed_material_ids.size() >= _slot_state.max_slots`（FR-203）または既に含まれる場合（二重投入防御）は何もしない
  - `_on_execute_pressed()`は`GameState.execute_alchemy(_slot_state.selected_recipe_id, _placed_material_ids.duplicate())`のみを呼び、戻り値の`Result`は使わない（結果は`product_crafted`/`execute_alchemy_failed`シグナル経由でのみ処理する。`GardenScreen._on_seed_plant_requested()`と同一パターン）
  - `_on_end_turn_pressed()`は`GameState.deliver_pending_products()`のみを呼ぶ（`advance_turn_growth()`等は呼ばない。FR-108のプレースホルダー実装であることを厳守）
  - `_recipe_option_button`のitem 0は「選択してください」プレースホルダー（`disabled`かつ`set_item_metadata`なし）とし、`_on_recipe_selected(index)`は`index <= 0`の場合は何もしない
- 注意事項: 本タスクの完了をもって「MainSceneへの組み込みは別task」（FR-405, CON-005）とするスコープ境界を厳守する。`AlchemyScreen`単体の`.tscn`をGdUnit4の`scene_runner()`でロードしてテストが通ることを完了条件とし、`MainScene`側のタブ切替・`visible`制御は一切実装しない。`GameState.deliver_pending_products()`と「調合実行」ボタンのハンドラを混同しないこと（FR-402で明示的に禁止）

## Files

- 新規: `atelier/features/alchemy/ui/alchemy_screen.gd`
- 新規: `atelier/features/alchemy/ui/alchemy_screen.tscn`
- テスト: `atelier/tests/integration/test_alchemy_screen.gd`
