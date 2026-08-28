---
id: "010"
title: "昇格試験の開始・合否分岐・終局までの結合シナリオをGdUnit4統合テストで検証する"
status: done
priority: 3
dependencies: ["008"]
estimated_complexity: high
---

# Task: 昇格試験の開始・合否分岐・終局までの結合シナリオをGdUnit4統合テストで検証する

## Goal

`scenes/main.tscn`を`scene_runner()`でロードし、「ランク判定確定→昇格試験開始→試験合否確定→分岐（workshop/garden/result）」（シナリオ3・4）を1本以上のGdUnit4統合テストとして自動検証し、特にFR-113（`exam_outcome_confirmed`→`game_cleared`/`game_over`の同一フレーム内連続発行と最終画面の上書き）が実機シーングラフ越しに正しく成立することを保証する。本Planの受入基準の中核（acceptance-criteria.md AC-018）。

## Interfaces

本タスクはテストコードのみを追加する（新規プロダクションコードなし）。

```gdscript
# atelier/tests/integration/test_main_scene_exam_flow.gd（新規）
extends GdUnitTestSuite

func before_test() -> void:
	GameState.reset_for_test()

func test_通常ターンの終了でランク判定が確定し試験が開始される() -> void:
	pass

func test_試験に合格すると工房強化画面が自動表示される_非最終ランク() -> void:
	pass

func test_最終ランクの試験に合格するとゲームクリア画面が表示される() -> void:
	# FR-113: exam_outcome_confirmed(SUCCESS) → game_cleared の順で2回発行される
	pass

func test_試験に不合格でも庭画面から再挑戦できる() -> void:
	pass

func test_規定回数連続降格するとゲームオーバー画面が表示される() -> void:
	# FR-113: exam_outcome_confirmed(FAILURE) → game_over の順で2回発行される
	pass
```

## Test Strategy

- [ ] ランクノルマ達成条件を満たす納品を`_on_end_turn_pressed()`相当のUI操作経由で完了させると、`exam_started`が発行され`get_visible_phase() == &"alchemy"`、庭タブが`disabled == true`になる
- [ ] 試験モードUI（「ターンを進める」ボタン）経由で試験ノルマを達成させ`exam_outcome_confirmed(SUCCESS)`を発行させると、非最終ランクの場合`get_visible_phase() == &"workshop"`かつ`GameState.get_state()["can_purchase_permanent"] == true`（`WorkshopScreen`の恒久投資タブが活性化していることを`WorkshopScreen.get_active_tab()`等の既存テスト用ゲッターで確認する）
- [ ] 真の最終ランク（`RankProgression.is_true_final_rank()`が真になるようテストフィクスチャを構成）で試験に合格させると、`monitor_signals(GameState, false)`で`exam_outcome_confirmed`と`game_cleared`の両方の発行を確認した上で、最終的に`get_visible_phase() == &"result"`（`ResultScreen.get_result_kind() == ResultScreen.ResultKind.CLEAR`）
- [ ] 制限ターン到達等で試験に不合格になった場合（ゲームオーバー条件未成立）、`get_visible_phase() == &"garden"`に復帰する
- [ ] 連続降格回数がゲームオーバー閾値に到達する状況を構成し試験に不合格になった場合、`monitor_signals(GameState, false)`で`exam_outcome_confirmed`と`game_over`の両方の発行を確認した上で、最終的に`get_visible_phase() == &"result"`（`ResultScreen.get_result_kind() == ResultScreen.ResultKind.OVER`）
- [ ] **境界値**: 連続降格回数が閾値の「1つ手前」で試験に不合格になった場合、`game_over`は発行されず`get_visible_phase() == &"garden"`のまま
- [ ] **異常系**: 既にゲームクリア／ゲームオーバー確定済みの状態で試験関連のUI操作を再度行っても、`commit_exam_outcome()`の冪等ガードにより画面が変化しない

## Implementation Notes

- 参照すべき既存コード:
  - `atelier/tests/integration/test_game_state_exam_outcome.gd`（`commit_exam_outcome()`のSUCCESS/FAILURE/最終ランク/ゲームオーバー各ケースを`GameState`単体で構成する際のフィクスチャパターン。ランクマスターの投入方法・`RANK_ORDER`実在の2ランクを使う手法（コメント参照）をそのまま踏襲できる）
  - `atelier/tests/integration/test_alchemy_screen.gd:654-655`のコメント（`RANK_ORDER`実在の2ランクをマスター登録する既存パターン）
  - `atelier/tests/integration/test_game_state_workshop_commit_exam_integration.gd`（`RANK_ORDER`末尾での`SUCCESS`確定パターンの既存参考実装）
  - task 001で作成した`atelier/data/ranks/*.tres`（本タスクでは実データを使うか、テスト専用の`_set_rank_masters_for_test()`で最小構成のランクマスターを注入するかを選択できる。「真の最終ランク」「ゲームオーバー閾値到達」を確実に再現するには後者の方が制御しやすい）
- 実装のヒント: 「試験ノルマを達成させる」ための具体的な操作（素材投入→調合実行→ターンを進める、を繰り返す）は`GameBalance`の試験ノルマ計算式に依存するため、テスト専用の低いノルマ値を持つ`RankMaster`/`ExamState`をフィクスチャとして注入し、少ない操作回数で確実にSUCCESS/FAILUREへ到達できるようにする。
- 注意事項: 本タスクはFR-113の検証が最重要かつ最も間違えやすい箇所（signal発行順序への依存）。`monitor_signals(GameState, false)`の第2引数省略は`testing.md`が警告する重大な罠（Autoloadが誤って解放される）なので必ず明示すること。

## Files

- 新規: `atelier/tests/integration/test_main_scene_exam_flow.gd`
