---
id: "001"
title: "GameStateへギルド納品UI向けアクセッサ（get_current_rank_master/get_current_rank_quota）を追加する"
status: done
priority: 1
dependencies: []
estimated_complexity: low
---

# Task: GameStateへギルド納品UI向けアクセッサを追加する

## Goal

`GuildDeliveryScreen`がランクノルマ簡易バーを表示できるよう、現在ランクの`RankMaster`を返す`GameState.get_current_rank_master()`と、ノルマ残量を返す`GameState.get_current_rank_quota()`を新規追加する（CON-001, CON-002, FR-301, FR-302）。

## Interfaces

```gdscript
# atelier/autoload/game_state.gd の is_current_rank_traits_unlocked()（L244-245）直後に追加する

## 現在ランクのRankMasterを返す（CON-001）。既存privateヘルパー
## _get_current_rank_master_or_fallback()をそのまま再利用し、判定式を重複実装しない（CON-002）。
## マスター未ロード時はtraits_unlocked=false, quota_max=0.0, limit_turn=0の
## 安全側フォールバックを返す（既存ヘルパーの契約をそのまま継承）
func get_current_rank_master() -> RankMaster:  # 🔵 CON-001/CON-002の指示どおり
    return _get_current_rank_master_or_fallback()


## 現在ランクのノルマ残量を返す（CON-001）。RankStateをUI層へ一切露出させないための
## プリミティブ値ラッパー（Plan設計フェーズで発見した、RankState型ガードとVariant無検証
## アクセスの構造的矛盾〔CON-005 vs coding-style.md〕を回避する目的）
func get_current_rank_quota() -> float:  # 🔵 CON-001（2026-08-22追加確認で確定）
    return _rank_state.quota
```

## Test Strategy

- [ ] **正常系**: `_set_rank_masters_for_test()`等で`quota_max = 100.0`, `display_name = "見習い"`の`RankMaster`を現在ランクとして登録後、`get_current_rank_master()`が同一の`quota_max`/`display_name`を持つ`RankMaster`を返す
- [ ] **正常系**: `_set_rank_state_for_test()`で`quota = 40.0`の`RankState`を注入後、`get_current_rank_quota()`が`40.0`を返す
- [ ] **異常系**: 現在ランクに対応する`RankMaster`が未登録（マスター未ロード）の場合、`get_current_rank_master()`が`_get_current_rank_master_or_fallback()`の安全側フォールバック（`quota_max = 0.0`, `traits_unlocked = false`）を返し、例外を投げない
- [ ] **境界値**: `RankState`が既定値（`reset_for_test()`直後、`quota = 0.0`）の場合、`get_current_rank_quota()`が`0.0`を返し例外を投げない

## Implementation Notes

- 参照すべき既存コード: `atelier/autoload/game_state.gd`の`_get_current_rank_master_or_fallback()`（L225-236）、`is_current_rank_traits_unlocked()`（L244-245、同型の薄いラッパーパターン）
- 実装のヒント: どちらの関数も1行の委譲のみで完結する。`_rank_state`は既にGameStateのフィールドとして存在する（`game_state.gd` L52）ため新規フィールド追加は不要
- 注意事項: `get_current_rank_quota()`は`_get_current_rank_master_or_fallback()`を経由しない（`RankState`は既定値`quota = 0.0`を持つため、ランクマスター未ロード時のフォールバック判定自体が不要。CON-002参照）

## Files

- 変更: `atelier/autoload/game_state.gd`
- テスト: `atelier/tests/integration/test_game_state_guild_ui_support.gd`
