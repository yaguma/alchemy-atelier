---
id: "006"
title: "調合画面用のAlchemyBackdropPixelを実装する"
status: done
priority: 2
dependencies: ["003"]
estimated_complexity: low
---

# Task: 調合画面用のAlchemyBackdropPixelを実装する

## Goal

`TitleBackdropPixel`と同型の`TextureRect`継承クラス`AlchemyBackdropPixel`を実装し、003で生成した背景アセットをNEARESTフィルタで表示する。

## Interfaces

```gdscript
# atelier/features/alchemy/ui/alchemy_backdrop.gd
class_name AlchemyBackdropPixel
extends TextureRect

# 🔵 TitleBackdropPixel（atelier/features/title/ui/title_backdrop.gd）と同型の実装
```

> 信号機: 🔵 既存`TitleBackdropPixel`の実装パターンに完全準拠

## Test Strategy

- [ ] `AlchemyBackdropPixel`をインスタンス化して`_ready()`後、`texture`が`preload("res://assets/ui/alchemy/alchemy_backdrop_pixel.png")`と一致する
- [ ] `texture_filter`が`CanvasItem.TEXTURE_FILTER_NEAREST`になっている
- [ ] `stretch_mode`が`TextureRect.STRETCH_KEEP_ASPECT_COVERED`になっている
- [ ] `mouse_filter`が`Control.MOUSE_FILTER_IGNORE`になっている

## Implementation Notes

- 参照すべき既存コード: `atelier/features/title/ui/title_backdrop.gd`（実装をそのまま複製し、テクスチャパスのみ変更）
- 実装のヒント: `005-garden-backdrop-script.md`と対になる実装。差分はテクスチャパスとクラス名のみ
- 注意事項: 調合投入枠・プレビューパネル等の前面UIが背景の上に正しく重なるZ順序を確認する

## Files

- 新規: `atelier/features/alchemy/ui/alchemy_backdrop.gd`
- 新規: `atelier/features/alchemy/ui/alchemy_backdrop.tscn`
- テスト: `atelier/tests/integration/test_alchemy_backdrop.gd`
