---
id: "001"
title: "RankOutcome enumを実装する"
status: pending
priority: 1
dependencies: []
estimated_complexity: low
---

# Task: RankOutcome enumを実装する

## Goal

`features/rank/logic/rank_outcome.gd`に、ランク結果を表す`RankOutcome`（`CONTINUE`/`PROMOTION_ELIGIBLE`/`DEMOTION`の3値）を実装する。`TurnLimitResolver.resolve_rank_outcome`（タスク006）と`GameState`の両方から参照される。

## Interfaces

```gdscript
# features/rank/logic/rank_outcome.gd（新規）
class_name RankOutcome  # 🔵 FR-003

enum Value { CONTINUE, PROMOTION_ELIGIBLE, DEMOTION }  # 🔵 FR-003, AC-006
```

> 信号機: 🔵 3値の構成はcore-systems.md L305-310クラス図に明記済み。🔴 `features/rank/logic/`への配置（`RankOutcome`という単独ファイルとして切り出す判断）はCON-003で本plan内新規決定（クラス図には配置未確定だった。`TurnLimitResolver`と`GameState`の両方から参照する必要があり、`state/`（GameState専用）には置けないため）

## Test Strategy

- [ ] 正常系（AC-006）: `RankOutcome.Value.CONTINUE`・`RankOutcome.Value.PROMOTION_ELIGIBLE`・`RankOutcome.Value.DEMOTION`の3値がすべて定義されている
- [ ] 正常系（AC-006）: 3値それぞれが一意な値であり、`==`比較で区別できる

## Implementation Notes

- 参照すべき既存コード: GDScriptの`enum`宣言スタイル（プロジェクト内に既存の`enum`利用例がなければGDScript標準構文に従う）
- 実装のヒント: `class_name`付きスクリプトの内部に`enum Value {...}`を定義し、`RankOutcome.Value.DEMOTION`の形でアクセスできるようにする
- 注意事項: `guild`planの`DailyOrderMaster.condition_type`のような文字列ベースの列挙ではなく、GDScriptネイティブの`enum`を使う（型安全性のため）

## Files

- 新規: `atelier/features/rank/logic/rank_outcome.gd`
- テスト: `atelier/tests/unit/features/rank/test_rank_outcome.gd`
