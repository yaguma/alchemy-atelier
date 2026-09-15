---
id: "006"
title: "UiTheme.make_button_stylebox()をドット絵テクスチャ方式に置き換える"
status: done
priority: 2
dependencies: ["002", "003"]
estimated_complexity: high
---

# Task: UiTheme.make_button_stylebox()をドット絵テクスチャ方式に置き換える

## Goal

`atelier/shared/theme/theme.gd`の`make_button_stylebox()`を、前Planの`UiPanelStyleBox`（手続きグラデーション描画）方式から`StyleBoxTexture`（ドット絵アセット9-slice）方式に**上書き置き換え**する。あわせてDISABLED状態を実際に半透明化する（旧実装は`Control.modulate`に委ねる想定だったが呼び出し元が未設定で実質機能していなかったため是正する）。

> 🔵 `make_button_stylebox()`の現状の呼び出し元は`ButtonStyleApplier.apply_button_style()`のみで、他画面からの参照はない（grep確認済み）。上書き置き換えで問題ない（YAGNI、別関数への分離はしない）。

## Interfaces

```gdscript
# shared/theme/theme.gd（既存への変更・追加）
class_name UiTheme

# --- 既存のenum・COLOR_BUTTON_*・BUTTON_HOVER_LIGHTEN_AMOUNT・BUTTON_PRESSED_DARKEN_AMOUNTは
#     プロンプトの配色情報源として維持する（削除しない）。_BUTTON_VARIANT_COLORSも維持可 ---

# 🟡 タスク003で生成したドット絵ボタンテクスチャへの参照
const BUTTON_TEXTURE_PRIMARY: Texture2D = preload("res://assets/ui/pixel/button_primary.png")
const BUTTON_TEXTURE_SECONDARY: Texture2D = preload("res://assets/ui/pixel/button_secondary.png")
const BUTTON_TEXTURE_DANGER: Texture2D = preload("res://assets/ui/pixel/button_danger.png")
const BUTTON_TEXTURE_TERTIARY: Texture2D = preload("res://assets/ui/pixel/button_tertiary.png")

# 🔴 9-slice用マージン(px)。タスク003で実際に生成されたPNGの寸法に合わせて調整すること
const BUTTON_TEXTURE_MARGIN := 6

# 🔵 DISABLED状態の透明度。旧実装の「呼び出し側modulateに委ねる」を是正し、実際に機能させる
const BUTTON_DISABLED_ALPHA := 0.5

const _BUTTON_VARIANT_TEXTURES := {
	ButtonVariant.PRIMARY: BUTTON_TEXTURE_PRIMARY,
	ButtonVariant.SECONDARY: BUTTON_TEXTURE_SECONDARY,
	ButtonVariant.DANGER: BUTTON_TEXTURE_DANGER,
	ButtonVariant.TERTIARY: BUTTON_TEXTURE_TERTIARY,
}


## 🔵 戻り値型はStyleBox（StyleBoxTextureはそのサブクラス）のため、呼び出し側
## ButtonStyleApplier.apply_button_style()のシグネチャは変更不要
static func make_button_stylebox(variant: ButtonVariant, state: ButtonState) -> StyleBoxTexture:
	# 🟡 ドット絵のにじみ防止のため伸縮でなくタイル（反復）で拡縮する
	# 🟡 HOVER/PRESSED/DISABLEDはmodulate_colorで表現し、NORMALはColor.WHITE（無着色）
	...
```

## Test Strategy

`tests/unit/shared/test_ui_theme.gd`（**既存ファイルの全面書き換え**。前Planの`UiPanelStyleBox`前提のassert（`gradient_top_color`, `corner_radius`等）はドット絵実装と矛盾するため置き換える）:

- [ ] `make_button_stylebox(ButtonVariant.PRIMARY, ButtonState.NORMAL)`が`StyleBoxTexture`のインスタンスを返し、`texture == UiTheme.BUTTON_TEXTURE_PRIMARY`である
- [ ] `make_button_stylebox(ButtonVariant.DANGER, ButtonState.NORMAL)`の`texture == UiTheme.BUTTON_TEXTURE_DANGER`である
- [ ] `make_button_stylebox(variant, ButtonState.HOVER)`の`modulate_color`が`NORMAL`時より明るい（例: 各チャンネル値が大きい、またはHSVのVが大きい）
- [ ] `make_button_stylebox(variant, ButtonState.PRESSED)`の`modulate_color`が`NORMAL`時より暗い
- [ ] `make_button_stylebox(variant, ButtonState.DISABLED)`の`modulate_color.a == UiTheme.BUTTON_DISABLED_ALPHA`である（実際に半透明化されることの確認）
- [ ] 4種類の`ButtonVariant`すべてで`make_button_stylebox()`が`null`を返さない
- [ ] `make_card_stylebox()`は変更していないため、既存の`UiPanelStyleBox`関連assert（`corner_radius == UiTheme.RADIUS_CARD`等）は維持する

## Implementation Notes

- 参照すべき既存コード: `atelier/shared/theme/theme.gd`（現状の`make_button_stylebox()`実装、`_BUTTON_VARIANT_COLORS`テーブル構造を踏襲してテクスチャ版`_BUTTON_VARIANT_TEXTURES`を作る）
- 実装のヒント:
  - `StyleBoxTexture.axis_stretch_horizontal` / `axis_stretch_vertical`を`StyleBoxTexture.AXIS_STRETCH_MODE_TILE`に設定し、ドット絵のにじみを防ぐ
  - `texture_margin_left/top/right/bottom`に`BUTTON_TEXTURE_MARGIN`を設定して9-slice化する
  - HOVER/PRESSED/DISABLEDは`modulate_color`（`Color.WHITE.lightened()`/`darkened()`、DISABLEDは`Color(1,1,1,BUTTON_DISABLED_ALPHA)`）で表現する
- 注意事項:
  - `preload()`はパース時にファイル実在が必須。タスク002（フォント）・003（ボタンテクスチャ）が先に完了していることを前提とする（本タスクの`dependencies`に含まれる理由）
  - `make_card_stylebox()`・`UiPanelStyleBox`・既存の`COLOR_SLOT_*`等の他画面向け定数は変更・削除しないこと

## Files

- 変更: `atelier/shared/theme/theme.gd`
- テスト: `atelier/tests/unit/shared/test_ui_theme.gd`（既存ファイルを書き換え）
