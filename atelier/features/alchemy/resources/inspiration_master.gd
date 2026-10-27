class_name InspirationMaster
extends Resource

## 熟練ひらめきの対応表（元レシピ × 投入特性 → ひらめく結果のレシピ）のマスターデータ定義
## （🔵 Issue #67、data-schema.md「v7.1追加スキーマ」InspirationMaster節、FR-714-005）。
## res://data/inspirations/*.tres配下に配置する。

@export var id: StringName = &""  # 🔵 一意識別子
@export var source_recipe_id: StringName = &""  # 🔵 使い込む元のレシピ
## 🔵 ひらめきに必要な投入特性。すべてが投入素材の特性に含まれている必要がある
@export var required_traits: Array[StringName] = []
@export var result_recipe_id: StringName = &""  # 🔵 ひらめく結果のレシピ（中間素材・派生の納品用）
## 🔵 候補になる最低ランク。ランクの上下はGameBalance.RANK_ORDERの並び順で比較する
@export var min_rank_id: StringName = &""
