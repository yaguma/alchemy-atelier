# 🔵 庭の植物の生育進行・成熟判定・枯死判定・収穫・一括枯死解決を担う純粋関数群
# （core-systems.md L64-80）。乱数はRngServiceを経由せず引数で受け取る（FR-402）。
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


## is_deadな株をgarden_state.plantsから除去した新しいGardenStateを返す（🔵 core-systems.md L65）。
## ターン終了処理でadvance_growthの直後に必ず呼ぶ（FR-103）。
## 🔵 該当するSeedMasterが見つからないseed_idの株は安全側に倒して除去しない（生存として扱う、タスク011方針）
static func resolve_withering(garden_state: GardenState, masters: Dictionary) -> GardenState:
	var survivors: Array[PlantState] = []
	for plant in garden_state.plants:
		var master: SeedMaster = masters.get(plant.seed_id)
		if master != null and is_dead(plant, master):
			continue
		survivors.append(plant)
	var result := GardenState.new()
	result.plants = survivors
	return result


## 成功時: Result.value に MaterialInstance を格納。失敗時: error_code="withered"（枯死）または"not_matured"（未成熟、防御的）。
## 🔴 master引数を追加（ヒアリング結果でユーザー確認済み。品質確定・特性選択・枯死判定がSeedMasterのフィールドに依存するため）
## 🔴 品質上昇判定は「待機1ターン以上で1回だけ判定」に単純化（ヒアリング結果でユーザー確認済み）
## 🟡 instance_idは呼び出し元（GameState）が採番するため、ここでは空文字列のプレースホルダーを設定する（タスク011実装ノート）
static func harvest(
	plant_state: PlantState, master: SeedMaster, rng_roll_quality: float, rng_roll_trait: float
) -> Result:
	if is_dead(plant_state, master):
		return Result.fail(&"withered")
	if not plant_state.is_matured:
		return Result.fail(&"not_matured")

	var waited_turns := plant_state.grown_turns - master.maturity_turns
	var quality := master.base_quality
	if waited_turns >= 1 and rng_roll_quality < GameBalance.QUALITY_UP_CHANCE:
		quality += 1
	quality = clampi(quality, GameBalance.QUALITY_SCORE_MIN, GameBalance.QUALITY_SCORE_MAX)

	var trait_tags: Array[StringName] = []
	var rolled_trait := TraitRoll.roll_trait(master, rng_roll_trait)
	if rolled_trait != &"":
		trait_tags.append(rolled_trait)

	var material := MaterialInstance.new("", master.produces_material_id, quality, trait_tags)
	return Result.ok(material)
