---
id: "004"
title: "RankState型を実装する"
status: done
priority: 1
dependencies: []
estimated_complexity: low
---

# Task: RankState型を実装する

## Goal

`features/rank/state/rank_state.gd`に、ランクごとのランタイム状態`RankState`（`RefCounted`継承、`quota`/`elapsed_turn`、`clone()`付き）を実装する。`RankMaster`には依存しない独立した型。

## Interfaces

```gdscript
# features/rank/state/rank_state.gd（新規）
class_name RankState
extends RefCounted  # 🟡 CON-011（GardenState/SlotStateと同型パターン、Resourceにすると.tres保存対象と誤認されるため回避）

var quota: float = 0.0        # 🔵 FR-005, AC-008
var elapsed_turn: int = 0     # 🔵 FR-005, AC-008

func clone() -> RankState:  # 🔵 FR-410（get_state()の防御的コピー用）
	...
```

> 信号機: 🔵 フィールド構成はdata-schema.md L83-84・core-systems.md L288（`reset_for_retry`の戻り値型）に明記済み。🟡 `RefCounted`継承・`clone()`の実装方針は`GardenState`/`SlotState`の既存パターン踏襲

## Test Strategy

- [ ] 正常系（AC-008）: `RankState.new()`のデフォルト値が`quota = 0.0`・`elapsed_turn = 0`である
- [ ] 正常系: フィールドへ値を設定後、`clone()`で複製したインスタンスが同じ値を持つ
- [ ] エッジケース: `clone()`で複製したインスタンスのフィールドを変更しても、元のインスタンスの値は変化しない（独立コピーであることの確認）

## Implementation Notes

- 参照すべき既存コード: `atelier/features/garden/state/garden_state.gd`（`RefCounted`継承・`clone()`実装パターン）
- 実装のヒント: `quota`/`elapsed_turn`はプリミティブ型のみのため、`clone()`は新規`RankState`を生成しフィールドを代入するだけのシンプルな実装でよい
- 注意事項: `RankMaster`への参照は持たない（`rank_state.gd`は`rank_master.gd`を知らない設計。生成・初期化は`RankQuotaResolver.reset_for_retry`または`GameState`が担う）

## Files

- 新規: `atelier/features/rank/state/rank_state.gd`
- テスト: `atelier/tests/unit/features/rank/test_rank_state.gd`
