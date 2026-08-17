---
id: "002"
title: "ExamState型を実装する"
status: pending
priority: 1
dependencies: []
estimated_complexity: low
---

# Task: ExamState型を実装する

## Goal

昇格試験中のランタイム状態を保持する`ExamState`型を、`RankState`と同様の`RefCounted`継承・防御的コピー`clone()`パターンで実装する。

## Interfaces

```gdscript
# features/rank/state/exam_state.gd
class_name ExamState
extends RefCounted

var exam_quota: float = 0.0        # 🔵 FR-006 試験ノルマ残量
var exam_quota_max: float = 0.0    # 🔵 FR-006 試験ノルマ上限（start_exam時点のスナップショット値）
var exam_elapsed_turn: int = 0     # 🔵 FR-006 試験内経過ターン
var exam_turn_limit: int = 0       # 🔵 FR-006 試験制限ターン

func clone() -> ExamState:          # 🔵 FR-006 独立コピーを返す（RankState.clone()と同型）
    pass
```

> 信号機: 🔵 `core-systems.md`L300-305クラス図・`data-schema.md`L63-69 exam_state辞書構造に忠実。`RankState`との相違点は、`quota_max`/`limit_turn`を`RankMaster`から都度参照せず`start_exam()`時点で計算済みの値を自身のフィールドとして保持する自己完結型である点（design phase確定）。

## Test Strategy

- [ ] デフォルト値: 新規`ExamState.new()`の4フィールドがすべて0（float 0.0 / int 0）
- [ ] `clone()`の戻り値が元インスタンスと全フィールド同値
- [ ] `clone()`の戻り値が元インスタンスとは別インスタンス（`==`ではなく`is`で非同一参照を確認）
- [ ] 独立性: `clone()`後に複製側のフィールドを変更しても元インスタンスに影響しない
- [ ] 境界値: 全フィールドが0の`ExamState`の`clone()`が正しく動作する

## Implementation Notes

- 参照すべき既存コード: `atelier/features/rank/state/rank_state.gd`（`RefCounted`継承・`clone()`パターンの参考）
- 実装のヒント: `RankState`のフィールド数・型を4フィールド版に置き換えるだけの単純な実装
- 注意事項: `RankMaster`への参照を持たない独立した型にする（design phase確定「RankStateはRankMasterを知らない」原則を踏襲）

## Files

- 新規: `atelier/features/rank/state/exam_state.gd`
- テスト: `atelier/tests/unit/features/rank/test_exam_state.gd`
