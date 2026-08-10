---
id: "006"
title: "Planting（種植えロジック）を実装する"
status: pending
priority: 2
dependencies: ["001", "004", "005"]
estimated_complexity: medium
---

# Task: Planting（種植えロジック）を実装する

## Goal

庭への種植えを担う純粋関数`Planting.can_plant`/`Planting.plant`を`features/garden/logic/planting.gd`に実装する（FR-102, FR-109）。空きスロット判定と、空きスロットへの新規`PlantState`作成のみを行い、`seed_inventory`の消費や`GardenState.plants`への実際の追加は呼び出し元（`GameState`, タスク013）の責務とする。

## Interfaces

```gdscript
# features/garden/logic/planting.gd
class_name Planting

## garden_state.plants.size() < slot_limit ならtrue（🔵 core-systems.md L63）
static func can_plant(garden_state: GardenState, slot_limit: int) -> bool:
	pass

## 成功時: Result.value に新規PlantState（空きslot_index、grown_turns=0, is_matured=false）を格納して返す。
## GardenState.plantsへの追加自体は行わない（呼び出し元の責務、🟡core-systems.mdの表記解釈）
## 失敗時: can_plantが偽ならResult.fail(&"slot_full")
static func plant(
	garden_state: GardenState,
	seed_id: StringName,
	master: SeedMaster,
	slot_limit: int
) -> Result:
	pass
```

## Test Strategy

- [ ] **正常系**: 空きスロットがある状態（`plants.size() < slot_limit`）で`can_plant`が`true`を返す
- [ ] **正常系**: `plant`成功時、`Result.success == true`かつ`Result.value`が`PlantState`型で`seed_id`が渡した値と一致し`grown_turns == 0`, `is_matured == false`
- [ ] **正常系**: 使用中スロット（`slot_index`）に歯抜けがある場合（例: 0番が空き、1番使用中）でも、空いている最小の`slot_index`が採番される
- [ ] **異常系**: スロット満杯（`plants.size() >= slot_limit`）で`can_plant`が`false`を返す
- [ ] **異常系**: スロット満杯で`plant`を呼ぶと`Result.success == false`かつ`error_code == &"slot_full"`が返り、渡した`garden_state.plants`自体は変更されない（`plant`は`GardenState`を書き換えない）
- [ ] **境界値**: 残り1スロットのとき`can_plant`が`true`、そのスロットを埋めた後は`can_plant`が`false`になる

## Implementation Notes

- 参照すべき既存コード: `docs/design/atelier-alchemy-core/core-systems.md` L32-36, L63（`Planting`のクラス図・主要メソッド表）
- 実装のヒント: 空きスロット探索は`for i in range(slot_limit)`で使用中`slot_index`の集合と照合するループでよい（`Dictionary[int, bool]`を使った使用中フラグ管理が実装しやすい）
- 注意事項: `logic/`配下のため副作用を持たせない。`garden_state`引数を直接書き換えないこと（`plant`は新しい`PlantState`を`Result.value`に格納して返すのみ）。乱数・I/O・GameStateへの参照を一切持たない（FR-401）

## Files

- 新規: `atelier/features/garden/logic/planting.gd`
- テスト: `atelier/tests/unit/features/garden/test_planting.gd`
