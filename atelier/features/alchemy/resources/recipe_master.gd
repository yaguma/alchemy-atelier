class_name RecipeMaster
extends Resource

## 調合物の設計図となるマスターデータ定義（res://data/recipes/*.tres配下に配置される想定）。
## data-schema.md「RecipeMaster」節参照。実データ（.tres）は本クラスでは作成しない。

const KIND_PRODUCT := &"product"  # 🔵 Issue #66（FR-713-001）。納品用レシピ
const KIND_INTERMEDIATE := &"intermediate"  # 🔵 別の調合に使う中間素材を作るレシピ

@export var id: StringName = &""  # 🔵 data-schema.md L150-166 一意識別子（🔴既存実装に合わせStringName）
@export var name: String = ""  # 🔵 表示名
@export var base_contribution: float = 0.0  # 🔵 品質・特性補正前のギルド貢献度基礎値
@export var base_reward: float = 0.0  # 🔵 品質・特性補正前の報酬基礎値
@export var kind: StringName = KIND_PRODUCT  # 🔵 Issue #66
## 🔵 Issue #66（FR-713-002）。kind == intermediateのとき、作られるMaterialMasterのID
@export var output_material_id: StringName = &""
## 🔵 Issue #66（FR-713-004）。中間素材が凝縮して持てる特性の数（通常1、ひらめき由来2）
@export var max_concentrated_traits: int = 1


func is_intermediate() -> bool:
	return kind == KIND_INTERMEDIATE
