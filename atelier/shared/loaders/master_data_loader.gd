class_name MasterDataLoader

const MATERIALS_DIR := "res://data/materials/"
const RECIPES_DIR := "res://data/recipes/"
const UPGRADES_DIR := "res://data/upgrades/"
const RANKS_DIR := "res://data/ranks/"
const DAILY_ORDERS_DIR := "res://data/daily_orders/"
const INSPIRATIONS_DIR := "res://data/inspirations/"  # 🔵 Issue #67
const TRES_EXTENSION := ".tres"


## categoryに対応するディレクトリ配下の全.tresをロードして返す
## &"materials"はSeedMaster/MaterialMaster混在、&"recipes"はRecipeMasterのみを返す
static func load_all(category: StringName) -> Array:
	var dir_path := _resolve_dir_path(category)
	if dir_path.is_empty():
		return []

	var result: Array = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return result

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(TRES_EXTENSION):
			var resource: Resource = load(dir_path + file_name)
			if _is_allowed_type(category, resource):
				result.append(resource)
		file_name = dir.get_next()
	dir.list_dir_end()

	return result


## SeedMaster.produces_material_id が同一Array内のMaterialMaster.idを指しているか検証する
static func validate_references(materials: Array) -> bool:
	var material_ids: Dictionary = {}
	for m in materials:
		if m is MaterialMaster:
			material_ids[(m as MaterialMaster).id] = true

	for m in materials:
		if m is SeedMaster:
			var produces_id: StringName = (m as SeedMaster).produces_material_id
			if not material_ids.has(produces_id):
				return false

	return true


## 🔵 Issue #66。中間素材レシピのoutput_material_idが同一Array内のMaterialMaster.idを指しているか検証する。
## 実行時の検証（GameStateの_validate_alchemy_request）は空IDしか弾けないため、IDの打ち間違いは
## 実データに対するテストでここを通して検出する
static func validate_recipe_outputs(recipes: Array, materials: Array) -> bool:
	var material_ids: Dictionary = {}
	for m in materials:
		if m is MaterialMaster:
			material_ids[(m as MaterialMaster).id] = true

	for r in recipes:
		if r is RecipeMaster and (r as RecipeMaster).is_intermediate():
			if not material_ids.has((r as RecipeMaster).output_material_id):
				return false

	return true


static func _resolve_dir_path(category: StringName) -> String:
	match category:
		&"materials":
			return MATERIALS_DIR
		&"recipes":
			return RECIPES_DIR
		&"upgrades":
			return UPGRADES_DIR
		&"ranks":
			return RANKS_DIR
		&"daily_orders":
			return DAILY_ORDERS_DIR
		&"inspirations":
			return INSPIRATIONS_DIR
		_:
			return ""


## ディレクトリに他カテゴリのリソースが紛れ込んでも取り込まないよう、category単位で受理型を限定する
static func _is_allowed_type(category: StringName, resource: Resource) -> bool:
	match category:
		&"materials":
			return resource is SeedMaster or resource is MaterialMaster
		&"recipes":
			return resource is RecipeMaster
		&"upgrades":
			return resource is UpgradeMaster
		&"ranks":
			return resource is RankMaster
		&"daily_orders":
			return resource is DailyOrderMaster
		&"inspirations":
			return resource is InspirationMaster
		_:
			return false
