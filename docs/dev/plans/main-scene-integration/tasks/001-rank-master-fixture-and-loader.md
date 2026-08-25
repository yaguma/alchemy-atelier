---
id: "001"
title: "RankMasterの最小限フィクスチャとload_rank_master_data()を実装する"
status: pending
priority: 1
dependencies: []
estimated_complexity: medium
---

# Task: RankMasterの最小限フィクスチャとload_rank_master_data()を実装する

## Goal

G〜Sランク8件分の`RankMaster` `.tres`（最小限の仮値）を作成し、`MasterDataLoader`に`&"ranks"`カテゴリを追加した上で、`GameStateRankDelegate.load_rank_master_data()`（新規）が起動時に呼ばれることで実際にプレイ可能なランク状態が成立するようにする。

## Interfaces

```gdscript
# atelier/shared/loaders/master_data_loader.gd への変更
const RANKS_DIR := "res://data/ranks/"  # 🔵 既存3定数と同型

# _resolve_dir_path()に分岐追加:
#   &"ranks": return RANKS_DIR  # 🔵
# _is_allowed_type()に分岐追加:
#   &"ranks": return resource is RankMaster  # 🔵
```

```gdscript
# atelier/autoload/game_state_rank_delegate.gd への追加
## res://data/ranks/ から RankMaster をロードし _rank_masters に格納する。🔵 既存3関数と同型パターン
## 初回ロード時（_rank_state_initialized == false）のみ、GameBalance.INITIAL_RANK_ID の
## RankMasterでRankQuotaResolver.reset_for_retry()を呼びRankStateを初期化し、
## _rank_state_initialized = true にする。🔵 コード調査で確認した「本番コードに初期化経路が
## 存在しない」ギャップを埋める（plan.md「Design Overview」参照）
static func load_rank_master_data(state: GameStateScript) -> void
```

```gdscript
# atelier/autoload/game_state.gd への追加（既存load_*と同型の1行委譲）
func load_rank_master_data() -> void:  # 🔵
	GameStateRankDelegate.load_rank_master_data(self)
```

```gdscript
# atelier/features/rank/resources/rank_master.gd のスキーマ（変更しない、参照のみ）
# id, display_name, quota_max, limit_turn, traits_unlocked, exam_turn_limit, exam_difficulty_coefficient
```

## Test Strategy

- [ ] `MasterDataLoader.load_all(&"ranks")` が `atelier/data/ranks/*.tres` の8件（G〜S）をすべて`RankMaster`として返す
- [ ] `MasterDataLoader.load_all(&"ranks")` が他カテゴリのリソース（`SeedMaster`等）を誤って含めない
- [ ] `GameState.load_rank_master_data()` 呼び出し後、`GameState.get_state()["current_rank_id"]` に対応する `RankMaster` が解決できる（`GameBalance.INITIAL_RANK_ID` = `&"rank_g"`）
- [ ] `load_rank_master_data()` 呼び出し後、`GameState._rank_state_initialized == true` であり `_rank_state.quota` が `rank_g` の `quota_max` と一致する
- [ ] `load_rank_master_data()` を2回連続で呼んでも `_rank_state` が上書き初期化されない（冪等性。2回目以降は初期化をスキップする）
- [ ] 8件の `RankMaster.id` が `GameBalance.RANK_ORDER`（`rank_g`〜`rank_s`）と過不足なく一致する
- [ ] **異常系**: `data/ranks/` にファイルが1件も無い状態で呼んでも `push_error` を出すのみでクラッシュしない（既存 `load_garden_master_data()` と同型の防御）

## Implementation Notes

- 参照すべき既存コード:
  - `atelier/autoload/game_state_garden_delegate.gd:11-25`（`load_garden_master_data()`の実装パターン、そのまま踏襲する）
  - `atelier/autoload/game_state_rank_delegate.gd:47-67`（`commit_rank_outcome()`。`_rank_state_initialized`ガードの意味を理解してから初期化ロジックを書く）
  - `atelier/features/rank/logic/rank_quota_resolver.gd:20-`（`reset_for_retry(rank_master) -> RankState`。これをそのまま流用する）
  - `atelier/shared/constants/game_balance.gd:67-`（`RANK_ORDER`, `INITIAL_RANK_ID`）
  - `atelier/data/materials/`, `atelier/data/recipes/`, `atelier/data/upgrades/` 配下の既存`.tres`（値の書式・Godotエディタでの`.tres`テキスト形式の参考）
- 実装のヒント: `.tres`ファイルはGodotエディタを使わずテキストエディタで手書きしてよい（`[gd_resource type="Resource" script_class="RankMaster" ...]`形式、既存の`data/materials/*.tres`を参考にヘッダ部分を揃える）。8ランクの仮値は「ランクが上がるほどノルマ・制限ターンが増える」程度の単調な数値でよい（例: quota_max = 10, 15, 22, 30, 40, 55, 75, 100 / limit_turn = 8, 10, 12, 14, 16, 18, 20, 24 / exam_turn_limit = 3固定 / exam_difficulty_coefficient = 1.0固定 / traits_unlocked = rank_g以外true）。バランス設計書との整合は取らなくてよい（別Planで確定）。
- 注意事項: `_rank_state_initialized`の初期化は「ロードのたび」ではなく「ゲーム開始時1回だけ」であるべき。`load_rank_master_data()`を将来複数回呼ぶ設計変更が入ってもプレイ中のランク進行状態を巻き戻さないよう、必ず`if not state._rank_state_initialized:`でガードすること。

## Files

- 新規: `atelier/data/ranks/rank_g.tres`, `rank_f.tres`, `rank_e.tres`, `rank_d.tres`, `rank_c.tres`, `rank_b.tres`, `rank_a.tres`, `rank_s.tres`
- 変更: `atelier/shared/loaders/master_data_loader.gd`, `atelier/autoload/game_state_rank_delegate.gd`, `atelier/autoload/game_state.gd`
- テスト: `atelier/tests/unit/shared/test_master_data_loader.gd`（`&"ranks"`カテゴリの追加テスト）, `atelier/tests/integration/test_game_state_rank_foundation.gd`（`load_rank_master_data()`の統合テスト、新規または既存ファイルへの追記）
