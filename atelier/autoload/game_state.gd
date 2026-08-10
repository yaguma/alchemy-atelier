extends Node

signal phase_changed(previous: StringName, next: StringName)

var _current_phase: StringName = &"garden"
var _gold: int = 0
var _current_turn: int = 1


# 内部Dictionary/Arrayフィールドを直接返すと呼び出し元が改変できてしまうため、
# 辞書リテラルを都度生成しduplicate(true)でディープコピーを保証する（state-management.md）
func get_state() -> Dictionary:
	return (
		{
			"current_phase": _current_phase,
			"gold": _gold,
			"current_turn": _current_turn,
		}
		. duplicate(true)
	)


func set_phase(next: StringName) -> void:
	var previous := _current_phase
	_current_phase = next
	phase_changed.emit(previous, next)


# テスト分離専用。assert()はリリースビルドで除去されるため、
# push_error+returnを併用して本番コードパスからの実行を確実に止める
func reset_for_test() -> void:
	assert(OS.is_debug_build(), "reset_for_test() must not be called in release builds")
	if not OS.is_debug_build():
		push_error("reset_for_test() must not be called in release builds")
		return
	_current_phase = &"garden"
	_gold = 0
	_current_turn = 1
