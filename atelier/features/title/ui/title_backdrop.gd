class_name TitleBackdropPixel
extends TextureRect

## ドット絵の朝の庭を1枚絵で表示する静的背景。title_backdrop.gd（水彩版、GradientTexture2D
## 3枚+_draw()の丘・草シルエット自前描画）を置き換える。GameState非依存。setup()を経由しない
## 例外は旧実装と同方針（.claude/rules/ui-components.md参照）

const BACKDROP_TEXTURE: Texture2D = preload("res://assets/ui/title/title_backdrop_pixel.png")


## 🔵 ドット絵テクスチャを画面全体にカバー表示し、ボタン操作を妨げないようクリックを透過する
func _ready() -> void:
	texture = BACKDROP_TEXTURE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
