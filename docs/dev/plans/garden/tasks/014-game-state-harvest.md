---
id: "014"
title: "GameState.harvest()を実装する"
status: done
priority: 3
dependencies: ["011", "012"]
estimated_complexity: medium
---

# Task: GameState.harvest()を実装する

## Goal

`GameState.harvest(slot_index)`を実装する（FR-104〜106, FR-108, CON-004でメソッド名`harvest`が確定）。`RngService`から品質用・特性用の乱数を個別に払い出し、`Harvest.harvest`に渡す。成功時は`inventory`へ追加しスロットを解放する。

## Interfaces

```gdscript
# autoload/game_state.gd（既存ファイルに追記）

signal material_harvested(material: MaterialInstance, slot_index: int)  # 🔵 FR-105
signal harvest_failed(slot_index: int, error_code: StringName)          # 🔴 UI側フィードバック用の新規補完

## RngServiceから品質用・特性用の乱数を個別に払い出し、Harvest.harvestへ渡す（🔵 FR-104, FR-402）
## 成功時: MaterialInstanceにinstance_idを採番して確定し、inventoryへ追加、該当スロットをgarden_state.plantsから除去
func harvest(slot_index: int) -> Result:
	pass
```

## Test Strategy

- [ ] **正常系**: 成熟直後（待機0ターン）のスロットを収穫すると`Result.success == true`、`value.quality_score == master.base_quality`、`material_harvested`シグナルが発行される（AC-005）
- [ ] **正常系**: 収穫成功後、`get_state().inventory`に生成された`MaterialInstance`が追加され、`get_state().garden_state.plants`から該当`slot_index`が除去されている（AC-005）
- [ ] **正常系**: 収穫のたびに`instance_id`が一意に採番される（2回連続で収穫した際に異なる`instance_id`になる）
- [ ] **異常系**: 存在しない`slot_index`を指定すると`Result.success == false`かつ`error_code == &"slot_not_found"`、`harvest_failed`シグナルが発行される（NFR-101）
- [ ] **異常系**: 枯死済み（`is_dead == true`）のスロットを収穫しようとすると失敗を返し（`error_code == &"withered"`）、`GardenState`・`inventory`のいずれも変化しない（AC-007）
- [ ] **異常系**: 収穫成功後、同じ`slot_index`を再度収穫しようとすると`&"slot_not_found"`で失敗する（AC-005異常系）

## Implementation Notes

- 参照すべき既存コード: `atelier/autoload/rng_service.gd`（`randf()`のAPI確認）、タスク011で実装した`Harvest.harvest`
- 実装のヒント: `RngService.randf()`を2回、変数を分けて呼び出すこと（1回の呼び出し結果を使い回さない。FR-104「品質用・特性用の乱数がそれぞれ払い出され」）。`instance_id`の採番は`"mat_%04d" % _material_instance_seq`のような形式で`_material_instance_seq`をインクリメントしながら行う
- 注意事項: `Harvest.harvest`がタスク011の実装方針次第で`instance_id`にプレースホルダー値を設定する場合、本タスクで`GameState`側が採番した実際の`instance_id`に上書きする処理が必要になる（タスク011の実装内容を確認してから着手すること）

## Files

- 変更: `atelier/autoload/game_state.gd`
- 変更: `atelier/tests/integration/test_game_state_garden.gd`
