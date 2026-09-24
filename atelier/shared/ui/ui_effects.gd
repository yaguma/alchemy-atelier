class_name UiEffects

## ui-polish Plan タスク001: 演出タスク群（002, 003, 004, 006, 007, 008, 010, 011, 014, 016, 017）が
## 共通利用するTween生成ヘルパー。duration<=0.0が渡された場合はTween.tween_property()に
## 負値を渡すとエラーになるため、maxf()で0.0に丸めてから使用する

## 🔴 コードレビュー指摘対応: play_pop_in/play_fade_in/animate_progress_value/play_highlight_pulseは
## いずれも永続的なノード（ゴールドラベル・ノルマバー等）に対して繰り返し呼ばれうる。短時間に
## 連続で呼ばれると前回のTweenが生存したまま新しいTweenが同じプロパティを奪い合い、表示が
## ちらつく/逆戻りする競合が起きていた。target単位でmeta経由に直前のTweenを追跡し、新規Tween
## 生成前に必ずkillする。fly_ghost()とplay_wither_fade()は使い捨てノード（複製後にqueue_free()
## される）に対して動作するため、この仕組みの対象外とする。
## kill_active_tween()/track_active_tween()はpublicにし、上記4関数でカバーできない独自の
## tween_method()等を組む呼び出し元（例: WorkshopScreen._animate_gold_countdown()）からも
## 同じ仕組みに乗せられるようにする
const _ACTIVE_TWEEN_META_KEY := &"_ui_effects_active_tween"


## targetに紐づく直前のアクティブなTweenがあればkillする
static func kill_active_tween(target: Object) -> void:
	if target.has_meta(_ACTIVE_TWEEN_META_KEY):
		var prev: Variant = target.get_meta(_ACTIVE_TWEEN_META_KEY)
		if prev is Tween and (prev as Tween).is_valid():
			(prev as Tween).kill()


## targetに紐づく直前のアクティブなTweenとしてtweenを記録する
static func track_active_tween(target: Object, tween: Tween) -> void:
	target.set_meta(_ACTIVE_TWEEN_META_KEY, tween)


## 既存ノードをscale 0→1でポップイン表示する
static func play_pop_in(target: Control, duration: float, ease_type: Tween.EaseType) -> Tween:
	kill_active_tween(target)
	target.scale = Vector2.ZERO
	var tween := target.create_tween()
	tween.tween_property(target, "scale", Vector2.ONE, maxf(duration, 0.0)).set_ease(ease_type)
	track_active_tween(target, tween)
	return tween


## targetのmodulate.aを0→1でフェードイン表示する
static func play_fade_in(target: CanvasItem, duration: float, ease_type: Tween.EaseType) -> Tween:
	kill_active_tween(target)
	target.modulate.a = 0.0
	var tween := target.create_tween()
	tween.tween_property(target, "modulate:a", 1.0, maxf(duration, 0.0)).set_ease(ease_type)
	track_active_tween(target, tween)
	return tween


## sourceの見た目を複製(duplicate())してoverlay_layerに乗せ、from_global_position→
## to_global_positionへ飛ばして完了後に複製ノードを自壊する。呼び出し元は複製後の元ノードの破棄
## タイミングを気にしなくてよい（このAPIが複製の寿命を完結して管理する）。
## 🔴 from_global_positionは呼び出し元が明示的に渡す契約。source.global_positionを内部で読むと、
## sourceが既にシーンツリーから外された（親を失った）状態ではローカルpositionと同値になり、
## 画面上の実位置とズレるため、sourceがまだ有効な祖先チェーンを持つうちに呼び出し元が取得する
static func fly_ghost(
	overlay_layer: Control,
	source: Control,
	from_global_position: Vector2,
	to_global_position: Vector2,
	duration: float
) -> Tween:
	var ghost := source.duplicate() as Control
	overlay_layer.add_child(ghost)
	ghost.global_position = from_global_position

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
	kill_active_tween(bar)
	var tween := bar.create_tween()
	tween.tween_property(bar, "value", to_value, maxf(duration, 0.0))
	track_active_tween(bar, tween)
	return tween


## targetのself_modulateをcolorへ→元の色へ、を往復させるパルス演出
## （特性発現ハイライト・指定合致キラキラで共用）
static func play_highlight_pulse(target: CanvasItem, color: Color, duration: float) -> Tween:
	kill_active_tween(target)
	var original_color: Color = target.self_modulate
	var half_duration := maxf(duration, 0.0) / 2.0

	var tween := target.create_tween()
	tween.tween_property(target, "self_modulate", color, half_duration)
	tween.tween_property(target, "self_modulate", original_color, half_duration)
	track_active_tween(target, tween)
	return tween
