class_name UiTheme

const FONT_MAIN: FontFile = preload("res://assets/fonts/noto_sans_jp_regular.ttf")

const FONT_SIZE_DEFAULT := 16

# 🔴 庭スロット4状態の表示色。ui-design/overview.mdでは色コード自体が未確定（🔴専用ビジュアルデザインパス待ち）のため、
# PlantSlotView実装のために暫定値を新規決定した。庭フェーズのアクセントカラー（リーフグリーン）を生育中に流用し、
# 他3状態は色だけでなくアイコン・テキストでも判別可能なNFR-201を踏まえた補助的な位置づけとする。
const COLOR_SLOT_EMPTY := Color("#B0AFA8")
const COLOR_SLOT_GROWING := Color("#8CC084")
const COLOR_SLOT_HARVESTABLE := Color("#D4A76A")
const COLOR_SLOT_WITHER_WARNING := Color("#E06C6C")
# 🔴 コードレビュー指摘対応で新規追加（DATA_ERROR状態）。他4色と混同しない紫系の警告色
const COLOR_SLOT_DATA_ERROR := Color("#9B7FC7")
