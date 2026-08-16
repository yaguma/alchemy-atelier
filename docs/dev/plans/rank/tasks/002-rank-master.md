---
id: "002"
title: "RankMasterのResource型を実装する"
status: done
priority: 1
dependencies: []
estimated_complexity: low
---

# Task: RankMasterのResource型を実装する

## Goal

`features/rank/resources/rank_master.gd`に、ランクのマスターデータ型`RankMaster`（`Resource`継承）を実装する。本plan内では`.tres`実データは作成せず、テストコード上でのフィクスチャ生成のみで使用する（CON-006）。

## Interfaces

```gdscript
# features/rank/resources/rank_master.gd（新規）
class_name RankMaster
extends Resource

@export var id: String = ""                            # 🔵 FR-004, AC-007
@export var display_name: String = ""                    # 🔵 FR-004, AC-007
@export var quota_max: float = 0.0                        # 🔵 FR-004, AC-007
@export var limit_turn: int = 0                           # 🔵 FR-004, AC-007
@export var traits_unlocked: bool = false                 # 🔵 FR-004, AC-007
@export var exam_turn_limit: int = 0                      # 🔵 FR-004, CON-012（本plan未使用）
@export var exam_difficulty_coefficient: float = 0.0      # 🔵 FR-004, CON-012（本plan未使用）
```

> 信号機: 🔵 フィールド構成はdata-schema.md L190-212に明記済み。`exam_turn_limit`/`exam_difficulty_coefficient`は本plan内のロジックからは参照されないが、スキーマ完全性のため定義する（CON-012）

## Test Strategy

- [ ] 正常系（AC-007）: 7フィールド全てに値を設定した`RankMaster.new()`インスタンスから、設定した値がそのまま読み出せる
- [ ] 正常系（AC-007）: `.tres`実データなしで、テストコード上のフィクスチャ生成のみでインスタンス化が完結する（CON-006）
- [ ] エッジケース（AC-007）: `exam_turn_limit`/`exam_difficulty_coefficient`のデフォルト値（`0`/`0.0`）を明示的に検証し、本plan内のいかなるロジックからも参照されないことをコードレビューで確認する

## Implementation Notes

- 参照すべき既存コード: `atelier/features/alchemy/resources/recipe_master.gd`（`Resource`継承・`@export var`のスタイル）
- 実装のヒント: `resources/*.gd`はマスターデータ型定義のみでロジックを持たないため`.claude/rules/testing.md`の「除外対象」に該当するが、AC-007のチェックリストに従い最低限のフィールド読み書き確認は行う
- 注意事項: `res://data/ranks/*.tres`の実データ作成は本plan外（FR-405）。テストは`RankMaster.new()`でコード上に直接フィクスチャを組み立てる

## Files

- 新規: `atelier/features/rank/resources/rank_master.gd`
- テスト: `atelier/tests/unit/features/rank/test_rank_master.gd`（最小限。除外対象のため厳密な網羅は不要）
