extends GdUnitTestSuite

## 調合画面のドット絵ビジュアル統合（garden-alchemy-visual-refresh Plan タスク008）を検証する。
## 🟡 既存のtest_alchemy_screen.gd（機能系の統合テスト、900行超）へ追記すると500行ルールの
## 超過をさらに悪化させるため、ビジュアル統合固有の検証はこの専用ファイルに分離する
## （006のtest_alchemy_backdrop.gdが独立ファイル化されている前例と同方針）。


func before_test() -> void:
	GameState.reset_for_test()


func _make_screen() -> AlchemyScreen:
	var runner := scene_runner("res://features/alchemy/ui/alchemy_screen.tscn")
	return runner.scene() as AlchemyScreen


# 正常系


## AlchemyBackdropPixelがVBoxContainerより背面（get_index()が小さい）に配置されていること。🔵
func test_AlchemyBackdropPixelがVBoxContainerより背面に配置されている() -> void:
	var screen := _make_screen()

	var backdrop := screen.find_child("AlchemyBackdrop", true, false)
	var vbox := screen.find_child("VBoxContainer", false, false)

	assert_object(backdrop).is_not_null()
	assert_object(vbox).is_not_null()
	assert_int(backdrop.get_index()).is_less(vbox.get_index())


func test_調合実行ボタンにニアレストフィルタが設定されている() -> void:
	var screen := _make_screen()

	var button := screen.find_child("ExecuteButton", true, false) as Button

	assert_int(button.texture_filter).is_equal(CanvasItem.TEXTURE_FILTER_NEAREST)


func test_ターン終了ボタンにニアレストフィルタが設定されている() -> void:
	var screen := _make_screen()

	var button := screen.find_child("EndTurnButton", true, false) as Button

	assert_int(button.texture_filter).is_equal(CanvasItem.TEXTURE_FILTER_NEAREST)


func test_ショップボタンにニアレストフィルタが設定されている() -> void:
	var screen := _make_screen()

	var button := screen.find_child("ShopButton", true, false) as Button

	assert_int(button.texture_filter).is_equal(CanvasItem.TEXTURE_FILTER_NEAREST)


# 境界値


## 試験中のみ表示されるAdvanceExamTurnButtonも、非表示状態からでもスタイル自体は適用済みであること
func test_ターンを進めるボタンにも非表示中からニアレストフィルタが設定されている() -> void:
	var screen := _make_screen()

	var button := screen.find_child("AdvanceExamTurnButton", true, false) as Button

	assert_bool(button.visible).is_false()
	assert_int(button.texture_filter).is_equal(CanvasItem.TEXTURE_FILTER_NEAREST)
