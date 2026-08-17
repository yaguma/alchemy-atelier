---
id: "001"
title: "ExamOutcome enumを実装する"
status: done
priority: 1
dependencies: []
estimated_complexity: low
---

# Task: ExamOutcome enumを実装する

## Goal

昇格試験の結果を表す3値の列挙型`ExamOutcome`を、既存の`RankOutcome`と同一パターン（`class_name` + `RefCounted`継承 + `Value` enum）で実装する。

## Interfaces

```gdscript
# features/rank/logic/exam_outcome.gd
class_name ExamOutcome
extends RefCounted

enum Value { CONTINUE, SUCCESS, FAILURE }  # 🔵 requirements.md FR-005
```

> 信号機: 🔵 既存`features/rank/logic/rank_outcome.gd`と完全に同型の配置・実装パターンを踏襲（design phase確定）。

## Test Strategy

- [ ] `ExamOutcome.Value`が`CONTINUE`/`SUCCESS`/`FAILURE`の3値を持つ
- [ ] 3値それぞれが一意な整数値を持つ（重複がない）
- [ ] 定義されていない4番目の値にアクセスしようとするとコンパイルエラーになる（静的検証、テストコード上は3値の網羅で代替確認）
- [ ] 境界値: `Value`の最小値・最大値が期待順序（`CONTINUE=0, SUCCESS=1, FAILURE=2`）と一致する

## Implementation Notes

- 参照すべき既存コード: `atelier/features/rank/logic/rank_outcome.gd`（8行、同型パターン）
- 実装のヒント: `rank_outcome.gd`をほぼそのままコピーし、enum値のみ差し替える
- 注意事項: `RankOutcome`とは別の独立した型として定義する（統合しない。FR-005参照）

## Files

- 新規: `atelier/features/rank/logic/exam_outcome.gd`
- テスト: `atelier/tests/unit/features/rank/test_exam_outcome.gd`
