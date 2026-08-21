extends GdUnitTestSuite

const MaterialInventoryListScene = preload("res://features/alchemy/ui/material_inventory_list.tscn")


func _make_material(
	instance_id: String, material_id: StringName, quality_score: int, trait_tags: Array[StringName]
) -> MaterialInstance:
	return MaterialInstance.new(instance_id, material_id, quality_score, trait_tags)


func _make_list() -> MaterialInventoryList:
	var list: MaterialInventoryList = auto_free(MaterialInventoryListScene.instantiate())
	add_child(list)
	return list


func _find_row(list: MaterialInventoryList, instance_id: String) -> Control:
	return list.find_child("MaterialEntry_%s" % instance_id, true, false) as Control


func _find_place_button(list: MaterialInventoryList, instance_id: String) -> Button:
	return _find_row(list, instance_id).get_node("PlaceButton") as Button


func _find_label(list: MaterialInventoryList, instance_id: String, label_name: String) -> Label:
	return _find_row(list, instance_id).get_node(label_name) as Label


# 正常系
func test_2件の素材を渡すと2件のエントリが表示される() -> void:
	var list := _make_list()
	var no_tags: Array[StringName] = []
	var materials: Array[MaterialInstance] = [
		_make_material("mat_1", &"herb_common", 3, no_tags),
		_make_material("mat_2", &"ore_common", 2, no_tags),
	]

	list.setup(materials)

	assert_int(list.get_entry_count()).is_equal(2)


# 正常系
func test_各エントリに素材IDと品質と特性が表示される() -> void:
	var list := _make_list()
	var tags: Array[StringName] = [&"holy", &"catalyst"]
	var materials: Array[MaterialInstance] = [_make_material("mat_1", &"herb_common", 4, tags)]

	list.setup(materials)

	assert_str(_find_label(list, "mat_1", "NameLabel").text).is_equal("herb_common")
	assert_str(_find_label(list, "mat_1", "QualityLabel").text).contains("4")
	var trait_text := _find_label(list, "mat_1", "TraitLabel").text
	assert_str(trait_text).contains("holy")
	assert_str(trait_text).contains("catalyst")


# 正常系
func test_配置ボタン押下で対応するinstance_idのシグナルが発行される() -> void:
	var list := _make_list()
	var no_tags: Array[StringName] = []
	var materials: Array[MaterialInstance] = [
		_make_material("mat_1", &"herb_common", 3, no_tags),
		_make_material("mat_2", &"ore_common", 2, no_tags),
	]
	list.setup(materials)
	monitor_signals(list, false)

	_find_place_button(list, "mat_2").pressed.emit()

	await assert_signal(list).is_emitted("material_place_requested", ["mat_2"])


# 正常系
func test_setupを再実行すると前回のエントリが残らない() -> void:
	var list := _make_list()
	var no_tags: Array[StringName] = []
	var first: Array[MaterialInstance] = [
		_make_material("mat_1", &"herb_common", 3, no_tags),
		_make_material("mat_2", &"ore_common", 2, no_tags),
	]
	list.setup(first)

	var second: Array[MaterialInstance] = [_make_material("mat_2", &"ore_common", 2, no_tags)]
	list.setup(second)

	assert_int(list.get_entry_count()).is_equal(1)
	assert_object(_find_row(list, "mat_1")).is_null()


# 異常系
func test_特性を持たない素材でもクラッシュせず表示される() -> void:
	var list := _make_list()
	var no_tags: Array[StringName] = []
	var materials: Array[MaterialInstance] = [_make_material("mat_1", &"herb_common", 1, no_tags)]

	list.setup(materials)

	assert_int(list.get_entry_count()).is_equal(1)
	assert_str(_find_label(list, "mat_1", "NameLabel").text).is_equal("herb_common")


# 異常系
func test_null要素が混在しても無視されクラッシュしない() -> void:
	var list := _make_list()
	var no_tags: Array[StringName] = []
	var materials: Array[MaterialInstance] = [
		null, _make_material("mat_1", &"herb_common", 3, no_tags)
	]

	list.setup(materials)

	assert_int(list.get_entry_count()).is_equal(1)


# 境界値
func test_空の配列でもエントリが0件で正常に表示される() -> void:
	var list := _make_list()
	var empty: Array[MaterialInstance] = []

	list.setup(empty)

	assert_int(list.get_entry_count()).is_equal(0)


# 境界値
func test_20件の素材を渡しても全件表示され末尾のシグナルが発行される() -> void:
	var list := _make_list()
	var no_tags: Array[StringName] = []
	var materials: Array[MaterialInstance] = []
	for i in range(20):
		materials.append(_make_material("mat_%d" % i, &"herb_common", (i % 5) + 1, no_tags))

	list.setup(materials)
	monitor_signals(list, false)
	_find_place_button(list, "mat_19").pressed.emit()

	assert_int(list.get_entry_count()).is_equal(20)
	await assert_signal(list).is_emitted("material_place_requested", ["mat_19"])
