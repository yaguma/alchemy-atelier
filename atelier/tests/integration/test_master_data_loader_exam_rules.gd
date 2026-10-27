extends GdUnitTestSuite

## 🔵 Issue #68（FR-715）。試験ルールの実データが読み込め、ランクの候補・合格報酬の参照先が実在し、
## 実際に達成可能な条件になっていることを検証する。


func _rules_by_id() -> Dictionary:
	var by_id: Dictionary = {}
	for rule in MasterDataLoader.load_all(&"exam_rules"):
		by_id[(rule as ExamRuleMaster).id] = rule
	return by_id


func _recipe_ids() -> Dictionary:
	var ids: Dictionary = {}
	for recipe in MasterDataLoader.load_all(&"recipes"):
		ids[(recipe as RecipeMaster).id] = true
	return ids


## 庭の種から収穫で付く可能性のある特性タグの集合（"none"は無特性のため除く）
func _obtainable_traits() -> Dictionary:
	var traits: Dictionary = {}
	for master in MasterDataLoader.load_all(&"materials"):
		if master is SeedMaster:
			for trait_tag in (master as SeedMaster).trait_pool:
				if trait_tag != &"none":
					traits[trait_tag] = true
	return traits


# 正常系


func test_各ランクの試験ルール候補がすべて実在する() -> void:
	var rules := _rules_by_id()

	for rank: RankMaster in MasterDataLoader.load_all(&"ranks"):
		for rule_id in rank.exam_rule_pool:
			assert_bool(rules.has(rule_id)).is_true()


func test_合格報酬と対象レシピがすべて実在する() -> void:
	var recipes := _recipe_ids()

	for rule: ExamRuleMaster in _rules_by_id().values():
		for recipe_id in rule.reward_recipe_ids:
			assert_bool(recipes.has(recipe_id)).is_true()
		for recipe_id in rule.target_recipe_ids:
			assert_bool(recipes.has(recipe_id)).is_true()


func test_ノルマ以外のルールは制限ターンが正の値である() -> void:
	for rule: ExamRuleMaster in _rules_by_id().values():
		if rule.rule_type == ExamRuleMaster.RULE_QUOTA:
			continue
		assert_int(rule.turn_limit).is_greater(0)


func test_複数特性ルールの特性はすべて庭で入手できる() -> void:
	var obtainable := _obtainable_traits()

	for rule: ExamRuleMaster in _rules_by_id().values():
		for trait_tag in rule.target_traits:
			assert_bool(obtainable.has(trait_tag)).is_true()


# 異常系


func test_Gランクは試験ルールを持たず従来の試験ノルマ方式で行う() -> void:
	for rank: RankMaster in MasterDataLoader.load_all(&"ranks"):
		if rank.id == "rank_g":
			assert_array(rank.exam_rule_pool).is_empty()
