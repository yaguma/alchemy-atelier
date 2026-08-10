---
id: "005"
title: "PlantState/GardenState状態型を実装する"
status: pending
priority: 1
dependencies: []
estimated_complexity: low
---

# Task: PlantState/GardenState状態型を実装する

## Goal

庭のランタイム状態型`PlantState`（1スロットの生育状況）と`GardenState`（庭全体、`plants`配列）を`features/garden/state/`に実装する。`GameState.get_state()`の防御的コピー（FR-403）に対応するため、両クラスに`clone()`を実装する。

## Interfaces

```gdscript
# features/garden/state/plant_state.gd
class_name PlantState
extends RefCounted

var slot_index: int         # 🔵 FR-002, data-schema.md L33-36
var seed_id: StringName     # 🔵
var grown_turns: int        # 🔵
var is_matured: bool        # 🔵

func _init(
	p_slot_index: int,
	p_seed_id: StringName,
	p_grown_turns: int = 0,
	p_is_matured: bool = false
) -> void:  # 🔵
	pass

func clone() -> PlantState:  # 🔴 FR-403対応の新規補完
	pass
```

```gdscript
# features/garden/state/garden_state.gd
class_name GardenState
extends RefCounted

var plants: Array[PlantState] = []  # 🔵 FR-001, data-schema.md L31

func clone() -> GardenState:  # 🔴 FR-403対応の新規補完。plantsの各要素もPlantState.clone()で複製する
	pass
```

## Test Strategy

- [ ] `PlantState`のコンストラクタに渡した4フィールドがそれぞれ正しく設定される
- [ ] `PlantState.clone()`で生成したインスタンスは元と別オブジェクトだが全フィールドの値が等しい
- [ ] `GardenState.clone()`で生成した`plants`配列は元の配列と別オブジェクト（同一配列参照ではない）
- [ ] `GardenState.clone()`で複製した`plants`内の各`PlantState`も別オブジェクトであり、複製後に複製側の`grown_turns`を変更しても元の`GardenState.plants`内の値は変化しない
- [ ] 空の`plants`（`[]`）を持つ`GardenState`でも`clone()`が正常に動作する

## Implementation Notes

- 参照すべき既存コード: `docs/design/atelier-alchemy-core/data-schema.md` L30-39（GardenState/PlantStateのJSON例）
- 実装のヒント: `GardenState.clone()`は`plants.map(func(p: PlantState) -> PlantState: return p.clone())`で実装できる
- 注意事項: `NFR-302`により、`state/`配下のクラスは他Featureから直接参照禁止（`GameState`からのみ参照される）。`RefCounted`継承とし`Resource`にはしない（マスターデータではなくランタイム状態のため）

## Files

- 新規: `atelier/features/garden/state/plant_state.gd`
- 新規: `atelier/features/garden/state/garden_state.gd`
- テスト: `atelier/tests/unit/features/garden/test_plant_state.gd`
- テスト: `atelier/tests/unit/features/garden/test_garden_state.gd`
