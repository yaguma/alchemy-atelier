class_name RecipeMaster
extends Resource

## 調合物の設計図となるマスターデータ定義（res://data/recipes/*.tres配下に配置される想定）。
## data-schema.md「RecipeMaster」節参照。実データ（.tres）は本クラスでは作成しない。

@export var id: StringName = &""  # 🔵 data-schema.md L150-166 一意識別子（🔴既存実装に合わせStringName）
@export var name: String = ""  # 🔵 表示名
@export var base_contribution: float = 0.0  # 🔵 品質・特性補正前のギルド貢献度基礎値
@export var base_reward: float = 0.0  # 🔵 品質・特性補正前の報酬基礎値
