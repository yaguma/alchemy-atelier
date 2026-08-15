extends Node

signal phase_changed(previous: StringName, next: StringName)
signal seed_planted(slot_index: int, seed_id: StringName)  # 🔵 FR-101
signal plant_seed_failed(seed_id: StringName, error_code: StringName)  # 🔴 UI側トースト表示(NFR-202)用の新規補完
signal material_harvested(material: MaterialInstance, slot_index: int)  # 🔵 FR-105
signal harvest_failed(slot_index: int, error_code: StringName)  # 🔴 UI側フィードバック用の新規補完
signal product_crafted(product: ProductInstance)  # 🔵 FR-112
# 🔴 garden の plant_seed_failed/harvest_failed パターン踏襲（FR-113）
signal execute_alchemy_failed(recipe_id: StringName, error_code: StringName)
signal delivered(results: Array[DeliveryResult])  # 🔴 FR-108

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

# --- 調合（alchemy）関連フィールド ---
var _recipe_masters: Dictionary = {}  # 🔵 Dictionary[StringName, RecipeMaster]
var _unlocked_recipe_ids: Array[StringName] = [GameBalance.INITIAL_RECIPE_ID]  # 🔵 FR-007
var _pending_products: Array[ProductInstance] = []  # 🔴 FR-008 ギルド納品待ちキュー
# 🔵 FR-006「実行時権威」の暫定置き場（_garden_slot_countと同様、本plan内ではGameStateが仮に保持する）
var _alchemy_slot_count: int = GameBalance.ALCHEMY_SLOT_COUNT_DEFAULT
# 🔴 CON-007。特性解禁はRankMaster側で管理する想定だが未実装のため暫定フィールドとして持つ
var _traits_unlocked: bool = false

# --- ギルド納品（guild）関連フィールド ---
# 🔴 FR-006, CON-004。RankSystem未実装のため、ランクノルマへの反映は行わず累積値のみ保持する
var _accumulated_contribution: float = 0.0
# 🔴 CON-010。日替わり指定調合物の再抽選ロジックは別planのため、既定値nullでも納品が成立する
var _current_daily_order: DailyOrderMaster = null


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

	var cloned_pending_products: Array[ProductInstance] = []
	for product in _pending_products:
		cloned_pending_products.append(product.clone())

	return {
		"current_phase": _current_phase,
		"gold": _gold,
		"current_turn": _current_turn,
		"garden_state": _garden_state.clone(),
		"seed_inventory": _seed_inventory.duplicate(true),
		"inventory": cloned_inventory,
		# 🔴 要素がStringName（値型相当）のため浅い複製で十分（FR-403）
		"unlocked_recipe_ids": _unlocked_recipe_ids.duplicate(),
		"pending_products": cloned_pending_products,
		# 🔴 floatは値型のため複製不要（FR-403）
		"accumulated_contribution": _accumulated_contribution,
		# 🔴 DailyOrderMasterは@export var（プリミティブ）のみでネストしたArray/Dictionaryを
		# 持たないため、参照をそのまま返してよい（FR-408の対象はpending_productsに限定）
		"current_daily_order": _current_daily_order,
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


## res://data/recipes/ から RecipeMaster をロードし _recipe_masters に格納する（🔵 FR-301）。
## 🔴 BootSceneからの呼び出し配線自体は本plan外。GameState側にAPIとして用意するのみ
func load_alchemy_master_data() -> void:
	var recipes := MasterDataLoader.load_all(&"recipes")

	var recipe_masters: Dictionary = {}
	for r in recipes:
		var recipe := r as RecipeMaster
		if recipe_masters.has(recipe.id):
			push_error("調合レシピのIDが重複しています: %s" % recipe.id)
			return
		recipe_masters[recipe.id] = recipe
	_recipe_masters = recipe_masters


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
	# 🔴 該当seed_idのSeedMasterが見つからない場合はスロット自体は存在するがマスターデータが
	# 欠落している内部不整合のため、slot_not_foundとは区別した専用エラーコードで返す（コードレビュー指摘対応）
	var master: SeedMaster = _seed_masters.get(plant_state.seed_id)
	if master == null:
		harvest_failed.emit(slot_index, &"master_data_missing")
		return Result.fail(&"master_data_missing")

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
	# 🔴 _inventoryへはclone()した独立コピーを格納する。material_harvestedシグナル・戻り値のResult.valueは
	# 生成直後の同一参照のままのため、将来の購読側がin-place変更しても_inventoryの正本データは汚染されない
	# （state-management.mdの防御的コピー方針に合わせる、コードレビュー指摘対応）
	_inventory.append(material.clone())

	material_harvested.emit(material, slot_index)
	return result


## _garden_state.plants内でslot_indexが一致する要素のインデックスを返す。見つからない場合は-1
func _find_plant_index(slot_index: int) -> int:
	for i in range(_garden_state.plants.size()):
		if _garden_state.plants[i].slot_index == slot_index:
			return i
	return -1


## 🔵 FR-102の順序で検証: (1)recipe_id実在 (2)unlocked (3)material実在 (4)投入枠内重複なし。
## 通過後にFR-103でSlotState.can_execute()を実行直前に再評価する。
## 成功時のみinventory除去→pending_products追加→product_crafted発行（FR-112）。
## いずれかの段階の失敗はinventory/pending_productsを一切変更せずexecute_alchemy_failedを発行（FR-113）
func execute_alchemy(recipe_id: StringName, material_instance_ids: Array[String]) -> Result:
	var indices := _resolve_inventory_indices(material_instance_ids)
	var error_code := _validate_alchemy_request(recipe_id, material_instance_ids, indices)
	if error_code != &"":
		execute_alchemy_failed.emit(recipe_id, error_code)
		return Result.fail(error_code)

	var materials: Array[MaterialInstance] = []
	for index in indices:
		materials.append(_inventory[index])

	# 🔵 FR-103。UI側の先出し判定を信頼せず、状態変更の直前にDomain層の実行可否を再評価する
	var slot_state := SlotState.new()
	slot_state.selected_recipe_id = recipe_id
	slot_state.max_slots = _alchemy_slot_count
	slot_state.materials = materials
	if not slot_state.can_execute():
		execute_alchemy_failed.emit(recipe_id, &"slot_execution_invalid")
		return Result.fail(&"slot_execution_invalid")

	# 🔵 FR-104。品質判定と特性発現判定には同一の_traits_unlockedを渡す
	var quality := QualityCalculator.calculate_quality(materials, _traits_unlocked)
	var quality_mult := QualityCalculator.quality_multiplier(quality)
	var activated_traits := TraitActivation.resolve_traits(materials, _traits_unlocked)

	var recipe: RecipeMaster = _recipe_masters[recipe_id]
	var contribution := ProductValueCalculator.calculate_contribution(
		recipe.base_contribution,
		quality_mult,
		ProductValueCalculator.resolve_contribution_bonus(activated_traits)
	)
	var reward := ProductValueCalculator.calculate_reward(
		recipe.base_reward,
		quality_mult,
		ProductValueCalculator.resolve_reward_bonus(activated_traits)
	)
	var product := ProductInstance.new(recipe_id, quality, activated_traits, contribution, reward)

	# 🔵 副作用はすべての検証・計算が成功した後にのみ適用する（FR-113のアトミック性）。
	# 🔴 remove_atのインデックスずれを避けるため降順に削除する
	indices.sort()
	indices.reverse()
	for index in indices:
		_inventory.remove_at(index)
	# 🔴 harvest()の_inventory.append(material.clone())と同方針。正本は独立コピーとして保持し、
	# シグナル購読側・戻り値の受け取り側による事後変更から守る
	_pending_products.append(product.clone())

	product_crafted.emit(product)
	return Result.ok(product)


## 🔴 _pending_productsを先頭から全件消費し、各ProductInstanceについて
## DeliveryResolver.resolve(product, _current_daily_order)を呼び出す（FR-005, FR-105）。
## final_rewardはroundi()で丸めて_goldへ即時加算（FR-106, CON-007）、
## final_contributionはfloatのまま_accumulated_contributionへ加算する（FR-107）。
## 全件処理後にキューを空にしdelivered(results)を発行する（FR-108）。
## キューが空の場合は状態を一切変更せずResult.ok([])を返す（FR-109, AC-012）
func deliver_pending_products() -> Result:
	var results: Array[DeliveryResult] = []
	if _pending_products.is_empty():
		return Result.ok(results)

	for product in _pending_products:
		var delivery_result := DeliveryResolver.resolve(product, _current_daily_order)
		_gold += roundi(delivery_result.final_reward)
		_accumulated_contribution += delivery_result.final_contribution
		results.append(delivery_result)

	# 🔴 走査中にclear()すると反復が壊れるため、キューの破棄はループ完了後に行う
	_pending_products.clear()

	delivered.emit(results)
	return Result.ok(results)


## 🔵 FR-102の4段階検証。問題がなければ空のStringNameを返す。
## 副作用を持たず、呼び出し元がシグナル発行とResult生成を担う
func _validate_alchemy_request(
	recipe_id: StringName, material_instance_ids: Array[String], indices: Array[int]
) -> StringName:
	if not _recipe_masters.has(recipe_id):
		return &"unknown_recipe_id"
	if not _unlocked_recipe_ids.has(recipe_id):
		return &"recipe_not_unlocked"
	if indices.has(-1):
		return &"material_not_owned"
	if _has_duplicate_ids(material_instance_ids):
		return &"duplicate_material_in_slot"
	return &""


## 各instance_idに対応する_inventory上のインデックスを、引数と同じ並び順で返す。
## 未所持のidは-1として保持し、検証側で一括判定できるようにする
func _resolve_inventory_indices(material_instance_ids: Array[String]) -> Array[int]:
	var indices: Array[int] = []
	for instance_id in material_instance_ids:
		indices.append(_find_inventory_index(instance_id))
	return indices


## _inventory内でinstance_idが一致する要素のインデックスを返す。見つからない場合は-1
func _find_inventory_index(instance_id: String) -> int:
	for i in range(_inventory.size()):
		if _inventory[i].instance_id == instance_id:
			return i
	return -1


## material_instance_ids内に重複が存在するか
func _has_duplicate_ids(ids: Array[String]) -> bool:
	var seen: Dictionary = {}
	for instance_id in ids:
		if seen.has(instance_id):
			return true
		seen[instance_id] = true
	return false


## テスト専用。実.tresロードを介さずSeedMaster/MaterialMasterを直接注入する（🟡 CON-005対応）
func _set_masters_for_test(seeds: Dictionary, materials: Dictionary) -> void:
	assert(OS.is_debug_build(), "_set_masters_for_test() must not be called in release builds")
	if not OS.is_debug_build():
		push_error("_set_masters_for_test() must not be called in release builds")
		return
	_seed_masters = seeds
	_material_masters = materials


## 🔴 テスト専用。seed_inventoryを実プレイの操作を介さず直接注入する
## （テストコードが非公開フィールドへ直接書き込むことを避けるための正規API、コードレビュー指摘対応）
func _set_seed_inventory_for_test(seed_inventory: Array[Dictionary]) -> void:
	assert(
		OS.is_debug_build(), "_set_seed_inventory_for_test() must not be called in release builds"
	)
	if not OS.is_debug_build():
		push_error("_set_seed_inventory_for_test() must not be called in release builds")
		return
	_seed_inventory = seed_inventory


## 🔴 テスト専用。plant_seed()を経由せずgarden_state.plantsへ株を直接追加する
## （生育経過済み・枯死済みなど、通常操作では到達しづらい状態を作るための正規API、コードレビュー指摘対応）
func _inject_plant_for_test(plant_state: PlantState) -> void:
	assert(OS.is_debug_build(), "_inject_plant_for_test() must not be called in release builds")
	if not OS.is_debug_build():
		push_error("_inject_plant_for_test() must not be called in release builds")
		return
	_garden_state.plants.append(plant_state)


## 🟡 テスト専用。実.tresロードを介さずRecipeMasterを直接注入する（CON-005対応、_set_masters_for_testと同型）
func _set_recipe_masters_for_test(masters: Dictionary) -> void:
	assert(
		OS.is_debug_build(), "_set_recipe_masters_for_test() must not be called in release builds"
	)
	if not OS.is_debug_build():
		push_error("_set_recipe_masters_for_test() must not be called in release builds")
		return
	_recipe_masters = masters


## 🔴 テスト専用。unlocked_recipe_idsをランク進行を介さず直接注入する（AC-009検証用）
func _set_unlocked_recipe_ids_for_test(ids: Array[StringName]) -> void:
	assert(
		OS.is_debug_build(),
		"_set_unlocked_recipe_ids_for_test() must not be called in release builds"
	)
	if not OS.is_debug_build():
		push_error("_set_unlocked_recipe_ids_for_test() must not be called in release builds")
		return
	_unlocked_recipe_ids = ids.duplicate()


## 🔴 テスト専用。alchemy_slot_countを工房強化を介さず直接注入する（AC-007境界値検証用）
func _set_alchemy_slot_count_for_test(count: int) -> void:
	assert(
		OS.is_debug_build(),
		"_set_alchemy_slot_count_for_test() must not be called in release builds"
	)
	if not OS.is_debug_build():
		push_error("_set_alchemy_slot_count_for_test() must not be called in release builds")
		return
	_alchemy_slot_count = count


## 🔴 テスト専用。traits_unlockedをランク進行を介さず直接注入する（AC-011検証用）
func _set_traits_unlocked_for_test(value: bool) -> void:
	assert(
		OS.is_debug_build(), "_set_traits_unlocked_for_test() must not be called in release builds"
	)
	if not OS.is_debug_build():
		push_error("_set_traits_unlocked_for_test() must not be called in release builds")
		return
	_traits_unlocked = value


## 🔴 テスト専用。deliver_pending_products()を経由せず本日の指定調合物を直接注入する（FR-301, AC-008）
func _set_current_daily_order_for_test(order: DailyOrderMaster) -> void:
	assert(
		OS.is_debug_build(),
		"_set_current_daily_order_for_test() must not be called in release builds"
	)
	if not OS.is_debug_build():
		push_error("_set_current_daily_order_for_test() must not be called in release builds")
		return
	_current_daily_order = order


## 🔴 テスト専用。harvest()/execute_alchemy()を経由せずinventoryへ素材を直接注入する。
## 内部正本は独立コピーとして保持し、呼び出し元が注入後に引数を変更しても汚染されないようにする
## （harvest()の_inventory.append(material.clone())と同じ方針）
func _inject_material_for_test(material: MaterialInstance) -> void:
	assert(OS.is_debug_build(), "_inject_material_for_test() must not be called in release builds")
	if not OS.is_debug_build():
		push_error("_inject_material_for_test() must not be called in release builds")
		return
	_inventory.append(material.clone())


## 🔴 テスト専用。execute_alchemy()を経由せず納品待ちキューへ調合物を直接注入する。
## 内部正本は独立コピーとして保持する（_inject_material_for_testと同じ方針）
func _inject_pending_product_for_test(product: ProductInstance) -> void:
	assert(
		OS.is_debug_build(),
		"_inject_pending_product_for_test() must not be called in release builds"
	)
	if not OS.is_debug_build():
		push_error("_inject_pending_product_for_test() must not be called in release builds")
		return
	_pending_products.append(product.clone())


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
	_recipe_masters = {}
	_unlocked_recipe_ids = [GameBalance.INITIAL_RECIPE_ID]
	_pending_products = []
	_alchemy_slot_count = GameBalance.ALCHEMY_SLOT_COUNT_DEFAULT
	_traits_unlocked = false
	_accumulated_contribution = 0.0
	_current_daily_order = null
