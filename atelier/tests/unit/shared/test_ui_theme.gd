extends GdUnitTestSuite


func test_プライマリボタンのノーマル状態がStyleBoxTextureでPRIMARYテクスチャを参照する() -> void:
	var style := UiTheme.make_button_stylebox(
		UiTheme.ButtonVariant.PRIMARY, UiTheme.ButtonState.NORMAL
	)

	assert_object(style).is_instanceof(StyleBoxTexture)
	assert_object(style.texture).is_equal(UiTheme.BUTTON_TEXTURE_PRIMARY)


func test_デンジャーボタンのノーマル状態がDANGERテクスチャを参照する() -> void:
	var style: StyleBoxTexture = UiTheme.make_button_stylebox(
		UiTheme.ButtonVariant.DANGER, UiTheme.ButtonState.NORMAL
	)

	assert_object(style.texture).is_equal(UiTheme.BUTTON_TEXTURE_DANGER)


func test_ホバー状態のmodulate_colorがノーマル状態より明るい() -> void:
	var normal_style: StyleBoxTexture = UiTheme.make_button_stylebox(
		UiTheme.ButtonVariant.PRIMARY, UiTheme.ButtonState.NORMAL
	)
	var hover_style: StyleBoxTexture = UiTheme.make_button_stylebox(
		UiTheme.ButtonVariant.PRIMARY, UiTheme.ButtonState.HOVER
	)

	assert_float(hover_style.modulate_color.v).is_greater(normal_style.modulate_color.v)


func test_プレス状態のmodulate_colorがノーマル状態より暗い() -> void:
	var normal_style: StyleBoxTexture = UiTheme.make_button_stylebox(
		UiTheme.ButtonVariant.SECONDARY, UiTheme.ButtonState.NORMAL
	)
	var pressed_style: StyleBoxTexture = UiTheme.make_button_stylebox(
		UiTheme.ButtonVariant.SECONDARY, UiTheme.ButtonState.PRESSED
	)

	assert_float(pressed_style.modulate_color.v).is_less(normal_style.modulate_color.v)


func test_ディスエーブル状態のmodulate_colorのアルファがBUTTON_DISABLED_ALPHAと一致する() -> void:
	var style: StyleBoxTexture = UiTheme.make_button_stylebox(
		UiTheme.ButtonVariant.TERTIARY, UiTheme.ButtonState.DISABLED
	)

	assert_float(style.modulate_color.a).is_equal_approx(UiTheme.BUTTON_DISABLED_ALPHA, 0.001)


func test_全バリアントでボタンスタイルボックスがnullにならない(
	variant: UiTheme.ButtonVariant,
	_test_parameters := [
		[UiTheme.ButtonVariant.PRIMARY],
		[UiTheme.ButtonVariant.SECONDARY],
		[UiTheme.ButtonVariant.DANGER],
		[UiTheme.ButtonVariant.TERTIARY],
	]
) -> void:
	var style := UiTheme.make_button_stylebox(variant, UiTheme.ButtonState.NORMAL)

	assert_object(style).is_not_null()


func test_パネルスタイルボックスがStyleBoxTextureを返す() -> void:
	var style := UiTheme.make_panel_stylebox()

	assert_object(style).is_instanceof(StyleBoxTexture)


func test_パネルスタイルボックスのテクスチャがPANEL_TEXTURE_PIXELと一致する() -> void:
	var style := UiTheme.make_panel_stylebox()

	assert_object(style.texture).is_equal(UiTheme.PANEL_TEXTURE_PIXEL)


func test_パネルスタイルボックスは2回呼び出しても同一インスタンスを返す() -> void:
	var first := UiTheme.make_panel_stylebox()
	var second := UiTheme.make_panel_stylebox()

	assert_object(first).is_same(second)


func test_パネルスタイルボックスのテクスチャマージンがPANEL_TEXTURE_MARGINと一致する() -> void:
	var style := UiTheme.make_panel_stylebox()

	# StyleBoxTexture.texture_margin_*はfloat型プロパティのため、assert_intではなくassert_floatで比較する
	assert_float(style.texture_margin_left).is_equal_approx(UiTheme.PANEL_TEXTURE_MARGIN, 0.001)
	assert_float(style.texture_margin_top).is_equal_approx(UiTheme.PANEL_TEXTURE_MARGIN, 0.001)
	assert_float(style.texture_margin_right).is_equal_approx(UiTheme.PANEL_TEXTURE_MARGIN, 0.001)
	assert_float(style.texture_margin_bottom).is_equal_approx(UiTheme.PANEL_TEXTURE_MARGIN, 0.001)


func test_パネルスタイルボックスの伸縮モードがタイルになっている() -> void:
	var style := UiTheme.make_panel_stylebox()

	assert_int(style.axis_stretch_horizontal).is_equal(StyleBoxTexture.AXIS_STRETCH_MODE_TILE)
	assert_int(style.axis_stretch_vertical).is_equal(StyleBoxTexture.AXIS_STRETCH_MODE_TILE)
