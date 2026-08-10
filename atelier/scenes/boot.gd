class_name BootScene
extends Control

@onready var _status_label: Label = %StatusLabel


func _ready() -> void:
	_apply_theme()
	_status_label.text = "アトリエ 起動確認"
	# 🔴 Phase1では実データが無いため空配列固定。実データ検証を後続Planで実装する際はこの呼び出し箇所自体を書き換える必要がある
	if not MasterDataLoader.validate_references([]):
		push_error("マスターデータのID相互参照が解決できません")
		return
	# _ready()実行中（シーンツリー構築中）にchange_scene_to_fileを直接呼ぶと
	# "Parent node is busy adding/removing children"エラーになるためcall_deferredで遅延させる
	get_tree().change_scene_to_file.call_deferred("res://scenes/main.tscn")


func _apply_theme() -> void:
	theme = preload("res://shared/theme/main_theme.tres")
