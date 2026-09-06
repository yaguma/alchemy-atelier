## GameStateの初期状態適用ロジックを分離する内部ヘルパー。
## テスト専用のreset_for_test()と、本番コードパスから呼べる新規ゲーム用reset_for_new_game()
## （SaveService.select_slot_and_restore()の新規スロット分岐から呼ばれる）が、
## この同じ初期化本体を共有する。GameStateTestSupportと同じパターンで、
## GameState側は本ファイルへの1行委譲のみを担う。
class_name GameStateResetDelegate

const GameStateScript = preload("res://autoload/game_state.gd")


## 🔵 reset_for_test()の既存実装本体をそのまま移設したもの。全フィールドを初期値へ戻す。
static func apply_default_state(state: GameStateScript) -> void:
	state._current_phase = &"garden"
	state._gold = 0
	state._current_turn = 1
	state._garden_state = GardenState.new()
	state._seed_inventory = [
		{"seed_id": GameBalance.INITIAL_SEED_ID, "count": GameBalance.INITIAL_SEED_COUNT}
	]
	state._inventory = []
	state._seed_masters = {}
	state._material_masters = {}
	state._material_instance_seq = 0
	state._garden_slot_count = GameBalance.GARDEN_SLOT_COUNT
	state._recipe_masters = {}
	state._unlocked_recipe_ids = [GameBalance.INITIAL_RECIPE_ID]
	state._pending_products = []
	state._alchemy_slot_count = GameBalance.ALCHEMY_SLOT_COUNT_DEFAULT
	state._current_daily_order = null
	state._daily_order_masters = []
	state._current_rank_id = GameBalance.INITIAL_RANK_ID
	state._rank_masters = {}
	state._rank_state = RankState.new()
	state._demotion_count = 0
	state._last_rank_outcome = RankOutcome.Value.CONTINUE
	state._rank_state_initialized = false
	state._warned_missing_rank_master_ids = {}
	state._in_exam = false
	state._exam_state = ExamState.new()
	state._last_exam_outcome = ExamOutcome.Value.CONTINUE
	state._has_cleared_game = false
	state._can_purchase_permanent = false
	state._purchased_upgrade_counts = {}
	state._upgrade_masters = {}
