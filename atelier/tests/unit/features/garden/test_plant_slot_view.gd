extends GdUnitTestSuite

const PlantSlotViewScene = preload("res://features/garden/ui/plant_slot_view.tscn")


func _make_view() -> PlantSlotView:
	var view: PlantSlotView = auto_free(PlantSlotViewScene.instantiate())
	add_child(view)
	return view


func _make_master(maturity_turns: int, death_grace_turns: int) -> SeedMaster:
	var master := SeedMaster.new()
	master.id = &"seed_herb"
	master.name = "薬草の種"
	master.maturity_turns = maturity_turns
	master.death_grace_turns = death_grace_turns
	return master


func _find_label(view: PlantSlotView, node_name: String) -> Label:
	return view.find_child(node_name) as Label


func _find_button(view: PlantSlotView, node_name: String) -> Button:
	return view.find_child(node_name) as Button


# 正常系


func test_setup_emptyで空き状態の色とアイコンとテキストが表示される() -> void:
	var view := _make_view()

	view.setup_empty(0)

	assert_int(view.get_status()).is_equal(PlantSlotView.Status.EMPTY)
	assert_int(view.get_slot_index()).is_equal(0)
	assert_str(_find_label(view, "StatusLabel").text).is_equal(
		PlantSlotView.status_text(PlantSlotView.Status.EMPTY)
	)
	assert_str(_find_label(view, "StatusIcon").text).is_equal(
		PlantSlotView.status_icon(PlantSlotView.Status.EMPTY)
	)
	assert_str(_find_label(view, "StatusLabel").text).is_not_empty()
	assert_str(_find_label(view, "StatusIcon").text).is_not_empty()


func test_未成熟のPlantStateをsetupすると生育中状態で表示される() -> void:
	var view := _make_view()
	var plant := PlantState.new(1, &"seed_herb", 1, false)

	view.setup(plant, _make_master(3, 2))

	assert_int(view.get_status()).is_equal(PlantSlotView.Status.GROWING)
	assert_int(view.get_slot_index()).is_equal(1)
	assert_str(_find_label(view, "StatusLabel").text).is_equal(
		PlantSlotView.status_text(PlantSlotView.Status.GROWING)
	)


func test_成熟済みかつ枯死していないPlantStateは収穫可能状態で表示され収穫ボタンが有効になる() -> void:
	var view := _make_view()
	var plant := PlantState.new(2, &"seed_herb", 3, true)

	view.setup(plant, _make_master(3, 4))

	assert_int(view.get_status()).is_equal(PlantSlotView.Status.HARVESTABLE)
	assert_bool(view.is_harvest_enabled()).is_true()
	assert_bool(_find_button(view, "HarvestButton").disabled).is_false()


func test_収穫ボタン押下でharvest_pressedがスロット番号付きで発行される() -> void:
	var view := _make_view()
	var plant := PlantState.new(3, &"seed_herb", 3, true)
	view.setup(plant, _make_master(3, 4))
	monitor_signals(view)

	_find_button(view, "HarvestButton").pressed.emit()

	await assert_signal(view).is_emitted("harvest_pressed", [3])


func test_待機ボタン押下でwait_pressedがスロット番号付きで発行される() -> void:
	var view := _make_view()
	var plant := PlantState.new(4, &"seed_herb", 3, true)
	view.setup(plant, _make_master(3, 4))
	monitor_signals(view)

	_find_button(view, "WaitButton").pressed.emit()

	await assert_signal(view).is_emitted("wait_pressed", [4])


func test_4状態それぞれに固有の色とアイコンとテキストが割り当てられている() -> void:
	var statuses: Array[PlantSlotView.Status] = [
		PlantSlotView.Status.EMPTY,
		PlantSlotView.Status.GROWING,
		PlantSlotView.Status.HARVESTABLE,
		PlantSlotView.Status.WITHER_WARNING,
	]
	var colors: Array[Color] = []
	var icons: Array[String] = []
	var texts: Array[String] = []
	for status in statuses:
		colors.append(PlantSlotView.status_color(status))
		icons.append(PlantSlotView.status_icon(status))
		texts.append(PlantSlotView.status_text(status))

	# NFR-201: 色だけに依存せずアイコン・テキストでも4状態を判別できること
	assert_int(_unique_count(colors)).is_equal(4)
	assert_int(_unique_count(icons)).is_equal(4)
	assert_int(_unique_count(texts)).is_equal(4)


# 異常系


func test_空き状態では収穫ボタンが無効化されている() -> void:
	var view := _make_view()

	view.setup_empty(0)

	assert_bool(view.is_harvest_enabled()).is_false()
	assert_bool(_find_button(view, "HarvestButton").disabled).is_true()


func test_生育中状態では収穫ボタンが無効化されている() -> void:
	var view := _make_view()
	var plant := PlantState.new(0, &"seed_herb", 1, false)

	view.setup(plant, _make_master(3, 2))

	assert_bool(view.is_harvest_enabled()).is_false()
	assert_bool(_find_button(view, "HarvestButton").disabled).is_true()


func test_枯死済みのPlantStateは枯死警告表示かつ収穫ボタンが無効化される() -> void:
	var view := _make_view()
	# grown_turns 6 - maturity 3 = 待機3ターン > death_grace 2 のため枯死
	var plant := PlantState.new(0, &"seed_herb", 6, true)

	view.setup(plant, _make_master(3, 2))

	assert_int(view.get_status()).is_equal(PlantSlotView.Status.WITHER_WARNING)
	assert_bool(view.is_harvest_enabled()).is_false()
	assert_bool(_find_button(view, "HarvestButton").disabled).is_true()


# 境界値


func test_枯死までの残りターンが警告閾値と等しいとき枯死警告状態に切り替わる() -> void:
	var view := _make_view()
	var master := _make_master(3, 4)
	# 残り = death_grace_turns 4 - 待機ターン(6-3=3) = 1 = WITHER_WARNING_REMAINING_TURNS
	var plant := PlantState.new(
		0, &"seed_herb", 3 + 4 - GameBalance.WITHER_WARNING_REMAINING_TURNS, true
	)

	view.setup(plant, master)

	assert_int(PlantSlotView.remaining_wither_turns(plant, master)).is_equal(
		GameBalance.WITHER_WARNING_REMAINING_TURNS
	)
	assert_int(view.get_status()).is_equal(PlantSlotView.Status.WITHER_WARNING)
	# AC-010: 枯死警告状態でも収穫自体は可能であること
	assert_bool(view.is_harvest_enabled()).is_true()


func test_枯死までの残りターンが警告閾値より1多いときは収穫可能状態にとどまる() -> void:
	var view := _make_view()
	var master := _make_master(3, 4)
	var plant := PlantState.new(
		0, &"seed_herb", 3 + 4 - (GameBalance.WITHER_WARNING_REMAINING_TURNS + 1), true
	)

	view.setup(plant, master)

	assert_int(PlantSlotView.remaining_wither_turns(plant, master)).is_equal(
		GameBalance.WITHER_WARNING_REMAINING_TURNS + 1
	)
	assert_int(view.get_status()).is_equal(PlantSlotView.Status.HARVESTABLE)


func test_成熟直前と成熟時で残り生育ターン数が0未満にならない() -> void:
	var master := _make_master(3, 2)

	(
		assert_int(
			PlantSlotView.remaining_growth_turns(PlantState.new(0, &"seed_herb", 2, false), master)
		)
		. is_equal(1)
	)
	(
		assert_int(
			PlantSlotView.remaining_growth_turns(PlantState.new(0, &"seed_herb", 3, true), master)
		)
		. is_equal(0)
	)
	(
		assert_int(
			PlantSlotView.remaining_growth_turns(PlantState.new(0, &"seed_herb", 5, true), master)
		)
		. is_equal(0)
	)


func _unique_count(values: Array) -> int:
	var seen: Array = []
	for value in values:
		if not seen.has(value):
			seen.append(value)
	return seen.size()
