extends GdUnitTestSuite

## 🔵 Issue #68（FR-715）。昇格試験ルールの予告・進捗記録・合格判定を検証する。


func _make_rule(rule_type: StringName) -> ExamRuleMaster:
	var rule := ExamRuleMaster.new()
	rule.id = StringName("exam_%s" % rule_type)
	rule.rule_type = rule_type
	rule.turn_limit = 2
	rule.target_count = 1
	return rule


func _make_product(
	recipe_id: StringName = &"recipe_a",
	quality: int = 3,
	traits: Array[StringName] = [],
	used_intermediate: bool = false
) -> ProductInstance:
	var product := ProductInstance.new(recipe_id, quality, traits, 10.0, 5.0)
	product.used_intermediate = used_intermediate
	return product


# 正常系（予告）


func test_候補から乱数で1つの試験ルールを予告する() -> void:
	var pool: Array[StringName] = [&"exam_a", &"exam_b"]

	assert_that(ExamRuleResolver.announce(pool, 0.1)).is_equal(&"exam_a")
	assert_that(ExamRuleResolver.announce(pool, 0.9)).is_equal(&"exam_b")


# 正常系（ルール別の合格判定）


func test_quotaルールは試験ノルマが0なら合格する() -> void:
	var rule := _make_rule(ExamRuleMaster.RULE_QUOTA)

	assert_bool(ExamRuleResolver.is_cleared({}, rule, 0.0)).is_true()
	assert_bool(ExamRuleResolver.is_cleared({}, rule, 5.0)).is_false()


func test_deliver_itemsは指定レシピの納品数が目標に達すると合格する() -> void:
	var rule := _make_rule(ExamRuleMaster.RULE_DELIVER_ITEMS)
	rule.target_recipe_ids = [&"recipe_a"] as Array[StringName]
	rule.target_count = 2
	var progress := {}

	progress = ExamRuleResolver.record_delivery(progress, rule, _make_product(&"recipe_a"))
	assert_bool(ExamRuleResolver.is_cleared(progress, rule, 1.0)).is_false()
	progress = ExamRuleResolver.record_delivery(progress, rule, _make_product(&"recipe_a"))

	assert_bool(ExamRuleResolver.is_cleared(progress, rule, 1.0)).is_true()


func test_deliver_itemsで対象外のレシピは数えない() -> void:
	var rule := _make_rule(ExamRuleMaster.RULE_DELIVER_ITEMS)
	rule.target_recipe_ids = [&"recipe_a"] as Array[StringName]

	var progress := ExamRuleResolver.record_delivery({}, rule, _make_product(&"recipe_b"))

	assert_int(ExamRuleResolver.delivered_count(progress)).is_equal(0)


func test_deliver_itemsで対象レシピが空なら任意のレシピを数える() -> void:
	var rule := _make_rule(ExamRuleMaster.RULE_DELIVER_ITEMS)

	var progress := ExamRuleResolver.record_delivery({}, rule, _make_product(&"recipe_b"))

	assert_int(ExamRuleResolver.delivered_count(progress)).is_equal(1)


func test_quality_with_slot_limitは指定品質以上の納品で合格する() -> void:
	var rule := _make_rule(ExamRuleMaster.RULE_QUALITY_WITH_SLOT_LIMIT)
	rule.min_quality = 4

	var low := ExamRuleResolver.record_delivery({}, rule, _make_product(&"recipe_a", 3))
	var high := ExamRuleResolver.record_delivery({}, rule, _make_product(&"recipe_a", 4))

	assert_bool(ExamRuleResolver.is_cleared(low, rule, 1.0)).is_false()
	assert_bool(ExamRuleResolver.is_cleared(high, rule, 1.0)).is_true()


func test_dual_traitsは指定特性をすべて宿した納品で合格する() -> void:
	var rule := _make_rule(ExamRuleMaster.RULE_DUAL_TRAITS)
	rule.target_traits = [&"holy", &"heal"] as Array[StringName]
	var one: Array[StringName] = [&"holy"]
	var both: Array[StringName] = [&"holy", &"heal"]

	var partial := ExamRuleResolver.record_delivery({}, rule, _make_product(&"r", 3, one))
	var full := ExamRuleResolver.record_delivery({}, rule, _make_product(&"r", 3, both))

	assert_bool(ExamRuleResolver.is_cleared(partial, rule, 1.0)).is_false()
	assert_bool(ExamRuleResolver.is_cleared(full, rule, 1.0)).is_true()


func test_use_intermediateは中間素材を投入した納品で合格する() -> void:
	var rule := _make_rule(ExamRuleMaster.RULE_USE_INTERMEDIATE)
	var no_traits: Array[StringName] = []

	var without := ExamRuleResolver.record_delivery({}, rule, _make_product(&"r", 3, no_traits))
	var with_it := ExamRuleResolver.record_delivery(
		{}, rule, _make_product(&"r", 3, no_traits, true)
	)

	assert_bool(ExamRuleResolver.is_cleared(without, rule, 1.0)).is_false()
	assert_bool(ExamRuleResolver.is_cleared(with_it, rule, 1.0)).is_true()


func test_quality_with_slot_limitでは投入枠の上限が下がる() -> void:
	var rule := _make_rule(ExamRuleMaster.RULE_QUALITY_WITH_SLOT_LIMIT)
	rule.slot_limit = 3

	assert_int(ExamRuleResolver.effective_slot_limit(rule, 5)).is_equal(3)


func test_record_deliveryは引数の進捗を書き換えない() -> void:
	var rule := _make_rule(ExamRuleMaster.RULE_DELIVER_ITEMS)
	var progress := {}

	ExamRuleResolver.record_delivery(progress, rule, _make_product())

	assert_dict(progress).is_empty()


# 異常系


func test_候補が空なら予告はない() -> void:
	var pool: Array[StringName] = []

	assert_that(ExamRuleResolver.announce(pool, 0.5)).is_equal(&"")


func test_ルールがnullなら試験ノルマ方式で判定する() -> void:
	assert_bool(ExamRuleResolver.is_cleared({}, null, 0.0)).is_true()
	assert_bool(ExamRuleResolver.is_cleared({}, null, 1.0)).is_false()


func test_ルールがnullなら投入枠の上限は変わらない() -> void:
	assert_int(ExamRuleResolver.effective_slot_limit(null, 4)).is_equal(4)


func test_枠制限のないルールでは投入枠の上限は変わらない() -> void:
	var rule := _make_rule(ExamRuleMaster.RULE_DUAL_TRAITS)

	assert_int(ExamRuleResolver.effective_slot_limit(rule, 4)).is_equal(4)


func test_未知のルール種別は合格しない() -> void:
	var rule := _make_rule(&"unknown")

	var progress := ExamRuleResolver.record_delivery({}, rule, _make_product())

	assert_bool(ExamRuleResolver.is_cleared(progress, rule, 0.0)).is_false()


# 境界値


func test_枠制限が通常の枠数より多くても通常の枠数を超えない() -> void:
	var rule := _make_rule(ExamRuleMaster.RULE_QUALITY_WITH_SLOT_LIMIT)
	rule.slot_limit = 9

	assert_int(ExamRuleResolver.effective_slot_limit(rule, 4)).is_equal(4)


func test_品質ちょうど指定値でも合格する() -> void:
	var rule := _make_rule(ExamRuleMaster.RULE_QUALITY_WITH_SLOT_LIMIT)
	rule.min_quality = 5

	var progress := ExamRuleResolver.record_delivery({}, rule, _make_product(&"r", 5))

	assert_bool(ExamRuleResolver.is_cleared(progress, rule, 1.0)).is_true()


func test_乱数値が1に近くても候補の範囲内から選ぶ() -> void:
	var pool: Array[StringName] = [&"exam_a", &"exam_b"]

	assert_that(ExamRuleResolver.announce(pool, 0.99999)).is_equal(&"exam_b")
