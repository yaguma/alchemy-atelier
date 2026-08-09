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
    "demotion_count": 0,
    "permanent_upgrades": {
      "alchemy_slot_count": 4,
      "garden_slot_count": 5,
      "unlocked_recipe_ids": []
    }
  },
  "rank_state": {
    "quota": 100.0,
    "quota_max": 100.0,
    "elapsed_turn": 0,
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
  "seed_inventory": [
    {
      "seed_id": "seed_herb",
      "count": 2
    }
  ],
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
    "exam_quota": 0.0,
    "exam_quota_max": 0.0,
    "exam_elapsed_turn": 0,
    "exam_turn_limit": 0
  }
}
```

### フィールド説明

| フィールド | 型 | 説明 | デフォルト値 | リセット契機 |
|-----------|-----|------|-------------|-------------|
| player.gold | int | 所持ゴールド | 🟡TBD（仮100、[`balance-design.md`](./balance-design.md)参照） | リセットされない（ゲーム開始時のみ初期化） |
| player.current_rank_id | String | 現在ランク（G〜S） | "G" | リセットされない |
| player.demotion_count | int | 現ランクでの降格回数（要件定義書§2「勝敗条件」） | 0 | **昇格成功時に0へリセット**（🔵2026-08-05追加、PRレビューCritical#3対応） |
| player.permanent_upgrades.alchemy_slot_count | int | 調合投入枠数 | 4 | リセットされない（恒久投資） |
| player.permanent_upgrades.garden_slot_count | int | 庭スロット数。**実行時の権威は常にこのフィールド**（🔵2026-08-10追加、実装レディネス監査#5対応。`GameBalance.GARDEN_SLOT_COUNT`はゲーム開始時にこのフィールドを初期化するための定数としてのみ使用し、以降の判定〔`Planting.plant`/`can_plant`の`slot_limit`引数〕は必ずこのフィールドを参照する。[`core-systems.md`](./core-systems.md) GardenSystem節参照） | 🟡TBD（仮5） | リセットされない（恒久投資） |
| player.permanent_upgrades.unlocked_recipe_ids | Array[String] | 解禁済みレシピID一覧。**最低1件を保証する**（🔵2026-08-05確定、要件定義書§4「レシピ（Recipe）」参照。0件だと調合が永久に実行不可能になるため） | 🟡TBD（初期解禁レシピの具体的な内容は未定だが、1件以上という制約は確定） | リセットされない（恒久投資） |
| rank_state.quota | float | 現在のランクノルマ残量 | ランクマスターの`quota_max`で初期化 | **降格時に`quota_max`へリセット**（`RankQuotaResolver.reset_for_retry`） |
| rank_state.elapsed_turn | int | 現ランクでの経過ターン数（🔴2026-08-06修正、実装レディネス監査対応。旧版は`player.elapsed_turn`として定義していたが、`core-systems.md`の`RankQuotaResolver.reset_for_retry`が返す`RankState`のフィールドとして扱われており定義箇所が二重化していたため、`rank_state`側に一本化した） | 0 | **降格時に0へリセット**（`RankQuotaResolver.reset_for_retry`。要件定義書§2「降格時のリセット規定」参照） |
| rank_state.limit_turn | int | 現ランクの制限ターン数 | 🟡TBD、ランクマスター参照 | 降格時は`elapsed_turn`が0に戻ることで実質的にリセットされる（`limit_turn`自体は不変） |
| garden_state.plants | Array | 庭スロットごとの生育状況 | 空配列 | リセットされない（降格時も維持） |
| seed_inventory | Array<{seed_id: String, count: int}> | 未収穫（庭に植える前）の「手持ちの種」を`SeedMaster.id`ごとの個数で管理する | 空配列。上限なし（🔵2026-08-10追加、実装レディネス監査#1対応。旧版は収穫後の`inventory`のみが定義されており、要件定義書§3「種を植える（手持ちの種から選ぶ）」・§4「種の指名買い」・§7「初期所持種」が前提とする「手持ちの種」の状態が欠落していた） | リセットされない（降格時も維持） |
| inventory | Array | 収穫済み・未使用の素材インスタンス一覧 | 空配列。**上限なし（無制限）**（🔵2026-08-04ヒアリングで確定、要件定義書§4「素材（Material）」参照） | リセットされない（降格時も維持） |
| daily_order | Object | 本日の指定調合物の条件 | **毎ターン終了時に再抽選**（🔵2026-08-05確定、要件定義書§4「日替わり指定調合物」参照） | 降格時も再抽選される |
| alchemy_slot_state.selected_recipe_id | String | 調合実行前に選択中のレシピID（🔵事前選択方式、2026-08-04ヒアリングで確定） | 空文字列（未選択） | 調合実行後に空へ戻す |
| alchemy_slot_state.materials | Array | 投入枠に配置中の素材インスタンスID一覧 | 空配列 | 調合実行後に空へ戻す |
| exam_state.in_exam | bool | 昇格試験中かどうか。真の間`GardenScreen`への遷移をUI側で禁止する（🔵[`core-systems.md`](./core-systems.md) RankSystem節参照） | false | 試験終了（成功/失敗）時にfalseへ |
| exam_state.exam_quota / exam_quota_max | float | 試験専用のノルマ。通常の`rank_state.quota`とは別管理（🔵2026-08-04ヒアリングで確定） | `PromotionExamResolver.start_exam`で`(rank_master.quota_max ÷ rank_master.limit_turn) × rank_master.exam_turn_limit × rank_master.exam_difficulty_coefficient`により初期化（🔵2026-08-05修正、PRレビューCritical#5対応。旧式`quota_max×倍率`は成立しなかったため撤回。係数は🟡TBD） | 試験開始のたびに再初期化 |
| exam_state.exam_elapsed_turn / exam_turn_limit | int | 試験内の経過ターン・制限ターン | `exam_turn_limit`は`rank_master.exam_turn_limit`から初期化（🟡TBD、仮1〜2ターン） | 試験開始のたびに再初期化 |

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
  "trait_pool": ["holy", "gold", "none"]
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

🔴 **2026-08-06修正（実装レディネス監査対応）**: 旧版は種の指名買い価格を`SeedMaster.name_purchase_price`として保持していたが、`UpgradeMaster`（`effect_type: "seed_name_purchase"`、後述）も同じ「種の指名買い」の価格情報（`price`フィールド）を持っており、価格の正の情報源が二重化していた。`SeedMaster`側の`name_purchase_price`は廃止し、価格は**`UpgradeMaster.price`に一本化**する。`UpgradeMaster.effect_value`が対象の`seed_id`を指す（下記UpgradeMaster節参照）。触媒（`MaterialMaster`）も同様に価格情報を持たず`UpgradeMaster.price`のみに一本化されており、この修正でマスターデータ全体の一貫性が取れる。

### MaterialMaster（`res://data/materials/*.tres`のうち素材定義）

```json
{
  "id": "material_catalyst",
  "name": "触媒",
  "icon_path": "res://assets/icons/material_catalyst.png",
  "shop_purchasable": true,
  "shop_base_quality": 3
}
```

| フィールド | 型 | 説明 | 必須 |
|-----------|-----|------|------|
| id | String | 一意識別子 | ○ |
| name | String | 表示名 | ○ |
| icon_path | String | アイコンリソースパス | ○ |
| shop_purchasable | bool | ショップで購入できる素材か（触媒等）。庭でのみ入手できる素材は`false` | ○ |
| shop_base_quality | int | ショップ購入時点の基準品質スコア（1〜5）。`shop_purchasable == true`の場合のみ使用（🟡TBD、仮3=B相当） | shop_purchasable依存 |

🔵 **2026-08-05修正（PRレビューCritical#6対応）**: 旧版は`is_catalyst: bool`フィールドで「触媒か」を判定していたが、これは`MaterialInstance.trait_tags`（インスタンス側で持つ特性タグ配列）と情報源が二重化しており、`QualityCalculator.calculate_quality(materials: Array[MaterialInstance])`が`MaterialInstance`しか受け取らないため`MaterialMaster.is_catalyst`を参照するにはDomain層がI/Oを行う必要が生じ純粋性に反していた。触媒か否かの判定は他の特性タグと同様に**`MaterialInstance.trait_tags.has(&"catalyst")`に一本化**し、`is_catalyst`フィールドは廃止した。触媒インスタンスは購入時に`trait_tags = ["catalyst"]`、`quality_score = shop_base_quality`で生成される（[`core-systems.md`](./core-systems.md) WorkshopSystem節「購入適用ロジック」参照。🔵2026-08-10修正、実装レディネス監査#3対応。旧版はAlchemySystem節「特性ボーナスの算出」を参照先としていたが該当記述が存在しないリンク切れだったため、実際に購入処理を担うWorkshopSystem節に新設した「購入適用ロジック」に参照先を修正した）。

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
| condition_type | String | `"item"`（品目指定）or `"trait"`（特性傾向指定）（要件定義書§4「日替わり指定調合物（疑似依頼）」の「品目 or 特性傾向」） | ○ |
| target_recipe_id | String | `condition_type == "item"`の場合の対象レシピID | condition_type依存 |
| target_trait | String | `condition_type == "trait"`の場合の対象特性タグ | condition_type依存 |
| match_bonus_multiplier | float | 合致時のボーナス倍率（🟡TBD、仮1.2〜1.5倍） | ○ |

### RankMaster（`res://data/ranks/*.tres`）

```json
{
  "id": "G",
  "display_name": "Gランク",
  "quota_max": 100.0,
  "limit_turn": 15,
  "traits_unlocked": false,
  "exam_turn_limit": 1,
  "exam_difficulty_coefficient": 1.0
}
```

| フィールド | 型 | 説明 | 必須 |
|-----------|-----|------|------|
| id | String | ランク識別子（G/F/E/D/C/B/A/S） | ○ |
| display_name | String | 表示名 | ○ |
| quota_max | float | 当該ランクのノルマ上限（🟡TBD） | ○ |
| limit_turn | int | 当該ランクの制限ターン数（🟡TBD、ランクが上がるほど厳しくする想定） | ○ |
| traits_unlocked | bool | 特性システムが解禁済みか（Gランクは`false`固定、要件定義書§6「Gランク・1ターン目」の「特性は封印」） | ○ |
| exam_turn_limit | int | 昇格試験の制限ターン数（🟡TBD、仮1〜2ターン。超短期の方向性のみ確定） | ○ |
| exam_difficulty_coefficient | float | 昇格試験ノルマの難度係数。`試験ノルマ = (quota_max ÷ limit_turn) × exam_turn_limit × exam_difficulty_coefficient`（🟡TBD、仮1.0〜1.5） | ○ |

🔴 **2026-08-05修正（PRレビューCritical#5対応）**: `exam_hp_multiplier`（`max_hp`に対する倍率）フィールドは廃止した。試験制限ターンが1〜2ターンしかない設計のため、この式では要求貢献度が通常ランクの約20倍になり成立しなかった。新しい`exam_difficulty_coefficient`は「当該ランクの1手あたり期待貢献度（`quota_max ÷ limit_turn`）」を基準にした係数であり、通常プレイでの貢献度水準と直接比較可能な単位になっている（[`core-systems.md`](./core-systems.md) RankSystem節参照）。

🔴 **2026-08-06修正（世界観整合性の見直し）**: `max_hp`は`quota_max`に改名した（「HP」がギルドの認定制度という世界観に合わないため。要件定義書§4「ギルドランク（審査基準）」参照）。

### UpgradeMaster（`res://data/upgrades/*.tres`）

```json
{
  "id": "upgrade_alchemy_slot",
  "name": "投入枠+1",
  "is_permanent": true,
  "price": 500,
  "effect_type": "alchemy_slot_increase",
  "effect_value": 1,
  "max_purchase_count": 1
}
```

| フィールド | 型 | 説明 | 必須 |
|-----------|-----|------|------|
| id | String | 一意識別子 | ○ |
| name | String | 表示名 | ○ |
| is_permanent | bool | 恒久投資か消耗投資か（要件定義書§4「ショップ／工房強化」の「価格序列」参照） | ○ |
| price | int | 価格（🟡TBD、価格序列: 投入枠+1 ≫ 庭拡張≒レシピ解禁 ＞ 触媒 ＞ 種の指名買い） | ○ |
| effect_type | String | 効果種別（`alchemy_slot_increase`/`garden_slot_increase`/`recipe_unlock`/`catalyst_stock`/`seed_name_purchase`） | ○ |
| effect_value | Variant | 効果の量またはID。`alchemy_slot_increase`/`garden_slot_increase`は増加量（int）、`recipe_unlock`は対象`RecipeMaster.id`（String）、`catalyst_stock`は対象`MaterialMaster.id`（String、通常`material_catalyst`固定）、`seed_name_purchase`は対象`SeedMaster.id`（String）を表す（🔵2026-08-10追加、実装レディネス監査#1・#3対応。具体的な適用ロジックは[`core-systems.md`](./core-systems.md) WorkshopSystem節「購入適用ロジック」参照） | ○ |
| max_purchase_count | int | このアップグレードを購入できる最大回数（🔵2026-08-05追加、PRレビューWarning対応。旧版は購入回数の上限がなく、「投入枠+1」を無制限に購入できてしまう不備があった。恒久投資は基本1回、消耗投資〔触媒・種の指名買い〕は実質無制限として大きな値を設定する） | ○ |

## データフロー

### ロードタイミング

| データ種別 | タイミング | 備考 |
|-----------|-----------|------|
| マスターデータ（`SeedMaster`等） | ゲーム起動時（`BootScene`） | 全`.tres`をメモリに保持。`architecture.md`のBootScene定義参照 |
| ランタイム状態（`GameState`） | ゲーム起動時に初期化 | セーブ機能がないため常に新規ゲーム状態から開始（🔵要件定義書冒頭のスコープ外規定） |

### 起動時検証（🔵2026-08-05追加、PRレビューWarning対応）

`BootScene`は全マスターデータのロード後、以下を検証し、失敗時は`push_error`で起動を停止する。

- マスターデータ間のID相互参照が解決可能か（`SeedMaster.produces_material_id`が実在の`MaterialMaster.id`を指しているか、`DailyOrderMaster.target_recipe_id`/`target_trait`が実在のレシピ/特性タグを指しているか 等）
- `player.permanent_upgrades.unlocked_recipe_ids`の初期値が最低1件以上か（要件定義書§4「レシピ（Recipe）」の制約参照）

### 保存タイミング

現バージョンでは永続化を行わない（セーブ/ロード機能はスコープ外）。セッションはブラウザ/アプリを閉じると失われる。この制約はコンセプト文書「やらないことリスト」の「手動納品の手間」等の設計意図とは無関係の**技術スコープ上の制約**であり、要件定義書冒頭で明示されている（🔵）。
