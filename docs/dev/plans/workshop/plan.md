# Plan: workshop

## Requirements Summary

`WorkshopSystem`（工房強化・ショップ）のDomain層基盤（`PurchaseValidator`, `UpgradeMaster`）と`GameState`統合（`apply_upgrade()`, `close_workshop()`, `get_purchased_count()`, `load_workshop_master_data()`）を実装する。ゴールドで恒久投資（投入枠+1／庭拡張／レシピ解禁、ランク間限定・購入任意）と消耗投資（触媒常備／種の指名買い、ターン中いつでも）を購入する機能。UI（`WorkshopScreen`）は本plan外。

詳細: [requirements.md](requirements.md)（FR 40件） | [user-stories.md](user-stories.md)（US 10件） | [acceptance-criteria.md](acceptance-criteria.md)（AC 18件）

赤信号は全てユーザーヒアリングで解消済み（0件）。

## Design Overview

Plan サブエージェントによるインターフェース設計を実施済み（本セクションはその要約。詳細な擬似コード・`.tres`内容は各タスクファイル参照）。

- `PurchaseValidator`（`features/workshop/logic/purchase_validator.gd`）: `can_purchase()`/`is_permanent_upgrade()`の2つのstatic純粋関数
- `UpgradeMaster`（`features/workshop/resources/upgrade_master.gd`）: `Resource`継承、7フィールド（`id`/`name`/`is_permanent`/`price`/`effect_type`/`effect_value`/`max_purchase_count`）
- `GameState`統合: 新規フィールド3件（`_can_purchase_permanent`, `_purchased_upgrade_counts`, `_upgrade_masters`）、新規メソッド4件（`apply_upgrade()`, `close_workshop()`, `get_purchased_count()`, `load_workshop_master_data()`）、既存`_commit_exam_success()`冒頭への1行追加、`get_state()`/`reset_for_test()`への統合、テスト専用API2件
- マスターデータ: `UpgradeMaster` 5件・`RecipeMaster`（第2レシピ）1件・`MaterialMaster`（`material_catalyst`）1件の新規`.tres`
- `MasterDataLoader`への`&"upgrades"`カテゴリ追加（既存`&"recipes"`実装パターンの横展開）
- `GameBalance`への価格・`max_purchase_count`・`effect_value`定数追加（価格序列: 投入枠+1(2000) ≫ 庭拡張(800)≒レシピ解禁(800) ＞ 触媒(150) ＞ 種の指名買い(50)、全て🟡仮値でCON-006によりbalance-tuning-cycle後日再調整前提）

検証済み事項: `game_state.gd`は現状710行、本plan追加分（約120〜150行見込み）を加えても`.gdlintrc`の`max-file-lines: 1000`には収まる。パブリックメソッド数も15→19件で`max-public-methods: 20`以内。

## Task Dependency Graph

トポロジカル順（並行実施可能なものは同一グループ）:

```
グループ1（依存なし、並行可）: 001, 002, 004, 005
グループ2: 003(dep:001), 007(dep:001)
グループ3: 006(dep:001,002,004)
グループ4: 008(dep:003,007)
グループ5: 009(dep:008), 010(dep:006,007)
```

| タスク | 依存 |
|---|---|
| 001 UpgradeMaster型定義 | - |
| 002 GameBalance定数追加 | - |
| 003 PurchaseValidator実装 | 001 |
| 004 第2レシピ.tres新規作成 | - |
| 005 material_catalyst.tres新規作成 | - |
| 006 MasterDataLoader upgrades対応+5件.tres | 001, 002, 004 |
| 007 GameStateフィールド基盤+get_state/reset_for_test+テスト専用API | 001 |
| 008 GameState.apply_upgrade()共通検証・ゴールド減算・シグナル発行 | 003, 007 |
| 009 GameState.apply_upgrade()のeffect_type別状態反映5種 | 008 |
| 010 GameState.close_workshop()/get_purchased_count()/load_workshop_master_data()/_commit_exam_success統合 | 006, 007 |

## 検証結果（task-breakdown Phase 4）

- MECE（漏れ・重複なし）: ✅ FR-001〜FR-018・FR-101〜FR-115・FR-201〜FR-203・FR-401〜FR-404の全40件が001〜010いずれかのタスクに1対1（一部FR-011・FR-015/111のみ2タスクに跨るが役割分担で重複作業なし）で対応
- 依存関係（循環なし・順序が成立）: ✅ 上表の通り。循環なし
- 各葉にDoDあり: ✅ 全タスクの`## Test Strategy`がAC-001〜AC-018のGiven/When/Thenに対応するチェックリストを持つ
- 粒度が揃っている: ✅ low 4件（001,002,004,005）/ medium 5件（003,006,007,008,010）/ high 1件（009、5種類のeffect_type分岐を含むため意図的に大きい。rank-up planの前例でも同様の粒度差は許容されている）
- 実行順序（トポロジカル順の目安）: 001 → 002 → 004 → 005 → 003 → 007 → 006 → 008 → 009 → 010（001,002,004,005は並行可、006は003より先でもよい）

## Cross-Plan Dependencies

- [`rank-up/plan.md`](../rank-up/plan.md): `_commit_exam_success()`（成功パス冒頭）への1行追加が本plan（タスク010）の対象。既存3分岐（次ランクなし/次ランクマスター欠落/正常昇格）すべてに影響する
- [`alchemy/plan.md`](../alchemy/plan.md): `_alchemy_slot_count`・`_unlocked_recipe_ids`・`RecipeMaster`型を本planが権威として書き込む
- [`garden/plan.md`](../garden/plan.md): `_garden_slot_count`・`_seed_inventory`・`_inventory`（`MaterialInstance`）・`MaterialMaster`型を本planが権威として書き込む
