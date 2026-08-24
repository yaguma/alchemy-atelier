extends Node

signal phase_changed(previous: StringName, next: StringName)
signal seed_planted(slot_index: int, seed_id: StringName)  # 🔵 FR-101
signal plant_seed_failed(seed_id: StringName, error_code: StringName)  # 🔴 UI側トースト表示(NFR-202)用の新規補完
signal material_harvested(material: MaterialInstance, slot_index: int)  # 🔵 FR-105
signal harvest_failed(slot_index: int, error_code: StringName)  # 🔴 UI側フィードバック用の新規補完
# 🔵 FR-111。Array[int]相当だが、GDScriptのsignal引数型注釈の制約に合わせてArrayとする
signal plants_withered(slot_indices: Array)
signal turn_growth_advanced(turn: int)  # 🔴 UI再描画トリガ用の新規補完
signal product_crafted(product: ProductInstance)  # 🔵 FR-112
# 🔴 garden の plant_seed_failed/harvest_failed パターン踏襲（FR-113）
signal execute_alchemy_failed(recipe_id: StringName, error_code: StringName)
signal delivered(results: Array[DeliveryResult])  # 🔴 FR-108
# 🔴 state-management.mdが定義するゴールド変動通知。deliver_pending_products()が
# _goldを変更する最初の経路のため、ここで初めて発行する
signal gold_changed(previous_amount: int, new_amount: int, delta: int)
signal rank_outcome_confirmed(outcome: RankOutcome.Value)  # 🔴 FR-112
signal game_over(demotion_count: int)  # 🔴 FR-113
# 🔵 FR-004, FR-101, FR-302。最終ランクでの昇格試験成功（真のゲームクリア）時のみ発行する。
# 対応する自然なペイロードが存在しないためYAGNIで無引数とする
signal game_cleared
signal exam_started  # 🟡 FR-302（任意要件）。開始ロジック自体は後続task（007〜011）で実装する
signal exam_outcome_confirmed(outcome: ExamOutcome.Value)  # 🟡 FR-301（任意要件）

var _current_phase: StringName = &"garden"
var _gold: int = 0
var _current_turn: int = 1

# --- 庭（garden）関連フィールド ---
var _garden_state: GardenState = GardenState.new()  # 🔵 FR-001
var _seed_inventory: Array[Dictionary] = []  # 🔵 [{seed_id: StringName, count: int}]
var _inventory: Array[MaterialInstance] = []  # 🔵 収穫済み素材
var _seed_masters: Dictionary = {}  # 🔵 Dictionary[StringName, SeedMaster]
var _material_masters: Dictionary = {}  # 🔵 Dictionary[StringName, MaterialMaster]
var _material_instance_seq: int = 0  # 🔴 instance_id採番用（新規補完）
# 🔵 FR-006「実行時権威」の暫定置き場（player.permanent_upgrades本体は別plan未実装のため、
# 本plan内では庭専用フィールドとして仮に保持する）
var _garden_slot_count: int = GameBalance.GARDEN_SLOT_COUNT

# --- 調合（alchemy）関連フィールド ---
var _recipe_masters: Dictionary = {}  # 🔵 Dictionary[StringName, RecipeMaster]
var _unlocked_recipe_ids: Array[StringName] = [GameBalance.INITIAL_RECIPE_ID]  # 🔵 FR-007
var _pending_products: Array[ProductInstance] = []  # 🔴 FR-008 ギルド納品待ちキュー
# 🔵 FR-006「実行時権威」の暫定置き場（_garden_slot_countと同様、本plan内ではGameStateが仮に保持する）
var _alchemy_slot_count: int = GameBalance.ALCHEMY_SLOT_COUNT_DEFAULT

# --- ギルド納品（guild）関連フィールド ---
# 🔴 CON-010。日替わり指定調合物の再抽選ロジックは別planのため、既定値nullでも納品が成立する
var _current_daily_order: DailyOrderMaster = null

# --- ランク進行（rank）関連フィールド ---
var _current_rank_id: StringName = GameBalance.INITIAL_RANK_ID  # 🔵 FR-006
var _rank_masters: Dictionary = {}  # 🔵 FR-006。Dictionary[StringName, RankMaster]
var _rank_state: RankState = RankState.new()  # 🔵 FR-006
var _demotion_count: int = 0  # 🔵 FR-006
# 🔴 FR-202。ゲームオーバー確定後にcommit_rank_outcome()が冪等に返すための直近確定結果
var _last_rank_outcome: RankOutcome.Value = RankOutcome.Value.CONTINUE
# 🔴 コードレビュー指摘対応。_rank_state.quotaは現状どの本番コードパスからもquota_maxから
# 初期化されない（ランクマスターロード自体がCON-006で本plan外）ため、「まだ本物のノルマ値が
# セットされていない」ことを明示的に区別するフラグ。falseの間はevaluate_rank_outcome()が
# 常にCONTINUEを返し、quota=0.0の既定値が「ノルマ達成済み」と誤認されることを防ぐ
var _rank_state_initialized: bool = false
# 🔴 コードレビュー指摘対応。_get_current_rank_master_or_fallback()のpush_error()が
# ランクマスター未登録の間、呼び出しのたびに多重発生しコンソールを埋めるのを防ぐため、
# 一度警告済みのランクIDを記録する（reset_for_test()で初期化）
var _warned_missing_rank_master_ids: Dictionary = {}

# --- 昇格試験（rank/exam）関連フィールド ---
# 🔵 FR-008。試験の開始/進行/結果確定ロジック自体は後続task（007〜011）で実装する
var _in_exam: bool = false
# 🟡 design phase確定。_rank_stateと同型パターンだが、ExamStateはRankMasterを再参照せず
# start_exam()時点で計算済みのexam_quota_maxを自身のフィールドとして保持する自己完結型
var _exam_state: ExamState = ExamState.new()
# 🔵 FR-113（_last_rank_outcomeと同型）。試験結果確定後にcommit_exam_outcome()が
# 冪等に返すための直近確定結果（後続taskで使用）
var _last_exam_outcome: ExamOutcome.Value = ExamOutcome.Value.CONTINUE
# 🔴 コードレビュー指摘対応。真のゲームクリア成立後、is_game_over()と同型の冪等性ガードで
# commit_rank_outcome()/commit_exam_outcome()を早期returnさせ、同じ最終ランクの試験が
# 再トリガーされてgame_clearedが複数回発行されるのを防ぐためのフラグ
var _has_cleared_game: bool = false

# --- 工房強化・ショップ（workshop）関連フィールド ---
var _can_purchase_permanent: bool = false  # 🔵 FR-009
var _purchased_upgrade_counts: Dictionary = {}  # 🔵 FR-010 Dictionary[StringName, int]
var _upgrade_masters: Dictionary = {}  # 🔵 FR-011 Dictionary[StringName, UpgradeMaster]


# 内部Dictionary/Arrayフィールドを直接返すと呼び出し元が改変できてしまうため、
# 辞書リテラルを都度生成しduplicate(true)でディープコピーを保証する（state-management.md）。
# garden_state/inventoryはカスタムRefCounted型を含むため、clone()を明示的に呼ぶ（🔵 AC-014, FR-403）。
# 🔴 Array.map()の戻り値は型付き配列(Array[MaterialInstance])ではなく素のArrayになり、
# 呼び出し元で型付き変数へ代入する際に実行時エラーとなるため、明示的に型付き配列を構築する
# （GardenState.clone()と同じ既知の罠）
func get_state() -> Dictionary:
	var cloned_inventory: Array[MaterialInstance] = []
	for material in _inventory:
		cloned_inventory.append(material.clone())

	var cloned_pending_products: Array[ProductInstance] = []
	for product in _pending_products:
		cloned_pending_products.append(product.clone())

	return {
		"current_phase": _current_phase,
		"gold": _gold,
		"current_turn": _current_turn,
		"garden_state": _garden_state.clone(),
		"seed_inventory": _seed_inventory.duplicate(true),
		# 🔴 タスク018（GardenScreen）実装のための新規補完。PlantSlotView.setup()/SeedInventoryList.setup()
		# がSeedMasterを必要とするため公開する。マスターデータ（Infrastructure層、Resourceは不変前提）の
		# ためDictionary自体の浅いduplicate()のみで防御的コピー要件を満たす
		"seed_masters": _seed_masters.duplicate(),
		# 🔴 GardenState.plantsは埋まっているスロットのみを保持し空きスロットを表現しないため、
		# GardenScreenが全スロット（空き含む）を描画するには庭の総スロット数が別途必要
		"garden_slot_count": _garden_slot_count,
		"inventory": cloned_inventory,
		# 🔵 CON-001。seed_masters公開と同型。AlchemyScreenがレシピ詳細（名称・必要素材等）を
		# 描画するために必要。マスターデータ（Resourceは不変前提）のため浅いduplicate()で十分
		"recipe_masters": _recipe_masters.duplicate(),
		# 🔵 CON-002。garden_slot_count公開と同型。AlchemyScreenが投入枠を空き含めて
		# 描画するために必要。int値型のため複製不要
		"alchemy_slot_count": _alchemy_slot_count,
		# 🔴 要素がStringName（値型相当）のため浅い複製で十分（FR-403）
		"unlocked_recipe_ids": _unlocked_recipe_ids.duplicate(),
		"pending_products": cloned_pending_products,
		# 🔴 DailyOrderMasterは@export var（プリミティブ）のみで構成されるが、Resource自体は
		# 参照型のため他フィールドと同様clone()してから返す（state-management.md防御的コピー要件）
		"current_daily_order": _current_daily_order.clone() if _current_daily_order else null,
		# 🔵 FR-006。StringName/intは値型のため複製不要。RankStateは参照型のためclone()する（FR-410）
		"current_rank_id": _current_rank_id,
		"demotion_count": _demotion_count,
		"rank_state": _rank_state.clone(),
		# 🔵 FR-009, AC-018。試験ビュー5フィールドはすべて値型のため、_exam_state.clone()のような
		# 明示的コピー呼び出しは不要（値型コピーで防御性が保たれる、design phase確定）
		"in_exam": _in_exam,
		"exam_quota": _exam_state.exam_quota,
		"exam_quota_max": _exam_state.exam_quota_max,
		"exam_elapsed_turn": _exam_state.exam_elapsed_turn,
		"exam_turn_limit": _exam_state.exam_turn_limit,
		"can_purchase_permanent": _can_purchase_permanent,  # 🔵 FR-017
		# 🔵 FR-007。seed_masters/recipe_masters公開と同型。UpgradeMasterはResource（不変前提の
		# マスターデータ）のため、Dictionary自体の浅いduplicate()のみで防御的コピー要件を満たす
		"upgrade_masters": _upgrade_masters.duplicate(),
		# 🔵 FR-008。値がint（値型）のDictionaryのため、浅いduplicate()でキー追加/削除・値上書きの
		# いずれからも_purchased_upgrade_counts本体を保護できる
		"purchased_upgrade_counts": _purchased_upgrade_counts.duplicate(),
	}


func set_phase(next: StringName) -> void:
	var previous := _current_phase
	_current_phase = next
	phase_changed.emit(previous, next)


# 🔴 500行ルール対応。以下、本番ロジックの実装本体は機能別のGameState*Delegateへ委譲する
# （GameStateTestSupportと同じパターン）。GameState側は公開シグネチャの維持とフィールド保持のみ担う。


func load_garden_master_data() -> void:
	GameStateGardenDelegate.load_garden_master_data(self)


func load_alchemy_master_data() -> void:
	GameStateAlchemyDelegate.load_alchemy_master_data(self)


func load_workshop_master_data() -> void:
	GameStateWorkshopDelegate.load_workshop_master_data(self)


func plant_seed(seed_id: StringName) -> Result:
	return GameStateGardenDelegate.plant_seed(self, seed_id)


## _seed_inventory内でseed_idが一致する要素のインデックスを返す。見つからない場合は-1。
## 🔴 既存テスト（test_game_state_apply_upgrade_effects.gd）がプライベートメソッドとして
## 直接呼び出しているため、GameState側の薄いラッパーとして維持する
func _find_seed_inventory_index(seed_id: StringName) -> int:
	return GameStateGardenDelegate.find_seed_inventory_index(self, seed_id)


## 🔵 素材インスタンスの連番IDを払い出す("mat_0000"形式)。garden delegateのharvest()と
## workshop delegateのapply_upgrade()のcatalyst_stock分岐が共有する採番カウンタ
## （instance_id衝突防止のため別カウンタに分離しない、コードレビュー指摘対応で共通ヘルパーへ抽出）。
## 複数delegateから横断的に使われる採番の正本のため、GameState自身に残す
func _next_material_instance_id() -> String:
	var id := "mat_%04d" % _material_instance_seq
	_material_instance_seq += 1
	return id


func harvest(slot_index: int) -> Result:
	return GameStateGardenDelegate.harvest(self, slot_index)


func advance_turn_growth() -> void:
	GameStateGardenDelegate.advance_turn_growth(self)


func execute_alchemy(recipe_id: StringName, material_instance_ids: Array[String]) -> Result:
	return GameStateAlchemyDelegate.execute_alchemy(self, recipe_id, material_instance_ids)


func deliver_pending_products() -> Result:
	return GameStateGuildDelegate.deliver_pending_products(self)


## _current_rank_idに対応するランクIDについて、まだ_warn_missing_rank_master()で
## 警告していなければpush_error()する。同一ランクIDでの多重発生を防ぐ（🔴 コードレビュー指摘対応）。
## rank delegate・_get_current_rank_master_or_fallback()の双方から横断的に使われるためGameState自身に残す
func _warn_missing_rank_master() -> void:
	if _warned_missing_rank_master_ids.has(_current_rank_id):
		return
	_warned_missing_rank_master_ids[_current_rank_id] = true
	push_error("現在ランクのマスターデータが見つかりません: %s" % _current_rank_id)


## _commit_exam_success()専用。次ランクのマスターデータが見つからない場合の警告を、
## _warn_missing_rank_master()と同じ_warned_missing_rank_master_idsで多重発生を防ぎつつ出す
## （🔴 コードレビュー指摘対応。next_rank_idは_current_rank_idとは別IDのため専用関数にする）
func _warn_missing_next_rank_master(next_rank_id: StringName) -> void:
	if _warned_missing_rank_master_ids.has(next_rank_id):
		return
	_warned_missing_rank_master_ids[next_rank_id] = true
	push_error("次ランクのマスターデータが見つかりません: %s" % next_rank_id)


## 現在ランクのRankMasterを返す。_rank_mastersに_current_rank_idが存在しない場合は
## _warn_missing_rank_master()した上で、特性未解禁・ノルマ0・制限ターン0の安全側フォールバックを返す
## （🔴 FR-114, CON-008）。マスターデータ未ロード時でも調合・納品が例外なく成立することを優先し、
## null返却は行わない。ランク結果評価（evaluate_rank_outcome）はこのフォールバックの
## quota_max=0.0/limit_turn=0が誤ってPROMOTION_ELIGIBLEを誘発しないよう、あえてこの関数を
## 経由せず_rank_mastersを直接参照する（コードレビュー指摘対応）。
## alchemy delegate（execute_alchemyのtraits_unlocked取得）とrank delegateの双方から
## 横断的に使われるためGameState自身に残す
func _get_current_rank_master_or_fallback() -> RankMaster:
	var master: RankMaster = _rank_masters.get(_current_rank_id)
	if master != null:
		return master

	_warn_missing_rank_master()
	var fallback := RankMaster.new()
	fallback.id = String(_current_rank_id)
	fallback.traits_unlocked = false
	fallback.quota_max = 0.0
	fallback.limit_turn = 0
	return fallback


## 現在ランクで特性システムが解禁済みかを返す（🔵 AC-015）。
## 🔴 UIの事前予測とDomain層の再評価が食い違わないよう、
## GameStateAlchemyDelegate.execute_alchemy()と同一の_get_current_rank_master_or_fallback()を
## 経由する（判定式を再実装しない、NFR-101）。ランクマスター未ロード時はフォールバックにより
## falseを返し、例外は投げない
func is_current_rank_traits_unlocked() -> bool:
	return _get_current_rank_master_or_fallback().traits_unlocked


## 現在ランクのRankMasterを返す（🔴 GuildDeliveryScreenのランクノルマ簡易バー表示用）。
## 判定式を重複実装しないよう_get_current_rank_master_or_fallback()をそのまま再利用する。
## マスター未ロード時はtraits_unlocked=false / quota_max=0.0 / limit_turn=0の安全側
## フォールバックを返す（既存ヘルパーの契約をそのまま継承し、nullは返さない）
func get_current_rank_master() -> RankMaster:
	return _get_current_rank_master_or_fallback()


## 現在ランクのノルマ残量を返す（🔴 GuildDeliveryScreenのランクノルマ簡易バー表示用）。
## RankState（他Featureのstate/）をUI層へ露出させずプリミティブ値のみ渡すためのラッパー。
## RankStateは既定値quota=0.0を持つため、マスター未ロード時のフォールバック判定は不要
func get_current_rank_quota() -> float:
	return _rank_state.quota


## 納品判定（DeliveryResolver.resolve）に渡すべき指定依頼を返す（🔵 FR-105, FR-401）。
## 🔴 コードレビュー指摘対応。GameStateGuildDelegate.deliver_pending_products()が試験中(_in_exam)に
## 指定依頼をnullへ切り替える分岐と全く同じ式をここに一本化し、AlchemyScreenのライブプレビューが
## 実際の納品結果と乖離しないようにする（試験中はプレビューも指定合致ボーナスなしで計算する）
func resolve_daily_order_for_delivery() -> DailyOrderMaster:
	return null if _in_exam else _current_daily_order


func evaluate_rank_outcome() -> RankOutcome.Value:
	return GameStateRankDelegate.evaluate_rank_outcome(self)


func commit_rank_outcome() -> Result:
	return GameStateRankDelegate.commit_rank_outcome(self)


## 🔵 FR-111。降格回数が上限に達しているか。rank delegate・exam delegate双方の
## ゲームオーバー判定から横断的に使われる単純な問い合わせのため、委譲せずGameState自身に残す
func is_game_over() -> bool:
	return _demotion_count >= GameBalance.MAX_DEMOTION_COUNT


## 🔴 コードレビュー指摘対応。真のゲームクリアが成立済みか。is_game_over()と同型の
## 冪等性ガードとしてcommit_rank_outcome()/commit_exam_outcome()の両方から使う
func is_game_cleared() -> bool:
	return _has_cleared_game


func advance_exam_turn() -> Result:
	return GameStateRankDelegate.advance_exam_turn(self)


func evaluate_exam_outcome() -> ExamOutcome.Value:
	return GameStateRankDelegate.evaluate_exam_outcome(self)


func commit_exam_outcome() -> Result:
	return GameStateRankDelegate.commit_exam_outcome(self)


func apply_upgrade(upgrade: UpgradeMaster) -> Result:
	return GameStateWorkshopDelegate.apply_upgrade(self, upgrade)


func close_workshop() -> void:
	GameStateWorkshopDelegate.close_workshop(self)


func get_purchased_count(upgrade_id: StringName) -> int:
	return GameStateWorkshopDelegate.get_purchased_count(self, upgrade_id)


## 🔴 500行ルール対応。以下のテスト専用API群は実装本体をgame_state_test_support.gd
## （GameStateTestSupport）へ委譲する。公開シグネチャ・呼び出し方法はテストコード側から見て変更しない


## テスト専用。実.tresロードを介さずSeedMaster/MaterialMasterを直接注入する（🟡 CON-005対応）
func _set_masters_for_test(seeds: Dictionary, materials: Dictionary) -> void:
	GameStateTestSupport.set_masters(self, seeds, materials)


## 🔴 テスト専用。seed_inventoryを実プレイの操作を介さず直接注入する
func _set_seed_inventory_for_test(seed_inventory: Array[Dictionary]) -> void:
	GameStateTestSupport.set_seed_inventory(self, seed_inventory)


## 🔴 テスト専用。plant_seed()を経由せずgarden_state.plantsへ株を直接追加する
func _inject_plant_for_test(plant_state: PlantState) -> void:
	GameStateTestSupport.inject_plant(self, plant_state)


## 🟡 テスト専用。実.tresロードを介さずRecipeMasterを直接注入する（CON-005対応）
func _set_recipe_masters_for_test(masters: Dictionary) -> void:
	GameStateTestSupport.set_recipe_masters(self, masters)


## 🔴 テスト専用。unlocked_recipe_idsをランク進行を介さず直接注入する（AC-009検証用）
func _set_unlocked_recipe_ids_for_test(ids: Array[StringName]) -> void:
	GameStateTestSupport.set_unlocked_recipe_ids(self, ids)


## 🔴 テスト専用。alchemy_slot_countを工房強化を介さず直接注入する（AC-007境界値検証用）
func _set_alchemy_slot_count_for_test(count: int) -> void:
	GameStateTestSupport.set_alchemy_slot_count(self, count)


## 🟡 テスト専用。実.tresロードを介さずRankMasterを直接注入する（FR-301）
func _set_rank_masters_for_test(masters: Dictionary) -> void:
	GameStateTestSupport.set_rank_masters(self, masters)


## 🟡 テスト専用。current_rank_idを昇格・降格を介さず直接注入する（FR-301）
func _set_current_rank_id_for_test(rank_id: StringName) -> void:
	GameStateTestSupport.set_current_rank_id(self, rank_id)


## 🟡 テスト専用。rank_stateをターン進行を介さず直接注入する（FR-301）
func _set_rank_state_for_test(state: RankState) -> void:
	GameStateTestSupport.set_rank_state(self, state)


## 🟡 テスト専用。demotion_countを降格処理を介さず直接注入する（FR-301）
func _set_demotion_count_for_test(count: int) -> void:
	GameStateTestSupport.set_demotion_count(self, count)


## 🔴 テスト専用。deliver_pending_products()を経由せず本日の指定調合物を直接注入する（FR-301, AC-008）
func _set_current_daily_order_for_test(order: DailyOrderMaster) -> void:
	GameStateTestSupport.set_current_daily_order(self, order)


## 🔴 テスト専用。harvest()/execute_alchemy()を経由せずinventoryへ素材を直接注入する
func _inject_material_for_test(material: MaterialInstance) -> void:
	GameStateTestSupport.inject_material(self, material)


## 🔴 テスト専用。execute_alchemy()を経由せず納品待ちキューへ調合物を直接注入する
func _inject_pending_product_for_test(product: ProductInstance) -> void:
	GameStateTestSupport.inject_pending_product(self, product)


## 🟡 テスト専用。試験開始処理（後続task）を経由せずexam_state/in_examを直接注入する（CON-008委譲パターン）
func _set_exam_state_for_test(exam_state: ExamState, in_exam: bool = true) -> void:
	GameStateTestSupport.set_exam_state(self, exam_state, in_exam)


## 🔵 テスト専用。can_purchase_permanentを工房強化画面の開閉操作を介さず直接注入する（FR-012）
func _set_can_purchase_permanent_for_test(value: bool) -> void:
	GameStateTestSupport.set_can_purchase_permanent(self, value)


## 🔵 テスト専用。purchased_upgrade_countsをapply_upgrade()を介さず直接注入する（FR-013）
func _set_purchased_upgrade_counts_for_test(counts: Dictionary) -> void:
	GameStateTestSupport.set_purchased_upgrade_counts(self, counts)


## 🔴 テスト専用。goldをdeliver_pending_products()を介さず直接注入する
## （apply_upgrade()の所持ゴールド境界値テスト用の新規補完）
func _set_gold_for_test(gold: int) -> void:
	GameStateTestSupport.set_gold(self, gold)


# テスト分離専用。デバッグビルドガードは他のテスト専用API群と同じくGameStateTestSupport.guard()
# へ一元化する（🔴 コードレビュー指摘対応。以前は本関数だけ独自にassert+push_error+returnを
# 重複実装していた）
func reset_for_test() -> void:
	if not GameStateTestSupport.guard("reset_for_test"):
		return
	_current_phase = &"garden"
	_gold = 0
	_current_turn = 1
	_garden_state = GardenState.new()
	_seed_inventory = [
		{"seed_id": GameBalance.INITIAL_SEED_ID, "count": GameBalance.INITIAL_SEED_COUNT}
	]
	_inventory = []
	_seed_masters = {}
	_material_masters = {}
	_material_instance_seq = 0
	_garden_slot_count = GameBalance.GARDEN_SLOT_COUNT
	_recipe_masters = {}
	_unlocked_recipe_ids = [GameBalance.INITIAL_RECIPE_ID]
	_pending_products = []
	_alchemy_slot_count = GameBalance.ALCHEMY_SLOT_COUNT_DEFAULT
	_current_daily_order = null
	_current_rank_id = GameBalance.INITIAL_RANK_ID
	_rank_masters = {}
	_rank_state = RankState.new()
	_demotion_count = 0
	_last_rank_outcome = RankOutcome.Value.CONTINUE
	_rank_state_initialized = false
	_warned_missing_rank_master_ids = {}
	_in_exam = false
	_exam_state = ExamState.new()
	_last_exam_outcome = ExamOutcome.Value.CONTINUE
	_has_cleared_game = false
	_can_purchase_permanent = false
	_purchased_upgrade_counts = {}
	_upgrade_masters = {}
