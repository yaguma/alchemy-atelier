# 🔵 庭の1スロット分の生育状況を表すランタイム状態（FR-002, data-schema.md L33-36）。
# state/配下のクラスはGameStateからのみ参照される（NFR-302）。マスターデータではないためRefCounted継承とする。
class_name PlantState
extends RefCounted

var slot_index: int
var seed_id: StringName
var grown_turns: int
var is_matured: bool


## 🔵 data-schema.mdのフィールド定義に従い各プロパティを設定する。
## grown_turns/is_maturedは新規植え付け直後の初期値をデフォルト引数で表す
func _init(
	p_slot_index: int, p_seed_id: StringName, p_grown_turns: int = 0, p_is_matured: bool = false
) -> void:
	slot_index = p_slot_index
	seed_id = p_seed_id
	grown_turns = p_grown_turns
	is_matured = p_is_matured


## 🔴 GameState.get_state()の防御的コピー要件（FR-403）を満たすための新規補完。
func clone() -> PlantState:
	return PlantState.new(slot_index, seed_id, grown_turns, is_matured)
