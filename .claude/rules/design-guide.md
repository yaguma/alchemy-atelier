# デザインガイドルール

> 🔴 2026-08-06改訂: 技術スタックがGodot 4.x + GDScriptに確定済み（`CLAUDE.md`参照）のため、コード例をTypeScript importからGDScriptの`UiTheme`参照構文に更新した。デザイン原則・カラー体系自体は変更なし。

## 概要

本プロジェクトは「水彩ファンタジースタイル」を採用する。
詳細は `docs/design/atelier-alchemy-core/ui-design/` を参照。

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
# OK
const UiTheme = preload("res://shared/theme/theme.gd")

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

### フェーズ別の個性の出し方

フェーズごとに色を変えたい場合は、**アクセントカラー**のみ使用する:

| フェーズ | アクセント | 使用箇所 |
|---------|----------|---------|
| 依頼受注 | ラベンダー (#B8A9D4) | フェーズタイトル、セクション見出しの左バー |
| 採取 | リーフグリーン (#8CC084) | 同上 |
| 調合 | アンバー (#D4A76A) | 同上 |
| 納品 | コーラル (#E8A87C) | 同上 |

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

---

## 禁止事項

- 色のハードコード（`Color("#333333")` 等を直接書く）
- フェーズ独自のカードスタイル（枠色・背景色・角丸を独自定義）
- 定義されていないボタンバリアントの追加
- ダーク背景の使用（サイドバー・ヘッダー・フッターを含む）
- 青紫（`#6366f1`）などテーマと無関係な色の使用
