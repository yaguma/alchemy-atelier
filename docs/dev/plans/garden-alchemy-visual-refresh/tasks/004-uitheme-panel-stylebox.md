---
id: "004"
title: "UiThemeにカードパネル用StyleBoxTexture生成関数を追加する"
status: done
priority: 2
dependencies: ["001"]
estimated_complexity: medium
---

> 🔵 2026-09-18追記: 001で本物のドット絵カードパネル（`panel_pixel.png`）に差し替えたことに伴い、`PANEL_TEXTURE_MARGIN`をプレースホルダー実測値14から本番アセット実測値10（実測約8px+安全マージン2px）に更新した。テストは`UiTheme.PANEL_TEXTURE_MARGIN`定数参照のため無修正で全件PASS。

# Task: UiThemeにカードパネル用StyleBoxTexture生成関数を追加する

## Goal

`UiTheme`（`atelier/shared/theme/theme.gd`）に、001で生成した共通カードパネルアセットから9-slice `StyleBoxTexture` を生成する `make_panel_stylebox()` を追加する。既存の `make_button_stylebox()` と同型のキャッシュ方式を踏襲する。

## Interfaces

```gdscript
# atelier/shared/theme/theme.gd への追加
const PANEL_TEXTURE_PIXEL: Texture2D = preload("res://assets/ui/pixel/panel_pixel.png")  # 🔵 001の出力を参照
const PANEL_TEXTURE_MARGIN := 20  # 🔴 暫定値。001のアセット実寸を見て、BUTTON_TEXTURE_MARGINと同じ手順（トリミング＋色解析）で実測補正する

static var _panel_stylebox_cache: StyleBoxTexture = null  # 🟡 バリアントが無いため単一キャッシュ

## 🟡 make_button_stylebox()と同型のStyleBoxTexture 9-slice生成。バリアントが無いため引数なし
static func make_panel_stylebox() -> StyleBoxTexture:
	if _panel_stylebox_cache != null:
		return _panel_stylebox_cache
	var style := StyleBoxTexture.new()
	style.texture = PANEL_TEXTURE_PIXEL
	style.texture_margin_left = PANEL_TEXTURE_MARGIN
	style.texture_margin_top = PANEL_TEXTURE_MARGIN
	style.texture_margin_right = PANEL_TEXTURE_MARGIN
	style.texture_margin_bottom = PANEL_TEXTURE_MARGIN
	style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	style.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	_panel_stylebox_cache = style
	return style
```

> 信号機: 🔵 既存`make_button_stylebox()`のパターンに完全準拠。🟡 バリアント無しの単純化は本Planのヒアリング結果（カードパネル共通1枚）に基づく妥当な設計。🔴 `PANEL_TEXTURE_MARGIN`の具体値は001完了後に実測して補正が必要（`BUTTON_TEXTURE_MARGIN`のコメント参照）

## Test Strategy

- [ ] `make_panel_stylebox()`が`StyleBoxTexture`を返す
- [ ] 返却された`StyleBoxTexture.texture`が`UiTheme.PANEL_TEXTURE_PIXEL`と一致する
- [ ] 2回呼び出した結果が同一インスタンスを返す（キャッシュされている）
- [ ] `texture_margin_left/top/right/bottom`が`PANEL_TEXTURE_MARGIN`と一致する
- [ ] `axis_stretch_horizontal`/`axis_stretch_vertical`が`AXIS_STRETCH_MODE_TILE`になっている

## Implementation Notes

- 参照すべき既存コード: `atelier/shared/theme/theme.gd`の`make_button_stylebox()`（`_button_stylebox_cache`のキャッシュパターン）
- 実装のヒント: `make_button_stylebox()`と異なりバリアント・状態ごとの分岐が無いため、キャッシュは単一の`StyleBoxTexture`インスタンスで足りる
- 注意事項: `PANEL_TEXTURE_MARGIN`は001完了後、実際のPNGを目視・色解析して過不足のない値に補正すること（`BUTTON_TEXTURE_MARGIN`定義部のコメントにある補正手順を参照）

## Files

- 変更: `atelier/shared/theme/theme.gd`
- テスト: `atelier/tests/unit/shared/test_ui_theme.gd`
