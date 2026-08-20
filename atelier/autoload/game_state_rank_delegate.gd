## GameStateのランク進行（rank）・昇格試験（exam）関連本番ロジックの実装詳細を分離する内部ヘルパー。
## rank/examは_commit_exam_success()がランク遷移・工房強化フラグへ波及するなど密結合のため、
## 1つの委譲クラスにまとめる（rank/exam双方とも "--- ランク進行（rank）関連フィールド ---" /
## "--- 昇格試験（rank/exam）関連フィールド ---" と、元コメントの時点で同一ドメイン扱いだった）。
## 🔴 game_state.gd 500行ルール対応。GameStateTestSupportと同じパターンで、
## GameState側は本ファイルへの1行委譲のみを担う。公開シグネチャ・呼び出し方法は変更しない。
class_name GameStateRankDelegate

const GameStateScript = preload("res://autoload/game_state.gd")


## 🔴 CON-009。現在のRankState/RankMasterからランク結果を算出して返す（FR-109）。
## 副作用を持たない問い合わせ専用。UIの先出し表示と、commit_rank_outcome()の実行直前再評価の両方から使う。
## 🔴 コードレビュー指摘対応。_rank_state_initializedがfalseの間（quota_maxからの初期化が
## まだ行われていない、ランクマスターがロードされていない等）は常にCONTINUEを返す。
## こうしないと_rank_state.quotaの既定値0.0が「ノルマ達成済み」と誤認され、
## ランクの初回挑戦が常にPROMOTION_ELIGIBLE判定になってしまう
static func evaluate_rank_outcome(state: GameStateScript) -> RankOutcome.Value:
	if not state._rank_state_initialized:
		return RankOutcome.Value.CONTINUE

	var rank_master: RankMaster = state._rank_masters.get(state._current_rank_id)
	if rank_master == null:
		state._warn_missing_rank_master()
		return RankOutcome.Value.CONTINUE

	var quota_cleared := RankQuotaResolver.is_rank_cleared(state._rank_state.quota)
	var turn_limit_reached := TurnLimitResolver.is_turn_limit_reached(
		state._rank_state.elapsed_turn, rank_master.limit_turn
	)
	return TurnLimitResolver.resolve_rank_outcome(quota_cleared, turn_limit_reached)


## 🔴 CON-009。evaluate_rank_outcome()を実行直前に再評価して状態へ確定反映する（FR-110）。
## DEMOTIONなら降格回数を加算し、RankStateを再挑戦用に差し替える。
## ゲームオーバー成立時のみgame_over(_demotion_count)を発行する（FR-113）。
## PROMOTION_ELIGIBLEでは次ランクへ進めない（FR-404、promotion-exam planの責務）。
## 既にゲームオーバー確定済みなら状態を変更せず直近の確定結果を返す（FR-202、冪等性）。
## 🔴 コードレビュー指摘対応。DEMOTION側の状態更新（_demotion_count/_rank_state）は、
## 他の全GameStateミューテータ（harvest/execute_alchemy/deliver_pending_products）と同様、
## 必ずrank_outcome_confirmed発行より前に完了させる（同期リスナーが更新前の値を読むのを防ぐ）
## 🔵 FR-101。PROMOTION_ELIGIBLE確定時、not _in_examの場合のみ_start_exam()を呼ぶ
## （二重開始防止、FR-201）。既存のDEMOTION/game_over処理・シグナル発行順序は変更しない
static func commit_rank_outcome(state: GameStateScript) -> Result:
	if state.is_game_over():
		return Result.ok(state._last_rank_outcome)

	var outcome := evaluate_rank_outcome(state)
	state._last_rank_outcome = outcome

	if outcome == RankOutcome.Value.DEMOTION:
		state._demotion_count += 1
		state._rank_state = RankQuotaResolver.reset_for_retry(
			state._get_current_rank_master_or_fallback()
		)
	elif outcome == RankOutcome.Value.PROMOTION_ELIGIBLE and not state._in_exam:
		_start_exam(state)

	state.rank_outcome_confirmed.emit(outcome)  # 🔴 FR-112

	if outcome == RankOutcome.Value.DEMOTION and state.is_game_over():
		state.game_over.emit(state._demotion_count)

	return Result.ok(outcome)


## 🔵 FR-101。PromotionExamResolver.start_examで現在ランクのExamStateを生成しin_examをtrueにする。
## 🔴 NFR-101。現在ランクのRankMasterが不正（null/limit_turn<=0/exam_turn_limit<=0）な場合は
## 試験を開始せずpush_error()する。
## 🔴 evaluate_rank_outcome()と同様、_get_current_rank_master_or_fallback()は経由せず
## _rank_mastersを直接参照する（フォールバックのlimit_turn=0を「正当な0値」と誤認しないため）。
## 🔴 exam_turn_limit<=0もここで弾く。PromotionExamResolver.start_exam内部にも同種ガードがあるが、
## そちらは失敗時にexam_quota=0のExamStateを返すだけで例外を投げないため、ここで検知しないと
## _in_exam=trueのまま試験が始まり、次のcommit_exam_outcome()でexam_quota<=0により即SUCCESS
## 判定されてしまう（試験を一切プレイせず昇格するバグ）
static func _start_exam(state: GameStateScript) -> void:
	var rank_master: RankMaster = state._rank_masters.get(state._current_rank_id)
	if rank_master == null:
		state._warn_missing_rank_master()
		return
	if rank_master.limit_turn <= 0:
		push_error("現在ランクのlimit_turnが不正なため試験を開始できません: %s" % state._current_rank_id)
		return
	if rank_master.exam_turn_limit <= 0:
		push_error("現在ランクのexam_turn_limitが不正なため試験を開始できません: %s" % state._current_rank_id)
		return

	state._exam_state = PromotionExamResolver.start_exam(rank_master)
	state._in_exam = true
	state.exam_started.emit()  # 🟡 FR-302


## 🔵 FR-103, FR-104。試験中(_in_exam=true)に調合を実行せず試験ターンだけ進める。
## 在庫切れ・解禁レシピ切れ等で調合が実行不能になったデッドロックからの回避手段。
## PromotionExamResolver.advance_turnは新規ExamStateを返す純粋関数（in-place書き換えではない）ため、
## execute_alchemy()の試験中ターン消費と同様に戻り値で明示的に置き換える。
## 🟡 in_exam=falseの場合は状態を一切変更せず失敗のResultを返す（FR-104）。
## エラーコード&"not_in_exam"はexecute_alchemy_failed等の既存命名規則(snake_case)から推定した新規コード
## （design phaseで明示要件なし）。resolve_outcomeの呼び出しは行わない（結果確定はcommit_exam_outcome()の責務）
static func advance_exam_turn(state: GameStateScript) -> Result:
	if not state._in_exam:
		return Result.fail(&"not_in_exam")

	state._exam_state = PromotionExamResolver.advance_turn(state._exam_state)
	return Result.ok()


## 🟡 FR-107。in_exam=falseの場合は常にCONTINUEを返す（_rank_state_initializedガードと同型の
## 安全策）。副作用を持たない問い合わせ専用。UIの先出し表示と、commit_exam_outcome()の
## 実行直前再評価の両方から使う。判定ロジック自体はPromotionExamResolver.resolve_outcome
## （ノルマ達成を制限ターン到達より優先する）にそのまま委譲する
static func evaluate_exam_outcome(state: GameStateScript) -> ExamOutcome.Value:
	if not state._in_exam:
		return ExamOutcome.Value.CONTINUE

	return PromotionExamResolver.resolve_outcome(state._exam_state)


## 🔵 FR-108〜113。evaluate_exam_outcome()を実行直前に再評価してから状態へ確定反映する。
## SUCCESSなら次ランクへの実遷移またはゲームクリア判定、FAILUREなら同ランク再挑戦のリセット処理へ
## それぞれ委譲する。既にゲームオーバー確定済みなら状態を変更せず直近の確定結果を冪等に返す
## （FR-113、commit_rank_outcome()と同型）。
## 🔴 _commit_exam_success()/_commit_exam_failure()での状態更新は、他の全GameStateミューテータと
## 同様に必ずexam_outcome_confirmed発行より前に完了させる（同期リスナーが更新前の値を読むのを防ぐ）
static func commit_exam_outcome(state: GameStateScript) -> Result:
	if state.is_game_over():
		return Result.ok(state._last_exam_outcome)

	var outcome := evaluate_exam_outcome(state)
	state._last_exam_outcome = outcome

	if outcome == ExamOutcome.Value.SUCCESS:
		_commit_exam_success(state)
	elif outcome == ExamOutcome.Value.FAILURE:
		_commit_exam_failure(state)

	state.exam_outcome_confirmed.emit(outcome)  # 🟡 FR-301

	if outcome == ExamOutcome.Value.FAILURE and state.is_game_over():
		# 🔴 FR-113。新規シグナルは作らず、既存のrank plan実装のgame_over(demotion_count)を再利用する
		state.game_over.emit(state._demotion_count)

	return Result.ok(outcome)


## 🔵 SUCCESS確定時の内部処理（FR-108, FR-109, FR-404）。次ランクがあれば昇格しrank_stateを
## 次ランクのquota_maxで再初期化する。次ランクなし（RANK_ORDER末尾）ならゲームクリアとして
## current_rank_id・rank_stateは不変のままin_examのみ終了させる。
## 🔴 NFR-101。次ランクのRankMasterが_rank_mastersに未登録の場合は、_rank_state・_current_rank_idは
## 変更せず_warn_missing_next_rank_master()で警告するが、_in_examは必ずfalseへ戻す。
## 🔴 コードレビュー指摘対応。以前は_in_examをtrueのまま残していたため、次のcommit_exam_outcome()
## 呼び出しでもexam_quotaが>0のままSUCCESS判定が再評価されこの分岐に無限に入り直し、
## push_errorが呼び出しのたびに連呼される「解決不能な幽霊試験状態」に陥っていた
## 🔵 FR-110。関数冒頭で_can_purchase_permanentをtrueにし、昇格試験成功と工房強化の恒久投資
## 購入可否フラグを接続する。FR-110は「昇格試験が成功した場合」とのみ規定し分岐を限定していない
## ため、以下3分岐すべてに一律適用されるようあえて分岐前（関数冒頭）に置く
static func _commit_exam_success(state: GameStateScript) -> void:
	state._can_purchase_permanent = true  # 🔵 FR-110。既存3分岐すべてに一律適用される位置
	var next_rank_id := RankProgression.get_next_rank_id(state._current_rank_id)

	if next_rank_id == &"":
		state._in_exam = false
		return

	var next_rank_master: RankMaster = state._rank_masters.get(next_rank_id)
	if next_rank_master == null:
		state._warn_missing_next_rank_master(next_rank_id)
		state._in_exam = false
		return

	state._current_rank_id = next_rank_id
	# 🟡 design phase確認済み。RankQuotaResolver.reset_for_retryは「同ランク再挑戦専用」ではなく
	# 「RankMasterのquota_maxからRankStateを初期化する」汎用関数のため、次ランク初期化にも流用する
	state._rank_state = RankQuotaResolver.reset_for_retry(next_rank_master)
	state._rank_state_initialized = true
	state._in_exam = false


## 🔵 FAILURE確定時の内部処理（FR-110, FR-111）。同ランクをreset_for_retryでリセットし、
## demotion_countを+1する（commit_rank_outcome()のDEMOTION分岐と同型）
static func _commit_exam_failure(state: GameStateScript) -> void:
	state._demotion_count += 1
	state._rank_state = RankQuotaResolver.reset_for_retry(
		state._get_current_rank_master_or_fallback()
	)
	state._in_exam = false
