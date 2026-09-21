## GameStateのデバッグプレイ支援API（ゴールド付与・ノルマ即時達成・次ランクジャンプ）の実装詳細を
## 分離する内部ヘルパー。GameStateTestSupportと同じくAutoloadモジュール内部の一部として扱い、
## state._current_rank_id等の_prefixフィールドへ直接アクセスする。
## 🔴 debug-playtest-support Planでの新規追加。テスト専用API（GameStateTestSupport）は
## テストコードから状態を直接注入するためのものだが、本ファイルは実際の手動デバッグプレイ中に
## GameStateTestSupport.guard()と同じデバッグビルド限定ガードの下で呼ばれる想定のため、
## 既存の本番ロジック（deliver_pending_products/commit_rank_outcome等）をそのまま呼び出し、
## 独自の状態遷移ロジックは持たない。
class_name GameStateDebugDelegate

const GameStateScript = preload("res://autoload/game_state.gd")

## 🔴 QA専用の固定付与量。ゲームバランスにもUIの見た目にも影響しないためGameBalance/UiThemeの
## いずれにも該当しない、本ファイル内限定の定数として置く
const DEBUG_GOLD_AMOUNT := 1000


## 所持ゴールドをDEBUG_GOLD_AMOUNTだけ即時増加させる。GameStateGuildDelegate.deliver_pending_products()
## と同じ「直接加算→gold_changed発行」の契約に揃え、GoldDisplay等の既存signal購読側が
## そのまま追随できるようにする
static func debug_add_gold(state: GameStateScript) -> void:
	if not GameStateTestSupport.guard("debug_add_gold"):
		return
	var gold_before := state._gold
	state._gold += DEBUG_GOLD_AMOUNT
	state.gold_changed.emit(gold_before, state._gold, DEBUG_GOLD_AMOUNT)


## alchemy_screen.gd:_on_end_turn_pressed()と同じ「deliver_pending_products() → commit_rank_outcome()」
## の2呼び出しをそのまま実行する。ノルマ判定・試験開始・降格判定は既存のcommit_rank_outcome()に
## すべて委譲するため新規ロジックは持たない
static func debug_force_end_turn(state: GameStateScript) -> Result:
	if not GameStateTestSupport.guard("debug_force_end_turn"):
		return Result.fail(&"debug_disabled")
	state.deliver_pending_products()
	return state.commit_rank_outcome()


## 現在ランクを次ランクへ即座に進める。RankProgression.get_next_rank_id()/is_true_final_rank()と
## GameStateRankDelegate._commit_exam_success()の昇格分岐を踏襲し、次ランクのRankMasterで
## RankQuotaResolver.reset_for_retryしたRankStateへ差し替える。
## 末尾ランク（is_true_final_rank()がtrue）または次ランクのRankMaster未登録時は何もしない
## （ゲームクリア演出・マスター欠落エラーは本来の昇格試験フローの責務であり、
## デバッグ用の即時ジャンプでは複製せず単に無視する）
static func debug_jump_to_next_rank(state: GameStateScript) -> void:
	if not GameStateTestSupport.guard("debug_jump_to_next_rank"):
		return
	if RankProgression.is_true_final_rank(state._current_rank_id):
		return

	var next_rank_id := RankProgression.get_next_rank_id(state._current_rank_id)
	if next_rank_id == &"":
		return

	var next_rank_master: RankMaster = state._rank_masters.get(next_rank_id)
	if next_rank_master == null:
		return

	state._current_rank_id = next_rank_id
	state._rank_state = RankQuotaResolver.reset_for_retry(next_rank_master)
	state._rank_state_initialized = true
