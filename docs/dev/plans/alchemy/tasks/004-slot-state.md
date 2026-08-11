---
id: "004"
title: "SlotState型とcan_executeを実装する"
status: done
priority: 1
dependencies: []
estimated_complexity: low
---

# Task: SlotState型とcan_executeを実装する

## Goal

調合投入枠のランタイム状態`SlotState`を`features/alchemy/state/`に実装し、実行可否判定`can_execute()`を提供する。`GameState`からのみ参照される内部状態型（NFR-302）とする。

## Interfaces

```gdscript
# features/alchemy/state/slot_state.gd
class_name SlotState
extends RefCounted

var materials: Array[MaterialInstance] = []
var max_slots: int = 0
var selected_recipe_id: StringName = &""

## レシピ未選択・0個投入・上限超過のいずれでも偽を返す
func can_execute() -> bool:
	...
```

> 信号機: 🔵 `core-systems.md` L123-128（フィールド）・L150（`can_execute`、2026-08-05修正のPRレビューWarning#7対応版＝上限チェック込み）に基づく

## Test Strategy

- [ ] 正常系: `materials`が1個以上`max_slots`以下、`selected_recipe_id`が非空文字列の場合`can_execute()`は真
- [ ] 異常系: `selected_recipe_id`が空文字列（未選択）の場合`can_execute()`は偽
- [ ] 異常系: `materials`が空配列（0個投入）の場合`can_execute()`は偽
- [ ] 境界値: `materials.size() == max_slots`（枠数ちょうど）は真
- [ ] 境界値: `materials.size() == max_slots + 1`（枠数超過）は偽

## Implementation Notes

- 参照すべき既存コード: `atelier/features/garden/state/plant_state.gd`, `atelier/features/garden/state/garden_state.gd`（`state/`配下のRefCounted型の書き方）
- 実装のヒント: `can_execute()`は`selected_recipe_id != &"" and 1 <= materials.size() and materials.size() <= max_slots`の1行条件式で実装できる
- 注意事項: `SlotState`は他Featureから直接参照されない（NFR-302）。`GameState`が`execute_alchemy`内で一時的に構築して使うだけの内部型として実装する

## Files

- 新規: `atelier/features/alchemy/state/slot_state.gd`
- テスト: `atelier/tests/unit/features/alchemy/test_slot_state.gd`
