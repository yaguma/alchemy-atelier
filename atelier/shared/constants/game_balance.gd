class_name GameBalance

## ゲームバランスに影響するパラメータを集約する静的定数クラス（coding-style.md「定数管理: GameBalance vs UiTheme」参照）。
## UIの見た目に関するパラメータはUiTheme（shared/theme/theme.gd）側に定義し、本クラスからは参照しない。

# balance-design.md L71 🟡TBD仮5。実行時権威はplayer.permanent_upgrades.garden_slot_count（FR-006）。
# 本定数はゲーム開始時の初期値としてのみ使用する
const GARDEN_SLOT_COUNT := 5  # 🔵 FR-005/FR-006, balance-design.md L71

# balance-design.md L73 🟡TBD仮2。SeedMaster.death_grace_turnsのデフォルト値
# （マスターデータ作成の参考値、実行時はSeedMaster側の値を優先）
const DEATH_GRACE_TURNS_DEFAULT := 2  # 🔵 FR-005, balance-design.md L73

# core-systems.md L76 🟡TBD、ヒアリング結果でユーザーが仮値0.3の採用を確認済み
const QUALITY_UP_CHANCE := 0.3  # 🔵 FR-005/FR-107

# data-schema.md quality_score定義（1〜5、S=5が上限）
const QUALITY_SCORE_MIN := 1  # 🔵 FR-107
const QUALITY_SCORE_MAX := 5  # 🔵 FR-107

# FR-204「枯死猶予ターンの残り僅少」の閾値。具体値はFR-204自体が🟡TBDとしているため本タスクで仮決めする
const WITHER_WARNING_REMAINING_TURNS := 1  # 🔴 FR-204（設計時点で未確定だった具体値の新規補完）

# CON-007/CON-008: 初期手持ち種セット
const INITIAL_SEED_ID: StringName = &"seed_herb"  # 🔵 CON-007, AC-011
const INITIAL_SEED_COUNT := 2  # 🔵 CON-007, AC-011

# --- 調合（alchemy）関連定数 ---

# core-systems.md AlchemySystem「投入枠」。実行時権威はplayer.permanent_upgrades側にあり、
# 本定数はゲーム開始時の初期値としてのみ使用する
const ALCHEMY_SLOT_COUNT_DEFAULT := 4  # 🔴 FR-005, core-systems.md AlchemySystem

# requirements.md §5 品質→価値倍率。品質スコア1〜5に対して単調非減少であることが前提
const QUALITY_MULTIPLIER_TABLE := {1: 1.0, 2: 1.25, 3: 1.5, 4: 1.75, 5: 2.0}  # 🔴 FR-005

# 同一特性タグが投入素材中にこの本数以上あると特性が発現する
const TRAIT_ACTIVATION_THRESHOLD := 2  # 🔴 FR-005, core-systems.md AlchemySystem

# 触媒効果の基準となる品質スコア。タスク009のWorkshopSystem.apply_upgrade()で実消費する
const CATALYST_BASE_QUALITY_SCORE := 3  # 🔴 FR-005

# 貢献度向き特性の倍率。報酬向きとキーが重複しないことが「真のトレードオフ」の前提（atelier-concept.md v7.0）
const TRAIT_CONTRIBUTION_BONUS := {&"holy": 1.3, &"purify": 1.3, &"heal": 1.3}  # 🔴 FR-005

# 報酬向き特性の倍率
const TRAIT_REWARD_BONUS := {&"gold": 1.3, &"glamour": 1.3, &"rare": 1.3}  # 🔴 FR-005

# CON-008: 初期解禁レシピ（data-schema.mdのサンプル値を流用）
const INITIAL_RECIPE_ID: StringName = &"recipe_healing_potion"  # 🔵 CON-008

# --- ギルド納品（guild）関連定数 ---

# 指定合致ボーナス倍率の既定値。DeliveryResolverはDailyOrderMaster.match_bonus_multiplier側を
# 参照するため（CON-006）、本定数はマスターデータ（.tres）作成時・テストフィクスチャの既定値に留まる
const DAILY_ORDER_MATCH_BONUS_MULTIPLIER := 1.3  # 🔵 FR-004/CON-006, requirements.md §5

# --- ランク進行（rank）関連定数 ---

# 降格がこの回数に達した時点でゲームオーバーとする（requirements.md §7「仮3」を採用した暫定値）
const MAX_DEMOTION_COUNT := 3  # 🟡 FR-007/CON-007, requirements.md §7

# ゲーム開始時のランク。対応する.tresは未作成（CON-006）のため、テストではフィクスチャを注入する
const INITIAL_RANK_ID: StringName = &"rank_g"  # 🔴 新規補完（INITIAL_SEED_ID/INITIAL_RECIPE_ID同型）

# ランクIDの昇格順序。次ランク判定はこの配列のindex+1で解決するため、G→Sの昇順を崩さないこと
const RANK_ORDER: Array[StringName] = [  # 🔵 FR-007
	&"rank_g",
	&"rank_f",
	&"rank_e",
	&"rank_d",
	&"rank_c",
	&"rank_b",
	&"rank_a",
	&"rank_s",
]

# --- 工房強化（workshop）関連定数 ---
# CON-006: 以下は全て仮値。balance-tuning-cycleスキルによる後日再調整を前提とする

const WORKSHOP_ALCHEMY_SLOT_PRICE := 2000  # 🟡 FR-008。序列上最高額
const WORKSHOP_ALCHEMY_SLOT_EFFECT_VALUE := 1  # 🟡 FR-008
const WORKSHOP_ALCHEMY_SLOT_MAX_PURCHASE_COUNT := 1  # 🟡 FR-008

const WORKSHOP_GARDEN_SLOT_PRICE := 800  # 🟡 FR-008
const WORKSHOP_GARDEN_SLOT_EFFECT_VALUE := 1  # 🟡 FR-008
const WORKSHOP_GARDEN_SLOT_MAX_PURCHASE_COUNT := 3  # 🔴→🟡 要件に上限指定なし、仮値として3を採用

const WORKSHOP_RECIPE_UNLOCK_PRICE := 800  # 🟡 FR-008
const WORKSHOP_RECIPE_UNLOCK_MAX_PURCHASE_COUNT := 1  # 🔵 effect_valueが単一レシピID固定のため1が論理的必然

const WORKSHOP_CATALYST_STOCK_PRICE := 150  # 🟡 FR-008
const WORKSHOP_CATALYST_STOCK_MAX_PURCHASE_COUNT := 999  # 🔵 AC-001「実質無制限」要件に対応

const WORKSHOP_SEED_NAME_PURCHASE_PRICE := 50  # 🟡 FR-008
const WORKSHOP_SEED_NAME_PURCHASE_MAX_PURCHASE_COUNT := 999  # 🔵 AC-001「実質無制限」要件に対応

# FR-007: recipe_unlock購入対象となる第2レシピのID（既存INITIAL_RECIPE_IDと対の定数）
const SECOND_RECIPE_ID: StringName = &"recipe_mana_tonic"  # 🔵 タスク004と対応

# FR-016: catalyst_stock購入で生成するMaterialInstanceのmaterial_id
const CATALYST_MATERIAL_ID: StringName = &"material_catalyst"  # 🔵 タスク005と対応
