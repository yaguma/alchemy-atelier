# 🔵 調合実行の成果を表すランタイムインスタンス（core-systems.md L129-135）。
# 複数Feature（alchemy/guild）で共有するためshared/entities/に配置する（CON-003）。
class_name ProductInstance
extends RefCounted

var recipe_id: StringName
var quality_score: int
var activated_traits: Array[StringName]
var contribution: float
var reward: float


## 🔵 core-systems.mdのフィールド定義に従い各プロパティを設定する。
## contribution/rewardの算出は呼び出し元（AlchemySystem）の責務であり、本コンストラクタでは行わない
func _init(
	p_recipe_id: StringName,
	p_quality_score: int,
	p_activated_traits: Array[StringName],
	p_contribution: float,
	p_reward: float
) -> void:
	recipe_id = p_recipe_id
	quality_score = p_quality_score
	activated_traits = p_activated_traits.duplicate()
	contribution = p_contribution
	reward = p_reward


## 🔵 GameState.get_state()の防御的コピー要件（FR-403）を満たす。
## activated_traitsは要素がStringNameのプリミティブ相当のため浅い複製で十分。
## 複製自体は_init()側が行うため、ここでは複製せずそのまま渡す（PR#15レビュー指摘対応）
func clone() -> ProductInstance:
	return ProductInstance.new(recipe_id, quality_score, activated_traits, contribution, reward)
