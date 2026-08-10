# 状態管理ルール

> 🔴 2026-08-06改訂: 技術スタックがGodot 4.x + GDScriptに確定済み（`CLAUDE.md`参照）のため、本ファイルはTypeScript前提のStateManager/EventBusパターンから、GodotのAutoload + ネイティブ`signal`パターンに全面書き換えした。

## 概要

本プロジェクトでは以下の2つの仕組みで状態管理とコンポーネント間通信を行う（[`docs/design/atelier-alchemy-core/architecture.md`](../../docs/design/atelier-alchemy-core/architecture.md)「対応表」参照）。

| 仕組み | Godotでの実装 | 責務 |
|--------|--------------|------|
| StateManager | `GameState` Autoload（シングルトンNode） | ゲーム状態の一元管理（Single Source of Truth） |
| EventBus | Godotネイティブの`signal`（専用Autoloadは持たない） | コンポーネント間のイベント駆動通信 |

## GameState（StateManager相当）

### 基本原則

- **イミュータブル更新の思想を踏襲**: 呼び出し元に状態オブジェクトを直接書き換えさせず、`GameState`の更新メソッド経由でのみ変更する
- **単一の情報源**: ゲーム状態は`GameState` Autoloadのみが保持する
- **実行直前の再検証**: UIの判定結果を信頼せず、状態変更の直前に必ずDomain層（`logic/*.gd`）の判定関数を再評価する（[`docs/design/atelier-alchemy-core/architecture.md`](../../docs/design/atelier-alchemy-core/architecture.md)「検証責務のレイヤー配置原則」参照）
- **`get_state()`戻り値の防御的コピー必須**: GodotのDictionary/Arrayは参照型のため、内部状態をそのまま返すと`GameState.get_state().inventory.append(x)`のような呼び出し元からの直接破壊を型システムが防げない（TypeScript版の`Readonly<T>`のような静的な保証がGDScriptには存在しない）。`get_state()`実装は必ず`duplicate(true)`でディープコピーしてから返す

### 状態取得

```gdscript
# Autoload名で直接参照（Godotのシングルトンはグローバルに公開される）
var state := GameState.get_state()
print(state.current_phase, state.gold, state.current_turn)
```

```gdscript
# autoload/game_state.gd側の実装（ディープコピーを徹底する）
func get_state() -> Dictionary:
	return _state.duplicate(true)
```

> 🔴 `_state.duplicate(true)`を経由しない実装（例: `_state`をそのまま返す、または`{"gold": _gold, "inventory": _inventory}`のように内部の`Array`/`Dictionary`をそのまま値として詰める）は、呼び出し側が`state.inventory.append(x)`のように内部状態を直接改変できてしまうため禁止する。高頻度（`_process()`等）で呼ぶ場合はコストを踏まえ、フィールド単位の個別ゲッター（`GameState.get_gold() -> int`等）への置き換えも検討する。

### 状態更新

状態更新は専用メソッドを使用する。呼び出し元からの直接的なフィールド書き換えは禁止。

```gdscript
# フェーズ変更
GameState.set_phase(&"alchemy")

# リソース操作
GameState.add_gold(100)
GameState.spend_gold(50)

# ターン進行
GameState.advance_turn()

# 調合実行（Domain層の再検証を含む一連の処理）
GameState.execute_alchemy(recipe_id, material_ids)
```

### テスト用API

`GameState`はAutoload（プロセス内で単一）のため、GdUnit4テストはインスタンスを差し替えられない。テスト分離のために内部状態を初期値へ戻す`reset_for_test()`を実装し、本番コードパスからは呼び出さない（[`godot-debug-tools.md`](./godot-debug-tools.md)「雛形1」参照）。

```gdscript
func reset_for_test() -> void:
	assert(OS.is_debug_build(), "reset_for_test() must not be called in release builds")
	_current_phase = &"garden"
	_gold = 0
	_inventory.clear()
	# ...その他フィールドも初期値へ
```

`assert()`はリリースビルドでは除去されるため、確実に呼び出しを止めたい場合は`if not OS.is_debug_build(): push_error(...); return`を併用する。

### フェーズ遷移ルール

フェーズ遷移には制約がある。`GameState`内部で定義する遷移テーブルで許可された遷移のみ実行可能。

```gdscript
# 遷移可能か確認
if GameState.can_transition_to(&"alchemy"):
	GameState.set_phase(&"alchemy")
```

---

## signal（EventBus相当）

### 基本原則

- **疎結合通信**: 発行側は購読側を知らない（Godotの`signal`はPub/Subパターンをネイティブサポートする）
- **専用EventBusクラスは作らない**: `signal`は発行元のクラス（主に`GameState`）が宣言し、購読側が`connect()`する
- **購読解除必須（寿命の異なる発行元のみ）**: `GameState`等Autoload（寿命が購読側ノードと異なる発行元）のsignalに`connect()`した場合は、購読側ノードの`_exit_tree()`で必ず`disconnect()`する。同一シーンツリー内の親子ノード間（自ノード自身のsignalや子ノードのsignalへの接続）はノード破棄時にGodotが自動的に切断するため、明示的な`disconnect()`は不要（詳細は[`ui-components.md`](./ui-components.md)「`_exit_tree()`での実装」参照）
- **注意（再接続漏れ）**: `_ready()`はノードが再度シーンツリーに追加されても自動では再実行されない。ノードをツリーから外して`_exit_tree()`でAutoload購読を切断した後、同じインスタンスを再追加する運用をすると、`_ready()`が呼ばれず購読が復帰せずUIが静かに更新されなくなる。本ゲームは`MainScene`常駐＋`visible`切替が基本のためこのケースは発生しにくいが、ノードの再追加を行う場合は購読の復帰を明示的に行うこと

### シグナル宣言と発行

```gdscript
# autoload/game_state.gd
extends Node

signal phase_changed(previous: StringName, next: StringName)
signal gold_changed(previous_amount: int, new_amount: int, delta: int)

func set_phase(next: StringName) -> void:
	var previous := _current_phase
	_current_phase = next
	phase_changed.emit(previous, next)

func add_gold(amount: int) -> void:
	var previous := _gold
	_gold += amount
	gold_changed.emit(previous, _gold, amount)
```

### シグナル購読

```gdscript
func _ready() -> void:
	GameState.phase_changed.connect(_on_phase_changed)

func _on_phase_changed(previous: StringName, next: StringName) -> void:
	print("Phase changed: ", next)

func _exit_tree() -> void:
	if GameState.phase_changed.is_connected(_on_phase_changed):
		GameState.phase_changed.disconnect(_on_phase_changed)
```

### 1回だけ購読

```gdscript
GameState.turn_started.connect(_on_first_turn, CONNECT_ONE_SHOT)
```

### イベント種別

主要な`signal`（`GameState`が発行するもの）:

| シグナル | 発行タイミング | 引数 |
|---------|---------------|-----------|
| `phase_changed` | フェーズ変更時 | `previous: StringName, next: StringName` |
| `turn_started` | ターン開始時 | `turn: int` |
| `turn_ended` | ターン終了時 | `turn: int` |
| `gold_changed` | ゴールド変動時 | `previous_amount: int, new_amount: int, delta: int` |
| `product_crafted` | 調合実行時 | `product: ProductInstance` |
| `delivered` | 納品決算時 | `result: DeliveryResult` |
| `rank_promoted` | 昇格試験成功時 | `new_rank: StringName` |

---

## シーン間のデータ受け渡し

本ゲームはターン制でシーン遷移が少なく、`MainScene`内でUI（`Control`ノード）の表示/非表示を切り替える構成を採る（[`docs/design/atelier-alchemy-core/architecture.md`](../../docs/design/atelier-alchemy-core/architecture.md)「シーン構成」参照）。そのため大半のデータ受け渡しは以下の方法2（`GameState`経由）で行い、方法1はシーン遷移そのものが発生する箇所（`BootScene`→`MainScene`、試験結果→`ResultScene`等）に限定する。

### 方法1: シーン起動時の引数渡し

```gdscript
# 遷移元
get_tree().change_scene_to_file("res://scenes/result.tscn")
# change_scene_to_file自体は引数を渡せないため、値はGameState経由で受け渡す（方法2に合流）
```

### 方法2: GameState経由（推奨）

ゲーム全体で共有する状態は`GameState`で管理する。

```gdscript
# 保存
GameState.set_selected_recipe_id(recipe_id)

# 別シーン/画面で取得
var recipe_id := GameState.get_state().selected_recipe_id
```

### 方法3: signal経由

非同期通知が必要な場合。

```gdscript
# 発行側
GameState.recipe_selected.emit(recipe_id)

# 購読側
GameState.recipe_selected.connect(func(recipe_id: StringName) -> void:
	_show_recipe_detail(recipe_id)
)
```

---

## UIコンポーネントでの状態監視

UIコンポーネント（`Control`継承）は`GameState`の`signal`を購読し、表示を更新する。

```gdscript
class_name GoldDisplay
extends Control

@onready var _gold_label: Label = %GoldLabel

func _ready() -> void:
	# 初期表示
	_update_display(GameState.get_state().gold)

	# 変更監視
	GameState.gold_changed.connect(_on_gold_changed)

func _on_gold_changed(_previous: int, new_amount: int, _delta: int) -> void:
	_update_display(new_amount)

func _update_display(amount: int) -> void:
	_gold_label.text = "%d G" % amount

func _exit_tree() -> void:
	if GameState.gold_changed.is_connected(_on_gold_changed):
		GameState.gold_changed.disconnect(_on_gold_changed)
```

---

## 禁止事項

- `GameState`のフィールドを外部から直接書き換える（`GameState._gold = 100`のような直接代入）
- `get_state()`の戻り値（特に`Array`/`Dictionary`型フィールド）を呼び出し元で直接変更する（`get_state()`実装が`duplicate(true)`していれば実害はないが、UIコンポーネント側でも「戻り値は読み取り専用」を前提にコードを書く）
- `signal`購読を解除せずにノードを破棄する
- シーン間でグローバル変数（`Engine`のメタデータ等）を使ったデータ共有
- UIコンポーネントから直接Domain層（`logic/*.gd`）を呼び出して状態を変える（必ず`GameState`経由で行う）
