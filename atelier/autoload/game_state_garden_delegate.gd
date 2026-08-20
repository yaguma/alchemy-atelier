## GameStateの庭（garden）関連本番ロジックの実装詳細を分離する内部ヘルパー。
## 🔴 game_state.gd 500行ルール対応。GameStateTestSupportと同じパターンで、
## GameState側は本ファイルへの1行委譲のみを担う。公開シグネチャ・呼び出し方法は変更しない。
class_name GameStateGardenDelegate

const GameStateScript = preload("res://autoload/game_state.gd")


## res://data/materials/ から SeedMaster/MaterialMaster をロードし _seed_masters/_material_masters に格納する。
## 🔴 BootSceneからの呼び出し配線自体は本plan外。GameState側にAPIとして用意するのみ
static func load_garden_master_data(state: GameStateScript) -> void:
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
	state._seed_masters = seeds
	state._material_masters = material_masters


## (1) seed_inventoryの対象countを確認 (2) Planting.plantを実行 (3) 両方成功時のみcountを1減算
## 🔵 FR-101（3ステップ順序が確定設計。在庫確認をPlanting.plant呼び出しより必ず先に行う、FR-110）
static func plant_seed(state: GameStateScript, seed_id: StringName) -> Result:
	if not state._seed_masters.has(seed_id):
		state.plant_seed_failed.emit(seed_id, &"unknown_seed_id")
		return Result.fail(&"unknown_seed_id")

	var inventory_index := find_seed_inventory_index(state, seed_id)
	if inventory_index == -1 or (state._seed_inventory[inventory_index]["count"] as int) <= 0:
		state.plant_seed_failed.emit(seed_id, &"seed_not_owned")
		return Result.fail(&"seed_not_owned")

	var master: SeedMaster = state._seed_masters[seed_id]
	var plant_result := Planting.plant(
		state._garden_state, seed_id, master, state._garden_slot_count
	)
	if not plant_result.success:
		state.plant_seed_failed.emit(seed_id, plant_result.error_code)
		return plant_result

	var plant_state: PlantState = plant_result.value
	state._garden_state.plants.append(plant_state)
	state._seed_inventory[inventory_index]["count"] = (
		(state._seed_inventory[inventory_index]["count"] as int) - 1
	)

	state.seed_planted.emit(plant_state.slot_index, seed_id)
	return plant_result


## _seed_inventory内でseed_idが一致する要素のインデックスを返す。見つからない場合は-1
## 🔴 workshop delegate（seed_name_purchase効果）からも共有利用するため公開関数とする
static func find_seed_inventory_index(state: GameStateScript, seed_id: StringName) -> int:
	for i in range(state._seed_inventory.size()):
		if state._seed_inventory[i]["seed_id"] == seed_id:
			return i
	return -1


## RngServiceから品質用・特性用の乱数を個別に払い出し、Harvest.harvestへ渡す（🔵 FR-104, FR-402）。
## 成功時: MaterialInstanceにinstance_idを採番して確定し、inventoryへ追加、該当スロットをgarden_state.plantsから除去
static func harvest(state: GameStateScript, slot_index: int) -> Result:
	var plant_index := _find_plant_index(state, slot_index)
	if plant_index == -1:
		state.harvest_failed.emit(slot_index, &"slot_not_found")
		return Result.fail(&"slot_not_found")

	var plant_state: PlantState = state._garden_state.plants[plant_index]
	# 🔴 該当seed_idのSeedMasterが見つからない場合はスロット自体は存在するがマスターデータが
	# 欠落している内部不整合のため、slot_not_foundとは区別した専用エラーコードで返す（コードレビュー指摘対応）
	var master: SeedMaster = state._seed_masters.get(plant_state.seed_id)
	if master == null:
		state.harvest_failed.emit(slot_index, &"master_data_missing")
		return Result.fail(&"master_data_missing")

	# 🔵 品質用・特性用の乱数はそれぞれ個別に払い出す（1回の呼び出し結果を使い回さない、FR-104）
	var rng_roll_quality := RngService.randf()
	var rng_roll_trait := RngService.randf()
	var result := Harvest.harvest(plant_state, master, rng_roll_quality, rng_roll_trait)
	if not result.success:
		state.harvest_failed.emit(slot_index, result.error_code)
		return result

	var material: MaterialInstance = result.value
	material.instance_id = state._next_material_instance_id()

	state._garden_state.plants.remove_at(plant_index)
	# 🔴 _inventoryへはclone()した独立コピーを格納する。material_harvestedシグナル・戻り値のResult.valueは
	# 生成直後の同一参照のままのため、将来の購読側がin-place変更しても_inventoryの正本データは汚染されない
	# （state-management.mdの防御的コピー方針に合わせる、コードレビュー指摘対応）
	state._inventory.append(material.clone())

	state.material_harvested.emit(material, slot_index)
	return result


## 🔵 FR-103, FR-111。庭にある全スロットにHarvest.advance_growthを適用し、その直後に必ず
## Harvest.resolve_witheringを呼ぶ（core-systems.md L65の順序厳守）。枯死除去が発生した場合のみ
## plants_witheredを発行し、最後にターンを1進めてturn_growth_advancedを発行する。
## 🔴 対象範囲は「庭にある全スロット」（成熟後の待機中も含む）とする。
## 理由: 品質上昇判定・枯死判定にはis_matured後もgrown_turnsの継続加算が必要なため（ヒアリング結果でユーザー確認済み）
## 🔴 is_maturedの再計算はHarvest.advance_growthのスコープ外（タスク008方針）のためここで行う。
## SeedMasterが欠落した株はフラグを再計算せずgrown_turnsのみ進める（Harvest.resolve_witheringの
## 「マスター欠落株は安全側に倒して除去しない」方針と揃える）
static func advance_turn_growth(state: GameStateScript) -> void:
	var grown_plants: Array[PlantState] = []
	var slot_indices_before: Array[int] = []
	for plant in state._garden_state.plants:
		var advanced := Harvest.advance_growth(plant, 1)
		var master: SeedMaster = state._seed_masters.get(advanced.seed_id)
		if master != null:
			advanced.is_matured = Harvest.is_matured(advanced, master)
		grown_plants.append(advanced)
		slot_indices_before.append(advanced.slot_index)
	state._garden_state.plants = grown_plants

	state._garden_state = Harvest.resolve_withering(state._garden_state, state._seed_masters)

	var surviving_slot_indices: Array[int] = []
	for plant in state._garden_state.plants:
		surviving_slot_indices.append(plant.slot_index)
	# 🔴 除去株の検出はresolve_withering前後のslot_index集合の差分で行う（タスク015実装ノート）。
	# シグナル引数の宣言型（Array）に合わせ、型付き配列にはしない
	var withered_slot_indices: Array = []
	for slot_index in slot_indices_before:
		if not surviving_slot_indices.has(slot_index):
			withered_slot_indices.append(slot_index)

	# 🔴 他の全GameStateミューテータと同様、状態更新はシグナル発行より前に完了させる
	# （同期リスナーが更新前の値を読むのを防ぐ）
	state._current_turn += 1

	if not withered_slot_indices.is_empty():
		state.plants_withered.emit(withered_slot_indices)
	state.turn_growth_advanced.emit(state._current_turn)


## _garden_state.plants内でslot_indexが一致する要素のインデックスを返す。見つからない場合は-1
static func _find_plant_index(state: GameStateScript, slot_index: int) -> int:
	for i in range(state._garden_state.plants.size()):
		if state._garden_state.plants[i].slot_index == slot_index:
			return i
	return -1
