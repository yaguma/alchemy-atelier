# 🔵 納品判定と最終価値算出を担う純粋関数群（core-systems.md L211-214）。
# 副作用・乱数・GameState参照を持たない（FR-401, FR-402, AC-013）。
class_name DeliveryResolver

const CONDITION_TYPE_ITEM := "item"
const CONDITION_TYPE_TRAIT := "trait"


## 🔵 調合物が日替わり指定依頼の条件に合致するか判定する（FR-101, FR-102, FR-201）。
## daily_order=nullは昇格試験からの呼び出し想定で、必ずfalseを返す（AC-003）。
## condition_typeが"item"/"trait"以外の未知値も非合致として扱う（AC-007, NFR-101）
static func matches_order(product: ProductInstance, daily_order: DailyOrderMaster) -> bool:
	if daily_order == null:
		return false

	match daily_order.condition_type:
		CONDITION_TYPE_ITEM:
			# 🔴 target_recipe_id未設定（既定値""）を、recipe_idが空のProduct（本来あり得ないが
			# 不正なマスターデータ/フィクスチャ由来の場合）と誤って合致させないためのガード
			if daily_order.target_recipe_id.is_empty():
				return false
			return product.recipe_id == StringName(daily_order.target_recipe_id)
		CONDITION_TYPE_TRAIT:
			if daily_order.target_trait.is_empty():
				return false
			return product.activated_traits.has(StringName(daily_order.target_trait))
		_:
			return false


## 🔵 指定合致ボーナスを適用した最終貢献度・報酬を算出する（FR-103, FR-104, FR-201）。
## 🔴 この倍率を掛けるのは本関数のみ。ProductValueCalculator側では適用しない（FR-403, AC-014 二重乗算バグ防止）
static func resolve(product: ProductInstance, daily_order: DailyOrderMaster) -> DeliveryResult:
	var order_matched := matches_order(product, daily_order)
	var multiplier := daily_order.match_bonus_multiplier if order_matched else 1.0

	return DeliveryResult.new(
		product.contribution * multiplier, product.reward * multiplier, order_matched
	)
