# Plan: alchemy-ui

## Requirements Summary

Godot 4.x + GDScript製ゲーム「Atelier」の調合画面UI（`AlchemyScreen`、SCR-002、`atelier/features/alchemy/ui/`配下）を新規実装する。Functional Core（`features/alchemy/logic/`）・State（`features/alchemy/state/slot_state.gd`）・Resources（`features/alchemy/resources/recipe_master.gd`）・Application層（`GameState.execute_alchemy()`等）は実装済みであり、本PlanはUI層のみを対象とする。先行実装済みの`features/garden/ui/`（`GardenScreen`等）と同一の実装パターン・スコープ境界を踏襲する。

詳細: [requirements.md](requirements.md)（FR 20件+NFR 3件+CON 7件） | [user-stories.md](user-stories.md)（US-001〜US-404、Must Have 8件） | [acceptance-criteria.md](acceptance-criteria.md)（AC-001〜AC-015、テストチェックリスト45件）

**スコープに含む**: レシピ選択（`OptionButton`）・投入枠のクリック配置/取り消し・在庫一覧表示・ライブプレビュー（品質/特性/貢献度/報酬、`DeliveryResolver`まで含む）・調合実行・「ターンを終了する」「ショップ」プレースホルダーボタン・`GameState`への`recipe_masters`/`alchemy_slot_count`/`is_current_rank_traits_unlocked()`追加公開。

**スコープに含まない**: MainSceneへのタブ統合、統一`end_turn()`実装、ギルド納品画面（SCR-003）・ショップ画面（SCR-004）自体の実装、ドラッグ&ドロップ投入、特性の「あと1個」ヒント表示、RankHud（共通ヘッダー）、キーボード/スクリーンリーダー対応（いずれも別Planまたは意図的除外。詳細はrequirements.md CON-004〜CON-006、user-stories.mdエピック5参照）。

## Design Overview

Planサブエージェントの設計成果（下記）を正とする。

### コンポーネント構成

```
AlchemyScreen（ルート、Control）                       … 画面統合（タスク005）
├─ RecipeOptionButton（Godot標準OptionButtonを直接使用、専用ラッパーなし）
├─ SlotsContainer（GridContainer）
│   └─ AlchemySlotView × alchemy_slot_count            … タスク002
├─ MaterialInventoryList（在庫一覧、MaterialEntryRowを内部実装として含む）… タスク003
├─ AlchemyPreviewPanel（表示専用、パイプライン計算はAlchemyScreen側）    … タスク004
├─ ExecuteButton / EndTurnButton / ShopButton（Godot標準Button）
└─ ToastLabel（Label、gardenの`ToastLabel`パターン踏襲）
```

### レイヤー構成

```
Presentation層  features/alchemy/ui/           AlchemyScreen, AlchemySlotView,
                                                MaterialInventoryList, AlchemyPreviewPanel
       ↓ (signal購読 / メソッド呼出 / 読み取り専用でDomain層static funcを直接呼ぶ)
Application層   autoload/game_state.gd         execute_alchemy, deliver_pending_products,
                                                get_state()拡張, is_current_rank_traits_unlocked()（タスク001）
       ↓ (static call)
Domain層        features/alchemy/logic/        QualityCalculator, TraitActivation,
                features/guild/logic/           ProductValueCalculator, DeliveryResolver（副作用なし）
       ↓ (読み取り)
Infrastructure層 features/alchemy/resources/    RecipeMaster
                shared/entities/                MaterialInstance, ProductInstance, Result
                shared/theme/theme.gd           UiTheme（調合画面用色定数を本Planで追加）
```

### 設計判断の要点（詳細はPlanサブエージェント成果物を各タスクファイルのInterfaces/Implementation Notesに転記）

- **GameState拡張（タスク001）**: `get_state()`に`recipe_masters`（`seed_masters`と同型の浅い`duplicate()`）・`alchemy_slot_count`（`garden_slot_count`と同型のint値）を追加。加えて、ライブプレビュー計算に必須の`traits_unlocked`フラグを取得するため`GameState.is_current_rank_traits_unlocked() -> bool`を新規追加する（既存private`_get_current_rank_master_or_fallback()`を再利用。ヒアリングで確定事項として追加承認済み、requirements.md CON-001/CON-002・acceptance-criteria.md AC-015参照）。
- **二段階リフレッシュ**: `GameState.get_state()`を実際に呼ぶ重い`_refresh()`（`_ready()`時・`product_crafted`受信後のみ）と、ローカルキャッシュのみで完結する軽い`_on_preview_inputs_changed()`（投入枠操作・レシピ選択のたびに呼ぶ）を分離する。理由は`OptionButton`の選択状態保持と、投入枠操作自体が`GameState`側の実データを変更しないUIローカルな仮置きであるため。
- **AlchemySlotView**: `ClearButton`単一操作に集約（gardenの`PlantSlotView.harvest_button`踏襲）。空/投入済みの2状態。
- **MaterialInventoryList**: 「投入済み除外後」の配列を呼び出し元（AlchemyScreen）から受け取る契約とし、フィルタリング責務はAlchemyScreen側に置く（投入済みという概念がドメイン層に存在しないローカル一時状態のため）。
- **AlchemyPreviewPanel**: 純粋な表示専用（計算済みの値を`show_preview()`で受け取るのみ）。`QualityCalculator`→`TraitActivation`→`ProductValueCalculator`→`DeliveryResolver`の4段階パイプライン呼び出しは`AlchemyScreen`側のprivateメソッドが担う（複合度が高くテスト容易性のため末端コンポーネントに置かない）。
- **UiTheme拡張**: `COLOR_ALCHEMY_SLOT_EMPTY`/`COLOR_ALCHEMY_SLOT_FILLED`/`COLOR_RECIPE_UNSELECTED`/`COLOR_RECIPE_SELECTED`をgardenの`COLOR_SLOT_*`命名パターンに倣って追加（タスク002で実施）。

## Task Dependency Graph

トポロジカル順（001が最も基盤、番号順に実行すればすべての依存が解決済みになる）:

```
001 GameState拡張（recipe_masters/alchemy_slot_count/is_current_rank_traits_unlocked）  [dep: なし]
002 AlchemySlotView + UiTheme色定数拡張                                                [dep: なし]
003 MaterialInventoryList（MaterialEntryRow内包）                                       [dep: なし]
004 AlchemyPreviewPanel                                                                [dep: なし]
001,002,003,004 └→ 005 AlchemyScreen（画面統合）                                        [dep: 001,002,003,004]
```

実行順序の目安: **001〜004（並行可）→ 005**

## Cross-Plan Dependencies

- **`atelier/features/guild/logic/delivery_resolver.gd`への依存**: 本Planの`AlchemyScreen`（タスク005）はライブプレビュー計算のため、alchemy Feature以外である`guild` Featureの`DeliveryResolver.resolve()`を直接呼び出す。architecture.mdの「他Featureから参照してよいのは`logic/*.gd`と`resources/*.gd`のみ」ルールに合致するため許容されるが、guildプランが将来`DeliveryResolver`のシグネチャを変更する場合は本Planの`AlchemyScreen`実装も影響を受ける点に留意する。
- **`GameState`拡張の後方互換性**: タスク001で追加する`recipe_masters`/`alchemy_slot_count`は、gardenプランが追加した`seed_masters`/`garden_slot_count`と同じ`get_state()`拡張パターンであり、既存キーの削除・変更は行わない。`is_current_rank_traits_unlocked()`は新規publicメソッド追加のみで既存シグネチャに影響しない。
- **MainScene統合・end_turn()統一化**: 本Plan完了時点でも`atelier/scenes/main.tscn`はプレースホルダーのままであり、`AlchemyScreen`は単体の`.tscn`としてのみ存在する（gardenの`GardenScreen`と同様）。両画面をタブ統合し、庭の生育進行・日替わり指定調合物再抽選・ランク判定を含む統一`end_turn()`を実装するのは別Planの責務とする。
