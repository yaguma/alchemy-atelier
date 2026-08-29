---
id: "001"
title: "DailyOrderMasterの実データとMasterDataLoaderのdaily_ordersカテゴリを実装する"
status: pending
priority: 1
dependencies: []
estimated_complexity: medium
---

# Task: DailyOrderMasterの実データとMasterDataLoaderのdaily_ordersカテゴリを実装する

## Goal

G〜S各ランクで達成可能な`DailyOrderMaster`実データ（`.tres`、仮値）を作成し、`MasterDataLoader`に`&"daily_orders"`カテゴリを追加することで、`MasterDataLoader.load_all(&"daily_orders")`で全件ロードできるようにする。

## Interfaces

```gdscript
# atelier/shared/loaders/master_data_loader.gd への変更
const DAILY_ORDERS_DIR := "res://data/daily_orders/"  # 🔵 既存4定数（MATERIALS_DIR等）と同型

# _resolve_dir_path()に分岐追加:
#   &"daily_orders": return DAILY_ORDERS_DIR  # 🔵
# _is_allowed_type()に分岐追加:
#   &"daily_orders": return resource is DailyOrderMaster  # 🔵
```

```gdscript
# atelier/features/guild/resources/daily_order_master.gd のスキーマ（変更しない、参照のみ、CON-001）
# id: String, condition_type: String("item"|"trait"), target_recipe_id: String,
# target_trait: String, match_bonus_multiplier: float
```

## Test Strategy

- [ ] `MasterDataLoader.load_all(&"daily_orders")`が`atelier/data/daily_orders/*.tres`の配置件数と同数を`DailyOrderMaster`として返す
- [ ] `condition_type == "item"`のエントリは`target_recipe_id`が非空である
- [ ] `condition_type == "trait"`のエントリは`target_trait`が非空である
- [ ] `MasterDataLoader.load_all(&"daily_orders")`が他カテゴリのリソース（`RankMaster`等）を誤って含めない
- [ ] **異常系**: `data/daily_orders/`にファイルが1件も無い状態で呼んでも空配列を返すのみでクラッシュしない（既存`load_all()`と同型の防御）
- [ ] **異常系**: 未知のカテゴリ（例`&"unknown"`）を渡すと空配列を返す（既存契約の非退行）
- [ ] **境界値**: 全ランク（G〜S）それぞれについて、そのランクで解禁済みのレシピ・特性のみを対象とするエントリが最低1件は存在する（実データの網羅性チェック。Gランクは特性未解禁のためitem条件のみでよい）

## Implementation Notes

- 参照すべき既存コード:
  - `atelier/shared/loaders/master_data_loader.gd:59-77`（`&"ranks"`カテゴリ追加パターン、そのまま踏襲する）
  - `atelier/data/ranks/*.tres`（main-scene-integration Planで新規作成した実データの書式・ヘッダ部分の参考）
  - `atelier/features/rank/resources/rank_master.gd`（`traits_unlocked`フィールド。Gランクはfalse固定）
  - `atelier/shared/constants/game_balance.gd:50`（`INITIAL_RECIPE_ID`。ゲーム開始時点で解禁済みの唯一のレシピ）
  - `atelier/shared/constants/game_balance.gd:56`（`DAILY_ORDER_MATCH_BONUS_MULTIPLIER = 1.3`。`DailyOrderMaster.match_bonus_multiplier`の既定値として既に参照されているため、`.tres`側で明示的に上書きしない限りこの値になる）
- 実装のヒント: `.tres`はGodotエディタを使わずテキストで手書きしてよい（`[gd_resource type="Resource" script_class="DailyOrderMaster" ...]`形式、既存の`data/ranks/*.tres`を参考にヘッダ部分を揃える）。最低限のデータ量として、`INITIAL_RECIPE_ID`（`recipe_healing_potion`）を対象とする`item`条件エントリを1件は必ず含めること（ゲーム開始直後から抽選プールが空にならないようにするため）。特性を対象とする`trait`条件エントリは、既存の特性タグ体系（`atelier/data/materials/*.tres`や`trait_tags`を参照）から妥当なものを2〜3件用意する。
- 注意事項: `DailyOrderMaster`自体のスキーマ変更は行わない（CON-001）。実データのバランス数値（`match_bonus_multiplier`）は仮値でよい（CON-004）。

## Files

- 新規: `atelier/data/daily_orders/*.tres`（最低5〜8件、item/trait両条件を含む）
- 変更: `atelier/shared/loaders/master_data_loader.gd`
- テスト: `atelier/tests/unit/shared/test_master_data_loader.gd`（`&"daily_orders"`カテゴリの追加テスト、既存ファイルへの追記）
