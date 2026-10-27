class_name MaterialMaster
extends Resource

## 素材のマスターデータ定義（res://data/materials/*.tres配下に混在配置される想定）。
## data-schema.md「MaterialMaster」節参照。実データ（.tres）は本クラスでは作成しない。
## 触媒判定はis_catalystフィールドではなくMaterialInstance.trait_tags.has(&"catalyst")に一本化済み。

@export var id: StringName = &""  # 🔵 data-schema.md L132-137 一意識別子
@export var name: String = ""  # 🔵 表示名
@export var icon_path: String = ""  # 🔵 アイコンリソースパス
@export var shop_purchasable: bool = false  # 🔵 ショップで購入できる素材か。庭でのみ入手できる素材はfalse
@export var shop_base_quality: int = 1  # 🔵 shop_purchasable == trueの場合のみ使用
## 🔵 Issue #64（FR-711-003/005）。品質が1段下がるまでのターン数。0以下なら劣化しない
@export var decay_interval_turns: int = 0
