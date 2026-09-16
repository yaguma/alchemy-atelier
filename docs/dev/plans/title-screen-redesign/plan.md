# Plan: title-screen-redesign

## Requirements Summary

直前に完了した`title-screen-design`Plan（`docs/dev/plans/title-screen-design/`、未コミット）は「水彩ファンタジー・暖色系パステル・角丸グラデーションStyleBox」路線でタイトル画面（`atelier/features/title/ui/title_screen.gd`/`.tscn`）の背景・ロゴ・ボタンを実装した。本Planはユーザーヒアリングの結果、**その路線を破棄し「ドット絵（ピクセルアート）」路線に作り直す**再設計Planである。

確定方針（ユーザーヒアリング済み）:

- スコープはタイトル画面本体（`title_screen.gd`/`.tscn`）＋その表示基盤（`UiTheme`, `ButtonStyleApplier`）。`SettingsPanel`のスタイル適用は引き続きスコープ外
- 配色は現状の暖色系パステル系統を概ね維持し、**描画技法のみ**をドット絵に変更する
- 実装方式は**画像アセット方式**（`atelier-image-gen`でドット絵PNGを生成し`TextureRect`/`StyleBoxTexture`＋`texture_filter=NEAREST`で表示）。前Planの`UiPanelStyleBox`（StyleBox手続き描画）は不採用（ただしクラス自体は他機能向け共通基盤として削除しない、スコープ外）
- フォントはドット絵風の日本語対応フォント（第一候補: **DotGothic16**、Google Fonts配布・SIL OFL 1.1）を新規導入する
- 前Planの成果物（`ui_panel_stylebox.gd`は残すが、`theme.gd`のボタントークン運用・`button_style_applier.gd`・`title_backdrop.gd`/`.tscn`・`title_emblem.png`・`title_screen.gd`/`.tscn`の変更分・関連テスト）は**本Planのタスク実装時に上書き・置き換える**
- `make_button_stylebox()`は新規関数を分けず**そのまま上書き**する（現状呼び出し元がTitleScreen以外に存在しないためgrep確認済み、YAGNI）
- ボタンのDISABLED状態は、旧実装（呼び出し側のmodulateに委ねる想定だが実質未使用）を是正し、`modulate_color`のアルファで実際に半透明化する
- `TitleBackdropPixel`はスクリプト付きクラスとして実装する（スクリプト無しTextureRectシーンにはしない）
- **ピクセルパーフェクトな整数倍スケールをゲーム全体（`project.godot`の`[display]`）に適用する**。ユーザーは「今後全体的にUI更新をしていく予定」と明言しており、タイトル画面限定のSubViewport方式は不採用。ただし既存5画面（庭・調合・ギルド納品・ランク・工房強化、いずれも水彩ファンタジー路線）が同じ低解像度・nearest拡縮の影響を受けるため、**回帰確認（タスク011）で影響を必ず確認すること**（🔴既存5画面の見た目が変わる可能性がある。今回のPlanでは他画面の再デザインまでは行わない）

## Design Overview

Plan サブエージェントによる設計（詳細はタスクファイル各所のInterfacesセクション参照）:

1. **`project.godot`の`[display]`セクション追加**: `window/stretch/mode="viewport"`, `window/stretch/aspect="keep"`, `window/stretch/scale_mode="integer"`（Godot 4.2+機能）＋低解像度の内部ビューポートサイズを設定し、整数倍スケールでのピクセルパーフェクト表示を実現する
2. **フォント**: `DotGothic16`（SIL OFL 1.1）を`atelier/assets/fonts/`に追加し、`UiTheme.FONT_PIXEL_JP`として公開する
3. **ドット絵アセット生成**: `atelier-image-gen`スキルでボタン4種（PRIMARY/SECONDARY/DANGER/TERTIARY）・タイトル背景1枚絵・タイトルロゴ紋章をドット絵PNGとして生成する
4. **`UiTheme.make_button_stylebox()`の置き換え**: `StyleBoxTexture`＋`AXIS_STRETCH_MODE_TILE`の9-slice方式に変更し、HOVER/PRESSED/DISABLEDを`modulate_color`で表現する
5. **`ButtonStyleApplier`**: `texture_filter = TEXTURE_FILTER_NEAREST`の設定を追加する（シグネチャ・戻り値の扱いは無変更）
6. **`TitleBackdropPixel`**: `title_backdrop.gd`を置き換える新クラス。1枚絵を`TextureRect`で表示するだけの薄い実装（水彩版の`GradientTexture2D`+`_draw()`丘・草の自前描画は全廃）
7. **`TitleScreen._apply_theme()`**: ロゴ・ボタンへの`FONT_PIXEL_JP`適用、`EmblemRect`への`texture_filter`設定を追加する。`.tscn`のノード構成（`LogoContainer`/`RootContainer`のレイアウト）自体は変更不要見込み
8. **`design-guide.md`改訂**: タイトル画面がドット絵技法を採用した旨、角丸基準・禁止事項節への追記を行う（プロジェクト全体を水彩からドット絵に統一するものではない）

## Task Dependency Graph

```
001 project.godot Viewportストレッチ設定（整数スケール対応）
002 ドット絵風日本語フォント（DotGothic16）導入
003 ボタン4種のドット絵テクスチャ生成（atelier-image-gen）
004 タイトル背景ドット絵1枚絵生成（atelier-image-gen）
005 タイトルロゴ紋章のドット絵再生成（atelier-image-gen）
  （001〜005は相互に独立、並行実施可）

006 UiThemeをドット絵ボタン方式に置き換え
  └─ 依存: 002（フォント）, 003（ボタンテクスチャ）※preload()にファイル実在が必須
        └─▶ 007 ButtonStyleApplierにtexture_filter追加
              └─ 依存: 006

008 TitleBackdropPixel実装
  └─ 依存: 004（背景画像）

009 TitleScreen本体へドット絵スタイル統合（背景・ロゴ・ボタン・フォント）
  └─ 依存: 002, 005, 007, 008
        └─▶ 010 design-guide.md改訂
              └─ 依存: 009
                    └─▶ 011 全体回帰確認（gdlint/gdformat/GdUnit4全件、project.godot変更が既存5画面に与える影響確認を含む）
                          └─ 依存: 001, 006, 007, 008, 009, 010
```

推奨実施順序: (001・002・003・004・005を並行) → 006 → 007 → (008は004完了後いつでも) → 009 → 010 → 011

## Cross-Plan Dependencies

- タスク001（`project.godot`のViewportストレッチ設定）は**プロジェクト全体のレンダリング解像度・拡縮方式に影響するグローバル変更**である。既存の`garden`/`alchemy`/`guild`/`rank`/`workshop`各Plan（水彩ファンタジー路線のまま、未対応）の画面が意図せず低解像度・nearest拡縮の影響を受ける可能性がある。本Planでは他画面の再デザインは行わないため、**タスク011の回帰確認で「既存5画面のテストが引き続きPASSすること」は確認するが、「見た目が破綻していないか」は自動テストでは検出できない**。ユーザーは今後プロジェクト全体をUI更新していく方針のため許容しているが、次にいずれかの既存画面Planへ着手する際は、本Planが変更した`project.godot`の`[display]`設定を前提に置くこと
- `UiTheme.make_button_stylebox()`は本Planで水彩実装からドット絵実装へ**上書き**される（別関数への分離はしない）。将来水彩版ボタンが別画面で必要になった場合は、そのPlanで改めて検討すること
- `UiPanelStyleBox`（`shared/theme/ui_panel_stylebox.gd`）・`make_card_stylebox()`は本Planでは変更しない（カード用の共通基盤として温存、スコープ外）
- 前Plan `title-screen-design` の成果物は本Planのタスク実装（dev-run）で上書きされる想定。`docs/dev/plans/title-screen-design/`のドキュメント自体は履歴として残す（削除しない）
