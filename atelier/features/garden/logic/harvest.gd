# 🔵 庭の植物の生育進行・成熟判定・枯死判定を担う純粋関数群（core-systems.md L64, L66-67）。
# 収穫本体（harvest）と一括枯死解決（resolve_withering）は後続タスクで本ファイルに追加する。
class_name Harvest


## grown_turnsのみ加算した新しいPlantStateを返す。is_maturedの再計算は呼び出し元の責務。
static func advance_growth(plant_state: PlantState, turns: int) -> PlantState:
	return PlantState.new(
		plant_state.slot_index,
		plant_state.seed_id,
		plant_state.grown_turns + turns,
		plant_state.is_matured
	)


## grown_turnsがmaturity_turns以上に達しているかを判定する。
static func is_matured(plant_state: PlantState, master: SeedMaster) -> bool:
	return plant_state.grown_turns >= master.maturity_turns


## 成熟後、death_grace_turnsを超えて（等号は生存）未収穫なら枯死とみなす。
## 未成熟の場合は枯死猶予の起算点に達していないため常にfalseを返す。
static func is_dead(plant_state: PlantState, master: SeedMaster) -> bool:
	if not plant_state.is_matured:
		return false
	var waited_turns := plant_state.grown_turns - master.maturity_turns
	return waited_turns > master.death_grace_turns
