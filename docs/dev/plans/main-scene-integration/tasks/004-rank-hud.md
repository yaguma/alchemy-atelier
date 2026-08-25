---
id: "004"
title: "RankHudコンポーネントを実装しMainSceneに常時表示する"
status: pending
priority: 2
dependencies: ["002"]
estimated_complexity: medium
---

# Task: RankHudコンポーネントを実装しMainSceneに常時表示する

## Goal

ランク名・ノルマ残量バー・残ターン・所持ゴールドの4要素を持つ`RankHud`（新規コンポーネント）を実装し、`MainScene`の全フェーズで常時表示させる。関連する`GameState` signalを購読し最新値へ追随させる。

## Interfaces

```gdscript
# atelier/shared/ui/rank_hud.gd（新規）
# 🟡 配置判断: shared/には現状ui/サブディレクトリが無いが、単一Featureに属さない横断UI
# コンポーネントのためshared/に新設する（plan.md「Design Overview」参照）
class_name RankHud
extends Control

@onready var _rank_name_label: Label = %RankNameLabel        # 🔵
@onready var _quota_bar: ProgressBar = %QuotaBar              # 🔵
@onready var _turn_remaining_label: Label = %TurnRemainingLabel # 🔵
@onready var _gold_label: Label = %GoldLabel                  # 🔵

const EMPTY_QUOTA_MAX := 1.0  # 🔵 GuildDeliveryScreenの同名定数と同型（0除算防止）

func _ready() -> void:
	refresh()
	GameState.gold_changed.connect(_on_state_changed)          # 🟡 FR-114
	GameState.turn_growth_advanced.connect(_on_state_changed)  # 🟡
	GameState.rank_outcome_confirmed.connect(_on_state_changed) # 🟡
	GameState.delivered.connect(_on_state_changed)              # 🟡
	GameState.exam_started.connect(_on_state_changed)           # 🟡
	GameState.exam_outcome_confirmed.connect(_on_state_changed) # 🟡

func _exit_tree() -> void:
	# 上記6 signal すべてを is_connected() ガード付きで disconnect

func refresh() -> void:  # 🔵 FR-002, FR-114。唯一の表示更新経路
	# GameState.get_state() + GameState.get_current_rank_master() から4要素を再計算して描画

func get_rank_name_text() -> String  # 🔵 テスト用
func get_gold_text() -> String       # 🔵 テスト用
func get_turn_remaining_text() -> String  # 🔵 テスト用
func get_quota_ratio() -> float      # 🔵 テスト用（quota / quota_max、quota_max<=0ならEMPTY_QUOTA_MAX基準の0.0）
```

```gdscript
# 引数なしのシグネチャに揃えるためのラッパー
func _on_state_changed(...) -> void:  # 各signalの引数は無視しrefresh()のみ呼ぶ
	refresh()
```

```
# atelier/shared/ui/rank_hud.tscn（新規）
[node name="RankHud" type="HBoxContainer"]
├── RankNameLabel (unique_name_in_owner)
├── QuotaBar (ProgressBar, unique_name_in_owner)
├── TurnRemainingLabel (unique_name_in_owner)
└── GoldLabel (unique_name_in_owner)
```

## Test Strategy

- [ ] `_ready()`直後、`get_rank_name_text()`が`GameState.get_current_rank_master().display_name`と一致する
- [ ] `GameState.add_gold(100)`相当の操作で`gold_changed`発行後、`get_gold_text()`が更新後の値を反映する
- [ ] `turn_growth_advanced`受信後、`get_turn_remaining_text()`が更新される
- [ ] `get_quota_ratio()`が`rank_state.quota / RankMaster.quota_max`と一致する
- [ ] **境界値**: `quota_max <= 0`（ランクマスター未登録のフォールバック等）でも`get_quota_ratio()`が0除算せずクラッシュしない
- [ ] **境界値**: `quota`が`quota_max`を超える値でも比率が1.0を超えて表示崩れしない（クランプされる）
- [ ] **異常系**: 現在ランクの`RankMaster`が未登録の場合でもクラッシュせずフォールバック表示になる
- [ ] `_exit_tree()`後、購読していた6 signal すべてが`is_connected() == false`
- [ ] RankHudの色・フォントサイズが`UiTheme`定数経由で指定されている（`Color("#...")`直書きがgrepで0件、NFR-202）

## Implementation Notes

- 参照すべき既存コード:
  - `atelier/features/guild/ui/guild_delivery_screen.gd`の`_refresh_rank_quota()`（`in_exam`時に`exam_quota`/`exam_quota_max`を、通常時に`rank_state.quota`/`RankMaster.quota_max`を出し分けるロジックがほぼそのまま流用できる）
  - `atelier/features/workshop/ui/workshop_screen.gd`の`_gold_label.text = "%d G" % gold`（ゴールド表示フォーマットの既存踏襲）
  - `atelier/shared/theme/theme.gd`（`UiTheme`定数一覧）
- 実装のヒント: `_refresh_rank_quota()`と同じ「試験中は`exam_quota`/`exam_quota_max`を見る」分岐をRankHudにも実装すること（`in_exam`表示中もノルマバーが正しく動くようにするため）。
- 注意事項: 6つのsignalそれぞれでハンドラ関数シグネチャ（引数の型・数）が異なる（`gold_changed(previous, new, delta)` vs `exam_started()`等）。GDScriptは`connect()`時に引数の数が合わなくてもコンパイルは通るが、実行時エラーを避けるため各signalに対応する引数を持つ薄いラッパー関数を用意するか、`bind()`は使わず単純に複数の同名処理を呼ぶ個別ハンドラを書く。

## Files

- 新規: `atelier/shared/ui/rank_hud.gd`, `atelier/shared/ui/rank_hud.tscn`
- 変更: `atelier/scenes/main.tscn`（RankHudをinstance）, `atelier/scenes/main.gd`（不要、RankHudは自己完結でGameStateを直接購読するため接続コード追加は不要）
- テスト: `atelier/tests/integration/test_rank_hud.gd`（新規）
