# 🔴 コードレビュー指摘対応。QualityCalculator→TraitActivation→ProductValueCalculatorの
# 3段階パイプラインを、GameStateAlchemyDelegate.execute_alchemy()（本番実行）とAlchemyScreen
# ._recompute_preview()（ライブプレビュー）の双方から呼ばれる単一の計算経路に一本化する。
# 二重実装による将来的な乖離（プレビューと実行結果の不一致）を防ぐのが目的。副作用・乱数を持たない。
class_name ProductProvisionalResolver


## 投入素材・レシピ・現在ランクの特性解禁状態から仮のProductInstanceを組み立てる。
## 🔵 指定調合物ボーナス（DeliveryResolver側の責務）は含まない値を返す（FR-403、二重乗算バグ防止）。
## recipe.idをrecipe_idとして採用する（呼び出し元が渡すrecipe_masters辞書のキーと一致する前提）
static func resolve(
	materials: Array[MaterialInstance], recipe: RecipeMaster, traits_unlocked: bool
) -> ProductInstance:
	var quality := QualityCalculator.calculate_quality(materials, traits_unlocked)
	var quality_mult := QualityCalculator.quality_multiplier(quality)
	var activated_traits := TraitActivation.resolve_traits(materials, traits_unlocked)

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
	return ProductInstance.new(recipe.id, quality, activated_traits, contribution, reward)
