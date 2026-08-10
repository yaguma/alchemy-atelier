# 🔵 庭全体のランタイム状態（FR-001, data-schema.md L31）。
# state/配下のクラスはGameStateからのみ参照される（NFR-302）。マスターデータではないためRefCounted継承とする。
class_name GardenState
extends RefCounted

## 🔴 代入時のエイリアシング防止のためsetterで防御的コピーする（PR#11レビュー指摘対応）
var plants: Array[PlantState] = []:
	set(value):
		plants = value.duplicate()


## 🔴 GameState.get_state()の防御的コピー要件（FR-403）を満たすための新規補完。
## plantsの各要素もPlantState.clone()で複製し、配列自体も別インスタンスにする。
## Array.map()の戻り値は型付き配列(Array[PlantState])ではなく素のArrayになり、
## plantsへの代入時に型不一致の実行時エラーとなるため、明示的に型付き配列を構築する
func clone() -> GardenState:
	var cloned := GardenState.new()
	var cloned_plants: Array[PlantState] = []
	for plant in plants:
		cloned_plants.append(plant.clone())
	cloned.plants = cloned_plants
	return cloned
