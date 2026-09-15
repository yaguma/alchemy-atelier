extends GdUnitTestSuite


func test_プライマリバリアント適用でノーマルスロットにオーバーライドが設定される() -> void:
	var button: Button = auto_free(Button.new())

	ButtonStyleApplier.apply_button_style(button, UiTheme.ButtonVariant.PRIMARY)

	assert_bool(button.has_theme_stylebox_override("normal")).is_true()


func test_プライマリバリアント適用で4状態全てにオーバーライドが設定される() -> void:
	var button: Button = auto_free(Button.new())

	ButtonStyleApplier.apply_button_style(button, UiTheme.ButtonVariant.PRIMARY)

	assert_bool(button.has_theme_stylebox_override("hover")).is_true()
	assert_bool(button.has_theme_stylebox_override("pressed")).is_true()
	assert_bool(button.has_theme_stylebox_override("disabled")).is_true()


func test_デンジャーバリアント適用でノーマルスロットのテクスチャがBUTTON_TEXTURE_DANGERと一致する() -> void:
	var button: Button = auto_free(Button.new())

	ButtonStyleApplier.apply_button_style(button, UiTheme.ButtonVariant.DANGER)

	var style: StyleBoxTexture = button.get_theme_stylebox("normal")
	assert_object(style.texture).is_equal(UiTheme.BUTTON_TEXTURE_DANGER)


func test_同じボタンへ2回適用してもエラーにならない() -> void:
	var button: Button = auto_free(Button.new())

	ButtonStyleApplier.apply_button_style(button, UiTheme.ButtonVariant.PRIMARY)
	ButtonStyleApplier.apply_button_style(button, UiTheme.ButtonVariant.SECONDARY)

	var style: StyleBoxTexture = button.get_theme_stylebox("normal")
	assert_object(style.texture).is_equal(UiTheme.BUTTON_TEXTURE_SECONDARY)


func test_バリアント適用でtexture_filterがnearestになる() -> void:
	var button: Button = auto_free(Button.new())

	ButtonStyleApplier.apply_button_style(button, UiTheme.ButtonVariant.PRIMARY)

	assert_int(button.texture_filter).is_equal(CanvasItem.TEXTURE_FILTER_NEAREST)


func test_バリアント適用でフォントサイズがBUTTON_FONT_SIZEになる() -> void:
	var button: Button = auto_free(Button.new())

	ButtonStyleApplier.apply_button_style(button, UiTheme.ButtonVariant.PRIMARY)

	assert_int(button.get_theme_font_size("font_size")).is_equal(UiTheme.BUTTON_FONT_SIZE)


func test_プライマリバリアント適用で文字色が白になる() -> void:
	var button: Button = auto_free(Button.new())

	ButtonStyleApplier.apply_button_style(button, UiTheme.ButtonVariant.PRIMARY)

	assert_object(button.get_theme_color("font_color")).is_equal(Color.WHITE)


func test_セカンダリバリアント適用で文字色がCOLOR_BUTTON_TEXT_ON_LIGHTになる() -> void:
	var button: Button = auto_free(Button.new())

	ButtonStyleApplier.apply_button_style(button, UiTheme.ButtonVariant.SECONDARY)

	assert_object(button.get_theme_color("font_color")).is_equal(UiTheme.COLOR_BUTTON_TEXT_ON_LIGHT)


func test_ターシャリバリアント適用で文字色がCOLOR_BUTTON_TEXT_ON_LIGHT_MUTEDになる() -> void:
	var button: Button = auto_free(Button.new())

	ButtonStyleApplier.apply_button_style(button, UiTheme.ButtonVariant.TERTIARY)

	assert_object(button.get_theme_color("font_color")).is_equal(
		UiTheme.COLOR_BUTTON_TEXT_ON_LIGHT_MUTED
	)
