---
id: "002"
title: "DailyOrderMasterのResource型を実装する"
status: done
priority: 1
dependencies: []
estimated_complexity: low
---

# Task: DailyOrderMasterのResource型を実装する

## Goal

`features/guild/resources/daily_order_master.gd`に、日替わり指定調合物のマスターデータ型`DailyOrderMaster`（`Resource`継承）を実装する。本plan内では`.tres`実データは作成せず、テストコード上でのフィクスチャ生成のみで使用する（CON-005）。

## Interfaces

```gdscript
# features/guild/resources/daily_order_master.gd（新規）
class_name DailyOrderMaster
extends Resource

@export var id: String = ""                      # 🔵 FR-003, AC-007
@export var condition_type: String = ""           # 🔵 FR-003, AC-007（"item" | "trait"）
@export var target_recipe_id: String = ""         # 🔵 FR-003, AC-007
@export var target_trait: String = ""             # 🔵 FR-003, AC-007
@export var match_bonus_multiplier: float = 1.3   # 🔵 FR-003, CON-006
```

> 信号機: 🔵 フィールド構成はdata-schema.md L170-189に明記済み。既定値`1.3`はCON-006（ヒアリング確定）に基づく

## Test Strategy

- [ ] 正常系: 5フィールド全てに値を設定した`DailyOrderMaster.new()`インスタンスから、設定した値がそのまま読み出せる（AC-007）
- [ ] 正常系: `.tres`実データなしで、テストコード上のフィクスチャ生成のみでインスタンス化が完結する（AC-007、CON-005）
- [ ] エッジケース: `condition_type`のデフォルト値が空文字であり、明示的に設定しない限り`"item"`/`"trait"`のいずれでもないことを確認する（後続タスク004の`matches_order`が未知値を安全に処理できるかの前提確認）

## Implementation Notes

- 参照すべき既存コード: `atelier/features/alchemy/resources/recipe_master.gd`（`Resource`継承・`@export var`のスタイル）
- 実装のヒント: `resources/*.gd`はマスターデータ型定義のみでロジックを持たないため、`.claude/rules/testing.md`の「除外対象」に該当し、この型自体への網羅的なテスト義務（NFR-401の対象外）はないが、AC-007のチェックリストに従い最低限のフィールド読み書き確認は行う
- 注意事項: `res://data/daily_orders/*.tres`の実データ作成は本plan外（FR-405）。テストは`DailyOrderMaster.new()`でコード上に直接フィクスチャを組み立てる

## Files

- 新規: `atelier/features/guild/resources/daily_order_master.gd`
- テスト: `atelier/tests/unit/features/guild/test_daily_order_master.gd`（最小限。除外対象のため厳密な網羅は不要）
