class_name AlchemyBackdropPixel
extends TextureRect

## ドット絵の調合台を1枚絵で表示する静的背景。GameState非依存の薄いラッパー。
## title_backdrop.gd（TitleBackdropPixel）と同型の設定はPixelBackdropApplierへ集約済み
## （.claude/rules/ui-components.md参照）

const BACKDROP_TEXTURE: Texture2D = preload("res://assets/ui/alchemy/alchemy_backdrop_pixel.png")


## 🔵 ドット絵テクスチャを画面全体にカバー表示し、投入枠・プレビュー等の前面UIの
## 操作を妨げないようクリックを透過する
func _ready() -> void:
	PixelBackdropApplier.apply(self, BACKDROP_TEXTURE)
