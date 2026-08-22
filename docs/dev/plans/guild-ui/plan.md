# Plan: guild-ui

## Requirements Summary

「Atelier」のギルド納品画面UI（SCR-003）を新規実装する。現状、`AlchemyScreen`の「ターン終了」ボタンが`GameState.deliver_pending_products()`を呼び、結果は「N件を納品しました」という1行トースト（FR-108プレースホルダー実装）で表示されるのみ。本planはこれを`features/guild/ui/`配下の専用画面`GuildDeliveryScreen`による複数件対応のリスト表示へ置き換える。

データ結合方式は「直接メソッド呼び出し方式」に確定した。`AlchemyScreen._on_end_turn_pressed()`が(1)`GameState.deliver_pending_products()`呼び出し直前に`pending_products`をスナップショット取得し、(2)呼び出しの戻り値とあわせて`GuildDeliveryScreen.display_results(products, results)`を直接呼び出す。これにより`GameState.delivered`シグナル購読も`product_crafted`追跡も不要になり、index対応（`DeliveryResult`が調合物名・品質・発現特性を持たないため必要）が同一関数スコープ内で構造的に保証される。

MainSceneへの組み込み・Tween演出・アクセシビリティ対応は本plan外（Won't Have）。

詳細: [requirements.md](requirements.md) | [user-stories.md](user-stories.md) | [acceptance-criteria.md](acceptance-criteria.md)

## Design Overview

### 新規コンポーネント

- **`GuildDeliveryResultRow`**（`features/guild/ui/guild_delivery_result_row.gd`/`.tscn`）: リスト1項目分の表示専用コンポーネント（`HBoxContainer`継承）。`AlchemyPreviewPanel`/`MaterialEntryRow`と同型の「GameState/Domain層に一切依存しない」契約。`setup(recipe_name, quality_score, activated_traits, order_matched, final_contribution, final_reward)`を公開する。
- **`GuildDeliveryScreen`**（`features/guild/ui/guild_delivery_screen.gd`/`.tscn`）: 画面本体（`Control`継承）。公開APIは`display_results(products: Array[ProductInstance], results: Array[DeliveryResult]) -> void`が唯一の表示更新経路（FR-008）。`GameState.delivered`・`GameState.product_crafted`のいずれも自前で購読しない。テスト用ゲッター`get_item_count()`/`get_total_contribution()`/`get_total_reward()`を提供する。ランクノルマ簡易バー（`GameState.get_current_rank_master()` + `GameState.get_current_rank_quota()`）と閉じるボタン（`screen_closed`シグナル）を含む。

### GameStateの拡張（CON-001, CON-002）

`atelier/autoload/game_state.gd`に以下2つの薄いラッパーを追加する。

```gdscript
func get_current_rank_master() -> RankMaster:
    return _get_current_rank_master_or_fallback()  # 既存private関数を再利用

func get_current_rank_quota() -> float:
    return _rank_state.quota
```

`get_current_rank_quota()`の追加理由: `GuildDeliveryScreen`が`GameState.get_state()["rank_state"]`（`RankState`インスタンス）を直接読むと、`RankState`型ガード（CON-005: 他Featureの`state/`直接参照禁止に抵触）と無検証`Variant`アクセス（coding-style.md抵触）のどちらかを強いられる構造的矛盾が生じる（Plan設計フェーズで発見）。プリミティブ値を返す専用APIを設けることで両ルールを同時に満たす。

### データフロー

```
AlchemyScreen._on_end_turn_pressed()
  1. var snapshot: Array[ProductInstance] = GameState.get_state()["pending_products"]
  2. var result := GameState.deliver_pending_products()
  3. _guild_delivery_screen.display_results(snapshot, result.value as Array[DeliveryResult])
       └─ GuildDeliveryScreen内部:
            recipe_id → GameState.get_state()["recipe_masters"] で名前解決
            quality_score/activated_traits → ProductInstanceからそのまま表示
            final_contribution/final_reward/order_matched → DeliveryResultからそのまま表示（再計算なし）
            合計値 = Σ results[i]
            GameState.get_current_rank_master() + get_current_rank_quota() → ノルマバー再計算
```

同一関数スコープ・同期実行のため、`snapshot`と`result.value`のindex不一致は構造的に発生しない。`pending_products`が空だった場合も`display_results([], [])`が毎ターン必ず呼ばれ、画面は0件へリセットされる（FR-006, US-401）。

### 既存パターンの踏襲元

- `atelier/features/alchemy/ui/alchemy_screen.gd`: 画面統合コンポーネントの構造（`_ready()`でのシグナル購読、`_exit_tree()`での`disconnect()`、`get_toast_text()`型のテスト用ゲッター）
- `atelier/features/alchemy/ui/alchemy_preview_panel.gd` / `material_entry_row.gd`: 表示専用子コンポーネントの契約
- `atelier/features/alchemy/ui/material_inventory_list.gd`: リスト再構築（`setup()`で全件クリア→再構築）パターン

## Task Dependency Graph

```
[001 game-state-guild-ui-support]  [002 guild-delivery-result-row-ui]
                \                          /
                 \                        /
              [003 guild-delivery-screen-ui]
                          |
              [004 alchemy-screen-guild-integration-ui]
```

トポロジカル順: 001, 002（並行可）→ 003 → 004

## Cross-Plan Dependencies

なし。`atelier/features/guild/logic/`（`DeliveryResolver`, `DeliveryResult`）・`atelier/autoload/game_state_guild_delegate.gd`はすべて実装済みで本planは変更しない（FR-405）。`atelier/features/alchemy/ui/alchemy_screen.gd`（alchemy-uiプラン成果物）へは004で変更を加える。
