---
id: "003"
title: "GameStateSaveDelegateにcollect_save_data()を実装する"
status: done
priority: 1
dependencies: []
estimated_complexity: high
---

# Task: GameStateSaveDelegateにcollect_save_data()を実装する

## Goal

`GameState`の全private fieldから、マスターデータ（`_seed_masters`等の`Dictionary[StringName, Resource]`群と`_daily_order_masters`配列自体）を除いたゲーム進行状態を、JSON化可能なプリミティブのみで構成されたDictionaryへ変換する。既存の`game_state_{garden,alchemy,guild,rank,workshop}_delegate.gd`・`game_state_test_support.gd`と同型の「`static func(state: GameStateScript, ...)`が`state`の private fieldへ直接アクセスする」パターンに従う。

## Interfaces

```gdscript
# atelier/autoload/game_state_save_delegate.gd
## GameStateの全機能delegate・GameStateTestSupportと同じ委譲パターン（🔵 既存パターン踏襲）
class_name GameStateSaveDelegate

const GameStateScript = preload("res://autoload/game_state.gd")

## stateの現在のゲーム進行状態から、マスターデータを除いたJSON化可能なDictionaryを構築して返す。
## StringNameはString()でStringへ変換する（JSON.stringify()の安全側対応、🟡）。
## 戻り値のキー一覧はtask 002の_is_valid_save_data()が要求する必須キー一覧と完全に一致させること
static func collect_save_data(state: GameStateScript) -> Dictionary

## state._garden_state（GardenState）を {"plants": [ {slot_index, seed_id, grown_turns, is_matured}, ... ]} へ変換する
static func _collect_garden_state(garden_state: GardenState) -> Dictionary

## state._inventory（Array[MaterialInstance]）を
## [ {"instance_id", "material_id", "quality_score", "trait_tags": [String,...]}, ... ] へ変換する
static func _collect_inventory(inventory: Array[MaterialInstance]) -> Array

## state._pending_products（Array[ProductInstance]）を
## [ {"recipe_id", "quality_score", "activated_traits": [String,...], "contribution", "reward",
##    "has_daily_order_snapshot", "daily_order_snapshot_id"}, ... ] へ変換する。
## daily_order_snapshotがnullの場合 daily_order_snapshot_id は空文字列""とする
static func _collect_pending_products(pending_products: Array[ProductInstance]) -> Array

## state._rank_state（RankState）を {"quota": float, "elapsed_turn": int} へ変換する
static func _collect_rank_state(rank_state: RankState) -> Dictionary

## state._exam_state（ExamState）を
## {"exam_quota", "exam_quota_max", "exam_elapsed_turn", "exam_turn_limit"} へ変換する
static func _collect_exam_state(exam_state: ExamState) -> Dictionary
```

## Test Strategy

- [ ] `GameState.reset_for_test()`直後（初期状態）で`collect_save_data()`を呼ぶと、`gold=0`, `current_turn=1`, `current_phase="garden"`, `inventory=[]`, `pending_products=[]`, `current_daily_order_id=""` 等の初期値が正しく含まれる
- [ ] `_inject_material_for_test()`で在庫に素材を1件注入後、`collect_save_data()["inventory"]`に`instance_id`/`material_id`/`quality_score`/`trait_tags`が正しく反映される
- [ ] `_inject_plant_for_test()`で庭に苗を1件注入後、`collect_save_data()["garden_state"]["plants"]`に`slot_index`/`seed_id`/`grown_turns`/`is_matured`が正しく反映される
- [ ] `_inject_pending_product_for_test()`で`has_daily_order_snapshot=false`の調合物を注入した場合、`daily_order_snapshot_id`が空文字列になる
- [ ] `_inject_pending_product_for_test()`で`has_daily_order_snapshot=true`かつ`daily_order_snapshot`に`id="order_a"`のDailyOrderMasterを持つ調合物を注入した場合、`daily_order_snapshot_id`が`"order_a"`になる
- [ ] `_set_current_daily_order_for_test()`で`id="order_b"`のDailyOrderMasterを設定した場合、`current_daily_order_id`が`"order_b"`になる。未設定（null）の場合は空文字列になる
- [ ] `StringName`型のフィールド（`current_phase`, `current_rank_id`, `unlocked_recipe_ids`の各要素）が全て`String`型として格納される（型検証）

## Implementation Notes

- 参照すべき既存コード: `atelier/autoload/game_state.gd`の`get_state()`（全フィールド一覧の参照元）、`atelier/autoload/game_state_test_support.gd`（`state: GameStateScript`を第一引数に取り private field へ直接アクセスするパターン）
- 実装のヒント: `get_state()`はUI向けにマスターデータも含めて返すため流用せず、`collect_save_data()`は`state`の private field を直接読む（`state._gold`, `state._inventory`等）。マスターデータ系フィールド（`_seed_masters`, `_material_masters`, `_recipe_masters`, `_rank_masters`, `_upgrade_masters`, `_daily_order_masters`, `_warned_missing_rank_master_ids`）は収集対象外とする
- 注意事項: `_last_rank_outcome`/`_last_exam_outcome`は`RankOutcome.Value`/`ExamOutcome.Value`のenum型のため、int値として格納し復元時（task 004）にenumへキャストし直す

## Files

- 新規: `atelier/autoload/game_state_save_delegate.gd`
- テスト: `atelier/tests/integration/test_game_state_save_delegate_collect.gd`
