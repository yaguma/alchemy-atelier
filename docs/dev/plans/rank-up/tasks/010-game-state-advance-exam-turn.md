---
id: "010"
title: "GameState.advance_exam_turn()を実装する"
status: done
priority: 2
dependencies: ["005", "006"]
estimated_complexity: low
---

# Task: GameState.advance_exam_turn()を実装する

## Goal

調合を実行せずに試験ターンだけ進める専用メソッド`advance_exam_turn()`を実装する。在庫切れ・解禁レシピ切れによるデッドロックの回避手段。`in_exam=false`時はエラーを返し状態を変更しない。

## Interfaces

```gdscript
# autoload/game_state.gd（新規メソッド）

## in_exam=falseの場合は状態を変更せず失敗のResultを返す。
## in_exam=trueの場合はPromotionExamResolver.advance_turnでexam_elapsed_turnを+1する 🔵 FR-103, FR-104
func advance_exam_turn() -> Result:
    pass
```

> 信号機: 🔵 `core-systems.md`L335・L350、design phase確定。エラーコード名`&"not_in_exam"`は🟡（design phaseで既存エラーコード命名規則から推定、明示要件なし）。

## Test Strategy

- [ ] 正常系: `in_exam=true`時に呼ぶと`get_state().exam_elapsed_turn`が+1され、`Result.success == true`
- [ ] 異常系（FR-104）: `in_exam=false`時に呼ぶと状態が一切変化せず`Result.success == false`
- [ ] 境界値: `in_exam=true`状態で`exam_elapsed_turn == exam_turn_limit - 1`から実行しちょうど上限に到達する
- [ ] 副作用範囲の確認: `advance_exam_turn()`呼び出しが`_rank_state`・`gold`・`_pending_products`等、試験状態以外のフィールドに一切影響しない

## Implementation Notes

- 参照すべき既存コード: `atelier/autoload/game_state.gd`の既存`Result`返却パターン（`execute_alchemy_failed`相当のエラーコード命名規則）
- 実装のヒント: design phase 2.3節の擬似コードをそのまま実装する（`PromotionExamResolver.advance_turn(_exam_state)`の呼び出しと代入のみ）
- 注意事項: `resolve_outcome`の呼び出しは行わない（結果確定は別メソッド`commit_exam_outcome()`、タスク011の責務）

## Files

- 変更: `atelier/autoload/game_state.gd`
- テスト: `atelier/tests/integration/test_game_state_advance_exam_turn.gd`
