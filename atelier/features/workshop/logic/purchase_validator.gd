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
