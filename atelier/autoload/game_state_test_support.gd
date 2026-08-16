## GameStateのテスト専用状態注入APIの実装詳細を分離する内部ヘルパー。
## 🔴 500行ルール対応。GameState本体からテスト専用API群（13関数分）を切り出し、
## GameState側は本ファイルへの1行委譲のみを担う。公開シグネチャ・呼び出し方法（テストコード側）は変更しない。
class_name GameStateTestSupport


## OS.is_debug_build()でなければpush_error()してfalseを返す（本番コードパスからの実行防止）。
## assert()はリリースビルドで除去されるため、push_error+戻り値の二重ガードを各呼び出し元で併用する
static func guard(function_name: String) -> bool:
	assert(OS.is_debug_build(), "%s() must not be called in release builds" % function_name)
	if not OS.is_debug_build():
		push_error("%s() must not be called in release builds" % function_name)
		return false
	return true


static func set_masters(state: GameStateAutoload, seeds: Dictionary, materials: Dictionary) -> void:
	if not guard("_set_masters_for_test"):
		return
	state._seed_masters = seeds
	state._material_masters = materials


static func set_seed_inventory(state: GameStateAutoload, seed_inventory: Array[Dictionary]) -> void:
	if not guard("_set_seed_inventory_for_test"):
		return
	state._seed_inventory = seed_inventory


static func inject_plant(state: GameStateAutoload, plant_state: PlantState) -> void:
	if not guard("_inject_plant_for_test"):
		return
	state._garden_state.plants.append(plant_state)


static func set_recipe_masters(state: GameStateAutoload, masters: Dictionary) -> void:
	if not guard("_set_recipe_masters_for_test"):
		return
	state._recipe_masters = masters


static func set_unlocked_recipe_ids(state: GameStateAutoload, ids: Array[StringName]) -> void:
	if not guard("_set_unlocked_recipe_ids_for_test"):
		return
	state._unlocked_recipe_ids = ids.duplicate()


static func set_alchemy_slot_count(state: GameStateAutoload, count: int) -> void:
	if not guard("_set_alchemy_slot_count_for_test"):
		return
	state._alchemy_slot_count = count


static func set_rank_masters(state: GameStateAutoload, masters: Dictionary) -> void:
	if not guard("_set_rank_masters_for_test"):
		return
	state._rank_masters = masters


static func set_current_rank_id(state: GameStateAutoload, rank_id: StringName) -> void:
	if not guard("_set_current_rank_id_for_test"):
		return
	state._current_rank_id = rank_id


## 内部正本は独立コピーとして保持し、呼び出し元が注入後に引数を変更しても汚染されないようにする
static func set_rank_state(state: GameStateAutoload, rank_state: RankState) -> void:
	if not guard("_set_rank_state_for_test"):
		return
	state._rank_state = rank_state.clone()


static func set_demotion_count(state: GameStateAutoload, count: int) -> void:
	if not guard("_set_demotion_count_for_test"):
		return
	state._demotion_count = count


## 内部正本は独立コピーとして保持し、呼び出し元が注入後に引数を変更しても汚染されないようにする
static func set_current_daily_order(state: GameStateAutoload, order: DailyOrderMaster) -> void:
	if not guard("_set_current_daily_order_for_test"):
		return
	state._current_daily_order = order.clone() if order else null


## 内部正本は独立コピーとして保持し、呼び出し元が注入後に引数を変更しても汚染されないようにする
static func inject_material(state: GameStateAutoload, material: MaterialInstance) -> void:
	if not guard("_inject_material_for_test"):
		return
	state._inventory.append(material.clone())


## 内部正本は独立コピーとして保持する
static func inject_pending_product(state: GameStateAutoload, product: ProductInstance) -> void:
	if not guard("_inject_pending_product_for_test"):
		return
	state._pending_products.append(product.clone())
