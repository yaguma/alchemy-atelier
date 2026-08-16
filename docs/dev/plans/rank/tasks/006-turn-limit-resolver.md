---
id: "006"
title: "TurnLimitResolverを実装する"
status: done
priority: 2
dependencies: ["001"]
estimated_complexity: medium
---

# Task: TurnLimitResolverを実装する

## Goal

`features/rank/logic/turn_limit_resolver.gd`に、制限ターン到達判定とランク結果確定を担う副作用なしの`TurnLimitResolver`（`is_turn_limit_reached`・`resolve_rank_outcome`の2 static func）を実装する。早期クリアボーナス（制限ターン未到達時は常に`CONTINUE`）の構造的保証を含む。

## Interfaces

```gdscript
# features/rank/logic/turn_limit_resolver.gd（新規）
class_name TurnLimitResolver

## current_turnがlimit_turn以上かどうかを返す。FR-104, AC-003
static func is_turn_limit_reached(current_turn: int, limit_turn: int) -> bool:  # 🔵
	...

## turn_limit_reachedが偽の場合は常にCONTINUEを返す（早期クリアボーナス、FR-105/FR-411）。
## 真の場合、quota_clearedが真ならPROMOTION_ELIGIBLE、偽ならDEMOTIONを返す（FR-106/FR-107）
static func resolve_rank_outcome(quota_cleared: bool, turn_limit_reached: bool) -> RankOutcome.Value:  # 🔵
	...
```

> 信号機: 🔵 2関数の計算式・契約はcore-systems.md L300-301に完全準拠。特に`turn_limit_reached`が偽のときに`PROMOTION_ELIGIBLE`/`DEMOTION`を返してはならない制約（FR-411）は早期クリアボーナスの構造的保証として必須

## Test Strategy

- [ ] 正常系（AC-003）: `is_turn_limit_reached(15, 15)` → `true`（等価で到達）
- [ ] 正常系（AC-003）: `is_turn_limit_reached(14, 15)` → `false`
- [ ] 正常系（AC-003）: `is_turn_limit_reached(20, 15)` → `true`（超過）
- [ ] 正常系（AC-004）: `resolve_rank_outcome(true, true)` → `PROMOTION_ELIGIBLE`
- [ ] 正常系（AC-004）: `resolve_rank_outcome(false, true)` → `DEMOTION`
- [ ] 境界値（AC-004, FR-411）: `resolve_rank_outcome(true, false)` → `CONTINUE`（ノルマクリア済みでも制限ターン未到達なら試験へ進まない、早期クリアボーナス）
- [ ] 境界値（AC-004）: `resolve_rank_outcome(false, false)` → `CONTINUE`
- [ ] 異常系（AC-013）: 同一引数で複数回呼び出しても常に同じ結果を返す（純粋性の確認）

## Implementation Notes

- 参照すべき既存コード: タスク001で実装した`RankOutcome`（`Value`列挙型の参照方法）、`atelier/features/rank/logic/rank_quota_resolver.gd`（タスク005、同一Featureの`logic/`層コーディングスタイル）
- 実装のヒント: `resolve_rank_outcome`は`if not turn_limit_reached: return RankOutcome.Value.CONTINUE`を最初に置く早期リターンで実装し、以降の分岐で`turn_limit_reached`が常に真であることを前提にできるようにする
- 注意事項: `quota_cleared`・`turn_limit_reached`の算出（`RankQuotaResolver.is_rank_cleared`・`is_turn_limit_reached`の呼び出し）は本関数の責務外。呼び出し元（`GameState.evaluate_rank_outcome`、タスク008）が2つの判定結果を渡す設計

## Files

- 新規: `atelier/features/rank/logic/turn_limit_resolver.gd`
- テスト: `atelier/tests/unit/features/rank/test_turn_limit_resolver.gd`
