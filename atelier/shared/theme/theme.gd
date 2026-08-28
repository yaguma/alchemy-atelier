class_name UiTheme

const FONT_MAIN: FontFile = preload("res://assets/fonts/noto_sans_jp_regular.ttf")

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
