extends GdUnitTestSuite


func test_rng_valueが0のとき先頭要素が選ばれる() -> void:
	var trait_pool: Array[StringName] = [&"holy", &"gold", &"none"]
	var seed_master := SeedMaster.new()
	seed_master.trait_pool = trait_pool

	var result := TraitRoll.roll_trait(seed_master, 0.0)

	assert_that(result).is_equal(&"holy")


func test_rng_valueが末尾に近い値のとき末尾要素が選ばれる() -> void:
	var trait_pool: Array[StringName] = [&"holy", &"gold", &"none"]
	var seed_master := SeedMaster.new()
	seed_master.trait_pool = trait_pool

	var result := TraitRoll.roll_trait(seed_master, 0.99)

	assert_that(result).is_equal(&"none")


func test_rng_valueが中間値のとき対応するインデックスの要素が選ばれる() -> void:
	var trait_pool: Array[StringName] = [&"holy", &"gold", &"none"]
	var seed_master := SeedMaster.new()
	seed_master.trait_pool = trait_pool

	# int(0.5 * 3) = 1 -> "gold"
	var result := TraitRoll.roll_trait(seed_master, 0.5)

	assert_that(result).is_equal(&"gold")


func test_trait_poolが1要素のみの場合rng_valueによらず常にその要素が返る(
	rng_value: float, _test_parameters := [[0.0], [0.5], [0.99]]
) -> void:
	var trait_pool: Array[StringName] = [&"only"]
	var seed_master := SeedMaster.new()
	seed_master.trait_pool = trait_pool

	var result := TraitRoll.roll_trait(seed_master, rng_value)

	assert_that(result).is_equal(&"only")


func test_rng_valueが1_0でも範囲外アクセスにならず末尾要素が返る() -> void:
	var trait_pool: Array[StringName] = [&"holy", &"gold", &"none"]
	var seed_master := SeedMaster.new()
	seed_master.trait_pool = trait_pool

	var result := TraitRoll.roll_trait(seed_master, 1.0)

	assert_that(result).is_equal(&"none")
