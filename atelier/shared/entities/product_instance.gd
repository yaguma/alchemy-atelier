# 🔵 調合実行の成果を表すランタイムインスタンス（core-systems.md L129-135）。
# 複数Feature（alchemy/guild）で共有するためshared/entities/に配置する（CON-003）。
class_name ProductInstance
extends RefCounted

var recipe_id: StringName
var quality_score: int
var activated_traits: Array[StringName]
var contribution: float
var reward: float

# 🔴 コードレビュー指摘対応（PR#42マージ後の追加バグ修正）。指定依頼はGarden側のEndTurn
# （advance_turn_growth()、FR-102）から調合キューの納品タイミングと無関係に再抽選されうるため、
# 納品時点の_current_daily_orderをそのまま使うと「調合時点でプレビューに表示していたボーナスが
# 納品時には別の依頼にすり替わって消える」不整合が起きる。execute_alchemy()が調合成立の瞬間に
# 効いていた指定依頼をここへ確定させ、deliver_pending_products()はその値を優先して使う。
# has_daily_order_snapshotがfalseのまま（execute_alchemy()を経由しないテスト専用注入等）の場合は
# 従来通り納品時点の_current_daily_orderへフォールバックし、guild Planの既存契約を変えない
var daily_order_snapshot: DailyOrderMaster = null  # 🔴 上記。nullは「調合時点で指定依頼なし」を表す
var has_daily_order_snapshot: bool = false  # 🔴 上記。trueならdaily_order_snapshotを優先する


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
## 🔴 daily_order_snapshotもResource（参照型）のためclone()で複製する（daily_order_master.gd同様の理由）
func clone() -> ProductInstance:
	var copy := ProductInstance.new(
		recipe_id, quality_score, activated_traits.duplicate(), contribution, reward
	)
	copy.has_daily_order_snapshot = has_daily_order_snapshot
	copy.daily_order_snapshot = daily_order_snapshot.clone() if daily_order_snapshot else null
	return copy
