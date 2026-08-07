# パフォーマンスルール

> 🔴 2026-08-06改訂: 技術スタックがGodot 4.x + GDScriptに確定済み（`CLAUDE.md`参照）のため、本ファイルはPhaser前提からGodot前提に全面書き換えした。

## 基本原則

- 推測ではなく計測に基づいて最適化
- 初期段階から拡張性を考慮
- 過度な最適化は避け、読みやすさとのバランスを取る

---

## Godot固有の最適化

### `_process()`メソッド

`_process(delta)`は毎フレーム（60fps想定なら毎秒60回）呼ばれる。

```gdscript
# NG: _process()内での重い処理
func _process(delta: float) -> void:
	var items := inventory.filter(func(i): return i.category == &"material")  # 毎フレーム配列生成
	_check_something_heavy()  # 必要ない場合も実行

# OK: イベント駆動で必要時のみ処理
# _process()自体を定義しない、または本当に毎フレーム必要な処理のみ
```

### `_process()`に書くべきでない処理

- ノードの生成・破棄
- リソース（`Resource`/`.tres`）のロード
- 重い計算（大量データ処理、経路探索等）
- ファイルI/O

### 必要な場合のみ`_process`を定義

```gdscript
# _process()が不要な画面では定義しない
class_name MenuScreen
extends Control

func _ready() -> void:
	pass  # UIの初期化のみ

# _process()は定義しない（本ゲームはターン制で常時アニメーションが少ないため多くの画面で不要）
```

`_process`/`_physics_process`は関数を定義しただけで有効になる。不要になった場合は`set_process(false)`で明示的に止める、または関数自体を削除する。

---

## オブジェクトプーリング

頻繁に生成・破棄するノード（カードUI等）はプーリングを使用する（実装例は[`godot-best-practices.md`](./godot-best-practices.md)「オブジェクトプーリング」参照）。

### プーリング対象の目安

- カードUI
- 一時的なエフェクト（`AnimatedSprite2D`, `GPUParticles2D`）
- 繰り返し表示するUI要素（リスト項目）

---

## テクスチャ最適化

### `AtlasTexture` / インポーターのアトラス化

多数の小さな画像は`AtlasTexture`にまとめる、またはGodotのTextureImporterでスプライトシート化する。

```gdscript
# 個別画像の読み込み（非推奨、大量にある場合）
var icon_texture := preload("res://assets/icons/gold.png")

# AtlasTextureで一括管理（推奨）
var icon_texture: AtlasTexture = preload("res://assets/icons_atlas_gold.tres")
```

### 画像サイズ

- 2の累乗サイズを推奨（64, 128, 256, 512, 1024）
- 必要以上に大きな画像を避ける
- Godotのインポート設定で圧縮モード（VRAM圧縮等）を用途に応じて選択する

---

## メモリ管理

### リソース破棄

シーン終了時は確実にリソースを解放する（詳細は[`godot-best-practices.md`](./godot-best-practices.md)「リソース破棄」参照）。

```gdscript
func _exit_tree() -> void:
	# Autoloadへのsignal購読解除
	if GameState.gold_changed.is_connected(_on_gold_changed):
		GameState.gold_changed.disconnect(_on_gold_changed)

	# Tween停止（ノード跨ぎで保持している場合のみ）
	if _active_tween and _active_tween.is_valid():
		_active_tween.kill()

	# Timer停止
	if _timer:
		_timer.stop()
```

### グローバル参照の回避

```gdscript
# NG: シングルトン以外でのグローバル的な参照保持
Engine.set_meta("current_state", state)

# OK: GameState Autoload経由
GameState.get_state()
```

---

## 状態管理の最適化

### `GameState`更新の原則

```gdscript
# NG: フィールドを外部から直接変更
GameState._inventory.append(item)

# OK: 専用メソッド経由で更新し、内部でsignal発行まで面倒を見る
GameState.add_item(item)
```

### 必要な部分のみ更新

```gdscript
# NG: 状態全体を再計算
GameState.recalculate_all()

# OK: 変更部分のみ
GameState.add_gold(reward)
```

---

## レンダリング最適化

### 可視性管理

画面外・非表示のノードは`visible = false`にする。`CanvasItem.visible = false`のノードはGodotが描画・入力処理をスキップする。

> 🔴 プーリングされたノード（[`godot-best-practices.md`](./godot-best-practices.md)「オブジェクトプーリング」参照）に対してこのカリングを行う場合、`visible`をプールの貸出中フラグと兼用しないこと。兼用すると画面外にスクロールしただけの使用中ノードが「空き」と誤判定され、二重貸出のバグになる。

```gdscript
# スクロールパネル外のカードを非表示
for i in cards.size():
	var is_visible := i >= start_index and i < end_index
	cards[i].visible = is_visible
```

### バッチ処理

複数のUI更新はまとめて実行する。Godotは1フレーム内の変更を自動的にまとめて次の描画に反映するため、Phaserのような明示的な再描画呼び出しは不要。

```gdscript
# OK: まとめて更新するだけでよい（Godotが自動的に次フレームでまとめて描画）
for item in items:
	_update_item_ui(item)
```

---

## 計測ツール

### Godotエディタ内蔵プロファイラ

- `Debugger`パネルの`Profiler`タブでフレーム時間の内訳を確認
- `Monitors`タブでオブジェクト数・描画コール数・メモリ使用量を確認
- リモートデバッグ（実機/エクスポートビルド接続）でも同様に確認可能

### FPS表示（開発時のみ）

`_process()`での毎フレーム`print()`は「重い処理」「本番へのprint()残存」の両方を自ら破る。デバッグビルド限定で`Timer`により間引いて`Label`に表示する。

```gdscript
@onready var _fps_label: Label = %FpsLabel

# デバッグビルドの_ready()でのみセットアップする（本番ビルドでは呼ばない）
func _setup_fps_display() -> void:
	if not OS.is_debug_build():
		return
	var timer := Timer.new()
	timer.wait_time = 0.5
	timer.timeout.connect(_on_fps_timer_timeout)
	add_child(timer)
	timer.start()

func _on_fps_timer_timeout() -> void:
	_fps_label.text = "FPS: %d" % Engine.get_frames_per_second()
```

---

## 禁止事項

- `print()`を本番環境に残す（デバッグ出力は`push_warning()`/`push_error()`、または専用デバッグフラグ経由に限定）
- 同期的な重い処理をメインスレッドで実行しない（必要なら`Thread`または`WorkerThreadPool`を検討）
- 無限ループの可能性があるコードを書かない
- `_process()`内でのノード生成
- 未使用のリソース参照を解放しない
