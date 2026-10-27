# 🔵 素材の鮮度（劣化・腐敗）を扱う純粋関数群（core-systems.md「v7.1追加システム」、FR-711）。
# 副作用・乱数・マスターデータ参照を持たない。劣化間隔は呼び出し元（GameState）がMaterialMasterから渡す。
class_name FreshnessResolver

const MIN_QUALITY := 1
const NO_DECAY := -1


## 🔵 鮮度経過ターンを1進めた複製を返す（引数はin-placeで書き換えない）。
## 経過ターンが劣化間隔の倍数に達したら品質を1段下げ、品質Dで迎えた場合は腐敗させる（FR-711-003/004）
static func age_material(material: MaterialInstance, decay_interval_turns: int) -> MaterialInstance:
	var aged := material.clone()
	aged.freshness_elapsed_turns += 1

	if not _decays(decay_interval_turns):
		return aged
	if aged.freshness_elapsed_turns % decay_interval_turns != 0:
		return aged

	if aged.quality_score > MIN_QUALITY:
		aged.quality_score -= 1
	else:
		aged.is_rotten = true
	return aged


## 🔵 次の劣化までの残りターン数を返す。劣化しない素材はNO_DECAY（-1）（FR-711-007）
static func turns_until_next_decay(material: MaterialInstance, decay_interval_turns: int) -> int:
	if not _decays(decay_interval_turns):
		return NO_DECAY
	return decay_interval_turns - material.freshness_elapsed_turns % decay_interval_turns


## 🔵 次の劣化タイミングで品質低下ではなく腐敗（在庫から消滅）になるかを返す。
## age_materialの「品質Dで劣化タイミングを迎えたら腐敗」と同じ判定をUI表示（MaterialEntryRow）でも使うために置く
static func rots_at_next_decay(material: MaterialInstance) -> bool:
	return material.quality_score <= MIN_QUALITY


## 🟡 material_masters（material_id -> MaterialMaster）から素材の劣化間隔を引く。
## マスター欠落時は劣化させない（Harvest.resolve_witheringの「欠落時は安全側に倒す」方針と揃える）。
## GameState（ターン終了時の劣化適用）とAlchemyScreen（残りターン表示）で同じ解決規則を使うために置く
static func decay_interval_of(material: MaterialInstance, material_masters: Dictionary) -> int:
	var master: MaterialMaster = material_masters.get(material.material_id)
	return master.decay_interval_turns if master != null else 0


static func _decays(decay_interval_turns: int) -> bool:
	return decay_interval_turns > 0
