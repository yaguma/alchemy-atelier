class_name DailyOrderMaster
extends Resource

## 日替わり指定調合物のマスターデータ定義（res://data/daily_orders/*.tres配下に配置される想定）。
## data-schema.md「DailyOrderMaster」節参照。実データ（.tres）は本plan外（FR-405）。

@export var id: String = ""  # 🔵 FR-003, AC-007 一意識別子
@export var condition_type: String = ""  # 🔵 FR-003, AC-007 条件種別（"item" | "trait"）
@export var target_recipe_id: String = ""  # 🔵 FR-003, AC-007 condition_type=="item"時の対象レシピID
@export var target_trait: String = ""  # 🔵 FR-003, AC-007 condition_type=="trait"時の対象特性
@export var match_bonus_multiplier: float = 1.3  # 🔵 FR-003, CON-006 条件合致時の倍率
