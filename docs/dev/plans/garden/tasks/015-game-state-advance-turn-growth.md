---
id: "015"
title: "GameState.advance_turn_growth()を実装する"
status: pending
priority: 3
dependencies: ["008", "011", "012"]
estimated_complexity: medium
---

# Task: GameState.advance_turn_growth()を実装する

## Goal

`GameState.advance_turn_growth()`を実装する（FR-103, FR-111）。庭にある全スロット（成熟後の待機中も含む）に`Harvest.advance_growth`を適用した直後に、必ず`Harvest.resolve_withering`を呼び出す順序を厳守する。

## Interfaces

```gdscript
# autoload/game_state.gd（既存ファイルに追記）

signal plants_withered(slot_indices: Array)   # 🔵 FR-111（Array[int]相当。GDScriptのsignal引数型注釈の制約に合わせてArrayとする）
signal turn_growth_advanced(turn: int)         # 🔴 UI再描画トリガ用の新規補完

## 🔴 対象範囲は「庭にある全スロット」（成熟後の待機中も含む）とする。
## 理由: 品質上昇判定・枯死判定にはis_matured後もgrown_turnsの継続加算が必要なため（ヒアリング結果でユーザー確認済み）
func advance_turn_growth() -> void:
	pass
```

## Test Strategy

- [ ] **正常系**: 生育中（未成熟）スロットの`grown_turns`が1進み、`master.maturity_turns`に達すると`is_matured`が`true`に更新される（AC-004）
- [ ] **正常系**: 成熟済みで枯死猶予超過寸前のスロットが混在する状態で`advance_turn_growth()`を呼ぶと、`advance_growth`適用後に`resolve_withering`が呼ばれ、猶予超過株のみ除去される（AC-004、呼び出し順序の確認）
- [ ] **正常系**: 猶予超過株が除去された場合、`plants_withered`シグナルが除去された`slot_index`一覧とともに発行される（FR-111）
- [ ] **異常系**: 庭にスロットが1つもない（`plants`が空配列）状態で`advance_turn_growth()`を呼んでもエラーにならない（AC-004異常系）
- [ ] **境界値**: 猶予をちょうど超過した直後のターンで枯死・除去される（超過前のターンでは除去されない）（AC-008境界値）
- [ ] **正常系**: `advance_turn_growth()`実行のたびに`current_turn`が1増加し、`turn_growth_advanced`シグナルが発行される

## Implementation Notes

- 参照すべき既存コード: タスク008/011で実装した`Harvest.advance_growth`/`Harvest.is_matured`/`Harvest.resolve_withering`、`docs/design/atelier-alchemy-core/core-systems.md` L65（`resolve_withering`は`advance_growth`の直後に必ず呼ぶ）
- 実装のヒント: 除去されたスロットの検出は「`resolve_withering`呼び出し前後の`slot_index`集合の差分」で計算する（除去前の`slot_index`一覧を保持しておき、除去後の一覧と比較する）
- 注意事項: `is_matured`フラグの再計算（`advance_growth`適用後、新しい`grown_turns`を基に`Harvest.is_matured`を呼び直してフラグを更新する処理）はタスク008で明示的にスコープ外とされた通り、本タスク（`GameState`側）の責務として実装すること

## Files

- 変更: `atelier/autoload/game_state.gd`
- 変更: `atelier/tests/integration/test_game_state_garden.gd`
