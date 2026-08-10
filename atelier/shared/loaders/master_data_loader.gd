class_name MasterDataLoader


# Phase1ではマスターデータ型が未整備のためスタブ（常に空配列）
# TODO(後続Plan): res://data/<category>/*.tres を列挙してロードする
static func load_all(_category: StringName) -> Array:
	return []


# Phase1では実マスターデータ型が無いためスタブ（常にtrue）
# TODO(後続Plan): materials内のcatalyst_tag / recipe.material_id等の相互参照を検証する
static func validate_references(_materials: Array) -> bool:
	return true
