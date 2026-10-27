extends GdUnitTestSuite

## ForwardingControl（shared/ui/forwarding_control.gd）の最小サイズ転送の振る舞いを固定する。
## 各ラッパー（PlantSlotView等）のテストは個別画面の文脈で検証しているため、ここでは
## 基底クラス自体の境界条件（複数対象・null対象・再バインド・解放済み対象）を検証する。


func _make_wrapper() -> ForwardingControl:
	var wrapper: ForwardingControl = auto_free(ForwardingControl.new())
	add_child(wrapper)
	return wrapper


func _make_target(wrapper: ForwardingControl, min_size: Vector2) -> Control:
	var target := Control.new()
	target.custom_minimum_size = min_size
	wrapper.add_child(target)
	return target


func test_複数対象の各軸の最大値を最小サイズとして報告する() -> void:
	var wrapper := _make_wrapper()
	var wide := _make_target(wrapper, Vector2(100, 10))
	var tall := _make_target(wrapper, Vector2(20, 80))

	wrapper._bind_minimum_size_forward([wide, tall])

	assert_vector(wrapper.get_combined_minimum_size()).is_equal(Vector2(100, 80))


func test_対象が空配列なら最小サイズは0になる() -> void:
	var wrapper := _make_wrapper()

	wrapper._bind_minimum_size_forward([])

	assert_vector(wrapper.get_combined_minimum_size()).is_equal(Vector2.ZERO)


func test_nullの対象は無視される() -> void:
	var wrapper := _make_wrapper()
	var target := _make_target(wrapper, Vector2(40, 30))

	wrapper._bind_minimum_size_forward([null, target])

	assert_vector(wrapper.get_combined_minimum_size()).is_equal(Vector2(40, 30))


func test_対象の最小サイズ変化がラッパーへ伝播する() -> void:
	var wrapper := _make_wrapper()
	var target := _make_target(wrapper, Vector2(10, 10))
	wrapper._bind_minimum_size_forward([target])

	target.custom_minimum_size = Vector2(10, 60)

	assert_vector(wrapper.get_combined_minimum_size()).is_equal(Vector2(10, 60))


func test_再バインド時に旧対象の購読が解除される() -> void:
	var wrapper := _make_wrapper()
	var old_target := _make_target(wrapper, Vector2(10, 10))
	var new_target := _make_target(wrapper, Vector2(50, 50))
	wrapper._bind_minimum_size_forward([old_target])

	wrapper._bind_minimum_size_forward([new_target])

	var handler := wrapper._on_forward_target_minimum_size_changed
	assert_bool(old_target.minimum_size_changed.is_connected(handler)).is_false()
	assert_vector(wrapper.get_combined_minimum_size()).is_equal(Vector2(50, 50))


func test_解放済みの対象は無視される() -> void:
	var wrapper := _make_wrapper()
	var freed_target := _make_target(wrapper, Vector2(200, 200))
	var alive_target := _make_target(wrapper, Vector2(30, 20))
	wrapper._bind_minimum_size_forward([freed_target, alive_target])

	freed_target.free()
	wrapper.update_minimum_size()

	assert_vector(wrapper.get_combined_minimum_size()).is_equal(Vector2(30, 20))
