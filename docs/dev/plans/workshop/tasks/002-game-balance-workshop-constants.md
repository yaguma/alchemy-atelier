---
id: "002"
title: "GameBalanceに工房強化・ショップ関連定数を追加する"
status: pending
priority: 1
dependencies: []
estimated_complexity: low
---

# Task: GameBalanceに工房強化・ショップ関連定数を追加する

## Goal

5種類のUpgradeMaster（投入枠+1／庭拡張／レシピ解禁／触媒常備／種の指名買い）の価格・`max_purchase_count`・`effect_value`、および第2レシピのIDを`GameBalance`定数として追加する（FR-008）。

## Interfaces

```gdscript
# atelier/shared/constants/game_balance.gd に追記

# --- 工房強化・ショップ（workshop）関連定数 ---
# CON-006: 以下は全て仮値。balance-tuning-cycleスキルによる後日再調整を前提とする

const WORKSHOP_ALCHEMY_SLOT_PRICE := 2000                    # 🟡 FR-008。序列上最高額
const WORKSHOP_ALCHEMY_SLOT_EFFECT_VALUE := 1                # 🟡 FR-008
const WORKSHOP_ALCHEMY_SLOT_MAX_PURCHASE_COUNT := 1          # 🟡 FR-008

const WORKSHOP_GARDEN_SLOT_PRICE := 800                      # 🟡 FR-008
const WORKSHOP_GARDEN_SLOT_EFFECT_VALUE := 1                 # 🟡 FR-008
const WORKSHOP_GARDEN_SLOT_MAX_PURCHASE_COUNT := 3           # 🔴→🟡 要件に上限指定なし、仮値として3を採用

const WORKSHOP_RECIPE_UNLOCK_PRICE := 800                    # 🟡 FR-008
const WORKSHOP_RECIPE_UNLOCK_MAX_PURCHASE_COUNT := 1         # 🔵 effect_valueが単一レシピID固定のため1が論理的必然

const WORKSHOP_CATALYST_STOCK_PRICE := 150                   # 🟡 FR-008
const WORKSHOP_CATALYST_STOCK_MAX_PURCHASE_COUNT := 999      # 🔵 AC-001「実質無制限」要件に対応

const WORKSHOP_SEED_NAME_PURCHASE_PRICE := 50                # 🟡 FR-008
const WORKSHOP_SEED_NAME_PURCHASE_MAX_PURCHASE_COUNT := 999  # 🔵 AC-001「実質無制限」要件に対応

# FR-007: recipe_unlock購入対象となる第2レシピのID（既存INITIAL_RECIPE_IDと対の定数）
const SECOND_RECIPE_ID: StringName = &"recipe_mana_tonic"    # 🔵 タスク004と対応

# FR-016: catalyst_stock購入で生成するMaterialInstanceのmaterial_id
const CATALYST_MATERIAL_ID: StringName = &"material_catalyst"  # 🔵 タスク005と対応
```

価格序列の検証: `WORKSHOP_ALCHEMY_SLOT_PRICE(2000) > WORKSHOP_GARDEN_SLOT_PRICE(800) == WORKSHOP_RECIPE_UNLOCK_PRICE(800) > WORKSHOP_CATALYST_STOCK_PRICE(150) > WORKSHOP_SEED_NAME_PURCHASE_PRICE(50)`。requirements.md §4「価格序列: 投入枠+1 ≫ 庭拡張≒レシピ解禁 ＞ 触媒 ＞ 種の指名買い」を満たす。

## Test Strategy

設定変更（Directモード対象、`.claude/rules/implement-workflow.md`「Directモード」の「型定義のみの変更」に準拠）のため専用テストは不要。価格序列は上記数値検証で確認済み。後続タスク（006, 008, 009）のテストがこれらの定数を実値として使用することで間接的に検証される。

- [ ] `gdlint`/`gdformat --check`が通過する
- [ ] 既存`CATALYST_BASE_QUALITY_SCORE`（L41）等、他の定数定義スタイル（コメント＋信号機マーカー）と一貫している

## Implementation Notes

- 参照すべき既存コード: `atelier/shared/constants/game_balance.gd`全体（命名規則・コメント規約・信号機マーカーの付け方）
- 実装のヒント: 既存の「--- ランク進行（rank）関連定数 ---」セクション区切りコメントと同じ形式で「--- 工房強化（workshop）関連定数 ---」セクションをファイル末尾に追加する
- 注意事項: `CATALYST_BASE_QUALITY_SCORE`（既存L41、コメントに「本plan内では未消費」と明記済み）は変更不要。本plan（タスク009）で初めて実消費されるだけなので、コメントの「未消費」の記述を「タスク009 apply_upgrade()で実消費」等に更新するのが望ましい（任意）

## Files

- 変更: `atelier/shared/constants/game_balance.gd`
