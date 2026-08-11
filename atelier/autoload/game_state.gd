extends Node

signal phase_changed(previous: StringName, next: StringName)
signal seed_planted(slot_index: int, seed_id: StringName)  # 🔵 FR-101
signal plant_seed_failed(seed_id: StringName, error_code: StringName)  # 🔴 UI側トースト表示(NFR-202)用の新規補完
signal material_harvested(material: MaterialInstance, slot_index: int)  # 🔵 FR-105
signal harvest_failed(slot_index: int, error_code: StringName)  # 🔴 UI側フィードバック用の新規補完

var _current_phase: StringName = &"garden"
var _gold: int = 0
var _current_turn: int = 1

# --- 庭（garden）関連フィールド ---
var _garden_state: GardenState = GardenState.new()  # 🔵 FR-001
var _seed_inventory: Array[Dictionary] = []  # 🔵 [{seed_id: StringName, count: int}]
var _inventory: Array[MaterialInstance] = []  # 🔵 収穫済み素材
var _seed_masters: Dictionary = {}  # 🔵 Dictionary[StringName, SeedMaster]
var _material_masters: Dictionary = {}  # 🔵 Dictionary[StringName, MaterialMaster]
var _material_instance_seq: int = 0  # 🔴 instance_id採番用（新規補完）
# 🔵 FR-006「実行時権威」の暫定置き場（player.permanent_upgrades本体は別plan未実装のため、
# 本plan内では庭専用フィールドとして仮に保持する）
var _garden_slot_count: int = GameBalance.GARDEN_SLOT_COUNT


# 内部Dictionary/Arrayフィールドを直接返すと呼び出し元が改変できてしまうため、
# 辞書リテラルを都度生成しduplicate(true)でディープコピーを保証する（state-management.md）。
# garden_state/inventoryはカスタムRefCounted型を含むため、clone()を明示的に呼ぶ（🔵 AC-014, FR-403）。
# 🔴 Array.map()の戻り値は型付き配列(Array[MaterialInstance])ではなく素のArrayになり、
# 呼び出し元で型付き変数へ代入する際に実行時エラーとなるため、明示的に型付き配列を構築する
# （GardenState.clone()と同じ既知の罠）
func get_state() -> Dictionary:
	var cloned_inventory: Array[MaterialInstance] = []
	for material in _inventory:
		cloned_inventory.append(material.clone())

	return {
		"current_phase": _current_phase,
		"gold": _gold,
		"current_turn": _current_turn,
		"garden_state": _garden_state.clone(),
		"seed_inventory": _seed_inventory.duplicate(true),
		"inventory": cloned_inventory,
	}


func set_phase(next: StringName) -> void:
	var previous := _current_phase
	_current_phase = next
	phase_changed.emit(previous, next)


## res://data/materials/ から SeedMaster/MaterialMaster をロードし _seed_masters/_material_masters に格納する。
## 🔴 BootSceneからの呼び出し配線自体は本plan外。GameState側にAPIとして用意するのみ
func load_garden_master_data() -> void:
	var materials := MasterDataLoader.load_all(&"materials")
	if not MasterDataLoader.validate_references(materials):
		push_error("庭マスターデータのID相互参照が解決できません")
		return

	var seeds: Dictionary = {}
	var material_masters: Dictionary = {}
	for m in materials:
		if m is SeedMaster:
			seeds[(m as SeedMaster).id] = m
		elif m is MaterialMaster:
			material_masters[(m as MaterialMaster).id] = m
	_seed_masters = seeds
	_material_masters = material_masters


## (1) seed_inventoryの対象countを確認 (2) Planting.plantを実行 (3) 両方成功時のみcountを1減算
## 🔵 FR-101（3ステップ順序が確定設計。在庫確認をPlanting.plant呼び出しより必ず先に行う、FR-110）
func plant_seed(seed_id: StringName) -> Result:
	if not _seed_masters.has(seed_id):
		plant_seed_failed.emit(seed_id, &"unknown_seed_id")
		return Result.fail(&"unknown_seed_id")

	var inventory_index := _find_seed_inventory_index(seed_id)
	if inventory_index == -1 or (_seed_inventory[inventory_index]["count"] as int) <= 0:
		plant_seed_failed.emit(seed_id, &"seed_not_owned")
		return Result.fail(&"seed_not_owned")

	var master: SeedMaster = _seed_masters[seed_id]
	var plant_result := Planting.plant(_garden_state, seed_id, master, _garden_slot_count)
	if not plant_result.success:
		plant_seed_failed.emit(seed_id, plant_result.error_code)
		return plant_result

	var plant_state: PlantState = plant_result.value
	_garden_state.plants.append(plant_state)
	_seed_inventory[inventory_index]["count"] = (
		(_seed_inventory[inventory_index]["count"] as int) - 1
	)

	seed_planted.emit(plant_state.slot_index, seed_id)
	return plant_result


## _seed_inventory内でseed_idが一致する要素のインデックスを返す。見つからない場合は-1
func _find_seed_inventory_index(seed_id: StringName) -> int:
	for i in range(_seed_inventory.size()):
		if _seed_inventory[i]["seed_id"] == seed_id:
			return i
	return -1


## RngServiceから品質用・特性用の乱数を個別に払い出し、Harvest.harvestへ渡す（🔵 FR-104, FR-402）。
## 成功時: MaterialInstanceにinstance_idを採番して確定し、inventoryへ追加、該当スロットをgarden_state.plantsから除去
func harvest(slot_index: int) -> Result:
	var plant_index := _find_plant_index(slot_index)
	if plant_index == -1:
		harvest_failed.emit(slot_index, &"slot_not_found")
		return Result.fail(&"slot_not_found")

	var plant_state: PlantState = _garden_state.plants[plant_index]
	# 🟡 該当seed_idのSeedMasterが見つからない場合は内部不整合のため安全側に倒しslot_not_foundとして扱う
	var master: SeedMaster = _seed_masters.get(plant_state.seed_id)
	if master == null:
		harvest_failed.emit(slot_index, &"slot_not_found")
		return Result.fail(&"slot_not_found")

	# 🔵 品質用・特性用の乱数はそれぞれ個別に払い出す（1回の呼び出し結果を使い回さない、FR-104）
	var rng_roll_quality := RngService.randf()
	var rng_roll_trait := RngService.randf()
	var result := Harvest.harvest(plant_state, master, rng_roll_quality, rng_roll_trait)
	if not result.success:
		harvest_failed.emit(slot_index, result.error_code)
		return result

	var material: MaterialInstance = result.value
	material.instance_id = "mat_%04d" % _material_instance_seq
	_material_instance_seq += 1

	_garden_state.plants.remove_at(plant_index)
	_inventory.append(material)

	material_harvested.emit(material, slot_index)
	return result


## _garden_state.plants内でslot_indexが一致する要素のインデックスを返す。見つからない場合は-1
func _find_plant_index(slot_index: int) -> int:
	for i in range(_garden_state.plants.size()):
		if _garden_state.plants[i].slot_index == slot_index:
			return i
	return -1


## テスト専用。実.tresロードを介さずSeedMaster/MaterialMasterを直接注入する（🟡 CON-005対応）
func _set_masters_for_test(seeds: Dictionary, materials: Dictionary) -> void:
	assert(OS.is_debug_build(), "_set_masters_for_test() must not be called in release builds")
	if not OS.is_debug_build():
		push_error("_set_masters_for_test() must not be called in release builds")
		return
	_seed_masters = seeds
	_material_masters = materials


# テスト分離専用。assert()はリリースビルドで除去されるため、
# push_error+returnを併用して本番コードパスからの実行を確実に止める
func reset_for_test() -> void:
	assert(OS.is_debug_build(), "reset_for_test() must not be called in release builds")
	if not OS.is_debug_build():
		push_error("reset_for_test() must not be called in release builds")
		return
	_current_phase = &"garden"
	_gold = 0
	_current_turn = 1
	_garden_state = GardenState.new()
	_seed_inventory = [
		{"seed_id": GameBalance.INITIAL_SEED_ID, "count": GameBalance.INITIAL_SEED_COUNT}
	]
	_inventory = []
	_seed_masters = {}
	_material_masters = {}
	_material_instance_seq = 0
	_garden_slot_count = GameBalance.GARDEN_SLOT_COUNT
