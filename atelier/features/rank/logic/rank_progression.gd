# 🔵 ランク進行順序の解決を担う純粋関数群（FR-010）。
# 副作用・乱数・GameState参照を持たない（FR-401, FR-402, AC-013）。
class_name RankProgression


## 🔵 現在ランクの次のランクIDを返す（FR-010）。GameBalance.RANK_ORDER上のindex+1参照。
## 次ランクなし（末尾＝ゲームクリア判定の根拠, FR-404）・未知のランクIDの場合は&""を返す。
## 🔴 コードレビュー指摘対応。「末尾（真のゲームクリア）」と「未知のランクID（不正な状態）」の
## 両方で&""を返すため、この2ケースを区別する必要がある呼び出し元はis_true_final_rank()を使うこと
static func get_next_rank_id(current_rank_id: StringName) -> StringName:
	var index := GameBalance.RANK_ORDER.find(current_rank_id)

	# 🔵 NFR-101: 未知のランクID（index == -1）でもクラッシュさせず空IDで処理を継続する
	if index < 0 or index + 1 >= GameBalance.RANK_ORDER.size():
		return &""

	return GameBalance.RANK_ORDER[index + 1]


## 🔴 コードレビュー指摘対応。current_rank_idがRANK_ORDER上に実在し、かつ末尾（真の最終ランク）で
## あるかを返す。get_next_rank_id()の戻り値&""だけでは「末尾（真のゲームクリア）」と「未知の
## ランクID（不正な状態）」を区別できないため、ゲームクリア判定にはこちらを使う（FR-004, FR-101）。
## 未知のランクID（index == -1）は末尾ではないためfalseを返す（NFR-101、クラッシュしない）。
static func is_true_final_rank(current_rank_id: StringName) -> bool:
	var index := GameBalance.RANK_ORDER.find(current_rank_id)
	return index >= 0 and index == GameBalance.RANK_ORDER.size() - 1
