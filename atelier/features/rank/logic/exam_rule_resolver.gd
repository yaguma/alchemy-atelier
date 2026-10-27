# 🔵 昇格試験ルールの予告・進捗記録・合格判定を担う純粋関数群（core-systems.md「v7.1追加システム」、FR-715）。
# 副作用・GameState参照を持たず、乱数はRngServiceが払い出した値を引数で受け取る。
# 進捗はExamState.progress（Dictionary）で表し、更新系は引数を書き換えず新しいDictionaryを返す。
class_name ExamRuleResolver

const PROGRESS_DELIVERED_COUNT := "delivered_count"
## 進捗（条件を満たす納品数）で合否を決めるルール種別
const PROGRESS_RULE_TYPES: Array[StringName] = [
	ExamRuleMaster.RULE_DELIVER_ITEMS,
	ExamRuleMaster.RULE_QUALITY_WITH_SLOT_LIMIT,
	ExamRuleMaster.RULE_DUAL_TRAITS,
	ExamRuleMaster.RULE_USE_INTERMEDIATE,
]


## 🔵 ランク開始時に試験ルールを1つ予告する（FR-715-002）。候補が空なら&""（従来の試験ノルマ方式）
static func announce(rule_pool: Array[StringName], rng_value: float) -> StringName:
	if rule_pool.is_empty():
		return &""
	var index := clampi(int(rng_value * rule_pool.size()), 0, rule_pool.size() - 1)
	return rule_pool[index]


## 🔵 試験中の納品1件を進捗に反映した新しい進捗を返す。ルールの条件を満たす納品だけを数える
static func record_delivery(
	progress: Dictionary, rule: ExamRuleMaster, product: ProductInstance
) -> Dictionary:
	var updated := progress.duplicate()
	if rule != null and _counts_toward(rule, product):
		updated[PROGRESS_DELIVERED_COUNT] = delivered_count(progress) + 1
	return updated


static func delivered_count(progress: Dictionary) -> int:
	return int(progress.get(PROGRESS_DELIVERED_COUNT, 0))


## 🔵 合格判定（FR-715-001）。ルールなし・quotaルールは試験ノルマが0以下なら合格（v7.0の方式）、
## それ以外のルールは条件を満たす納品数が目標に達したら合格
static func is_cleared(progress: Dictionary, rule: ExamRuleMaster, exam_quota: float) -> bool:
	if rule == null or rule.rule_type == ExamRuleMaster.RULE_QUOTA:
		return RankQuotaResolver.is_rank_cleared(exam_quota)
	if not _is_known_progress_rule(rule.rule_type):
		return false
	return delivered_count(progress) >= maxi(1, rule.target_count)


## 🔵 試験中の投入枠上限（FR-715-004）。quality_with_slot_limitのみ通常の枠数より小さい上限を課す
static func effective_slot_limit(rule: ExamRuleMaster, base_slot_count: int) -> int:
	if rule == null or rule.rule_type != ExamRuleMaster.RULE_QUALITY_WITH_SLOT_LIMIT:
		return base_slot_count
	if rule.slot_limit <= 0:
		return base_slot_count
	return mini(rule.slot_limit, base_slot_count)


static func _counts_toward(rule: ExamRuleMaster, product: ProductInstance) -> bool:
	match rule.rule_type:
		ExamRuleMaster.RULE_DELIVER_ITEMS:
			return (
				rule.target_recipe_ids.is_empty() or rule.target_recipe_ids.has(product.recipe_id)
			)
		ExamRuleMaster.RULE_QUALITY_WITH_SLOT_LIMIT:
			return product.quality_score >= rule.min_quality
		ExamRuleMaster.RULE_DUAL_TRAITS:
			for trait_tag in rule.target_traits:
				if not product.activated_traits.has(trait_tag):
					return false
			return not rule.target_traits.is_empty()
		ExamRuleMaster.RULE_USE_INTERMEDIATE:
			return product.used_intermediate
		_:
			return false


static func _is_known_progress_rule(rule_type: StringName) -> bool:
	return PROGRESS_RULE_TYPES.has(rule_type)
