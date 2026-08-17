# 🔵 昇格試験の状態遷移（開始・ターン進行・結果判定）を担う純粋関数群（core-systems.md L334-336）。
# 副作用・乱数・GameState/RngService参照を持たない（FR-402, AC-013）。
class_name PromotionExamResolver


## 🔵 昇格試験を開始し、初期状態のExamStateを返す（FR-002）。
## 試験ノルマ上限は「ランクのノルマ上限 × 難度係数 × (試験制限ターン / ランク制限ターン)」で算出する。
## 🔵 NFR-101: rank_master欠落・limit_turn<=0（ゼロ除算）時もクラッシュさせずゼロ値のExamStateを返す。
static func start_exam(rank_master: RankMaster) -> ExamState:
	var exam_state := ExamState.new()

	if rank_master == null:
		push_error("PromotionExamResolver.start_exam(): rank_master is null")
		return exam_state

	if rank_master.limit_turn <= 0:
		push_error("PromotionExamResolver.start_exam(): limit_turn must be positive")
		return exam_state

	var quota_max := (
		rank_master.quota_max
		* rank_master.exam_difficulty_coefficient
		* float(rank_master.exam_turn_limit)
		/ float(rank_master.limit_turn)
	)
	exam_state.exam_quota_max = quota_max
	exam_state.exam_quota = quota_max
	exam_state.exam_turn_limit = rank_master.exam_turn_limit
	return exam_state


## 🔵 試験の経過ターンを1進めた新規ExamStateを返す（FR-003, FR-403）。
## 引数はin-placeで書き換えない（FR-401）。
static func advance_turn(exam_state: ExamState) -> ExamState:
	var advanced := exam_state.clone()
	advanced.exam_elapsed_turn += 1
	return advanced


## 🔵 試験の結果を3値で判定する（FR-004）。
## 🔵 ノルマ達成を最優先で評価するため、制限ターン到達時でもSUCCESSが優先される。
static func resolve_outcome(exam_state: ExamState) -> ExamOutcome.Value:
	if exam_state.exam_quota <= 0.0:
		return ExamOutcome.Value.SUCCESS

	if exam_state.exam_elapsed_turn >= exam_state.exam_turn_limit:
		return ExamOutcome.Value.FAILURE

	return ExamOutcome.Value.CONTINUE
