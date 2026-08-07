# コーディングスタイルルール

> 🔴 2026-08-06改訂: 技術スタックがGodot 4.x + GDScriptに確定済み（`CLAUDE.md`参照）のため、本ファイルはTypeScript前提からGDScript前提に全面書き換えした。

## 基本原則

- 読みやすさと保守性を最優先
- 一貫性のあるコードスタイル
- 静的型付けの徹底

---

## GDScript

### 静的型付け

- すべての変数・引数・戻り値に型注釈を付ける（`var x: int`、`func foo(a: int) -> bool:`）
- `Variant`型（TypeScriptの`any`に相当）の無条件使用は禁止。外部入力等やむを得ない場合は`is`演算子による型ガードで早期に絞り込む
- 明示的な型キャストが必要な場面は最小限にする

```gdscript
# NG
var data = fetch_data()          # 型注釈なし（Variant推論）
var item = array[0] as Item      # 安易なキャスト

# OK
var data: Dictionary = fetch_data()
if data is Dictionary and _is_valid_data(data):
	# 型ガードで絞り込み
	pass
var item: Item = array[0] if array.size() > 0 else null
```

### 命名規則

| 対象 | 規則 | 例 |
|------|------|-----|
| 変数・関数 | snake_case | `material_list`, `calculate_reward` |
| クラス（`class_name`） | PascalCase | `MaterialCard`, `GoldDisplay` |
| シグナル | snake_case（過去形推奨） | `phase_changed`, `gold_changed` |
| 定数 | UPPER_SNAKE_CASE | `MAX_DECK_SIZE`, `GAME_BALANCE` |
| ファイル | snake_case | `material_card.gd`, `quality_calculator.gd` |
| ディレクトリ | snake_case | `garden/`, `state_management/` |
| private（モジュール内限定）メンバ | 先頭に`_` | `_internal_state`, `_calculate_bonus()` |

### インターフェース命名

GDScriptには`interface`に相当する言語機能がなく、本プロジェクトでは独立インターフェースファイルを作成しない方針（[`docs/design/atelier-alchemy-core/architecture.md`](../../docs/design/atelier-alchemy-core/architecture.md)「インターフェース定義について」参照）。`I`プレフィックスは使用しない。

### ファイル冒頭の記述順序

GDScriptは`import`文を持たない。`class_name`によるグローバル解決、または`preload`/`const`で依存を明示する。ファイル内は以下の順序で記述する。

```gdscript
class_name GardenScreen                     # 1. class_name宣言（UIやDomainクラス）
extends Control                             # 2. extends宣言

const SeedMaster = preload("res://features/garden/resources/seed_master.gd")  # 3. 依存の明示

signal planted(slot_index: int)             # 4. シグナル宣言

@export var slot_count: int = 4             # 5. @export変数

var _current_slot: int = 0                  # 6. 通常の変数（privateは_prefix）

func _ready() -> void:                      # 7. ライフサイクルメソッド
	pass

func plant(seed_id: StringName) -> void:    # 8. その他メソッド
	pass
```

---

## Godot固有のスタイル

### Autoloadクラス（StateManager相当）

```gdscript
# autoload/game_state.gd
extends Node

signal phase_changed(previous: StringName, next: StringName)

var _current_phase: StringName = &"garden"
var _gold: int = 0

func get_state() -> Dictionary:
	return {
		"current_phase": _current_phase,
		"gold": _gold,
	}

func set_phase(next: StringName) -> void:
	var previous := _current_phase
	_current_phase = next
	phase_changed.emit(previous, next)
```

### UIコンポーネントクラス（`Control`継承）

```gdscript
# features/garden/ui/garden_screen.gd
class_name GardenScreen
extends Control

@onready var _plant_button: Button = %PlantButton

func _ready() -> void:
	_plant_button.pressed.connect(_on_plant_pressed)

func _on_plant_pressed() -> void:
	pass
```

同一シーンツリー内の子ノード（`_plant_button`）が発行するsignalへの接続は、ノード破棄時にGodotが自動的に切断するため`_exit_tree()`での明示的な`disconnect()`は不要（[`ui-components.md`](./ui-components.md)「`_exit_tree()`での実装」参照。明示的な解除が必須なのはAutoloadなど寿命がノードと異なる発行元への接続のみ）。

---

## フォーマット・リンター（gdformat / gdlint 準拠）

### フォーマット

- インデント: タブ（GDScript標準）
- 行幅: 100文字目安
- クォート: ダブルクォート推奨
- 末尾カンマ: 複数行の配列/辞書リテラルでは付ける

### リンター

- `gdlint`（gdtoolkit）のデフォルトルールを遵守
- 警告は放置せず修正

---

## コメント

### 書くべきコメント

- 「なぜ」そうしたかの理由
- 複雑なビジネスロジックの説明
- TODO/FIXME（担当者とチケット番号付き）

```gdscript
# ゲームバランス調整: 序盤の挫折防止のため
# Gランクの品質上昇確率は他ランクより高く設定する（balance-design.md §難易度曲線）
var quality_up_chance := GameBalance.QUALITY_UP_CHANCE_G_RANK

# TODO(TASK-0025): ランク昇格時の演出を追加
```

### 書くべきでないコメント

- コードを読めばわかること
- 古くなった情報
- コメントアウトされたコード

```gdscript
# NG: コードで自明
# ゴールドを100増やす
_gold += 100

# NG: 古いコード（削除すべき）
# var old_value = calculate_old(x)
```

---

## ファイル構成

### 1ファイルの上限

- 300行を超えたら分割を検討
- 1コンポーネント = 1ファイルを原則

### 機能モジュール構成

```
features/garden/
├── logic/
│   ├── planting.gd
│   └── harvest.gd
├── state/
│   └── garden_state.gd
├── resources/
│   └── seed_master.gd
└── ui/
	├── garden_screen.tscn
	└── garden_screen.gd
```

---

## 定数管理: GameBalance vs UiTheme

ゲーム内の定数は用途に応じて2つのファイルに分離して管理する（[`docs/design/atelier-alchemy-core/architecture.md`](../../docs/design/atelier-alchemy-core/architecture.md)の設計方針をGodot向けに翻訳）。

### GameBalance (`shared/constants/game_balance.gd`)

**ゲームバランスに影響するパラメータ**を管理する`class_name`付き静的クラス。

| カテゴリ | 例 |
|---------|-----|
| 報酬・コスト | 調合基礎貢献度/報酬、購入価格 |
| 制限値 | 投入枠数、庭スロット数、保管上限 |
| ランク設定 | ランクノルマ、制限ターン数、昇格試験係数 |
| 品質パラメータ | 品質上昇確率、品質乗数テーブル |
| 特性パラメータ | 特性ボーナス乗数、発現閾値 |

```gdscript
# shared/constants/game_balance.gd
class_name GameBalance

const GARDEN_SLOT_COUNT := 4          # balance-design.md §パラメータ設計 対応
const QUALITY_UP_CHANCE_G_RANK := 0.3 # 🟡TBD
```

```gdscript
# 使用例
var max_slots := GameBalance.GARDEN_SLOT_COUNT
```

### UiTheme (`shared/theme/theme.gd`)

**UIの見た目に関するパラメータ**を管理する`class_name`付き静的クラス。

| カテゴリ | 例 |
|---------|-----|
| 色 | 背景色、テキスト色、ボーダー色、品質色、ボタン色 |
| フォント | フォントリソースパス、フォントサイズ |
| スペーシング | マージン、パディング |

```gdscript
# shared/theme/theme.gd
class_name UiTheme

const COLOR_BACKGROUND_PRIMARY := Color("#2a2a3d")
const FONT_SIZE_MEDIUM := 16
```

```gdscript
# 使用例
var bg_color := UiTheme.COLOR_BACKGROUND_PRIMARY
```

### 判断基準

```
その定数を変更するとゲームバランスが変わるか？
  → YES: GameBalance（game_balance.gd）
  → NO: その定数を変更するとUIの見た目が変わるか？
    → YES: UiTheme（theme.gd）
    → NO: 用途に応じて shared/constants/ または各feature内に配置
```

### 注意事項

- `GameBalance`の値を`UiTheme`から参照しない（逆も同様）
- マジックナンバーは必ずどちらかのファイルに定数として定義する
- バランス設計書（[`docs/design/atelier-alchemy-core/balance-design.md`](../../docs/design/atelier-alchemy-core/balance-design.md)）の変更時は`GameBalance`も同期更新する
- 各定数にはバランス設計書のセクション番号をコメントで対応付ける

---

## 禁止事項

- `Variant`型の無条件使用（型ガードなしでの使用）
- 安易な型キャスト
- マジックナンバーの直書き（`GameBalance`または`UiTheme`に定数化）
- ネストが深いコード（3階層以上は早期リターンで解消）
- `print()`を本番コードに残す（デバッグ出力は`push_warning()`/`push_error()`、または専用デバッグフラグ経由に限定）
