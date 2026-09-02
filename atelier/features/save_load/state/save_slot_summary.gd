# 🔵 スロット選択UIへ渡す1スロット分の要約。SaveServiceが構築し、UIは読み取りのみ行う。
# ファイル不在（is_empty）と破損（is_corrupted）を独立したフラグで表現し、
# 破損スロットでも例外を投げずに「読めないスロット」として描画できるようにする。
class_name SaveSlotSummary
extends RefCounted

var slot_index: int = 0
## trueならそのスロットにセーブファイルが存在しない
var is_empty: bool = true
## trueならファイルは存在するがchecksum不一致等で読めない
var is_corrupted: bool = false
var gold: int = 0
var current_rank_id: String = ""
var current_turn: int = 0
var saved_at_unix: int = 0
