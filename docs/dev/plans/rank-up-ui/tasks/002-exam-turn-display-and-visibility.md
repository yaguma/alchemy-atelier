---
id: "002"
title: "試験残りターン表示とtin_exam連動のvisible切替を実装する"
status: pending
priority: 1
dependencies: ["001"]
estimated_complexity: medium
---

# Task: 試験残りターン表示とin_exam連動のvisible切替を実装する

## Goal

`in_exam`状態に応じて`%ExamTurnLabel`（残りターン数）・`%AdvanceExamTurnButton`・`%EndTurnButton`のvisible状態を正しく切り替える。`_refresh()`から呼び出す`_refresh_exam_ui(state: Dictionary)`ヘルパーと、残りターン数を算出する静的関数`remaining_exam_turns()`を実装する。

## Interfaces

```gdscript
# 🔵 FR-302（MAY要件）。既存 error_message() の static func パターンを踏襲
static func remaining_exam_turns(exam_turn_limit: int, exam_elapsed_turn: int) -> int:
	return maxi(exam_turn_limit - exam_elapsed_turn, 0)  # 🔵 FR-106、負値にならないようクランプ

const EXAM_TURN_LABEL_FORMAT := "残り%dターン"  # 🟡 FR-106、書式は新規決定

# 🔴 実装判断（要件は分割を義務付けないが、_refresh()肥大化回避のため抽出）
# _refresh() が既に取得済みの state（GameState.get_state()の戻り値）を再利用し、
# 追加の GameState.get_state() 呼び出しは行わない（NFR-001）
func _refresh_exam_ui(state: Dictionary) -> void:
	var in_exam: bool = state["in_exam"]  # 🔵
	_exam_turn_label.visible = in_exam  # 🔵 FR-201, FR-202
	_advance_exam_turn_button.visible = in_exam  # 🔵 FR-201, FR-202, FR-406
	_end_turn_button.visible = not in_exam  # 🔵 FR-203, FR-204
	if in_exam:
		var remaining := remaining_exam_turns(state["exam_turn_limit"], state["exam_elapsed_turn"])  # 🔵
		_exam_turn_label.text = EXAM_TURN_LABEL_FORMAT % remaining  # 🟡
```

## Test Strategy

- [ ] `_set_exam_state_for_test()`で`exam_turn_limit=5, exam_elapsed_turn=2`を注入し`_refresh()`を呼ぶと、`%ExamTurnLabel.text`が「残り3ターン」になる（AC-002正常系）
- [ ] `exam_elapsed_turn == exam_turn_limit`（例: 両方5）の場合、「残り0ターン」と表示され負値にならない（AC-002境界値）
- [ ] `exam_elapsed_turn > exam_turn_limit`（異常値、例: limit=3, elapsed=5）でも「残り0ターン」のままでクランプされる（AC-002異常系）
- [ ] `in_exam=false`の場合、`%ExamTurnLabel.visible`が`false`である（AC-002境界値）
- [ ] `in_exam=true`の場合、`%AdvanceExamTurnButton.visible`が`true`、`%EndTurnButton.visible`が`false`である（AC-003, AC-004正常系）
- [ ] `in_exam=false`の場合、`%AdvanceExamTurnButton.visible`が`false`、`%EndTurnButton.visible`が`true`である（AC-003, AC-004正常系、既存動作の回帰確認）
- [ ] `in_exam=true`から`in_exam=false`へ戻った後（試験終了後）、`%EndTurnButton.visible`が`true`に復帰する（AC-004異常系、回帰含む）

## Implementation Notes

- 参照すべき既存コード: `alchemy_screen.gd`の`_refresh()`（82〜100行目）。`var state := GameState.get_state()`（86行目）で取得済みの`state`変数をそのまま`_refresh_exam_ui(state)`に渡す
- `_refresh()`末尾（`_on_preview_inputs_changed()`呼び出しの前後どちらでもよい）に`_refresh_exam_ui(state)`の呼び出しを1行追加する
- テスト用の試験状態注入は`GameState._set_exam_state_for_test(exam_state, in_exam)`（`atelier/autoload/game_state_test_support.gd`、既存API）を使う
- `GameState.get_state()`が返す`exam_turn_limit`/`exam_elapsed_turn`は`int`型（`game_state.gd`の`get_state()`参照）

## Files

- 変更: `atelier/features/alchemy/ui/alchemy_screen.gd`
- テスト: `atelier/tests/integration/test_alchemy_screen.gd`
