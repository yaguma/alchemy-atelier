# UIコンポーネント設計ルール

> 🔴 2026-08-06改訂: 技術スタックがGodot 4.x + GDScriptに確定済み（`CLAUDE.md`参照）のため、本ファイルはPhaser `BaseComponent`前提からGodot `Control`継承コンポーネントパターンに全面書き換えした。

## 概要

UIコンポーネントは原則`Control`を継承した独立シーン（`.tscn` + `.gd`）として実装し、一貫したライフサイクルとAPI設計に従う。GodotにはPhaserの`BaseComponent`のような共通基底クラスを明示的に用意する必要はない（`Node`のライフサイクル自体が`_ready()`/`_exit_tree()`という共通の初期化/破棄フックを提供するため）。

## コンポーネントの基本形

```gdscript
# features/garden/ui/plant_card.gd
class_name PlantCard
extends Control

signal selected(card: PlantCard)

var _plant: PlantState
@onready var _bg: Panel = %Background
@onready var _title_label: Label = %TitleLabel

func setup(plant: PlantState) -> void:
	_plant = plant
	_title_label.text = plant.display_name

func _ready() -> void:
	gui_input.connect(_on_gui_input)

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		selected.emit(self)

func _exit_tree() -> void:
	if gui_input.is_connected(_on_gui_input):
		gui_input.disconnect(_on_gui_input)
```

### ライフサイクルの対応

| Phaser `BaseComponent` | Godot `Control` |
|---|---|
| コンストラクタ + `create()` | シーンインスタンス化 + `_ready()` |
| `destroy()` | `_exit_tree()`（`queue_free()`によって呼ばれる） |
| `this.container` | ノード自身（`Control`は既にコンテナ） |
| `setVisible(visible)` | `visible = true/false`（組み込みプロパティ） |
| `setPosition(x, y)` | `position = Vector2(x, y)`（組み込みプロパティ） |

Phaserと異なり`this.rexUI`のような外部UIプラグイン参照は不要。Godot標準の`Control`ノード群（`Panel`, `Button`, `Label`, `VBoxContainer`等）とテーマリソースで完結させる。

## `_ready()`での実装

`_ready()`ではUIの初期化処理・シグナル接続を行う。子ノードへの参照は`@onready`または`%UniqueName`（シーン内のユニーク名）で取得する。

```gdscript
func _ready() -> void:
	# 子ノードへの参照は@onreadyで取得済み（シーンツリーで事前配置）
	_apply_theme()
	_setup_events()

func _apply_theme() -> void:
	_bg.self_modulate = UiTheme.COLOR_BACKGROUND_CARD

func _setup_events() -> void:
	_confirm_button.pressed.connect(_on_confirm_pressed)
```

## `_exit_tree()`での実装

`_exit_tree()`ではすべての外部リソース参照・シグナル接続を確実に解放する。Godotは子ノードの`queue_free()`を自動的に伝播するため、Phaserの`container.destroy(true)`に相当する処理を手書きする必要はない。

```gdscript
func _exit_tree() -> void:
	# GameState等Autoloadのシグナル購読は必ず解除する（Autoload側は自動破棄されないため）
	if GameState.gold_changed.is_connected(_on_gold_changed):
		GameState.gold_changed.disconnect(_on_gold_changed)

	# Tween停止
	if _active_tween and _active_tween.is_valid():
		_active_tween.kill()

	# タイマー停止
	if _timer:
		_timer.stop()
```

### 破棄チェックリスト

- [ ] `GameState`等Autoloadへのシグナル購読解除（Autoloadは破棄されないため明示的な`disconnect()`が必要）
- [ ] `Tween`の停止（`kill()`）
- [ ] `Timer`ノードの停止
- [ ] 子ノードは`queue_free()`の自動伝播に任せる（手動`destroy()`呼び出しは不要）

> 同一シーンツリー内の子`Control`ノードへの接続（`self`が発行元・子が購読側等）はノード破棄時にGodotが自動的に切断する。**明示的な`disconnect()`が必須なのはAutoload（`GameState`）など、寿命がノードと異なる発行元への接続のみ**。

## テーマ（UiTheme）の活用

色やサイズは`UiTheme`定数、またはGodotの`Theme`リソースを使用し、ハードコーディングを避ける。

```gdscript
const UiTheme = preload("res://shared/theme/theme.gd")

func _apply_theme() -> void:
	_bg.self_modulate = UiTheme.COLOR_BACKGROUND_PRIMARY
	_title_label.add_theme_font_size_override("font_size", UiTheme.FONT_SIZE_MEDIUM)
```

Godot標準の`Theme`リソース（`.tres`）を併用する場合も、色・フォントサイズの実値は`UiTheme`定数から取得し、`Theme`リソース側にハードコードしない。

## コンポーネントの構成パターン

### 単純なコンポーネント

```gdscript
class_name GoldDisplay
extends Control

@onready var _gold_label: Label = %GoldLabel

func update_gold(amount: int) -> void:
	_gold_label.text = "%s G" % _format_number(amount)

func _format_number(n: int) -> String:
	return String.num_int64(n)
```

### 状態監視するコンポーネント

```gdscript
class_name PhaseIndicator
extends Control

@onready var _phase_label: Label = %PhaseLabel

func _ready() -> void:
	_update_phase(GameState.get_state().current_phase)
	GameState.phase_changed.connect(_on_phase_changed)

func _on_phase_changed(_previous: StringName, next: StringName) -> void:
	_update_phase(next)

func _update_phase(phase: StringName) -> void:
	_phase_label.text = String(phase)

func _exit_tree() -> void:
	if GameState.phase_changed.is_connected(_on_phase_changed):
		GameState.phase_changed.disconnect(_on_phase_changed)
```

### 子コンポーネントを持つコンポーネント

```gdscript
class_name CardList
extends Control

const PlantCardScene = preload("res://features/garden/ui/plant_card.tscn")

var _cards: Array[PlantCard] = []

func setup(plants: Array[PlantState]) -> void:
	for card in _cards:
		card.queue_free()
	_cards.clear()

	for plant in plants:
		var card: PlantCard = PlantCardScene.instantiate()
		card.setup(plant)
		add_child(card)
		_cards.append(card)

# 子ノードはqueue_free()の自動伝播で解放されるため、
# 明示的なdestroy()の呼び出しや_exit_tree()での個別破棄は不要
```

## アニメーション

### `Tween`の使用

```gdscript
func fade_in() -> void:
	modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.3).set_ease(Tween.EASE_OUT)

func pulse() -> void:
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(1.1, 1.1), 0.2)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.2)
```

`create_tween()`で生成した`Tween`はノードにアタッチされ、ノード破棄時に自動的に停止する（Phaserのように`shutdown()`で`tweens.killAll()`を手書きする必要はない）。ノードを跨いで使い回す`Tween`インスタンスのみ、`_exit_tree()`で明示的に`kill()`する。

### アニメーション完了待ち

```gdscript
func show_async() -> void:
	modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.3)
	await tween.finished
```

## インタラクション

### クリックイベント

```gdscript
func _ready() -> void:
	gui_input.connect(_on_gui_input)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_handle_click()

func _exit_tree() -> void:
	if gui_input.is_connected(_on_gui_input):
		gui_input.disconnect(_on_gui_input)
	if mouse_entered.is_connected(_on_mouse_entered):
		mouse_entered.disconnect(_on_mouse_entered)
	if mouse_exited.is_connected(_on_mouse_exited):
		mouse_exited.disconnect(_on_mouse_exited)
```

### ホバーエフェクト

```gdscript
func _on_mouse_entered() -> void:
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(1.05, 1.05), 0.1)

func _on_mouse_exited() -> void:
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.1)
```

## 禁止事項

- `setup()`（初期化メソッド）を呼ばずにコンポーネントを使用する
- Autoloadへのシグナル購読を`_exit_tree()`で解除しない
- `UiTheme`を使わずに色をハードコーディングする
- `Tween`/`Timer`の停止漏れ（ノード跨ぎで使い回す場合のみ該当）
- シーン外で`Control`ノードを`new()`して管理する（Godotでは`.tscn`の`instantiate()`を使う）
