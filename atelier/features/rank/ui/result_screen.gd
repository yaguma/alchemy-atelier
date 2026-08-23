class_name ResultScreen
extends Control

## 結果画面。GameState.game_over / GameState.game_cleared を自己購読し、
## クリア表示/オーバー表示を単一Control内で排他的に切り替える。
## 閉じる/次へ進むボタン・統計情報表示は実装しない（FR-402, FR-404）。

enum ResultKind { NONE, CLEAR, OVER }  # 🔵 FR-401（排他性）を型で表現

const CLEAR_MESSAGE_TEXT := "ゲームクリア"  # 🟡 文言は暫定（SCR-006の詳細設計が未作成のため）
const OVER_MESSAGE_TEXT := "ゲームオーバー"  # 🟡 同上
const INITIAL_MESSAGE_TEXT := ""  # 🟡 シグナル未発行時は結果種別未確定（AC-003境界値）

# 🔵 排他状態を保持する唯一のソース。無条件上書きだけでFR-401の排他性が成立する
var _result_kind: ResultKind = ResultKind.NONE

@onready var _result_message_label: Label = %ResultMessageLabel


func _ready() -> void:  # 🔵 FR-001
	_apply_result_kind()
	# 🔵 GameStateはAutoloadのため_exit_tree()での明示的disconnect()が必須（ui-components.md）
	GameState.game_over.connect(_on_game_over)
	GameState.game_cleared.connect(_on_game_cleared)


func _exit_tree() -> void:  # 🔵 FR-104
	if GameState.game_over.is_connected(_on_game_over):
		GameState.game_over.disconnect(_on_game_over)
	if GameState.game_cleared.is_connected(_on_game_cleared):
		GameState.game_cleared.disconnect(_on_game_cleared)


## 現在の表示種別を返す（テスト用）。🟡 FR-301
func get_result_kind() -> ResultKind:
	return _result_kind


func _on_game_cleared() -> void:  # 🔵 FR-102
	_result_kind = ResultKind.CLEAR
	_apply_result_kind()


# 🔵 FR-103, FR-404。demotion_countは表示に用いない（統計情報表示はスコープ外）
func _on_game_over(_demotion_count: int) -> void:
	_result_kind = ResultKind.OVER
	_apply_result_kind()


func _apply_result_kind() -> void:
	if _result_message_label == null:
		return
	match _result_kind:
		ResultKind.CLEAR:
			_result_message_label.text = CLEAR_MESSAGE_TEXT
		ResultKind.OVER:
			_result_message_label.text = OVER_MESSAGE_TEXT
		_:
			_result_message_label.text = INITIAL_MESSAGE_TEXT
