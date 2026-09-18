---
id: "005"
title: "庭画面用のGardenBackdropPixelを実装する"
status: done
priority: 2
dependencies: ["002"]
estimated_complexity: low
---

# Task: 庭画面用のGardenBackdropPixelを実装する

## Goal

`TitleBackdropPixel`と同型の`TextureRect`継承クラス`GardenBackdropPixel`を実装し、002で生成した背景アセットをNEARESTフィルタで表示する。

## Interfaces

```gdscript
# atelier/features/garden/ui/garden_backdrop.gd
class_name GardenBackdropPixel
extends TextureRect

# 🔵 TitleBackdropPixel（atelier/features/title/ui/title_backdrop.gd）と同型の実装
```

> 信号機: 🔵 既存`TitleBackdropPixel`の実装パターンに完全準拠（GameState非依存の薄いラッパー）

## Test Strategy

- [ ] `GardenBackdropPixel`をインスタンス化して`_ready()`後、`texture`が`preload("res://assets/ui/garden/garden_backdrop_pixel.png")`と一致する
- [ ] `texture_filter`が`CanvasItem.TEXTURE_FILTER_NEAREST`になっている
- [ ] `stretch_mode`が`TextureRect.STRETCH_KEEP_ASPECT_COVERED`になっている
- [ ] `mouse_filter`が`Control.MOUSE_FILTER_IGNORE`になっている（背景がクリックを奪わない）

## Implementation Notes

- 参照すべき既存コード: `atelier/features/title/ui/title_backdrop.gd`（実装をそのまま複製し、テクスチャパスのみ変更）
- 実装のヒント: `atelier/features/title/ui/title_backdrop.tscn`相当の`.tscn`も同様に複製する
- 注意事項: `EXPAND_IGNORE_SIZE`をレイアウトフラグに設定し、親コンテナのサイズ制約を受けずフル画面表示できるようにする（`TitleBackdropPixel`と同様）

## Files

- 新規: `atelier/features/garden/ui/garden_backdrop.gd`
- 新規: `atelier/features/garden/ui/garden_backdrop.tscn`
- テスト: `atelier/tests/integration/test_garden_backdrop.gd`
