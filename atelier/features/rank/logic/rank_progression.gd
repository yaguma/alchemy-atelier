# 🔵 ランク進行順序の解決を担う純粋関数群（FR-010）。
# 副作用・乱数・GameState参照を持たない（FR-401, FR-402, AC-013）。
class_name RankProgression


## 🔵 現在ランクの次のランクIDを返す（FR-010）。GameBalance.RANK_ORDER上のindex+1参照。
## 次ランクなし（末尾＝ゲームクリア判定の根拠, FR-404）・未知のランクIDの場合は&""を返す。
static func get_next_rank_id(current_rank_id: StringName) -> StringName:
	var index := GameBalance.RANK_ORDER.find(current_rank_id)

	# 🔵 NFR-101: 未知のランクID（index == -1）でもクラッシュさせず空IDで処理を継続する
	if index < 0 or index + 1 >= GameBalance.RANK_ORDER.size():
		return &""

	return GameBalance.RANK_ORDER[index + 1]
