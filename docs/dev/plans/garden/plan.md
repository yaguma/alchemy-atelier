# Plan: garden

## Requirements Summary

「Atelier」（Godot 4.x + GDScript）のPhase 2最初の機能実装として、庭（garden）機能を実装する。プレイヤーが手持ちの種を植え、ターン経過で生育させ、成熟後に収穫して品質・特性を持つ`MaterialInstance`を得るサイクルを、`features/garden/`配下のFunctional Core（`logic/`）+ ランタイム状態（`state/`）+ マスターデータ（`resources/`）+ `GameState`統合 + `GardenScreen`（単体テスト可能なUI）として実装する。

**スコープに含む**: 種植え・生育進行・枯死自動解決・収穫（品質確定・特性選択）・庭スロット4状態表示・降格時の資産維持。
**スコープに含まない**: `MainScene`へのタブ統合、ショップでの種指名買いの実購入ロジック、昇格試験中のガーデン遷移禁止制御（いずれも別task・別plan）。

詳細: [requirements.md](requirements.md)（FR 31件+NFR 8件+CON 8件） | [user-stories.md](user-stories.md)（US-001〜008） | [acceptance-criteria.md](acceptance-criteria.md)（AC-001〜014、テストチェックリスト46件）

## Design Overview

既存の確定設計（`docs/design/atelier-alchemy-core/core-systems.md` GardenSystem節、`data-schema.md`）を正としてインターフェースを踏襲した。設計フェーズで判明した実装ギャップは、ヒアリングでユーザー確認済みの方針に従う:

- **`Result`型の新規追加**（`shared/entities/result.gd`）: `Planting.plant`/`Harvest.harvest`の戻り値型として確定設計が前提とするが実体がリポジトリに存在しないため、本plan内で新規に土台を追加する（タスク001）
- **`Harvest.harvest`に`master: SeedMaster`引数を追加**（3引数→4引数）: 品質確定・特性選択・枯死判定が全て`SeedMaster`フィールド依存のため
- **`advance_turn_growth`は庭の全スロット対象**（成熟後の待機中も含む）: 品質上昇・枯死判定に成熟後もgrown_turnsの継続加算が必要なため
- **品質上昇判定は単発判定に単純化**（待機1ターン以上で1回だけ`QUALITY_UP_CHANCE`判定）: `Harvest.harvest`の乱数引数が単発floatであるため。バランス調整フェーズで再検証可能

### レイヤー構成

```
Presentation層  features/garden/ui/           GardenScreen, PlantSlotView, SeedInventoryList
       ↓ (signal購読 / メソッド呼出)
Application層   autoload/game_state.gd         plant_seed, harvest, advance_turn_growth
       ↓ (static call)
Domain層        features/garden/logic/         Planting, Harvest, TraitRoll（副作用なし）
       ↓ (読み取り)
Infrastructure層 features/garden/resources/     SeedMaster, MaterialMaster
                shared/loaders/master_data_loader.gd
                shared/entities/                Result, MaterialInstance
                shared/constants/game_balance.gd
```

## Task Dependency Graph

トポロジカル順（001が最も基盤、番号順に実行すればすべての依存が解決済みになる）:

```
001 result型
002 material_instance型          （001, 002は独立）
003 game_balance庭定数            （独立）
004 seed/material_master型        （独立）
005 plant_state/garden_state型    （独立）
   └→ 006 planting              [dep: 001,004,005]
   └→ 007 trait_roll            [dep: 004]
   └→ 008 harvest(生育/成熟/枯死判定) [dep: 004,005]
   └→ 009 庭マスターデータ.tres    [dep: 004]
      └→ 010 master_data_loader庭拡張 [dep: 004,009]
008,007,001,002,003 └→ 011 harvest(収穫/枯死解決) [dep: 001,002,003,007,008]
001,002,003,004,005,010 └→ 012 GameState庭基盤   [dep: 001,002,003,004,005,010]
006,012 └→ 013 GameState.plant_seed  [dep: 006,012]
011,012 └→ 014 GameState.harvest     [dep: 011,012]
008,011,012 └→ 015 GameState.advance_turn_growth [dep: 008,011,012]
003,004,005,008 └→ 016 PlantSlotView [dep: 003,004,005,008]
004 └→ 017 SeedInventoryList        [dep: 004]
013,014,015,016,017 └→ 018 GardenScreen [dep: 013,014,015,016,017]
```

実行順序の目安: **001〜005（並行可）→ 006〜010（並行可）→ 011 → 012 → 013〜015（並行可）→ 016〜017（並行可）→ 018**

## Cross-Plan Dependencies

- **他Featureとの共有インターフェース**: `shared/entities/material_instance.gd`（`MaterialInstance`）・`shared/entities/result.gd`（`Result`）は本plan内で新規作成するが、alchemy機能（次期plan想定）も`MaterialInstance`を消費する見込み（`AlchemySystem`の`QualityCalculator.calculate_quality(materials: Array[MaterialInstance])`）。`Result`型の命名・フィールド構成（`success`/`value`/`error_code`）はalchemy機能の`SlotState`関連ロジックでも再利用される可能性が高く、後続planで破壊的変更しないよう留意する
- **`shared/constants/game_balance.gd`**: 本plan（タスク003）で新規作成するが、庭以外の定数（調合投入枠数等）は他plan（alchemy等）が追記する前提。本plan内では庭関連定数のみ追加し、ファイル全体の所有権は主張しない
- **`GameState`**: 本plan完了時点で`plant_seed`/`harvest`/`advance_turn_growth`の3メソッドのみ追加。`end_turn()`（日替わり指定調合物再抽選・制限ターン判定を含む統合処理）はguild/rank機能側の別planが実装し、その中から本plan実装済みの`advance_turn_growth()`を呼び出す想定（CON-004）
- **`MainScene`統合・BootScene配線**: 本plan外。`GardenScreen`の`MainScene`へのタブ組み込み、`boot.gd`から`GameState.load_garden_master_data()`を呼ぶ配線は、いずれも別task（MainScene統合plan、または各機能plan完了後の統合task）で行う
