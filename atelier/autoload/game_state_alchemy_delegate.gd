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

	# 🔵 Issue #67。ひらめき対応表はレシピと寿命が同じ調合マスターデータのため、ここで一緒に読み込む
	# （GameStateの公開メソッド数がgdlintの上限に達しているため、専用のload_*を増やさない）
	var inspirations: Array[InspirationMaster] = []
	for master in MasterDataLoader.load_all(&"inspirations"):
		inspirations.append(master as InspirationMaster)
	state._inspiration_masters = inspirations


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
	slot_state.max_slots = effective_slot_count(state)
	slot_state.materials = materials
	if not slot_state.can_execute():
		state.execute_alchemy_failed.emit(recipe_id, &"slot_execution_invalid")
		return Result.fail(&"slot_execution_invalid")

	# 🔵 FR-104/FR-201。品質判定と特性発現判定には現在ランク由来の同一のtraits_unlockedを渡す
	# 🔴 コードレビュー指摘対応。AlchemyScreenのライブプレビューと同一の計算経路
	# （ProductProvisionalResolver）を通すことで、両者の乖離を防ぐ
	var traits_unlocked := state._get_current_rank_master_or_fallback().traits_unlocked
	var recipe: RecipeMaster = state._recipe_masters[recipe_id]
	if recipe.is_intermediate():
		return _craft_intermediate(state, recipe, materials, indices, traits_unlocked)

	var product := ProductProvisionalResolver.resolve(materials, recipe, traits_unlocked)
	product.used_intermediate = _uses_intermediate(state, materials)  # 🔵 Issue #68

	# 🔴 コードレビュー指摘対応。指定依頼の合致判定自体はDeliveryResolverの責務（FR-403,
	# 二重乗算バグ防止）のためここでは倍率を適用しないが、「どの指定依頼を基準に納品時ボーナスを
	# 判定するか」は調合が成立したこの瞬間の_current_daily_orderで確定させる。
	# resolve_daily_order_for_delivery()は_in_exam中はnullを返すため、試験中の調合はここで
	# 自動的に「指定依頼なし」として確定する（FR-401と同じ結論）
	product.has_daily_order_snapshot = true
	product.daily_order_snapshot = state.resolve_daily_order_for_delivery()

	# 🔵 副作用はすべての検証・計算が成功した後にのみ適用する（FR-113のアトミック性）。
	_consume_materials_and_exam_turn(state, indices)
	# 🔴 harvest()の_inventory.append(material.clone())と同方針。正本は独立コピーとして保持し、
	# シグナル購読側・戻り値の受け取り側による事後変更から守る
	state._pending_products.append(product.clone())
	var inspiration := _apply_inspiration(state, recipe_id, materials)

	state.product_crafted.emit(product)
	_emit_inspired(state, inspiration, recipe_id, materials)
	return Result.ok(product)


## 🔵 Issue #66（FR-713-002）。中間素材レシピは調合物を納品待ちに積まず、凝縮した素材を在庫へ加える。
## 素材の消費・試験ターンの消費は納品用の調合と同じ扱いにする
static func _craft_intermediate(
	state: GameStateScript,
	recipe: RecipeMaster,
	materials: Array[MaterialInstance],
	indices: Array[int],
	traits_unlocked: bool
) -> Result:
	var crafted := IntermediateCrafter.craft(
		materials, recipe, traits_unlocked, state._next_material_instance_id()
	)
	_consume_materials_and_exam_turn(state, indices)
	state._inventory.append(crafted.clone())
	# 🔵 FR-713-007。中間素材の調合も熟練度の加算対象とする
	var inspiration := _apply_inspiration(state, recipe.id, materials)

	state.intermediate_crafted.emit(crafted)
	_emit_inspired(state, inspiration, recipe.id, materials)
	return Result.ok(crafted)


## 🔵 Issue #67（FR-714-002〜007）。熟練度を加算してひらめき判定を行い、ひらめいたら結果のレシピを
## 解禁して熟練度を0に戻す。状態更新のみ行い、ひらめいたInspirationMaster（なければnull）を返す
## （シグナル発行は呼び出し元が調合結果のシグナルの後に行う）
static func _apply_inspiration(
	state: GameStateScript, recipe_id: StringName, materials: Array[MaterialInstance]
) -> InspirationMaster:
	if not state._get_current_rank_master_or_fallback().inspiration_unlocked:
		return null

	var mastery: Dictionary = state._inspiration_state.mastery
	var count := int(mastery.get(recipe_id, 0)) + 1
	mastery[recipe_id] = count
	# 🔵 FR-714-004。判定用・候補選択用の乱数は個別に払い出す（Harvest.harvestと同じ方針）
	var roll_inspire := RngService.randf()
	var roll_pick := RngService.randf()
	if not InspirationResolver.should_inspire(count, roll_inspire):
		return null

	var candidates := InspirationResolver.find_candidates(
		state._inspiration_masters,
		recipe_id,
		InspirationResolver.input_traits(materials),
		state._current_rank_id,
		state._unlocked_recipe_ids
	)
	var picked := InspirationResolver.pick(candidates, roll_pick)
	# 🔵 FR-714-007。候補がなければひらめかず、熟練度もリセットしない
	if picked == null:
		return null

	state._unlocked_recipe_ids.append(picked.result_recipe_id)
	state._inspiration_state.inspired_recipe_ids.append(picked.result_recipe_id)
	mastery[recipe_id] = 0
	return picked


static func _emit_inspired(
	state: GameStateScript,
	inspiration: InspirationMaster,
	recipe_id: StringName,
	materials: Array[MaterialInstance]
) -> void:
	if inspiration == null:
		return
	state.recipe_inspired.emit(
		inspiration.result_recipe_id, recipe_id, InspirationResolver.input_traits(materials)
	)


## 投入素材を在庫から取り除き、試験中なら試験ターンを1消費する。
## 🔴 remove_atのインデックスずれを避けるため降順に削除する
## 🔵 FR-102。試験中は調合成功1回につき試験内ターンを1消費する。advance_turn()は
## 新規ExamStateを返す純粋関数（in-place書き換えではない）ため、戻り値で明示的に置き換える。
## 同期リスナーが更新前の値を読むのを防ぐため、シグナル発行より前に呼び出し元が本関数を済ませる
## （commit_rank_outcome()のシグナル発行順序と同方針）
static func _consume_materials_and_exam_turn(state: GameStateScript, indices: Array[int]) -> void:
	var descending := indices.duplicate()
	descending.sort()
	descending.reverse()
	for index in descending:
		state._inventory.remove_at(index)

	if state._in_exam:
		state._exam_state = PromotionExamResolver.advance_turn(state._exam_state)


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
	# 🔵 Issue #66。出力先の素材IDがない中間素材レシピは、材料だけ失う事態を防ぐため実行させない
	var recipe: RecipeMaster = state._recipe_masters[recipe_id]
	if recipe.is_intermediate() and recipe.output_material_id == &"":
		return &"intermediate_output_missing"
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


## 🔵 Issue #68（FR-715-004）。試験中は試験ルールによって投入枠の上限が下がる場合がある
static func effective_slot_count(state: GameStateScript) -> int:
	if not state._in_exam:
		return state._alchemy_slot_count
	return ExamRuleResolver.effective_slot_limit(
		GameStateRankDelegate.current_exam_rule(state), state._alchemy_slot_count
	)


## 🔵 Issue #68。投入素材に中間素材（MaterialMaster.is_intermediate）が含まれているか
static func _uses_intermediate(state: GameStateScript, materials: Array[MaterialInstance]) -> bool:
	for material in materials:
		var master: MaterialMaster = state._material_masters.get(material.material_id)
		if master != null and master.is_intermediate:
			return true
	return false
