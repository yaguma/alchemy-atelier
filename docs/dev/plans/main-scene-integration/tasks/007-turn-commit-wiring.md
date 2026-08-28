---
id: "007"
title: "AlchemyScreenにcommit_rank_outcome()/commit_exam_outcome()の呼び出しを配線する"
status: done
priority: 2
dependencies: ["006"]
estimated_complexity: medium
---

# Task: AlchemyScreenにcommit_rank_outcome()/commit_exam_outcome()の呼び出しを配線する

## Goal

本番コードパスから一度も呼ばれていなかった`GameState.commit_rank_outcome()`（通常ターン納品後）と`GameState.commit_exam_outcome()`（試験ターン進行後）を、`AlchemyScreen`の既存ターン終了系ハンドラから呼び出し、ランク判定・試験合否確定が実際に発火するようにする。

## Interfaces

```gdscript
# atelier/features/alchemy/ui/alchemy_screen.gd への変更

# _on_end_turn_pressed()の末尾に追加（既存: alchemy_screen.gd:331-333）
func _on_end_turn_pressed() -> void:
	var snapshot: Array[ProductInstance] = GameState.get_state()["pending_products"]
	_deliver_and_display(snapshot)
	GameState.commit_rank_outcome()  # 🔵 FR-115（新規追加行）

# _on_advance_exam_turn_pressed()に追加（既存: alchemy_screen.gd:349-351）
func _on_advance_exam_turn_pressed() -> void:
	GameState.advance_exam_turn()
	GameState.commit_exam_outcome()  # 🔵 FR-116（新規追加行）
	_refresh()
```

## Test Strategy

- [ ] `_on_end_turn_pressed()`実行後、`GameState.commit_rank_outcome()`が呼ばれ`rank_outcome_confirmed`が発行される（`monitor_signals(GameState, false)`で検証）
- [ ] ランクノルマ達成状態で`_on_end_turn_pressed()`を実行すると`exam_started`が発行され試験が開始される（`GameState.get_state()["in_exam"] == true`になる）
- [ ] `_on_advance_exam_turn_pressed()`実行後、`GameState.commit_exam_outcome()`が呼ばれ`exam_outcome_confirmed`が発行される
- [ ] 試験ノルマ達成状態で`_on_advance_exam_turn_pressed()`を実行すると`exam_outcome_confirmed(SUCCESS)`が発行される
- [ ] **異常系**: `in_exam == true`の状態（試験モードUI表示中）で`_on_end_turn_pressed()`が呼ばれることはない（`_end_turn_button.visible = not in_exam`により押下不能なため、`commit_rank_outcome()`の試験中誤発火は既存UIのvisible制御で防止されていることを確認する）
- [ ] **境界値**: `commit_rank_outcome()`がDEMOTIONかつゲームオーバー閾値到達と判定した場合、`_on_end_turn_pressed()`完了後に`game_over`も発行されている
- [ ] **回帰確認**: 既存の`test_alchemy_screen.gd`のターン終了系テストが引き続きパスする（`commit_rank_outcome()`呼び出し追加によって既存のnormal-turnテストが未初期化のランクマスターでクラッシュしないよう、テストフィクスチャに`_set_rank_masters_for_test()`が必要な場合は追加する）

## Implementation Notes

- 参照すべき既存コード:
  - `atelier/autoload/game_state_rank_delegate.gd:47-67`（`commit_rank_outcome()`の実装。`is_game_over()`/`is_game_cleared()`成立後は冪等に早期returnするため、複数回呼んでも安全）
  - `atelier/autoload/game_state_rank_delegate.gd:133-155`（`commit_exam_outcome()`の実装。同様に冪等）
  - `atelier/tests/integration/test_game_state_rank_outcome.gd`, `test_game_state_exam_outcome.gd`（`commit_rank_outcome()`/`commit_exam_outcome()`の単体挙動は既にテスト済み。本タスクは「呼び出し配線」の統合検証のみを追加すればよく、判定ロジック自体の再テストは不要）
- 実装のヒント: `commit_rank_outcome()`は`_on_end_turn_pressed()`のみに追加し、`_on_product_crafted()`内の試験中自動納品パス（`in_exam`時の`_deliver_and_display()`呼び出し）には追加しないこと。試験中のランク判定は`commit_exam_outcome()`が別途担当するため、両者を混同すると二重判定になる。
- 注意事項: 既存の`test_alchemy_screen.gd`統合テストは、ランクマスター未設定（`_rank_state_initialized == false`）の状態で`_on_end_turn_pressed()`を呼んでいる可能性がある。`commit_rank_outcome()`追加後もそれらのテストが壊れないことを確認し、壊れる場合は`before_test()`に`GameState._set_rank_masters_for_test(...)`相当のセットアップを追加する（該当テストのみ最小限の修正に留める）。

## Files

- 変更: `atelier/features/alchemy/ui/alchemy_screen.gd`
- テスト: `atelier/tests/integration/test_alchemy_screen.gd`（既存ファイルへのテストケース追記、必要なら既存テストのフィクスチャ修正）
