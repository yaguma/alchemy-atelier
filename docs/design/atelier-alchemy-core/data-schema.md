# データスキーマ設計

作成日: 2026-08-04
準拠要件: [`../../spec/atelier-alchemy-core/requirements.md`](../../spec/atelier-alchemy-core/requirements.md)（以下「要件定義書」）§4「ゲーム要素」

> ⚠️ **セーブ/ロード機能は現バージョンの設計スコープ外**（`CLAUDE.md`、要件定義書冒頭）。そのため本文書は「セーブデータ構造」ではなく、実装に必須となる**ランタイム状態構造（`GameState`が保持するインメモリ状態）**とマスターデータ構造を中心に記述する。セーブ機能が将来追加される場合は、ランタイム状態構造がほぼそのままシリアライズ対象になる想定（🟡）。

## ランタイム状態構造（GameState、インメモリ）

`GameState` Autoload（[`architecture.md`](./architecture.md) 参照）が保持する状態を、JSON相当の構造で表現する（実装はGDScriptの`class_name GameState extends Node`が持つプロパティ群であり、実ファイルとしてこの形で保存されるわけではない）。

```json
{
  "player": {
    "gold": 100,
    "current_rank_id": "G",
    "elapsed_turn": 0,
    "demotion_count": 0,
    "permanent_upgrades": {
      "alchemy_slot_count": 4,
      "garden_slot_count": 5,
      "unlocked_recipe_ids": []
    }
  },
  "rank_state": {
    "rank_hp": 100.0,
    "rank_hp_max": 100.0,
    "limit_turn": 15
  },
  "garden_state": {
    "plants": [
      {
        "slot_index": 0,
        "seed_id": "seed_herb",
        "grown_turns": 2,
        "is_matured": false
      }
    ]
  },
  "inventory": [
    {
      "instance_id": "mat_0001",
      "material_id": "material_herb",
      "quality_score": 3,
      "trait_tags": ["holy"]
    }
  ],
  "daily_order": {
    "order_id": "order_0042",
    "condition_type": "trait",
    "target": "holy"
  },
  "alchemy_slot_state": {
    "selected_recipe_id": "recipe_healing_potion",
    "materials": []
  },
  "exam_state": {
    "in_exam": false,
    "exam_hp": 0.0,
    "exam_hp_max": 0.0,
    "exam_elapsed_turn": 0,
    "exam_turn_limit": 0
  }
}
```

### フィールド説明

| フィールド | 型 | 説明 | デフォルト値 |
|-----------|-----|------|-------------|
| player.gold | int | 所持ゴールド | 🟡TBD（仮100、[`balance-design.md`](./balance-design.md)参照） |
| player.current_rank_id | String | 現在ランク（G〜S） | "G" |
| player.elapsed_turn | int | 現ランクでの経過ターン数 | 0 |
| player.demotion_count | int | 現ランクでの降格回数（要件定義書L96） | 0 |
| player.permanent_upgrades.alchemy_slot_count | int | 調合投入枠数 | 4 |
| player.permanent_upgrades.garden_slot_count | int | 庭スロット数 | 🟡TBD（仮5） |
| player.permanent_upgrades.unlocked_recipe_ids | Array[String] | 解禁済みレシピID一覧 | 🔴TBD（初期解禁レシピが未定。「4. ゲーム要素」参照） |
| rank_state.rank_hp | float | 現在のランクHP | ランクマスターの`max_hp`で初期化 |
| rank_state.limit_turn | int | 現ランクの制限ターン数 | 🟡TBD、ランクマスター参照 |
| garden_state.plants | Array | 庭スロットごとの生育状況 | 空配列 |
| inventory | Array | 収穫済み・未使用の素材インスタンス一覧 | 空配列。**上限なし（無制限）**（🔵2026-08-04ヒアリングで確定、要件定義書§4「素材（Material）」参照） |
| daily_order | Object | 本日の指定調合物の条件 | 日替わりで更新 |
| alchemy_slot_state.selected_recipe_id | String | 調合実行前に選択中のレシピID（🔵事前選択方式、2026-08-04ヒアリングで確定） | 空文字列（未選択） |
| alchemy_slot_state.materials | Array | 投入枠に配置中の素材インスタンスID一覧 | 空配列 |
| exam_state.in_exam | bool | 昇格試験中かどうか。真の間`GardenScreen`への遷移をUI側で禁止する（🔵[`core-systems.md`](./core-systems.md) RankSystem節参照） | false |
| exam_state.exam_hp / exam_hp_max | float | 試験専用のHP。通常の`rank_state.rank_hp`とは別管理（🔵2026-08-04ヒアリングで確定） | `PromotionExamResolver.start_exam`で`rank_master.max_hp × exam_hp_multiplier`により初期化（🟡倍率TBD） |
| exam_state.exam_elapsed_turn / exam_turn_limit | int | 試験内の経過ターン・制限ターン | `exam_turn_limit`は`rank_master.exam_turn_limit`から初期化（🟡TBD、仮1〜2ターン） |

🔵 各フィールドは要件定義書§4の「状態」「変化」記述に対応。数値の初期値の多くは[`balance-design.md`](./balance-design.md)の🟡TBD値をそのまま参照する。

## マスターデータ構造

すべて`Resource`を継承したカスタムクラス（`class_name` + `.tres`、[`architecture.md`](./architecture.md) 参照）として定義する。

### SeedMaster（`res://data/materials/*.tres`のうち種定義）

```json
{
  "id": "seed_herb",
  "name": "薬草の種",
  "produces_material_id": "material_herb",
  "maturity_turns": 2,
  "death_grace_turns": 2,
  "base_quality": 2,
  "trait_pool": ["holy", "gold", "none"],
  "name_purchase_price": 10
}
```

| フィールド | 型 | 説明 | 必須 |
|-----------|-----|------|------|
| id | String | 一意識別子 | ○ |
| name | String | 表示名 | ○ |
| produces_material_id | String | 収穫時に生成される`MaterialMaster`のID | ○ |
| maturity_turns | int | 成熟までのターン数（種別ごとに異なる、🟡TBD具体値） | ○ |
| death_grace_turns | int | 成熟後の枯死猶予ターン数（🟡TBD具体値） | ○ |
| base_quality | int | 成熟直後に収穫した場合の品質スコア（🔴TBD、[`core-systems.md`](./core-systems.md)品質確定ロジック参照） | ○ |
| trait_pool | Array[String] | 収穫時に一様乱数で選ばれる特性タグ候補（「none」＝無特性を含めるかは🔴TBD） | ○ |
| name_purchase_price | int | 種の指名買い価格（🟡TBD） | ○ |

### MaterialMaster（`res://data/materials/*.tres`のうち素材定義）

```json
{
  "id": "material_herb",
  "name": "薬草",
  "icon_path": "res://assets/icons/material_herb.png",
  "is_catalyst": false
}
```

| フィールド | 型 | 説明 | 必須 |
|-----------|-----|------|------|
| id | String | 一意識別子 | ○ |
| name | String | 表示名 | ○ |
| icon_path | String | アイコンリソースパス | ○ |
| is_catalyst | bool | 補助系特性「触媒」素材か（要件定義書L111） | ○ |

### RecipeMaster（`res://data/recipes/*.tres`）

```json
{
  "id": "recipe_healing_potion",
  "name": "回復薬",
  "base_contribution": 10.0,
  "base_reward": 5.0
}
```

| フィールド | 型 | 説明 | 必須 |
|-----------|-----|------|------|
| id | String | 一意識別子 | ○ |
| name | String | 調合物名 | ○ |
| base_contribution | float | 基礎貢献度（🟡TBD） | ○ |
| base_reward | float | 基礎報酬（🟡TBD） | ○ |

🔵 **2026-08-04ヒアリングで確定**: レシピは**事前選択方式**を採用する。プレイヤーは調合実行前に解禁済みレシピから1つを選択し（[`core-systems.md`](./core-systems.md) AlchemySystem節「レシピ選択」参照）、そのレシピの`base_contribution`/`base_reward`が価値計算に使われる。要件定義書§4「レシピ（Recipe）」節に反映済み。初期解禁レシピ・追加レシピの具体的な内容（何種類、どんな名称・数値か）は引き続き🟡TBD（要件定義書§7）。

### DailyOrderMaster（`res://data/daily_orders/*.tres`）

```json
{
  "id": "order_0042",
  "condition_type": "trait",
  "target_recipe_id": "",
  "target_trait": "holy",
  "match_bonus_multiplier": 1.2
}
```

| フィールド | 型 | 説明 | 必須 |
|-----------|-----|------|------|
| id | String | 一意識別子 | ○ |
| condition_type | String | `"item"`（品目指定）or `"trait"`（特性傾向指定）（要件定義書L129「品目 or 特性傾向」） | ○ |
| target_recipe_id | String | `condition_type == "item"`の場合の対象レシピID | condition_type依存 |
| target_trait | String | `condition_type == "trait"`の場合の対象特性タグ | condition_type依存 |
| match_bonus_multiplier | float | 合致時のボーナス倍率（🟡TBD、仮1.2〜1.5倍） | ○ |

### RankMaster（`res://data/ranks/*.tres`）

```json
{
  "id": "G",
  "display_name": "Gランク",
  "max_hp": 100.0,
  "limit_turn": 15,
  "traits_unlocked": false,
  "exam_hp_multiplier": 1.5,
  "exam_turn_limit": 1
}
```

| フィールド | 型 | 説明 | 必須 |
|-----------|-----|------|------|
| id | String | ランク識別子（G/F/E/D/C/B/A/S） | ○ |
| display_name | String | 表示名 | ○ |
| max_hp | float | 当該ランクのランクHP上限（🟡TBD） | ○ |
| limit_turn | int | 当該ランクの制限ターン数（🟡TBD、ランクが上がるほど厳しくする想定） | ○ |
| traits_unlocked | bool | 特性システムが解禁済みか（Gランクは`false`固定、要件定義書§6「Gランク・1ターン目」の「特性は封印」） | ○ |
| exam_hp_multiplier | float | 昇格試験の試験HP = `max_hp × exam_hp_multiplier`（🟡TBD、通常のランクHPより高めに設定する想定。2026-08-04ヒアリングで方向性のみ確定） | ○ |
| exam_turn_limit | int | 昇格試験の制限ターン数（🟡TBD、仮1〜2ターン。超短期の方向性のみ確定） | ○ |

### UpgradeMaster（`res://data/upgrades/*.tres`）

```json
{
  "id": "upgrade_alchemy_slot",
  "name": "投入枠+1",
  "is_permanent": true,
  "price": 500,
  "effect_type": "alchemy_slot_increase",
  "effect_value": 1
}
```

| フィールド | 型 | 説明 | 必須 |
|-----------|-----|------|------|
| id | String | 一意識別子 | ○ |
| name | String | 表示名 | ○ |
| is_permanent | bool | 恒久投資か消耗投資か（要件定義書L133「価格序列」参照） | ○ |
| price | int | 価格（🟡TBD、価格序列: 投入枠+1 ≫ 庭拡張≒レシピ解禁 ＞ 触媒 ＞ 種の指名買い） | ○ |
| effect_type | String | 効果種別（`alchemy_slot_increase`/`garden_slot_increase`/`recipe_unlock`/`catalyst_stock`/`seed_name_purchase`） | ○ |
| effect_value | Variant | 効果の量またはID | ○ |

## データフロー

### ロードタイミング

| データ種別 | タイミング | 備考 |
|-----------|-----------|------|
| マスターデータ（`SeedMaster`等） | ゲーム起動時（`BootScene`） | 全`.tres`をメモリに保持。`architecture.md`のBootScene定義参照 |
| ランタイム状態（`GameState`） | ゲーム起動時に初期化 | セーブ機能がないため常に新規ゲーム状態から開始（🔵要件定義書冒頭のスコープ外規定） |

### 保存タイミング

現バージョンでは永続化を行わない（セーブ/ロード機能はスコープ外）。セッションはブラウザ/アプリを閉じると失われる。この制約はコンセプト文書L61「手動納品の手間」等の設計意図とは無関係の**技術スコープ上の制約**であり、要件定義書冒頭で明示されている（🔵）。
