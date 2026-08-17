---
id: "011"
title: "GameStateに試験結果の評価・確定処理を実装する"
status: pending
priority: 2
dependencies: ["004", "006"]
estimated_complexity: high
---

# Task: GameStateに試験結果の評価・確定処理を実装する

## Goal

`evaluate_exam_outcome()`（副作用なし先読み）と`commit_exam_outcome()`（副作用あり確定）を実装する。成功時は次ランクへの実遷移またはゲームクリア判定、失敗時は同ランク再挑戦またはゲームオーバー判定を行う。`evaluate_rank_outcome`/`commit_rank_outcome`と完全対称のパターンを踏襲する。

## Interfaces

```gdscript
# autoload/game_state.gd（新規メソッド）

## in_exam=falseの場合は常にCONTINUEを返す（_rank_state_initializedガードと同型の安全策） 🟡 FR-107
func evaluate_exam_outcome() -> ExamOutcome.Value:
    pass

## 実行直前にevaluate_exam_outcome()を再評価してから確定する。is_game_over()確定後は
## 冪等に_last_exam_outcomeを返す 🔵 FR-108〜113
func commit_exam_outcome() -> Result:
    pass

## SUCCESS確定時の内部処理。次ランクありなら昇格・rank_state再初期化、
## 次ランクなし（RANK_ORDER末尾）ならゲームクリア（current_rank_id・rank_state不変） 🔵 FR-108, FR-109, FR-404
func _commit_exam_success() -> void:
    pass

## FAILURE確定時の内部処理。同ランクをreset_for_retryでリセットし、demotion_countを+1する 🔵 FR-110, FR-111
func _commit_exam_failure() -> void:
    pass
```

> 信号機: 🔵 design phaseで擬似コード確定済み。`_rank_state_initialized = true`の設定は本タスクが唯一の本番セット経路になる点、`RankQuotaResolver.reset_for_retry`を次ランク初期化にも流用する点はユーザー確認済み。

## Test Strategy

### evaluate_exam_outcome
- [ ] 正常系: `in_exam=true`で`exam_quota<=0`の状態 → `SUCCESS`
- [ ] 正常系: `in_exam=true`で`exam_elapsed_turn>=exam_turn_limit`かつ`exam_quota>0` → `FAILURE`
- [ ] 異常系（FR-107ガード）: `in_exam=false`の場合は`exam_quota`等の値に関わらず常に`CONTINUE`
- [ ] 状態不変性: 呼び出し前後で`in_exam`・`_exam_state`・`_rank_state`・`gold`が一切変化しない

### commit_exam_outcome（成功・次ランクあり）
- [ ] 正常系: `rank_g`で`SUCCESS`確定 → `current_rank_id`が`rank_f`に更新、`demotion_count==0`、`rank_state.quota==次ランクのquota_max`、`in_exam==false`
- [ ] 正常系: `_rank_state_initialized`が`true`に設定される
- [ ] 正常系: `exam_outcome_confirmed(SUCCESS)`シグナルが発行される
- [ ] 異常系: 次ランクの`RankMaster`が`_rank_masters`に存在しない場合、`push_error()`が呼ばれ`current_rank_id`・`rank_state`は変更されない（NFR-101）

### commit_exam_outcome（成功・次ランクなし＝ゲームクリア境界）
- [ ] 境界値（RANK_ORDER末尾）: `rank_s`で`SUCCESS`確定 → `current_rank_id`は`rank_s`のまま、`rank_state`再初期化なし、`in_exam==false`
- [ ] 異常系: `RANK_ORDER`範囲外アクセスによるクラッシュが発生しない

### commit_exam_outcome（失敗・ゲームオーバー境界）
- [ ] 正常系: `FAILURE`確定 → `rank_state`が`reset_for_retry`相当の初期値に戻り`demotion_count`が+1、`in_exam==false`
- [ ] 境界値（ゲームオーバー確定境界）: `demotion_count`が`MAX_DEMOTION_COUNT-1`から+1されちょうど`MAX_DEMOTION_COUNT`に到達すると`game_over`シグナルが発行される
- [ ] 異常系: `demotion_count`が`MAX_DEMOTION_COUNT-1`未満のままなら`game_over`は発行されない

### commit_exam_outcome（CONTINUE・冪等性）
- [ ] 正常系（FR-112）: `CONTINUE`中に呼んでも`in_exam`・`_exam_state`・`_rank_state`が一切変化しない
- [ ] 異常系（FR-113）: `is_game_over()==true`確定後に複数回連続で呼んでも`demotion_count`が再加算されず、直近の確定結果が冪等に返る

## Implementation Notes

- 参照すべき既存コード: `atelier/autoload/game_state.gd`の`evaluate_rank_outcome()`/`commit_rank_outcome()`/`is_game_over()`（完全対称の構造として踏襲）、`atelier/features/rank/logic/rank_quota_resolver.gd`の`reset_for_retry`（次ランク初期化・同ランクリセットの両方に流用）
- 実装のヒント: design phase 2.5節の擬似コードをそのまま実装する。`_commit_exam_success()`は`RankProgression.get_next_rank_id`（タスク004）を呼び出す
- 注意事項: `game_over`シグナルは既存のrank plan実装（`is_game_over()` / `game_over(demotion_count: int)`）をそのまま再利用し、新規シグナルを作らない

## Files

- 変更: `atelier/autoload/game_state.gd`
- テスト: `atelier/tests/integration/test_game_state_exam_outcome.gd`
