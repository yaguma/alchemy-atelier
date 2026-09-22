class_name UiEffects

## ui-polish Plan タスク001: 演出タスク群（002, 003, 004, 006, 007, 008, 010, 011, 014, 016, 017）が
## 共通利用するTween生成ヘルパー。duration<=0.0が渡された場合はTween.tween_property()に
## 負値を渡すとエラーになるため、maxf()で0.0に丸めてから使用する


## 既存ノードをscale 0→1でポップイン表示する
static func play_pop_in(target: Control, duration: float, ease_type: Tween.EaseType) -> Tween:
	target.scale = Vector2.ZERO
	var tween := target.create_tween()
	tween.tween_property(target, "scale", Vector2.ONE, maxf(duration, 0.0)).set_ease(ease_type)
	return tween


## targetのmodulate.aを0→1でフェードイン表示する
static func play_fade_in(target: CanvasItem, duration: float, ease_type: Tween.EaseType) -> Tween:
	target.modulate.a = 0.0
	var tween := target.create_tween()
	tween.tween_property(target, "modulate:a", 1.0, maxf(duration, 0.0)).set_ease(ease_type)
	return tween


## sourceの見た目を複製(duplicate())してoverlay_layerに乗せ、from_global(sourceの現在位置)→
## to_globalへ飛ばして完了後に複製ノードを自壊する。呼び出し元は複製後の元ノードの破棄タイミングを
## 気にしなくてよい（このAPIが複製の寿命を完結して管理する）
static func fly_ghost(
	overlay_layer: Control, source: Control, to_global_position: Vector2, duration: float
) -> Tween:
	var ghost := source.duplicate() as Control
	overlay_layer.add_child(ghost)
	ghost.global_position = source.global_position

	var tween := ghost.create_tween()
	tween.tween_property(ghost, "global_position", to_global_position, maxf(duration, 0.0))
	tween.finished.connect(ghost.queue_free)
	return tween


## targetをグレー(UiTheme.COLOR_WITHER_FADE_TARGET)へself_modulateし、透明度を0へフェードしてから自壊する
static func play_wither_fade(target: Control, duration: float) -> Tween:
	target.self_modulate = UiTheme.COLOR_WITHER_FADE_TARGET

	var tween := target.create_tween()
	tween.tween_property(target, "modulate:a", 0.0, maxf(duration, 0.0))
	tween.finished.connect(target.queue_free)
	return tween


## ProgressBar.valueをtween_property()で滑らかにto_valueへ変化させる
static func animate_progress_value(bar: ProgressBar, to_value: float, duration: float) -> Tween:
	var tween := bar.create_tween()
	tween.tween_property(bar, "value", to_value, maxf(duration, 0.0))
	return tween


## targetのself_modulateをcolorへ→元の色へ、を往復させるパルス演出
## （特性発現ハイライト・指定合致キラキラで共用）
static func play_highlight_pulse(target: CanvasItem, color: Color, duration: float) -> Tween:
	var original_color: Color = target.self_modulate
	var half_duration := maxf(duration, 0.0) / 2.0

	var tween := target.create_tween()
	tween.tween_property(target, "self_modulate", color, half_duration)
	tween.tween_property(target, "self_modulate", original_color, half_duration)
	return tween
