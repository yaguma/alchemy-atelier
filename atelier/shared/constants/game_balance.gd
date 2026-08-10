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
