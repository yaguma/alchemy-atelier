---
id: "003"
title: "GameBalanceに調合関連定数を追加する"
status: pending
priority: 1
dependencies: []
estimated_complexity: low
---

# Task: GameBalanceに調合関連定数を追加する

## Goal

調合計算で使う定数（品質倍率テーブル・特性発現閾値・特性ボーナス倍率・触媒基準品質・投入枠初期値・初期解禁レシピID）を`shared/constants/game_balance.gd`の`GameBalance`に追記する。既存の庭関連定数は変更しない。

## Interfaces

```gdscript
# shared/constants/game_balance.gd（既存ファイルへの追記）

# --- 調合（alchemy）関連定数 ---
const ALCHEMY_SLOT_COUNT_DEFAULT := 4
const QUALITY_MULTIPLIER_TABLE := {1: 1.0, 2: 1.25, 3: 1.5, 4: 1.75, 5: 2.0}
const TRAIT_ACTIVATION_THRESHOLD := 2
const CATALYST_BASE_QUALITY_SCORE := 3
const TRAIT_CONTRIBUTION_BONUS := {&"holy": 1.3, &"purify": 1.3, &"heal": 1.3}
const TRAIT_REWARD_BONUS := {&"gold": 1.3, &"glamour": 1.3, &"rare": 1.3}
const INITIAL_RECIPE_ID: StringName = &"recipe_healing_potion"
```

> 信号機: 🔴 FR-005（ユーザーヒアリングで確定済みの仮値。バランス調整サイクルで後日上書き前提）。`INITIAL_RECIPE_ID`のみ🔵（CON-008、`data-schema.md`のサンプル値を流用）

## Test Strategy

- [ ] 正常系: `GameBalance.QUALITY_MULTIPLIER_TABLE[3]`が`1.5`である
- [ ] 正常系: `GameBalance.TRAIT_CONTRIBUTION_BONUS[&"holy"]`と`GameBalance.TRAIT_REWARD_BONUS[&"gold"]`がそれぞれ`1.3`である
- [ ] エッジケース: `QUALITY_MULTIPLIER_TABLE`が品質1〜5すべてのキーを持ち、値が単調非減少（`table[1] <= table[2] <= ... <= table[5]`）である
- [ ] エッジケース: 既存の庭関連定数（`GARDEN_SLOT_COUNT`等）が変更されていないことを確認する（回帰確認）

## Implementation Notes

- 参照すべき既存コード: `atelier/shared/constants/game_balance.gd`（既存の庭定数のコメントスタイル: どの設計文書のどの箇所に対応するか・信号機・TBDである旨を明記）
- 実装のヒント: 既存ファイル末尾に「--- 調合（alchemy）関連定数 ---」というセクションコメントを付けて追記する。各定数に`core-systems.md`/`requirements.md`§5の対応箇所と🔴マークをコメントで付与する
- 注意事項: `TRAIT_CONTRIBUTION_BONUS`/`TRAIT_REWARD_BONUS`のキーは`StringName`（`&"holy"`等）。`CATALYST_BASE_QUALITY_SCORE`は本plan内では未消費（WorkshopSystem別planでの参照用の前方定義）だが、`gdlint`で未使用警告が出ないか実装時に確認する

## Files

- 変更: `atelier/shared/constants/game_balance.gd`
- テスト: `atelier/tests/unit/shared/test_game_balance_alchemy.gd`
