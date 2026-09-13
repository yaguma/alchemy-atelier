# レイヤー別ノード構成リファレンス

対象画面に実際に必要なレイヤーだけを組み合わせる。「背景」「HUD」の2層だけの画面が最も多い。

**注意**: 以下は「あるべき姿」であり、現状の実装がそのまま持っているわけではない。実際に
`garden_screen.tscn`/`workshop_screen.tscn`を見ると、画面ルートの`Control`の直下にいきなり
本文用の`VBoxContainer`が1つあるだけで、背景専用ノードは存在せず、ヘッダー行（ゴールド表示・
タブボタン等）も本文と同じコンテナに混在している。モーダル用の`OverlayLayer`だけは実在するが、
画面によって`OverlayLayer`/`SettingsOverlayLayer`と名前が揺れている。つまりこのレイヤー分解を
使うタスクでは、**既存のレイヤーを使う**のではなく**その場でレイヤーをノードとして実体化する**
作業が毎回必要になる可能性が高い。着手前に対象の`.tscn`を開いて実際のノードツリーを確認すること。

## 背景レイヤー

このプロジェクトに視差スクロールやタイルマップの世界は存在しない。背景の役目は
「`.claude/rules/design-guide.md`の温かい背景色を敷き、必要なら控えめな装飾を足す」こと。
既存画面には背景専用ノードがないことがほとんどなので、画面ルートの最初の子として追加する
（`anchors_preset = PRESET_FULL_RECT`で画面全体を覆い、本文コンテナより手前＝ツリー上で先に置く）。

```gdscript
# 最小構成: UiThemeの背景色を敷くだけ
@onready var _background: ColorRect = %Background

func _apply_theme() -> void:
	_background.color = UiTheme.COLOR_BACKGROUND_PRIMARY
```

装飾画像を足す場合は`TextureRect`を背景の上・本体UIの下に置く（`stretch_mode`は
`STRETCH_KEEP_ASPECT_COVERED`が画面サイズ差に強い）。**フェーズ独自の背景色をハードコードしない**
（design-guide.md「フェーズ独自のカードスタイル」禁止と同じ理由）。フェーズごとの個性はアクセントカラー
（庭=リーフグリーン等）を見出しの左バー等の小さな要素にだけ使う。

## ゲームプレイ空間レイヤー

素材カード・調合スロット・投入枠のように「プレイヤーが操作する対象」を並べる層。`Camera2D`や
`Node2D`のワールドは基本的に不要——既存実装（`GardenScreen`, `AlchemyScreen`等）はすべて
`Container`系ノード（`GridContainer`, `HBoxContainer`等）で完結している。

```gdscript
# features/{feature}/ui/{screen}.gd の典型パターン（garden_screen.gdを参照）
@onready var _slots_container: Container = %SlotsContainer

func _refresh() -> void:
	for child in _slots_container.get_children():
		_slots_container.remove_child(child)
		child.queue_free()
	# ... 状態に応じてカード/スロットのシーンをinstantiateしてadd_child
```

一覧の項目数が多く頻繁に生成・破棄する場合は`godot-best-practices.md`の「オブジェクトプーリング」を
検討する。ただしプール貸出中フラグに`visible`を流用しない（可視性カリングと衝突するため、専用の
`_in_use: bool`を使う）。

## HUD/操作UIレイヤー

全画面共通の`RankHud`（`atelier/shared/ui/rank_hud.gd`。ランク名・ノルマバー・残ターン・所持G）が
既に存在するので、新しい共通ステータス表示を作る前に必ずこれを再利用できないか確認する（これは
実際に画面共通の別ノードとして分離済み）。一方、画面固有の常時要素（ゴールド表示・タブボタン等の
ヘッダー行）は現状ほとんどの画面で本文コンテンツと同じ`VBoxContainer`にフラットに並んでいるだけで、
構造上「HUD的な要素」として分離されてはいない。演出を足す機会に、ヘッダー行を専用の`HeaderRow`
コンテナとして本文と視覚的・構造的に区別しておくと、後から色や余白を独立に調整しやすくなる。ただし
既存の`%UniqueName`をGdUnit4テストが参照している場合は、移動でパスが変わらないか確認してから行う。

```gdscript
# RankHudはGameStateのみを参照する自己完結コンポーネント。
# 他画面はRankHudのsignal（例: menu_requested）を購読するだけで、内部実装には触れない
@onready var _rank_hud: RankHud = %RankHud

func _ready() -> void:
	_rank_hud.menu_requested.connect(_on_menu_requested)
```

新しく画面固有のHUD要素を足す場合も、色・フォントサイズは`UiTheme`経由、レイアウトは
`MarginContainer`/`HBoxContainer`でRankHudの直下に固定する。

## モーダル/オーバーレイレイヤー

ポップアップは`PauseMenu`/`SettingsPanel`が既に使っている**`open_singleton()`パターン**を踏襲する。
新方式（例えば独自の`CanvasLayer`を毎回手で組む）を発明しない。

```gdscript
# 呼び出し元（例: MainScene, PauseMenu）が持つ最小限の実装
var _my_modal: MyModal = null

func _on_open_button_pressed() -> void:
	_my_modal = MyModal.open_singleton(_my_modal, _overlay_parent, _on_modal_closed)

func _on_modal_closed() -> void:
	_my_modal = null
```

```gdscript
# モーダル側（例: pause_menu.gd）が実装する静的ヘルパー
static func open_singleton(
	current: MyModal, overlay_parent: Node, on_closed: Callable
) -> MyModal:
	if is_instance_valid(current):
		return current  # 多重起動防止。既存インスタンスをそのまま返す
	var modal: MyModal = MyModalScene.instantiate()
	overlay_parent.add_child(modal)
	modal.closed.connect(on_closed)
	return modal
```

`overlay_parent`（呼び出し元が持つ`%OverlayLayer`等）を最前面に描画されるノードとして用意しておけば、
モーダルはその子として追加されるだけでZ順の心配をしなくてよい。モーダルは背後のボタンを誤って
押せないよう、全画面を覆う`Control`（`anchors_preset = PRESET_FULL_RECT`）を最下層に敷く。

既存画面のオーバーレイ用ノードは`workshop_screen.tscn`の`OverlayLayer`、`main.tscn`の
`SettingsOverlayLayer`のように名前が揺れている。新規に追加する場合は`OverlayLayer`に統一し、
今回のタスクと無関係な既存ノードを名前を揃えるためだけにリネームしない（無関係な変更は
`.claude/rules/planning.md`の「計画は軽量に」にも反する）。

## MainSceneでの合成（参考）

本プロジェクトのメイン4画面（庭・調合・工房・結果）はシーン遷移ではなく、`scenes/main.gd`が
`GameState.phase_changed`を購読して各画面の`visible`を排他的に切り替える方式で合成されている
（`architecture.md`「シーン構成」参照）。新しい常駐画面を追加する場合もこの方式に合わせ、
シーン遷移や動的instantiateではなく「常駐+visible切替」を基本にする。
