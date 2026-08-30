extends GdUnitTestSuite

const NON_RANK_SOURCE_PATH := "res://data/materials/material_herb.tres"
const NON_RANK_TEMP_PATH := "res://data/ranks/_tmp_non_rank.tres"
const NON_DAILY_ORDER_TEMP_PATH := "res://data/daily_orders/_tmp_non_daily_order.tres"
const NON_TRES_TEMP_PATH := "res://data/daily_orders/_tmp_note.txt"

## data/daily_orders/配下に配置した実データの件数。実データ追加時は本定数も更新する
const EXPECTED_DAILY_ORDER_COUNT := 5
const NO_TRAIT_TAG := &"none"


func after_test() -> void:
	# 混在テストが作成した一時ファイルを、テスト失敗時も含め確実に除去する
	for path in [NON_RANK_TEMP_PATH, NON_DAILY_ORDER_TEMP_PATH, NON_TRES_TEMP_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
		if FileAccess.file_exists(path + ".uid"):
			DirAccess.remove_absolute(path + ".uid")


# 正常系


func test_materialsカテゴリで実データの全件をロードする() -> void:
	var materials := MasterDataLoader.load_all(&"materials")

	var seed_count := 0
	var material_count := 0
	for m in materials:
		if m is SeedMaster:
			seed_count += 1
		elif m is MaterialMaster:
			material_count += 1

	assert_int(seed_count).is_equal(2)
	assert_int(material_count).is_equal(3)


func test_ロードしたSeedMasterのフィールドが実データと一致する() -> void:
	var materials := MasterDataLoader.load_all(&"materials")

	var seed_herb: SeedMaster = null
	for m in materials:
		if m is SeedMaster and (m as SeedMaster).id == &"seed_herb":
			seed_herb = m
			break

	assert_object(seed_herb).is_not_null()
	assert_int(seed_herb.maturity_turns).is_equal(2)
	assert_int(seed_herb.death_grace_turns).is_equal(2)
	assert_int(seed_herb.base_quality).is_equal(2)
	assert_that(seed_herb.produces_material_id).is_equal(&"material_herb")


func test_ranksカテゴリで実データの全件をRankMasterとしてロードする() -> void:
	var ranks := MasterDataLoader.load_all(&"ranks")

	assert_int(ranks.size()).is_equal(GameBalance.RANK_ORDER.size())
	for r in ranks:
		assert_object(r).is_instanceof(RankMaster)


func test_ranksカテゴリのIDがRANK_ORDERと過不足なく一致する() -> void:
	var ranks := MasterDataLoader.load_all(&"ranks")

	var loaded_ids: Array[StringName] = []
	for r in ranks:
		loaded_ids.append(StringName((r as RankMaster).id))
	loaded_ids.sort()
	var expected_ids: Array[StringName] = GameBalance.RANK_ORDER.duplicate()
	expected_ids.sort()

	assert_array(loaded_ids).is_equal(expected_ids)


func test_daily_ordersカテゴリで実データの全件をDailyOrderMasterとしてロードする() -> void:
	var orders := MasterDataLoader.load_all(&"daily_orders")

	assert_int(orders.size()).is_equal(EXPECTED_DAILY_ORDER_COUNT)
	for o in orders:
		assert_object(o).is_instanceof(DailyOrderMaster)


func test_daily_ordersのidが重複せず全件非空である() -> void:
	var orders := MasterDataLoader.load_all(&"daily_orders")

	var seen_ids: Dictionary = {}
	for o in orders:
		var order_id: String = (o as DailyOrderMaster).id
		assert_str(order_id).is_not_empty()
		assert_bool(seen_ids.has(order_id)).is_false()
		seen_ids[order_id] = true


func test_item条件のエントリはtarget_recipe_idが実在レシピを指す() -> void:
	var recipe_ids: Dictionary = {}
	for r in MasterDataLoader.load_all(&"recipes"):
		recipe_ids[String((r as RecipeMaster).id)] = true

	var item_order_count := 0
	for o in MasterDataLoader.load_all(&"daily_orders"):
		var order := o as DailyOrderMaster
		if order.condition_type != "item":
			continue
		item_order_count += 1
		assert_str(order.target_recipe_id).is_not_empty()
		assert_bool(recipe_ids.has(order.target_recipe_id)).is_true()

	assert_int(item_order_count).is_greater(0)


func test_trait条件のエントリはtarget_traitが収穫可能な特性を指す() -> void:
	var obtainable_traits := _collect_obtainable_traits()

	var trait_order_count := 0
	for o in MasterDataLoader.load_all(&"daily_orders"):
		var order := o as DailyOrderMaster
		if order.condition_type != "trait":
			continue
		trait_order_count += 1
		assert_str(order.target_trait).is_not_empty()
		assert_bool(obtainable_traits.has(StringName(order.target_trait))).is_true()

	assert_int(trait_order_count).is_greater(0)


## match_bonus_multiplierを.tres側で明示指定していないこと（GameBalance側の変更に追従すること）を担保する
func test_daily_ordersのボーナス倍率がGameBalanceの既定値と一致する() -> void:
	var orders := MasterDataLoader.load_all(&"daily_orders")

	for o in orders:
		var multiplier: float = (o as DailyOrderMaster).match_bonus_multiplier
		assert_float(multiplier).is_equal(GameBalance.DAILY_ORDER_MATCH_BONUS_MULTIPLIER)


func test_実データに対しvalidate_referencesがtrueを返す() -> void:
	var materials := MasterDataLoader.load_all(&"materials")

	var result := MasterDataLoader.validate_references(materials)

	assert_bool(result).is_true()


# 異常系


func test_未解決のproduces_material_idがある場合validate_referencesがfalseを返す() -> void:
	var seed := SeedMaster.new()
	seed.id = &"seed_unknown"
	seed.produces_material_id = &"material_not_exist"
	var material := MaterialMaster.new()
	material.id = &"material_herb"

	var result := MasterDataLoader.validate_references([seed, material])

	assert_bool(result).is_false()


## ranksディレクトリに他カテゴリのリソース（MaterialMaster）を一時的に置いても、
## _is_allowed_type()の型フィルタにより取り込まれないことを検証する
func test_ranksディレクトリに他カテゴリのリソースがあっても取り込まない() -> void:
	var non_rank: Resource = load(NON_RANK_SOURCE_PATH)
	assert_int(ResourceSaver.save(non_rank.duplicate(), NON_RANK_TEMP_PATH)).is_equal(OK)

	var ranks := MasterDataLoader.load_all(&"ranks")

	assert_int(ranks.size()).is_equal(GameBalance.RANK_ORDER.size())
	for r in ranks:
		assert_object(r).is_instanceof(RankMaster)


## daily_ordersディレクトリに他カテゴリのリソース（MaterialMaster）を一時的に置いても、
## _is_allowed_type()の型フィルタにより取り込まれないことを検証する
func test_daily_ordersディレクトリに他カテゴリのリソースがあっても取り込まない() -> void:
	var non_order: Resource = load(NON_RANK_SOURCE_PATH)
	assert_int(ResourceSaver.save(non_order.duplicate(), NON_DAILY_ORDER_TEMP_PATH)).is_equal(OK)

	var orders := MasterDataLoader.load_all(&"daily_orders")

	assert_int(orders.size()).is_equal(EXPECTED_DAILY_ORDER_COUNT)
	for o in orders:
		assert_object(o).is_instanceof(DailyOrderMaster)


## .tres以外のファイルが混ざってもload()が呼ばれずクラッシュしないことを検証する
func test_daily_ordersディレクトリの非tresファイルを無視する() -> void:
	var file := FileAccess.open(NON_TRES_TEMP_PATH, FileAccess.WRITE)
	assert_object(file).is_not_null()
	file.store_string("not a resource")
	file.close()

	var orders := MasterDataLoader.load_all(&"daily_orders")

	assert_int(orders.size()).is_equal(EXPECTED_DAILY_ORDER_COUNT)


func test_未知のカテゴリでload_allを呼ぶと空配列を返す() -> void:
	var materials := MasterDataLoader.load_all(&"unknown_category")

	assert_array(materials).is_empty()


# 境界値


func test_空配列をvalidate_referencesに渡すとtrueを返す() -> void:
	var result := MasterDataLoader.validate_references([])

	assert_bool(result).is_true()


## G〜S全ランクで抽選プールが空にならないこと（Gランクは特性未解禁のためitem条件のみが有効）を検証する
func test_全ランクで達成可能なdaily_orderが最低1件存在する() -> void:
	var orders := MasterDataLoader.load_all(&"daily_orders")
	var obtainable_traits := _collect_obtainable_traits()
	var initial_recipe_id := String(GameBalance.INITIAL_RECIPE_ID)

	for rank_id in GameBalance.RANK_ORDER:
		var rank := _find_rank(rank_id)
		assert_object(rank).is_not_null()

		var achievable_count := 0
		for o in orders:
			var order := o as DailyOrderMaster
			if order.condition_type == "item" and order.target_recipe_id == initial_recipe_id:
				achievable_count += 1
			elif (
				order.condition_type == "trait"
				and rank.traits_unlocked
				and obtainable_traits.has(StringName(order.target_trait))
			):
				achievable_count += 1

		var failure_message := "ランク%sで達成可能なdaily_orderが存在しません" % rank_id
		assert_int(achievable_count).override_failure_message(failure_message).is_greater(0)


# ヘルパー


## 収穫で実際に入手しうる特性タグ集合をSeedMaster.trait_poolから構築する（&"none"は特性なしを表すため除外）
func _collect_obtainable_traits() -> Dictionary:
	var traits: Dictionary = {}
	for m in MasterDataLoader.load_all(&"materials"):
		if not (m is SeedMaster):
			continue
		for tag in (m as SeedMaster).trait_pool:
			if tag != NO_TRAIT_TAG:
				traits[tag] = true
	return traits


func _find_rank(rank_id: StringName) -> RankMaster:
	for r in MasterDataLoader.load_all(&"ranks"):
		if StringName((r as RankMaster).id) == rank_id:
			return r
	return null
