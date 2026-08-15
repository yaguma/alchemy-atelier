---
id: "006"
title: "GameState.deliver_pending_productsを実装する"
status: pending
priority: 3
dependencies: ["004", "005"]
estimated_complexity: high
---

# Task: GameState.deliver_pending_productsを実装する

## Goal

`GameState.deliver_pending_products() -> Result`を実装する。`_pending_products`を先頭から全件消費し、各`ProductInstance`について`DeliveryResolver.resolve`を呼び出したうえで、`final_reward`を`_gold`へ、`final_contribution`を`_accumulated_contribution`へ反映し、`delivered`シグナルを発行する単一アトミック呼び出し（CON-009）。

## Interfaces

```gdscript
# autoload/game_state.gd（既存ファイルへの追記）

## _pending_productsを先頭から全件消費し、各ProductInstanceについて
## DeliveryResolver.resolve(product, _current_daily_order)を呼び出す（FR-005, FR-105）。
## final_rewardはroundi()で丸めて_goldへ即時加算（FR-106, CON-007）。
## final_contributionはfloatのまま_accumulated_contributionへ加算（FR-107）。
## 処理完了後_pending_productsを空にし、delivered(results)シグナルを発行する（FR-108）。
## _pending_productsが空の場合は状態を一切変更せずResult.ok([])を返す（FR-109, AC-012）
func deliver_pending_products() -> Result:
	...
```

> 信号機: 🔵 `DeliveryResolver.resolve`呼び出し・`match_bonus`適用ロジック自体（core-systems.md L213-214）。🔴 キュー消費順序・全件処理・`_gold`即時加算・`roundi()`丸め・`delivered`シグナルの新設は本plan内ヒアリング結果に基づく新規補完（FR-105〜109, CON-007, CON-009）

## Test Strategy

- [ ] 正常系（AC-008）: `_pending_products`に3件投入 → 戻り値`Result.value`（`Array[DeliveryResult]`）が3要素、`_pending_products`が空になる
- [ ] 正常系（AC-008）: キュー先頭から順に処理され、戻り値配列の順序が投入順と一致する
- [ ] 異常系（AC-008）: 同じ納品処理を連続2回呼ぶと、2回目は`Result.value`が空配列（二重納品されない）
- [ ] 正常系（AC-009）: `_gold = 0`・`reward = 5.0`・合致ボーナス1.3倍で`final_reward = 6.5` → `roundi()`により`_gold`が`7`になる
- [ ] 境界値（AC-009）: `final_reward = 6.4` → `_gold`は`+6`、`final_reward = 6.5` → `_gold`は`+7`（四捨五入の境界）
- [ ] 境界値（AC-009）: `final_reward = 0.0` → `_gold`が変化しない
- [ ] 異常系（AC-009）: 加算前の`_gold`が0でない場合も既存値へ正しく加算される（上書きされない）
- [ ] 正常系（AC-010）: `contribution = 10.0`の1件納品で`_accumulated_contribution`が`10.0`（合致なしの場合）増える
- [ ] 正常系（AC-010）: 納品処理を複数回実行すると`_accumulated_contribution`が累積する（リセットされない）
- [ ] 正常系（AC-011）: `delivered`シグナルが1回発行され、`results`の要素数が納品件数と一致し、`order_matched`が件別に正しい（`monitor_signals(GameState, false)`で監視、Autoloadのため第2引数`false`必須）
- [ ] 正常系（AC-012）: `_pending_products`が空の状態で呼び出すと、`Result.success == true`かつ`value`が空配列、`_gold`・`_accumulated_contribution`・`_pending_products`のいずれも変化しない
- [ ] 統合（AC-014）: `execute_alchemy` → `deliver_pending_products`の一連の呼び出しで、`final_contribution`が`base × quality_mult × trait_bonus × match_bonus`（合致ボーナスは1回のみ）となることを期待値計算と突き合わせて確認する
- [ ] 統合（AC-015）: `deliver_pending_products()`呼び出し後、`get_state().pending_products`に`append`しても`GameState`内部の`_pending_products`は変化しない（防御的コピーの維持確認）

## Implementation Notes

- 参照すべき既存コード: `atelier/autoload/game_state.gd`の`execute_alchemy()`（検証→Domain層呼び出し→副作用適用→signal発行、というメソッド全体の構成パターン、特に「副作用は成功確定後にのみ適用する」という順序）
- 実装のヒント: `_pending_products`が空なら即座に`Result.ok([])`を返して終了する（早期リターン、FR-109）。非空の場合は`results: Array[DeliveryResult] = []`を用意し、`for product in _pending_products:`でループしながら`DeliveryResolver.resolve(product, _current_daily_order)`を呼び、`_gold += roundi(result.final_reward)`・`_accumulated_contribution += result.final_contribution`・`results.append(result)`を行う。ループ完了後に`_pending_products.clear()`・`delivered.emit(results)`・`return Result.ok(results)`
- 注意事項: `_pending_products`を走査中に同じ配列を`clear()`すると走査が壊れるため、`clear()`はループ完了後に行う。`roundi()`はGDScript組み込み関数（四捨五入）であり、`round()`（float返却）と混同しない

## Files

- 変更: `atelier/autoload/game_state.gd`
- テスト: `atelier/tests/integration/test_game_state_deliver_pending_products.gd`
