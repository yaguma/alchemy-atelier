extends GdUnitTestSuite

const SCENE_PATH := "res://features/title/ui/title_backdrop.tscn"
const TitleBackdropPixelScript = preload("res://features/title/ui/title_backdrop.gd")


func _make_backdrop() -> TitleBackdropPixel:
	var runner := scene_runner(SCENE_PATH)
	return runner.scene() as TitleBackdropPixel


# 正常系


func test_シーンをinstantiateしてadd_childしてもエラーが出ない() -> void:
	var backdrop := _make_backdrop()

	assert_object(backdrop).is_not_null()


func test_texture_がBACKDROP_TEXTUREと一致する() -> void:
	var backdrop := _make_backdrop()

	assert_object(backdrop.texture).is_equal(TitleBackdropPixelScript.BACKDROP_TEXTURE)


func test_texture_filterがNEARESTに設定されている() -> void:
	var backdrop := _make_backdrop()

	assert_int(backdrop.texture_filter).is_equal(CanvasItem.TEXTURE_FILTER_NEAREST)


func test_mouse_filterがIGNOREに設定されている() -> void:
	var backdrop := _make_backdrop()

	assert_int(backdrop.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)


func test_ノード名がTitleBackdropである() -> void:
	var backdrop := _make_backdrop()

	assert_str(backdrop.name).is_equal("TitleBackdrop")
