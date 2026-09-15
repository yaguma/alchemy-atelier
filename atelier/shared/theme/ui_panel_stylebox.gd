class_name UiPanelStyleBox
extends StyleBox

## 角丸パネル用StyleBox。縦グラデーション塗り・縁取り・内側ハイライト/シャドウ帯・
## 外側ドロップシャドウを1つのStyleBoxで表現する（ボタン/カードStyleBoxの描画基盤）。

const CORNER_ARC_SEGMENTS := 8  # 🟡 1コーナーあたりの円弧分割数。滑らかさとポリゴン頂点数のバランスで暫定決定

@export var corner_radius: int = 10  # 🟡 design-guide.md未確定のため暫定値
@export var border_width: int = 2  # 🟡
@export var border_color: Color = Color.WHITE
@export var gradient_top_color: Color = Color.WHITE
@export var gradient_bottom_color: Color = Color.WHITE
@export var highlight_color: Color = Color(1, 1, 1, 0.75)  # 🟡 上端ハイライトのアルファ
@export var inner_shadow_color: Color = Color(0, 0, 0, 0.3)  # 🟡 下端の凹み影のアルファ
@export var draw_outer_shadow: bool = true
@export var outer_shadow_color: Color = Color(0, 0, 0, 0.16)  # 🟡
@export var outer_shadow_size: int = 5  # 🟡


# 🔴 StyleBoxはControl._draw()と異なりdraw_polygon()等の高レベルAPIを使えないため、
# RenderingServer.canvas_item_add_polygon()を直接呼ぶ。描画順序: 外側ドロップシャドウ→
# 縁取り→内側グラデーション本体→上端ハイライト帯→下端シャドウ帯
func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	if draw_outer_shadow:
		var shadow_rect := rect.grow(float(outer_shadow_size))
		_add_uniform_polygon(to_canvas_item, shadow_rect, outer_shadow_color, float(corner_radius))

	_add_uniform_polygon(to_canvas_item, rect, border_color, float(corner_radius))

	var inner_rect := rect.grow(-float(border_width))
	var inner_radius := maxf(float(corner_radius) - float(border_width), 0.0)
	_add_gradient_polygon(to_canvas_item, inner_rect, inner_radius)

	_add_highlight_and_shadow_bands(to_canvas_item, inner_rect)


# 🔵 StyleBoxの既定オーバーライド。border_width分の余白を最小サイズとして返す
func _get_minimum_size() -> Vector2:
	return Vector2(border_width * 2, border_width * 2)


func _add_uniform_polygon(to_canvas_item: RID, rect: Rect2, color: Color, radius: float) -> void:
	var points := _build_rounded_rect_points(rect, radius)
	RenderingServer.canvas_item_add_polygon(to_canvas_item, points, PackedColorArray([color]))


func _add_gradient_polygon(to_canvas_item: RID, rect: Rect2, radius: float) -> void:
	var points := _build_rounded_rect_points(rect, radius)
	var height := maxf(rect.size.y, 0.001)
	var colors := PackedColorArray()
	for point in points:
		var ratio := clampf((point.y - rect.position.y) / height, 0.0, 1.0)
		colors.append(gradient_top_color.lerp(gradient_bottom_color, ratio))
	RenderingServer.canvas_item_add_polygon(to_canvas_item, points, colors)


func _add_highlight_and_shadow_bands(to_canvas_item: RID, inner_rect: Rect2) -> void:
	var band_height := minf(inner_rect.size.y * 0.25, 6.0)
	if band_height <= 0.0:
		return

	var highlight_rect := Rect2(inner_rect.position, Vector2(inner_rect.size.x, band_height))
	_add_uniform_polygon(to_canvas_item, highlight_rect, highlight_color, 0.0)

	var shadow_band_position := inner_rect.position + Vector2(0.0, inner_rect.size.y - band_height)
	var shadow_band_rect := Rect2(shadow_band_position, Vector2(inner_rect.size.x, band_height))
	_add_uniform_polygon(to_canvas_item, shadow_band_rect, inner_shadow_color, 0.0)


# 🔴 角丸ポリゴン頂点計算。ユニットテスト用に副作用なしのstatic funcとして独立させてある。
# radiusはrectの短辺の半分にクランプし、0以下なら単純な4角形（角丸なし）を返す
static func _build_rounded_rect_points(rect: Rect2, radius: float) -> PackedVector2Array:
	var max_radius := minf(rect.size.x, rect.size.y) * 0.5
	var clamped_radius := clampf(radius, 0.0, max_radius)
	if clamped_radius <= 0.0:
		return PackedVector2Array(
			[
				rect.position,
				rect.position + Vector2(rect.size.x, 0.0),
				rect.position + rect.size,
				rect.position + Vector2(0.0, rect.size.y),
			]
		)

	var corner_centers: Array[Vector2] = [
		rect.position + Vector2(clamped_radius, clamped_radius),
		rect.position + Vector2(rect.size.x - clamped_radius, clamped_radius),
		rect.position + Vector2(rect.size.x - clamped_radius, rect.size.y - clamped_radius),
		rect.position + Vector2(clamped_radius, rect.size.y - clamped_radius),
	]
	var corner_start_degrees: Array[float] = [180.0, 270.0, 0.0, 90.0]

	var points := PackedVector2Array()
	for corner_index in range(corner_centers.size()):
		var center := corner_centers[corner_index]
		var start_deg := corner_start_degrees[corner_index]
		for segment in range(CORNER_ARC_SEGMENTS + 1):
			var angle_deg := start_deg + 90.0 * float(segment) / float(CORNER_ARC_SEGMENTS)
			var angle_rad := deg_to_rad(angle_deg)
			points.append(center + Vector2(cos(angle_rad), sin(angle_rad)) * clamped_radius)
	return points
