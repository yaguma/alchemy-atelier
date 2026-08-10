extends GdUnitTestSuite


func test_コンストラクタに渡した値がプロパティに設定される() -> void:
	var trait_tags: Array[StringName] = [&"holy"]

	var instance := MaterialInstance.new("mat_0001", &"material_herb", 3, trait_tags)

	assert_str(instance.instance_id).is_equal("mat_0001")
	assert_that(instance.material_id).is_equal(&"material_herb")
	assert_int(instance.quality_score).is_equal(3)
	assert_that(instance.trait_tags).is_equal(trait_tags)


func test_cloneで生成したインスタンスは値が等しいが別オブジェクトである() -> void:
	var trait_tags: Array[StringName] = [&"holy"]
	var original := MaterialInstance.new("mat_0001", &"material_herb", 3, trait_tags)

	var cloned := original.clone()

	assert_bool(cloned == original).is_false()
	assert_str(cloned.instance_id).is_equal(original.instance_id)
	assert_that(cloned.material_id).is_equal(original.material_id)
	assert_int(cloned.quality_score).is_equal(original.quality_score)
	assert_that(cloned.trait_tags).is_equal(original.trait_tags)


func test_cloneしたtrait_tagsを変更しても元のインスタンスは変化しない() -> void:
	var trait_tags: Array[StringName] = [&"holy"]
	var original := MaterialInstance.new("mat_0001", &"material_herb", 3, trait_tags)

	var cloned := original.clone()
	cloned.trait_tags.append(&"catalyst")

	assert_int(cloned.trait_tags.size()).is_equal(2)
	assert_int(original.trait_tags.size()).is_equal(1)


func test_空のtrait_tagsでもインスタンス生成とcloneができる() -> void:
	var empty_tags: Array[StringName] = []

	var instance := MaterialInstance.new("mat_0002", &"material_herb", 1, empty_tags)
	var cloned := instance.clone()

	assert_int(instance.trait_tags.size()).is_equal(0)
	assert_int(cloned.trait_tags.size()).is_equal(0)


func test_コンストラクタに渡した配列を後から変更してもインスタンスは影響を受けない() -> void:
	var trait_tags: Array[StringName] = [&"holy"]
	var instance := MaterialInstance.new("mat_0001", &"material_herb", 3, trait_tags)

	trait_tags.append(&"catalyst")

	assert_int(instance.trait_tags.size()).is_equal(1)
