---
id: "013"
title: "GameState.plant_seed()を実装する"
status: done
priority: 3
dependencies: ["006", "012"]
estimated_complexity: medium
---

# Task: GameState.plant_seed()を実装する

## Goal

`GameState.plant_seed(seed_id)`を実装する（FR-101, FR-109, FR-110）。`seed_inventory`の在庫確認→`Planting.plant`呼び出し→両方成功時のみ在庫を1減算、の3ステップ順序を厳守する。

## Interfaces

```gdscript
# autoload/game_state.gd（既存ファイルに追記）

signal seed_planted(slot_index: int, seed_id: StringName)               # 🔵 FR-101
signal plant_seed_failed(seed_id: StringName, error_code: StringName)   # 🔴 UI側のトースト表示（NFR-202）に必要な新規補完

## (1) seed_inventoryの対象countを確認 (2) Planting.plantを実行 (3) 両方成功時のみcountを1減算
## 🔵 FR-101（3ステップ順序が確定設計）
func plant_seed(seed_id: StringName) -> Result:
	pass
```

## Test Strategy

- [ ] **正常系**: 空きスロット・種在庫ありで`plant_seed(&"seed_herb")`が成功し、`Result.success == true`、`seed_planted`シグナルが発行される（AC-001）
- [ ] **正常系**: 植え付け成功後、`get_state().garden_state.plants`に新規`PlantState`が追加され、`get_state().seed_inventory`の該当`count`が1減算されている（AC-001）
- [ ] **境界値**: `count == 1`の種を植えると成功し`count`が0になる（AC-001境界値）
- [ ] **異常系**: 庭スロット満杯のとき`plant_seed`が失敗を返し（`error_code == &"slot_full"`）、`plant_seed_failed`シグナルが発行され、`garden_state`・`seed_inventory`のいずれも変化しない（AC-002）
- [ ] **異常系**: `seed_inventory`に対象`seed_id`が存在しない、または`count == 0`のとき、`Planting.plant`を呼び出さずに`plant_seed`が失敗を返す（`error_code == &"seed_not_owned"`）（AC-003, FR-110）
- [ ] **異常系**: `_seed_masters`に存在しない未知の`seed_id`を渡すと`error_code == &"unknown_seed_id"`で失敗する（NFR-101）

## Implementation Notes

- 参照すべき既存コード: `docs/design/atelier-alchemy-core/core-systems.md` L86-94（種の消費フロー3ステップ）、タスク006で実装した`Planting.plant`/`Planting.can_plant`
- 実装のヒント: `_garden_slot_count`（タスク012で追加したフィールド）を`slot_limit`として`Planting.plant`に渡す
- 注意事項: ステップ(1)の在庫確認を`Planting.plant`呼び出しより必ず先に行うこと（FR-110「`Planting.plant`を呼び出さずに失敗を返す」）。テストでは`Planting.plant`が呼ばれていないことまでは直接検証できないため、`garden_state`が変化していないことで代替確認する

## Files

- 変更: `atelier/autoload/game_state.gd`
- 変更: `atelier/tests/integration/test_game_state_garden.gd`（タスク012のテストファイルに追記）
