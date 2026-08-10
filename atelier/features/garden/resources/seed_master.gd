class_name SeedMaster
extends Resource

## 庭で育成する「種」のマスターデータ定義（res://data/materials/*.tres配下に混在配置される想定）。
## data-schema.md「SeedMaster」節参照。実データ（.tres）は本クラスでは作成しない。

@export var id: StringName = &""  # 🔵 data-schema.md L106 一意識別子
@export var name: String = ""  # 🔵 data-schema.md L106 表示名
@export var produces_material_id: StringName = &""  # 🔵 収穫時に生成されるMaterialMasterのID
@export var maturity_turns: int = 1  # 🔵 成熟までのターン数（種別ごとに異なる、🟡TBD具体値）
@export var death_grace_turns: int = 2  # 🔵 成熟後の枯死猶予ターン数（🟡TBD具体値）
@export var base_quality: int = 1  # 🔵 成熟直後に収穫した場合の品質スコア
@export var trait_pool: Array[StringName] = []  # 🔵 収穫時に一様乱数で選ばれる特性タグ候補
