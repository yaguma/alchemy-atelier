---
id: "002"
title: "G→F昇格までの通常ターン〜試験合格シナリオを実装する"
status: done
priority: 1
dependencies: ["001"]
estimated_complexity: medium
---

# Task: G→F昇格までの通常ターン〜試験合格シナリオを実装する

## Goal

タスク001のヘルパーを使い、「庭で植付→調合実行→ターン終了で納品→ノルマ消化→昇格試験開始→試験1回消化→合格確定→workshop自動遷移」までを実機シーングラフ越しのUI操作のみで通す前半シナリオを実装する。

## Interfaces

```gdscript
## 調合画面へ切り替え、レシピ選択・素材投入・調合実行・ターン終了を1サイクル行う
func _run_one_alchemy_turn(main: MainScene, material_instance_id: String) -> void:
	pass  # 🔵 test_main_scene_happy_path.gdの_select_recipe/_place_material/_press踏襲

## 試験中に調合を1回実行し、試験ノルマを消し切る（自動納品される）
func _craft_once_in_exam(main: MainScene) -> void:
	pass  # 🔵 test_main_scene_exam_flow.gdの同名関数を踏襲

func test_G昇格試験に合格しworkshop画面へ自動遷移する() -> void:
	pass
```

> 信号機: 🔵 既存の`test_main_scene_exam_flow.gd`の`_craft_once_in_exam()`・`_start_exam_via_ui()`相当ロジックの転用のため確信度は高い。`_run_one_alchemy_turn()`は`test_main_scene_happy_path.gd`の`test_通常ターンを1周して庭に復帰する()`本体をヘルパー化したもの。

## Test Strategy

- [ ] G(`rank_g`)スタート時、庭で植付→調合タブ→レシピ選択・素材投入・調合実行→EndTurnButton押下で納品が発生し`GameState.get_state()["pending_products"]`が0件になること
- [ ] 上記納品でランクノルマを消し切った結果、`GameState.exam_started`が発行され`GameState.get_state()["in_exam"]`が`true`になること
- [ ] 試験中に`_craft_once_in_exam()`→`AdvanceExamTurnButton`押下で`GameState.exam_outcome_confirmed`が`ExamOutcome.Value.SUCCESS`で発行されること
- [ ] 合格確定後、`main.get_visible_phase()`が`&"workshop"`になり`GameState.get_state()["current_rank_id"]`が`rank_f`になること
- [ ] 合格確定後、`GameState.get_state()["can_purchase_permanent"]`が`true`になること（工房購入テストの前提）

## Implementation Notes

- 参照すべき既存コード: `atelier/tests/integration/test_main_scene_exam_flow.gd`の`test_試験に合格すると工房強化画面が自動表示される_非最終ランク()`（L256-272）が単一ランクでの合格確定フローの正解実装
- `test_main_scene_happy_path.gd`の`test_通常ターンを1周して庭に復帰する()`（L177-229）が植付→調合→納品の1サイクルの正解実装
- 本タスクはタスク001で作った`test_main_scene_full_loop_playthrough.gd`に追記する形で進める（新規ファイルは作らない）
- 注意事項: 素材は`_inject_material_for_test()`で毎ターン投入するか、在庫が足りているか都度確認すること。既存の`_inject_pending_product_for_test()`（`_start_exam_via_ui()`パターン）を使えば納品対象の素材収穫プロセスを省略できる

## Files

- 変更: `atelier/tests/integration/test_main_scene_full_loop_playthrough.gd`
