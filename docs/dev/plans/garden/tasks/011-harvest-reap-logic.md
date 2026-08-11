---
id: "011"
title: "Harvestの収穫・枯死解決ロジックを実装する"
status: done
priority: 2
dependencies: ["001", "002", "003", "007", "008"]
estimated_complexity: high
---

# Task: Harvestの収穫・枯死解決ロジックを実装する

## Goal

タスク008で実装した`features/garden/logic/harvest.gd`に、一括枯死解決`resolve_withering`と収穫本体`harvest`を追加する（FR-104〜108, FR-111）。品質確定（`base_quality`＋待機による品質上昇）・特性選択（`TraitRoll`呼び出し）・`MaterialInstance`生成までを一貫して行う。

## Interfaces

```gdscript
# features/garden/logic/harvest.gd（既存ファイルに追記）

## is_deadな株をgarden_state.plantsから除去した新しいGardenStateを返す（🔵 core-systems.md L65）
## ターン終了処理でadvance_growthの直後に必ず呼ぶ（FR-103）
static func resolve_withering(
	garden_state: GardenState,
	masters: Dictionary  # Dictionary[StringName, SeedMaster]
) -> GardenState:
	pass

## 成功時: Result.value に MaterialInstance を格納。失敗時: error_code="withered"（枯死）または"not_matured"（未成熟、防御的）
## 🔴 master引数を追加（core-systems.mdの表は3引数だが、品質確定・特性選択・枯死判定がSeedMasterのフィールドに
## 依存するため実装上4引数が必須と判断。ヒアリング結果で「master引数を追加」の方針をユーザー確認済み）
## 🔴 品質上昇判定は「待機1ターン以上で1回だけ判定」に単純化（ヒアリング結果でユーザー確認済み。
## 複数ターン分の独立試行ではない点に注意）
static func harvest(
	plant_state: PlantState,
	master: SeedMaster,
	rng_roll_quality: float,
	rng_roll_trait: float
) -> Result:
	pass
```

## Test Strategy

- [ ] **正常系**: 待機0ターン（成熟直後）で収穫すると`Result.success == true`かつ`value.quality_score == master.base_quality`
- [ ] **正常系**: 待機1ターン以上かつ`rng_roll_quality < GameBalance.QUALITY_UP_CHANCE`で収穫すると品質が`base_quality + 1`になる（FR-107, AC-006）
- [ ] **異常系**: 待機1ターン以上でも`rng_roll_quality >= GameBalance.QUALITY_UP_CHANCE`のときは品質が上昇しない（`base_quality`のまま）
- [ ] **境界値**: `base_quality`が既に`GameBalance.QUALITY_SCORE_MAX`（5）の状態で品質上昇判定に成功しても`quality_score`は5を超えない（クランプされる）
- [ ] **正常系**: 収穫成功時の`MaterialInstance.material_id`が`master.produces_material_id`と一致し、`trait_tags`に`TraitRoll.roll_trait(master, rng_roll_trait)`の結果が1件含まれる
- [ ] **異常系**: `is_dead`が真の`plant_state`に対し`harvest`を呼ぶと`Result.success == false`かつ`error_code == &"withered"`、`MaterialInstance`は生成されない（FR-108, AC-007）
- [ ] **正常系（resolve_withering）**: 枯死株を含む`garden_state`に対し`resolve_withering`を呼ぶと、枯死株のみが`plants`から除去され生存株は残る
- [ ] **正常系（resolve_withering）**: 枯死株が存在しない`garden_state`に対し`resolve_withering`を呼んでも`plants`の内容は変化しない
- [ ] **異常系（resolve_withering）**: `plants`が空配列の`garden_state`でもエラーにならず空配列を返す

## Implementation Notes

- 参照すべき既存コード: `docs/design/atelier-alchemy-core/core-systems.md` L65, L68, L73-80（`resolve_withering`/`harvest`の主要メソッド表、品質確定ロジックの方針）
- 実装のヒント: `instance_id`の採番はこのタスクでは行わない（呼び出し元＝`GameState`、タスク014が採番して`harvest`実行後に`MaterialInstance.instance_id`を設定し直すか、`harvest`に採番済みIDを追加引数で渡す設計は本タスクのスコープ外とし、`harvest`内部では固定のプレースホルダー値または空文字列を設定し、`GameState`側で上書きする実装を許容する。実装時にどちらの方式を取るかはコードレビューで確認する）
- 注意事項: `logic/`配下のため`RngService`・`GameState`を直接参照しないこと（乱数は`rng_roll_quality`/`rng_roll_trait`として引数で受け取る、FR-402）。`resolve_withering`の`masters`引数の型は`Dictionary[StringName, SeedMaster]`とし、該当する`SeedMaster`が見つからない`seed_id`のスロットは安全側に倒して除去しない（生存として扱う）

## Files

- 変更: `atelier/features/garden/logic/harvest.gd`（タスク008で作成したファイルに`resolve_withering`/`harvest`を追記）
- 変更: `atelier/tests/unit/features/garden/test_harvest.gd`（タスク008のテストファイルに追記）
