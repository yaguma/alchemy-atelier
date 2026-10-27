extends GdUnitTestSuite

## コードレビュー指摘対応: RankHud/TabBarをそれぞれ固定offset_top/offset_bottomでMain直下に
## 絶対配置していたため、RankHudのカードパネル化・ボタン最小サイズ変更のたびに数値を
## 手動で合わせ直す必要があり、実際にTabBarとの重なりが発生していた。両者をHeaderBar
## （VBoxContainer）の子（layout_mode = 2、コンテナ管理）にしたことで、TabBarは常に
## RankHudの実際の高さに追従して配置されるようになったことを固定する回帰テスト。
##
## 追記: HeaderBar自体はMain直下に他の4画面（GardenScreen等）と並ぶ兄弟ノードとして
## 絶対配置されており、ノード順（HeaderBarが4画面より後）により常に手前に描画されるだけで、
## 4画面側はHeaderBarの高さぶんの余白を確保していなかった。そのためHeaderBarが各画面自身の
## 最上段（庭のターン終了/ショップボタン、調合のレシピ選択等）に重なって隠す不具合があった。
## HeaderBarと4画面をRootLayout（VBoxContainer）の子にし、4画面をHeaderBarの下に並ぶ
## ScreenLayer（size_flags_vertical=3で残り領域いっぱいに広がるControl）へ移すことで、
## HeaderBarが確保する高さぶん4画面側が自動的に押し下げられるようにした。その回帰テスト。

const MAIN_SCENE_PATH := "res://scenes/main.tscn"


func before_test() -> void:
	GameState.reset_for_test()


func _make_main() -> MainScene:
	var runner := scene_runner(MAIN_SCENE_PATH)
	return runner.scene() as MainScene


# 正常系


func test_RankHudとTabBarが共にHeaderBarの子である() -> void:
	var main := _make_main()

	var rank_hud := main.find_child("RankHud", true, false) as Control
	var tab_bar := main.find_child("TabBar", true, false) as Control

	assert_object(rank_hud.get_parent()).is_equal(tab_bar.get_parent())
	assert_str(rank_hud.get_parent().name).is_equal("HeaderBar")


func test_HeaderBarがVBoxContainerである() -> void:
	var main := _make_main()

	var header_bar := main.find_child("HeaderBar", true, false)

	assert_object(header_bar).is_instanceof(VBoxContainer)


func test_TabBarがRankHudより後の子としてHeaderBar内に並んでいる() -> void:
	var main := _make_main()

	var rank_hud := main.find_child("RankHud", true, false) as Control
	var tab_bar := main.find_child("TabBar", true, false) as Control

	assert_int(tab_bar.get_index()).is_greater(rank_hud.get_index())


func test_レイアウト確定後にTabBarのY座標がRankHudの高さ以上になり重ならない() -> void:
	var main := _make_main()
	await await_idle_frame()

	var rank_hud := main.find_child("RankHud", true, false) as Control
	var tab_bar := main.find_child("TabBar", true, false) as Control

	assert_float(tab_bar.global_position.y).is_greater_equal(
		rank_hud.global_position.y + rank_hud.size.y
	)


func test_レイアウト確定後にScreenLayerのY座標がHeaderBarの高さ以上になり重ならない() -> void:
	var main := _make_main()
	await await_idle_frame()

	var header_bar := main.find_child("HeaderBar", true, false) as Control
	var screen_layer := main.find_child("ScreenLayer", true, false) as Control

	assert_float(screen_layer.global_position.y).is_greater_equal(
		header_bar.global_position.y + header_bar.size.y
	)


func test_GardenScreenがScreenLayerの子であり4画面がHeaderBarの兄弟ではない() -> void:
	var main := _make_main()

	var garden_screen := main.find_child("GardenScreen", true, false) as Control
	var screen_layer := main.find_child("ScreenLayer", true, false) as Control

	assert_object(garden_screen.get_parent()).is_equal(screen_layer)
