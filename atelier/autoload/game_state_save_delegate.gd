## GameStateのセーブデータ収集ロジックを分離する内部ヘルパー。
## 🔵 既存のgame_state_{garden,alchemy,guild,rank,workshop}_delegate.gd・game_state_test_support.gdと
## 同じく、static funcがstateのprivate fieldへ直接アクセスするパターンに従う。
class_name GameStateSaveDelegate

const GameStateScript = preload("res://autoload/game_state.gd")


## 🔵 stateの現在のゲーム進行状態を、JSON化可能なプリミティブのみのDictionaryへ変換して返す。
## get_state()はUI向けにマスターデータ（SeedMaster等のResource）まで含めて返すため流用せず、
## private fieldを直接読む。マスターデータ系フィールド（_seed_masters, _material_masters,
## _recipe_masters, _rank_masters, _upgrade_masters, _daily_order_masters,
## _warned_missing_rank_master_ids）は再ロードで復元できるため収集対象外とする。
## 🔵 StringNameはJSON.stringify()が扱える型ではないためString()でStringへ変換する。
## 🟡 Resource参照（_current_daily_order, ProductInstance.daily_order_snapshot）はIDのみを保存し、
## ロード時にマスターデータから引き直す前提とする（Resource自体をJSONへ埋め込まない）。
static func collect_save_data(state: GameStateScript) -> Dictionary:
	var unlocked_recipe_ids: Array[String] = []
	for recipe_id in state._unlocked_recipe_ids:
		unlocked_recipe_ids.append(String(recipe_id))

	var seed_inventory: Array[Dictionary] = []
	for entry in state._seed_inventory:
		seed_inventory.append({"seed_id": String(entry["seed_id"]), "count": int(entry["count"])})

	var purchased_upgrade_counts: Dictionary = {}
	for upgrade_id in state._purchased_upgrade_counts:
		purchased_upgrade_counts[String(upgrade_id)] = int(
			state._purchased_upgrade_counts[upgrade_id]
		)

	# 🟡 Resource本体ではなくIDのみを保存する。未設定（null）は空文字列で表現し、
	# ロード時に「本日の指定なし」として復元できるようにする
	var daily_order := state._current_daily_order
	var current_daily_order_id: String = daily_order.id if daily_order else ""

	return {
		"current_phase": String(state._current_phase),
		"gold": state._gold,
		"current_turn": state._current_turn,
		"garden_state": _collect_garden_state(state._garden_state),
		"seed_inventory": seed_inventory,
		"inventory": _collect_inventory(state._inventory),
		"material_instance_seq": state._material_instance_seq,
		"garden_slot_count": state._garden_slot_count,
		"unlocked_recipe_ids": unlocked_recipe_ids,
		"pending_products": _collect_pending_products(state._pending_products),
		"alchemy_slot_count": state._alchemy_slot_count,
		"current_daily_order_id": current_daily_order_id,
		"current_rank_id": String(state._current_rank_id),
		"demotion_count": state._demotion_count,
		"rank_state": _collect_rank_state(state._rank_state),
		"rank_state_initialized": state._rank_state_initialized,
		# 🔵 enum値はJSON上でintとして往復させる（GodotのJSONは数値をfloatで復元するため、
		# ロード側でint()へ丸める前提）
		"last_rank_outcome": int(state._last_rank_outcome),
		"in_exam": state._in_exam,
		"exam_state": _collect_exam_state(state._exam_state),
		"last_exam_outcome": int(state._last_exam_outcome),
		"has_cleared_game": state._has_cleared_game,
		"can_purchase_permanent": state._can_purchase_permanent,
		"purchased_upgrade_counts": purchased_upgrade_counts,
	}


static func _collect_garden_state(garden_state: GardenState) -> Dictionary:
	var plants: Array[Dictionary] = []
	for plant in garden_state.plants:
		var entry := {
			"slot_index": plant.slot_index,
			"seed_id": String(plant.seed_id),
			"grown_turns": plant.grown_turns,
			"is_matured": plant.is_matured,
		}
		plants.append(entry)
	return {"plants": plants}


static func _collect_inventory(inventory: Array[MaterialInstance]) -> Array:
	var collected: Array[Dictionary] = []
	for material in inventory:
		var trait_tags: Array[String] = []
		for tag in material.trait_tags:
			trait_tags.append(String(tag))
		var entry := {
			"instance_id": material.instance_id,
			"material_id": String(material.material_id),
			"quality_score": material.quality_score,
			"trait_tags": trait_tags,
		}
		collected.append(entry)
	return collected


## 🟡 daily_order_snapshotはResource参照のためIDのみを保存する。has_daily_order_snapshotが
## trueでもsnapshot自体がnull（＝調合時点で指定依頼なし）の場合があるため、
## 両フィールドを独立して保存し、ロード側でIDの空文字列とフラグを別々に復元できるようにする。
static func _collect_pending_products(pending_products: Array[ProductInstance]) -> Array:
	var collected: Array[Dictionary] = []
	for product in pending_products:
		var activated_traits: Array[String] = []
		for activated_trait in product.activated_traits:
			activated_traits.append(String(activated_trait))
		var snapshot := product.daily_order_snapshot
		var entry := {
			"recipe_id": String(product.recipe_id),
			"quality_score": product.quality_score,
			"activated_traits": activated_traits,
			"contribution": product.contribution,
			"reward": product.reward,
			"has_daily_order_snapshot": product.has_daily_order_snapshot,
			"daily_order_snapshot_id": snapshot.id if snapshot else "",
		}
		collected.append(entry)
	return collected


static func _collect_rank_state(rank_state: RankState) -> Dictionary:
	return {"quota": rank_state.quota, "elapsed_turn": rank_state.elapsed_turn}


static func _collect_exam_state(exam_state: ExamState) -> Dictionary:
	return {
		"exam_quota": exam_state.exam_quota,
		"exam_quota_max": exam_state.exam_quota_max,
		"exam_elapsed_turn": exam_state.exam_elapsed_turn,
		"exam_turn_limit": exam_state.exam_turn_limit,
	}


## 🔵 collect_save_data()の逆変換。検証済みdataをstateのprivate fieldへ直接適用する。
## 呼び出し前提: state.load_*_master_data()が全て実行済みであること
## （current_daily_order_id・daily_order_snapshot_idのID→Resource解決に必要）。
## マスターデータ系フィールドは収集対象外のため、ここでも一切書き換えない。
## 🔵 JSON往復を経たdataは数値がすべてfloatになるため、int/StringNameフィールドは
## 明示的にint()/StringName()へ変換してから代入する（collect側のコメントと対になる前提）。
## 🔵 配列・オブジェクトはすべて新規インスタンスを構築し、引数dataの内部配列を
## stateがそのまま保持しないようにする（呼び出し元からの内部状態改変を防ぐ）。
static func restore_save_data(state: GameStateScript, data: Dictionary) -> void:
	var seed_inventory: Array[Dictionary] = []
	for entry in data["seed_inventory"]:
		seed_inventory.append(
			{"seed_id": StringName(entry["seed_id"]), "count": int(entry["count"])}
		)

	var unlocked_recipe_ids: Array[StringName] = []
	for recipe_id in data["unlocked_recipe_ids"]:
		unlocked_recipe_ids.append(StringName(recipe_id))

	var purchased_upgrade_counts: Dictionary = {}
	var saved_counts: Dictionary = data["purchased_upgrade_counts"]
	for upgrade_id in saved_counts:
		purchased_upgrade_counts[StringName(upgrade_id)] = int(saved_counts[upgrade_id])

	var daily_order_masters := state._daily_order_masters

	state._current_phase = StringName(data["current_phase"])
	state._gold = int(data["gold"])
	state._current_turn = int(data["current_turn"])
	state._garden_state = _restore_garden_state(data["garden_state"])
	state._seed_inventory = seed_inventory
	state._inventory = _restore_inventory(data["inventory"])
	state._material_instance_seq = int(data["material_instance_seq"])
	state._garden_slot_count = int(data["garden_slot_count"])
	state._unlocked_recipe_ids = unlocked_recipe_ids
	state._pending_products = _restore_pending_products(
		data["pending_products"], daily_order_masters
	)
	state._alchemy_slot_count = int(data["alchemy_slot_count"])
	state._current_daily_order = _find_daily_order_master_by_id(
		daily_order_masters, String(data["current_daily_order_id"])
	)
	state._current_rank_id = StringName(data["current_rank_id"])
	state._demotion_count = int(data["demotion_count"])
	state._rank_state = _restore_rank_state(data["rank_state"])
	state._rank_state_initialized = bool(data["rank_state_initialized"])
	state._last_rank_outcome = int(data["last_rank_outcome"]) as RankOutcome.Value
	state._in_exam = bool(data["in_exam"])
	state._exam_state = _restore_exam_state(data["exam_state"])
	state._last_exam_outcome = int(data["last_exam_outcome"]) as ExamOutcome.Value
	state._has_cleared_game = bool(data["has_cleared_game"])
	state._can_purchase_permanent = bool(data["can_purchase_permanent"])
	state._purchased_upgrade_counts = purchased_upgrade_counts


## 🟡 保存済みIDに一致するDailyOrderMasterをロード済みマスターから線形探索して返す。
## 空文字列（＝保存時点で指定依頼なし）、およびマスターデータ側の変更でIDが消えた場合は
## 例外を投げずnullを返す（「本日の指定なし」への安全側フォールバック。CON-010と同じ扱い）。
## 母集団は最大でも日替わり依頼の全件数のため、辞書化せず線形探索で足りる
static func _find_daily_order_master_by_id(
	daily_order_masters: Array[DailyOrderMaster], id: String
) -> DailyOrderMaster:
	if id.is_empty():
		return null
	for master in daily_order_masters:
		if master.id == id:
			return master
	return null


static func _restore_garden_state(data: Dictionary) -> GardenState:
	var plants: Array[PlantState] = []
	for entry in data["plants"]:
		plants.append(
			PlantState.new(
				int(entry["slot_index"]),
				StringName(entry["seed_id"]),
				int(entry["grown_turns"]),
				bool(entry["is_matured"])
			)
		)
	var garden_state := GardenState.new()
	garden_state.plants = plants
	return garden_state


static func _restore_inventory(data: Array) -> Array[MaterialInstance]:
	var inventory: Array[MaterialInstance] = []
	for entry in data:
		var trait_tags: Array[StringName] = []
		for tag in entry["trait_tags"]:
			trait_tags.append(StringName(tag))
		inventory.append(
			MaterialInstance.new(
				String(entry["instance_id"]),
				StringName(entry["material_id"]),
				int(entry["quality_score"]),
				trait_tags
			)
		)
	return inventory


## 🟡 has_daily_order_snapshotとdaily_order_snapshot_idは独立に復元する（collect側と対）。
## IDが空文字列・未知のいずれの場合もsnapshotはnullとし、フラグは保存値をそのまま維持する。
## フラグをtrueのまま残すことで「調合時点で指定依頼なし」として扱われ、
## deliver_pending_products()が納品時点の別依頼へ勝手にフォールバックすることを防ぐ
static func _restore_pending_products(
	data: Array, daily_order_masters: Array[DailyOrderMaster]
) -> Array[ProductInstance]:
	var pending_products: Array[ProductInstance] = []
	for entry in data:
		var activated_traits: Array[StringName] = []
		for activated_trait in entry["activated_traits"]:
			activated_traits.append(StringName(activated_trait))
		var product := ProductInstance.new(
			StringName(entry["recipe_id"]),
			int(entry["quality_score"]),
			activated_traits,
			float(entry["contribution"]),
			float(entry["reward"])
		)
		product.has_daily_order_snapshot = bool(entry["has_daily_order_snapshot"])
		product.daily_order_snapshot = _find_daily_order_master_by_id(
			daily_order_masters, String(entry["daily_order_snapshot_id"])
		)
		pending_products.append(product)
	return pending_products


static func _restore_rank_state(data: Dictionary) -> RankState:
	var rank_state := RankState.new()
	rank_state.quota = float(data["quota"])
	rank_state.elapsed_turn = int(data["elapsed_turn"])
	return rank_state


static func _restore_exam_state(data: Dictionary) -> ExamState:
	var exam_state := ExamState.new()
	exam_state.exam_quota = float(data["exam_quota"])
	exam_state.exam_quota_max = float(data["exam_quota_max"])
	exam_state.exam_elapsed_turn = int(data["exam_elapsed_turn"])
	exam_state.exam_turn_limit = int(data["exam_turn_limit"])
	return exam_state
