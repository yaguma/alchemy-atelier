---
id: "004"
title: "GameStateSaveDelegateにrestore_save_data()を実装する"
status: done
priority: 1
dependencies: ["003"]
estimated_complexity: high
---

# Task: GameStateSaveDelegateにrestore_save_data()を実装する

## Goal

`collect_save_data()`の逆変換として、検証済み（`SaveDataCodec.validate_and_unwrap()`通過済み）のDictionaryを`GameState`の各private fieldへ直接適用する。呼び出し時点で`state`のマスターデータ（`_daily_order_masters`等）が既にロード済みであることを前提とする。

## Interfaces

```gdscript
# atelier/autoload/game_state_save_delegate.gd に追記

## 検証済みdataをstateへ適用する。呼び出し前提: state.load_*_master_data()が全て実行済みであること
## （current_daily_order_id等のID→Resource解決に必要、🔴 呼び出し順序はSaveService側で保証する。
## task 006/009参照。本関数自体は呼び出し順序を強制しない）
static func restore_save_data(state: GameStateScript, data: Dictionary) -> void

## data["current_daily_order_id"]（String、空文字列なら"指定依頼なし"）から
## state._daily_order_masters（Array[DailyOrderMaster]、ロード済み前提）を線形探索し、
## 一致するidを持つDailyOrderMasterを返す。見つからない場合・空文字列の場合はnullを返す
## （🔵 GameState._get_current_rank_master_or_fallback()と同様、見つからない場合も例外を投げない）
static func _find_daily_order_master_by_id(
	daily_order_masters: Array[DailyOrderMaster], id: String
) -> DailyOrderMaster

## data["garden_state"]（Dictionary）からGardenStateを再構築する（_collect_garden_state()の逆変換）
static func _restore_garden_state(data: Dictionary) -> GardenState

## data["inventory"]（Array）からArray[MaterialInstance]を再構築する
static func _restore_inventory(data: Array) -> Array[MaterialInstance]

## data["pending_products"]（Array）とdaily_order_masters（ID解決用）から
## Array[ProductInstance]を再構築する
static func _restore_pending_products(
	data: Array, daily_order_masters: Array[DailyOrderMaster]
) -> Array[ProductInstance]

## data["rank_state"]（Dictionary）からRankStateを再構築する
static func _restore_rank_state(data: Dictionary) -> RankState

## data["exam_state"]（Dictionary）からExamStateを再構築する
static func _restore_exam_state(data: Dictionary) -> ExamState
```

## Test Strategy

- [ ] **ラウンドトリップ**: `reset_for_test()`→複数のテスト専用API（`_inject_material_for_test`, `_inject_plant_for_test`, `_set_current_daily_order_for_test`, `_set_gold_for_test`等）で代表的な状態を構築→`collect_save_data()`→`restore_save_data()`（別のGameStateインスタンス相当、または同一インスタンスを`reset_for_test()`し直してから適用）した結果、`get_state()`の主要フィールド（`gold`, `current_turn`, `current_phase`, `inventory`の`instance_id`/`quality_score`, `garden_state.plants`の`slot_index`/`seed_id`）が元の値と一致する
- [ ] `current_daily_order_id`が空文字列の場合、復元後の`_current_daily_order`が`null`になる
- [ ] `current_daily_order_id`が`_daily_order_masters`に存在するIDの場合、復元後の`_current_daily_order`がそのIDを持つDailyOrderMasterになる
- [ ] `current_daily_order_id`が`_daily_order_masters`に存在しないID（マスターデータ側の変更等でIDが消えたケース）の場合、例外を投げずに`_current_daily_order`が`null`になる（安全側フォールバック、異常系）
- [ ] `pending_products`内の`has_daily_order_snapshot=true`かつ有効な`daily_order_snapshot_id`を持つ要素が、復元後`ProductInstance.daily_order_snapshot`に正しいDailyOrderMasterを保持する
- [ ] `last_rank_outcome`/`last_exam_outcome`のint値が正しく`RankOutcome.Value`/`ExamOutcome.Value`のenumへ復元される（境界値: 各enumの最小値・最大値）

## Implementation Notes

- 参照すべき既存コード: `atelier/autoload/game_state_test_support.gd`の各`set_*_for_test()`（private fieldへの直接代入パターン、および「内部正本は独立コピーとして保持する」という防御的コピー方針）
- 実装のヒント: 配列・オブジェクトを復元する際は必ず新規インスタンスを生成する（呼び出し元のDictionary/Arrayをそのまま保持しない、`state-management.md`の防御的コピー要件に準じる）
- 注意事項: `_daily_order_masters`は`Array[DailyOrderMaster]`型で`GameState`に保持されているが、現状publicアクセスできる形になっているか（`state._daily_order_masters`への直接アクセス可否）を実装前に確認すること。既存delegateパターン同様、private-by-convention（`_`プレフィックスのみ、GDScript的には他スクリプトからも参照可能）のため直接アクセス自体は技術的に可能

## Files

- 変更: `atelier/autoload/game_state_save_delegate.gd`
- テスト: `atelier/tests/integration/test_game_state_save_delegate_restore.gd`
