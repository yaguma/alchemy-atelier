---
id: "002"
title: "GuildDeliveryResultRow（納品結果リスト1項目の表示専用コンポーネント）を実装する"
status: pending
priority: 2
dependencies: []
estimated_complexity: medium
---

# Task: GuildDeliveryResultRowを実装する

## Goal

納品結果リストの1項目（調合物名・品質・発現特性・指定依頼合致有無・貢献度・報酬）を表示する、GameState/Domain層に一切依存しない表示専用コンポーネント`GuildDeliveryResultRow`を実装する（FR-003, FR-201, FR-202）。

## Interfaces

```gdscript
# atelier/features/guild/ui/guild_delivery_result_row.gd
class_name GuildDeliveryResultRow
extends HBoxContainer  # 🟡 AlchemyPreviewPanel(Control)ではなくリスト行のため横並びコンテナを採用

const ORDER_MATCHED_TEXT := "指定合致"  # 🔵 AlchemyPreviewPanel.ORDER_MATCHED_TEXT踏襲
const TRAITS_NONE_TEXT := "なし"        # 🔵 AlchemyPreviewPanel.TRAITS_NONE_TEXT踏襲
const TRAIT_SEPARATOR := ", "           # 🔵 AlchemyPreviewPanel.TRAIT_SEPARATOR踏襲

@onready var _name_label: Label = %NameLabel
@onready var _quality_label: Label = %QualityLabel
@onready var _traits_label: Label = %TraitsLabel
@onready var _order_match_label: Label = %OrderMatchLabel
@onready var _value_label: Label = %ValueLabel

## add_child()後（@onready解決後）に呼ぶこと。MaterialEntryRow.setup()と同一契約 🔵
func setup(
    recipe_name: String,
    quality_score: int,
    activated_traits: Array[StringName],
    order_matched: bool,
    final_contribution: float,
    final_reward: float
) -> void: ...  # 🔵 FR-003で確定済みの表示項目をそのまま引数化

static func format_quality(quality_score: int) -> String: ...   # 🔵 AlchemyPreviewPanel.format_quality踏襲
static func format_traits(activated_traits: Array[StringName]) -> String: ...  # 🔵 同上
static func format_value(final_contribution: float, final_reward: float) -> String: ...  # 🔵 同上（ラベルのみ「見込み」→実績表記に変更）
```

## Test Strategy

- [ ] **正常系**: `setup("回復薬", 4, [&"holy"], true, 12.5, 30.0)`後、`%NameLabel.text == "回復薬"`、`%QualityLabel.text`が品質4を表す文言、`%TraitsLabel.text`が`"holy"`を含む文言になる
- [ ] **正常系**: `order_matched == true`のとき`%OrderMatchLabel.visible == true`かつ`text == "指定合致"`
- [ ] **正常系**: `order_matched == false`のとき`%OrderMatchLabel.visible == false`（FR-202）
- [ ] **正常系**: `format_value(12.5, 30.0)`が貢献度・報酬の両方を含む文字列を返す
- [ ] **境界値**: `activated_traits`が空配列の場合、`format_traits([])`が`TRAITS_NONE_TEXT`（「なし」）を含む文字列を返す
- [ ] **境界値**: `quality_score`が最小値1・最大値5（`GameBalance.QUALITY_SCORE_MIN`/`MAX`）でもクラッシュせず表示される

## Implementation Notes

- 参照すべき既存コード: `atelier/features/alchemy/ui/alchemy_preview_panel.gd`（`format_quality`/`format_traits`/`format_value`の実装とテキスト定数、`_apply_display()`での`visible`制御パターン）、`atelier/features/alchemy/ui/material_entry_row.gd`（`setup()`のみを公開するリスト行コンポーネントの最小契約）、`atelier/tests/unit/features/alchemy/test_material_inventory_list.gd`（`find_child(name, true, false)`でリスト行を検索しラベルを直接検証するテストパターン）
- 実装のヒント: `AlchemyPreviewPanel`は「見込み」表記（プレビュー用）だが、本コンポーネントは実際の納品結果（確定値）を表示するため、`format_value()`のラベル文言は「貢献度」「報酬」（見込みを付けない）に変更すること
- 注意事項: 本コンポーネントは`GameState`・Domain層（`DeliveryResolver`等）のいずれにも一切依存しない（`AlchemyPreviewPanel`と同一の設計方針、FR-005）。呼び出し元（003）が`ProductInstance`/`DeliveryResult`から必要な値を取り出し、プリミティブ値として`setup()`に渡す

## Files

- 新規: `atelier/features/guild/ui/guild_delivery_result_row.gd`
- 新規: `atelier/features/guild/ui/guild_delivery_result_row.tscn`
- テスト: `atelier/tests/unit/features/guild/test_guild_delivery_result_row.gd`
