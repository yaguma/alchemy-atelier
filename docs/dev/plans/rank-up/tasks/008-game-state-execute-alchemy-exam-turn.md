---
id: "008"
title: "GameState.execute_alchemy()に試験中ターン消費を統合する"
status: done
priority: 2
dependencies: ["005", "006"]
estimated_complexity: low
---

# Task: GameState.execute_alchemy()に試験中ターン消費を統合する

## Goal

`in_exam=true`の間に`execute_alchemy()`が成功した場合、`PromotionExamResolver.advance_turn`で`exam_elapsed_turn`を+1する差分を既存メソッドに追加する。

## Interfaces

```gdscript
# autoload/game_state.gd（既存execute_alchemy()の成功パス末尾への差分）

## 成功パスの末尾（product_crafted.emit()より前）でin_examならadvance_turnを適用 🔵 FR-102
func execute_alchemy(recipe_id: StringName, material_ids: Array[String]) -> Result:
    pass
```

> 信号機: 🔵 `core-systems.md`L350・design phase確定。「同期リスナーが更新前の値を読むのを防ぐ」既存コメント方針（`commit_rank_outcome()`のシグナル発行順序）を踏襲し、`product_crafted.emit()`より前に状態更新を完了させる。

## Test Strategy

- [ ] 正常系: `in_exam=true`時に`execute_alchemy()`が成功すると`get_state().exam_elapsed_turn`が呼び出し前より+1される
- [ ] 正常系: `in_exam=false`時は`execute_alchemy()`成功後も`exam_elapsed_turn`が変化しない（通常プレイへの影響がないことの確認）
- [ ] 異常系: `execute_alchemy()`がレシピ不成立・投入枠不足等で失敗（`execute_alchemy_failed`発行）した場合、`exam_elapsed_turn`は加算されない
- [ ] 境界値: `exam_elapsed_turn == exam_turn_limit - 1`の状態から実行し、ちょうど`exam_turn_limit`に到達する

## Implementation Notes

- 参照すべき既存コード: `atelier/autoload/game_state.gd`の`execute_alchemy()`（成功パス・失敗パスの分岐、`product_crafted`シグナル発行位置）
- 実装のヒント: 既存の失敗時early-return分岐には一切手を入れない（自然に異常系要件を満たす）
- 注意事項: `execute_alchemy()`自体のシグネチャ・戻り値の型は変更しない（既存呼び出し元への影響を避ける）

## Files

- 変更: `atelier/autoload/game_state.gd`
- テスト: `atelier/tests/integration/test_game_state_execute_alchemy.gd`（既存ファイルへのテストケース追記）
