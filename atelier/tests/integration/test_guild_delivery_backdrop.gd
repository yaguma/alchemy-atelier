extends GdUnitTestSuite

const SCENE_PATH := "res://features/guild/ui/guild_delivery_backdrop.tscn"
const GuildDeliveryBackdropPixelScript = preload(
	"res://features/guild/ui/guild_delivery_backdrop.gd"
)


func _make_backdrop() -> GuildDeliveryBackdropPixel:
	var runner := scene_runner(SCENE_PATH)
	return runner.scene() as GuildDeliveryBackdropPixel


# 正常系


func test_シーンをinstantiateしてadd_childしてもエラーが出ない() -> void:
	var backdrop := _make_backdrop()

	assert_object(backdrop).is_not_null()


func test_texture_がBACKDROP_TEXTUREと一致する() -> void:
	var backdrop := _make_backdrop()

	assert_object(backdrop.texture).is_equal(GuildDeliveryBackdropPixelScript.BACKDROP_TEXTURE)


func test_texture_filterがNEARESTに設定されている() -> void:
	var backdrop := _make_backdrop()

	assert_int(backdrop.texture_filter).is_equal(CanvasItem.TEXTURE_FILTER_NEAREST)


func test_stretch_modeがKEEP_ASPECT_COVEREDに設定されている() -> void:
	var backdrop := _make_backdrop()

	assert_int(backdrop.stretch_mode).is_equal(TextureRect.STRETCH_KEEP_ASPECT_COVERED)


func test_mouse_filterがIGNOREに設定されている() -> void:
	var backdrop := _make_backdrop()

	assert_int(backdrop.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)


func test_ノード名がGuildDeliveryBackdropである() -> void:
	var backdrop := _make_backdrop()

	assert_str(backdrop.name).is_equal("GuildDeliveryBackdrop")
