---
id: "011"
title: "GameState.execute_alchemyを実装する"
status: pending
priority: 3
dependencies: ["005", "006", "007", "010"]
estimated_complexity: high
---

# Task: GameState.execute_alchemyを実装する

## Goal

`GameState.execute_alchemy(recipe_id, material_instance_ids) -> Result`を実装する。投入検証（4段階）→`SlotState`再評価→Domain層計算（品質・特性・価値）→成功時のみ在庫消費・`pending_products`追加・signal発行、を単一アトミック呼び出しとして行う。

## Interfaces

```gdscript
# autoload/game_state.gd（既存ファイルへの追記）

## FR-102の順序で検証: (1)recipe_id実在 (2)unlocked (3)material実在 (4)投入枠内重複なし。
## 通過後にFR-103でSlotState.can_execute()を実行直前に再評価。
## 成功時のみinventory除去→pending_products追加→product_crafted発行（FR-112）。
## いずれかの段階の失敗はinventory/pending_productsを一切変更せずexecute_alchemy_failedを発行（FR-113）
func execute_alchemy(recipe_id: StringName, material_instance_ids: Array[String]) -> Result:
	...

## _inventory内でinstance_idが一致する要素のインデックスを返す。見つからない場合は-1
func _find_inventory_index(instance_id: String) -> int:
	...

## material_instance_ids内に重複が存在するか
func _has_duplicate_ids(ids: Array[String]) -> bool:
	...
```

> 信号機: 🔵 検証(3)(4)・`SlotState.can_execute()`再評価・Domain層呼び出し順序（`core-systems.md` L162-169, L142-152）。🔴 検証(1)(2)のレシピ存在/解禁チェック順序、失敗時のシグナル発行・状態不変の具体設計は garden の`plant_seed`パターン踏襲の新規補完（FR-102, FR-112, FR-113）

## Test Strategy

- [ ] 正常系（AC-010）: 特性なし・触媒なしの単純ケースで`contribution = base_contribution * quality_multiplier(quality_score) * 1.0`、`reward = base_reward * quality_multiplier(quality_score) * 1.0`が式通りに算出され、`Result.success`が真
- [ ] 正常系（AC-010）: 調合成功後、投入した全`instance_id`が`inventory`から消え、`inventory.size()`が投入前より投入数分減っている
- [ ] 正常系（AC-010）: 調合成功後、生成された`ProductInstance`が`pending_products`に追加され、`product_crafted`シグナルが発行された`product`の内容が算出結果と一致する
- [ ] 正常系（AC-010）: `ProductInstance.recipe_id`が投入した`recipe_id`と一致する（FR-111）
- [ ] 異常系（AC-009ケースA）: 未知の`recipe_id`（`_recipe_masters`に存在しない）で`error_code = &"unknown_recipe_id"`の失敗`Result`が返り、`execute_alchemy_failed`が発行され、`inventory`/`pending_products`が不変
- [ ] 異常系（AC-009ケースB）: 実在するが`_unlocked_recipe_ids`に含まれない`recipe_id`で`error_code = &"recipe_not_unlocked"`の失敗`Result`が返る
- [ ] 異常系（AC-005）: `material_instance_ids`に`inventory`へ実在しない`instance_id`が1件でも含まれると`error_code = &"material_not_owned"`で失敗する
- [ ] 異常系（AC-006）: `material_instance_ids`に同一`instance_id`が2回指定されると`error_code = &"duplicate_material_in_slot"`で失敗する
- [ ] 異常系（AC-007）: `material_instance_ids`が`_alchemy_slot_count`を超える件数（例: 5件で上限4）だと`error_code = &"slot_execution_invalid"`で失敗する。ちょうど上限件数（4件）は成功する
- [ ] 異常系（AC-008）: `material_instance_ids = []`（0個投入）だと`error_code = &"slot_execution_invalid"`で失敗する
- [ ] 正常系（AC-011）: `_traits_unlocked = false`で触媒+特性2個を投入しても、品質は触媒ボーナスなしの平均四捨五入値のまま、`activated_traits`は空配列になり特性ボーナスが乗らない
- [ ] 正常系（AC-011）: 同じ素材構成で`_traits_unlocked = true`に切り替えると触媒・特性ボーナスの両方が有効になる（対比確認）
- [ ] 異常系（AC-015）: 各失敗ケース（5種類の`error_code`）ごとに`execute_alchemy_failed`が対応する`error_code`で発行され、かつ`inventory`・`pending_products`が呼び出し前と完全に一致する

## Implementation Notes

- 参照すべき既存コード: `atelier/autoload/game_state.gd`の`plant_seed()`/`harvest()`（検証→Domain層呼び出し→副作用適用→signal発行、というメソッド全体の構成パターン）、`_find_seed_inventory_index()`/`_find_plant_index()`（インデックス探索ヘルパーのスタイル）
- 実装のヒント: 検証(1)〜(4)は早期リターンで実装し、いずれかに引っかかった時点で即座に`execute_alchemy_failed.emit(...)`して`Result.fail(...)`を返す。検証を全て通過してから`SlotState`を構築し`can_execute()`を再評価する（FR-103）。Domain層呼び出しは`QualityCalculator.calculate_quality` → `quality_multiplier` → `TraitActivation.resolve_traits` → `ProductValueCalculator.resolve_contribution_bonus`/`resolve_reward_bonus` → `calculate_contribution`/`calculate_reward`の順で行う。`_traits_unlocked`は`calculate_quality`と`resolve_traits`の両方に同一値で渡す（FR-104）
- 注意事項: 副作用（`_inventory.remove_at`・`_pending_products.append`・`product_crafted.emit`）は全ての検証・計算が成功した後にのみ行う。途中で失敗した場合は`_inventory`/`_pending_products`を一切変更しない（FR-113を満たすための実装上の要点）。`recipe: RecipeMaster = _recipe_masters[recipe_id]`の取得は検証(1)通過後であれば安全

## Files

- 変更: `atelier/autoload/game_state.gd`
- テスト: `atelier/tests/integration/test_game_state_execute_alchemy.gd`
