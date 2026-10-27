extends GdUnitTestSuite

## 🔵 Issue #67（FR-714-005）。ひらめき対応表の実データが読み込め、参照先がすべて実在することを検証する。


func _recipes_by_id() -> Dictionary:
	var by_id: Dictionary = {}
	for recipe in MasterDataLoader.load_all(&"recipes"):
		by_id[(recipe as RecipeMaster).id] = recipe
	return by_id


func _material_ids() -> Dictionary:
	var ids: Dictionary = {}
	for master in MasterDataLoader.load_all(&"materials"):
		if master is MaterialMaster:
			ids[(master as MaterialMaster).id] = true
	return ids


# 正常系


func test_inspirationsカテゴリで実データをInspirationMasterとしてロードする() -> void:
	var inspirations := MasterDataLoader.load_all(&"inspirations")

	assert_int(inspirations.size()).is_equal(4)
	for master in inspirations:
		assert_bool(master is InspirationMaster).is_true()


func test_元レシピと結果のレシピがすべて実在する() -> void:
	var recipes := _recipes_by_id()

	for master: InspirationMaster in MasterDataLoader.load_all(&"inspirations"):
		assert_bool(recipes.has(master.source_recipe_id)).is_true()
		assert_bool(recipes.has(master.result_recipe_id)).is_true()


func test_解禁ランクはすべてRANK_ORDERに含まれる() -> void:
	for master: InspirationMaster in MasterDataLoader.load_all(&"inspirations"):
		assert_bool(GameBalance.RANK_ORDER.has(master.min_rank_id)).is_true()


func test_中間素材レシピの出力素材がすべて実在し劣化しない() -> void:
	var material_ids := _material_ids()
	var materials: Dictionary = {}
	for master in MasterDataLoader.load_all(&"materials"):
		if master is MaterialMaster:
			materials[(master as MaterialMaster).id] = master

	for recipe: RecipeMaster in _recipes_by_id().values():
		if not recipe.is_intermediate():
			continue
		assert_bool(material_ids.has(recipe.output_material_id)).is_true()
		var output: MaterialMaster = materials[recipe.output_material_id]
		assert_int(output.decay_interval_turns).is_equal(0)
		assert_bool(output.is_intermediate).is_true()


# 異常系


func test_ひらめきはEランク以降でのみ解禁される() -> void:
	for rank: RankMaster in MasterDataLoader.load_all(&"ranks"):
		var order := GameBalance.RANK_ORDER.find(StringName(rank.id))
		var expected := order >= GameBalance.RANK_ORDER.find(&"rank_e")
		assert_bool(rank.inspiration_unlocked).is_equal(expected)
