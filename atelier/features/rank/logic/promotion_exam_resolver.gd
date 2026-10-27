# 🔵 昇格試験の状態遷移（開始・ターン進行・結果判定）を担う純粋関数群（core-systems.md L334-336）。
# 副作用・乱数・GameState/RngService参照を持たない（FR-402, AC-013）。
class_name PromotionExamResolver


## 🔵 昇格試験を開始し、初期状態のExamStateを返す（FR-002）。
## 試験ノルマ上限は「ランクのノルマ上限 × 難度係数 × (試験制限ターン / ランク制限ターン)」で算出する。
## 🔵 NFR-101: rank_master欠落・limit_turn<=0（ゼロ除算）・exam_turn_limit<=0（未設定データ）時も
## クラッシュさせず、resolve_outcome()が即SUCCESS判定してしまわないようゼロ値のExamStateを返す。
## 🔵 Issue #68（FR-715）。ruleがノルマ以外の試験ルールなら、制限ターンはルールの値を使い、
## 合否は試験ノルマではなく進捗で判定する（resolve_outcome参照）。ruleがnull・quotaルールなら従来どおり
static func start_exam(rank_master: RankMaster, rule: ExamRuleMaster = null) -> ExamState:
	var exam_state := ExamState.new()

	if rank_master == null:
		push_error("PromotionExamResolver.start_exam(): rank_master is null")
		return exam_state

	if rule != null and rule.rule_type != ExamRuleMaster.RULE_QUOTA:
		return _start_rule_exam(rule)

	if rank_master.limit_turn <= 0:
		push_error("PromotionExamResolver.start_exam(): limit_turn must be positive")
		return exam_state

	if rank_master.exam_turn_limit <= 0:
		push_error("PromotionExamResolver.start_exam(): exam_turn_limit must be positive")
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
	exam_state.exam_rule_id = rule.id if rule != null else &""
	return exam_state


## 🔵 Issue #68。ノルマ以外の試験ルールのExamState。試験ノルマは使わないため0のままにする。
## 🔵 NFR-101: turn_limit<=0（未設定データ）なら開始時点でFAILUREにならないよう、ルールIDも
## 持たないゼロ値のExamStateを返す（呼び出し元のGameStateが開始前に検知して弾く）
static func _start_rule_exam(rule: ExamRuleMaster) -> ExamState:
	var exam_state := ExamState.new()
	if rule.turn_limit <= 0:
		push_error("PromotionExamResolver.start_exam(): rule.turn_limit must be positive")
		return exam_state
	exam_state.exam_turn_limit = rule.turn_limit
	exam_state.exam_rule_id = rule.id
	return exam_state


## 🔵 試験の経過ターンを1進めた新規ExamStateを返す（FR-003, FR-403）。
## 引数はin-placeで書き換えない（FR-401）。
static func advance_turn(exam_state: ExamState) -> ExamState:
	var advanced := exam_state.clone()
	advanced.exam_elapsed_turn += 1
	return advanced


## 🔵 試験の結果を3値で判定する（FR-004）。
## 🔵 ノルマ達成を最優先で評価するため、制限ターン到達時でもSUCCESSが優先される。
## 🔵 Issue #68。合格条件の判定はExamRuleResolver.is_clearedに委ねる（ruleがnullなら試験ノルマ方式）
static func resolve_outcome(
	exam_state: ExamState, rule: ExamRuleMaster = null
) -> ExamOutcome.Value:
	if ExamRuleResolver.is_cleared(exam_state.progress, rule, exam_state.exam_quota):
		return ExamOutcome.Value.SUCCESS

	if exam_state.exam_elapsed_turn >= exam_state.exam_turn_limit:
		return ExamOutcome.Value.FAILURE

	return ExamOutcome.Value.CONTINUE
