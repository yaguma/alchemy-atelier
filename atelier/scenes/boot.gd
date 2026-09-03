class_name BootScene
extends Control

# 🔵 FR-001。起動直後の遷移先はタイトル画面。スロット選択（「続きから／新規開始」）は
# TitleScreenの「はじめる」以降に移り、マスターデータロード（MainScene._enter_tree()）
# より前に確定する点は変わらない。復元自体はMainScene側のSaveService.apply_pending_restore()が行う
const NEXT_SCENE_PATH := "res://features/title/ui/title_screen.tscn"

# 🟡 遷移を実際に実行するか。統合テストではシーン差し替えがGdUnit4のテストランナー自身の
# current_sceneを巻き込むため、テスト側でfalseにして遷移要求の有無のみを検証する
# （slot_select_screen.gdのscene_transition_enabledと同方針）
var scene_transition_enabled: bool = true

var _requested_next_scene_path: String = ""

@onready var _status_label: Label = %StatusLabel


func _ready() -> void:
	_apply_theme()
	_status_label.text = "アトリエ 起動確認"
	# 🔴 Phase1では実データが無いため空配列固定。実データ検証を後続Planで実装する際はこの呼び出し箇所自体を書き換える必要がある
	if not MasterDataLoader.validate_references([]):
		push_error("マスターデータのID相互参照が解決できません")
		return
	_requested_next_scene_path = NEXT_SCENE_PATH
	if not scene_transition_enabled:
		return
	# _ready()実行中（シーンツリー構築中）にchange_scene_to_fileを直接呼ぶと
	# "Parent node is busy adding/removing children"エラーになるためcall_deferredで遅延させる
	get_tree().change_scene_to_file.call_deferred(NEXT_SCENE_PATH)


## 🔵 遷移先として要求されたシーンパスを返す（テスト用の観測点）。未要求なら空文字列。
func get_requested_next_scene_path() -> String:
	return _requested_next_scene_path


func _apply_theme() -> void:
	theme = preload("res://shared/theme/main_theme.tres")
