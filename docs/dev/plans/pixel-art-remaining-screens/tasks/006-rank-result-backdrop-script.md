---
id: "006"
title: "結果画面用のRankResultBackdropPixelを実装する"
status: done
priority: 2
dependencies: ["003"]
estimated_complexity: low
---

# Task: 結果画面用のRankResultBackdropPixelを実装する

## Goal

`GardenBackdropPixel`と同型の`TextureRect`継承クラス`RankResultBackdropPixel`を実装し、003で生成した背景アセットを`PixelBackdropApplier`経由でNEARESTフィルタ表示する。

## Interfaces

```gdscript
# atelier/features/rank/ui/rank_result_backdrop.gd
class_name RankResultBackdropPixel
extends TextureRect

const BACKDROP_TEXTURE: Texture2D = preload("res://assets/ui/rank/rank_result_backdrop_pixel.png")

func _ready() -> void:
	PixelBackdropApplier.apply(self, BACKDROP_TEXTURE)
```

> 信号機: 🔵 既存`GardenBackdropPixel`の実装パターンに完全準拠

## Test Strategy

- [ ] `RankResultBackdropPixel`をインスタンス化して`_ready()`後、`texture`が`preload("res://assets/ui/rank/rank_result_backdrop_pixel.png")`と一致する
- [ ] `texture_filter`が`CanvasItem.TEXTURE_FILTER_NEAREST`になっている
- [ ] `stretch_mode`が`TextureRect.STRETCH_KEEP_ASPECT_COVERED`になっている
- [ ] `mouse_filter`が`Control.MOUSE_FILTER_IGNORE`になっている

## Implementation Notes

- 参照すべき既存コード: `atelier/features/garden/ui/garden_backdrop.gd`/`.tscn`
- 実装のヒント: 004（guild）・005（workshop）と同一パターンで複製する
- 注意事項: `ResultScreen`はクラス名`ResultScreen`（`class_name ResultScreen`）と衝突しないよう、本タスクの新クラスは`RankResultBackdropPixel`のまま`ResultBackdropPixel`等に短縮しない

## Files

- 新規: `atelier/features/rank/ui/rank_result_backdrop.gd`
- 新規: `atelier/features/rank/ui/rank_result_backdrop.tscn`
- テスト: `atelier/tests/integration/test_rank_result_backdrop.gd`
