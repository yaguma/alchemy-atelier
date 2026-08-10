extends GdUnitTestSuite


func test_コンストラクタに渡した値がプロパティに設定される() -> void:
	var plant := PlantState.new(0, &"seed_herb", 2, true)

	assert_int(plant.slot_index).is_equal(0)
	assert_that(plant.seed_id).is_equal(&"seed_herb")
	assert_int(plant.grown_turns).is_equal(2)
	assert_bool(plant.is_matured).is_true()


func test_コンストラクタの省略可能引数はデフォルト値が設定される() -> void:
	var plant := PlantState.new(1, &"seed_herb")

	assert_int(plant.grown_turns).is_equal(0)
	assert_bool(plant.is_matured).is_false()


func test_cloneで生成したインスタンスは値が等しいが別オブジェクトである() -> void:
	var original := PlantState.new(0, &"seed_herb", 2, true)

	var cloned := original.clone()

	assert_bool(cloned == original).is_false()
	assert_int(cloned.slot_index).is_equal(original.slot_index)
	assert_that(cloned.seed_id).is_equal(original.seed_id)
	assert_int(cloned.grown_turns).is_equal(original.grown_turns)
	assert_bool(cloned.is_matured).is_equal(original.is_matured)


func test_cloneしたインスタンスのgrown_turnsを変更しても元は変化しない() -> void:
	var original := PlantState.new(0, &"seed_herb", 2, false)

	var cloned := original.clone()
	cloned.grown_turns = 99

	assert_int(cloned.grown_turns).is_equal(99)
	assert_int(original.grown_turns).is_equal(2)
