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
# 🔴 state-management.mdが定義するゴールド変動通知。deliver_pending_products()が
# _goldを変更する最初の経路のため、ここで初めて発行する
signal gold_changed(previous_amount: int, new_amount: int, delta: int)
signal rank_outcome_confirmed(outcome: RankOutcome.Value)  # 🔴 FR-112
signal game_over(demotion_count: int)  # 🔴 FR-113
signal exam_started  # 🟡 FR-302（任意要件）。開始ロジック自体は後続task（007〜011）で実装する
signal exam_outcome_confirmed(outcome: ExamOutcome.Value)  # 🟡 FR-301（任意要件）

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

# --- ギルド納品（guild）関連フィールド ---
# 🔴 CON-010。日替わり指定調合物の再抽選ロジックは別planのため、既定値nullでも納品が成立する
var _current_daily_order: DailyOrderMaster = null

# --- ランク進行（rank）関連フィールド ---
var _current_rank_id: StringName = GameBalance.INITIAL_RANK_ID  # 🔵 FR-006
var _rank_masters: Dictionary = {}  # 🔵 FR-006。Dictionary[StringName, RankMaster]
var _rank_state: RankState = RankState.new()  # 🔵 FR-006
var _demotion_count: int = 0  # 🔵 FR-006
# 🔴 FR-202。ゲームオーバー確定後にcommit_rank_outcome()が冪等に返すための直近確定結果
var _last_rank_outcome: RankOutcome.Value = RankOutcome.Value.CONTINUE
# 🔴 コードレビュー指摘対応。_rank_state.quotaは現状どの本番コードパスからもquota_maxから
# 初期化されない（ランクマスターロード自体がCON-006で本plan外）ため、「まだ本物のノルマ値が
# セットされていない」ことを明示的に区別するフラグ。falseの間はevaluate_rank_outcome()が
# 常にCONTINUEを返し、quota=0.0の既定値が「ノルマ達成済み」と誤認されることを防ぐ
var _rank_state_initialized: bool = false
# 🔴 コードレビュー指摘対応。_get_current_rank_master_or_fallback()のpush_error()が
# ランクマスター未登録の間、呼び出しのたびに多重発生しコンソールを埋めるのを防ぐため、
# 一度警告済みのランクIDを記録する（reset_for_test()で初期化）
var _warned_missing_rank_master_ids: Dictionary = {}

# --- 昇格試験（rank/exam）関連フィールド ---
# 🔵 FR-008。試験の開始/進行/結果確定ロジック自体は後続task（007〜011）で実装する
var _in_exam: bool = false
# 🟡 design phase確定。_rank_stateと同型パターンだが、ExamStateはRankMasterを再参照せず
# start_exam()時点で計算済みのexam_quota_maxを自身のフィールドとして保持する自己完結型
var _exam_state: ExamState = ExamState.new()
# 🔵 FR-113（_last_rank_outcomeと同型）。試験結果確定後にcommit_exam_outcome()が
# 冪等に返すための直近確定結果（後続taskで使用）
var _last_exam_outcome: ExamOutcome.Value = ExamOutcome.Value.CONTINUE

# --- 工房強化・ショップ（workshop）関連フィールド ---
var _can_purchase_permanent: bool = false  # 🔵 FR-009
var _purchased_upgrade_counts: Dictionary = {}  # 🔵 FR-010 Dictionary[StringName, int]
var _upgrade_masters: Dictionary = {}  # 🔵 FR-011 Dictionary[StringName, UpgradeMaster]


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
		# 🔴 DailyOrderMasterは@export var（プリミティブ）のみで構成されるが、Resource自体は
		# 参照型のため他フィールドと同様clone()してから返す（state-management.md防御的コピー要件）
		"current_daily_order": _current_daily_order.clone() if _current_daily_order else null,
		# 🔵 FR-006。StringName/intは値型のため複製不要。RankStateは参照型のためclone()する（FR-410）
		"current_rank_id": _current_rank_id,
		"demotion_count": _demotion_count,
		"rank_state": _rank_state.clone(),
		# 🔵 FR-009, AC-018。試験ビュー5フィールドはすべて値型のため、_exam_state.clone()のような
		# 明示的コピー呼び出しは不要（値型コピーで防御性が保たれる、design phase確定）
		"in_exam": _in_exam,
		"exam_quota": _exam_state.exam_quota,
		"exam_quota_max": _exam_state.exam_quota_max,
		"exam_elapsed_turn": _exam_state.exam_elapsed_turn,
		"exam_turn_limit": _exam_state.exam_turn_limit,
		"can_purchase_permanent": _can_purchase_permanent,  # 🔵 FR-017
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


## res://data/upgrades/ から UpgradeMaster をロードし _upgrade_masters に格納する（🔵 FR-005, FR-011）。
## 重複ID検知パターンはload_alchemy_master_data()を踏襲する。
## 🔴 BootSceneからの呼び出し配線自体は本plan外。GameState側にAPIとして用意するのみ
func load_workshop_master_data() -> void:
	var upgrades := MasterDataLoader.load_all(&"upgrades")

	var upgrade_masters: Dictionary = {}
	for u in upgrades:
		var upgrade := u as UpgradeMaster
		if upgrade_masters.has(upgrade.id):
			push_error("工房強化アップグレードのIDが重複しています: %s" % upgrade.id)
			return
		upgrade_masters[upgrade.id] = upgrade
	_upgrade_masters = upgrade_masters


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

	# 🔵 FR-104/FR-201。品質判定と特性発現判定には現在ランク由来の同一のtraits_unlockedを渡す
	var traits_unlocked := _get_current_rank_master_or_fallback().traits_unlocked
	var quality := QualityCalculator.calculate_quality(materials, traits_unlocked)
	var quality_mult := QualityCalculator.quality_multiplier(quality)
	var activated_traits := TraitActivation.resolve_traits(materials, traits_unlocked)

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

	# 🔵 FR-102。試験中は調合成功1回につき試験内ターンを1消費する。advance_turn()は
	# 新規ExamStateを返す純粋関数（in-place書き換えではない）ため、戻り値で明示的に置き換える。
	# 同期リスナーが更新前の値を読むのを防ぐため、product_crafted.emit()より前に状態更新を完了させる
	# （commit_rank_outcome()のシグナル発行順序と同方針）
	if _in_exam:
		_exam_state = PromotionExamResolver.advance_turn(_exam_state)

	product_crafted.emit(product)
	return Result.ok(product)


## 🔴 _pending_productsを先頭から全件消費し、各ProductInstanceについて
## DeliveryResolver.resolve(product, _current_daily_order)を呼び出す（FR-005, FR-105）。
## final_rewardはroundi()で丸めて_goldへ即時加算（FR-106, CON-007）、
## final_contributionはRankQuotaResolver.apply_contributionで現在ランクのノルマ残量から
## 減算する（🔵 FR-108, CON-004）。
## 全件処理後にキューを空にしdelivered(results)を発行する（FR-108）。
## キューが空の場合は状態を一切変更せずResult.ok([])を返す（FR-109, AC-012）
func deliver_pending_products() -> Result:
	var results: Array[DeliveryResult] = []
	if _pending_products.is_empty():
		return Result.ok(results)

	var gold_before := _gold
	# 🔵 FR-105, FR-106, FR-401。試験中(_in_exam)はdaily_orderをnullに切り替え、
	# 指定合致ボーナス（DeliveryResolver.matches_orderはdaily_order=nullで常にfalse）を不適用にする。
	# 報酬(gold)加算はこの分岐と無関係に常時行う（FR-106: 試験中/非試験中でgold加算量は変わらない）
	var order_for_delivery: DailyOrderMaster = null if _in_exam else _current_daily_order
	for product in _pending_products:
		var delivery_result := DeliveryResolver.resolve(product, order_for_delivery)
		_gold += roundi(delivery_result.final_reward)
		# 🔵 貢献度の適用先を試験中/非試験中で切り替える。RankQuotaResolver.apply_contribution自体は
		# ノルマの入れ物がRankState.quotaかExamState.exam_quotaかを問わない汎用のfloatクランプ関数のため無変更で流用する
		if _in_exam:
			_exam_state.exam_quota = RankQuotaResolver.apply_contribution(
				_exam_state.exam_quota, delivery_result.final_contribution
			)
		else:
			_rank_state.quota = RankQuotaResolver.apply_contribution(
				_rank_state.quota, delivery_result.final_contribution
			)
		results.append(delivery_result)

	# 🔴 走査中にclear()すると反復が壊れるため、キューの破棄はループ完了後に行う
	_pending_products.clear()

	if _gold != gold_before:
		gold_changed.emit(gold_before, _gold, _gold - gold_before)

	# 🔴 emit直後にResult.ok(results)で同一配列を返すと、delivered購読側がその場で
	# 配列を書き換え（clear/並べ替え等）た場合に戻り値まで汚染される。
	# duplicate()でシグナル発行用の別配列を渡し、戻り値の配列とは独立させる
	# （要素のDeliveryResultインスタンス自体はプリミティブ値型フィールドのみのため共有で問題ない）
	delivered.emit(results.duplicate())
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


## _current_rank_idに対応するランクIDについて、まだ_warn_missing_rank_master()で
## 警告していなければpush_error()する。同一ランクIDでの多重発生を防ぐ（🔴 コードレビュー指摘対応）
func _warn_missing_rank_master() -> void:
	if _warned_missing_rank_master_ids.has(_current_rank_id):
		return
	_warned_missing_rank_master_ids[_current_rank_id] = true
	push_error("現在ランクのマスターデータが見つかりません: %s" % _current_rank_id)


## _commit_exam_success()専用。次ランクのマスターデータが見つからない場合の警告を、
## _warn_missing_rank_master()と同じ_warned_missing_rank_master_idsで多重発生を防ぎつつ出す
## （🔴 コードレビュー指摘対応。next_rank_idは_current_rank_idとは別IDのため専用関数にする）
func _warn_missing_next_rank_master(next_rank_id: StringName) -> void:
	if _warned_missing_rank_master_ids.has(next_rank_id):
		return
	_warned_missing_rank_master_ids[next_rank_id] = true
	push_error("次ランクのマスターデータが見つかりません: %s" % next_rank_id)


## 現在ランクのRankMasterを返す。_rank_mastersに_current_rank_idが存在しない場合は
## _warn_missing_rank_master()した上で、特性未解禁・ノルマ0・制限ターン0の安全側フォールバックを返す
## （🔴 FR-114, CON-008）。マスターデータ未ロード時でも調合・納品が例外なく成立することを優先し、
## null返却は行わない。ランク結果評価（evaluate_rank_outcome）はこのフォールバックの
## quota_max=0.0/limit_turn=0が誤ってPROMOTION_ELIGIBLEを誘発しないよう、あえてこの関数を
## 経由せず_rank_mastersを直接参照する（コードレビュー指摘対応）
func _get_current_rank_master_or_fallback() -> RankMaster:
	var master: RankMaster = _rank_masters.get(_current_rank_id)
	if master != null:
		return master

	_warn_missing_rank_master()
	var fallback := RankMaster.new()
	fallback.id = String(_current_rank_id)
	fallback.traits_unlocked = false
	fallback.quota_max = 0.0
	fallback.limit_turn = 0
	return fallback


## 🔴 CON-009。現在のRankState/RankMasterからランク結果を算出して返す（FR-109）。
## 副作用を持たない問い合わせ専用。UIの先出し表示と、commit_rank_outcome()の実行直前再評価の両方から使う。
## 🔴 コードレビュー指摘対応。_rank_state_initializedがfalseの間（quota_maxからの初期化が
## まだ行われていない、ランクマスターがロードされていない等）は常にCONTINUEを返す。
## こうしないと_rank_state.quotaの既定値0.0が「ノルマ達成済み」と誤認され、
## ランクの初回挑戦が常にPROMOTION_ELIGIBLE判定になってしまう
func evaluate_rank_outcome() -> RankOutcome.Value:
	if not _rank_state_initialized:
		return RankOutcome.Value.CONTINUE

	var rank_master: RankMaster = _rank_masters.get(_current_rank_id)
	if rank_master == null:
		_warn_missing_rank_master()
		return RankOutcome.Value.CONTINUE

	var quota_cleared := RankQuotaResolver.is_rank_cleared(_rank_state.quota)
	var turn_limit_reached := TurnLimitResolver.is_turn_limit_reached(
		_rank_state.elapsed_turn, rank_master.limit_turn
	)
	return TurnLimitResolver.resolve_rank_outcome(quota_cleared, turn_limit_reached)


## 🔴 CON-009。evaluate_rank_outcome()を実行直前に再評価して状態へ確定反映する（FR-110）。
## DEMOTIONなら降格回数を加算し、RankStateを再挑戦用に差し替える。
## ゲームオーバー成立時のみgame_over(_demotion_count)を発行する（FR-113）。
## PROMOTION_ELIGIBLEでは次ランクへ進めない（FR-404、promotion-exam planの責務）。
## 既にゲームオーバー確定済みなら状態を変更せず直近の確定結果を返す（FR-202、冪等性）。
## 🔴 コードレビュー指摘対応。DEMOTION側の状態更新（_demotion_count/_rank_state）は、
## 他の全GameStateミューテータ（harvest/execute_alchemy/deliver_pending_products）と同様、
## 必ずrank_outcome_confirmed発行より前に完了させる（同期リスナーが更新前の値を読むのを防ぐ）
## 🔵 FR-101。PROMOTION_ELIGIBLE確定時、not _in_examの場合のみ_start_exam()を呼ぶ
## （二重開始防止、FR-201）。既存のDEMOTION/game_over処理・シグナル発行順序は変更しない
func commit_rank_outcome() -> Result:
	if is_game_over():
		return Result.ok(_last_rank_outcome)

	var outcome := evaluate_rank_outcome()
	_last_rank_outcome = outcome

	if outcome == RankOutcome.Value.DEMOTION:
		_demotion_count += 1
		_rank_state = RankQuotaResolver.reset_for_retry(_get_current_rank_master_or_fallback())
	elif outcome == RankOutcome.Value.PROMOTION_ELIGIBLE and not _in_exam:
		_start_exam()

	rank_outcome_confirmed.emit(outcome)  # 🔴 FR-112

	if outcome == RankOutcome.Value.DEMOTION and is_game_over():
		game_over.emit(_demotion_count)

	return Result.ok(outcome)


## 🔵 FR-111。降格回数が上限に達しているか
func is_game_over() -> bool:
	return _demotion_count >= GameBalance.MAX_DEMOTION_COUNT


## 🔵 FR-101。PromotionExamResolver.start_examで現在ランクのExamStateを生成しin_examをtrueにする。
## 🔴 NFR-101。現在ランクのRankMasterが不正（null/limit_turn<=0/exam_turn_limit<=0）な場合は
## 試験を開始せずpush_error()する。
## 🔴 evaluate_rank_outcome()と同様、_get_current_rank_master_or_fallback()は経由せず
## _rank_mastersを直接参照する（フォールバックのlimit_turn=0を「正当な0値」と誤認しないため）。
## 🔴 exam_turn_limit<=0もここで弾く。PromotionExamResolver.start_exam内部にも同種ガードがあるが、
## そちらは失敗時にexam_quota=0のExamStateを返すだけで例外を投げないため、ここで検知しないと
## _in_exam=trueのまま試験が始まり、次のcommit_exam_outcome()でexam_quota<=0により即SUCCESS
## 判定されてしまう（試験を一切プレイせず昇格するバグ）
func _start_exam() -> void:
	var rank_master: RankMaster = _rank_masters.get(_current_rank_id)
	if rank_master == null:
		_warn_missing_rank_master()
		return
	if rank_master.limit_turn <= 0:
		push_error("現在ランクのlimit_turnが不正なため試験を開始できません: %s" % _current_rank_id)
		return
	if rank_master.exam_turn_limit <= 0:
		push_error("現在ランクのexam_turn_limitが不正なため試験を開始できません: %s" % _current_rank_id)
		return

	_exam_state = PromotionExamResolver.start_exam(rank_master)
	_in_exam = true
	exam_started.emit()  # 🟡 FR-302


## 🔵 FR-103, FR-104。試験中(_in_exam=true)に調合を実行せず試験ターンだけ進める。
## 在庫切れ・解禁レシピ切れ等で調合が実行不能になったデッドロックからの回避手段。
## PromotionExamResolver.advance_turnは新規ExamStateを返す純粋関数（in-place書き換えではない）ため、
## execute_alchemy()の試験中ターン消費と同様に戻り値で明示的に置き換える。
## 🟡 in_exam=falseの場合は状態を一切変更せず失敗のResultを返す（FR-104）。
## エラーコード&"not_in_exam"はexecute_alchemy_failed等の既存命名規則(snake_case)から推定した新規コード
## （design phaseで明示要件なし）。resolve_outcomeの呼び出しは行わない（結果確定はcommit_exam_outcome()の責務）
func advance_exam_turn() -> Result:
	if not _in_exam:
		return Result.fail(&"not_in_exam")

	_exam_state = PromotionExamResolver.advance_turn(_exam_state)
	return Result.ok()


## 🟡 FR-107。in_exam=falseの場合は常にCONTINUEを返す（_rank_state_initializedガードと同型の
## 安全策）。副作用を持たない問い合わせ専用。UIの先出し表示と、commit_exam_outcome()の
## 実行直前再評価の両方から使う。判定ロジック自体はPromotionExamResolver.resolve_outcome
## （ノルマ達成を制限ターン到達より優先する）にそのまま委譲する
func evaluate_exam_outcome() -> ExamOutcome.Value:
	if not _in_exam:
		return ExamOutcome.Value.CONTINUE

	return PromotionExamResolver.resolve_outcome(_exam_state)


## 🔵 FR-108〜113。evaluate_exam_outcome()を実行直前に再評価してから状態へ確定反映する。
## SUCCESSなら次ランクへの実遷移またはゲームクリア判定、FAILUREなら同ランク再挑戦のリセット処理へ
## それぞれ委譲する。既にゲームオーバー確定済みなら状態を変更せず直近の確定結果を冪等に返す
## （FR-113、commit_rank_outcome()と同型）。
## 🔴 _commit_exam_success()/_commit_exam_failure()での状態更新は、他の全GameStateミューテータと
## 同様に必ずexam_outcome_confirmed発行より前に完了させる（同期リスナーが更新前の値を読むのを防ぐ）
func commit_exam_outcome() -> Result:
	if is_game_over():
		return Result.ok(_last_exam_outcome)

	var outcome := evaluate_exam_outcome()
	_last_exam_outcome = outcome

	if outcome == ExamOutcome.Value.SUCCESS:
		_commit_exam_success()
	elif outcome == ExamOutcome.Value.FAILURE:
		_commit_exam_failure()

	exam_outcome_confirmed.emit(outcome)  # 🟡 FR-301

	if outcome == ExamOutcome.Value.FAILURE and is_game_over():
		# 🔴 FR-113。新規シグナルは作らず、既存のrank plan実装のgame_over(demotion_count)を再利用する
		game_over.emit(_demotion_count)

	return Result.ok(outcome)


## 🔵 SUCCESS確定時の内部処理（FR-108, FR-109, FR-404）。次ランクがあれば昇格しrank_stateを
## 次ランクのquota_maxで再初期化する。次ランクなし（RANK_ORDER末尾）ならゲームクリアとして
## current_rank_id・rank_stateは不変のままin_examのみ終了させる。
## 🔴 NFR-101。次ランクのRankMasterが_rank_mastersに未登録の場合は、_rank_state・_current_rank_idは
## 変更せず_warn_missing_next_rank_master()で警告するが、_in_examは必ずfalseへ戻す。
## 🔴 コードレビュー指摘対応。以前は_in_examをtrueのまま残していたため、次のcommit_exam_outcome()
## 呼び出しでもexam_quotaが>0のままSUCCESS判定が再評価されこの分岐に無限に入り直し、
## push_errorが呼び出しのたびに連呼される「解決不能な幽霊試験状態」に陥っていた
## 🔵 FR-110。関数冒頭で_can_purchase_permanentをtrueにし、昇格試験成功と工房強化の恒久投資
## 購入可否フラグを接続する。FR-110は「昇格試験が成功した場合」とのみ規定し分岐を限定していない
## ため、以下3分岐すべてに一律適用されるようあえて分岐前（関数冒頭）に置く
func _commit_exam_success() -> void:
	_can_purchase_permanent = true  # 🔵 FR-110。既存3分岐すべてに一律適用される位置
	var next_rank_id := RankProgression.get_next_rank_id(_current_rank_id)

	if next_rank_id == &"":
		_in_exam = false
		return

	var next_rank_master: RankMaster = _rank_masters.get(next_rank_id)
	if next_rank_master == null:
		_warn_missing_next_rank_master(next_rank_id)
		_in_exam = false
		return

	_current_rank_id = next_rank_id
	# 🟡 design phase確認済み。RankQuotaResolver.reset_for_retryは「同ランク再挑戦専用」ではなく
	# 「RankMasterのquota_maxからRankStateを初期化する」汎用関数のため、次ランク初期化にも流用する
	_rank_state = RankQuotaResolver.reset_for_retry(next_rank_master)
	_rank_state_initialized = true
	_in_exam = false


## 🔵 FAILURE確定時の内部処理（FR-110, FR-111）。同ランクをreset_for_retryでリセットし、
## demotion_countを+1する（commit_rank_outcome()のDEMOTION分岐と同型）
func _commit_exam_failure() -> void:
	_demotion_count += 1
	_rank_state = RankQuotaResolver.reset_for_retry(_get_current_rank_master_or_fallback())
	_in_exam = false


## 🔵 検証(1)null(2)恒久フラグ(3)can_purchase再評価の順に行い、全て通過した場合のみ
## 状態変更（ゴールド減算・effect反映・購入回数カウント更新）をすべて完了させてからgold_changedを
## 発行する（FR-101〜104, FR-112〜114, FR-401〜402）。いずれかの検証に失敗した場合は
## いかなる状態も変更しない（execute_alchemy()と同型のアトミック性パターン）。
## effect_type別の状態反映は_apply_upgrade_effect()に委譲する（別taskでno-op実装から差し替え予定）
func apply_upgrade(upgrade: UpgradeMaster) -> Result:
	if upgrade == null:
		return Result.fail(&"invalid_upgrade")

	if PurchaseValidator.is_permanent_upgrade(upgrade) and not _can_purchase_permanent:
		return Result.fail(&"workshop_closed")

	# 🔵 UIの先出し判定を信頼せず、状態変更の直前にDomain層の実行可否を再評価する
	var already_purchased_count: int = _purchased_upgrade_counts.get(upgrade.id, 0)
	if not PurchaseValidator.can_purchase(
		_gold, upgrade.price, already_purchased_count, upgrade.max_purchase_count
	):
		return Result.fail(&"cannot_purchase")

	# --- 状態変更フェーズ（全て完了するまでシグナル発行しない） ---
	var previous_gold := _gold
	_gold -= upgrade.price

	_apply_upgrade_effect(upgrade)  # 別taskで実装。本taskではno-op

	_purchased_upgrade_counts[upgrade.id] = already_purchased_count + 1

	gold_changed.emit(previous_gold, _gold, _gold - previous_gold)

	return Result.ok(upgrade)


## 🔴 本taskではno-op。別taskでeffect_type別（alchemy_slot_increase/garden_slot_increase/
## recipe_unlock/catalyst_stock/seed_name_purchase）の5分岐を実装する
func _apply_upgrade_effect(_upgrade: UpgradeMaster) -> void:
	pass


## 🔵 恒久投資購入可否フラグを閉じる（FR-015, FR-018）
func close_workshop() -> void:
	_can_purchase_permanent = false


## 🔵 未購入（キー未登録）の場合は0を返す（FR-018）
func get_purchased_count(upgrade_id: StringName) -> int:
	return _purchased_upgrade_counts.get(upgrade_id, 0)


## 🔴 500行ルール対応。以下のテスト専用API群は実装本体をgame_state_test_support.gd
## （GameStateTestSupport）へ委譲する。公開シグネチャ・呼び出し方法はテストコード側から見て変更しない


## テスト専用。実.tresロードを介さずSeedMaster/MaterialMasterを直接注入する（🟡 CON-005対応）
func _set_masters_for_test(seeds: Dictionary, materials: Dictionary) -> void:
	GameStateTestSupport.set_masters(self, seeds, materials)


## 🔴 テスト専用。seed_inventoryを実プレイの操作を介さず直接注入する
func _set_seed_inventory_for_test(seed_inventory: Array[Dictionary]) -> void:
	GameStateTestSupport.set_seed_inventory(self, seed_inventory)


## 🔴 テスト専用。plant_seed()を経由せずgarden_state.plantsへ株を直接追加する
func _inject_plant_for_test(plant_state: PlantState) -> void:
	GameStateTestSupport.inject_plant(self, plant_state)


## 🟡 テスト専用。実.tresロードを介さずRecipeMasterを直接注入する（CON-005対応）
func _set_recipe_masters_for_test(masters: Dictionary) -> void:
	GameStateTestSupport.set_recipe_masters(self, masters)


## 🔴 テスト専用。unlocked_recipe_idsをランク進行を介さず直接注入する（AC-009検証用）
func _set_unlocked_recipe_ids_for_test(ids: Array[StringName]) -> void:
	GameStateTestSupport.set_unlocked_recipe_ids(self, ids)


## 🔴 テスト専用。alchemy_slot_countを工房強化を介さず直接注入する（AC-007境界値検証用）
func _set_alchemy_slot_count_for_test(count: int) -> void:
	GameStateTestSupport.set_alchemy_slot_count(self, count)


## 🟡 テスト専用。実.tresロードを介さずRankMasterを直接注入する（FR-301）
func _set_rank_masters_for_test(masters: Dictionary) -> void:
	GameStateTestSupport.set_rank_masters(self, masters)


## 🟡 テスト専用。current_rank_idを昇格・降格を介さず直接注入する（FR-301）
func _set_current_rank_id_for_test(rank_id: StringName) -> void:
	GameStateTestSupport.set_current_rank_id(self, rank_id)


## 🟡 テスト専用。rank_stateをターン進行を介さず直接注入する（FR-301）
func _set_rank_state_for_test(state: RankState) -> void:
	GameStateTestSupport.set_rank_state(self, state)


## 🟡 テスト専用。demotion_countを降格処理を介さず直接注入する（FR-301）
func _set_demotion_count_for_test(count: int) -> void:
	GameStateTestSupport.set_demotion_count(self, count)


## 🔴 テスト専用。deliver_pending_products()を経由せず本日の指定調合物を直接注入する（FR-301, AC-008）
func _set_current_daily_order_for_test(order: DailyOrderMaster) -> void:
	GameStateTestSupport.set_current_daily_order(self, order)


## 🔴 テスト専用。harvest()/execute_alchemy()を経由せずinventoryへ素材を直接注入する
func _inject_material_for_test(material: MaterialInstance) -> void:
	GameStateTestSupport.inject_material(self, material)


## 🔴 テスト専用。execute_alchemy()を経由せず納品待ちキューへ調合物を直接注入する
func _inject_pending_product_for_test(product: ProductInstance) -> void:
	GameStateTestSupport.inject_pending_product(self, product)


## 🟡 テスト専用。試験開始処理（後続task）を経由せずexam_state/in_examを直接注入する（CON-008委譲パターン）
func _set_exam_state_for_test(exam_state: ExamState, in_exam: bool = true) -> void:
	GameStateTestSupport.set_exam_state(self, exam_state, in_exam)


## 🔵 テスト専用。can_purchase_permanentを工房強化画面の開閉操作を介さず直接注入する（FR-012）
func _set_can_purchase_permanent_for_test(value: bool) -> void:
	GameStateTestSupport.set_can_purchase_permanent(self, value)


## 🔵 テスト専用。purchased_upgrade_countsをapply_upgrade()を介さず直接注入する（FR-013）
func _set_purchased_upgrade_counts_for_test(counts: Dictionary) -> void:
	GameStateTestSupport.set_purchased_upgrade_counts(self, counts)


## 🔴 テスト専用。goldをdeliver_pending_products()を介さず直接注入する
## （apply_upgrade()の所持ゴールド境界値テスト用の新規補完）
func _set_gold_for_test(gold: int) -> void:
	GameStateTestSupport.set_gold(self, gold)


# テスト分離専用。デバッグビルドガードは他のテスト専用API群と同じくGameStateTestSupport.guard()
# へ一元化する（🔴 コードレビュー指摘対応。以前は本関数だけ独自にassert+push_error+returnを
# 重複実装していた）
func reset_for_test() -> void:
	if not GameStateTestSupport.guard("reset_for_test"):
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
	_current_daily_order = null
	_current_rank_id = GameBalance.INITIAL_RANK_ID
	_rank_masters = {}
	_rank_state = RankState.new()
	_demotion_count = 0
	_last_rank_outcome = RankOutcome.Value.CONTINUE
	_rank_state_initialized = false
	_warned_missing_rank_master_ids = {}
	_in_exam = false
	_exam_state = ExamState.new()
	_last_exam_outcome = ExamOutcome.Value.CONTINUE
	_can_purchase_permanent = false
	_purchased_upgrade_counts = {}
	_upgrade_masters = {}
