class_name UpgradeMaster
extends Resource

## 工房強化・ショップの購入対象マスターデータ定義（res://data/upgrades/*.tres配下に配置される想定）。
## data-schema.md「UpgradeMaster」節参照。実データ（.tres）は本クラスでは作成しない。

@export var id: StringName = &""  # 🔵 FR-004 一意識別子
@export var name: String = ""  # 🔵 FR-004 表示名
@export var is_permanent: bool = false  # 🔵 FR-004 恒久強化か否か
@export var price: int = 0  # 🔵 FR-004 購入価格
# 🔵 FR-004。alchemy_slot_increase/garden_slot_increase/recipe_unlock/
# catalyst_stock/seed_name_purchaseの5種類
@export var effect_type: StringName = &""
# 🔵 FR-004。effect_typeに応じてint/StringNameを取る契約フィールド
# （設計都合のVariant濫用ではなく要件が明示する契約）
@export var effect_value: Variant = null
@export var max_purchase_count: int = 1  # 🔵 FR-004 購入可能回数上限
