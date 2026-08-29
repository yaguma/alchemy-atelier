---
id: "003"
title: "GameStateに指定依頼のロード・初回抽選・毎ターン再抽選を配線する"
status: pending
priority: 2
dependencies: ["002"]
estimated_complexity: medium
---

# Task: GameStateに指定依頼のロード・初回抽選・毎ターン再抽選を配線する

## Goal

`GameStateGuildDelegate`に指定依頼マスターデータのロード・初回抽選を行う`load_daily_order_master_data()`と、現在の解禁状況で再抽選する`reroll_daily_order()`を実装し、`GameState.advance_turn_growth()`から毎ターン終了時に再抽選が呼ばれるようにする。

## Interfaces

```gdscript
# atelier/autoload/game_state_guild_delegate.gd への追加
## res://data/daily_orders/からDailyOrderMasterをロードしstate._daily_order_mastersに格納した後、
## 初回抽選を1回行いstate._current_daily_orderへ設定する。🔵 load_rank_master_data()と同型パターン
## FR-008, FR-101
static func load_daily_order_master_data(state: GameStateScript) -> void

## 現在の解禁状況（state._unlocked_recipe_ids, state.is_current_rank_traits_unlocked()）で
## DailyOrderSelector.filter_achievable()した後、RngService.randf()の払い出し値で
## DailyOrderSelector.select()し、state._current_daily_orderを更新する。
## 絞り込み結果が空の場合はnullを設定する（FR-103, FR-202, FR-405）。🔵 FR-102, FR-103
static func reroll_daily_order(state: GameStateScript) -> void
```

```gdscript
# atelier/autoload/game_state.gd への追加
var _daily_order_masters: Array[DailyOrderMaster] = []  # 🔵 新規フィールド。既存load_*と同型

func load_daily_order_master_data() -> void:  # 🔵 既存load_*と同型の1行委譲
	GameStateGuildDelegate.load_daily_order_master_data(self)

# advance_turn_growth()の変更（既存関数、CON-010）
func advance_turn_growth() -> void:
	GameStateGardenDelegate.advance_turn_growth(self)
	GameStateGuildDelegate.reroll_daily_order(self)  # 🔵 FR-102, CON-010（新規追加行）
```

```gdscript
# atelier/scenes/main.gd への追加（既存load_garden/alchemy/workshop/rank_master_data()と同型）
# _enter_tree()に1行追加:
#   GameState.load_daily_order_master_data()
```

## Test Strategy

- [ ] `GameState.load_daily_order_master_data()`呼び出し後、`GameState.get_state()["current_daily_order"]`が非`null`になる（達成可能なエントリが存在する状態で）
- [ ] `load_daily_order_master_data()`呼び出し後、`GameState.resolve_daily_order_for_delivery()`が非`null`を返す
- [ ] `GameState.advance_turn_growth()`実行後、`_current_daily_order`が再抽選される（`monitor_signals`ではなく`get_state()`のbefore/after比較、または`RngService.set_seed()`で決定的に検証）
- [ ] **異常系**: マスターデータが0件（`res://data/daily_orders/`が空相当）でも`load_daily_order_master_data()`がクラッシュせず`_current_daily_order`は`null`のままになる
- [ ] **異常系**: `advance_turn_growth()`実行時に絞り込み後のプールが空になった場合、`_current_daily_order`が`null`に更新される（フォールバック用の特別なマスターは生成されない、FR-405）
- [ ] **境界値**: `load_daily_order_master_data()`を2回呼んでもクラッシュしない（マスターデータの再ロード自体は許容、ランク初期化のような1回限りガードは不要）
- [ ] **境界値**: `advance_turn_growth()`実行後も、試験中（`_in_exam == true`）であれば`resolve_daily_order_for_delivery()`は引き続き`null`を返す（FR-201の非退行）
- [ ] **境界値**: `advance_exam_turn()`（試験中のターン進行）を実行しても`_current_daily_order`が変化しない（再抽選しない、FR-302）
- [ ] `MainScene._enter_tree()`が`GameState.load_daily_order_master_data()`を呼ぶ（`scene_runner("res://scenes/main.tscn")`での統合テスト）

## Implementation Notes

- 参照すべき既存コード:
  - `atelier/autoload/game_state_rank_delegate.gd`（`load_rank_master_data()`相当の実装パターン。ただし本タスクでは「初回のみ」の冪等ガード（`_rank_state_initialized`相当）は**不要**。指定依頼は再ロードのたび再抽選しても問題ない設計のため）
  - `atelier/autoload/game_state_garden_delegate.gd:112-142`（`advance_turn_growth()`の既存実装。この直後にguild delegateを呼ぶ）
  - `atelier/autoload/game_state.gd:261-262`（`is_current_rank_traits_unlocked()`。既存の公開関数をそのまま再利用し、判定式を重複実装しない、NFR-101）
  - `atelier/autoload/game_state.gd:43`（`_unlocked_recipe_ids`フィールド）
  - `atelier/autoload/rng_service.gd:10-11`（`RngService.randf() -> float`。`[0.0, 1.0)`の乱数値を払い出す）
  - `atelier/scenes/main.gd:39-43`（`_enter_tree()`内の既存4つの`load_*_master_data()`呼び出し。5つ目として追加する）
- 実装のヒント: `reroll_daily_order()`は`DailyOrderSelector.filter_achievable(state._daily_order_masters, state._unlocked_recipe_ids, state.is_current_rank_traits_unlocked())`で絞り込んだ後、`DailyOrderSelector.select(pool, RngService.randf())`で抽選し、結果を`state._current_daily_order = result`に代入する（`result`が`null`でもそのまま代入してよい）。`load_daily_order_master_data()`は`state._daily_order_masters = MasterDataLoader.load_all(&"daily_orders")`でロードした後、末尾で`reroll_daily_order(state)`を呼び出す（初回抽選、FR-101）。
- 注意事項: `advance_turn_growth()`の変更は既存の`GameStateGardenDelegate.advance_turn_growth(self)`呼び出しの**直後**に追加する（呼び出し順を変えない）。`_daily_order_masters`は`GameState.reset_for_test()`でもクリアすること（既存の他フィールドと同様のリセット対象に含める）。

## Files

- 変更: `atelier/autoload/game_state_guild_delegate.gd`, `atelier/autoload/game_state.gd`, `atelier/scenes/main.gd`
- テスト: `atelier/tests/integration/test_game_state_daily_order_lifecycle.gd`（新規）
