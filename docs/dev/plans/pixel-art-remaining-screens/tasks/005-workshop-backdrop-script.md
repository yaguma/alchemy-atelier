---
id: "005"
title: "工房強化・ショップ画面用のWorkshopBackdropPixelを実装する"
status: done
priority: 2
dependencies: ["002"]
estimated_complexity: low
---

# Task: 工房強化・ショップ画面用のWorkshopBackdropPixelを実装する

## Goal

`GardenBackdropPixel`と同型の`TextureRect`継承クラス`WorkshopBackdropPixel`を実装し、002で生成した背景アセットを`PixelBackdropApplier`経由でNEARESTフィルタ表示する。

## Interfaces

```gdscript
# atelier/features/workshop/ui/workshop_backdrop.gd
class_name WorkshopBackdropPixel
extends TextureRect

const BACKDROP_TEXTURE: Texture2D = preload("res://assets/ui/workshop/workshop_backdrop_pixel.png")

func _ready() -> void:
	PixelBackdropApplier.apply(self, BACKDROP_TEXTURE)
```

> 信号機: 🔵 既存`GardenBackdropPixel`の実装パターンに完全準拠

## Test Strategy

- [ ] `WorkshopBackdropPixel`をインスタンス化して`_ready()`後、`texture`が`preload("res://assets/ui/workshop/workshop_backdrop_pixel.png")`と一致する
- [ ] `texture_filter`が`CanvasItem.TEXTURE_FILTER_NEAREST`になっている
- [ ] `stretch_mode`が`TextureRect.STRETCH_KEEP_ASPECT_COVERED`になっている
- [ ] `mouse_filter`が`Control.MOUSE_FILTER_IGNORE`になっている

## Implementation Notes

- 参照すべき既存コード: `atelier/features/garden/ui/garden_backdrop.gd`/`.tscn`
- 実装のヒント: 004（guild）と同一パターンで複製する
- 注意事項: `WorkshopScreen`には`%OverlayLayer`（購入確認ダイアログ用の半透明Control）が既存であるため、背景は`OverlayLayer`より確実に背面（ツリー順で先頭）に置く

## Files

- 新規: `atelier/features/workshop/ui/workshop_backdrop.gd`
- 新規: `atelier/features/workshop/ui/workshop_backdrop.tscn`
- テスト: `atelier/tests/integration/test_workshop_backdrop.gd`
