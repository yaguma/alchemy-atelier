---
id: "007"
title: "GameState.commit_rank_outcome()に試験開始トリガーを統合する"
status: pending
priority: 2
dependencies: ["005", "006"]
estimated_complexity: medium
---

# Task: GameState.commit_rank_outcome()に試験開始トリガーを統合する

## Goal

既存の`commit_rank_outcome()`が`PROMOTION_ELIGIBLE`を確定した際、`PromotionExamResolver.start_exam`で試験状態を生成し`in_exam`をtrueにする内部ヘルパー`_start_exam()`を実装・統合する。二重開始を防止する。

## Interfaces

```gdscript
# autoload/game_state.gd（既存メソッドへの差分）

## PROMOTION_ELIGIBLE確定時、not _in_examの場合のみ_start_exam()を呼ぶ 🔵 FR-101
## （既存commit_rank_outcome()への追加分岐。既存のDEMOTION/game_over処理は変更しない）
func commit_rank_outcome() -> Result:
    pass

## 現在ランクのRankMasterが不正（null/limit_turn<=0）な場合は試験を開始せずpush_error()する
## （NFR-101の「試験開始不可」フォールバック） 🔵 FR-101
func _start_exam() -> void:
    pass
```

> 信号機: 🔵 design phaseで擬似コード確定済み。`not _in_exam`ガードによる二重開始防止（FR-201）はGameState側の責務として確定（ユーザー確認済み）。

## Test Strategy

- [ ] 正常系: `PROMOTION_ELIGIBLE`確定後に`get_state().in_exam == true`
- [ ] 正常系: 試験開始後の`exam_quota_max`が`PromotionExamResolver.start_exam`の計算式と一致する
- [ ] 正常系: `exam_started`シグナルが発行される
- [ ] 異常系: 現在ランクの`RankMaster`が`_rank_masters`に存在しない場合、試験を開始せず`push_error()`が呼ばれ`in_exam`は`false`のまま
- [ ] 二重開始防止（FR-201）: `in_exam=true`かつ`exam_elapsed_turn > 0`の状態で`commit_rank_outcome()`が再度`PROMOTION_ELIGIBLE`を確定させても、既存の`_exam_state`が上書きされない（`exam_elapsed_turn`が巻き戻らない）
- [ ] 既存動作の非破壊確認: `DEMOTION`/`CONTINUE`確定時の既存挙動（`rank_outcome_confirmed`発行等）が変化しない

## Implementation Notes

- 参照すべき既存コード: `atelier/autoload/game_state.gd`の`commit_rank_outcome()`（実行直前再評価・`rank_outcome_confirmed`発行パターン）、`_get_current_rank_master_or_fallback()`
- 実装のヒント: design phase 2.1節の擬似コードをそのまま反映する。`PROMOTION_ELIGIBLE`分岐に`elif outcome == RankOutcome.Value.PROMOTION_ELIGIBLE and not _in_exam:`を追加するのみで、既存のDEMOTION分岐・シグナル発行順序は変更しない
- 注意事項: `_start_exam()`内で`RankMaster`不正時にNFR-101フォールバックを行うため、`PromotionExamResolver.start_exam`内部のnullガードには（design phase確認済みの通り）到達しない設計を許容する

## Files

- 変更: `atelier/autoload/game_state.gd`
- テスト: `atelier/tests/integration/test_game_state_start_exam.gd`
