---
id: "003"
title: "GameBalanceに庭関連の定数を追加する"
status: done
priority: 1
dependencies: []
estimated_complexity: low
---

# Task: GameBalanceに庭関連の定数を追加する

## Goal

庭機能で使用するバランス数値をマジックナンバーとして直書きせず、`shared/constants/game_balance.gd`の`GameBalance`に定数として定義する（FR-005）。`shared/constants/game_balance.gd`自体が未作成（`.gitkeep`のみ）のため、本タスクで新規作成する。

## Interfaces

```gdscript
# shared/constants/game_balance.gd
class_name GameBalance

# balance-design.md §71 🟡TBD仮5。実行時権威は player.permanent_upgrades.garden_slot_count（FR-006）。
# 本定数はゲーム開始時の初期値としてのみ使用する
const GARDEN_SLOT_COUNT := 5  # 🔵 FR-005/FR-006, balance-design.md L71

# balance-design.md §73 🟡TBD仮2。SeedMaster.death_grace_turnsのデフォルト値（マスターデータ作成の参考値、実行時はSeedMaster側の値を優先）
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
```

## Test Strategy

本タスクはDirectモード（定数定義のみ、実行時ロジックを持たない）のため専用テストファイルは作成しない。以下をレビュー観点として確認する。

- [ ] 全定数に型注釈が付いている（`Variant`の無条件使用がない）
- [ ] `gdlint`/`gdformat --check`が通る
- [ ] マジックナンバーとしてコード直書きされている箇所が他タスクに存在しない（後続タスクの実装時にレビューで確認）

## Implementation Notes

- 参照すべき既存コード: `docs/design/atelier-alchemy-core/balance-design.md` L69-75（庭関連の仮値一覧）、`.claude/rules/coding-style.md`「定数管理: GameBalance vs UiTheme」
- 実装のヒント: 各定数に元となった設計文書の行番号・信頼性レベルをコメントで併記する（上記Interfacesのコメントをそのまま踏襲してよい）
- 注意事項: `GameBalance`の値を`UiTheme`から参照しない。`shared/constants/game_balance.gd`は他Feature（alchemy/guild等）からも将来参照される共有定数ファイルのため、庭関連以外の定数を本タスクで追加しないこと（スコープ外）

## Files

- 新規: `atelier/shared/constants/game_balance.gd`
