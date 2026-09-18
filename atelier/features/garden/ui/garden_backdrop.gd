class_name GardenBackdropPixel
extends TextureRect

## ドット絵の庭を1枚絵で表示する静的背景。GameState非依存の薄いラッパー。
## title_backdrop.gd（TitleBackdropPixel）と完全に同型の実装（.claude/rules/ui-components.md参照）

const BACKDROP_TEXTURE: Texture2D = preload("res://assets/ui/garden/garden_backdrop_pixel.png")


## 🔵 ドット絵テクスチャを画面全体にカバー表示し、操作を妨げないようクリックを透過する
func _ready() -> void:
	texture = BACKDROP_TEXTURE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
