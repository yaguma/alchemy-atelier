# 🔵 日替わり指定依頼の絞り込みと抽選を担う純粋関数群。
# 副作用・乱数生成・GameState参照を持たず、乱数値は引数で受け取る（tdd-implementation.md）。
class_name DailyOrderSelector

const CONDITION_TYPE_ITEM := "item"
const CONDITION_TYPE_TRAIT := "trait"


## 🔵 現在の解禁状況で達成可能なDailyOrderMasterのみへ絞り込む。
## itemは対象レシピが解禁済みのもの、traitはtraits_unlockedがtrueの場合のみ残す。
## 🔴 未知のcondition_type・ターゲットが空文字のエントリは、不正なマスターデータが
## 抽選プールへ混入して達成不能な依頼が提示されるのを防ぐため除外する
static func filter_achievable(
	all_orders: Array[DailyOrderMaster],
	unlocked_recipe_ids: Array[StringName],
	traits_unlocked: bool,
) -> Array[DailyOrderMaster]:
	var achievable: Array[DailyOrderMaster] = []

	for order in all_orders:
		match order.condition_type:
			CONDITION_TYPE_ITEM:
				if order.target_recipe_id.is_empty():
					continue
				if unlocked_recipe_ids.has(StringName(order.target_recipe_id)):
					achievable.append(order)
			CONDITION_TYPE_TRAIT:
				if order.target_trait.is_empty():
					continue
				if traits_unlocked:
					achievable.append(order)
			_:
				continue

	return achievable


## 🔵 絞り込み済みプールから乱数値[0.0, 1.0)を用いて1件を均一抽選する。
## 種別による重み付けはせず、プールが空の場合はnullを返す。
## 🔴 random_valueが理論上の境界（1.0近傍）や契約外の値でも配列範囲外アクセスしないようクランプする
static func select(pool: Array[DailyOrderMaster], random_value: float) -> DailyOrderMaster:
	if pool.is_empty():
		return null

	var index := clampi(floori(random_value * pool.size()), 0, pool.size() - 1)
	return pool[index]
