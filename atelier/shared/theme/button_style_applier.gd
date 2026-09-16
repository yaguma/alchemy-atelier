class_name ButtonStyleApplier


## 🔵 Godot Buttonのテーマスロット名（normal/hover/pressed/disabled/focus）標準API仕様に対応。
## focusはnormalと同じStyleBoxを流用する（フォーカスリングの独自デザインは本タスクのスコープ外）
## 🔴 2026-09-16追加: フォントサイズ・文字色のoverrideも本関数で一括適用する。実機確認で
## 「文字が小さい」「明るい塗りのボタンで白文字が読めない」の指摘を受けて追加した
static func apply_button_style(button: Button, variant: UiTheme.ButtonVariant) -> void:
	button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	button.add_theme_font_size_override("font_size", UiTheme.BUTTON_FONT_SIZE)
	var text_color := UiTheme.get_button_text_color(variant)
	button.add_theme_color_override("font_color", text_color)
	button.add_theme_color_override("font_hover_color", text_color)
	button.add_theme_color_override("font_pressed_color", text_color)
	# focusはnormalと同じStyleBoxを流用するため、文字色も同じ色に揃える
	button.add_theme_color_override("font_focus_color", text_color)
	# disabledは背景StyleBoxをBUTTON_DISABLED_ALPHAで半透明化しているため、文字色も同じアルファに揃える
	button.add_theme_color_override(
		"font_disabled_color",
		Color(text_color.r, text_color.g, text_color.b, UiTheme.BUTTON_DISABLED_ALPHA)
	)
	var normal_style := UiTheme.make_button_stylebox(variant, UiTheme.ButtonState.NORMAL)
	button.add_theme_stylebox_override("normal", normal_style)
	button.add_theme_stylebox_override("focus", normal_style)
	button.add_theme_stylebox_override(
		"hover", UiTheme.make_button_stylebox(variant, UiTheme.ButtonState.HOVER)
	)
	button.add_theme_stylebox_override(
		"pressed", UiTheme.make_button_stylebox(variant, UiTheme.ButtonState.PRESSED)
	)
	button.add_theme_stylebox_override(
		"disabled", UiTheme.make_button_stylebox(variant, UiTheme.ButtonState.DISABLED)
	)
