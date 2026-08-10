---
id: "008"
title: "Harvestの生育・成熟・枯死判定ロジックを実装する"
status: done
priority: 2
dependencies: ["004", "005"]
estimated_complexity: medium
---

# Task: Harvestの生育・成熟・枯死判定ロジックを実装する

## Goal

`features/garden/logic/harvest.gd`に、生育進行・成熟判定・枯死判定の3つの純粋関数（`advance_growth`, `is_matured`, `is_dead`）を実装する。収穫本体（`harvest`）と一括枯死解決（`resolve_withering`）は後続タスク011で同ファイルに追加する。

## Interfaces

```gdscript
# features/garden/logic/harvest.gd
class_name Harvest

## 副作用なし。grown_turnsのみ加算した新しいPlantStateを返す（is_maturedは更新しない、呼び出し元の責務）
## 🔵 core-systems.md L64
static func advance_growth(plant_state: PlantState, turns: int) -> PlantState:
	pass

## grown_turns >= master.maturity_turns を判定（🔵 core-systems.md L66）
static func is_matured(plant_state: PlantState, master: SeedMaster) -> bool:
	pass

## 成熟後、death_grace_turnsを"超えて"（>、以下ではない）未収穫なら真。
## ちょうどdeath_grace_turns分の待機は生存（AC-007境界値: 「猶予ちょうど超過前は成功」）
## 🟡 core-systems.md L67の境界の解釈（「超えて」の等号扱い）を本タスクで明確化
static func is_dead(plant_state: PlantState, master: SeedMaster) -> bool:
	pass
```

## Test Strategy

- [ ] **正常系**: `advance_growth(plant_state, 1)`で`grown_turns`が1増えた新しい`PlantState`が返る（元の`plant_state.grown_turns`は変化しない）
- [ ] **正常系**: `advance_growth`は`slot_index`/`seed_id`/`is_matured`を変更せずそのまま引き継ぐ
- [ ] **正常系**: `grown_turns == master.maturity_turns`のとき`is_matured`が`true`を返す
- [ ] **異常系**: `grown_turns < master.maturity_turns`のとき`is_matured`が`false`を返す
- [ ] **境界値**: 成熟直後（`grown_turns == maturity_turns`、待機0ターン）は`is_dead`が`false`
- [ ] **境界値**: 待機ターン数が`death_grace_turns`ちょうど（`grown_turns == maturity_turns + death_grace_turns`）は`is_dead`が`false`（AC-007「猶予ちょうど＝超過1ターン前は成功」に対応）
- [ ] **境界値**: 待機ターン数が`death_grace_turns`を1超えた（`grown_turns == maturity_turns + death_grace_turns + 1`）は`is_dead`が`true`
- [ ] **異常系**: 未成熟（`is_matured`が偽）の`PlantState`は`is_dead`が常に`false`を返す

## Implementation Notes

- 参照すべき既存コード: `docs/design/atelier-alchemy-core/core-systems.md` L64, L66-67（`Harvest.advance_growth`/`is_matured`/`is_dead`の主要メソッド表）
- 実装のヒント: `advance_growth`は`PlantState.new(plant_state.slot_index, plant_state.seed_id, plant_state.grown_turns + turns, plant_state.is_matured)`のように新規オブジェクトを生成する（`005`タスクで実装した`PlantState`のコンストラクタを利用）
- 注意事項: `is_matured`の再計算（`advance_growth`後に`is_matured`フラグ自体を更新する処理）はこのタスクのスコープ外。`GameState`側（タスク015）が`advance_growth`の戻り値に対して`is_matured`を都度呼び出し、フラグを更新する設計とする

## Files

- 新規: `atelier/features/garden/logic/harvest.gd`（本タスクでは`advance_growth`/`is_matured`/`is_dead`の3メソッドのみ実装。`resolve_withering`/`harvest`はタスク011で追記）
- テスト: `atelier/tests/unit/features/garden/test_harvest.gd`（本タスクでは上記3メソッドのテストのみ追加。タスク011で同ファイルに追記）
