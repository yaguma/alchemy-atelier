## GameStateのギルド納品（guild）関連本番ロジックの実装詳細を分離する内部ヘルパー。
## 🔴 game_state.gd 500行ルール対応。GameStateTestSupportと同じパターンで、
## GameState側は本ファイルへの1行委譲のみを担う。公開シグネチャ・呼び出し方法は変更しない。
class_name GameStateGuildDelegate

const GameStateScript = preload("res://autoload/game_state.gd")


## 🔴 _pending_productsを先頭から全件消費し、各ProductInstanceについて
## DeliveryResolver.resolve(product, _current_daily_order)を呼び出す（FR-005, FR-105）。
## final_rewardはroundi()で丸めて_goldへ即時加算（FR-106, CON-007）、
## final_contributionはRankQuotaResolver.apply_contributionで現在ランクのノルマ残量から
## 減算する（🔵 FR-108, CON-004）。
## 全件処理後にキューを空にしdelivered(results)を発行する（FR-108）。
## キューが空の場合は状態を一切変更せずResult.ok([])を返す（FR-109, AC-012）
static func deliver_pending_products(state: GameStateScript) -> Result:
	var results: Array[DeliveryResult] = []
	if state._pending_products.is_empty():
		return Result.ok(results)

	var gold_before := state._gold
	# 🔵 FR-105, FR-106, FR-401。試験中(_in_exam)はdaily_orderをnullに切り替え、
	# 指定合致ボーナス（DeliveryResolver.matches_orderはdaily_order=nullで常にfalse）を不適用にする。
	# 報酬(gold)加算はこの分岐と無関係に常時行う（FR-106: 試験中/非試験中でgold加算量は変わらない）
	# 🔴 コードレビュー指摘対応。AlchemyScreenのライブプレビューと同一の式を共有するため
	# GameState.resolve_daily_order_for_delivery()に一本化した（ここで独自にtern化しない）
	var order_for_delivery := state.resolve_daily_order_for_delivery()
	for product in state._pending_products:
		var delivery_result := DeliveryResolver.resolve(product, order_for_delivery)
		state._gold += roundi(delivery_result.final_reward)
		# 🔵 貢献度の適用先を試験中/非試験中で切り替える。RankQuotaResolver.apply_contribution自体は
		# ノルマの入れ物がRankState.quotaかExamState.exam_quotaかを問わない汎用のfloatクランプ関数のため無変更で流用する
		if state._in_exam:
			state._exam_state.exam_quota = RankQuotaResolver.apply_contribution(
				state._exam_state.exam_quota, delivery_result.final_contribution
			)
		else:
			state._rank_state.quota = RankQuotaResolver.apply_contribution(
				state._rank_state.quota, delivery_result.final_contribution
			)
		results.append(delivery_result)

	# 🔴 走査中にclear()すると反復が壊れるため、キューの破棄はループ完了後に行う
	state._pending_products.clear()

	if state._gold != gold_before:
		state.gold_changed.emit(gold_before, state._gold, state._gold - gold_before)

	# 🔴 emit直後にResult.ok(results)で同一配列を返すと、delivered購読側がその場で
	# 配列を書き換え（clear/並べ替え等）た場合に戻り値まで汚染される。
	# duplicate()でシグナル発行用の別配列を渡し、戻り値の配列とは独立させる
	# （要素のDeliveryResultインスタンス自体はプリミティブ値型フィールドのみのため共有で問題ない）
	state.delivered.emit(results.duplicate())
	return Result.ok(results)
