extends GdUnitTestSuite

## BootSceneの遷移先決定を検証する。起動直後のトップ画面はTitleScreenであり、
## 「つづきから／新規」の分岐はTitleScreen以降（SlotSelectScreen）の責務となる。
## 起動→スロット選択→復元のE2E結線はtest_boot_to_slot_select_flow.gdがカバーする。

const BOOT_SCENE_PATH := "res://scenes/boot.tscn"
const TITLE_SCENE_PATH := "res://features/title/ui/title_screen.tscn"


func before_test() -> void:
	GameState.reset_for_test()


func after_test() -> void:
	GameState.reset_for_test()


# 正常系


func test_BootSceneはタイトル画面への遷移を要求する() -> void:
	var boot := _make_boot()

	assert_str(boot.get_requested_next_scene_path()).is_equal(TITLE_SCENE_PATH)


func test_BootSceneの遷移先シーンのルートはTitleScreenである() -> void:
	var runner := scene_runner(BootScene.NEXT_SCENE_PATH)

	assert_object(runner.scene() as TitleScreen).is_not_null()


# 異常系


## マスターデータ検証に失敗した場合、BootSceneは遷移を要求せず早期リターンする。
## 検証入力は_ready()内で空配列固定のためテストから失敗させる差し込み口がなく、
## ここでは「_ready()を通していないBootSceneは遷移を要求しない」ことで
## 遷移未要求時の観測値（空文字列）が成立することを確認する
func test_ready前のBootSceneは遷移を要求しない() -> void:
	var boot := auto_free(load(BOOT_SCENE_PATH).instantiate()) as BootScene

	assert_str(boot.get_requested_next_scene_path()).is_empty()


# 境界値


func test_遷移が無効でも遷移先パスの決定自体は行われる() -> void:
	var boot := _make_boot()

	assert_bool(boot.scene_transition_enabled).is_false()
	assert_str(boot.get_requested_next_scene_path()).is_equal(BootScene.NEXT_SCENE_PATH)


# ヘルパー


## BootSceneはscene_runner()で起動すると_ready()内のchange_scene_to_fileが
## GdUnit4のテストランナー自身のcurrent_sceneを差し替えてしまうため、
## 手動インスタンス化して遷移抑止フラグを立ててからツリーへ追加する
func _make_boot() -> BootScene:
	var boot := auto_free(load(BOOT_SCENE_PATH).instantiate()) as BootScene
	boot.scene_transition_enabled = false
	add_child(boot)
	return boot
