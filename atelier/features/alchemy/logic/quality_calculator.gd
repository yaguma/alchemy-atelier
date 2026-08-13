# 🔵 投入素材から調合物の品質スコアを確定し、品質から価値倍率を引く純粋関数群
# （core-systems.md L146-147）。副作用・乱数を持たない。
class_name QualityCalculator

const CATALYST_TAG := &"catalyst"


## 🔵 投入素材の品質スコア平均を四捨五入し、traits_unlockedかつ触媒タグ保有時のみ+1する（core-systems.md L146）。
## 空配列は SlotState.can_execute() により実運用では到達しない防御的分岐
static func calculate_quality(materials: Array[MaterialInstance], traits_unlocked: bool) -> int:
	if materials.is_empty():
		return GameBalance.QUALITY_SCORE_MIN

	var total := 0
	for material in materials:
		total += material.quality_score
	var quality := roundi(float(total) / float(materials.size()))

	if traits_unlocked and _has_catalyst(materials):
		quality += 1

	return clampi(quality, GameBalance.QUALITY_SCORE_MIN, GameBalance.QUALITY_SCORE_MAX)


## 🔵 品質スコアに対応する価値倍率を返す（core-systems.md L147）。
## 範囲外の入力はテーブル未定義キーによるnull返却を避けるため下限・上限にクランプする
static func quality_multiplier(quality_score: int) -> float:
	var clamped := clampi(
		quality_score, GameBalance.QUALITY_SCORE_MIN, GameBalance.QUALITY_SCORE_MAX
	)
	return GameBalance.QUALITY_MULTIPLIER_TABLE[clamped]


static func _has_catalyst(materials: Array[MaterialInstance]) -> bool:
	for material in materials:
		if material.trait_tags.has(CATALYST_TAG):
			return true
	return false
