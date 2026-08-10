# 🔵 庭への種植えを担う純粋関数（FR-102, FR-109, core-systems.md L32-36, L63）。
# 空きスロット判定と新規PlantState作成のみを行い、seed_inventoryの消費や
# GardenState.plantsへの実際の追加は呼び出し元（GameState）の責務とする。
class_name Planting


## garden_state.plants.size() < slot_limit ならtrue
static func can_plant(garden_state: GardenState, slot_limit: int) -> bool:
	return garden_state.plants.size() < slot_limit


## 成功時: Result.value に新規PlantState（空きslot_index、grown_turns=0, is_matured=false）を格納して返す。
## GardenState.plantsへの追加自体は行わない（呼び出し元の責務）
## 失敗時: can_plantが偽ならResult.fail(&"slot_full")
static func plant(
	garden_state: GardenState, seed_id: StringName, _master: SeedMaster, slot_limit: int
) -> Result:
	if not can_plant(garden_state, slot_limit):
		return Result.fail(&"slot_full")

	var slot_index := _find_free_slot_index(garden_state, slot_limit)
	return Result.ok(PlantState.new(slot_index, seed_id))


## 使用中のslot_indexの集合と照合し、空いている最小のslot_indexを返す
static func _find_free_slot_index(garden_state: GardenState, slot_limit: int) -> int:
	var used_slots: Dictionary = {}
	for plant_state in garden_state.plants:
		used_slots[plant_state.slot_index] = true

	for i in range(slot_limit):
		if not used_slots.has(i):
			return i
	return slot_limit
