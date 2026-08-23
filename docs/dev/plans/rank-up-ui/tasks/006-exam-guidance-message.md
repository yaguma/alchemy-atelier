---
id: "006"
title: "試験中の在庫切れ/解禁レシピ0時に案内メッセージを表示する"
status: pending
priority: 3
dependencies: ["002"]
estimated_complexity: low
---

# Task: 試験中の在庫切れ/解禁レシピ0時に案内メッセージを表示する

## Goal

`in_exam == true`かつ在庫（`inventory`）が空、または解禁レシピ（`unlocked_recipe_ids`）が空の場合に、`%ExamGuidanceLabel`で案内メッセージを表示する。それ以外の場合は非表示にする。

## Interfaces

```gdscript
# 🟡 FR-205, FR-206, FR-301。文言はAI推論による新規決定（CON-003で本Plan内確定が許容）
const EXAM_GUIDANCE_MESSAGE := "投入できる素材がありません。「ターンを進める」で試験を進行できます。"

# _refresh_exam_ui(state) 内に追加する分岐（タスク002で新設済みのメソッドを拡張）
# 🟡 FR-205, FR-206
func _refresh_exam_ui(state: Dictionary) -> void:
	# ...(タスク002で実装済みの残りターン表示・visible切替はそのまま)...
	var in_exam: bool = state["in_exam"]
	var inventory: Array = state["inventory"]
	var unlocked_recipe_ids: Array = state["unlocked_recipe_ids"]
	var should_show_guidance := in_exam and (inventory.is_empty() or unlocked_recipe_ids.is_empty())  # 🟡
	_exam_guidance_label.visible = should_show_guidance
	if should_show_guidance:
		_exam_guidance_label.text = EXAM_GUIDANCE_MESSAGE
```

## Test Strategy

- [ ] `in_exam=true`かつ在庫0（`_set_recipe_masters_for_test`等で在庫を空にする）の場合、`%ExamGuidanceLabel.visible`が`true`になる（AC-010正常系）
- [ ] `in_exam=true`かつ解禁レシピ0（`_set_unlocked_recipe_ids_for_test([])`）の場合も`%ExamGuidanceLabel.visible`が`true`になる（AC-010正常系）
- [ ] `in_exam=true`かつ在庫・解禁レシピともにある場合、`%ExamGuidanceLabel.visible`が`false`になる（AC-010正常系）
- [ ] `in_exam=false`の場合、在庫0であっても`%ExamGuidanceLabel.visible`は`false`のまま（試験中限定であることの確認、AC-010異常系）
- [ ] 案内メッセージ表示中でも`%ExecuteButton.disabled`は既存の`_slot_state.can_execute()`ロジックにより無効化され、`%AdvanceExamTurnButton`は常に有効のままである（design doc「エラー状態」記述の確認、AC-010境界値）

## Implementation Notes

- 参照すべき既存コード: タスク002で実装済みの`_refresh_exam_ui(state)`を拡張する（新規メソッドは追加しない）
- 在庫・解禁レシピの取得は`_refresh()`が既に取得済みの`state`（`GameState.get_state()`の戻り値）から行い、追加の`GameState.get_state()`呼び出しは行わない（NFR-001）
- `%ExecuteButton`の無効化は既存の`_on_preview_inputs_changed()`内`_execute_button.disabled = not _slot_state.can_execute()`（111行目）がそのまま機能するため変更不要
- テスト用の在庫・解禁レシピ操作は`GameState._inject_material_for_test()`/`_set_unlocked_recipe_ids_for_test()`（既存API）を使う

## Files

- 変更: `atelier/features/alchemy/ui/alchemy_screen.gd`
- テスト: `atelier/tests/integration/test_alchemy_screen.gd`
