# Godot ベストプラクティス

> 🔴 2026-08-06改訂: 技術スタックがGodot 4.x + GDScriptに確定済み（`CLAUDE.md`参照）のため、旧`phaser-best-practices.md`（Phaser 3 + rexUI前提）をGodot前提に全面書き換えし、本ファイル名に変更した。

## シーン/ノードライフサイクル

Godotのノードは以下のライフサイクルメソッドを持つ。適切なタイミングで処理を行うこと。

```gdscript
class_name MyScreen
extends Control

func _init() -> void:            # ノード生成時（シーンツリー未接続、子ノード未初期化の可能性あり）
	pass

func _ready() -> void:           # シーンツリーに追加され、子ノードの準備が完了した時
	pass

func _process(delta: float) -> void:       # 毎フレーム更新（必要な場合のみ定義）
	pass

func _physics_process(delta: float) -> void:  # 物理フレーム更新（本ゲームでは基本不要）
	pass

func _exit_tree() -> void:       # シーンツリーから removed される時（Phaserのshutdown()相当）
	pass
```

### 各メソッドの責務

| メソッド | 責務 | 注意点 |
|---------|------|--------|
| `_init()` | プロパティの初期値設定のみ | 子ノード（`@onready`）や`get_node()`はまだ使えない |
| `_ready()` | 子ノード参照の確定、シグナル接続、初期表示 | `@onready var`はこの時点で解決済み |
| `_process(delta)` | 毎フレーム処理 | 必要な場合のみ定義（未使用なら省略） |
| `_exit_tree()` | シグナル購読解除、Tween/Timer停止 | Phaserの`shutdown()`に相当 |

### シーン間データ受け渡し

Godotの`change_scene_to_file()`はPhaserの`scene.start(key, data)`のような引数渡しをサポートしないため、`GameState` Autoload経由で値を受け渡す（[`state-management.md`](./state-management.md)参照）。

```gdscript
# 遷移元
GameState.set_pending_result({ "gold": 1000, "turn": 25 })
get_tree().change_scene_to_file("res://scenes/result.tscn")

# 遷移先
func _ready() -> void:
	var result := GameState.get_state().pending_result
```

本ゲームはターン制でシーン遷移が少ないため、大半の画面切り替えは`MainScene`常駐＋子`Control`の`visible`切り替えで実現する（[`docs/design/atelier-alchemy-core/architecture.md`](../../docs/design/atelier-alchemy-core/architecture.md)「シーン構成」参照）。この場合はシーン遷移自体が発生せず、`show_phase(phase)`のような表示切替メソッドを`MainScene`側に用意する。

---

## Control / テーマシステム

### Godot標準UIノードで完結させる

rexUI等の外部UIプラグインは使用しない。Godot標準の`Control`派生ノード（`Panel`, `Button`, `Label`, `RichTextLabel`, `VBoxContainer`, `HBoxContainer`, `GridContainer`, `ScrollContainer`等）とテーマリソースで画面を構築する。

| 用途 | Godot標準ノード |
|---|---|
| ボタン | `Button` |
| モーダルダイアログ | `Window`（`PopupPanel` / `AcceptDialog`等）または`CanvasLayer`+`Control`の自作オーバーレイ |
| レイアウト管理 | `VBoxContainer` / `HBoxContainer` / `GridContainer` / `MarginContainer` |
| スクロール可能パネル | `ScrollContainer` |
| 角丸背景 | `Panel` + `StyleBoxFlat`（`corner_radius_*`） |

### シーン内ユニーク名（`%Name`）の活用

子ノードへの参照は`@onready var x: Button = %ConfirmButton`のように、エディタでシーン内ユニーク名（`%`）を設定して取得する。深い`get_node("Path/To/Node")`のパス直書きは避ける。

---

## アセット管理

### 一括プリロードとリソースキャッシュ

Godotは`.tres`/`.tscn`をインポート時に自動でリソースキャッシュするため、Phaserの`preload()`のような明示的な一括ロードシーンは必須ではない。ただし起動時のマスターデータ整合性検証は`BootScene`で行う（[`docs/design/atelier-alchemy-core/architecture.md`](../../docs/design/atelier-alchemy-core/architecture.md)参照）。

```gdscript
# scenes/boot.gd
func _ready() -> void:
	var materials := MasterDataLoader.load_all(&"materials")
	if not MasterDataLoader.validate_references(materials):
		push_error("マスターデータのID相互参照が解決できません")
		return
	get_tree().change_scene_to_file("res://scenes/main.tscn")
```

### リソースパスの命名規則

```
res://data/<category>/<name>.tres
res://features/<feature>/ui/<screen_name>.tscn

例:
res://data/materials/herb_common.tres
res://data/recipes/healing_potion.tres
res://features/alchemy/ui/alchemy_screen.tscn
```

---

## パフォーマンス最適化

### オブジェクトプーリング

頻繁に生成・破棄するUI要素（カード等）はプーリングを検討する。GodotはPhaserの`Group`のような組み込みプーリング機構を持たないため、配列とノードの管理で自作する。非表示ノードでも`_process()`定義があれば呼ばれ続けるため`process_mode`も止める。また再利用時に前回表示が残らないよう、貸し出し・返却の両方で内部状態をリセットする。

> 🔴 貸出中フラグには`visible`を流用しない。一覧のスクロール表示等で画面外カードを`visible = false`にするカリング処理（[`performance.md`](./performance.md)「可視性管理」参照）と併用すると、画面外にスクロールしただけの使用中カードが「空き」と誤判定され二重貸出される。貸出中管理は専用の`_in_use: bool`で行い、`visible`は表示制御専用として分離する。

```gdscript
var _card_pool: Array[PlantCard] = []

func _get_or_create_card() -> PlantCard:
	for card in _card_pool:
		if not card.is_in_use():
			card.visible = true
			card.process_mode = Node.PROCESS_MODE_INHERIT
			card.mark_in_use()
			card.reset_state()  # 前回の貸出時の表示が残らないよう、貸出時にもリセットする
			return card
	var card: PlantCard = PlantCardScene.instantiate()
	add_child(card)
	card.mark_in_use()
	_card_pool.append(card)
	return card

func _release_card(card: PlantCard) -> void:
	card.mark_released()  # _in_useをfalseに戻す（visibleとは独立して管理する）
	card.reset_state()  # 表示内容（品質・特性タグ等）をクリアし、前回表示の残留を防ぐ
	card.visible = false
	card.process_mode = Node.PROCESS_MODE_DISABLED
```

### プーリング対象の目安

- カードUI
- 一時的なエフェクト（`AnimatedSprite2D`等）
- 繰り返し表示するUI要素（リスト項目）

### 不要な`_process`を避ける

- `_process()`は毎フレーム呼ばれるため、必要な場合のみ定義する
- イベント駆動（`signal`）で済む処理は`_process()`に書かない
- 定義しないノードでは`set_process(false)`にする必要すらない（デフォルトでは`_process`未定義なら呼ばれない）

### `SpriteFrames` / `AtlasTexture`

多数の小さな画像はテクスチャアトラス（`AtlasTexture`）にまとめる、またはGodotのTextureImporterのアトラス生成機能を利用する。

```gdscript
# 個別テクスチャの読み込み（非推奨、多数の場合）
var icon_gold := preload("res://assets/icons/gold.png")

# AtlasTextureでアトラスの一部を切り出す（推奨）
var icon_gold: AtlasTexture = preload("res://assets/icons_atlas_gold.tres")
```

---

## リソース破棄

### シーン終了時のクリーンアップ

```gdscript
func _exit_tree() -> void:
	# Autoloadへのシグナル購読解除（必須）
	if GameState.phase_changed.is_connected(_on_phase_changed):
		GameState.phase_changed.disconnect(_on_phase_changed)

	# Tween停止（ノード跨ぎで保持している場合のみ）
	if _active_tween and _active_tween.is_valid():
		_active_tween.kill()

	# Timer停止
	if _timer:
		_timer.stop()
```

### ノードの破棄

```gdscript
# 個別破棄（子ノードも再帰的に解放される。現フレームの処理完了後に解放されるため安全）
node.queue_free()

# 即座に破棄が必要な場合（通常はqueue_free()を使う）
node.free()
```

> 🔴 `free()`はその場で即座にメモリを解放するため、signalのコールバック中や`_process()`/`_physics_process()`の実行中に、そのノード自身やまだ処理中のノードに対して呼ぶとクラッシュしうる。呼び出しタイミングに確信が持てない場合は必ず`queue_free()`を使う。

---

## イベント管理

### 入力イベント vs `GameState`のsignal

| 用途 | 使うべきもの |
|------|------------|
| 入力イベント（クリック等） | `Control.gui_input` / `Button.pressed` |
| ノード固有のライフサイクルイベント | `Node`の仮想メソッド（`_ready`, `_exit_tree`等） |
| ゲームロジックイベント | `GameState`の`signal`（[`state-management.md`](./state-management.md)参照） |
| UIコンポーネント間通信 | 直接の親子関係なら`signal`を子が発行し親が`connect()`、無関係な場合は`GameState`経由 |

### シグナル接続の解除

登録した接続は、発行元の寿命が購読側ノードより長い場合（主にAutoload）は必ず解除する。

```gdscript
# 登録
GameState.phase_changed.connect(_on_phase_changed)

# 解除（_exit_tree()で）
if GameState.phase_changed.is_connected(_on_phase_changed):
	GameState.phase_changed.disconnect(_on_phase_changed)
```

同一シーンツリー内の親子ノード間接続は、子ノードが破棄されればGodotが自動的に切断するため明示的な解除は必須ではないが、可読性のため揃えて解除してもよい。

---

## 日本語テキスト描画の注意

> 🔴 Godot 4.xのデフォルトフォントは日本語グリフを一切含まないため、CJK対応フォント（`FontFile`）を設定しない場合、日本語テキストは「部分的な欠落」ではなく**全く描画されない（豆腐文字/矩形のみ表示）**。本ゲームは全UIが日本語表示前提のため、これは「注意点」ではなく**Phase 1（プロジェクト基盤構築）で最初に対応すべき必須セットアップ**である。

### 対策: プロジェクト共通フォントの設定

```gdscript
# shared/theme/theme.gd
class_name UiTheme

const FONT_MAIN: FontFile = preload("res://assets/fonts/noto_sans_jp.ttf")
```

`Theme`リソース（`res://shared/theme/main_theme.tres`）の`default_font`に上記フォントを設定し、プロジェクト設定（`Project > Project Settings > GUI > Theme > Custom`）で全体テーマとして適用する。

### 適用が必要なケース

- 見出し等、太字・大きめの日本語テキスト
- 特にフォントサイズ16px相当以上のテキスト
- 画数の多い漢字（受、愛、変など）を含むテキストで字形欠けが疑われる場合は、フォントの言語カバレッジ（Language/Script設定）を確認する

---

## 禁止事項

- `_process()`内での重い処理（ノード生成、大量データ処理等）
- シーン終了時のリソース未解放（Autoloadへのsignal購読解除漏れ）
- グローバル変数的な使い方でのノード参照保持（`Engine.set_meta()`の濫用等）
- 深い`get_node("A/B/C/D")`パス直書きの多用（シーン内ユニーク名`%Name`または`@export`での参照注入を使う）
