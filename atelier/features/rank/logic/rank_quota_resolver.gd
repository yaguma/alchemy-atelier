# 🔵 ノルマ残量計算を担う純粋関数群（core-systems.md L297-299）。
# 副作用・乱数・GameState参照を持たない（FR-401, FR-402, AC-013）。
class_name RankQuotaResolver


## 🔵 貢献度をノルマ残量から減算する（FR-101, AC-001）。
## 0未満にはならず、残量を超えた貢献度の超過分は切り捨てる。
static func apply_contribution(current_quota: float, contribution: float) -> float:
	return maxf(0.0, current_quota - contribution)


## 🔵 ノルマを達成済みか判定する（FR-102, AC-002）。
## 🔴 クランプ済みなら負値は発生しないが、防御的に負値もクリア扱いとする
static func is_rank_cleared(current_quota: float) -> bool:
	return current_quota <= 0.0


## 🔵 ランク再挑戦用にノルマ残量と経過ターンを初期化した新規RankStateを返す（FR-103, AC-008）。
## 引数や呼び出し元の既存RankStateはin-placeで書き換えない（FR-401）。
static func reset_for_retry(rank_master: RankMaster) -> RankState:
	var reset_state := RankState.new()

	# 🔵 NFR-101: マスターデータ欠落時もクラッシュさせず、既定値のRankStateで処理を継続する
	if rank_master == null:
		push_error("RankQuotaResolver.reset_for_retry(): rank_master is null")
		return reset_state

	reset_state.quota = rank_master.quota_max
	return reset_state
