extends GdUnitTestSuite


func _make_material(trait_tags: Array[StringName] = []) -> MaterialInstance:
	return MaterialInstance.new("mat_test", &"material_herb", 3, trait_tags)


# 正常系
func test_特性タグを持つ素材が2個以上で発現する() -> void:
	var materials: Array[MaterialInstance] = [
		_make_material([&"holy"]),
		_make_material([&"holy"]),
	]

	assert_array(TraitActivation.resolve_traits(materials, true)).contains([&"holy"])


# 異常系
func test_特性タグを持つ素材が1個のみでは発現しない() -> void:
	var materials: Array[MaterialInstance] = [_make_material([&"holy"]), _make_material()]

	assert_array(TraitActivation.resolve_traits(materials, true)).is_empty()


# 境界値
func test_特性タグを持つ素材が3個以上でも1つだけ発現する() -> void:
	var materials: Array[MaterialInstance] = [
		_make_material([&"holy"]),
		_make_material([&"holy"]),
		_make_material([&"holy"]),
	]

	var result := TraitActivation.resolve_traits(materials, true)

	assert_int(result.count(&"holy")).is_equal(1)


# 境界値
func test_特性未解放なら発現条件を満たしていても空配列を返す() -> void:
	var materials: Array[MaterialInstance] = [
		_make_material([&"holy"]),
		_make_material([&"holy"]),
		_make_material([&"holy"]),
	]

	assert_array(TraitActivation.resolve_traits(materials, false)).is_empty()


# 正常系
func test_触媒タグは発現閾値ルールの対象外である() -> void:
	var materials: Array[MaterialInstance] = [
		_make_material([&"catalyst"]),
		_make_material([&"catalyst"]),
	]

	assert_array(TraitActivation.resolve_traits(materials, true)).is_empty()


# 正常系
func test_出現数を正しく数える() -> void:
	var materials: Array[MaterialInstance] = [
		_make_material([&"holy"]),
		_make_material([&"holy"]),
		_make_material(),
	]

	assert_int(TraitActivation.count_trait_occurrences(materials, &"holy")).is_equal(2)


# エッジケース
func test_空配列ならresolve_traitsは空配列でcount_trait_occurrencesは0を返す() -> void:
	var materials: Array[MaterialInstance] = []

	assert_array(TraitActivation.resolve_traits(materials, true)).is_empty()
	assert_int(TraitActivation.count_trait_occurrences(materials, &"holy")).is_equal(0)


# 正常系
func test_貢献度系と報酬系が同時に発現条件を満たす場合両方発現する() -> void:
	var materials: Array[MaterialInstance] = [
		_make_material([&"holy"]),
		_make_material([&"holy"]),
		_make_material([&"gold"]),
		_make_material([&"gold"]),
	]

	var result := TraitActivation.resolve_traits(materials, true)

	assert_array(result).contains([&"holy", &"gold"])
	assert_int(result.size()).is_equal(2)
