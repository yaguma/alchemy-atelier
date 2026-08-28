---
id: "002"
title: "MainSceneの骨格を実装し4画面の常駐とvisible切替を成立させる"
status: done
priority: 1
dependencies: ["001"]
estimated_complexity: high
---

# Task: MainSceneの骨格を実装し4画面の常駐とvisible切替を成立させる

## Goal

`atelier/scenes/main.tscn`にGardenScreen/AlchemyScreen/WorkshopScreen/ResultScreenの4画面をインスタンス化して常駐させ、`main.gd`が起動時マスターデータロードと`GameState.phase_changed`購読による`visible`排他切替を行うことで、`GameState.set_phase()`を呼べば表示画面が追随する最小限の骨格を成立させる。タブバー・RankHud・工房/納品ルーティング・試験分岐は後続タスクで追加するため、本タスクでは`GameState.set_phase()`を外部から直接呼んだ場合の追随のみを検証範囲とする。

## Interfaces

```gdscript
# atelier/scenes/main.gd（新規）
class_name MainScene
extends Control

@onready var _garden_screen: GardenScreen = %GardenScreen      # 🔵
@onready var _alchemy_screen: AlchemyScreen = %AlchemyScreen   # 🔵
@onready var _workshop_screen: WorkshopScreen = %WorkshopScreen # 🔵
@onready var _result_screen: ResultScreen = %ResultScreen       # 🔵

const PHASE_SCREENS := {  # 🔵 FR-001, FR-103
	&"garden": "_garden_screen",
	&"alchemy": "_alchemy_screen",
	&"workshop": "_workshop_screen",
	&"result": "_result_screen",
}

func _ready() -> void:
	# 1. マスターデータロード（FR-006）
	GameState.load_garden_master_data()
	GameState.load_alchemy_master_data()
	GameState.load_workshop_master_data()
	GameState.load_rank_master_data()
	# 2. GameState.phase_changed購読（FR-103）
	GameState.phase_changed.connect(_on_phase_changed)
	# 3. 初期表示をcurrent_phaseに合わせる（FR-004）
	_apply_visible_phase(GameState.get_state()["current_phase"])

func _exit_tree() -> void:  # 🔵 FR-005
	if GameState.phase_changed.is_connected(_on_phase_changed):
		GameState.phase_changed.disconnect(_on_phase_changed)

func _on_phase_changed(_previous: StringName, next: StringName) -> void:  # 🔵 FR-103
	_apply_visible_phase(next)

func _apply_visible_phase(phase: StringName) -> void:  # 🔵 FR-001, FR-103, FR-004
	# PHASE_SCREENSの4画面のうちphaseに一致する1つのみvisible=true、他はfalse
	# 未知のphase値の場合はいずれもvisible=trueにせず警告する（AC-001異常系）

func get_visible_phase() -> StringName:  # 🔵 テスト用。現在visible=trueの画面に対応するフェーズ名を返す
```

```
# atelier/scenes/main.tscn（新規構築）
[node name="Main" type="Control"]
├── GardenScreen (instance=garden_screen.tscn, unique_name_in_owner, visible初期値=true)
├── AlchemyScreen (instance=alchemy_screen.tscn, unique_name_in_owner, visible=false)
├── WorkshopScreen (instance=workshop_screen.tscn, unique_name_in_owner, visible=false)
└── ResultScreen (instance=result_screen.tscn, unique_name_in_owner, visible=false)
```

## Test Strategy

- [ ] `scene_runner("res://scenes/main.tscn")`でロード直後、`get_visible_phase() == &"garden"`であり、GardenScreenのみ`visible == true`
- [ ] `GameState.load_garden_master_data()`等4関数が`_ready()`内で呼ばれた結果、`GameState.get_state()["seed_masters"]`等が空でない（`GameState.reset_for_test()`直後の状態から検証）
- [ ] `GameState.set_phase(&"alchemy")`を外部から呼ぶと`phase_changed`発行を経て`get_visible_phase() == &"alchemy"`になり、AlchemyScreenのみ可視、他3画面は不可視
- [ ] garden→alchemy→workshop→result→gardenと連続で`set_phase()`しても、常にちょうど1画面のみ可視である
- [ ] **異常系**: 未知のフェーズ値（例: `&"unknown"`）で`set_phase()`した場合、4画面のうち可視のものが0または1のまま（複数可視にならない）で`push_warning`を出す
- [ ] `_exit_tree()`後、`GameState.phase_changed.is_connected()`が`false`になる
- [ ] `main.gd`に`_process()`が定義されていない（NFR-002。ソース中に`func _process`が0件）

## Implementation Notes

- 参照すべき既存コード:
  - `atelier/features/workshop/ui/workshop_screen.gd`の`_refresh()`パターン（GameState.get_state()の都度取得スタイルを他画面も踏襲している）
  - `atelier/scenes/boot.gd`（`change_scene_to_file.call_deferred`の遷移先が本タスクの`main.tscn`。boot.gd自体は変更しない、CON-002）
  - `atelier/features/*/ui/*.tscn`の各画面ルートノードの`anchors_preset`（`main.tscn`内にインスタンスする際もフルスクリーン表示になるよう揃える）
- 実装のヒント: `PHASE_SCREENS`のようなDictionary+文字列プロパティ名参照は型安全性に欠けるため、実装時は`match phase:`文で4分岐を素直に書く方が`coding-style.md`の型安全方針に沿う（Interfacesの`PHASE_SCREENS`は設計意図の説明用であり、実装は`match`文推奨）。
- 注意事項: 4画面すべてに`GameState`が既にAutoloadとしてロード済み（テスト側で`GameState.reset_for_test()`を`before_test()`で呼ぶことを前提にできる）。本タスクではタブバー・RankHud・ショップ導線・試験分岐は一切実装しない（後続タスクのスコープ）。

## Files

- 新規: `atelier/scenes/main.gd`
- 変更: `atelier/scenes/main.tscn`
- テスト: `atelier/tests/integration/test_main_scene_visibility.gd`（新規）
