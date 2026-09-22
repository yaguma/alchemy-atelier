class_name UiTheme

## 🔵 design-guide.mdのボタン4種（プライマリ/セカンダリ/デンジャー/ターシャリ）の意味論と一致させる
enum ButtonVariant { PRIMARY, SECONDARY, DANGER, TERTIARY }
## 🔵 Godot Buttonの標準StyleBoxスロット名（normal/hover/pressed/disabled）に対応させる
enum ButtonState { NORMAL, HOVER, PRESSED, DISABLED }

const FONT_MAIN: FontFile = preload("res://assets/fonts/noto_sans_jp_regular.ttf")
## 🔵 ドット絵風日本語フォント（DotGothic16）。タイトル画面等の個別ノードから
## add_theme_font_override()で使う想定で、main_theme.tresのdefault_fontは変更しない
const FONT_PIXEL_JP: FontFile = preload("res://assets/fonts/dotgothic16_regular.ttf")

const FONT_SIZE_DEFAULT := 16

# 🟡 リスト系コンポーネント（UpgradeItemList等）のエントリ間スペーシング。コードレビュー指摘対応で
# 新規追加。既存のSeedInventoryList.ENTRY_SEPARATIONはローカル定数のまま残っているが、
# 本定数の追加を機に新規コンポーネントから統一的に参照できるようにする
const SPACING_LIST_ENTRY := 8

# 🔴 庭スロット4状態の表示色。ui-design/overview.mdでは色コード自体が未確定（🔴専用ビジュアルデザインパス待ち）のため、
# PlantSlotView実装のために暫定値を新規決定した。庭フェーズのアクセントカラー（リーフグリーン）を生育中に流用し、
# 他3状態は色だけでなくアイコン・テキストでも判別可能なNFR-201を踏まえた補助的な位置づけとする。
const COLOR_SLOT_EMPTY := Color("#B0AFA8")
const COLOR_SLOT_GROWING := Color("#8CC084")
const COLOR_SLOT_HARVESTABLE := Color("#D4A76A")
const COLOR_SLOT_WITHER_WARNING := Color("#E06C6C")
# 🔴 コードレビュー指摘対応で新規追加（DATA_ERROR状態）。他4色と混同しない紫系の警告色
const COLOR_SLOT_DATA_ERROR := Color("#9B7FC7")

# 🟡 調合投入枠2状態の表示色。ui-design/overview.mdで色コードが未確定（🔴専用ビジュアルデザインパス待ち）のため、
# 庭のCOLOR_SLOT_*と同様に暫定値を新規決定した。空きは庭と同じグレーで揃え、投入済みは
# 調合フェーズのアクセント（アンバー）とは別系統の寒色にして「素材が入っている」ことを示す。
const COLOR_ALCHEMY_SLOT_EMPTY := Color("#B0AFA8")
const COLOR_ALCHEMY_SLOT_FILLED := Color("#7FA8C9")

# 🔴 全画面共通ヘッダー（RankHud）の表示色。ui-design/overview.mdでは色コード自体が未確定
# （🔴専用ビジュアルデザインパス待ち）のため暫定値を新規決定した。テキストはdesign-guide.mdの
# 「温もり」方針に沿う濃いブラウングレー、ノルマバーはギルド納品のアクセント（コーラル）系を
# 流用してランクノルマとギルド決算の関連を色でも示す。
const COLOR_HUD_TEXT := Color("#4A4438")
const COLOR_HUD_QUOTA_BAR := Color("#E8A87C")

# 🟡 調合プレビューの「指定合致」強調色。ui-design/overview.mdで色コードが未確定のため暫定値。
# ギルド納品フェーズのアクセント（コーラル）系を流用し、指定依頼との関連を色でも示す。
# NFR-201に従い、色は補助であり判別自体は専用テキストの表示/非表示で行う
const COLOR_ALCHEMY_PREVIEW_ORDER_MATCHED := Color("#E8A87C")

# 🔴 タイトル画面背景（TitleBackdrop）の色。design-guide.mdのフェーズアクセント表に該当エントリが
# ないため新規決定。朝の庭の逆光をイメージし、空は上から暖色クリーム→アプリコット→コーラルの
# 3階調、朝日グローは金色、丘と草の額縁はリーフグリーン系を暗く落として奥→手前で階調をつける
const COLOR_TITLE_SKY_TOP := Color("#FFF3D6")
const COLOR_TITLE_SKY_MID := Color("#F6BE8A")
const COLOR_TITLE_SKY_BOTTOM := Color("#F2A679")
const COLOR_TITLE_SUN_GLOW := Color("#FFE9A8")
const COLOR_TITLE_HILL_BACK := Color("#9CAE74")
const COLOR_TITLE_HILL_FRONT := Color("#748A54")
const COLOR_TITLE_GRASS_FRAME := Color("#56693F")

# 🟡 ボタン4種（プライマリ/セカンダリ/デンジャー/ターシャリ）のNORMAL状態カラー。
# design-guide.mdのバリアント意味論に沿い、各top/bottom/borderの3色1セットで暫定値を定義する
const COLOR_BUTTON_PRIMARY_TOP := Color("#93CC85")
const COLOR_BUTTON_PRIMARY_BOTTOM := Color("#5E9C57")
const COLOR_BUTTON_PRIMARY_BORDER := Color("#4C7C3F")
const COLOR_BUTTON_SECONDARY_TOP := Color("#FFFCF5")
const COLOR_BUTTON_SECONDARY_BOTTOM := Color("#F0E2C3")
const COLOR_BUTTON_SECONDARY_BORDER := Color("#8A7048")
const COLOR_BUTTON_DANGER_TOP := Color("#E39C90")
const COLOR_BUTTON_DANGER_BOTTOM := Color("#C25E4C")
const COLOR_BUTTON_DANGER_BORDER := Color("#9A3F30")
const COLOR_BUTTON_TERTIARY_TOP := Color("#FFFCF5")
const COLOR_BUTTON_TERTIARY_BOTTOM := Color("#F1E4C7")
const COLOR_BUTTON_TERTIARY_BORDER := Color("#C7A669")

# 🟡 HOVER/PRESSED状態での明暗変化量。screen-design-updateタスク002の設計を踏襲した暫定値
const BUTTON_HOVER_LIGHTEN_AMOUNT := 0.08
const BUTTON_PRESSED_DARKEN_AMOUNT := 0.08

# 🔴 2026-09-16追加: ボタンラベルのフォントサイズ。既定の16pxはドット絵ボタン
# （高さ64px程度）に対して小さすぎたため、実機確認の指摘を受けて拡大した
const BUTTON_FONT_SIZE := 28

# 🔵 design-guide.mdのボタン表（プライマリ=白文字、セカンダリ=text.primary、
# デンジャー=白文字、ターシャリ=text.muted）に対応する文字色。セカンダリ/ターシャリは
# 明るいクリーム系の塗りのため白文字だと視認できず、実機確認で発覚し追加した
const COLOR_BUTTON_TEXT_ON_LIGHT := Color("#4A4438")  # 🔵 COLOR_HUD_TEXTと同じ値を再利用
# 🟡 COLOR_BUTTON_SECONDARY_BORDERと同じ値を再利用、ターシャリの「控えめ」さを文字色でも表現
const COLOR_BUTTON_TEXT_ON_LIGHT_MUTED := Color("#8A7048")

const _BUTTON_VARIANT_TEXT_COLORS := {
	ButtonVariant.PRIMARY: Color.WHITE,
	ButtonVariant.SECONDARY: COLOR_BUTTON_TEXT_ON_LIGHT,
	ButtonVariant.DANGER: Color.WHITE,
	ButtonVariant.TERTIARY: COLOR_BUTTON_TEXT_ON_LIGHT_MUTED,
}

# 🔵 ドット絵ボタンテクスチャ（9-slice、StyleBoxTexture方式）。design-guide.mdのバリアント意味論に対応
const BUTTON_TEXTURE_PRIMARY: Texture2D = preload("res://assets/ui/pixel/button_primary.png")
const BUTTON_TEXTURE_SECONDARY: Texture2D = preload("res://assets/ui/pixel/button_secondary.png")
const BUTTON_TEXTURE_DANGER: Texture2D = preload("res://assets/ui/pixel/button_danger.png")
const BUTTON_TEXTURE_TERTIARY: Texture2D = preload("res://assets/ui/pixel/button_tertiary.png")

# 🔴 2026-09-16修正: StyleBoxTextureのtexture_margin_*はGodotがStyleBoxの最小サイズ
# （margin_left+margin_right, margin_top+margin_bottom）としてそのまま採用するため、
# テクスチャ解像度に関わらずここで指定した絶対px数がボタンの強制最小サイズになる。
# 旧230pxはテクスチャが1024x1024だった当時の実測値をそのまま転用したため、
# 460x460という巨大な最小サイズを全ボタンに強制し、480x270は元より1280x720の
# Viewportでもレイアウトが完全に破綻する不具合を引き起こしていた（実機確認で発覚）。
# 対策として、ボタンテクスチャ画像を実際の枠内容にトリミングした上で64x64に
# 縮小（Pillow, LANCZOS）し、4種すべてを色解析して枠が完全に収まる最大値
# （実測: primary約8px, secondary約11px, danger約19px, tertiary約9px）に
# 安全マージンを加えた20pxを全種共通で採用する。この値は「ボタンテクスチャの
# トリミング内容」と対で管理すること（テクスチャを再生成する場合は本値も再計測する）
const BUTTON_TEXTURE_MARGIN := 20

# 🔵 DISABLED状態の不透明度。旧UiPanelStyleBox実装は呼び出し側のControl.modulateに
# 委ねる想定だったが、呼び出し元（ButtonStyleApplier）が未設定で実質機能していなかったため、
# StyleBoxTexture.modulate_color側で直接半透明化するよう是正する
const BUTTON_DISABLED_ALPHA := 0.5

# 🔵 バリアントごとのドット絵ボタンテクスチャをまとめたテーブル（make_button_stylebox()から参照）
const _BUTTON_VARIANT_TEXTURES := {
	ButtonVariant.PRIMARY: BUTTON_TEXTURE_PRIMARY,
	ButtonVariant.SECONDARY: BUTTON_TEXTURE_SECONDARY,
	ButtonVariant.DANGER: BUTTON_TEXTURE_DANGER,
	ButtonVariant.TERTIARY: BUTTON_TEXTURE_TERTIARY,
}

# 🔵 garden-alchemy-visual-refresh Plan タスク004: カードパネル共通のドット絵9-sliceテクスチャ。
# ボタンと異なりバリアント分岐が無いため単一テクスチャのみ
const PANEL_TEXTURE_PIXEL: Texture2D = preload("res://assets/ui/pixel/panel_pixel.png")

# 🔴 2026-09-18: panel_pixel.pngをGEMINI_API_KEY設定後にatelier-image-genで本番アセットへ差し替え、
# それに伴い枠幅を再計測した（旧: Pillowプレースホルダーの実測値14px）。Gemini生成の1024x1024画像を
# 既存ボタンテクスチャと同じ64x64にNEARESTでダウンサンプルした後、中央帯（y=30-34）を平均して
# Pillowで色解析した結果、外周の枠から中央のほぼ均一なクリーム領域に落ち着くまでの幅は上下左右
# 対称に約8pxだった（BUTTON_TEXTURE_MARGINと同じ「トリミング＋色解析」手順）。安全マージンを
# 2px加えて10pxを採用する。テクスチャを再生成する場合は本値も再計測すること
const PANEL_TEXTURE_MARGIN := 10

# 🟡 ui-polish Plan タスク001: UiEffects共通演出ヘルパーが使う演出値。以降のタスク（002, 003, 004,
# 006, 007, 008, 010, 011, 014, 016, 017）の使用実績を見て調整可能な暫定値として決定する
const ANIM_DURATION_POP_IN := 0.25
const ANIM_DURATION_FLY_GHOST := 0.4
const ANIM_DURATION_WITHER_FADE := 0.5
const ANIM_DURATION_QUOTA_BAR := 0.3
const ANIM_DURATION_FADE_SCREEN := 0.2
const ANIM_DURATION_HIGHLIGHT_PULSE := 0.6
const ANIM_DURATION_GOLD_COUNTDOWN := 0.4  # 🟡 タスク016: 購入成功時のゴールドカウントダウン演出時間
const ANIM_EASE_DEFAULT := Tween.EASE_OUT

# 🟡 play_wither_fade()の対象を枯れたグレーへ変色させる色。既存のCOLOR_SLOT_*系とは別に、
# 演出専用の値として新規決定した
const COLOR_WITHER_FADE_TARGET := Color("#8A8A82")
# 🟡 警告トースト用の色。design-guide.mdのステータス色には該当エントリが無いため、
# デンジャーボタン系統の赤系を流用して新規決定した
const COLOR_TOAST_WARNING := Color("#C25E4C")
# 🟡 特性発現ハイライト用の色。庭/調合フェーズのアクセントとは独立させ、金色で「発現」を強調する
const COLOR_TRAIT_HIGHLIGHT := Color("#FFD54F")
# 🟡 指定合致キラキラ用の色。既存COLOR_ALCHEMY_PREVIEW_ORDER_MATCHED（コーラル系）と
# 用途が重なるため、同じ値を再利用する
const COLOR_ORDER_MATCHED_HIGHLIGHT := COLOR_ALCHEMY_PREVIEW_ORDER_MATCHED

# 🔵 2026-09-16追加: make_button_stylebox()の(variant, state)組み合わせごとの生成結果キャッシュ。
# StyleBoxTextureは内容が同じであれば複数のButtonで安全に共有できる読み取り専用リソースのため、
# 同じ組み合わせに対して毎回新規インスタンスを生成しない（PRレビュー指摘対応）
static var _button_stylebox_cache: Dictionary = {}

# 🟡 make_panel_stylebox()の生成結果キャッシュ。バリアントが無いため単一インスタンスでよい
static var _panel_stylebox_cache: StyleBoxTexture = null


## 🔵 2026-09-16追加: バリアントごとのボタン文字色を返す（design-guide.mdのボタン表に対応）
static func get_button_text_color(variant: ButtonVariant) -> Color:
	return _BUTTON_VARIANT_TEXT_COLORS[variant]


## 🔵 ボタン4種 × 4状態のStyleBoxTextureを生成する（ドット絵9-slice方式）。
## HOVER/PRESSED/DISABLEDはテクスチャ差し替えではなくmodulate_colorで表現する:
## HOVERはNORMALよりわずかに明るく、PRESSEDはわずかに暗く、DISABLEDは半透明化する
## （旧UiPanelStyleBox実装の「DISABLEDは呼び出し側modulateに委ねる」を是正し、実際に機能させる）
static func make_button_stylebox(variant: ButtonVariant, state: ButtonState) -> StyleBoxTexture:
	var cache_key := "%d_%d" % [variant, state]
	if _button_stylebox_cache.has(cache_key):
		return _button_stylebox_cache[cache_key]

	var texture: Texture2D = _BUTTON_VARIANT_TEXTURES[variant]

	var style := StyleBoxTexture.new()
	style.texture = texture
	style.texture_margin_left = BUTTON_TEXTURE_MARGIN
	style.texture_margin_top = BUTTON_TEXTURE_MARGIN
	style.texture_margin_right = BUTTON_TEXTURE_MARGIN
	style.texture_margin_bottom = BUTTON_TEXTURE_MARGIN
	# ドット絵のにじみ防止のため伸縮ではなくタイル（反復）で拡縮する
	style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	style.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE

	match state:
		ButtonState.HOVER:
			# Color.lightened()は白に対して既に上限のため効果がない。オーバーブライト
			# （1.0超のmodulate）でNORMALより明るく見せる
			var brighten := 1.0 + BUTTON_HOVER_LIGHTEN_AMOUNT
			style.modulate_color = Color(brighten, brighten, brighten, 1.0)
		ButtonState.PRESSED:
			style.modulate_color = Color.WHITE.darkened(BUTTON_PRESSED_DARKEN_AMOUNT)
		ButtonState.DISABLED:
			style.modulate_color = Color(1.0, 1.0, 1.0, BUTTON_DISABLED_ALPHA)
		_:
			style.modulate_color = Color.WHITE

	_button_stylebox_cache[cache_key] = style
	return style


## 🔴 コードレビュー指摘対応: `control.add_theme_font_override("font", UiTheme.FONT_PIXEL_JP)`が
## garden-alchemy-visual-refresh Planの各画面（8ファイル以上）へ個別にコピーされていたため、
## 単一の呼び出し口へ集約する。将来フォント自体や追加のoverride（サイズ等）を変える場合の
## 変更漏れを防ぐ
static func apply_pixel_font(control: Control) -> void:
	control.add_theme_font_override("font", FONT_PIXEL_JP)


## 🟡 make_button_stylebox()と同型のStyleBoxTexture 9-slice生成。カードパネル共通アセットは
## バリアント・状態を持たないため引数なしで単一インスタンスを返す
static func make_panel_stylebox() -> StyleBoxTexture:
	if _panel_stylebox_cache != null:
		return _panel_stylebox_cache

	var style := StyleBoxTexture.new()
	style.texture = PANEL_TEXTURE_PIXEL
	style.texture_margin_left = PANEL_TEXTURE_MARGIN
	style.texture_margin_top = PANEL_TEXTURE_MARGIN
	style.texture_margin_right = PANEL_TEXTURE_MARGIN
	style.texture_margin_bottom = PANEL_TEXTURE_MARGIN
	# ドット絵のにじみ防止のため伸縮ではなくタイル（反復）で拡縮する（ボタンと同じ方針）
	style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	style.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE

	_panel_stylebox_cache = style
	return style


## 🔴 コードレビュー指摘対応（PR#58）: `panel.add_theme_stylebox_override("panel",
## UiTheme.make_panel_stylebox())`が12ファイルへ個別にコピーされていたため、apply_pixel_font()と
## 同じ方針で単一の呼び出し口へ集約する。将来カードパネルの適用方法を変える場合の変更漏れを防ぐ
static func apply_panel_style(panel: PanelContainer) -> void:
	panel.add_theme_stylebox_override("panel", make_panel_stylebox())
