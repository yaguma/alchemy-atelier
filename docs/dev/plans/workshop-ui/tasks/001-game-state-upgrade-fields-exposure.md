---
id: "001"
title: "GameState.get_state()にupgrade_masters/purchased_upgrade_countsを公開する"
status: pending
priority: 1
dependencies: []
estimated_complexity: low
---

# Task: GameState.get_state()にupgrade_masters/purchased_upgrade_countsを公開する

## Goal

`GameState.get_state()`の戻り値辞書に`"upgrade_masters"`（`Dictionary[StringName, UpgradeMaster]`）と`"purchased_upgrade_counts"`（`Dictionary[StringName, int]`）の2キーを追加し、`WorkshopScreen`（後続タスク）が一覧描画に必要な情報を取得できるようにする（FR-007, FR-008）。

## Interfaces

```gdscript
# atelier/autoload/game_state.gd の get_state() 内、既存の "can_purchase_permanent" キー行の直前または直後に追加する
func get_state() -> Dictionary:
	# ...(既存のcloned_inventory/cloned_pending_products構築処理は変更しない)...
	return {
		# ...(既存キーは全て変更しない)...
		"can_purchase_permanent": _can_purchase_permanent,  # 🔵 既存（変更不要）
		# 🔵 FR-007。seed_masters/recipe_masters公開と同型。UpgradeMasterはResource（不変前提の
		# マスターデータ）のため、Dictionary自体の浅いduplicate()のみで防御的コピー要件を満たす
		"upgrade_masters": _upgrade_masters.duplicate(),
		# 🔵 FR-008。値がint（値型）のDictionaryのため、浅いduplicate()でキー追加/削除・値上書きの
		# いずれからも_purchased_upgrade_counts本体を保護できる
		"purchased_upgrade_counts": _purchased_upgrade_counts.duplicate(),
	}
```

> 信号機: 🔵 すべて確定（Plan設計フェーズで確認済み）。`_upgrade_masters`/`_purchased_upgrade_counts`フィールド自体・`load_workshop_master_data()`・テスト専用API（`_set_can_purchase_permanent_for_test`, `_set_purchased_upgrade_counts_for_test`）は先行Plan `workshop` で実装済みのため本タスクでは変更しない。

## Test Strategy

既存の `atelier/tests/integration/test_game_state_workshop_fields.gd` にテストケースを追加する（新規ファイルは作らない）。

- [ ] `get_state()`の戻り値が`"upgrade_masters"`キーを持つ（`has("upgrade_masters")`が真）
- [ ] `reset_for_test()`直後、`get_state()["upgrade_masters"]`は空のDictionary（`size() == 0`）
- [ ] `load_workshop_master_data()`呼び出し後、`get_state()["upgrade_masters"]`に実データ由来の`UpgradeMaster`が5件格納される（`atelier/data/upgrades/`の`.tres`が5件存在することを前提とする。値の型が`UpgradeMaster`であることも確認する）
- [ ] `get_state()`の戻り値が`"purchased_upgrade_counts"`キーを持つ
- [ ] `_set_purchased_upgrade_counts_for_test({...})`で注入した値が`get_state()["purchased_upgrade_counts"]`に反映される
- [ ] エッジケース（防御的コピー）: `get_state()["upgrade_masters"]`を取得後、戻り値のDictionaryにキーを追加/削除しても、再度`get_state()`を呼んだ結果には影響しない（`GameState._upgrade_masters`本体が汚染されないことを確認する）
- [ ] エッジケース（防御的コピー）: `get_state()["purchased_upgrade_counts"]`を取得後、戻り値の値を書き換えても、再度`get_state()`を呼んだ結果には反映されない

## Implementation Notes

- 参照すべき既存コード: `atelier/autoload/game_state.gd`（`get_state()`本体、95〜142行目付近。`"seed_masters": _seed_masters.duplicate()`が同型の浅い複製パターン）、`atelier/tests/integration/test_game_state_workshop_fields.gd`（既存テストの前提・命名規則）
- 実装のヒント: `get_state()`は1つの辞書リテラルをreturnしているだけなので、既存キーの並びを崩さないよう`can_purchase_permanent`の近くに新規2行を追加するだけでよい。ロジック変更は不要
- 注意事項: `_upgrade_masters`/`_purchased_upgrade_counts`フィールド自体や`GameStateWorkshopDelegate`・`load_workshop_master_data()`・既存テスト専用APIは一切変更しないこと（先行Plan `workshop` の資産）。`gdlint`の`max-public-methods`等の制約に抵触しないことを確認する（本タスクは`get_state()`本体の変更のみで新規publicメソッド追加はない）

## Files

- 変更: `atelier/autoload/game_state.gd`
- テスト: `atelier/tests/integration/test_game_state_workshop_fields.gd`（既存ファイルにテストケース追加）
