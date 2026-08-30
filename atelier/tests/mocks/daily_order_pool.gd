## 🔴 コードレビュー指摘対応。指定依頼の達成可能プールを本番実装
## （GameStateGuildDelegate.reroll_daily_order）と同じ条件でテスト側に再現する共有ヘルパー。
## test_main_scene_daily_order_flow.gdとtest_game_state_daily_order_lifecycle.gdが
## 個別に持っていた同一実装を1箇所へ統合した。class_nameを持たない補助スクリプトのため、
## 利用側はconst+preloadで参照する（.claude/rules/architecture.md「公開APIパターン」の例外運用）

static func current_pool() -> Array[DailyOrderMaster]:
	return DailyOrderSelector.filter_achievable(
		GameState._daily_order_masters,
		GameState._unlocked_recipe_ids,
		GameState.is_current_rank_traits_unlocked()
	)
