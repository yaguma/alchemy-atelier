# 🔵 品質倍率と特性ボーナスから調合物の貢献度・報酬を算出する純粋関数群。
# 副作用・乱数を持たない。
# 🟡 特性ボーナスの系統別（貢献度系/報酬系）乗算合成APIはcore-systems.mdのクラス図に無い追加分のため、
# 設計文書側への反映（同期）を別途検討すること。
class_name ProductValueCalculator


## 🔵 貢献度 = 基礎貢献度 × 品質倍率 × 貢献度系特性ボーナス。
## 指定調合物ボーナス（match_bonus_multiplier相当）は納品決算側の責務であり、
## 二重乗算バグ（FR-406）の再発防止のため本関数では受け取らない
static func calculate_contribution(
	base_contribution: float, quality_mult: float, trait_bonus: float
) -> float:
	return base_contribution * quality_mult * trait_bonus


## 🔵 報酬 = 基礎報酬 × 品質倍率 × 報酬系特性ボーナス。
## 指定調合物ボーナスを受け取らない理由はcalculate_contribution()と同じ（FR-406）
static func calculate_reward(base_reward: float, quality_mult: float, trait_bonus: float) -> float:
	return base_reward * quality_mult * trait_bonus


## 🔵 発現特性のうち貢献度系として登録されたタグの倍率のみを乗算合成する。
## 報酬系タグ・未登録タグは無視する（系統間の非干渉＝真のトレードオフの前提）
static func resolve_contribution_bonus(activated_traits: Array[StringName]) -> float:
	return _multiply_bonus(activated_traits, GameBalance.TRAIT_CONTRIBUTION_BONUS)


## 🔵 発現特性のうち報酬系として登録されたタグの倍率のみを乗算合成する。
## 貢献度系タグ・未登録タグは無視する
static func resolve_reward_bonus(activated_traits: Array[StringName]) -> float:
	return _multiply_bonus(activated_traits, GameBalance.TRAIT_REWARD_BONUS)


## 🟡 倍率テーブルに登録済みのタグのみを乗算合成する。該当なしなら等倍（1.0）を返す
static func _multiply_bonus(activated_traits: Array[StringName], bonus_table: Dictionary) -> float:
	var bonus := 1.0
	for trait_tag in activated_traits:
		if bonus_table.has(trait_tag):
			bonus *= float(bonus_table[trait_tag])
	return bonus
