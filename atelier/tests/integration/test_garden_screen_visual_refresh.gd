extends GdUnitTestSuite

## 庭画面のドット絵ビジュアル統合（garden-alchemy-visual-refresh Plan タスク007）を検証する。
## 🟡 既存のtest_garden_screen.gd（機能系の統合テスト）へ追記すると責務が混在するため、
## ビジュアル統合固有の検証はこの専用ファイルに分離する（008のtest_alchemy_screen_visual_refresh.gd
## と同方針）。


func before_test() -> void:
	GameState.reset_for_test()


func _make_screen() -> GardenScreen:
	var runner := scene_runner("res://features/garden/ui/garden_screen.tscn")
	return runner.scene() as GardenScreen


# 正常系


## GardenBackdropがVBoxContainerより背面（get_index()が小さい）に配置されていること。🔵
func test_GardenBackdropがVBoxContainerより背面に配置されている() -> void:
	var screen := _make_screen()

	var backdrop := screen.find_child("GardenBackdrop", false, false)
	var vbox := screen.find_child("VBoxContainer", false, false)

	assert_object(backdrop).is_not_null()
	assert_object(vbox).is_not_null()
	assert_int(backdrop.get_index()).is_less(vbox.get_index())


func test_ターン終了ボタンにニアレストフィルタが設定されている() -> void:
	var screen := _make_screen()

	var button := screen.find_child("EndTurnButton", true, false) as Button

	assert_int(button.texture_filter).is_equal(CanvasItem.TEXTURE_FILTER_NEAREST)


func test_ショップボタンにニアレストフィルタが設定されている() -> void:
	var screen := _make_screen()

	var button := screen.find_child("ShopButton", true, false) as Button

	assert_int(button.texture_filter).is_equal(CanvasItem.TEXTURE_FILTER_NEAREST)


## コードレビュー指摘対応: alchemy_screen.gdのEndTurnButton（同じ「ターンを終了する」操作、
## design-guide.mdのボタン表「日終了・破棄→デンジャー」に対応）とバリアントが食い違っていたため、
## DANGERへ統一したことを固定する回帰テスト
func test_ターン終了ボタンがDANGERバリアントになっている() -> void:
	var screen := _make_screen()

	var button := screen.find_child("EndTurnButton", true, false) as Button
	var style: StyleBoxTexture = button.get_theme_stylebox("normal")

	assert_object(style.texture).is_equal(UiTheme.BUTTON_TEXTURE_DANGER)
