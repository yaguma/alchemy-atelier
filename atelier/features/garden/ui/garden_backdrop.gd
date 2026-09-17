class_name GardenBackdropPixel
extends TextureRect

## ドット絵の庭を1枚絵で表示する静的背景。GameState非依存の薄いラッパー。
## title_backdrop.gd（TitleBackdropPixel）と同型の設定はPixelBackdropApplierへ集約済み
## （.claude/rules/ui-components.md参照）

const BACKDROP_TEXTURE: Texture2D = preload("res://assets/ui/garden/garden_backdrop_pixel.png")


## 🔵 ドット絵テクスチャを画面全体にカバー表示し、操作を妨げないようクリックを透過する
func _ready() -> void:
	PixelBackdropApplier.apply(self, BACKDROP_TEXTURE)
