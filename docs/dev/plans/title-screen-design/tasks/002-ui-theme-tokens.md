---
id: "002"
title: "UiThemeに色トークンとボタン/カードStyleBoxファクトリ関数を追加する"
status: done
priority: 1
dependencies: ["001"]
estimated_complexity: medium
---

# Task: UiThemeに色トークンとボタン/カードStyleBoxファクトリ関数を追加する

## Goal

`shared/theme/theme.gd`（`UiTheme`）に、カード/ボタン4種用の暫定カラートークンと、`UiPanelStyleBox`を生成する`static func`群を追加する。本Planのスコープはタイトル画面のため、ゲージ/モーダル用ファクトリは追加しない（YAGNI。庭・調合画面向けPlan再着手時に別途追加）。

## Interfaces

```gdscript
# shared/theme/theme.gd（既存クラスへの追加分。既存の COLOR_SLOT_*, COLOR_HUD_* 等は変更・削除しない）
class_name UiTheme

enum ButtonVariant { PRIMARY, SECONDARY, DANGER, TERTIARY }   # 🔵 design-guide.mdのボタン4種の意味論と一致
enum ButtonState { NORMAL, HOVER, PRESSED, DISABLED }          # 🔵 Godot Buttonの標準StyleBoxスロット名に対応

# --- カード/パネル ---
const RADIUS_CARD: int = 10                                    # 🟡 暫定値（design-guide.md未確定）
const BORDER_WIDTH_CARD: int = 2                                # 🟡
const COLOR_CARD_BORDER: Color = Color("#C7A669")               # 🟡 琥珀色、暫定
const COLOR_CARD_GRADIENT_TOP: Color = Color("#FFFCF5")         # 🟡
const COLOR_CARD_GRADIENT_BOTTOM: Color = Color("#F0E2C3")      # 🟡

# --- ボタン4種（各 top/bottom/border の3色1セット） ---
const COLOR_BUTTON_PRIMARY_TOP: Color = Color("#93CC85")        # 🟡
const COLOR_BUTTON_PRIMARY_BOTTOM: Color = Color("#5E9C57")     # 🟡
const COLOR_BUTTON_PRIMARY_BORDER: Color = Color("#4C7C3F")     # 🟡
const COLOR_BUTTON_SECONDARY_TOP: Color = Color("#FFFCF5")      # 🟡
const COLOR_BUTTON_SECONDARY_BOTTOM: Color = Color("#F0E2C3")   # 🟡
const COLOR_BUTTON_SECONDARY_BORDER: Color = Color("#8A7048")   # 🟡
const COLOR_BUTTON_DANGER_TOP: Color = Color("#E39C90")         # 🟡
const COLOR_BUTTON_DANGER_BOTTOM: Color = Color("#C25E4C")      # 🟡
const COLOR_BUTTON_DANGER_BORDER: Color = Color("#9A3F30")      # 🟡
const COLOR_BUTTON_TERTIARY_TOP: Color = Color("#FFFCF5")       # 🟡
const COLOR_BUTTON_TERTIARY_BOTTOM: Color = Color("#F1E4C7")    # 🟡
const COLOR_BUTTON_TERTIARY_BORDER: Color = Color("#C7A669")    # 🟡

static func make_card_stylebox() -> StyleBox: ...                                   # 🟡
static func make_button_stylebox(variant: ButtonVariant, state: ButtonState) -> StyleBox: ...  # 🟡
```

`ButtonState`ごとの見た目差分（🔴 具体値はAI裁量で決定、`screen-design-update`タスク002の設計を踏襲）:
- `HOVER`: `NORMAL`よりわずかに明るいtop/bottom色
- `PRESSED`: `NORMAL`よりわずかに暗く、`outer_shadow_size`を0にして「押し込まれた」感を出す
- `DISABLED`: `NORMAL`と同じStyleBoxを返す（透明度制御は呼び出し側の`Control.modulate`に委ねる）

## Test Strategy

`tests/unit/shared/test_ui_theme.gd`（新規。事前に`Grep`で同名ファイルが無いことを確認すること）:

- [ ] `make_card_stylebox()`が`UiPanelStyleBox`のインスタンスを返し、`corner_radius == UiTheme.RADIUS_CARD`である
- [ ] `make_button_stylebox(ButtonVariant.PRIMARY, ButtonState.NORMAL)`の`gradient_top_color`が`COLOR_BUTTON_PRIMARY_TOP`と一致する
- [ ] `make_button_stylebox(ButtonVariant.DANGER, ButtonState.NORMAL)`の`border_color`が`COLOR_BUTTON_DANGER_BORDER`と一致する
- [ ] `make_button_stylebox(ButtonVariant.SECONDARY, ButtonState.PRESSED)`の`outer_shadow_size`が0になる
- [ ] 4種類の`ButtonVariant`すべてで`make_button_stylebox()`が`null`を返さない

## Implementation Notes

- 参照すべき既存コード: `atelier/shared/theme/theme.gd`（既存の定数定義パターン・命名規則を踏襲。既存定数を削除・変更しないこと）
- 実装のヒント: `Color("#RRGGBB")`形式のリテラルはGodotの`Color`コンストラクタでそのまま使える。各`make_*_stylebox()`は`UiPanelStyleBox.new()`してプロパティを設定し返すだけのシンプルな関数
- 注意事項: 既存の`COLOR_SLOT_*`・`COLOR_HUD_*`・`COLOR_ALCHEMY_*`等（`self_modulate`用に使われている既存トークン）は変更・削除しない。本タスクは追加のみ

## Files

- 変更: `atelier/shared/theme/theme.gd`
- テスト: `atelier/tests/unit/shared/test_ui_theme.gd`
