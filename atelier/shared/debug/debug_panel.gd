class_name DebugPanel
extends Control

## デバッグビルド限定で画面上に常設表示するQA専用操作パネル（ゴールド付与/ノルマ即達成/
## 次ランクへジャンプの3ボタン）。debug-playtest-support Plan タスク002。
## 🔵 godot-debug-tools.md「将来検討: 開発用デバッグコンソール」節の設計方針
## （OS.is_debug_build()ガード必須）に準拠する。
## 🔵 ボタン自体はdisabled条件を一切持たない。押下可否の実際の判定は
## GameState側（task 001のGameStateDebugDelegate.guard()等）にすべて委譲されており、
## 本パネルは単にGameStateのデバッグAPIを呼び出すだけの薄い結線に徹する。

@onready var _add_gold_button: Button = %AddGoldButton
@onready var _force_end_turn_button: Button = %ForceEndTurnButton
@onready var _jump_rank_button: Button = %JumpRankButton


## リリースビルドでは即座にqueue_free()し、以降の@onready解決・シグナル接続を一切行わない
func _ready() -> void:
	if not OS.is_debug_build():
		queue_free()
		return
	_add_gold_button.pressed.connect(_on_add_gold_pressed)
	_force_end_turn_button.pressed.connect(_on_force_end_turn_pressed)
	_jump_rank_button.pressed.connect(_on_jump_rank_pressed)


func _on_add_gold_pressed() -> void:
	GameState.debug_add_gold()


func _on_force_end_turn_pressed() -> void:
	GameState.debug_force_end_turn()


func _on_jump_rank_pressed() -> void:
	GameState.debug_jump_to_next_rank()


## 次ランクへボタンを返す（🔴 debug-playtest-support Plan タスク003。debug_jump_to_next_rank()は
## GameStateの内部フィールドを直接書き換えるだけでシグナルを発行しないため、MainScene側が
## RankHud.refresh()への結線に使う。RankHud.get_menu_button()と同型の公開アクセサ）
func get_jump_rank_button() -> Button:
	return _jump_rank_button
