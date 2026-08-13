# 🔵 投入素材から発現する特性タグを判定する純粋関数群（core-systems.md L148-149）。
# 副作用・乱数を持たない。
class_name TraitActivation


## 🔵 traits_unlocked=falseなら常に空配列。真の場合、同一特性タグの出現数が
## GameBalance.TRAIT_ACTIVATION_THRESHOLD以上のものだけを発現済みとして返す。
## 触媒タグ（QualityCalculator側で個別処理）はこの閾値ルールの対象外のため除外する
static func resolve_traits(
	materials: Array[MaterialInstance], traits_unlocked: bool
) -> Array[StringName]:
	if not traits_unlocked:
		return []

	var activated: Array[StringName] = []
	for trait_tag in _collect_unique_tags(materials):
		if trait_tag == GameBalance.CATALYST_TAG:
			continue
		if count_trait_occurrences(materials, trait_tag) >= GameBalance.TRAIT_ACTIVATION_THRESHOLD:
			activated.append(trait_tag)
	return activated


## 🔵 投入素材中の特定特性タグの出現数を数える
static func count_trait_occurrences(
	materials: Array[MaterialInstance], trait_tag: StringName
) -> int:
	var count := 0
	for material in materials:
		if material.trait_tags.has(trait_tag):
			count += 1
	return count


## 🟡 投入素材から出現するユニークなタグ集合を、出現順を保ったまま収集する
static func _collect_unique_tags(materials: Array[MaterialInstance]) -> Array[StringName]:
	var seen: Dictionary = {}
	var unique: Array[StringName] = []
	for material in materials:
		for trait_tag in material.trait_tags:
			if seen.has(trait_tag):
				continue
			seen[trait_tag] = true
			unique.append(trait_tag)
	return unique
