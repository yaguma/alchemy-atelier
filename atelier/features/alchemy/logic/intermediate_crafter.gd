# 🔵 中間素材（別の調合に使う、特性を凝縮した素材）を組み立てる純粋関数群
# （core-systems.md「v7.1追加システム」、FR-713）。副作用・乱数を持たない。
# instance_idの採番は呼び出し元（GameState）の責務。
class_name IntermediateCrafter


## 🔵 投入素材とレシピから中間素材のMaterialInstanceを組み立てる（FR-713-002〜004）。
## 品質は納品用と同じ計算（QualityCalculator）、特性はTraitActivationで発現したもののうち
## レシピが許す数だけを凝縮する。鮮度は0から始まる（劣化しないかどうかはMaterialMaster側で決まる）
static func craft(
	materials: Array[MaterialInstance],
	recipe: RecipeMaster,
	traits_unlocked: bool,
	instance_id: String
) -> MaterialInstance:
	var quality := QualityCalculator.calculate_quality(materials, traits_unlocked)
	var activated := TraitActivation.resolve_traits(materials, traits_unlocked)
	var concentrated := select_concentrated_traits(
		materials, activated, recipe.max_concentrated_traits
	)
	return MaterialInstance.new(
		instance_id, recipe.output_material_id, quality, build_trait_tags(concentrated)
	)


## 🔵 発現した特性のうち、投入素材中の出現数が多い順（同数なら発現順で先のもの）に最大max_traits個を返す
## （FR-713-004）
static func select_concentrated_traits(
	materials: Array[MaterialInstance], activated_traits: Array[StringName], max_traits: int
) -> Array[StringName]:
	var ranked := activated_traits.duplicate()
	# 🔵 sort_customは安定ソートではないため、同数時は元の発現順インデックスで明示的に比較する
	ranked.sort_custom(
		func(a: StringName, b: StringName) -> bool:
			var count_a := TraitActivation.count_trait_occurrences(materials, a)
			var count_b := TraitActivation.count_trait_occurrences(materials, b)
			if count_a != count_b:
				return count_a > count_b
			return activated_traits.find(a) < activated_traits.find(b)
	)

	var selected: Array[StringName] = []
	for trait_tag in ranked:
		if selected.size() >= max_traits:
			break
		selected.append(trait_tag)
	return selected


## 🔵 各特性をGameBalance.INTERMEDIATE_CONCENTRATION個ずつ並べる（例: [holy] → [holy, holy]）
static func build_trait_tags(concentrated_traits: Array[StringName]) -> Array[StringName]:
	var tags: Array[StringName] = []
	for trait_tag in concentrated_traits:
		for i in range(GameBalance.INTERMEDIATE_CONCENTRATION):
			tags.append(trait_tag)
	return tags
