---
id: "003"
title: "試験開始/結果確定シグナルを購読してトーストメッセージを表示する"
status: done
priority: 2
dependencies: ["001"]
estimated_complexity: medium
---

# Task: 試験開始/結果確定シグナルを購読してトーストメッセージを表示する

## Goal

タスク001で購読済みの`GameState.exam_started`/`exam_outcome_confirmed`シグナルのハンドラ実装を完成させる。開始時・結果確定時（SUCCESS/FAILURE）にトーストメッセージを表示し、`CONTINUE`の場合は無言で画面表示のみ再計算する。

## Interfaces

```gdscript
# 🔴 文言はAI推論による新規決定（design doc上もTBD、CON-003に基づき本Planで確定）。
# 実装時にユーザーレビューで最終確認することが望ましい
const EXAM_MESSAGES := {
	&"exam_started": "昇格試験が始まりました！",
	&"exam_success": "昇格試験に合格しました！",
	&"exam_failure": "昇格試験に失敗しました…",
}

# 🟡 FR-103。design doc OnExamStarted
func _on_exam_started() -> void:
	_refresh()
	_show_toast(EXAM_MESSAGES[&"exam_started"])

# 🟡 FR-104, FR-105。design doc OnExamResolved
# ExamOutcome.Value は features/rank/logic/exam_outcome.gd の class_name をグローバル参照する
func _on_exam_outcome_confirmed(outcome: ExamOutcome.Value) -> void:
	_refresh()
	match outcome:
		ExamOutcome.Value.SUCCESS:
			_show_toast(EXAM_MESSAGES[&"exam_success"])
		ExamOutcome.Value.FAILURE:
			_show_toast(EXAM_MESSAGES[&"exam_failure"])
		_:
			pass  # 🔵 FR-105。CONTINUEの場合はトーストを表示しない
```

## Test Strategy

- [ ] `GameState.exam_started.emit()`後、`get_toast_text()`が「昇格試験が始まりました！」を返す（AC-006正常系）
- [ ] `_set_exam_state_for_test()`でSUCCESS条件（`exam_quota <= 0`）を満たす`ExamState`を注入し`GameState.commit_exam_outcome()`を直接呼び出すと、`get_toast_text()`が「昇格試験に合格しました！」を返す（AC-007正常系、`test_game_state_exam_outcome.gd`と同型の前提でGameState側を直接操作する）
- [ ] FAILURE条件（`exam_elapsed_turn >= exam_turn_limit`かつ`exam_quota > 0`）で`commit_exam_outcome()`を呼ぶと、`get_toast_text()`が「昇格試験に失敗しました…」を返す（AC-007正常系）
- [ ] CONTINUE条件（試験継続中）で`GameState.exam_outcome_confirmed.emit(ExamOutcome.Value.CONTINUE)`を発行しても、直前のトースト文言から変化しない（AC-008正常系、無言であることの確認）
- [ ] `exam_started`発行後、`%ExamTurnLabel`等の試験用UIが表示状態に更新されている（`_refresh()`が呼ばれていることの間接確認、AC-006境界値）
- [ ] `_on_exam_outcome_confirmed`のソースコード文字列に`outcome: ExamOutcome.Value`の型注釈が存在する（NFR-101、既存`_screen_source()`ヘルパー相当の手法で検証）

## Implementation Notes

- 参照すべき既存コード: `alchemy_screen.gd`の`_on_product_crafted()`（275〜279行目）・`_show_toast()`（286〜289行目）のトースト表示パターンをそのまま踏襲する
- `ERROR_MESSAGES`辞書（14〜20行目）と同じ「クラス定数辞書」パターンで`EXAM_MESSAGES`を定義する（FR-301）
- `commit_exam_outcome()`をテストから直接呼び出す手法は`atelier/tests/integration/test_game_state_exam_outcome.gd`を参考にする（CON-005前提: 本番コードからの呼び出し経路は本Planの対象外）
- 文言（`EXAM_MESSAGES`の値）はタスク実装時に日本語として妥当なものを最終確認し、必要であれば調整してよい（CON-003で本Plan内での確定が許容されている）

## Files

- 変更: `atelier/features/alchemy/ui/alchemy_screen.gd`
- テスト: `atelier/tests/integration/test_alchemy_screen.gd`
