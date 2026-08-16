class_name RankMaster
extends Resource

## ギルドランクのマスターデータ定義（res://data/ranks/*.tres配下に配置される想定）。
## data-schema.md「RankMaster」節参照。実データ（.tres）は本plan外（FR-405）。

@export var id: String = ""  # 🔵 data-schema.md L190-212 ランク識別子（G/F/E/D/C/B/A/S）
@export var display_name: String = ""  # 🔵 表示名
@export var quota_max: float = 0.0  # 🔵 当該ランクのノルマ上限
@export var limit_turn: int = 0  # 🔵 当該ランクの制限ターン数
@export var traits_unlocked: bool = false  # 🔵 特性システムが解禁済みか（Gランクはfalse固定）

# 🔵 CON-012: 昇格試験用フィールド。本plan内のロジックからは参照しないが、
# data-schema.mdのスキーマ完全性を保つため定義のみ行う。
@export var exam_turn_limit: int = 0  # 🔵 昇格試験の制限ターン数
@export var exam_difficulty_coefficient: float = 0.0  # 🔵 昇格試験ノルマの難度係数
