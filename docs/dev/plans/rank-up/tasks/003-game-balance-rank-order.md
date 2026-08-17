---
id: "003"
title: "GameBalanceにRANK_ORDER定数を追加する"
status: done
priority: 1
dependencies: []
estimated_complexity: low
---

# Task: GameBalanceにRANK_ORDER定数を追加する

## Goal

ランクIDの昇格順序を表す`GameBalance.RANK_ORDER`定数を追加し、次ランク判定ロジック（タスク004）が参照できるようにする。

## Interfaces

```gdscript
# shared/constants/game_balance.gd（既存ファイルへの追加）
const RANK_ORDER: Array[StringName] = [  # 🔵 FR-007
    &"rank_g", &"rank_f", &"rank_e", &"rank_d", &"rank_c", &"rank_b", &"rank_a", &"rank_s"
]
```

> 信号機: 🔵 ユーザーヒアリングで確定。既存`INITIAL_RANK_ID := &"rank_g"`の命名規則（`rank_*`のsnake_case）と整合。

## Test Strategy

- [ ] `RANK_ORDER[0] == &"rank_g"`（先頭が初期ランクと一致）
- [ ] `RANK_ORDER[7] == &"rank_s"`（末尾がSランク）
- [ ] `RANK_ORDER.size() == 8`
- [ ] `RANK_ORDER`内に重複したランクIDが存在しない
- [ ] 境界値: `RANK_ORDER[0] == GameBalance.INITIAL_RANK_ID`（既存定数との整合性）

## Implementation Notes

- 参照すべき既存コード: `atelier/shared/constants/game_balance.gd`（L64付近の`INITIAL_RANK_ID`定義に隣接して追加）
- 実装のヒント: 既存定数のフォーマット（コメントでバランス設計書セクション対応を記載する規約、`coding-style.md`参照）に従う
- 注意事項: 他Feature（garden/alchemy/guild）の既存定数は変更しない（CON-003相当の既存rank plan制約を踏襲）

## Files

- 変更: `atelier/shared/constants/game_balance.gd`
- テスト: `atelier/tests/unit/shared/test_game_balance_rank.gd`（既存ファイルへのテストケース追記）
