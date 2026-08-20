## GameStateの工房強化・ショップ（workshop）関連本番ロジックの実装詳細を分離する内部ヘルパー。
## 🔴 game_state.gd 500行ルール対応。GameStateTestSupportと同じパターンで、
## GameState側は本ファイルへの1行委譲のみを担う。公開シグネチャ・呼び出し方法は変更しない。
class_name GameStateWorkshopDelegate

const GameStateScript = preload("res://autoload/game_state.gd")


## res://data/upgrades/ から UpgradeMaster をロードし _upgrade_masters に格納する（🔵 FR-005, FR-011）。
## 重複ID検知パターンはload_alchemy_master_data()を踏襲する。
## 🔴 BootSceneからの呼び出し配線自体は本plan外。GameState側にAPIとして用意するのみ
static func load_workshop_master_data(state: GameStateScript) -> void:
	var upgrades := MasterDataLoader.load_all(&"upgrades")

	var upgrade_masters: Dictionary = {}
	for u in upgrades:
		var upgrade := u as UpgradeMaster
		if upgrade_masters.has(upgrade.id):
			push_error("工房強化アップグレードのIDが重複しています: %s" % upgrade.id)
			return
		upgrade_masters[upgrade.id] = upgrade
	state._upgrade_masters = upgrade_masters


## 🔵 検証(1)null(2)恒久フラグ(3)can_purchase再評価の順に行い、全て通過した場合のみ
## 状態変更（ゴールド減算・effect反映・購入回数カウント更新）をすべて完了させてからgold_changedを
## 発行する（FR-101〜104, FR-112〜114, FR-401〜402）。いずれかの検証に失敗した場合は
## いかなる状態も変更しない（execute_alchemy()と同型のアトミック性パターン）。
## effect_type別の状態反映は_apply_upgrade_effect()に委譲する
static func apply_upgrade(state: GameStateScript, upgrade: UpgradeMaster) -> Result:
	if upgrade == null:
		return Result.fail(&"invalid_upgrade")

	if PurchaseValidator.is_permanent_upgrade(upgrade) and not state._can_purchase_permanent:
		return Result.fail(&"workshop_closed")

	# 🔵 UIの先出し判定を信頼せず、状態変更の直前にDomain層の実行可否を再評価する
	var already_purchased_count: int = state._purchased_upgrade_counts.get(upgrade.id, 0)
	if not PurchaseValidator.can_purchase(
		state._gold, upgrade.price, already_purchased_count, upgrade.max_purchase_count
	):
		return Result.fail(&"cannot_purchase")

	# 🔴 未知のeffect_typeや型不一致のeffect_valueを持つUpgradeMasterは、状態変更フェーズに
	# 入る前にここで弾く。これにより_apply_upgrade_effect()に到達する時点でeffect_typeが
	# 既知の5種類・effect_valueが正しい型であることが保証され、_apply_upgrade_effect()内の
	# 素朴なasキャストが安全になる（コードレビュー指摘対応）
	if not PurchaseValidator.is_valid_effect(upgrade):
		return Result.fail(&"invalid_effect")

	# --- 状態変更フェーズ（全て完了するまでシグナル発行しない） ---
	var previous_gold := state._gold
	state._gold -= upgrade.price

	_apply_upgrade_effect(state, upgrade)

	state._purchased_upgrade_counts[upgrade.id] = already_purchased_count + 1

	state.gold_changed.emit(previous_gold, state._gold, state._gold - previous_gold)

	return Result.ok(upgrade)


## 🔵 upgrade.effect_typeに応じてGameStateの各状態を更新する（FR-105〜FR-109）。
## 呼び出し元のapply_upgrade()が既にPurchaseValidator.is_valid_effect()で
## effect_type・effect_valueの型を検証済みであることを前提とする（コードレビュー指摘対応で
## 事前検証を追加済み）。そのため以下のasキャストは全て型保証済みの安全なキャストであり、
## ここで改めて型ガードを重複させない。反映先はすべてGameState自身のフィールドに限定する
static func _apply_upgrade_effect(state: GameStateScript, upgrade: UpgradeMaster) -> void:
	match upgrade.effect_type:
		&"alchemy_slot_increase":
			state._alchemy_slot_count += (upgrade.effect_value as int)
		&"garden_slot_increase":
			state._garden_slot_count += (upgrade.effect_value as int)
		&"recipe_unlock":
			state._unlocked_recipe_ids.append(upgrade.effect_value as StringName)
		&"catalyst_stock":
			var material := MaterialInstance.new(
				state._next_material_instance_id(),
				GameBalance.CATALYST_MATERIAL_ID,
				GameBalance.CATALYST_BASE_QUALITY_SCORE,
				[&"catalyst"]
			)
			state._inventory.append(material)
		&"seed_name_purchase":
			var seed_id := upgrade.effect_value as StringName
			var index := GameStateGardenDelegate.find_seed_inventory_index(state, seed_id)
			if index == -1:
				state._seed_inventory.append({"seed_id": seed_id, "count": 1})
			else:
				state._seed_inventory[index]["count"] = (
					(state._seed_inventory[index]["count"] as int) + 1
				)
		_:
			push_error("未知のeffect_typeです: %s" % upgrade.effect_type)  # 🟡 防御的分岐


## 🔵 恒久投資購入可否フラグを閉じる（FR-015, FR-018）
static func close_workshop(state: GameStateScript) -> void:
	state._can_purchase_permanent = false


## 🔵 未購入（キー未登録）の場合は0を返す（FR-018）
static func get_purchased_count(state: GameStateScript, upgrade_id: StringName) -> int:
	return state._purchased_upgrade_counts.get(upgrade_id, 0)
