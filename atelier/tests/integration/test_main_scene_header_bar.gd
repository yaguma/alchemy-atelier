extends GdUnitTestSuite

## コードレビュー指摘対応: RankHud/TabBarをそれぞれ固定offset_top/offset_bottomでMain直下に
## 絶対配置していたため、RankHudのカードパネル化・ボタン最小サイズ変更のたびに数値を
## 手動で合わせ直す必要があり、実際にTabBarとの重なりが発生していた。両者をHeaderBar
## （VBoxContainer）の子（layout_mode = 2、コンテナ管理）にしたことで、TabBarは常に
## RankHudの実際の高さに追従して配置されるようになったことを固定する回帰テスト。

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
