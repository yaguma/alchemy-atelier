# データスキーマ設計

準拠要件: [`../../spec/atelier-alchemy-core/requirements.md`](../../spec/atelier-alchemy-core/requirements.md)
関連: [`architecture.md`](architecture.md) / [`interfaces.gd`](interfaces.gd)

> **信頼性レベル凡例**: 🔵 要件/コンセプト準拠 ／ 🟡 妥当な推測 ／ 🔴 新規推測
>
> 🔵 本プロジェクトはGodot 4.x採用のため、マスターデータは**カスタム `Resource`（`class_name` + `.tres`）**で表現する（[`CLAUDE.md`](../../../CLAUDE.md) 対応表）。JSONは使用しない。**セーブデータは現バージョンのスコープ外**（[`requirements.md`](../../spec/atelier-alchemy-core/requirements.md) 概要・2章）。

---

## マスターデータ（カスタム Resource）

🔵 `shared/data/*.gd` で `class_name` 付き Resource を定義し、`resources/**/*.tres` に実体を配置。BootScene起動時に一括ロードし、全データをメモリ保持。

### MaterialMaster（素材マスタ）

```gdscript
class_name MaterialMaster extends Resource

@export var id: String                 # 一意識別子（例 "herb"）
@export var display_name: String       # 表示名（例 "薬草"）
@export var maturity_turns: int        # 成熟までのターン数（種別ごと 1〜5）
@export var wither_grace_turns: int    # 成熟後の枯死猶予ターン数
@export var trait_pool: Array[String]  # 収穫時に付きうる特性IDの候補（狙いテーブル）
```

| フィールド | 型 | 説明 | 必須 |
|-----------|-----|------|------|
| id | String | 一意識別子 | ○ 🔵 |
| display_name | String | 表示名 | ○ 🔵 |
| maturity_turns | int | 成熟ターン数（1〜5） | ○ 🔵 |
| wither_grace_turns | int | 枯死猶予ターン数 | ○ 🟡 |
| trait_pool | Array[String] | 付与されうる特性ID候補 | ○ 🔵 |

### TraitMaster（特性タグマスタ）

```gdscript
class_name TraitMaster extends Resource

@export_enum("contribution", "reward", "support") var kind: String  # 系統
@export var id: String                 # 例 "sacred"（聖）
@export var display_name: String       # 表示名
@export var bonus_multiplier: float    # 発現時のボーナス倍率（🟡 TBD）
```

🔵 系統は貢献度系（聖・浄・癒）／報酬系（金・華・稀）／補助系（触媒）。補助系「触媒」は品質+1段。

| フィールド | 型 | 説明 | 必須 |
|-----------|-----|------|------|
| kind | String(enum) | contribution / reward / support | ○ 🔵 |
| id | String | 一意識別子 | ○ 🔵 |
| display_name | String | 表示名 | ○ 🔵 |
| bonus_multiplier | float | 発現時ボーナス倍率 | ○ 🟡 TBD |

### RecipeMaster（レシピマスタ）

```gdscript
class_name RecipeMaster extends Resource

@export var id: String                 # 例 "healing_potion"
@export var display_name: String       # 例 "回復薬"
@export var base_contribution: int     # 基礎貢献度（🟡 TBD）
@export var base_reward: int           # 基礎報酬（🟡 TBD）
@export var unlock_rank: String        # 解禁ランク（G〜S）
```

| フィールド | 型 | 説明 | 必須 |
|-----------|-----|------|------|
| id | String | 一意識別子 | ○ 🔵 |
| display_name | String | 表示名 | ○ 🔵 |
| base_contribution | int | 基礎貢献度 | ○ 🟡 TBD |
| base_reward | int | 基礎報酬 | ○ 🟡 TBD |
| unlock_rank | String | 解禁ランク | ○ 🟡 |

### SeedMaster（種マスタ）🟡

🟡 種と素材を別マスタに分けるか統合するかは実装時判断。ここでは「種→どの素材に育つか＋狙い特性」を持つ最小定義を示す。

```gdscript
class_name SeedMaster extends Resource

@export var id: String
@export var material_id: String        # 育つ素材のID
@export var target_trait_id: String    # 指名買いで狙える特性（分散の中心）
@export var price: int                  # 種の指名買い価格（安価）
```

---

## ランタイム状態（GameState 保持・非永続）

🟡 セーブ非対応のため以下はメモリ上のみ。`GameState` Autoloadが保持する。

### MaterialInstance（収穫済み素材の実体）

```gdscript
class_name MaterialInstance extends RefCounted

var instance_id: String                # 実体の一意ID
var master_id: String                  # 元となる MaterialMaster.id
var quality: int                       # 品質スコア 1〜5（D〜S）
var traits: Array[String]              # 宿った特性ID（0〜2個）
```

| フィールド | 型 | 説明 | 範囲 |
|-----------|-----|------|------|
| instance_id | String | 実体ID | — 🟡 |
| master_id | String | 素材マスタID参照 | — 🔵 |
| quality | int | 品質スコア | 1〜5 🔵 |
| traits | Array[String] | 特性ID（0〜2個） | 🔵 |

### GardenPlot（庭スロットの状態）

```gdscript
# GameState 内で Dictionary 配列として保持する想定
{
  "slot_index": 0,
  "seed_id": "herb_seed",     # 空きなら ""
  "planted_turn": 3,          # 植えたターン
  "state": "growing"          # empty/growing/mature/withered
}
```

### GameState の保持する状態（要約）

🔵 [`requirements.md`](../../spec/atelier-alchemy-core/requirements.md) 4章「プレイヤー」「ギルドランク」に準拠。

| 状態 | 型 | 説明 |
|------|-----|------|
| current_rank | String(G〜S) | 現在ランク 🔵 |
| rank_hp | int | ランクHP（0クランプ）🔵 |
| remaining_turns | int | 現ランクの残りターン数 🔵 |
| gold | int | 所持ゴールド 🔵 |
| slot_limit | int | 調合投入枠数（初期4）🔵 |
| garden_slot_limit | int | 庭スロット数 🔵 |
| unlocked_recipes | Array[String] | 解禁レシピID 🔵 |
| demotion_count | int | 同ランクでの降格回数 🔵 |
| inventory | Array[MaterialInstance] | 収穫・購入した素材在庫 🟡 |
| garden_plots | Array[Dictionary] | 庭スロットの状態 🟡 |
| daily_spec | Dictionary | 本日の指定調合物条件 🔵 |
| current_turn | int | 経過ターン 🟡 |

---

## バランス定数（game_balance.gd）

🔵 バランスに影響する値は `shared/constants/game_balance.gd` に集約（マジックナンバー禁止）。

```gdscript
class_name GameBalance

const INITIAL_SLOT_LIMIT := 4          # 調合投入枠 初期
const MAX_SLOT_LIMIT := 5              # 恒久投資上限
const TRAIT_ACTIVATION_THRESHOLD := 2  # 特性発現閾値（確定仕様）
const INITIAL_GARDEN_SLOTS := 5        # 🟡 TBD
const WITHER_GRACE_TURNS := 2          # 🟡 TBD
const INITIAL_GOLD := 100              # 🟡 TBD
const DEMOTION_LIMIT := 3              # 🟡 TBD 降格許容回数
const SPEC_MATCH_BONUS := 1.2          # 🟡 TBD 指定合致ボーナス
# ランク別制限ターン・HP、品質倍率テーブル等は別途定義（🟡 TBD）
```

---

## データのロード/セーブタイミング

| データ種別 | タイミング | 備考 |
|-----------|-----------|------|
| マスターデータ（`.tres`） | 🔵 ゲーム起動時（BootScene） | 全データをメモリ保持 |
| バランス定数 | 🔵 起動時（コード定義） | 不変 |
| ゲーム進行状態 | 🔵 新規ゲーム開始時に生成 | メモリのみ |
| セーブデータ | **なし（スコープ外）** | 🔵 現バージョン未実装。中断からの再開体験は別途検討 |

> 🔵 セーブ/ロード・タイトル画面・設定画面は現バージョンの設計スコープ外（[`requirements.md`](../../spec/atelier-alchemy-core/requirements.md) 概要）。将来対応する場合は `SaveData` Resource ＋ 検証（改ざん検出）を `.claude/rules/security.md` に沿って設計する。
