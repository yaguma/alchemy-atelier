# 🔵 工房強化・ショップの購入可否判定を担う純粋関数群（FR-001, FR-002, FR-003）。
# 副作用なし、Node非継承、GameState・UI層への参照禁止（FR-403、Functional Core原則）。
class_name PurchaseValidator


## 🔵 所持ゴールドが価格以上、かつ購入済み回数が上限未満であれば購入可能と判定する（FR-001）。
static func can_purchase(
	gold: int, price: int, already_purchased_count: int, max_purchase_count: int
) -> bool:
	return gold >= price and already_purchased_count < max_purchase_count


## 🔵 対象アップグレードが恒久強化かどうかを返す（FR-002）。
static func is_permanent_upgrade(upgrade: UpgradeMaster) -> bool:
	return upgrade.is_permanent


## 🔴 effect_typeが既知の5種類（FR-105〜109）のいずれかであり、かつeffect_valueがその種別に
## 応じた型（int/StringName）を満たすかを検証する。未知のeffect_typeや型不一致のeffect_valueを
## 持つUpgradeMasterがapply_upgrade()の状態変更フェーズに到達すると、ゴールドだけ減算されて
## 効果が反映されない不整合が起きるため、状態変更前にこの関数で弾く（コードレビュー指摘対応）
static func is_valid_effect(upgrade: UpgradeMaster) -> bool:
	match upgrade.effect_type:
		&"alchemy_slot_increase", &"garden_slot_increase":
			return upgrade.effect_value is int
		&"recipe_unlock", &"seed_name_purchase":
			return upgrade.effect_value is StringName
		&"catalyst_stock":
			return true
		_:
			return false
