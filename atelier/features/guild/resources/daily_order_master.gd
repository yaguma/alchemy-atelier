class_name DailyOrderMaster
extends Resource

## 日替わり指定調合物のマスターデータ定義（res://data/daily_orders/*.tres配下に配置される想定）。
## data-schema.md「DailyOrderMaster」節参照。実データ（.tres）は本plan外（FR-405）。

@export var id: String = ""  # 🔵 FR-003, AC-007 一意識別子
@export var condition_type: String = ""  # 🔵 FR-003, AC-007 条件種別（"item" | "trait"）
@export var target_recipe_id: String = ""  # 🔵 FR-003, AC-007 condition_type=="item"時の対象レシピID
@export var target_trait: String = ""  # 🔵 FR-003, AC-007 condition_type=="trait"時の対象特性
# 🔴 GameBalance.DAILY_ORDER_MATCH_BONUS_MULTIPLIERを既定値として参照する（🔵 FR-003, CON-006）。
# （coding-style.md「マジックナンバーの直書き禁止」。2箇所独立に1.3を書くと将来の
# バランス変更でこの既定値だけ取り残される）
@export var match_bonus_multiplier: float = GameBalance.DAILY_ORDER_MATCH_BONUS_MULTIPLIER


## 🔴 GameState.get_state()の防御的コピー要件（state-management.md）を満たすためのclone()。
## Resourceは参照型のため、get_state()やテスト注入APIがこのインスタンスをそのまま
## 渡すと呼び出し元からGameStateの内部状態を直接改変できてしまう（プリミティブ型の
## @export varのみで構成されていてもインスタンス自体は共有される点に注意）
func clone() -> DailyOrderMaster:
	var copy := DailyOrderMaster.new()
	copy.id = id
	copy.condition_type = condition_type
	copy.target_recipe_id = target_recipe_id
	copy.target_trait = target_trait
	copy.match_bonus_multiplier = match_bonus_multiplier
	return copy
