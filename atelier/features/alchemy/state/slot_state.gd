# 🔵 調合投入枠のランタイム状態（core-systems.md L123-128）。
# state/配下のクラスはGameStateからのみ参照される内部状態型（NFR-302）のためRefCounted継承とする。
class_name SlotState
extends RefCounted

## 🔴 代入時のエイリアシング防止のためsetterで防御的コピーする（GardenState.plantsと同方針）
var materials: Array[MaterialInstance] = []:
	set(value):
		materials = value.duplicate()

var max_slots: int = 0
var selected_recipe_id: StringName = &""


## 🔵 レシピ未選択・0個投入・枠数超過のいずれでも実行不可とする（core-systems.md L150）
func can_execute() -> bool:
	if selected_recipe_id == &"":
		return false
	return 1 <= materials.size() and materials.size() <= max_slots
