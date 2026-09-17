# Plan: garden-alchemy-visual-refresh

## Requirements Summary

タイトル画面（PR #55、`docs/dev/plans/title-screen-redesign/`）で確立したドット絵UIデザインを、庭（garden）画面・調合（alchemy）画面、および両画面と常時同時表示される共通UI（RankHud・TabBar、`atelier/scenes/main.tscn`常駐）へ展開する。

ヒアリングで確定した方針:

- **ドット絵に統一**する（水彩には統一しない）。`.claude/rules/design-guide.md`の「ドット絵技法はタイトル画面のみの例外」規定を、庭・調合・共通UI（RankHud/TabBar）も対象に含める方針へ改訂する（このPlanのスコープに含む）
- **フォント**: 庭・調合・共通UIもDotGothic16（`UiTheme.FONT_PIXEL_JP`、既存）に統一する
- **対象要素**: ボタン・フォントに加え、**背景・カードパネルもフル新規制作**する（タイトル画面と同等の完成度）
- **共通UI**: RankHud・TabBarも本Planでドット絵化する
- **カードパネルアセット**: 庭・調合・RankHud・TabBarで**共通1枚**のドット絵9-slice画像を使う（画面ごとの個別テクスチャは作らない）
- **TabBar**: 専用タブ形状アセットは新規生成せず、既存4バリアントボタンテクスチャ（`ButtonStyleApplier`経由）をそのまま流用する
- **在庫リスト行**（`SeedEntryRow`/`MaterialEntryRow`）も新規カードパネルでカード化する（ボタン/フォントのみの最小適用には絞らない）

**スコープ外**（今回は対象としない）: guild（ギルド納品）・rank（ランク進行・昇格試験）・workshop（工房強化）の3画面。これらは既存の水彩スタイル前提のまま。

## Design Overview

### 既存インターフェース（調査済み、変更なし）

- `UiTheme`（`atelier/shared/theme/theme.gd`）: `ButtonVariant`/`ButtonState`列挙型、`make_button_stylebox(variant, state) -> StyleBoxTexture`（9-slice StyleBoxTexture方式、`_button_stylebox_cache`でキャッシュ、`BUTTON_TEXTURE_MARGIN`実測補正済み、HOVER/PRESSED/DISABLEDは`modulate_color`で表現）、`FONT_PIXEL_JP`（DotGothic16、既に定義済み）
- `ButtonStyleApplier.apply_button_style(button, variant)`: texture_filter=NEAREST、フォントサイズ・4状態文字色（focus/disabled含む、直近PRで修正済み）・4状態StyleBoxTextureを一括適用。シグネチャ変更不要で庭・調合・RankHud・TabBarのボタンにそのまま使える
- `TitleBackdropPixel`（`atelier/features/title/ui/title_backdrop.gd`）: `TextureRect`継承、`_ready()`でtexture代入・NEAREST・`STRETCH_KEEP_ASPECT_COVERED`・`EXPAND_IGNORE_SIZE`・`mouse_filter=IGNORE`を設定するだけの薄い実装。庭・調合の背景に複製可能なパターン
- 庭・調合画面（`garden_screen.tscn`/`alchemy_screen.tscn`）は現在Panel/PanelContainerノードを一切持たず、`PlantSlotView`/`AlchemySlotView`は`self_modulate`をルートControlに設定しているが背景が無いため視覚的に無効化されている。RankHud（`atelier/shared/ui/rank_hud.gd`）・TabBar（`main.tscn`内）も背景なしの透明`HBoxContainer`

### 新規インターフェース設計

```gdscript
# atelier/shared/theme/theme.gd への追加
const PANEL_TEXTURE_PIXEL: Texture2D = preload("res://assets/ui/pixel/panel_pixel.png")  # 🟡 庭/調合/RankHud/TabBar共通1枚
const PANEL_TEXTURE_MARGIN := 20  # 🔴 暫定値、アセット生成後に実測補正（BUTTON_TEXTURE_MARGINと同じワークフロー）
static var _panel_stylebox_cache: StyleBoxTexture = null  # 🟡 バリアントが無いため単一キャッシュで足りる

## 🟡 make_button_stylebox()と同型のStyleBoxTexture 9-slice生成。バリアントが無いため引数なし
static func make_panel_stylebox() -> StyleBoxTexture
```

- 状態別の色分け（庭5状態・調合2状態）は**新規テクスチャを増やさず**、既存`COLOR_SLOT_*`/`COLOR_ALCHEMY_SLOT_*`定数を新設する`%SlotPanel`（`PanelContainer`）の`self_modulate`に適用する方式を踏襲する（既存ロジックの移設のみ、破壊的変更は最小）🟡
- `PlantSlotView`/`AlchemySlotView`/`AlchemyPreviewPanel`/`SeedEntryRow`/`MaterialEntryRow`: ルートControlへの`self_modulate`設定を廃止し、新設する`%SlotPanel`（`add_theme_stylebox_override("panel", UiTheme.make_panel_stylebox())`）へ移す 🟡
- `GardenBackdropPixel`（`atelier/features/garden/ui/garden_backdrop.gd`）・`AlchemyBackdropPixel`（`atelier/features/alchemy/ui/alchemy_backdrop.gd`）: `TitleBackdropPixel`と同型の`TextureRect`継承薄いクラス 🟡
- `RankHud`: ルートの`HBoxContainer`を`PanelContainer`でラップし`make_panel_stylebox()`を適用する構造変更 🟡
- `TabBar`（`GardenTabButton`/`AlchemyTabButton`）: 新規アセットなし。`ButtonStyleApplier.apply_button_style()`をそのまま適用し、`toggle_mode`のpressed状態で選択中タブを表現する（視覚的な「タブらしさ」は回帰確認タスクで実機確認） 🔴

### 新規アセット一覧

| パス | 用途 | 概算解像度 | 信号 |
|---|---|---|---|
| `atelier/assets/ui/pixel/panel_pixel.png` | 庭/調合/RankHud/TabBar共通カードパネル9-slice | 32x32〜48x48程度 | 🟡 |
| `atelier/assets/ui/garden/garden_backdrop_pixel.png` | 庭画面背景1枚絵（リーフグリーン系） | 480x270程度（title同等） | 🟡 |
| `atelier/assets/ui/alchemy/alchemy_backdrop_pixel.png` | 調合画面背景1枚絵（アンバー系） | 480x270程度 | 🟡 |

## Task Dependency Graph

```
001 card-panel-asset ─┐
002 garden-backdrop-asset ─┼─(並行可)
003 alchemy-backdrop-asset ─┘
        │
        ▼
004 uitheme-panel-stylebox (dep: 001)
005 garden-backdrop-script (dep: 002)
006 alchemy-backdrop-script (dep: 003)
        │
        ▼
007 garden-screen-integration     (dep: 004, 005)
008 alchemy-screen-integration    (dep: 004, 006)
009 rank-hud-integration          (dep: 004)
010 tab-bar-integration           (dep: 004)
        │
        ▼
011 design-guide-update  (dep: 007, 008, 009, 010)
        │
        ▼
012 regression-check     (dep: 011)
```

## Cross-Plan Dependencies

- `docs/dev/plans/title-screen-redesign/`: `ButtonVariant`/`ButtonStyleApplier`/`make_button_stylebox()`/`FONT_PIXEL_JP`/`atelier/project.godot`の`[display]`stretch設定（本Planでは変更不要、既にグローバル適用済み）を前提として再利用する
- `.claude/rules/design-guide.md`: 「ドット絵技法はタイトル画面のみの例外」の記述をタスク011で改訂し、guild/rank/workshopは引き続き対象外であることを明記する
