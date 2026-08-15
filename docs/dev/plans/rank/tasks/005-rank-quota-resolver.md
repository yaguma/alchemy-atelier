---
id: "005"
title: "RankQuotaResolverを実装する"
status: pending
priority: 2
dependencies: ["002", "004"]
estimated_complexity: medium
---

# Task: RankQuotaResolverを実装する

## Goal

`features/rank/logic/rank_quota_resolver.gd`に、ノルマ残量計算を担う副作用なしの`RankQuotaResolver`（`apply_contribution`・`is_rank_cleared`・`reset_for_retry`の3 static func）を実装する。

## Interfaces

```gdscript
# features/rank/logic/rank_quota_resolver.gd（新規）
class_name RankQuotaResolver

## current_quotaからcontributionを減算し、0未満にならないようクランプする（超過分は切り捨て）。FR-101, AC-001
static func apply_contribution(current_quota: float, contribution: float) -> float:  # 🔵
	...

## current_quotaが0以下かどうかを返す。FR-102, AC-002
static func is_rank_cleared(current_quota: float) -> bool:  # 🔵
	...

## rank_master.quota_maxでquota、0でelapsed_turnを初期化した新しいRankStateを返す。
## 引数rank_masterや呼び出し元の既存RankStateはin-placeで書き換えない（FR-401）。
## rank_master = nullの場合はpush_error()し、quota=0.0/elapsed_turn=0の既定RankStateを返す（NFR-101）
static func reset_for_retry(rank_master: RankMaster) -> RankState:  # 🔵 FR-103, AC-008
	...
```

> 信号機: 🔵 3関数の計算式・契約はcore-systems.md L297-299に完全準拠。null安全性はNFR-101の要求から導出

## Test Strategy

- [ ] 正常系（AC-001）: `apply_contribution(100.0, 30.0)` → `70.0`
- [ ] 境界値（AC-001）: `apply_contribution(10.0, 30.0)` → `0.0`（0未満にならずクランプ、超過分は切り捨て）
- [ ] 境界値（AC-001）: `apply_contribution(0.0, 10.0)` → `0.0`（既に0の状態からの減算）
- [ ] 正常系（AC-002）: `is_rank_cleared(0.0)` → `true`、`is_rank_cleared(0.1)` → `false`
- [ ] 境界値（AC-002）: `is_rank_cleared(-1.0)`（クランプ済みなら通常発生しないが、防御的に呼ばれても`true`を返す）
- [ ] 正常系（AC-008）: `reset_for_retry(rank_master)`（`quota_max = 100.0`）実行後、返り値の`quota == 100.0`・`elapsed_turn == 0`
- [ ] 異常系（AC-008）: `reset_for_retry(rank_master)`実行後も引数`rank_master`のフィールドは変化しない（FR-401、in-place書き換え禁止の確認）
- [ ] 異常系（NFR-101）: `reset_for_retry(null)`を呼んでもクラッシュせず、`push_error()`を発行し`quota=0.0`・`elapsed_turn=0`の`RankState`を返す
- [ ] 異常系（AC-013）: 同一引数で複数回呼び出しても常に同じ結果を返す（純粋性の確認）

## Implementation Notes

- 参照すべき既存コード: `atelier/features/guild/logic/delivery_resolver.gd`（guild plan、`logic/`層の`static func`実装スタイル・null安全性ガードの参考。guild plan未実装の場合は`atelier/features/alchemy/logic/quality_calculator.gd`を参照する）
- 実装のヒント: `apply_contribution`は`maxf(0.0, current_quota - contribution)`（GDScript組み込み関数`maxf`）で1行実装できる。`reset_for_retry`は`rank_master == null`ガードを最初に置く
- 注意事項: `reset_for_retry`は必ず**新しい**`RankState`インスタンスを`RankState.new()`で生成して返す。既存の`RankState`インスタンスを引数として受け取らない設計（呼び出し元の`GameState`が戻り値で差し替える）

## Files

- 新規: `atelier/features/rank/logic/rank_quota_resolver.gd`
- テスト: `atelier/tests/unit/features/rank/test_rank_quota_resolver.gd`
