---
id: "008"
title: "GameStateにランク結果評価・確定処理を実装し納品時のノルマ消費を統合する"
status: done
priority: 3
dependencies: ["005", "006", "007"]
estimated_complexity: high
---

# Task: GameStateにランク結果評価・確定処理を実装し納品時のノルマ消費を統合する

## Goal

`GameState.evaluate_rank_outcome()`（副作用なしの問い合わせ）・`commit_rank_outcome()`（副作用あり、DEMOTION確定処理を含む）・`is_game_over()`を実装する。あわせて`deliver_pending_products()`（guild plan実装済み前提、CON-010）内の`_accumulated_contribution += result.final_contribution`を`RankQuotaResolver.apply_contribution`による`_rank_state.quota`更新へ置き換え、暫定フィールド`_accumulated_contribution`を削除する。

## Interfaces

```gdscript
# autoload/game_state.gd（既存ファイルへの追記・deliver_pending_products()の一部変更）

signal rank_outcome_confirmed(outcome: RankOutcome.Value)  # 🔴 FR-112
signal game_over(demotion_count: int)  # 🔴 FR-113

## 副作用なし。現在ランクのRankMaster（フォールバック込み）とRankStateからquota_cleared/
## turn_limit_reachedを算出し、TurnLimitResolver.resolve_rank_outcomeの結果を返す（FR-109）
func evaluate_rank_outcome() -> RankOutcome.Value:  # 🔴 CON-009
	...

## evaluate_rank_outcome()を実行直前に再評価し、結果を状態へ確定反映する（FR-110）。
## rank_outcome_confirmed(outcome)を発行する（FR-112）。
## DEMOTIONの場合: _demotion_countを+1、RankQuotaResolver.reset_for_retry(現在ランクのRankMaster)で
## _rank_stateを差し替える。is_game_over()が真になった時点でgame_over(_demotion_count)を発行する（FR-113）。
## 既にゲームオーバーが確定している場合は状態を変更せず直近のResultを返す（FR-202、冪等性）
func commit_rank_outcome() -> Result:  # 🔴 CON-009。value = RankOutcome.Value
	...

## _demotion_countがGameBalance.MAX_DEMOTION_COUNT以上かどうかを返す
func is_game_over() -> bool:  # 🔵 FR-111
	...

# deliver_pending_products()内（guild plan実装済み前提）の変更箇所:
#   変更前: _accumulated_contribution += result.final_contribution
#   変更後: _rank_state.quota = RankQuotaResolver.apply_contribution(_rank_state.quota, result.final_contribution)
# （FR-108, CON-004【破壊的変更】）

# var _accumulated_contribution: float = 0.0  # FR-408により削除
```

> 信号機: 🔴 `evaluate_rank_outcome`/`commit_rank_outcome`の2メソッド分離設計はCON-009で本plan内新規決定（先出し問い合わせと副作用ありの確定を分離）。🔵 `is_game_over`の閾値比較・`deliver_pending_products`の置き換え内容自体はFR-108/FR-111として確定済み

## Test Strategy

- [ ] 正常系（AC-009）: `deliver_pending_products()`実行後、`_rank_state.quota`が`RankQuotaResolver.apply_contribution`の期待値どおりに減少している（guild planのAC-010相当を本plan向けに書き換えたテスト）
- [ ] 異常系（AC-009）: `GameState`に`_accumulated_contribution`フィールドが存在しないことをコードレビューで確認する（FR-408）
- [ ] 正常系（AC-010）: `_rank_state.quota = 0.0`・`elapsed_turn >= limit_turn`の状態で`evaluate_rank_outcome()` → `PROMOTION_ELIGIBLE`
- [ ] 正常系（AC-010）: `evaluate_rank_outcome()`を複数回呼んでも状態が変化しない（副作用なしの確認）
- [ ] 正常系（AC-011）: `evaluate_rank_outcome()`が`DEMOTION`を返す状況で`commit_rank_outcome()`を呼ぶと、`_demotion_count`が+1され、`_rank_state`が`reset_for_retry`相当（`quota = quota_max`・`elapsed_turn = 0`）に差し替わる
- [ ] 境界値（AC-011）: `_demotion_count`が`GameBalance.MAX_DEMOTION_COUNT - 1`の状態から`DEMOTION`が確定すると`_demotion_count`が閾値に到達し、`is_game_over()`が`true`になる
- [ ] 異常系（AC-011, FR-202）: `is_game_over()`が`true`の状態で`commit_rank_outcome()`を再度呼んでも`_demotion_count`はそれ以上増加せず、`_rank_state`も変化しない
- [ ] 正常系（AC-012）: `commit_rank_outcome()`実行時に`rank_outcome_confirmed`シグナルが確定した`RankOutcome`を伴って1回発行される（`monitor_signals(GameState, false)`で監視）
- [ ] 正常系（AC-012）: `DEMOTION`確定によりゲームオーバーが成立した瞬間、`game_over(_demotion_count)`シグナルが発行される
- [ ] 正常系（AC-012）: `PROMOTION_ELIGIBLE`確定時は`game_over`シグナルが発行されない、かつ`_current_rank_id`・`_rank_state`・`_demotion_count`のいずれも変化しない（FR-404、次ランクへの遷移は本plan外）

## Implementation Notes

- 参照すべき既存コード: `atelier/autoload/game_state.gd`の`execute_alchemy()`（早期リターンによる検証パターン）、guild plan実装済みの`deliver_pending_products()`（本タスクで内部の1行を変更する対象。**guild planの実装がまだ完了していない場合、本タスクは着手できない。CON-010参照**）
- 実装のヒント: `evaluate_rank_outcome()`は`_get_current_rank_master_or_fallback()`（タスク007）で現在ランクを取得し、`RankQuotaResolver.is_rank_cleared(_rank_state.quota)`と`TurnLimitResolver.is_turn_limit_reached(_rank_state.elapsed_turn, rank_master.limit_turn)`を算出したうえで`TurnLimitResolver.resolve_rank_outcome(...)`に渡す。`commit_rank_outcome()`は`is_game_over()`が真なら早期リターンで直近の状態を`Result.ok`として返し（FR-202）、そうでなければ`evaluate_rank_outcome()`を再評価してから`rank_outcome_confirmed.emit(outcome)`、`DEMOTION`なら`_demotion_count += 1` → `_rank_state = RankQuotaResolver.reset_for_retry(rank_master)` → `is_game_over()`なら`game_over.emit(_demotion_count)`の順で処理する
- 注意事項: `PROMOTION_ELIGIBLE`確定時は`_current_rank_id`を次ランクへ進める処理を**行わない**（FR-404、promotion-exam planの責務）。`commit_rank_outcome()`はシグナル発行のみでよい

## Files

- 変更: `atelier/autoload/game_state.gd`
- テスト: `atelier/tests/integration/test_game_state_rank_outcome.gd`
