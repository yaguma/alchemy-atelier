# Plan: daily-orders

## Requirements Summary

`DailyOrderMaster`（指定依頼マスター）のスキーマと、消費側（`DeliveryResolver.matches_order()`/`resolve()`、`GameState.resolve_daily_order_for_delivery()`）は既に確定済みだが、実データ（`res://data/daily_orders/*.tres`）が0件で、毎ターン指定依頼を抽選・更新する本番ロジックが存在しない（`_current_daily_order`への代入経路がテスト専用APIのみ）。guild Planのrequirements.md FR-405が「実データ作成と再抽選ロジックは別planの対象」と予告しており、本Planがそれに該当する。

詳細: [requirements.md](requirements.md) | [user-stories.md](user-stories.md) | [acceptance-criteria.md](acceptance-criteria.md)

スコープに含める主な要素:
- G〜S各ランクで達成可能な`DailyOrderMaster`実データ（`.tres`、仮値）
- `MasterDataLoader`への`&"daily_orders"`カテゴリ追加
- 抽選ロジック（Domain層の純粋関数、`features/guild/logic/daily_order_selector.gd`）: 解禁状況による絞り込み＋均一抽選
- `GameState.load_daily_order_master_data()`（初回ロード＋初回抽選）と、`GameState.advance_turn_growth()`直後のフックによる毎ターン再抽選
- `AlchemyScreen`への指定依頼表示UI追加

スコープ外（Won't Have）:
- `DailyOrderMaster`スキーマ・`DeliveryResolver`・`resolve_daily_order_for_delivery()`の変更（すべて確定済み資産）
- バランス数値（`match_bonus_multiplier`等）の正式確定（別Planで実施、本Planは仮値）
- 試験中（`advance_exam_turn()`）のターン進行での再抽選（既存契約「試験中は常にnull」を維持するため対象外）
- `condition_type`のitem/trait別の重み付け抽選（本Planは均一抽選のみ）

## Design Overview

### インターフェース設計

```gdscript
# atelier/shared/loaders/master_data_loader.gd への変更
const DAILY_ORDERS_DIR := "res://data/daily_orders/"  # 🔵 既存4定数と同型
# _resolve_dir_path()に分岐追加: &"daily_orders": return DAILY_ORDERS_DIR
# _is_allowed_type()に分岐追加: &"daily_orders": return resource is DailyOrderMaster
```

```gdscript
# atelier/features/guild/logic/daily_order_selector.gd（新規、Functional Core）
class_name DailyOrderSelector

## 現在の解禁状況で達成可能なDailyOrderMasterのみへ絞り込む純粋関数（FR-005, FR-203, NFR-302）。
## condition_type=="item"はtarget_recipe_idがunlocked_recipe_idsに含まれるもの、
## condition_type=="trait"はtraits_unlocked==trueの場合のみ残す。未知のcondition_type・
## 空文字ターゲットは除外する
static func filter_achievable(
    all_orders: Array[DailyOrderMaster],
    unlocked_recipe_ids: Array[StringName],
    traits_unlocked: bool,
) -> Array[DailyOrderMaster]

## 絞り込み済みプールから乱数値[0.0, 1.0)を用いて1件を均一抽選する純粋関数（FR-006, FR-301, FR-404）。
## プールが空の場合はnullを返す。乱数はRngServiceから払い出された値を引数で受け取り、
## 自己生成しない
static func select(pool: Array[DailyOrderMaster], random_value: float) -> DailyOrderMaster
```

```gdscript
# atelier/autoload/game_state_guild_delegate.gd への追加
## res://data/daily_orders/からDailyOrderMasterをロードしstate._daily_order_mastersに格納した後、
## 初回抽選を1回行いstate._current_daily_orderへ設定する（FR-008, FR-101）。
## load_rank_master_data()と同型パターン
static func load_daily_order_master_data(state: GameStateScript) -> void

## 現在の解禁状況（state._unlocked_recipe_ids, state.is_current_rank_traits_unlocked()）で
## DailyOrderSelector.filter_achievable()した後、RngService.randf()の払い出し値で
## DailyOrderSelector.select()し、state._current_daily_orderを更新する（FR-102, FR-103）
static func reroll_daily_order(state: GameStateScript) -> void
```

```gdscript
# atelier/autoload/game_state.gd への追加
var _daily_order_masters: Array[DailyOrderMaster] = []  # 🔵 新規フィールド。既存load_*と同型

func load_daily_order_master_data() -> void:  # 🔵 既存load_*と同型の1行委譲
    GameStateGuildDelegate.load_daily_order_master_data(self)

# advance_turn_growth()への追加行（既存関数を変更、CON-010）
func advance_turn_growth() -> void:
    GameStateGardenDelegate.advance_turn_growth(self)
    GameStateGuildDelegate.reroll_daily_order(self)  # 🔵 FR-102, CON-010（新規追加行）
```

```gdscript
# atelier/features/alchemy/ui/alchemy_screen.gd / .tscn への変更
# 新規ノード: %DailyOrderLabel（Label、RecipeOptionButtonとAlchemyPreviewPanelの間に配置。NFR-201）
# _refresh()内、_daily_order_for_preview設定直後にラベル文言を更新する処理を追加（🟡 CON-011、
# 文言・詳細配置は本Plan内で確定する低リスクな未確定事項）
```

### データフロー

```
[初回ロード]
MainScene._enter_tree() → GameState.load_daily_order_master_data()
  → GameStateGuildDelegate.load_daily_order_master_data()
    → MasterDataLoader.load_all(&"daily_orders") → state._daily_order_masters
    → reroll_daily_order(state) [内部呼び出し、初回抽選]

[毎ターン再抽選]
GardenScreen: 「ターンを終了する」→ GameState.advance_turn_growth()
  → GameStateGardenDelegate.advance_turn_growth(state)  [既存、turn_growth_advanced発行]
  → GameStateGuildDelegate.reroll_daily_order(state)     [新規]
    → filter_achievable(all, unlocked_recipe_ids, is_current_rank_traits_unlocked())
    → select(pool, RngService.randf())
    → state._current_daily_order = 結果（nullもありうる）

[表示・消費]
AlchemyScreen._refresh() → _daily_order_for_preview = GameState.resolve_daily_order_for_delivery()
  → %DailyOrderLabelへ反映（新規）
  → 既存の_recompute_preview()・DeliveryResolver.resolve()は無変更のまま_daily_order_for_previewを消費
```

## Task Dependency Graph

```
001 daily-order-fixture-and-loader（基盤・独立）
  ├─→ 002 daily-order-selector-logic（純粋関数、001の実データで統合検証）
  │     └─→ 003 daily-order-lifecycle-wiring（load_daily_order_master_data・advance_turn_growth配線）
  │           ├─→ 004 daily-order-ui-display
  │           └─→ 005 integration-test-daily-order-flow（004完了後、UI表示込みで通しテスト）
```

トポロジカル順: 001 → 002 → 003 → 004 → 005

## Cross-Plan Dependencies

- `atelier/features/guild/resources/daily_order_master.gd`（guild Planの成果物）は本Planで**変更しない**（CON-001）。
- `atelier/autoload/game_state.gd`の`resolve_daily_order_for_delivery()`（guild Planの成果物）は本Planで**変更しない**（CON-002）。
- `atelier/data/daily_orders/*.tres`（本Plan成果物）は将来のバランス調整Plan（`balance-design.md`の🟡🔴項目解消）が数値を上書きする前提の**仮データ**である（main-scene-integration Planの`data/ranks/*.tres`と同方針）。
