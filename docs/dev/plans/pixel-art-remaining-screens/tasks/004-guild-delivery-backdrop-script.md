---
id: "004"
title: "ギルド納品結果画面用のGuildDeliveryBackdropPixelを実装する"
status: done
priority: 2
dependencies: ["001"]
estimated_complexity: low
---

# Task: ギルド納品結果画面用のGuildDeliveryBackdropPixelを実装する

## Goal

`GardenBackdropPixel`/`AlchemyBackdropPixel`と同型の`TextureRect`継承クラス`GuildDeliveryBackdropPixel`を実装し、001で生成した背景アセットを`PixelBackdropApplier`経由でNEARESTフィルタ表示する。

## Interfaces

```gdscript
# atelier/features/guild/ui/guild_delivery_backdrop.gd
class_name GuildDeliveryBackdropPixel
extends TextureRect

const BACKDROP_TEXTURE: Texture2D = preload("res://assets/ui/guild/guild_delivery_backdrop_pixel.png")

func _ready() -> void:
	PixelBackdropApplier.apply(self, BACKDROP_TEXTURE)
```

> 信号機: 🔵 既存`GardenBackdropPixel`（`atelier/features/garden/ui/garden_backdrop.gd`）の実装パターンに完全準拠（`PixelBackdropApplier`集約済み、GameState非依存の薄いラッパー）

## Test Strategy

- [ ] `GuildDeliveryBackdropPixel`をインスタンス化して`_ready()`後、`texture`が`preload("res://assets/ui/guild/guild_delivery_backdrop_pixel.png")`と一致する
- [ ] `texture_filter`が`CanvasItem.TEXTURE_FILTER_NEAREST`になっている
- [ ] `stretch_mode`が`TextureRect.STRETCH_KEEP_ASPECT_COVERED`になっている
- [ ] `mouse_filter`が`Control.MOUSE_FILTER_IGNORE`になっている（背景がクリックを奪わない）

## Implementation Notes

- 参照すべき既存コード: `atelier/features/garden/ui/garden_backdrop.gd`/`.tscn`（実装をそのまま複製し、テクスチャパスのみ変更）、`atelier/shared/ui/pixel_backdrop_applier.gd`（共通適用処理）
- 実装のヒント: `.tscn`は`GardenBackdrop`（`garden_backdrop.tscn`）のノード構成（`anchors_preset=15`でフル画面、`mouse_filter=2`）をそのまま複製する
- 注意事項: `class_name`の命名衝突がないことを確認する（`GuildDeliveryBackdropPixel`はプロジェクト内で未使用のはず）

## Files

- 新規: `atelier/features/guild/ui/guild_delivery_backdrop.gd`
- 新規: `atelier/features/guild/ui/guild_delivery_backdrop.tscn`
- テスト: `atelier/tests/integration/test_guild_delivery_backdrop.gd`
