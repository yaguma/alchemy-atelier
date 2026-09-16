---
id: "008"
title: "TitleBackdropPixelを実装し title_backdrop.gd/.tscn を置き換える"
status: done
priority: 2
dependencies: ["004"]
estimated_complexity: medium
---

# Task: TitleBackdropPixelを実装し title_backdrop.gd/.tscn を置き換える

## Goal

前Planの`TitleBackdrop`（`GradientTexture2D`3枚＋`_draw()`による丘・草シルエットの自前プロシージャル描画）を、ドット絵1枚絵を表示するだけの薄い`TitleBackdropPixel`に置き換える。

## Interfaces

```gdscript
# features/title/ui/title_backdrop.gd（既存ファイルを全面書き換え）
class_name TitleBackdropPixel
extends TextureRect

## 🔵 ドット絵の朝の庭を1枚絵で表示する静的背景。title_backdrop.gd（水彩版、GradientTexture2D
## 3枚+_draw()の丘・草シルエット自前描画）を置き換える。GameState非依存。setup()を経由しない
## 例外は旧実装と同方針（.claude/rules/ui-components.md参照）

const BACKDROP_TEXTURE: Texture2D = preload("res://assets/ui/title/title_backdrop_pixel.png")


func _ready() -> void:
	texture = BACKDROP_TEXTURE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # 🔵 ドット絵の必須設定
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED  # 🟡 前Planの背景と同じ画面全体カバー方針を踏襲
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE  # 🟡
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # 🔵 旧title_backdrop.gdと同じ、ボタン操作を妨げない
```

シーン構成（`features/title/ui/title_backdrop.tscn`、既存ファイルを全面書き換え）:
```
TitleBackdrop (TextureRect, script=title_backdrop.gd, mouse_filter=MOUSE_FILTER_IGNORE)
```
子ノード（`SkyRect`/`SunGlow`）は不要になるため削除する。**ルートノード名は`"TitleBackdrop"`のまま維持する**（`title_screen.gd`/`test_title_screen.gd`の`find_child("TitleBackdrop", true, false)`系コードとの互換性のため。クラス名`TitleBackdropPixel`とノード名`TitleBackdrop`は独立して問題ない）。

## Test Strategy

`tests/integration/test_title_backdrop.gd`（**既存ファイルの全面書き換え**。前Planの`_draw()`/`resized`シグナル前提のテストはプロシージャル描画の廃止に伴い成立しなくなるため置き換える）:

- [ ] `TitleBackdropScene.instantiate()`したノードを`auto_free()`+`add_child()`してもエラーが出ない
- [ ] `texture == TitleBackdropPixel.BACKDROP_TEXTURE`である
- [ ] `texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST`である
- [ ] `mouse_filter == Control.MOUSE_FILTER_IGNORE`である（背景がクリックを奪わないことの確認、旧テストケースを踏襲）
- [ ] ノード名が`"TitleBackdrop"`である（`find_child()`互換性の確認）

## Implementation Notes

- 参照すべき既存コード: `atelier/features/title/ui/title_backdrop.gd`/`.tscn`（前Plan成果物、置き換え対象として現状を確認してから着手する）
- 実装のヒント: `TextureRect`単体で完結するため、`SkyRect`/`SunGlow`ノード・`_draw()`・`GRASS_BLADE_COUNT`等の関連定数は全て削除してよい
- 注意事項: `title_screen.gd`側の`find_child("TitleBackdrop", true, false)`系の既存テスト・実装コードには影響を与えないよう、ノード名は変更しないこと

## Files

- 変更: `atelier/features/title/ui/title_backdrop.gd`（全面書き換え）
- 変更: `atelier/features/title/ui/title_backdrop.tscn`（全面書き換え）
- テスト: `atelier/tests/integration/test_title_backdrop.gd`（既存ファイルを書き換え）
