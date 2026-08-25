---
id: "009"
title: "通常ターン1周と工房往復の結合シナリオをGdUnit4統合テストで検証する"
status: pending
priority: 3
dependencies: ["008"]
estimated_complexity: medium
---

# Task: 通常ターン1周と工房往復の結合シナリオをGdUnit4統合テストで検証する

## Goal

`scenes/main.tscn`を`scene_runner()`でロードし、「庭で植付→調合タブ切替→調合実行→ターン終了で納品→続けるで庭復帰」（シナリオ1）と「庭/調合からの工房往復」（シナリオ2）を1本以上のGdUnit4統合テストとして自動検証し、本Planの中核であるacceptance-criteria.mdのAC-018（横断的受入基準）の一部を満たす。

## Interfaces

本タスクはテストコードのみを追加する（新規プロダクションコードなし）。

```gdscript
# atelier/tests/integration/test_main_scene_happy_path.gd（新規）
extends GdUnitTestSuite

func before_test() -> void:
	GameState.reset_for_test()

func test_通常ターンを1周して庭に復帰する() -> void:
	# シナリオ1: plan.md「Design Overview」データフロー図の「通常ターン1周」を再現する
	pass

func test_工房への往復で直前フェーズに復帰する() -> void:
	# シナリオ2
	pass
```

## Test Strategy

- [ ] `scene_runner("res://scenes/main.tscn")`ロード直後、`GardenScreen`が可視でマスターデータ（種一覧）が実データで表示される
- [ ] 種を植える（`GardenScreen`の`SeedInventoryList`経由で`seed_plant_requested`を発行）→`GameState.get_state()["garden_state"]`に反映される
- [ ] 調合タブ押下 →`AlchemyScreen`のみ可視になる
- [ ] レシピ選択・素材投入・「調合を実行する」押下 →`product_crafted`発行、在庫が更新される
- [ ] 「ターンを終了する」押下 →`GuildDeliveryScreen`が可視になり結果が表示され、`RankHud`のゴールド表示が納品報酬分だけ増加する
- [ ] 「続ける」押下 →`GardenScreen`のみ可視な状態（庭フェーズ）に復帰する
- [ ] （シナリオ2）alchemyフェーズでショップボタン押下 →`WorkshopScreen`が可視になる → 閉じるボタン押下 →`AlchemyScreen`のみ可視な状態に復帰する
- [ ] 全シナリオを通じて`change_scene_to_file()`が一度も呼ばれない（NFR-001。`main.tscn`のノードがシナリオ実行中に破棄・再生成されないことを確認する。実装が正しければ自明に満たされるが、明示的な観測方法がなければ「ノードインスタンスIDが実行前後で変化しない」ことで代替確認する）

## Implementation Notes

- 参照すべき既存コード:
  - `atelier/tests/integration/test_game_state_execute_alchemy.gd`, `test_game_state_deliver_pending_products.gd`（`GameState`単体では既にこれらの操作フローがテスト済み。本タスクは「UI操作経由でシーングラフ越しに同じ結果に到達するか」を検証する点が既存テストと異なる）
  - `.claude/rules/godot-debug-tools.md`「状態セットアップ雛形」（`scene_runner()`の使い方、`_add_material_to_inventory()`等のヘルパー関数パターン）
  - `atelier/features/garden/ui/seed_inventory_list.gd`, `atelier/features/alchemy/ui/material_inventory_list.gd`（UI操作をシミュレートする際に発行すべきsignal・呼ぶべきメソッドの確認）
- 実装のヒント: `data/materials/`, `data/recipes/`等の実データ（task 001以前から存在する既存の`.tres`）をそのまま使ってよい。庭で植えた種が収穫可能になるまでには生育ターンが必要な場合があるため、`GameState.advance_turn_growth()`を必要回数呼ぶか、初期状態で既に収穫可能な株を`_add_material_to_inventory()`相当のテスト専用APIで直接在庫投入してよい（テストの本質は「UI配線」の検証であり、庭ロジック自体の再検証ではないため）。
- 注意事項: `before_test()`で`GameState.reset_for_test()`を呼びテスト間の状態を分離する。`GameState`を監視する場合は`monitor_signals(GameState, false)`を明示する。

## Files

- 新規: `atelier/tests/integration/test_main_scene_happy_path.gd`
