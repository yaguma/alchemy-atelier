---
id: "003"
title: "GameBalanceにランク進行関連定数を追加する"
status: pending
priority: 1
dependencies: []
estimated_complexity: low
---

# Task: GameBalanceにランク進行関連定数を追加する

## Goal

`shared/constants/game_balance.gd`にゲームオーバー閾値`MAX_DEMOTION_COUNT`と初期ランクID`INITIAL_RANK_ID`を追加する。マジックナンバーの直書きを避ける。

## Interfaces

```gdscript
# shared/constants/game_balance.gd（既存ファイルへの追記）

const MAX_DEMOTION_COUNT := 3  # 🟡 FR-007, CON-007（spec/requirements.md §7「仮3」を採用した暫定値）
const INITIAL_RANK_ID: StringName = &"rank_g"  # 🔴 新規補完。INITIAL_SEED_ID/INITIAL_RECIPE_IDと同型の初期値パターン
```

> 信号機: 🟡 `MAX_DEMOTION_COUNT`は既存文書の推奨値をそのまま採用。🔴 `INITIAL_RANK_ID`は本plan内での新規補完（既存の`INITIAL_SEED_ID`/`INITIAL_RECIPE_ID`と同型のパターン踏襲）

## Test Strategy

- [ ] 正常系: `GameBalance.MAX_DEMOTION_COUNT == 3`であることを確認する
- [ ] 正常系: `GameBalance.INITIAL_RANK_ID == &"rank_g"`であり、型が`StringName`であることを確認する

## Implementation Notes

- 参照すべき既存コード: `atelier/shared/constants/game_balance.gd`の`INITIAL_SEED_ID`・`INITIAL_RECIPE_ID`（初期値定数の命名・型パターン）
- 実装のヒント: 既存の調合・ギルド関連定数の直後など、論理的にまとまった位置に追記する
- 注意事項: `INITIAL_RANK_ID`の実際の値（`"rank_g"`）は`res://data/ranks/`に対応する`.tres`が存在しない前提（CON-006）のため、本plan内のテストでは`_set_rank_masters_for_test()`（タスク007）で同名IDのフィクスチャを注入して整合させる

## Files

- 変更: `atelier/shared/constants/game_balance.gd`
- テスト: `atelier/tests/unit/shared/test_game_balance_rank.gd`
