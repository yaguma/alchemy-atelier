# =============================================================================
# interfaces.gd
# atelier-alchemy-core 技術設計 — 主要インターフェース/契約のスケッチ
# 準拠: docs/spec/atelier-alchemy-core/requirements.md
#       docs/design/atelier-alchemy-core/core-systems.md
#
# 注記:
#  - 本ファイルは「設計上の契約」を GDScript の型注釈で示すスケッチであり、
#    そのままコンパイル・実行することを目的としない（実装は atelier-godot/ で行う）。
#  - GDScript には interface 構文がないため、Domain層は static func の
#    シグネチャ、Application層は class の公開APIとして表現する。
#  - 信頼性: 🔵要件準拠 / 🟡妥当な推測 / 🔴新規推測
# =============================================================================


# -----------------------------------------------------------------------------
# 共通の型・列挙（enum / 型エイリアスのイメージ）
# -----------------------------------------------------------------------------
# ランク: 文字列 "G".."S" で扱う（enum 化は実装時判断）🔵
# 品質スコア: int 1..5（D..S）🔵
# 特性系統: "contribution" / "reward" / "support" 🔵


# -----------------------------------------------------------------------------
# Domain: AlchemySystem（調合・★核心）  features/alchemy/logic/
# すべて副作用なしの static func 🔵
# -----------------------------------------------------------------------------
class QualityLogic:
	# 投入素材の平均品質（1..5）。旧 calculateQuality の仕様を再実装 🔵
	static func average_quality(materials: Array) -> int:
		return 0

	# 品質倍率。旧 calculateAverageQualityMultiplier の仕様を再実装 🟡
	static func quality_multiplier(avg_quality: int) -> float:
		return 1.0


class TraitLogic:
	# 投入素材の特性タグを集計（trait_id -> 個数）🔵
	static func count_by_trait(materials: Array) -> Dictionary:
		return {}

	# 同一タグ2個以上で発現、3個目以降は据え置き（確定仕様）🔵
	static func resolve_traits(materials: Array) -> Array:
		return []

	# 最低1個以上投入されているか（0個は実行不可）🔵
	static func can_craft(slots: Array) -> bool:
		return false


# -----------------------------------------------------------------------------
# Domain: GuildSystem（納品・決算）  features/guild/logic/
# -----------------------------------------------------------------------------
class ContributionRewardLogic:
	# 貢献度 = 基礎貢献度 × 品質倍率 × 貢献度系特性ボーナス × 指定合致ボーナス 🔵
	static func calc_contribution(product, daily_spec, balance) -> int:
		return 0

	# 報酬 = 基礎報酬 × 品質倍率 × 報酬系特性ボーナス × 指定合致ボーナス 🔵
	static func calc_reward(product, daily_spec, balance) -> int:
		return 0

	# 本日の指定調合物（品目 or 特性傾向）に合致するか 🔵
	static func is_spec_matched(product, daily_spec) -> bool:
		return false


# -----------------------------------------------------------------------------
# Domain: GardenSystem（庭・仕込み）  features/garden/logic/
# 乱数は引数 roll で受け取る（Functional Core 原則・期待値不動）🔵
# -----------------------------------------------------------------------------
class GardenLogic:
	# 全スロットの生育をターン分進め、枯死判定を反映 🔵
	static func advance_growth(plots: Array, elapsed: int) -> Array:
		return plots

	# 成熟後経過ターンと乱数から収穫品質（1..5）を確定 🟡
	static func resolve_harvest_quality(plot: Dictionary, roll: float) -> int:
		return 1

	# 種の狙い特性テーブルと分散乱数から付与特性を1つ決定（無しもあり得る）🔵
	static func roll_trait(seed_master, roll: float):
		return null

	# 枯死猶予ターン超過判定 🔵
	static func is_withered(plot: Dictionary, current_turn: int) -> bool:
		return false

	# 空きスロット有無 🔵
	static func can_plant(plots: Array, slot_limit: int) -> bool:
		return false


# -----------------------------------------------------------------------------
# Domain: RankSystem（ランク進行）  features/rank/logic/
# -----------------------------------------------------------------------------
class RankLogic:
	# HP減算（max(0, hp - contribution)・オーバーキル切捨）🔵
	static func apply_contribution(hp: int, contribution: int) -> int:
		return max(0, hp - contribution)

	# 制限ターン到達時の結末: "continue" / "exam" / "demote" 🔵
	static func evaluate_turn_end(hp: int, remaining_turns: int) -> String:
		return "continue"

	# 昇格先ランク（"S" のときは "CLEAR" を返す想定）🔵
	static func next_rank(rank: String) -> String:
		return rank

	# 降格回数が上限到達か（ゲームオーバー判定）🔵
	static func is_game_over(demotion_count: int, limit: int) -> bool:
		return demotion_count >= limit


# -----------------------------------------------------------------------------
# Domain: WorkshopSystem（工房強化・ショップ）  features/workshop/logic/
# -----------------------------------------------------------------------------
class ShopLogic:
	# 所持ゴールドが価格以上か 🔵
	static func can_purchase(gold: int, price: int) -> bool:
		return gold >= price

	# 価格序列に基づく価格取得 🔵
	static func price_of(item_id: String, balance) -> int:
		return 0


# -----------------------------------------------------------------------------
# Application: GameState（Autoload・唯一の可変状態）
# 公開APIと signal の契約 🟡（signal 名は architecture.md と対応）
# -----------------------------------------------------------------------------
class IGameState:
	# --- signal（通知）---
	# signal phase_changed(new_phase)
	# signal turn_advanced(turn, remaining_turns)
	# signal rank_hp_changed(previous, current, delta)
	# signal gold_changed(previous, current, delta)
	# signal product_delivered(product, contribution, reward, matched)
	# signal rank_cleared(rank)
	# signal rank_demoted(rank, demotion_count)
	# signal game_over(rank)
	# signal game_cleared()

	# --- 庭 ---
	func plant_seed(slot_index: int, seed_id: String) -> void: pass
	func harvest(slot_index: int) -> void: pass

	# --- 調合 ---
	func place_material(slot_index: int, instance_id: String) -> void: pass
	func remove_material(slot_index: int) -> void: pass
	func execute_craft() -> void: pass   # can_craft 検証 → 品質/特性確定 → 自動納品

	# --- ショップ（消耗投資: ターン中いつでも）---
	func buy_seed(seed_id: String) -> bool: pass
	func buy_catalyst() -> bool: pass

	# --- 工房強化（恒久投資: 工房強化画面のみ）---
	func apply_permanent_upgrade(upgrade_id: String) -> bool: pass

	# --- ターン/進行 ---
	func end_turn() -> void: pass         # 庭の生育進行 → 制限ターン判定


# -----------------------------------------------------------------------------
# Application: RngService（Autoload・シード管理された乱数供給）🔵
# -----------------------------------------------------------------------------
class IRngService:
	func seed_with(value: int) -> void: pass
	func next_float() -> float: return 0.0   # 収穫特性の分散乱数（期待値不動）
	func next_int(max_exclusive: int) -> int: return 0


# -----------------------------------------------------------------------------
# PromotionExamSystem（昇格試験）🟡 TBD — 境界のみ
# 内部ルール・演出・敗北条件は別途設計（requirements.md 2章/7章）
# -----------------------------------------------------------------------------
class IPromotionExam:
	# 入力: 現在ランク・プレイヤー状態 / 出力: 成功可否
	func run(rank: String, state) -> bool: return false
