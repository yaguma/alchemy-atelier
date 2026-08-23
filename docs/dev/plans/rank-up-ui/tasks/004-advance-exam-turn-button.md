---
id: "004"
title: "「ターンを進める」ボタンの押下挙動を実装する"
status: pending
priority: 2
dependencies: ["002"]
estimated_complexity: low
---

# Task: 「ターンを進める」ボタンの押下挙動を実装する

## Goal

`%AdvanceExamTurnButton`押下時に`GameState.advance_exam_turn()`を呼び出し、試験ターンをクラフトせずに消費した上で画面表示（残りターン表示）を再計算する。在庫が尽きた場合や解禁レシピがない場合のデッドロック回避手段として機能させる。

## Interfaces

```gdscript
# 🔵 FR-102。design doc OnExamTurnAdvanced
# 戻り値のResultは無視してよい（in_exam=falseの場合ボタン自体がvisible=falseで押下不能なため、
# GameState.advance_exam_turn()のResult.fail(&"not_in_exam")ハンドリングは不要という設計判断 🟡）
func _on_advance_exam_turn_pressed() -> void:
	GameState.advance_exam_turn()
	_refresh()
```

`_ready()`内に`_advance_exam_turn_button.pressed.connect(_on_advance_exam_turn_pressed)`を追加する（🔵、タスク001で追加済みのノード参照を使う）。

## Test Strategy

- [ ] `in_exam=true`、`exam_turn_limit=5, exam_elapsed_turn=2`の状態で`%AdvanceExamTurnButton`を押下すると、`GameState.get_state()["exam_elapsed_turn"]`が3になる（AC-003正常系）
- [ ] 押下後、`%ExamTurnLabel.text`が「残り2ターン」に更新される（AC-003正常系、タスク002の表示ロジックと連動）
- [ ] 在庫が空（`state["inventory"]`が空配列）の状態でも`%AdvanceExamTurnButton.disabled`が`false`のまま（常時有効、AC-003正常系）
- [ ] `exam_elapsed_turn`が`exam_turn_limit`に到達する直前（例: limit=5, elapsed=4）で押下すると`exam_elapsed_turn=5`になり、残りターン表示が「残り0ターン」になる（AC-003境界値）
- [ ] `in_exam=false`の場合、`%AdvanceExamTurnButton`は非表示（`visible=false`）であり押下操作自体が想定されない（タスク002の回帰確認）

## Implementation Notes

- 参照すべき既存コード: `alchemy_screen.gd`の`_on_end_turn_pressed()`（265〜268行目）と同様に、`GameState`メソッド呼び出し＋`_refresh()`のシンプルな2行構成にする
- `GameState.advance_exam_turn()`は`atelier/autoload/game_state_rank_delegate.gd`に実装済み（`in_exam=false`なら`Result.fail(&"not_in_exam")`を返すのみで、状態変更なし）
- テストでは`GameState._set_exam_state_for_test(exam_state, true)`で試験状態を注入してから押下操作をシミュレートする

## Files

- 変更: `atelier/features/alchemy/ui/alchemy_screen.gd`
- テスト: `atelier/tests/integration/test_alchemy_screen.gd`
