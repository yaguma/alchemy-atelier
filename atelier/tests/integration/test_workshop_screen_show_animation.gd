extends GdUnitTestSuite

## ui-polish Plan タスク017: 工房画面表示時のフェードイン演出
## （ui-design/screens/workshop-shop.md L69）を検証する。
## play_show_animation()はvisible=trueへの変更を行わず（MainScene._apply_visible_phase()側で
## 完了済みのため）、modulate.aのみ0→1へフェードする薄いラッパーである。

const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const WORKSHOP_SCREEN_PATH := "res://features/workshop/ui/workshop_screen.tscn"


func before_test() -> void:
	GameState.reset_for_test()


func _make_main() -> MainScene:
	var runner := scene_runner(MAIN_SCENE_PATH)
	return runner.scene() as MainScene


func _make_workshop_screen() -> WorkshopScreen:
	var runner := scene_runner(WORKSHOP_SCREEN_PATH)
	return runner.scene() as WorkshopScreen


func _find_workshop_screen(main: MainScene) -> WorkshopScreen:
	return main.find_child("WorkshopScreen", true, false) as WorkshopScreen


func _find_gold_label(screen: WorkshopScreen) -> Label:
	return screen.find_child("GoldLabel", true, false) as Label


func _max_show_duration() -> float:
	return UiTheme.ANIM_DURATION_FADE_SCREEN + 0.2


# 正常系


func test_play_show_animation呼び出し直後にmodulateが1未満へ変化し始める() -> void:
	var screen := _make_workshop_screen()
	screen.modulate.a = 1.0

	screen.play_show_animation()

	assert_float(screen.modulate.a).is_less(1.0)


func test_play_show_animation完了後にmodulateが完全に不透明へ収束する() -> void:
	var screen := _make_workshop_screen()
	screen.modulate.a = 1.0

	screen.play_show_animation()
	await get_tree().create_timer(_max_show_duration()).timeout

	assert_float(screen.modulate.a).is_equal_approx(1.0, 0.01)


func test_play_show_animationはvisibleを変更しない() -> void:
	var screen := _make_workshop_screen()
	screen.visible = false

	screen.play_show_animation()

	assert_bool(screen.visible).is_false()


func test_workshopフェーズへ遷移するとworkshop_screenのmodulateが1未満へ変化し始める() -> void:
	var main := _make_main()
	var workshop_screen := _find_workshop_screen(main)
	workshop_screen.modulate.a = 1.0

	GameState.set_phase(&"workshop")

	assert_float(workshop_screen.modulate.a).is_less(1.0)
	assert_bool(workshop_screen.visible).is_true()


func test_workshopフェーズへ遷移するとrefreshによる表示内容が演出完了前から正しい() -> void:
	GameState.load_workshop_master_data()
	GameState._set_gold_for_test(1234)
	var main := _make_main()
	var workshop_screen := _find_workshop_screen(main)

	GameState.set_phase(&"workshop")

	assert_str(_find_gold_label(workshop_screen).text).is_equal("1234 G")


func test_他画面からworkshopへ遷移した直後の初回表示でも正しくフェードインする() -> void:
	var main := _make_main()
	GameState.set_phase(&"alchemy")
	var workshop_screen := _find_workshop_screen(main)
	workshop_screen.modulate.a = 1.0

	GameState.set_phase(&"workshop")

	assert_float(workshop_screen.modulate.a).is_less(1.0)


# 境界値


func test_同じworkshopフェーズへ連続して切り替わってもクラッシュしない() -> void:
	var main := _make_main()
	GameState.set_phase(&"workshop")
	var workshop_screen := _find_workshop_screen(main)

	GameState.set_phase(&"garden")
	GameState.set_phase(&"workshop")
	await get_tree().create_timer(_max_show_duration()).timeout

	assert_float(workshop_screen.modulate.a).is_equal_approx(1.0, 0.01)
