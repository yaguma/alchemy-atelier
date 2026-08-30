---
id: "004"
title: "F→E昇格サイクルと通し全体の非再生成アサーションを実装する"
status: done
priority: 2
dependencies: ["003"]
estimated_complexity: high
---

# Task: F→E昇格サイクルと通し全体の非再生成アサーションを実装する

## Goal

タスク003完了直後のalchemy画面から、`rank_f`用の低ノルマ状態を再注入し、G→F昇格と同じ手順（植付〜納品→試験→合格）をもう一度通して`rank_e`への昇格を確定させる。さらにテスト冒頭から最後まで4画面+MainSceneのインスタンスIDが一切変わっていないことを最終アサーションとして加え、シナリオ全体を1つの結合テスト関数として完結させる。

## Interfaces

```gdscript
func test_G昇格から工房強化購入を経てF昇格まで実機シーングラフのみで通しで到達する() -> void:
	# タスク001〜004のヘルパーを組み合わせた1本の結合テスト本体。
	# 冒頭で_screen_instance_ids()を記録し、末尾で再取得して不変を検証する（🔵 NFR-001踏襲）
	pass
```

> 信号機: 🟡 F→E昇格時、`_enter_rank(RANK_F_ID)`で`RankState`を明示的に低ノルマへ再注入することで rank_state.gd の「elapsed_turn自動進行未実装」ギャップ（test_main_scene_exam_flow.gd L89-91）を回避する設計だが、rank_f昇格直後に本番コード側が`RankState`をどう初期化しているか（`quota`が新ランクの`quota_max`に自動リセットされるか等）は未調査。テスト側で明示注入すれば競合しない想定だが、実装時に`GameState.commit_rank_outcome()`または`_apply_rank_promotion()`相当の実装（`atelier/autoload/game_state_rank_delegate.gd`等）を確認し、二重初期化で不整合が出ないことを確かめること。

## Test Strategy

- [ ] タスク003完了直後（`current_rank_id == rank_f`, alchemy画面）から`_enter_rank(RANK_F_ID)`で低ノルマを再注入し、再度植付〜納品〜試験〜合格のサイクルを実行すると`GameState.get_state()["current_rank_id"]`が`rank_e`になること
- [ ] F→E昇格確定後も`main.get_visible_phase()`が`&"workshop"`になること（G→F昇格時と同一の遷移パターンの再現性確認）
- [ ] テスト冒頭で記録した`_screen_instance_ids(main)`（MainScene+4画面=5件）が、F→E昇格・工房遷移・全操作完了後も完全一致すること（`change_scene_to_file()`による再生成が起きていない = NFR-001）
- [ ] エッジケース: G→F、F→Eの2回の昇格を通じて`GameState.exam_outcome_confirmed`がちょうど2回、いずれも`ExamOutcome.Value.SUCCESS`で発行されていること（`_event_order`的なレコーダで記録し、CONTINUE等の中間発行と区別する。`test_main_scene_exam_flow.gd`の`_on_exam_outcome_confirmed()`踏襲）

## Implementation Notes

- 参照すべき既存コード: `atelier/tests/integration/test_main_scene_exam_flow.gd`のFR-113観測用リスナー（L183-212）、`atelier/tests/integration/test_main_scene_happy_path.gd`の`_screen_instance_ids()`（L165-171）
- 本タスクはタスク001〜003で積み上げた各ステップを1つの`test_`関数（または冒頭で共通セットアップを行い後半のみ本タスクで追記する構成）として結合する。既存3タスクのヘルパーをそのまま呼び出す形にし、新規ロジックは「2周目のランク遷移」と「最終アサーション」のみに絞る
- 注意事項: `estimated_complexity: high`とした理由は、F→E昇格時のRankState競合リスク（Interfaces節の🟡参照）を実装しながら検証する必要があるため。想定外の挙動が見つかった場合は本タスクの中で原因調査まで行い、必要なら本番コード側の既知ギャップとして`rank_state.gd`にコメントを追記する（本Planでは本番コードの修正は想定していないが、テストが正しく書けない場合は最小限のバグ修正を検討し、その旨をタスク完了報告に明記する）

## Files

- 変更: `atelier/tests/integration/test_main_scene_full_loop_playthrough.gd`
