---
id: "005"
title: "指定依頼の抽選から表示・納品ボーナスまでの結合シナリオをGdUnit4統合テストで検証する"
status: done
priority: 3
dependencies: ["004"]
estimated_complexity: high
---

# Task: 指定依頼の抽選から表示・納品ボーナスまでの結合シナリオをGdUnit4統合テストで検証する

## Goal

`scenes/main.tscn`を`scene_runner()`でロードし、「ゲーム開始時の初回抽選→AlchemyScreenでの表示確認→指定依頼に合致する調合物の納品でボーナス反映→ターン終了で再抽選→表示更新」を1本以上のGdUnit4統合テストとして自動検証し、本Planの受入基準（acceptance-criteria.mdの横断的受入基準）を満たす。

## Interfaces

本タスクはテストコードのみを追加する（新規プロダクションコードなし）。

```gdscript
# atelier/tests/integration/test_main_scene_daily_order_flow.gd（新規）
extends GdUnitTestSuite

func before_test() -> void:
	GameState.reset_for_test()

func test_ゲーム開始直後から指定依頼が機能し画面に表示される() -> void:
	pass

func test_指定依頼に合致する調合物を納品するとボーナスが反映される() -> void:
	pass

func test_ターン終了で指定依頼が再抽選され表示が更新される() -> void:
	pass

func test_達成可能な指定依頼が無いランクでも通しプレイが完走する() -> void:
	pass
```

## Test Strategy

- [ ] `scene_runner("res://scenes/main.tscn")`ロード直後、`GameState.resolve_daily_order_for_delivery()`が非`null`（達成可能なエントリが存在する初期状態を前提とする）
- [ ] `AlchemyScreen`表示時、`DailyOrderLabel`のテキストが空欄ではなく指定依頼の内容を表す
- [ ] `condition_type == "item"`の指定依頼に合致するレシピで調合・納品すると、`DeliveryResult`の貢献度・報酬が`match_bonus_multiplier`倍になっている（既存`DeliveryResolver`の契約どおり、本タスクでは配線の結果のみ検証する）
- [ ] `GameState.advance_turn_growth()`相当のUI操作（庭画面の「ターンを終了する」ボタン押下）後、`_current_daily_order`が変化しうる（`RngService.set_seed()`で固定した場合は決定的に新しい値になることを確認する）
- [ ] 再抽選後、調合画面へ切り替えると`DailyOrderLabel`が新しい指定依頼の内容に追随している
- [ ] **異常系**: `_set_unlocked_recipe_ids_for_test()`等でGランク相当（解禁レシピ1件・特性未解禁）に構成し、かつその1件を対象とする`.tres`が存在しない状況を作った場合でも、庭→調合→納品→ターン終了の一巡が例外なく完走し、`DailyOrderLabel`が「指定依頼: なし」相当の表示になる
- [ ] **異常系**: 昇格試験中（`GameState.exam_started`発行後）は、調合プレビューと納品結果の両方でボーナスが適用されない（既存契約の非退行、FR-201）
- [ ] **境界値**: 試験中のターン進行（「ターンを進める」ボタン）を挟んでも`_current_daily_order`が変化しない（FR-302）

## Implementation Notes

- 参照すべき既存コード:
  - `atelier/tests/integration/test_main_scene_happy_path.gd`（main-scene-integration Planの既存パターン。`scene_runner()`でのUI操作シミュレーション方法、庭での収穫・調合実行・ターン終了の一連の操作手順をそのまま踏襲できる）
  - `atelier/tests/integration/test_game_state_deliver_pending_products.gd`（`DeliveryResolver`経由のボーナス反映確認の既存パターン）
  - `.claude/rules/godot-debug-tools.md`「状態セットアップ雛形」（`scene_runner()`の使い方、テストヘルパー関数パターン）
  - `atelier/autoload/rng_service.gd:6-7`（`RngService.set_seed()`。決定的な乱数固定でテストの再現性を確保する）
- 実装のヒント: `data/daily_orders/`, `data/materials/`, `data/recipes/`等の実データ（task 001以前から存在するものと、task 001で新規作成したものの双方）をそのまま使ってよい。「Gランクで達成可能な指定依頼が0件」の異常系シナリオは、実データの構成に依存せず確実に再現するため、テスト専用APIで`_daily_order_masters`相当を差し替える手段が必要な場合は、既存の`_set_current_daily_order_for_test()`とは別に、必要最小限のテスト専用APIを追加してよいかを判断する（追加する場合は`GameStateTestSupport`に1関数追加する程度に留め、本番コードパスへの影響がないことを確認する）。
- 注意事項: `before_test()`で`GameState.reset_for_test()`を呼びテスト間の状態を分離する。`GameState`のsignalを監視する場合は`monitor_signals(GameState, false)`を明示する（Autoload監視時の重大な罠）。

## Files

- 新規: `atelier/tests/integration/test_main_scene_daily_order_flow.gd`
- 変更（必要な場合のみ）: `atelier/autoload/game_state_test_support.gd`（テスト専用APIの追加、最小限）
