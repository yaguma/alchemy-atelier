---
id: "005"
title: "GameStateにギルド納品関連フィールド・テストAPIを追加する"
status: pending
priority: 3
dependencies: ["002"]
estimated_complexity: medium
---

# Task: GameStateにギルド納品関連フィールド・テストAPIを追加する

## Goal

`autoload/game_state.gd`に、納品処理（タスク006）の前提となるランタイムフィールド（累積貢献度・本日の指定調合物）、`delivered`シグナル宣言、`get_state()`/`reset_for_test()`の拡張、テスト専用APIを追加する。`deliver_pending_products()`本体（タスク006）は対象外。

## Interfaces

```gdscript
# autoload/game_state.gd（既存ファイルへの追記）

signal delivered(results: Array[DeliveryResult])  # 🔴 FR-108

# --- ギルド納品（guild）関連フィールド ---
var _accumulated_contribution: float = 0.0          # 🔴 FR-006, CON-004。RankSystem未実装のための暫定累積フィールド
var _current_daily_order: DailyOrderMaster = null    # 🔴 CON-010。再抽選ロジックは別plan、既定値nullで動作

## テスト専用。deliver_pending_products()を経由せず本日の指定調合物を直接注入する（FR-301, AC-008）
func _set_current_daily_order_for_test(order: DailyOrderMaster) -> void:
	...
```

> 信号機: 🔵 `delivered`のシグナル命名は既存の`product_crafted`/`material_harvested`パターン踏襲。🔴 `_accumulated_contribution`/`_current_daily_order`/テスト専用APIは本plan・alchemy実装パターン踏襲の新規補完（FR-006, CON-004, CON-010, FR-301）

## Test Strategy

- [ ] 正常系: `reset_for_test()`実行後、`_accumulated_contribution`が`0.0`、`_current_daily_order`が`null`になっている（AC-010境界値）
- [ ] 正常系: `get_state()`が`accumulated_contribution`をキーとして含み、`_accumulated_contribution`と同じ値を返す
- [ ] 正常系: `_set_current_daily_order_for_test(order)`実行後、以降の（本タスクで検証可能な範囲の）状態取得に反映される
- [ ] エッジケース: `_set_current_daily_order_for_test()`を呼ばない場合、`_current_daily_order`は`null`のまま（デフォルト動作の確認）

## Implementation Notes

- 参照すべき既存コード: `atelier/autoload/game_state.gd`の`_traits_unlocked`（暫定フィールドの命名・初期値パターン）、`_set_traits_unlocked_for_test()`（テスト専用APIの二重ガード実装）、`get_state()`/`reset_for_test()`の既存拡張箇所（alchemy planタスク010で追加された調合関連フィールドの並び）
- 実装のヒント: テスト専用APIは既存の`_set_traits_unlocked_for_test`と同じ二重ガード（`assert(OS.is_debug_build(), ...)` + `if not OS.is_debug_build(): push_error(...); return`）を必ず踏襲する
- 注意事項: `_accumulated_contribution`は`float`のプリミティブ値のため`get_state()`での複製は不要（値渡し）。`_current_daily_order`は`Resource`型だが本plan内で書き換え可能なミュータブルフィールドを持たないため、`get_state()`では参照をそのまま返してよい（`DailyOrderMaster`は`@export var`のみでネストした`Array`/`Dictionary`フィールドを持たないため、FR-408の対象は`pending_products`に限定される）

## Files

- 変更: `atelier/autoload/game_state.gd`
- テスト: `atelier/tests/integration/test_game_state_guild_foundation.gd`
