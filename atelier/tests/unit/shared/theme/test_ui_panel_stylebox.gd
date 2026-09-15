extends GdUnitTestSuite


func test_最小サイズがborder_widthの2倍を返す() -> void:
	var style := UiPanelStyleBox.new()
	style.border_width = 3

	var result := style._get_minimum_size()

	assert_vector(result).is_equal(Vector2(6, 6))


func test_角丸半径0かつ極小矩形でもエラーなく完了する() -> void:
	var rect := Rect2(0, 0, 4, 4)

	var points := UiPanelStyleBox._build_rounded_rect_points(rect, 0.0)

	assert_int(points.size()).is_equal(4)


func test_頂点配列が矩形をouter_shadow_size分広げた範囲内に収まる() -> void:
	var rect := Rect2(10, 20, 100, 60)
	var outer_shadow_size := 5
	var bounds := rect.grow(float(outer_shadow_size))

	var points := UiPanelStyleBox._build_rounded_rect_points(rect, 12.0)

	for point in points:
		assert_bool(bounds.has_point(point)).is_true()


func test_角丸半径が矩形短辺の半分にクランプされる() -> void:
	var rect := Rect2(0, 0, 10, 6)

	var points := UiPanelStyleBox._build_rounded_rect_points(rect, 100.0)

	for point in points:
		assert_bool(_is_on_rect_boundary(point, rect)).is_true()


func _is_on_rect_boundary(point: Vector2, rect: Rect2) -> bool:
	var epsilon := 0.001
	var within_x := (
		point.x >= rect.position.x - epsilon and point.x <= rect.position.x + rect.size.x + epsilon
	)
	var within_y := (
		point.y >= rect.position.y - epsilon and point.y <= rect.position.y + rect.size.y + epsilon
	)
	return within_x and within_y
