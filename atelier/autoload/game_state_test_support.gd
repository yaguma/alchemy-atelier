## GameStateのテスト専用状態注入APIの実装詳細を分離する内部ヘルパー。
## 🔴 500行ルール対応。GameState本体からテスト専用API群（13関数分）を切り出し、
## GameState側は本ファイルへの1行委譲のみを担う。公開シグネチャ・呼び出し方法（テストコード側）は変更しない。
class_name GameStateTestSupport

# 🔴 GameStateAutoloadというclass_nameは付けない（state-management.mdの単一情報源ルールと
# 緊張関係になるため、コードレビュー指摘対応）。RngServiceScriptと同じくpreload定数で型注釈する
const GameStateScript = preload("res://autoload/game_state.gd")


## OS.is_debug_build()でなければpush_error()してfalseを返す（本番コードパスからの実行防止）。
## assert()はリリースビルドで除去されるため、push_error+戻り値の二重ガードを各呼び出し元で併用する
static func guard(function_name: String) -> bool:
	assert(OS.is_debug_build(), "%s() must not be called in release builds" % function_name)
	if not OS.is_debug_build():
		push_error("%s() must not be called in release builds" % function_name)
		return false
	return true


static func set_masters(state: GameStateScript, seeds: Dictionary, materials: Dictionary) -> void:
	if not guard("_set_masters_for_test"):
		return
	state._seed_masters = seeds
	state._material_masters = materials


static func set_seed_inventory(state: GameStateScript, seed_inventory: Array[Dictionary]) -> void:
	if not guard("_set_seed_inventory_for_test"):
		return
	state._seed_inventory = seed_inventory


static func inject_plant(state: GameStateScript, plant_state: PlantState) -> void:
	if not guard("_inject_plant_for_test"):
		return
	state._garden_state.plants.append(plant_state)


static func set_recipe_masters(state: GameStateScript, masters: Dictionary) -> void:
	if not guard("_set_recipe_masters_for_test"):
		return
	state._recipe_masters = masters


static func set_unlocked_recipe_ids(state: GameStateScript, ids: Array[StringName]) -> void:
	if not guard("_set_unlocked_recipe_ids_for_test"):
		return
	state._unlocked_recipe_ids = ids.duplicate()


static func set_alchemy_slot_count(state: GameStateScript, count: int) -> void:
	if not guard("_set_alchemy_slot_count_for_test"):
		return
	state._alchemy_slot_count = count


static func set_rank_masters(state: GameStateScript, masters: Dictionary) -> void:
	if not guard("_set_rank_masters_for_test"):
		return
	state._rank_masters = masters


static func set_current_rank_id(state: GameStateScript, rank_id: StringName) -> void:
	if not guard("_set_current_rank_id_for_test"):
		return
	state._current_rank_id = rank_id


## 内部正本は独立コピーとして保持し、呼び出し元が注入後に引数を変更しても汚染されないようにする。
## 🔴 コードレビュー指摘対応。テストが明示的にRankStateを注入した時点で「本物のノルマ値が
## セットされた」とみなし、_rank_state_initializedをtrueにする（GameState.evaluate_rank_outcome()
## 参照）。これにより、注入されていない既定値0.0が誤ってノルマ達成済みと評価されるのを防ぐ
static func set_rank_state(state: GameStateScript, rank_state: RankState) -> void:
	if not guard("_set_rank_state_for_test"):
		return
	state._rank_state = rank_state.clone()
	state._rank_state_initialized = true


static func set_demotion_count(state: GameStateScript, count: int) -> void:
	if not guard("_set_demotion_count_for_test"):
		return
	state._demotion_count = count


## 内部正本は独立コピーとして保持し、呼び出し元が注入後に引数を変更しても汚染されないようにする
static func set_current_daily_order(state: GameStateScript, order: DailyOrderMaster) -> void:
	if not guard("_set_current_daily_order_for_test"):
		return
	state._current_daily_order = order.clone() if order else null


## 内部正本は独立コピーとして保持し、呼び出し元が注入後に引数を変更しても汚染されないようにする
static func inject_material(state: GameStateScript, material: MaterialInstance) -> void:
	if not guard("_inject_material_for_test"):
		return
	state._inventory.append(material.clone())


## 内部正本は独立コピーとして保持する
static func inject_pending_product(state: GameStateScript, product: ProductInstance) -> void:
	if not guard("_inject_pending_product_for_test"):
		return
	state._pending_products.append(product.clone())


## 内部正本は独立コピーとして保持し、呼び出し元が注入後に引数を変更しても汚染されないようにする
static func set_exam_state(state: GameStateScript, exam_state: ExamState, in_exam: bool) -> void:
	if not guard("_set_exam_state_for_test"):
		return
	state._exam_state = exam_state.clone()
	state._in_exam = in_exam


static func set_can_purchase_permanent(state: GameStateScript, value: bool) -> void:
	if not guard("_set_can_purchase_permanent_for_test"):
		return
	state._can_purchase_permanent = value


## 内部正本は独立コピーとして保持する（既存set_current_daily_order()等と同方針）
static func set_purchased_upgrade_counts(state: GameStateScript, counts: Dictionary) -> void:
	if not guard("_set_purchased_upgrade_counts_for_test"):
		return
	state._purchased_upgrade_counts = counts.duplicate()
