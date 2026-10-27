## GameState.get_state()が返す読み取り専用ビューの組み立てを分離する内部ヘルパー。
## 🔴 game_state.gd 500行ルール対応（Issue #68）。GameStateTestSupportと同じパターンで、
## GameState側は本ファイルへの1行委譲のみを担う。返す内容・防御的コピーの方針は移設前と同一。
class_name GameStateViewDelegate

const GameStateScript = preload("res://autoload/game_state.gd")


# 内部Dictionary/Arrayフィールドを直接返すと呼び出し元が改変できてしまうため、
# 辞書リテラルを都度生成しduplicate(true)でディープコピーを保証する（state-management.md）。
# garden_state/inventoryはカスタムRefCounted型を含むため、clone()を明示的に呼ぶ（🔵 AC-014, FR-403）。
# 🔴 Array.map()の戻り値は型付き配列(Array[MaterialInstance])ではなく素のArrayになり、
# 呼び出し元で型付き変数へ代入する際に実行時エラーとなるため、明示的に型付き配列を構築する
# （GardenState.clone()と同じ既知の罠）
static func build_state(state: GameStateScript) -> Dictionary:
	var cloned_inventory: Array[MaterialInstance] = []
	for material in state._inventory:
		cloned_inventory.append(material.clone())

	var cloned_pending_products: Array[ProductInstance] = []
	for product in state._pending_products:
		cloned_pending_products.append(product.clone())

	var current_daily_order := state._current_daily_order
	return {
		"current_phase": state._current_phase,
		"gold": state._gold,
		"current_turn": state._current_turn,
		"garden_state": state._garden_state.clone(),
		"seed_inventory": state._seed_inventory.duplicate(true),
		# 🔴 タスク018（GardenScreen）実装のための新規補完。PlantSlotView.setup()/SeedInventoryList.setup()
		# がSeedMasterを必要とするため公開する。マスターデータ（Infrastructure層、Resourceは不変前提）の
		# ためDictionary自体の浅いduplicate()のみで防御的コピー要件を満たす
		"seed_masters": state._seed_masters.duplicate(),
		# 🔴 GardenState.plantsは埋まっているスロットのみを保持し空きスロットを表現しないため、
		# GardenScreenが全スロット（空き含む）を描画するには庭の総スロット数が別途必要
		"garden_slot_count": state._garden_slot_count,
		"inventory": cloned_inventory,
		# 🔵 Issue #64（FR-711-007）。seed_masters公開と同型。AlchemyScreenが素材ごとの劣化間隔から
		# 次の劣化までの残りターンを表示するために必要。Resourceは不変前提のため浅いduplicate()で十分
		"material_masters": state._material_masters.duplicate(),
		# 🔵 CON-001。seed_masters公開と同型。AlchemyScreenがレシピ詳細（名称・必要素材等）を
		# 描画するために必要。マスターデータ（Resourceは不変前提）のため浅いduplicate()で十分
		"recipe_masters": state._recipe_masters.duplicate(),
		# 🔵 CON-002。garden_slot_count公開と同型。AlchemyScreenが投入枠を空き含めて
		# 描画するために必要。int値型のため複製不要
		"alchemy_slot_count": state._alchemy_slot_count,
		# 🔴 要素がStringName（値型相当）のため浅い複製で十分（FR-403）
		"unlocked_recipe_ids": state._unlocked_recipe_ids.duplicate(),
		"pending_products": cloned_pending_products,
		"recipe_mastery": state._inspiration_state.mastery.duplicate(),  # 🔵 Issue #67
		"inspired_recipe_ids": state._inspiration_state.inspired_recipe_ids.duplicate(),
		# 🔴 DailyOrderMasterは@export var（プリミティブ）のみで構成されるが、Resource自体は
		# 参照型のため他フィールドと同様clone()してから返す（state-management.md防御的コピー要件）
		"current_daily_order": current_daily_order.clone() if current_daily_order else null,
		# 🔵 Issue #65。値がfloat（値型）のDictionaryのため浅いduplicate()で十分
		"market_rates": state._market_rates.duplicate(),
		# 🔵 FR-006。StringName/intは値型のため複製不要。RankStateは参照型のためclone()する（FR-410）
		"current_rank_id": state._current_rank_id,
		"demotion_count": state._demotion_count,
		"rank_state": state._rank_state.clone(),
		# 🔵 FR-009, AC-018。試験ビュー5フィールドはすべて値型のため、_exam_state.clone()のような
		# 明示的コピー呼び出しは不要（値型コピーで防御性が保たれる、design phase確定）
		"in_exam": state._in_exam,
		"exam_quota": state._exam_state.exam_quota,
		"exam_quota_max": state._exam_state.exam_quota_max,
		"exam_elapsed_turn": state._exam_state.exam_elapsed_turn,
		"exam_turn_limit": state._exam_state.exam_turn_limit,
		# 🔵 Issue #68（FR-715）。試験ルール関連。ExamRuleMasterは不変前提のマスターデータのため複製しない
		"exam_rule_id": state._exam_state.exam_rule_id,
		"exam_rule": GameStateRankDelegate.current_exam_rule(state),
		"exam_progress": state._exam_state.progress.duplicate(),
		"announced_exam_rule":
		state._exam_rule_masters.get(state._rank_state.announced_exam_rule_id),
		"effective_alchemy_slot_count": GameStateAlchemyDelegate.effective_slot_count(state),
		"can_purchase_permanent": state._can_purchase_permanent,  # 🔵 FR-017
		# 🔵 FR-007。seed_masters/recipe_masters公開と同型。UpgradeMasterはResource（不変前提の
		# マスターデータ）のため、Dictionary自体の浅いduplicate()のみで防御的コピー要件を満たす
		"upgrade_masters": state._upgrade_masters.duplicate(),
		# 🔵 FR-008。値がint（値型）のDictionaryのため、浅いduplicate()でキー追加/削除・値上書きの
		# いずれからも_purchased_upgrade_counts本体を保護できる
		"purchased_upgrade_counts": state._purchased_upgrade_counts.duplicate(),
	}
