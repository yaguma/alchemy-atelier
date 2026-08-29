---
id: "004"
title: "AlchemyScreenに現在の指定依頼を表示するUIを追加する"
status: pending
priority: 2
dependencies: ["003"]
estimated_complexity: medium
---

# Task: AlchemyScreenに現在の指定依頼を表示するUIを追加する

## Goal

`AlchemyScreen`にプレイヤーが素材投入を決める前に現在の指定依頼（対象レシピ/特性・ボーナス倍率）を確認できるラベルを追加し、指定依頼の更新に追随して表示を更新する。

## Interfaces

```gdscript
# atelier/features/alchemy/ui/alchemy_screen.gd への変更
@onready var _daily_order_label: Label = %DailyOrderLabel  # 🟡 CON-011、配置は本タスクで確定

const DAILY_ORDER_NONE_TEXT := "指定依頼: なし"  # 🟡 文言は新規決定（CON-011）
const DAILY_ORDER_ITEM_FORMAT := "指定依頼: %s（x%.1f）"  # 🟡 %sはレシピ表示名、%.1fはmatch_bonus_multiplier
const DAILY_ORDER_TRAIT_FORMAT := "指定依頼: 特性「%s」（x%.1f）"  # 🟡 %sは特性名

# _refresh()内、_daily_order_for_preview設定行の直後に追加:
#   _update_daily_order_label()

## _daily_order_for_previewの内容に応じてDailyOrderLabelの文言を更新する。🟡 CON-011
## condition_type=="item"はrecipe_mastersからtarget_recipe_idの表示名を解決する。
## 対応するRecipeMasterが見つからない場合（マスター未ロード等）はtarget_recipe_id自体を
## フォールバック表示する（既存のGardenScreenのフォールバックパターンと同型、NFR-301同等の防御）
func _update_daily_order_label() -> void
```

```
# atelier/features/alchemy/ui/alchemy_screen.tscn への変更
# RecipeOptionButtonとAlchemyPreviewPanelの間に新規ノードを追加（NFR-201「投入前に確認できる位置」）:
├── DailyOrderLabel (Label, unique_name_in_owner)
```

## Test Strategy

- [ ] `_current_daily_order`が`condition_type == "item"`のとき、`DailyOrderLabel`のテキストに対象レシピの表示名（`RecipeMaster.name`相当）とボーナス倍率が含まれる
- [ ] `_current_daily_order`が`condition_type == "trait"`のとき、`DailyOrderLabel`のテキストに対象特性名とボーナス倍率が含まれる
- [ ] `_current_daily_order == null`のとき、`DailyOrderLabel`のテキストが`DAILY_ORDER_NONE_TEXT`（空欄ではなく「指定依頼: なし」等の明示的な文言）になる
- [ ] `GameState.advance_turn_growth()`実行（再抽選）後、画面の再表示（`_refresh()`）で`DailyOrderLabel`が新しい指定依頼の内容に追随する
- [ ] 試験中（`_in_exam == true`、`resolve_daily_order_for_delivery()`が`null`を返す状態）では`DailyOrderLabel`も`DAILY_ORDER_NONE_TEXT`相当の表示になる
- [ ] **異常系**: `target_recipe_id`に対応する`RecipeMaster`が`recipe_masters`に見つからない場合でも、`DailyOrderLabel`の更新がクラッシュせず`target_recipe_id`自体を表示するフォールバックになる
- [ ] **境界値**: 投入内容が指定依頼に合致する場合、既存の`AlchemyPreviewPanel`（`result.order_matched`）側の表示は本タスクで変更しない（回帰確認。二重乗算防止FR-407の非退行）

## Implementation Notes

- 参照すべき既存コード:
  - `atelier/features/alchemy/ui/alchemy_screen.gd:118-138`（`_refresh()`の既存実装。`_daily_order_for_preview = GameState.resolve_daily_order_for_delivery()`の直後に`_update_daily_order_label()`を呼ぶ）
  - `atelier/features/garden/ui/garden_screen.gd:70-93`（`SeedMaster`が解決できない場合のフォールバック表示パターン、`_resolve_display_name()`相当の考え方を踏襲する）
  - `atelier/features/alchemy/ui/alchemy_screen.gd:41`（`_recipe_masters: Dictionary`。`recipe_id -> RecipeMaster`のキャッシュ済み辞書、`_refresh()`内で既に更新されているものをそのまま参照する）
  - `atelier/features/alchemy/ui/alchemy_screen.tscn:30-39`（`RecipeOptionButton`と`AlchemyPreviewPanel`の間、新規ノードの挿入位置）
- 実装のヒント: `_update_daily_order_label()`は`_daily_order_for_preview`（`_refresh()`で既にキャッシュ済み）を読むだけで完結させ、追加の`GameState.get_state()`呼び出しは行わない（NFR-001と同種のコスト意識）。倍率の乗算は本関数では一切行わず、`match_bonus_multiplier`の値を表示するだけに留める（FR-407「二重乗算バグ防止」の非退行）。
- 注意事項: `_daily_order_label`が`null`（`_ready()`前など）の場合はガードして早期returnする（既存の`_toast_label`等と同型の安全策）。

## Files

- 変更: `atelier/features/alchemy/ui/alchemy_screen.gd`, `atelier/features/alchemy/ui/alchemy_screen.tscn`
- テスト: `atelier/tests/integration/test_alchemy_screen.gd`（既存ファイルへのテストケース追記）
