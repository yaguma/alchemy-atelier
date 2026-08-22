---
id: "003"
title: "GuildDeliveryScreen（納品結果リスト・合計値・ノルマバー・閉じるボタン）を実装する"
status: pending
priority: 2
dependencies: ["001", "002"]
estimated_complexity: high
---

# Task: GuildDeliveryScreenを実装する

## Goal

`display_results(products, results)`を唯一の表示更新経路として、複数件の納品結果をリスト表示し、合計貢献度・合計報酬・ランクノルマ簡易バーを表示し、「閉じる/続ける」ボタンで導線シグナルを発行する`GuildDeliveryScreen`を実装する（FR-001〜FR-008, FR-101, FR-102, FR-201, FR-202, FR-301, FR-302, FR-401〜FR-403）。

## Interfaces

```gdscript
# atelier/features/guild/ui/guild_delivery_screen.gd
class_name GuildDeliveryScreen
extends Control

signal screen_closed  # 🟡 FR-102。シグナル名は要件文書でも「例」表記であり確定名ではない

const GuildDeliveryResultRowScene = preload("res://features/guild/ui/guild_delivery_result_row.tscn")
const UNKNOWN_RECIPE_NAME := "不明な調合物"  # 🔴 AC-001異常系フォールバック文言、暫定

var _item_count: int = 0
var _total_contribution: float = 0.0
var _total_reward: float = 0.0

@onready var _entry_container: VBoxContainer = %EntryContainer
@onready var _total_label: Label = %TotalLabel
@onready var _rank_name_label: Label = %RankNameLabel
@onready var _quota_bar: ProgressBar = %QuotaBar
@onready var _continue_button: Button = %ContinueButton


func _ready() -> void:  # 🔵 AlchemyScreen._ready()と同型（Autoload非購読のためGameStateシグナルconnectはない）
    _continue_button.pressed.connect(_on_continue_pressed)
    _refresh_rank_quota()
    _apply_totals()


## 唯一の公開表示更新経路（FR-008）。products[i]とresults[i]は同一調合物対応が
## 呼び出し元（AlchemyScreen）で保証済み（FR-101, CON-003）という前提でindexをそのまま使う。
## pending_productsが空だった場合もdisplay_results([], [])が呼ばれ0件へリセットする（FR-006, AC-008）
func display_results(products: Array[ProductInstance], results: Array[DeliveryResult]) -> void:  # 🔵 FR-008/FR-101確定
    _rebuild_list(products, results)
    _apply_totals()
    _refresh_rank_quota()


## テスト用ゲッター（FR-007）
func get_item_count() -> int:  # 🔵 FR-007がメソッド例まで明示
    return _item_count

func get_total_contribution() -> float:  # 🔵
    return _total_contribution

func get_total_reward() -> float:  # 🔵
    return _total_reward


func _rebuild_list(products: Array[ProductInstance], results: Array[DeliveryResult]) -> void: ...  # 🔵
func _resolve_recipe_name(recipe_masters: Dictionary, recipe_id: StringName) -> String: ...  # 🔴 未登録recipe_id時のフォールバック文言が暫定
func _apply_totals() -> void: ...  # 🔵
static func format_totals(total_contribution: float, total_reward: float) -> String: ...  # 🟡 AlchemyPreviewPanel.format_value踏襲の合計値版
func _refresh_rank_quota() -> void: ...  # 🔵 GameState.get_current_rank_master()/get_current_rank_quota()のみ使用（CON-005遵守）
func _on_continue_pressed() -> void: ...  # 🟡 screen_closed.emit()のみ、GameStateへの副作用なし（FR-402）
```

## Test Strategy

- [ ] **正常系（単一件）**: `recipe_masters`に`RecipeMaster(name="回復薬")`を登録した状態で`display_results([product], [delivery_result])`を呼ぶと、リストに1項目追加され調合物名・品質・発現特性・貢献度・報酬が一致する（AC-001）
- [ ] **正常系（複数件）**: 貢献度・報酬が異なる3件で`display_results(products, results)`を呼ぶと、`get_item_count() == 3`、`get_total_contribution()`が3件の`final_contribution`総和、`get_total_reward()`が3件の`final_reward`総和と一致する（AC-002）
- [ ] **正常系（指定合致表示）**: `order_matched == true`の項目に合致テキストが表示され、`order_matched == false`の項目には表示されない（AC-003, FR-201, FR-202）
- [ ] **正常系（index対応）**: 異なるレシピ2件を`display_results([product_a, product_b], [result_a, result_b])`で渡すと、リスト1件目が`product_a`由来、2件目が`product_b`由来の情報と対応する（AC-006）
- [ ] **正常系（0件リセット）**: 直前に2件表示している状態から`display_results([], [])`を呼ぶと、`get_item_count() == 0`かつ合計値が0にリセットされる（AC-008, US-401）
- [ ] **正常系（ノルマバー）**: `GameState.get_current_rank_master()`が`quota_max = 100.0, display_name = "見習い"`を、`GameState.get_current_rank_quota()`が`40.0`を返す状態で`_ready()`または`display_results()`が実行されると、ノルマバーが`40/100`を反映し`%RankNameLabel.text == "見習い"`になる（AC-004正常系）
- [ ] **異常系（recipe_id未登録）**: `recipe_masters`に対応する`RecipeMaster`が存在しない`recipe_id`の場合、クラッシュせず`UNKNOWN_RECIPE_NAME`で表示される（AC-001異常系）
- [ ] **異常系（ノルマ未ロード）**: 現在ランクの`RankMaster`が未ロード（`get_current_rank_master()`がフォールバックの`quota_max = 0.0`を返す）場合、0除算エラーを起こさずバーが空表示になる（AC-004異常系）
- [ ] **境界値**: `activated_traits`が0件の場合「なし」等のプレースホルダーテキストが表示される（AC-001境界値、`GuildDeliveryResultRow`側の契約を呼び出すだけで自然に満たされる）

## Implementation Notes

- 参照すべき既存コード: `atelier/features/alchemy/ui/material_inventory_list.gd`（`setup()`で子ノード全破棄→再構築するリスト管理パターン）、`atelier/features/alchemy/ui/alchemy_screen.gd`（`_refresh()`での`GameState.get_state()`呼び出しパターン、`_recipe_masters = state["recipe_masters"]`のような暗黙型変換の書き方）
- 実装のヒント:
  - `_rebuild_list()`は`_entry_container`の既存子ノードを`queue_free()`→`GuildDeliveryResultRowScene.instantiate()`で再構築する（`MaterialInventoryList`と同型）。行の`name`は`"DeliveryEntry_%d" % i`（`ProductInstance`に一意ID相当のフィールドがないためindexベース）
  - `recipe_id → RecipeMaster.name`解決は`GameState.get_state()["recipe_masters"]`を`_rebuild_list()`内で1回だけ取得して使う（CON-004）
  - ランクノルマバーは`GameState.get_current_rank_master()`（001で追加）と`GameState.get_current_rank_quota()`（001で追加）の2つのみを呼ぶ。`GameState.get_state()["rank_state"]`や`RankState`型を一切参照しないこと（CON-005遵守、Plan設計フェーズで発見した構造的矛盾の回避策）
  - `products.size()`と`results.size()`は呼び出し元の契約上常に一致する（FR-101, CON-003）が、`mini(products.size(), results.size())`で防御的に短い方に合わせるガードを入れてよい
- 注意事項: `.tscn`構成はルート`Control` → `VBoxContainer`の下に「`HBoxContainer(RankNameLabel, QuotaBar)`」→「`ScrollContainer > EntryContainer(VBoxContainer)`」→「`TotalLabel`」→「`ContinueButton`」の構成を想定（すべて`unique_name_in_owner = true`で`%Name`アクセス）。演出（Tween等）・キーボード操作対応は実装しない（FR-401, FR-403）

## Files

- 新規: `atelier/features/guild/ui/guild_delivery_screen.gd`
- 新規: `atelier/features/guild/ui/guild_delivery_screen.tscn`
- テスト: `atelier/tests/integration/test_guild_delivery_screen.gd`
