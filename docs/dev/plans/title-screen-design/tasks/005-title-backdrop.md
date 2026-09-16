---
id: "005"
title: "タイトル画面の背景コンポーネント（TitleBackdrop）を実装する"
status: done
priority: 2
dependencies: []
estimated_complexity: high
---

# Task: タイトル画面の背景コンポーネント（TitleBackdrop）を実装する

## Goal

朝の庭のイメージ（暖色系の空のグラデーション・朝日/六芒星のグロー・なだらかな丘と背の高い草の額縁シルエット）を表現する、`GameState`非依存の静的背景コンポーネントを実装する。NanoBanana生成画像（`nanobanana/Gemini_Generated_Image_Atelier_タイトル.jpg`）は配色・構図の参考のみとし、実データとしては取り込まない。

## Interfaces

```gdscript
# features/title/ui/title_backdrop.gd
class_name TitleBackdrop
extends Control

func _ready() -> void: ...      # 🟡 resizedシグナルに queue_redraw() を接続。setup()は不要（静的装飾のため .claude/rules/ui-components.md の setup() 原則の明示的な例外）
func _draw() -> void: ...       # 🔴 丘・草の額縁のシルエットをサイズ相対座標で自前描画
```

シーン構成（`features/title/ui/title_backdrop.tscn`、🔴 具体的なノード配置・パラメータはAI裁量）:
```
TitleBackdrop (Control, script=title_backdrop.gd, mouse_filter=MOUSE_FILTER_IGNORE)
├── SkyRect (TextureRect, texture=GradientTexture2D[暖色系空色2〜3色, fill=LINEAR], anchors_preset=15)
└── SunGlow (TextureRect, texture=GradientTexture2D[金色系, fill=RADIAL], material=CanvasItemMaterial[blend_mode=BLEND_MODE_ADD])
```
丘・両端の草の額縁シルエットは`TitleBackdrop._draw()`内で直接描画する（別ノードにしない、`GardenBackdrop`の設計方針を踏襲）。

## Test Strategy

`tests/integration/test_title_backdrop.gd`（新規、GdUnit4シーンテスト）:

- [ ] `TitleBackdropScene.instantiate()`したノードを`auto_free()`+`add_child()`してもエラーが出ない
- [ ] `mouse_filter`が`MOUSE_FILTER_IGNORE`に設定されている（背景がクリックを奪わないことの確認）
- [ ] ノードのサイズを変更（`size = Vector2(800, 600)`）した後に`resized`シグナル経由で再描画がトリガーされる
- [ ] 極端に小さいサイズ（`Vector2(1, 1)`）でもクラッシュしない（境界値）

## Implementation Notes

- 参照すべき既存コード: `atelier/features/title/ui/title_screen.tscn`（配置先の親シーン）。`GardenBackdrop`が存在すればそのパターンを踏襲するが、`docs/dev/plans/screen-design-update/`は未実装のため実コードとしては参照できない点に注意（タスクファイルの設計のみ参照可能）
- 実装のヒント: `GradientTexture2D`は`.tres`リソースとして`atelier/shared/theme/gradients/`配下に切り出すか、`_ready()`内で動的生成するかは実装時に判断してよい（🔴）
- 注意事項: `.claude/rules/design-guide.md`の「ダーク背景禁止」「青紫系禁止」を厳守すること

## Files

- 新規: `atelier/features/title/ui/title_backdrop.gd`
- 新規: `atelier/features/title/ui/title_backdrop.tscn`
- 新規（任意）: `atelier/shared/theme/gradients/title_sky.tres`, `atelier/shared/theme/gradients/title_sun_glow.tres`
- テスト: `atelier/tests/integration/test_title_backdrop.gd`
