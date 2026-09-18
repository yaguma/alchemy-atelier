extends GdUnitTestSuite

## コードレビュー指摘対応: title_backdrop.gd/garden_backdrop.gd/alchemy_backdrop.gdで
## 重複していた背景設定処理をPixelBackdropApplier.apply()へ集約したための単体テスト
## （button_style_applier.gdの既存テストと同型）。

const DUMMY_TEXTURE: Texture2D = preload("res://assets/ui/pixel/panel_pixel.png")


func test_applyでtextureが設定される() -> void:
	var rect: TextureRect = auto_free(TextureRect.new())

	PixelBackdropApplier.apply(rect, DUMMY_TEXTURE)

	assert_object(rect.texture).is_equal(DUMMY_TEXTURE)


func test_applyでtexture_filterがnearestになる() -> void:
	var rect: TextureRect = auto_free(TextureRect.new())

	PixelBackdropApplier.apply(rect, DUMMY_TEXTURE)

	assert_int(rect.texture_filter).is_equal(CanvasItem.TEXTURE_FILTER_NEAREST)


func test_applyでstretch_modeがKEEP_ASPECT_COVEREDになる() -> void:
	var rect: TextureRect = auto_free(TextureRect.new())

	PixelBackdropApplier.apply(rect, DUMMY_TEXTURE)

	assert_int(rect.stretch_mode).is_equal(TextureRect.STRETCH_KEEP_ASPECT_COVERED)


func test_applyでexpand_modeがIGNORE_SIZEになる() -> void:
	var rect: TextureRect = auto_free(TextureRect.new())

	PixelBackdropApplier.apply(rect, DUMMY_TEXTURE)

	assert_int(rect.expand_mode).is_equal(TextureRect.EXPAND_IGNORE_SIZE)


func test_applyでmouse_filterがIGNOREになる() -> void:
	var rect: TextureRect = auto_free(TextureRect.new())

	PixelBackdropApplier.apply(rect, DUMMY_TEXTURE)

	assert_int(rect.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
