---
id: "001"
title: "GameStateにgame_clearedシグナルを追加し真のゲームクリア分岐から発行する"
status: pending
priority: 1
dependencies: []
estimated_complexity: low
---

# Task: GameStateにgame_clearedシグナルを追加し真のゲームクリア分岐から発行する

## Goal

`GameState`に新規シグナル`game_cleared`（引数なし）を追加し、`game_state_rank_delegate.gd`の`_commit_exam_success()`内で「最終ランクでの昇格試験成功（真のゲームクリア）」の分岐からのみ発行する。次ランクのRankMaster欠落エラー分岐からは発行しない。

## Interfaces

```gdscript
# atelier/autoload/game_state.gd（19行目付近、既存game_over宣言の隣に追加）
signal game_over(demotion_count: int)  # 既存
signal game_cleared  # 🔵 FR-004, FR-101, FR-302。引数なし（対応する自然なペイロードが存在しないためYAGNIで無引数を採用）
```

```gdscript
# atelier/autoload/game_state_rank_delegate.gd の _commit_exam_success() 内（157-176行目付近）
static func _commit_exam_success(state: GameStateScript) -> void:
	state._can_purchase_permanent = true
	var next_rank_id := RankProgression.get_next_rank_id(state._current_rank_id)

	if next_rank_id == &"":
		state._in_exam = false
		state.game_cleared.emit()  # 🔵 FR-101。真のゲームクリア分岐からのみ発行。状態mutation完了後に発行
		return

	var next_rank_master: RankMaster = state._rank_masters.get(next_rank_id)
	if next_rank_master == null:
		state._warn_missing_next_rank_master(next_rank_id)
		state._in_exam = false
		return  # 🔵 FR-201, FR-405。このエラー分岐からはgame_clearedを発行しない（変更なし、現状維持）

	# ...既存の通常昇格処理（変更なし）
```

## Test Strategy

配置先: `atelier/tests/integration/test_game_state_exam_outcome.gd`（既存ファイルに追加。既にランク/試験フィクスチャが揃っているため）

- [ ] **正常系**: 現在ランクがRANK_ORDER末尾（次ランクIDが空文字列）の状態で`_set_current_rank_id_for_test`等により昇格試験SUCCESS条件を整え、`commit_exam_outcome()`を呼ぶと`GameState.game_cleared`が発行される（`assert_signal(GameState).is_emitted(GameState.game_cleared)`、`monitor_signals(GameState, false)`必須）
- [ ] **正常系**: 上記と同じ操作後、`_current_rank_id`が変化しないこと・`_in_exam`が`false`になることを確認する
- [ ] **異常系**: 次ランクIDが存在するが対応する`RankMaster`が`_rank_masters`に未登録の状態で`commit_exam_outcome()`を呼ぶと、`game_cleared`が発行されないこと（`assert_signal(GameState).is_not_emitted(GameState.game_cleared)`相当）を確認する
- [ ] **異常系**: 上記と同じ操作で`game_over`も発行されないことを確認する
- [ ] **境界値**: RANK_ORDER末尾から2番目のランクでSUCCESS確定した場合（次ランクのRankMasterが登録済み）は通常昇格処理となり、`_current_rank_id`が次ランクへ更新され、`game_cleared`は発行されないことを確認する
- [ ] **エッジケース**: マスターデータ欠落分岐実行後、該当RankMasterを追加登録してから再度SUCCESS確定させると正常に次ランクへ昇格し、`game_cleared`は発行されないことを確認する（既存の「解決不能な幽霊試験状態」バグの再発防止確認を兼ねる）

## Implementation Notes

- 参照すべき既存コード: `atelier/autoload/game_state.gd`（18-21行目、既存signal定義群）、`atelier/autoload/game_state_rank_delegate.gd`（125-186行目、`commit_exam_outcome()`/`_commit_exam_success()`/`_commit_exam_failure()`）
- 実装のヒント: `commit_rank_outcome()`内の既存`game_over.emit(state._demotion_count)`呼び出し（61-62行目付近）が「状態mutation完了後に発行」という既存規約の実例。`game_cleared.emit()`もこれに倣い、`state._in_exam = false`の代入後・`return`の直前に配置する
- 注意事項: `game_cleared`は状態フィールドを持たないため、`reset_for_test()`・`GameStateTestSupport`への変更は不要。`monitor_signals(GameState, ...)`を使う場合は第2引数を必ず`false`にする（Autoloadの誤解放を防ぐ既知の罠、`.claude/rules/testing.md`参照）

## Files

- 変更: `atelier/autoload/game_state.gd`
- 変更: `atelier/autoload/game_state_rank_delegate.gd`
- テスト: `atelier/tests/integration/test_game_state_exam_outcome.gd`（既存ファイルへのテストケース追加）
