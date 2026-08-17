---
id: "006"
title: "GameStateに試験状態の基盤フィールド・シグナル・テストAPIを追加する"
status: pending
priority: 1
dependencies: ["001", "002"]
estimated_complexity: medium
---

# Task: GameStateに試験状態の基盤フィールド・シグナル・テストAPIを追加する

## Goal

`GameState`に昇格試験状態を保持するフィールド・シグナルを追加し、`get_state()`・`reset_for_test()`・テスト専用APIを試験状態対応に拡張する。試験の開始/進行/結果確定ロジック自体は後続タスク（007〜011）で実装する。

## Interfaces

```gdscript
# autoload/game_state.gd（既存ファイルへの追加）
var _in_exam: bool = false                                    # 🔵 FR-008
var _exam_state: ExamState = ExamState.new()                  # 🟡 design phase確定（_rank_stateと同型パターン）
var _last_exam_outcome: ExamOutcome.Value = ExamOutcome.Value.CONTINUE  # 🔵 FR-113（_last_rank_outcomeと同型）

signal exam_started()                                          # 🟡 FR-302（任意要件）
signal exam_outcome_confirmed(outcome: ExamOutcome.Value)      # 🟡 FR-301（任意要件）
```

`get_state()`への追加ビュー（🔵 FR-009, AC-018）:
```gdscript
"in_exam": _in_exam,
"exam_quota": _exam_state.exam_quota,
"exam_quota_max": _exam_state.exam_quota_max,
"exam_elapsed_turn": _exam_state.exam_elapsed_turn,
"exam_turn_limit": _exam_state.exam_turn_limit,
```

テスト専用API（🔵 CON-008委譲パターン）:
```gdscript
# game_state.gd
func _set_exam_state_for_test(exam_state: ExamState, in_exam: bool = true) -> void:
    pass

# game_state_test_support.gd
static func set_exam_state(state: GameStateScript, exam_state: ExamState, in_exam: bool) -> void:
    pass
```

## Test Strategy

- [ ] 初期値: 新規`GameState`（または`reset_for_test()`直後）で`get_state().in_exam == false`
- [ ] 初期値: `get_state().exam_quota == 0.0`等、試験状態の5フィールドがすべてデフォルト値
- [ ] `get_state()`キー: 戻り値のDictionaryに`in_exam`/`exam_quota`/`exam_quota_max`/`exam_elapsed_turn`/`exam_turn_limit`の5キーが存在する
- [ ] 防御的コピー: `_set_exam_state_for_test()`で試験状態を設定後、`get_state()`の戻り値を書き換えても内部の`_exam_state`に影響しない
- [ ] `_set_exam_state_for_test()`: 呼び出し後に`_in_exam`・`_exam_state`の値が引数通りに反映される
- [ ] `reset_for_test()`: 試験状態を設定した後に`reset_for_test()`を呼ぶと`in_exam`・`exam_quota`等がすべて初期値に戻る
- [ ] テスト専用APIガード: `assert(OS.is_debug_build())`＋`push_error()`の二重ガードが機能する（既存パターン踏襲の確認）

## Implementation Notes

- 参照すべき既存コード: `atelier/autoload/game_state.gd`（`_rank_state`フィールド・`get_state()`実装・`reset_for_test()`実装）、`atelier/autoload/game_state_test_support.gd`（`_set_rank_state_for_test`等の既存委譲パターン）
- 実装のヒント: `_rank_state`まわりの既存実装をほぼそのまま複製し、型を`ExamState`/`ExamOutcome`に置き換える
- 注意事項: `get_state()`の試験ビュー5フィールドはすべて値型（float/int/bool）のため、`_rank_state.clone()`のような明示的コピー呼び出しは不要（値型コピーで防御性が保たれる）

## Files

- 変更: `atelier/autoload/game_state.gd`
- 変更: `atelier/autoload/game_state_test_support.gd`
- テスト: `atelier/tests/integration/test_game_state_exam_foundation.gd`
