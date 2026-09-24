extends GdUnitTestSuite

## PR #61コードレビュー指摘の回帰テスト。UiEffects.fly_ghost()がfrom_global_positionを
## 明示的に受け取るAPIへ変更されたことに伴うAlchemyScreenEffects側の修正
## （play_material_slide_inの二重複製解消・play_craft_result_popの中央配置バグ）を検証する。

const AlchemySlotViewScene = preload("res://features/alchemy/ui/alchemy_slot_view.tscn")


func _make_control(rect: Rect2 = Rect2(Vector2.ZERO, Vector2(200, 200))) -> Control:
	var control: Control = auto_free(Control.new())
	control.position = rect.position
	control.size = rect.size
	add_child(control)
	return control


func _make_slot_view() -> AlchemySlotView:
	var slot_view: AlchemySlotView = AlchemySlotViewScene.instantiate()
	add_child(auto_free(slot_view))
	slot_view.setup_empty(0)
	return slot_view


# 正常系


func test_play_material_slide_inでoverlay_layerの子ノード数がちょうど1増える() -> void:
	var overlay := _make_control()
	var target_slot := _make_slot_view()
	var slot_views: Array[AlchemySlotView] = [target_slot]
	var placed_ids: Array[String] = ["mat_1"]
	var before_count := overlay.get_child_count()

	AlchemyScreenEffects.play_material_slide_in(
		overlay, slot_views, placed_ids, "mat_1", Vector2(10, 10)
	)

	# 🔴 修正前はtarget_slot.duplicate()（呼び出し元）→fly_ghost内部でさらにduplicate()という
	# 二重複製が発生していた。overlay_layerへ実際に載るのはfly_ghost内部の複製1つだけであるべき
	assert_int(overlay.get_child_count()).is_equal(before_count + 1)


func test_play_material_slide_in後もtarget_slot自身はシーンツリーから外れない() -> void:
	var overlay := _make_control()
	var target_slot := _make_slot_view()
	var slot_views: Array[AlchemySlotView] = [target_slot]
	var placed_ids: Array[String] = ["mat_1"]

	AlchemyScreenEffects.play_material_slide_in(
		overlay, slot_views, placed_ids, "mat_1", Vector2(10, 10)
	)

	assert_bool(is_instance_valid(target_slot)).is_true()
	assert_object(target_slot.get_parent()).is_not_null()


func test_play_craft_result_popでポップアップがoverlay_layerの中央に配置される() -> void:
	var overlay := _make_control(Rect2(Vector2(50, 50), Vector2(300, 300)))

	AlchemyScreenEffects.play_craft_result_pop(overlay, "テスト完成！", 0.05)

	var popup := overlay.get_child(overlay.get_child_count() - 1) as Control
	# 🔴 修正前はglobal_positionへ中央点をそのまま代入していたため、popup自身のサイズの半分だけ
	# 右下にズレていた。get_combined_minimum_size()はコンテナのsort待ちが要らない同期API。
	var expected_position := (
		overlay.get_global_rect().get_center() - popup.get_combined_minimum_size() / 2.0
	)
	assert_vector(popup.global_position).is_equal_approx(expected_position, Vector2(0.5, 0.5))


# 境界値


func test_投入枠外のslot_indexでは演出が発生しない() -> void:
	var overlay := _make_control()
	var target_slot := _make_slot_view()
	var slot_views: Array[AlchemySlotView] = [target_slot]
	var placed_ids: Array[String] = []  # "mat_1"が含まれないためfindが-1を返す
	var before_count := overlay.get_child_count()

	AlchemyScreenEffects.play_material_slide_in(
		overlay, slot_views, placed_ids, "mat_1", Vector2(10, 10)
	)

	assert_int(overlay.get_child_count()).is_equal(before_count)
