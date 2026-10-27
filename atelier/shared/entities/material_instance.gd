# 🔵 収穫・購入で得られる素材のランタイムインスタンス（data-schema.md L46-53）。
# 複数Feature（garden/alchemy等）で共有するためshared/entities/に配置する（CON-003）。
class_name MaterialInstance
extends RefCounted

var instance_id: String
var material_id: StringName
var quality_score: int
var trait_tags: Array[StringName]
## 🔵 Issue #64（FR-711）。在庫に加わってからの経過ターン（鮮度）。FreshnessResolverが進める
var freshness_elapsed_turns: int = 0
## 🔵 Issue #64（FR-711-004）。品質Dで劣化タイミングを迎えた素材。ターン終了処理で在庫から取り除かれる
var is_rotten: bool = false


## 🔵 data-schema.mdのフィールド定義に従い各プロパティを設定する。
## instance_idの採番は呼び出し元（GameStateまたはHarvest.harvest）の責務であり、本コンストラクタでは行わない
func _init(
	p_instance_id: String,
	p_material_id: StringName,
	p_quality_score: int,
	p_trait_tags: Array[StringName]
) -> void:
	instance_id = p_instance_id
	material_id = p_material_id
	quality_score = p_quality_score
	trait_tags = p_trait_tags.duplicate()


## 🔴 GameState.get_state()の防御的コピー要件（FR-403/AC-014）を満たすための新規補完。
## trait_tagsは要素がStringNameのプリミティブ相当のため浅い複製で十分
func clone() -> MaterialInstance:
	var cloned := MaterialInstance.new(
		instance_id, material_id, quality_score, trait_tags.duplicate()
	)
	cloned.freshness_elapsed_turns = freshness_elapsed_turns
	cloned.is_rotten = is_rotten
	return cloned
