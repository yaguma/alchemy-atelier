# Plan: pixel-art-remaining-screens

## Requirements Summary

`docs/dev/plans/garden-alchemy-visual-refresh/`（PR済み）でタイトル・庭・調合画面、および共通UI（RankHud・TabBar）に確立したドット絵（ピクセルアート）UIデザインを、`.claude/rules/design-guide.md`が現在も「対象外」と明記しているguild（ギルド納品結果画面）・rank（昇格試験/ゲームクリア・オーバー結果画面）・workshop（工房強化・ショップ画面、購入確認ダイアログ含む）の3画面へ展開する。

ヒアリングで確定した方針:

- **適用パターンは庭・調合と完全に同一**にする: 画面専用の背景1枚絵（`TextureRect`、`PixelBackdropApplier`経由）＋既存共通カードパネル（`UiTheme.make_panel_stylebox()` / `UiTheme.PANEL_TEXTURE_PIXEL`）＋既存ボタン（`ButtonStyleApplier.apply_button_style()`）＋既存フォント（`UiTheme.apply_pixel_font()` / `FONT_PIXEL_JP`）をそのまま再利用する。**UiTheme側に新規インフラを追加する必要はない**（ボタン4バリアント・パネルStyleBoxTexture・フォント適用ヘルパー・`PixelBackdropApplier`は前Planで実装済みで、そのまま流用できることを確認済み）
- guild（`GuildDeliveryScreen`。調合画面への埋め込みオーバーレイとして表示される）にも**専用の背景イラスト**を新規生成する（調合背景をそのまま流用しない。納品演出として画面の切り替わりを視覚的に示す）
- 3画面分の新規背景アセット（`guild_delivery_backdrop_pixel.png` / `workshop_backdrop_pixel.png` / `rank_result_backdrop_pixel.png`）を`atelier-image-gen`スキル（Gemini API）で生成する
- 対象外（本Planでも変更しない）: `atelier/shared/ui/pause_menu.gd`（一時停止メニュー）、`atelier/features/title/`・`settings/`・`save_load/`（既存のまま）。design-guide.mdのボタン4バリアントの意味論・角丸規定・カラー参照ルール自体も変更しない（適用範囲の記述のみ更新する）

## Design Overview

### 既存インターフェース（調査済み、変更なし・そのまま再利用）

- `PixelBackdropApplier.apply(rect: TextureRect, texture: Texture2D)`（`atelier/shared/ui/pixel_backdrop_applier.gd`）: 背景1枚絵の共通適用処理。`GardenBackdropPixel`/`AlchemyBackdropPixel`と同型の薄いラッパーискрипты（`class_name XxxBackdropPixel extends TextureRect` + `_ready()`で`PixelBackdropApplier.apply(self, BACKDROP_TEXTURE)`のみ）を3画面分複製すればよい
- `UiTheme.make_panel_stylebox() -> StyleBoxTexture`（`atelier/shared/theme/theme.gd`）: カードパネル共通9-slice。バリアント無しで単一キャッシュ、そのまま呼び出せる
- `UiTheme.apply_pixel_font(control: Control)`: `FONT_PIXEL_JP`（DotGothic16）を対象ノードへ適用する単一口。全Label系ノードに個別適用する
- `ButtonStyleApplier.apply_button_style(button: Button, variant: UiTheme.ButtonVariant)`: 4バリアント（PRIMARY/SECONDARY/DANGER/TERTIARY）をそのまま流用
- 3画面とも現状`main_theme.tres`（フォントのみ設定、StyleBox一切なし）に依存した素のGodot既定Controlスタイルで、庭・調合と違いいかなる装飾も未着手（`self_modulate`等の無効化された残骸すら無い、まっさらな状態）と確認済み

### 新規インターフェース設計

```gdscript
# atelier/features/guild/ui/guild_delivery_backdrop.gd（新規、GardenBackdropPixelと同型）
class_name GuildDeliveryBackdropPixel
extends TextureRect
const BACKDROP_TEXTURE: Texture2D = preload("res://assets/ui/guild/guild_delivery_backdrop_pixel.png")
func _ready() -> void:
	PixelBackdropApplier.apply(self, BACKDROP_TEXTURE)

# atelier/features/workshop/ui/workshop_backdrop.gd（新規、同型）
class_name WorkshopBackdropPixel
extends TextureRect
const BACKDROP_TEXTURE: Texture2D = preload("res://assets/ui/workshop/workshop_backdrop_pixel.png")

# atelier/features/rank/ui/rank_result_backdrop.gd（新規、同型）
class_name RankResultBackdropPixel
extends TextureRect
const BACKDROP_TEXTURE: Texture2D = preload("res://assets/ui/rank/rank_result_backdrop_pixel.png")
```

- `GuildDeliveryScreen`/`WorkshopScreen`/`ResultScreen`: 各ルート`Control`に対応する`XxxBackdropPixel`を最背面ノードとして追加し、既存の`VBoxContainer`（or `CenterContainer`）をルート直下の`PanelContainer`（`%ContentPanel`等、`make_panel_stylebox()`適用）でラップする 🟡（garden/alchemyの`%SlotPanel`と同じ「新設ラップ＋既存子をその内側へ移す」方針）
- `GuildDeliveryResultRow`（`atelier/features/guild/ui/guild_delivery_result_row.tscn`）: garden/alchemyの`SeedEntryRow`/`MaterialEntryRow`と同様、ルート`HBoxContainer`を`%RowPanel`（`PanelContainer`、`make_panel_stylebox()`適用）でカード化する 🟡
- `UpgradeItemRow`（`atelier/features/workshop/ui/upgrade_item_row.tscn`）: 同様に`%RowPanel`でカード化する 🟡
- `PurchaseConfirmDialog`（`atelier/features/workshop/ui/purchase_confirm_dialog.tscn`）: モーダルダイアログのため専用背景1枚絵は不要。ルート`RootContainer`を`%DialogPanel`（`PanelContainer`、`make_panel_stylebox()`適用）でラップし、既存の`%OverlayLayer`（workshop_screen.tscn、半透明の全画面Control）上に載せる 🟡
- ボタンバリアント割当て（🔴 実装時に画面バランスを見て調整可、design-guide.mdの意味論に沿った初期案）:
  - `GuildDeliveryScreen.ContinueButton` → PRIMARY（結果確認を締めて次へ進む確定操作）
  - `WorkshopScreen.PermanentTabButton` / `ConsumableTabButton` → SECONDARY（`main.tscn`の`GardenTabButton`/`AlchemyTabButton`と同じ扱い。現状`toggle_mode`ではなく`disabled`で購入可否のみ表現しており「選択中タブ」の視覚差は無いため、タブらしい選択表現は012相当の回帰確認タスクで実機確認する）
  - `WorkshopScreen.CloseButton` → SECONDARY（画面を離脱する「戻る」系操作）
  - `UpgradeItemRow.PurchaseButton` → PRIMARY（購入確定操作）
  - `PurchaseConfirmDialog.ConfirmButton` → PRIMARY / `CancelButton` → SECONDARY（design-guide.mdのプライマリ/セカンダリ意味論に直接一致）
  - `ResultScreen`にはボタンが存在しない（`result_screen.gd`のコメントで「閉じる/次へ進むボタンは実装しない（FR-402, FR-404）」と明記済み、FR番号は既存要件文書の参照でありPlanでは変更しない）。本Planでも追加しない

### 新規アセット一覧

| パス | 用途 | 概算解像度 | 信号 |
|---|---|---|---|
| `atelier/assets/ui/guild/guild_delivery_backdrop_pixel.png` | ギルド納品結果画面の背景1枚絵（コーラル系、design-guide.mdのギルド納品アクセント色を踏襲） | 480x270程度（garden/alchemy同等） | 🟡 |
| `atelier/assets/ui/workshop/workshop_backdrop_pixel.png` | 工房強化・ショップ画面の背景1枚絵（ラベンダー系、design-guide.mdの工房強化アクセント色を踏襲） | 480x270程度 | 🟡 |
| `atelier/assets/ui/rank/rank_result_backdrop_pixel.png` | 昇格試験/ゲームクリア・オーバー結果画面の背景1枚絵（到達・区切りを示す演出、design-guide.mdにrank専用アクセント色の定義が無いため配色は生成時の裁量） | 480x270程度 | 🔴 |

カードパネル・ボタンテクスチャは3画面とも**新規生成しない**（`UiTheme.PANEL_TEXTURE_PIXEL`・4種ボタンテクスチャの共通アセットをそのまま再利用）。

## Task Dependency Graph

```
001 guild-delivery-backdrop-asset ─┐
002 workshop-backdrop-asset ───────┼─(並行可)
003 rank-result-backdrop-asset ────┘
        │
        ▼
004 guild-delivery-backdrop-script (dep: 001)
005 workshop-backdrop-script       (dep: 002)
006 rank-result-backdrop-script    (dep: 003)
        │
        ▼
007 guild-delivery-screen-integration    (dep: 004)
008 workshop-screen-integration          (dep: 005)
009 workshop-purchase-dialog-integration (dep: []（既存UiThemeインフラのみに依存、005と並行可）)
010 rank-result-screen-integration       (dep: 006)
        │
        ▼
011 design-guide-and-docs-update (dep: 007, 008, 009, 010)
        │
        ▼
012 regression-check (dep: 011)
```

## Cross-Plan Dependencies

- `docs/dev/plans/garden-alchemy-visual-refresh/`: `UiTheme`のボタン4バリアント・`make_panel_stylebox()`・`apply_pixel_font()`・`PixelBackdropApplier`・`ButtonStyleApplier`を前提として再利用する（本Planでは一切変更しない）
- `docs/dev/plans/title-screen-redesign/`: `FONT_PIXEL_JP`・`project.godot`の`[display]`stretch設定（既にグローバル適用済み、変更不要）
- `.claude/rules/design-guide.md`: 「guild・rank・workshopの3画面は水彩ファンタジースタイルのまま対象外」の記述をタスク011で改訂する。改訂後は例外規定が実質不要になる（全画面がドット絵に統一されるため）ことも踏まえ、水彩ファンタジースタイルの記述自体を「将来水彩を使う場合の設計原則」として残すか、ドット絵をプロジェクト全体の標準として書き換えるかはタスク011で判断する
- `docs/design/atelier-alchemy-core/ui-design/screens/guild-delivery.md`: 既存の6行目に「本画面はタイトル画面と同じドット絵技法に刷新済み」という2026-09-18付の注記が**既に存在する**が、実装（`guild_delivery_screen.gd`/`.tscn`）は現時点でこの注記に反する素の未装飾状態であることを確認済み（🔴 ドキュメントドリフト、CLAUDE.mdが警告する過去の類似事例と同種）。タスク011で本Planの実装完了後にこの注記の内容が実態と一致することを確認し、必要なら日付・文面を本Planの実施日に合わせて修正する
