# 🔵 熟練ひらめきの確率・候補・内容を決める純粋関数群（core-systems.md「v7.1追加システム」、FR-714）。
# 副作用を持たず、乱数はRngServiceが払い出した値を引数で受け取る（Domain層で乱数を生成しない）。
class_name InspirationResolver

const CATALYST_TAG := &"catalyst"


## 🔵 熟練度（調合回数）からひらめく確率を返す（FR-714-003）。
## 天井回数以上なら1.0、熟練度0以下なら0.0
static func chance_for(mastery_count: int) -> float:
	if mastery_count <= 0:
		return 0.0
	if mastery_count >= GameBalance.INSPIRATION_CEILING_COUNT:
		return 1.0
	return minf(
		1.0,
		(
			GameBalance.INSPIRATION_BASE_CHANCE
			+ GameBalance.INSPIRATION_CHANCE_STEP * (mastery_count - 1)
		)
	)


static func should_inspire(mastery_count: int, rng_value: float) -> bool:
	return rng_value < chance_for(mastery_count)


## 🔵 投入素材の特性タグの和集合（初出順、触媒を除く）。ひらめく内容の方向を決める入力（FR-714-005）。
## 発現した特性ではなく「投入した特性」で決めるため、発現閾値に届かない1個の投入も方向付けに使える
static func input_traits(materials: Array[MaterialInstance]) -> Array[StringName]:
	var traits: Array[StringName] = []
	for material in materials:
		for trait_tag in material.trait_tags:
			if trait_tag == CATALYST_TAG or traits.has(trait_tag):
				continue
			traits.append(trait_tag)
	return traits


## 🔵 ひらめきの候補を返す（FR-714-005）。元レシピが一致し、現在ランクが解禁ランク以上で、
## 結果のレシピがまだ解禁されておらず、必要特性がすべて投入特性に含まれるものに絞る
static func find_candidates(
	masters: Array[InspirationMaster],
	source_recipe_id: StringName,
	traits: Array[StringName],
	current_rank_id: StringName,
	unlocked_recipe_ids: Array[StringName]
) -> Array[InspirationMaster]:
	var candidates: Array[InspirationMaster] = []
	for master in masters:
		if master.source_recipe_id != source_recipe_id:
			continue
		if not _is_open(master, current_rank_id, unlocked_recipe_ids):
			continue
		if not _contains_all(traits, master.required_traits):
			continue
		candidates.append(master)
	return candidates


## 🔵 PR #75レビュー指摘対応。投入特性を問わず、まだひらめく余地がある元レシピのIDを返す
## （解禁ランクを満たし、結果のレシピが未解禁の対応表を1件以上持つもの）。
## 調合画面はここに含まれないレシピの熟練度・ひらめき確率を表示しない
## （ひらめく先がないのに「次のひらめき100%」と表示して修行を促さないため）
static func inspirable_source_recipe_ids(
	masters: Array[InspirationMaster],
	current_rank_id: StringName,
	unlocked_recipe_ids: Array[StringName]
) -> Array[StringName]:
	var source_ids: Array[StringName] = []
	for master in masters:
		if source_ids.has(master.source_recipe_id):
			continue
		if _is_open(master, current_rank_id, unlocked_recipe_ids):
			source_ids.append(master.source_recipe_id)
	return source_ids


## 現在ランクが解禁ランク以上で、結果のレシピがまだ解禁されていないか
static func _is_open(
	master: InspirationMaster, current_rank_id: StringName, unlocked_recipe_ids: Array[StringName]
) -> bool:
	if unlocked_recipe_ids.has(master.result_recipe_id):
		return false
	var current_rank_order := GameBalance.RANK_ORDER.find(current_rank_id)
	var min_rank_order := GameBalance.RANK_ORDER.find(master.min_rank_id)
	return current_rank_order >= 0 and min_rank_order >= 0 and current_rank_order >= min_rank_order


## 🔵 必要特性の数が最も多い（より具体的な）候補群から、rng_value（0以上1未満）で1つ選ぶ。
## 候補がなければnull
static func pick(candidates: Array[InspirationMaster], rng_value: float) -> InspirationMaster:
	var most_specific: Array[InspirationMaster] = []
	var best_count := -1
	for candidate in candidates:
		var count := candidate.required_traits.size()
		if count > best_count:
			best_count = count
			most_specific = [candidate]
		elif count == best_count:
			most_specific.append(candidate)

	if most_specific.is_empty():
		return null
	var index := clampi(int(rng_value * most_specific.size()), 0, most_specific.size() - 1)
	return most_specific[index]


static func _contains_all(haystack: Array[StringName], needles: Array[StringName]) -> bool:
	for needle in needles:
		if not haystack.has(needle):
			return false
	return true
