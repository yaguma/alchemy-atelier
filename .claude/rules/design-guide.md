# デザインガイドルール

> 🔴 2026-08-06改訂: 技術スタックがGodot 4.x + GDScriptに確定済み（`CLAUDE.md`参照）のため、コード例をTypeScript importからGDScriptの`UiTheme`参照構文に更新した。デザイン原則・カラー体系自体は変更なし。
> 🔴 2026-09-16改訂: タイトル画面がドット絵（ピクセルアート）技法を採用したため（`docs/dev/plans/title-screen-redesign/`参照）、本ファイルにその技法選択の分岐を追記した。**プロジェクト全体のデフォルトは引き続き水彩ファンタジースタイルであり、タイトル画面のみの限定的な分岐である**。他画面（庭・調合・ギルド納品・工房強化等）を水彩からドット絵へ統一するものではない。
> 🔴 2026-09-18改訂: `docs/dev/plans/garden-alchemy-visual-refresh/`にて、タイトル画面のドット絵技法を**庭・調合の2画面、および両画面と常時同時表示される共通UI（`RankHud`・`TabBar`）**にも展開した。これによりドット絵技法の適用範囲は「タイトル画面のみ」から「タイトル・庭・調合・共通UI（RankHud/TabBar）」に拡大したが、**guild（ギルド納品）・rank（ランク進行・昇格試験）・workshop（工房強化）の3画面は引き続き水彩ファンタジースタイルがデフォルトのまま**であり、対象外である。以降の本ファイル中の「タイトル画面のみの例外」という記述は、上記の拡大後の範囲（タイトル・庭・調合・共通UI）を指すものと読み替えること。
> 🔵 2026-09-19改訂: `docs/dev/plans/pixel-art-remaining-screens/`にて、上記で対象外としていたguild（ギルド納品結果画面）・rank（昇格試験/ゲームクリア・オーバー結果画面）・workshop（工房強化・ショップ画面、購入確認ダイアログ含む）の3画面にもドット絵技法を展開し、**5機能（garden/alchemy/guild/rank/workshop）の全画面がドット絵技法に統一された**。以降「水彩ファンタジースタイルはguild/rank/workshopの3画面に適用される」という記述は誤りであり、下記「概要」節・「ボタン」節の例外注記を参照すること。水彩ファンタジースタイルの節自体は、将来新画面を追加する際やドット絵からの回帰を検討する際の設計原則として残す（現状は全画面で未使用）。
> 🔵 2026-09-22改訂: 上記の「5機能の全画面統一」は庭・調合・ギルド納品・工房強化・ランクという**ゲームプレイ5機能内のUI**のみを指しており、`title-settings-screens-extension` Planで実装された周辺UI（`atelier/features/save_load/ui/slot_select_screen.tscn`のスロット選択画面、`atelier/shared/ui/pause_menu.tscn`のゲーム中一時停止メニュー、`atelier/shared/ui/settings_panel.tscn`の設定パネル）はドット絵統一の対象リストに含まれておらず、水彩スタイル未適用のまま取り残されていた（design-guide.md自体にも記載が無かった）。本改訂で上記3画面/共通コンポーネントにも`PixelBackdropApplier`（スロット選択画面のみ、`TitleBackdrop`を再利用）・`UiTheme.apply_panel_style()`・`ButtonStyleApplier.apply_button_style()`・`UiTheme.apply_pixel_font()`を適用し、タイトル〜起動フロー〜ゲーム中断メニューまで含めた全UIがドット絵技法に統一された。`CheckButton`/`HSlider`（設定パネルの音量スライダー・トグル）はドット絵9-slice化の前例が無いためスコープ外とし、フォントのみ合わせている。

## 概要

本プロジェクトは「水彩ファンタジースタイル」を採用する方針で設計されたが、2026-09-19時点で**実際に使用されている画面は存在しない**（後述の通り全画面がドット絵技法に置き換わったため）。以下の記述は将来水彩ファンタジースタイルへ回帰・新規適用する場合の設計原則として残す。
詳細は `docs/design/atelier-alchemy-core/ui-design/` を参照。

> 🔵 2026-09-19時点で、タイトル・庭・調合・ギルド納品・工房強化・ランク（昇格試験/結果画面）の**全画面**、および共通UI（`RankHud`・`TabBar`）が、ドット絵（ピクセルアート）技法を採用している（`docs/design/atelier-alchemy-core/ui-design/screens/`配下の各画面設計書参照。2026-09-16にタイトル画面から開始し、2026-09-18に`docs/dev/plans/garden-alchemy-visual-refresh/`で庭・調合・共通UIへ、2026-09-19に`docs/dev/plans/pixel-art-remaining-screens/`でguild・rank・workshopへ拡大し、全画面統一が完了した）。背景・ボタン・カードパネルをドット絵アセット＋`texture_filter`のnearest設定で構成し、フォントもDotGothic16（ドット絵風日本語フォント）を使用する。上記「概要」の水彩ファンタジースタイルの記述は、現状どの画面にも適用されていない（将来の設計原則として残置）。

---

## デザイン原則

- **柔らかさ**: 大きめの角丸、パステルカラー、ふんわりした影
- **温もり**: クリーム系の温かい背景、ゴールドのアクセント
- **明瞭さ**: 適切なコントラスト、アイコン+テキスト併記
- **統一感**: 全フェーズで同じカード・ボタン・枠線スタイル

---

## カラー参照ルール

### 必須: UiTheme 経由で参照

```gdscript
# OK: UiThemeはclass_name経由のグローバル参照（preload+constで再宣言するとclass_nameを隠しコンパイルエラーになるため行わない）
var bg := UiTheme.COLOR_BACKGROUND_PRIMARY
var radius := UiTheme.RADIUS_MD

# NG: 色のハードコード
var bg := Color("#333333")
var border := Color("#ffd54f")
```

### 新しい色が必要な場合

1. まず `design-guide.md` のパレットに該当するトークンがないか確認
2. なければ `shared/theme/theme.gd`（`UiTheme`）にトークンを追加してから使用
3. 直接ハードコードは禁止

---

## コンポーネントスタイル統一ルール

### カード / パネル（全フェーズ共通）

| 属性 | 値 | トークン |
|------|-----|---------|
| 背景 | 白 | `UiTheme.COLOR_BACKGROUND_CARD` |
| 枠線 | 2px | `UiTheme.BORDER_REGULAR` + `UiTheme.COLOR_BORDER_DEFAULT` |
| 角丸 | 12px | `UiTheme.RADIUS_MD` |
| 影 | 小 | `UiTheme.SHADOW_SM` |
| ホバー | 影拡大 + 枠線強調 | `UiTheme.SHADOW_MD` + `UiTheme.COLOR_BORDER_STRONG` |
| 選択 | フォーカスリング | `UiTheme.BORDER_THICK` + `UiTheme.COLOR_BORDER_FOCUS` + `UiTheme.SHADOW_GLOW_FOCUS` |

**フェーズ独自のカード枠色・背景色をハードコードしない。**

### ボタン（4種類のみ）

| バリアント | 用途 | 背景 | テキスト |
|-----------|------|------|---------|
| **プライマリ** | 確定（受注・納品・決定） | `brand.primary` (草色) | 白 |
| **セカンダリ** | キャンセル・戻る | 透明 + 枠線 | `text.primary` |
| **デンジャー** | 日終了・破棄 | `status.error` | 白 |
| **ターシャリ** | 設定など最も控えめなアクション | `surface.card` + 薄い枠線(1.5px) | `text.muted` (13px) |

これ以外のボタンスタイルを新たに作らない。

> 🔵 上記4バリアントの**意味論（用途）はドット絵技法の画面でも変わらない**。実装方式（水彩StyleBoxの手続き描画か、ドット絵StyleBoxTextureの9-slice展開か）は画面ごとに異なるため、`docs/design/atelier-alchemy-core/ui-design/screens/`配下の個別画面設計書を参照すること。
>
> 🔴 2026-09-16追記: タイトル画面はユーザーの実機確認フィードバックにより、上記4バリアントの使い分けを行わず**4ボタン全てを単一スタイル（セカンダリ）に統一する**画面固有の例外とした（詳細は[`screens/title.md`](../../docs/design/atelier-alchemy-core/ui-design/screens/title.md)参照）。これは「確定/取消/危険/控えめ」の意味論による差別化がタイトル画面の単純な導線には過剰だったための個別判断であり、本表のバリアント意味論自体を否定するものではない。他画面でバリアントを使い分ける場合は本表の用途に従うこと。

### フェーズ別の個性の出し方

フェーズごとに色を変えたい場合は、**アクセントカラー**のみ使用する:

| フェーズ | アクセント | 使用箇所 |
|---------|----------|---------|
| 庭 | リーフグリーン (#8CC084) | フェーズタイトル、セクション見出しの左バー |
| 調合 | アンバー (#D4A76A) | 同上 |
| ギルド納品 | コーラル (#E8A87C) | 同上 |
| 工房強化 | ラベンダー (#B8A9D4) | 同上 |

カード枠・ボタン・背景にフェーズ色を使うのは禁止。

---

## 角丸の基準

| 用途 | 値 | トークン |
|------|-----|---------|
| バッジ・タグ | 6px | `UiTheme.RADIUS_SM` |
| カード・パネル | 12px | `UiTheme.RADIUS_MD` |
| ボタン | 18px | `UiTheme.RADIUS_LG` |
| モーダル・トースト | 24px | `UiTheme.RADIUS_XL` |

角丸なし（0px）は原則使用しない。

> 🔵 ドット絵アセット（タイトル・庭・調合・共通UI）の角は、角丸ではなくピクセル単位の面取りで表現する。上記`RADIUS_*`トークンは水彩StyleBoxにのみ適用され、ドット絵StyleBoxTexture/9-sliceには適用しない。

---

## 禁止事項

- 色のハードコード（`Color("#333333")` 等を直接書く）
- フェーズ独自のカードスタイル（枠色・背景色・角丸を独自定義）
- 定義されていないボタンバリアントの追加
- ダーク背景の使用（サイドバー・ヘッダー・フッターを含む）
- 青紫（`#6366f1`）などテーマと無関係な色の使用
- ドット絵アセットに`texture_filter`のnearest設定を忘れ、滲ませる（`CanvasItem.texture_filter = TEXTURE_FILTER_NEAREST`相当を必ず設定する）
