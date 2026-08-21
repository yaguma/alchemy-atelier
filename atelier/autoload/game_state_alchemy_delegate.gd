## GameStateの調合（alchemy）関連本番ロジックの実装詳細を分離する内部ヘルパー。
## 🔴 game_state.gd 500行ルール対応。GameStateTestSupportと同じパターンで、
## GameState側は本ファイルへの1行委譲のみを担う。公開シグネチャ・呼び出し方法は変更しない。
class_name GameStateAlchemyDelegate

const GameStateScript = preload("res://autoload/game_state.gd")


## res://data/recipes/ から RecipeMaster をロードし _recipe_masters に格納する（🔵 FR-301）。
## 🔴 BootSceneからの呼び出し配線自体は本plan外。GameState側にAPIとして用意するのみ
static func load_alchemy_master_data(state: GameStateScript) -> void:
	var recipes := MasterDataLoader.load_all(&"recipes")

	var recipe_masters: Dictionary = {}
	for r in recipes:
		var recipe := r as RecipeMaster
		if recipe_masters.has(recipe.id):
			push_error("調合レシピのIDが重複しています: %s" % recipe.id)
			return
		recipe_masters[recipe.id] = recipe
	state._recipe_masters = recipe_masters


## 🔵 FR-102の順序で検証: (1)recipe_id実在 (2)unlocked (3)material実在 (4)投入枠内重複なし。
## 通過後にFR-103でSlotState.can_execute()を実行直前に再評価する。
## 成功時のみinventory除去→pending_products追加→product_crafted発行（FR-112）。
## いずれかの段階の失敗はinventory/pending_productsを一切変更せずexecute_alchemy_failedを発行（FR-113）
static func execute_alchemy(
	state: GameStateScript, recipe_id: StringName, material_instance_ids: Array[String]
) -> Result:
	var indices := _resolve_inventory_indices(state, material_instance_ids)
	var error_code := _validate_alchemy_request(state, recipe_id, material_instance_ids, indices)
	if error_code != &"":
		state.execute_alchemy_failed.emit(recipe_id, error_code)
		return Result.fail(error_code)

	var materials: Array[MaterialInstance] = []
	for index in indices:
		materials.append(state._inventory[index])

	# 🔵 FR-103。UI側の先出し判定を信頼せず、状態変更の直前にDomain層の実行可否を再評価する
	var slot_state := SlotState.new()
	slot_state.selected_recipe_id = recipe_id
	slot_state.max_slots = state._alchemy_slot_count
	slot_state.materials = materials
	if not slot_state.can_execute():
		state.execute_alchemy_failed.emit(recipe_id, &"slot_execution_invalid")
		return Result.fail(&"slot_execution_invalid")

	# 🔵 FR-104/FR-201。品質判定と特性発現判定には現在ランク由来の同一のtraits_unlockedを渡す
	# 🔴 コードレビュー指摘対応。AlchemyScreenのライブプレビューと同一の計算経路
	# （ProductProvisionalResolver）を通すことで、両者の乖離を防ぐ
	var traits_unlocked := state._get_current_rank_master_or_fallback().traits_unlocked
	var recipe: RecipeMaster = state._recipe_masters[recipe_id]
	var product := ProductProvisionalResolver.resolve(materials, recipe, traits_unlocked)

	# 🔵 副作用はすべての検証・計算が成功した後にのみ適用する（FR-113のアトミック性）。
	# 🔴 remove_atのインデックスずれを避けるため降順に削除する
	indices.sort()
	indices.reverse()
	for index in indices:
		state._inventory.remove_at(index)
	# 🔴 harvest()の_inventory.append(material.clone())と同方針。正本は独立コピーとして保持し、
	# シグナル購読側・戻り値の受け取り側による事後変更から守る
	state._pending_products.append(product.clone())

	# 🔵 FR-102。試験中は調合成功1回につき試験内ターンを1消費する。advance_turn()は
	# 新規ExamStateを返す純粋関数（in-place書き換えではない）ため、戻り値で明示的に置き換える。
	# 同期リスナーが更新前の値を読むのを防ぐため、product_crafted.emit()より前に状態更新を完了させる
	# （commit_rank_outcome()のシグナル発行順序と同方針）
	if state._in_exam:
		state._exam_state = PromotionExamResolver.advance_turn(state._exam_state)

	state.product_crafted.emit(product)
	return Result.ok(product)


## 🔵 FR-102の4段階検証。問題がなければ空のStringNameを返す。
## 副作用を持たず、呼び出し元がシグナル発行とResult生成を担う
static func _validate_alchemy_request(
	state: GameStateScript,
	recipe_id: StringName,
	material_instance_ids: Array[String],
	indices: Array[int]
) -> StringName:
	if not state._recipe_masters.has(recipe_id):
		return &"unknown_recipe_id"
	if not state._unlocked_recipe_ids.has(recipe_id):
		return &"recipe_not_unlocked"
	if indices.has(-1):
		return &"material_not_owned"
	if _has_duplicate_ids(material_instance_ids):
		return &"duplicate_material_in_slot"
	return &""


## 各instance_idに対応する_inventory上のインデックスを、引数と同じ並び順で返す。
## 未所持のidは-1として保持し、検証側で一括判定できるようにする
static func _resolve_inventory_indices(
	state: GameStateScript, material_instance_ids: Array[String]
) -> Array[int]:
	var indices: Array[int] = []
	for instance_id in material_instance_ids:
		indices.append(_find_inventory_index(state, instance_id))
	return indices


## _inventory内でinstance_idが一致する要素のインデックスを返す。見つからない場合は-1
static func _find_inventory_index(state: GameStateScript, instance_id: String) -> int:
	for i in range(state._inventory.size()):
		if state._inventory[i].instance_id == instance_id:
			return i
	return -1


## material_instance_ids内に重複が存在するか
static func _has_duplicate_ids(ids: Array[String]) -> bool:
	var seen: Dictionary = {}
	for instance_id in ids:
		if seen.has(instance_id):
			return true
		seen[instance_id] = true
	return false
