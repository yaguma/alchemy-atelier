# 🔵 昇格試験中のランタイム状態（FR-006, core-systems.md L300-305, data-schema.md L63-69）。
# RankStateと異なりRankMasterを参照せず、start_exam()時点で計算済みのノルマ上限・制限ターンを
# 自身のフィールドとして保持する自己完結型とする（試験中にマスターデータを再参照しない）。
class_name ExamState
extends RefCounted

var exam_quota: float = 0.0
var exam_quota_max: float = 0.0
var exam_elapsed_turn: int = 0
var exam_turn_limit: int = 0


## 🔵 GameState.get_state()の防御的コピー要件（FR-410）を満たす。
## フィールドはプリミティブ型のみのため、新規インスタンスへの代入で独立コピーになる。
func clone() -> ExamState:
	var cloned := ExamState.new()
	cloned.exam_quota = exam_quota
	cloned.exam_quota_max = exam_quota_max
	cloned.exam_elapsed_turn = exam_elapsed_turn
	cloned.exam_turn_limit = exam_turn_limit
	return cloned
