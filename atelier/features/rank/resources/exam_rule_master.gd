class_name ExamRuleMaster
extends Resource

## 昇格試験の出題ルールのマスターデータ定義（🔵 Issue #68、data-schema.md「v7.1追加スキーマ」
## ExamRuleMaster節、FR-715）。res://data/exam_rules/*.tres配下に配置する。

const RULE_QUOTA := &"quota"  # 試験ノルマを制限ターン内に0にする（v7.0までの方式）
const RULE_DELIVER_ITEMS := &"deliver_items"  # 指定レシピの調合物を指定数納品する
const RULE_QUALITY_WITH_SLOT_LIMIT := &"quality_with_slot_limit"  # 投入枠を減らし指定品質以上を納品
const RULE_DUAL_TRAITS := &"dual_traits"  # 指定特性をすべて同時に宿した調合物を納品する
const RULE_USE_INTERMEDIATE := &"use_intermediate"  # 中間素材を投入した調合物を納品する

@export var id: StringName = &""
@export var rule_type: StringName = RULE_QUOTA
@export var display_text: String = ""  # 🔵 予告・試験画面に出す説明文
## 🔵 試験の制限ターン数。quotaルールは従来どおりRankMaster.exam_turn_limitを使うため参照しない
@export var turn_limit: int = 0
@export var target_recipe_ids: Array[StringName] = []  # 🔵 deliver_itemsの対象（空なら任意）
@export var target_count: int = 1  # 🔵 合格に必要な納品数
@export var slot_limit: int = 0  # 🔵 quality_with_slot_limitの投入枠上限（0以下なら制限なし）
@export var min_quality: int = 0  # 🔵 quality_with_slot_limitの最低品質
@export var target_traits: Array[StringName] = []  # 🔵 dual_traitsで同時に宿す特性
@export var reward_recipe_ids: Array[StringName] = []  # 🔵 合格時に解禁されるレシピ（FR-715-005）
