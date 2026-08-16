# 🔵 ランクごとのランタイム状態（FR-005, AC-008, data-schema.md L83-84）。
# state/配下のクラスはGameStateからのみ参照される（FR-409）。マスターデータではないためRefCounted継承とする。
class_name RankState
extends RefCounted

var quota: float = 0.0
# 🔴 コードレビュー指摘対応（既知のギャップ、本plan外）。elapsed_turnを進める本番コードは
# 現状どこにも存在しない（ターン進行システム自体が未実装）。将来ターン進行を配線する際は、
# GameState._current_turnの更新と必ずセットでelapsed_turnも進めること。片方だけ更新すると
# TurnLimitResolver.is_turn_limit_reached()が永久にfalseのままランク進行が静かに凍結する
var elapsed_turn: int = 0


## 🔵 GameState.get_state()の防御的コピー要件（FR-410）を満たす。
## フィールドはプリミティブ型のみのため、新規インスタンスへの代入で独立コピーになる。
func clone() -> RankState:
	var cloned := RankState.new()
	cloned.quota = quota
	cloned.elapsed_turn = elapsed_turn
	return cloned
