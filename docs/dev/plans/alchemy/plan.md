# Plan: alchemy

## Requirements Summary

「Atelier」（Godot 4.x + GDScript）のPhase 2機能実装として、調合（AlchemySystem、★ゲームの核心）を実装する。庭（garden）機能は既に`logic/`・`state/`・`resources/`・`GameState`統合まで完了済み（UIのみ別task）。プレイヤーが庭で仕込んだ`MaterialInstance`を調合台（投入枠）に投入し、レシピの事前選択・品質計算・特性発現判定・価値算出を経て`ProductInstance`を生成するサイクルを実装する。

**スコープに含む**: `features/alchemy/logic/`（`QualityCalculator`/`TraitActivation`/`ProductValueCalculator`）・`features/alchemy/state/`（`SlotState`）・`features/alchemy/resources/`（`RecipeMaster`）・`shared/entities/product_instance.gd`（`ProductInstance`）・`GameState.execute_alchemy`統合（投入検証〜在庫消費〜`pending_products`キュー追加まで）。
**スコープに含まない**: ギルド納品判定・ランクノルマ反映・指定合致ボーナス（GuildSystem、guild plan）、昇格試験での調合流用（RankSystem、rank plan）、`features/alchemy/ui/`（AlchemyScreen等、別task）、ショップでの触媒購入・レシピ解禁購入処理（WorkshopSystem、workshop plan）。

詳細: [requirements.md](requirements.md)（FR30件+NFR7件+CON10件） | [user-stories.md](user-stories.md)（US-001〜012） | [acceptance-criteria.md](acceptance-criteria.md)（AC-001〜015、テストチェックリスト46件）

## Design Overview

既存の確定設計（`docs/design/atelier-alchemy-core/core-systems.md` AlchemySystem節、`data-schema.md`）を正としてインターフェースを踏襲した。設計フェーズで判明した実装ギャップは、ヒアリングでユーザー確認済みの方針に従う:

- **`ProductInstance`を`shared/entities/`に新規追加**: `core-systems.md`のクラス図では配置未確定だったが、後続guild planが型として直接参照する必要があり、`MaterialInstance`と同じ配置判断（CON-003）とした
- **`GameState`に未納品キュー`pending_products: Array[ProductInstance]`を新設**: ギルド納品が別plan未実装のため、本plan完了時点では`execute_alchemy`成功時にここへ追加するだけに留める。後続guild planが消費する契約インターフェースとする（CON-004）
- **`traits_unlocked`は`GameState`内の暫定フィールド`_traits_unlocked`（初期値`false`）で保持**: 本来の権威は`RankMaster.traits_unlocked`だがRankSystem未実装のため、garden plan の `_garden_slot_count` パターンと同型の暫定置き場とする（CON-007）
- **`execute_alchemy`は単一アトミック呼び出しに限定**: `(recipe_id, material_instance_ids) -> Result`のみを実装し、UIのライブプレビュー用途の逐次的な`SlotState`操作API（投入/取消）は本plan外（UI非対応のため、CON-009）
- **`ProductValueCalculator`に`resolve_contribution_bonus`/`resolve_reward_bonus`を新設**: `core-systems.md`のクラス図には無いが、特性ボーナスの乗算合成をDomain層の純粋関数として切り出すことでFR-401（Functional Core純粋性）とNFR-401（テスト対象化）を満たす
- **GameBalanceの新規定数は具体値で確定**: 品質倍率テーブル・特性ボーナス6種・触媒基準品質等、garden plan の `QUALITY_UP_CHANCE := 0.3` と同水準で「仮値だが決め切る」方針（ユーザー承認済み）

### レイヤー構成

```
Presentation層  features/alchemy/ui/           対象外（本plan外、FR-405/CON-009）
       ↓ (未実装。UI plan側でsignal購読/execute_alchemy呼出を行う想定)
Application層   autoload/game_state.gd         execute_alchemy, load_alchemy_master_data
       ↓ (static call)
Domain層        features/alchemy/logic/        QualityCalculator, TraitActivation,
                                                ProductValueCalculator（副作用なし）
       ↓ (読み取り)
Infrastructure層 features/alchemy/resources/    RecipeMaster
                shared/loaders/master_data_loader.gd（recipes対応拡張）
                shared/entities/                Result, MaterialInstance（既存）, ProductInstance（新規）
                shared/constants/game_balance.gd（調合定数の追記）
                features/alchemy/state/         SlotState（GameStateからのみ参照、NFR-302）
```

## Task Dependency Graph

トポロジカル順（001が最も基盤、番号順に実行すればすべての依存が解決済みになる）:

```
001 ProductInstance型         （独立）
002 RecipeMaster型            （独立）
003 GameBalance調合定数        （独立）
004 SlotState型               （独立）
   └→ 005 QualityCalculator      [dep: 003]
   └→ 006 TraitActivation        [dep: 003]
   └→ 007 ProductValueCalculator [dep: 003]
002 └→ 008 recipe_healing_potion.tresフィクスチャ [dep: 002]
002,008 └→ 009 MasterDataLoader recipes拡張 [dep: 002,008]
001,002,003,004,009 └→ 010 GameState調合基盤（フィールド・load・get_state拡張・テストAPI） [dep: 001,002,003,004,009]
005,006,007,010 └→ 011 GameState.execute_alchemy [dep: 005,006,007,010]
```

実行順序の目安: **001〜004（並行可）→ 005〜007・008（並行可）→ 009 → 010 → 011**

## Cross-Plan Dependencies

- **`shared/entities/product_instance.gd`（`ProductInstance`）**: 本plan内で新規作成する。後続のguild plan（`DeliveryResolver.matches_order`/`resolve`）が型として直接参照する見込みが高く、フィールド構成（`recipe_id`/`quality_score`/`activated_traits`/`contribution`/`reward`）は破壊的変更しないよう留意する
- **`GameState.pending_products`**: 本plan完了時点では「調合成功時に追加するだけ」のキューとして実装する。後続のguild planがこのキューを消費して納品判定・ランクノルマ反映を行う想定だが、消費用のAPI（`dequeue`/`deliver`相当）は本plan側では追加しない（申し送り事項）
- **`shared/constants/game_balance.gd`**: 本plan（タスク003）で調合関連定数のみ追記する。庭関連の既存定数は変更しない。ファイル全体の所有権は主張しない
- **`_traits_unlocked`暫定フィールド**: 本plan完了時点では`GameState`内の手動設定フィールド（デフォルト`false`）に留まる。後続のrank planが`RankMaster.traits_unlocked`を実装した際、この暫定フィールドを正式な権威に置き換える想定
- **`MainScene`統合・AlchemyScreen UI**: 本plan外。garden plan と同様、別task・別planで行う
