# 🔵 制限ターン到達判定とランク結果確定を担う純粋関数群（core-systems.md L300-301）。
# 副作用・乱数・GameState参照を持たない（AC-013）。
class_name TurnLimitResolver


## 🔵 現在ターンが制限ターンに到達しているか判定する（FR-104, AC-003）。
## 等価（current_turn == limit_turn）も到達として扱う
static func is_turn_limit_reached(current_turn: int, limit_turn: int) -> bool:
	return current_turn >= limit_turn


## 🔵 ノルマ達成状況と制限ターン到達状況からランク結果を確定する（FR-105, FR-106, FR-107）。
## 🔴 制限ターン未到達なら、ノルマクリア済みでも必ずCONTINUEを返す早期リターンを先頭に置き、
## 早期クリアボーナス（FR-411）を構造的に保証する
static func resolve_rank_outcome(
	quota_cleared: bool, turn_limit_reached: bool
) -> RankOutcome.Value:
	if not turn_limit_reached:
		return RankOutcome.Value.CONTINUE

	return RankOutcome.Value.PROMOTION_ELIGIBLE if quota_cleared else RankOutcome.Value.DEMOTION
