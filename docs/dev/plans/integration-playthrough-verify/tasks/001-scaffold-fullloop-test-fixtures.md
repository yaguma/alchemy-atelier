---
id: "001"
title: "ロングランプレイスルーテストの雛形と共通フィクスチャヘルパーを実装する"
status: done
priority: 1
dependencies: []
estimated_complexity: medium
---

# Task: ロングランプレイスルーテストの雛形と共通フィクスチャヘルパーを実装する

## Goal

`atelier/tests/integration/test_main_scene_full_loop_playthrough.gd` を新規作成し、G→F→Eの2段階連続昇格シナリオで使い回すフィクスチャ生成・UI操作ヘルパー一式と、シーンを起動して初期状態を確認するだけの最小テスト（Red相当の土台）を用意する。

## Interfaces

```gdscript
extends GdUnitTestSuite

# --- 定数（既存test_main_scene_exam_flow.gdのRANK_QUOTA_MAX等を踏襲） ---
const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const RANK_G_ID: StringName = &"rank_g"      # 🔵 GameBalance.RANK_ORDER[0]
const RANK_F_ID: StringName = &"rank_f"      # 🔵 GameBalance.RANK_ORDER[1]
const RANK_E_ID: StringName = &"rank_e"      # 🔵 GameBalance.RANK_ORDER[2]
const RECIPE_ID: StringName = &"recipe_full_loop_test"
const MATERIAL_ID: StringName = &"material_herb"
const MATERIAL_QUALITY := 3
const RANK_QUOTA_MAX := 4.0                  # 🔵 test_main_scene_exam_flow.gdと同値の低ノルマ
const RANK_LIMIT_TURN := 2
const EXAM_TURN_LIMIT := 2
const EXAM_DIFFICULTY_COEFFICIENT := 1.0
const PRODUCT_CONTRIBUTION := 20.0
const PRODUCT_REWARD := 5.0
const RECIPE_BASE_CONTRIBUTION := 20.0
const RECIPE_BASE_REWARD := 5.0

func before_test() -> void:  # 🔵 GameState.reset_for_test()踏襲
	pass

func _make_main() -> MainScene:  # 🔵 scene_runner(MAIN_SCENE_PATH).scene()
	pass

## 3ランク分（rank_g/rank_f/rank_e）のRankMasterを一括登録する
func _setup_rank_masters() -> void:  # 🔵 _set_rank_masters_for_test()踏襲
	pass

## current_rank_idと、その時点で使う低ノルマRankStateを注入する。
## ランクを跨ぐたびに呼び直す想定（🟡 elapsed_turn自動進行未実装のための既存回避策踏襲）
func _enter_rank(rank_id: StringName) -> void:
	pass

func _setup_recipe_and_material() -> void:  # 🔵 _set_recipe_masters_for_test等踏襲
	pass

# --- UI操作ヘルパー（test_main_scene_happy_path.gd / test_main_scene_exam_flow.gd踏襲） ---
func _press(root: Node, node_name: String) -> void:  # 🔵
	pass

func _screen_instance_ids(main: MainScene) -> Array[int]:  # 🔵 NFR-001観測点踏襲
	pass
```

> 信号機: 定数・ヘルパーの大半は既存2ファイル（`test_main_scene_happy_path.gd`, `test_main_scene_exam_flow.gd`）の確立済みパターンの転用のため🔵。`_enter_rank()`のみ複数ランク遷移という新規要件のため🟡（設計はPlan.mdのDesign Overview参照）。

## Test Strategy

- [ ] `_make_main()`でMainSceneを起動した直後、`_setup_rank_masters()` + `_enter_rank(RANK_G_ID)` 後に `GameState.get_state()["current_rank_id"]` が `rank_g` であること
- [ ] `_screen_instance_ids(main)` がGardenScreen/AlchemyScreen/WorkshopScreen/ResultScreen/MainScene自身の5件のインスタンスIDを返すこと
- [ ] エッジケース: `_enter_rank()`を同一テスト内で2回（rank_g→rank_f）呼んでも例外にならず、2回目呼び出し後の`RankState.quota`が`RANK_QUOTA_MAX`にリセットされていること

## Implementation Notes

- 参照すべき既存コード: `atelier/tests/integration/test_main_scene_exam_flow.gd`（フィクスチャ生成・UI操作ヘルパー全般）, `atelier/tests/integration/test_main_scene_happy_path.gd`（`_screen_instance_ids()`, `_press()`）
- `RankMaster`のフィールド（`id`, `display_name`, `quota_max`, `limit_turn`, `traits_unlocked`, `exam_turn_limit`, `exam_difficulty_coefficient`）は`test_main_scene_exam_flow.gd`の`_make_rank()`をそのまま流用可能
- `RankState`のフィールド（`quota`, `elapsed_turn`）も同ファイルの`_make_rank_state()`を参照
- 本タスクではシナリオ本体（試験・工房・2段階昇格）は実装しない。ヘルパー一式が期待通り動くことを確認する最小限のテストのみ置く
- 注意事項: `MainScene._enter_tree()`がマスターデータを読み込むため、フィクスチャ注入は必ず`_make_main()`呼び出し**後**に行う（既存コードのコメント L99-100参照）

## Files

- 新規: `atelier/tests/integration/test_main_scene_full_loop_playthrough.gd`
