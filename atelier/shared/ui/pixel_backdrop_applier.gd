class_name PixelBackdropApplier

## 🔴 コードレビュー指摘対応: TitleBackdropPixel/GardenBackdropPixel/AlchemyBackdropPixelの
## _ready()が「テクスチャを設定し、NEARESTフィルタ・KEEP_ASPECT_COVERED・クリック透過を適用する」
## という同一の手順をほぼ逐語的に重複させていたため、単一の適用関数へ集約する
## （変更時に3ファイルへコピーする必要をなくす）。


## ドット絵背景1枚絵を`rect`に設定し、全画面カバー表示・クリック透過の共通設定を適用する
static func apply(rect: TextureRect, texture: Texture2D) -> void:
	rect.texture = texture
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
