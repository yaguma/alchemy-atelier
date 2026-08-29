# daily-orders 要件定義書

## 概要

日替わり指定調合物（以下「指定依頼」）の**抽選・更新・表示**を本番コードパスに実装する。

現状、`DailyOrderMaster`（`atelier/features/guild/resources/daily_order_master.gd`）のスキーマと、
納品判定側の消費経路（`DeliveryResolver.matches_order()` / `DeliveryResolver.resolve()` /
`GameState.resolve_daily_order_for_delivery()`）は**実装・確定済み**である。
しかし `GameState._current_daily_order` への代入経路はテスト専用API
（`GameState._set_current_daily_order_for_test()`）のみで、本番コードからは一切存在しない。
また `res://data/daily_orders/` ディレクトリ自体が未作成（実データ0件）で、
`MasterDataLoader` も `&"daily_orders"` カテゴリに未対応である。

guild Plan の `docs/dev/plans/guild/requirements.md` FR-405 が
「実データ作成と毎ターン終了時の再抽選ロジックは別planの対象」と明示しており、本Planがその別planに該当する。

本Planのスコープは以下の4点。

1. `res://data/daily_orders/*.tres` 実データの新規作成（バランス数値は仮値）
2. `MasterDataLoader` への `&"daily_orders"` カテゴリ追加
3. 抽選ロジック（Domain層の純粋関数）と、その適用（初回ロード時・毎ターン終了時）
4. 現在の指定依頼をプレイヤーへ提示するUI表示

## 関連文書

- **ユーザーストーリー**: [user-stories.md](user-stories.md)
- **受入基準**: [acceptance-criteria.md](acceptance-criteria.md)
- **設計・タスク**: [plan.md](plan.md)
- **先行Plan（消費側の確定仕様）**: [../guild/requirements.md](../guild/requirements.md)
- **直近の同型実装（RankMaster実データ整備）**: [../main-scene-integration/](../main-scene-integration/)
- **設計文書**: [../../../design/atelier-alchemy-core/core-systems.md](../../../design/atelier-alchemy-core/core-systems.md), [../../../design/atelier-alchemy-core/data-schema.md](../../../design/atelier-alchemy-core/data-schema.md)

## 用語集

| 用語 | 定義 |
|-----|------|
| 指定依頼（日替わり指定調合物） | そのターンにギルドが指定する調合物・特性。合致した調合物を納品すると貢献度・報酬が倍率ボーナスを受ける |
| `DailyOrderMaster` | 指定依頼1件のマスターデータ型。`id` / `condition_type` / `target_recipe_id` / `target_trait` / `match_bonus_multiplier` を持つ（確定済み・変更不可） |
| `condition_type` | 指定依頼の条件種別。`"item"`（対象レシピ一致）または `"trait"`（対象特性の発現） |
| 抽選プール | 抽選対象となる `DailyOrderMaster` の集合。本Planでは「現在の解禁状況で達成可能なもの」に絞り込む |
| 解禁済みレシピ | `GameState._unlocked_recipe_ids` に含まれるレシピID。工房強化（`recipe_unlock`）で増える |
| 特性解禁 | `RankMaster.traits_unlocked`。false のランク（Gランク）では特性が一切発現しない |
| 指定依頼なし | `_current_daily_order == null` の状態。ボーナス倍率1.0倍で納品が正常に成立する |
| 試験中 | `GameState._in_exam == true`。`resolve_daily_order_for_delivery()` が常に `null` を返す |
| `RngService` | 乱数を一元管理するAutoload。Domain層は乱数を自己生成せず、払い出された値を引数で受け取る |

## 機能要件（EARS記法）

**【信頼性レベル凡例】**:
- 🔵 PRD・設計文書・ヒアリングに基づく確実な要件
- 🟡 妥当な推測による要件
- 🔴 AI推論補完による要件（要確認）

### 普遍要件（SHALL）

- **FR-001**: システムは `res://data/daily_orders/` 配下に `DailyOrderMaster` の実データ（`.tres`）を1件以上保持しなければならない 🔵 *[ヒアリング「実データ0件・本Planで新規作成」]*
  - 関連: US-001, AC-001
- **FR-002**: システムは `MasterDataLoader.load_all(&"daily_orders")` で `res://data/daily_orders/` 配下の全 `.tres` をロードできなければならない 🔵 *[ヒアリング「`&"daily_orders"`は未対応」／`master_data_loader.gd:51-77` の `&"ranks"` 追加と同型]*
  - 関連: US-001, AC-001
- **FR-003**: システムは `MasterDataLoader` の `&"daily_orders"` カテゴリにおいて、`DailyOrderMaster` 型以外のリソースを結果に含めてはならない 🔵 *[`master_data_loader.gd:66-77` `_is_allowed_type()` の既存契約を踏襲]*
  - 関連: AC-001
- **FR-004**: システムは抽選プールの絞り込みを、副作用・乱数生成・`GameState` 参照を持たない純粋関数（`features/guild/logic/` 配下の `static func`）として実装しなければならない 🔵 *[`.claude/rules/architecture.md`「Functional Core, Imperative Shell」／`delivery_resolver.gd:1-2` の既存方針]*
  - 関連: US-002, AC-002
- **FR-005**: システムは抽選プールを、現在の解禁状況で達成可能な `DailyOrderMaster` のみに絞り込まなければならない 🔵 *[ヒアリング回答1]*
  - `condition_type == "item"` の場合、`target_recipe_id` が `GameState._unlocked_recipe_ids` に含まれるもののみ
  - `condition_type == "trait"` の場合、現在ランクの `RankMaster.traits_unlocked == true` であるもののみ
  - 関連: US-002, AC-002, AC-003
- **FR-006**: システムは抽選ロジックにおいて、乱数を `RngService` から払い出された値として引数で受け取らなければならない（Domain層で乱数を自己生成しない） 🔵 *[`.claude/rules/tdd-implementation.md`「Domain層で乱数を自己生成しない」]*
  - 関連: US-002, AC-002
- **FR-007**: システムは現在の指定依頼をプレイヤーが確認できるUI要素として表示しなければならない 🔵 *[ヒアリング回答2「UI表示は本Planのスコープに含める」]*
  - 表示内容: 条件種別に応じた対象（レシピ名 or 特性名）と、合致時のボーナス倍率
  - 関連: US-005, US-006, AC-006
- **FR-008**: システムは `GameState` に指定依頼マスターデータのロード関数（`load_daily_order_master_data()` 相当）を追加し、`MainScene._enter_tree()` から既存4関数と同じ経路で呼び出さなければならない 🔵 *[ヒアリング回答5／`scenes/main.gd:39-43` の既存パターン]*
  - 関連: US-001, AC-004

### イベント駆動要件（WHEN-THEN）

- **FR-101**: 指定依頼マスターデータの初回ロードが完了した場合、システムは指定依頼を1回抽選し `_current_daily_order` に設定しなければならない 🔵 *[ヒアリング回答5「初回ターンから指定依頼が機能するように」]*
  - 関連: US-001, AC-004
- **FR-102**: `GameState.advance_turn_growth()` が実行された場合、システムはその直後に指定依頼を再抽選し `_current_daily_order` を更新しなければならない 🔵 *[ヒアリング「毎ターン指定調合物を抽選・更新する本番ロジック」／guild Plan FR-405／フック先確定（`advance_turn_growth()`は`_current_turn`を実際にインクリメントする唯一の関数、`game_state_garden_delegate.gd:138`）]*
  - 関連: US-002, AC-005
- **FR-103**: 抽選プールが空（該当する `DailyOrderMaster` が1件もない）の場合、システムは `_current_daily_order` を `null` に設定しなければならない 🔵 *[ヒアリング回答4「そのターンは指定依頼なし。フォールバック用の特別なマスターエントリは用意しない」]*
  - 関連: US-003, US-004, US-007, AC-003
- **FR-104**: 指定依頼が更新された場合、システムはUIが追随できるよう状態変更を通知しなければならない 🟡 *[`.claude/rules/state-management.md`「UIは`signal`購読で追随する」／既存 `turn_growth_advanced` 等と同型]*
  - 🔴 専用signalを新設するか、既存の `turn_growth_advanced` / `phase_changed` 購読による `_refresh()` で足りるかは **Phase 2で確定**
  - 関連: US-005, AC-006
- **FR-105**: マスターデータのロードで `DailyOrderMaster.id` の重複を検出した場合、システムは `push_error()` で警告しなければならない 🟡 *[`game_state_rank_delegate.gd:25-27` の `&"ranks"` ロードと同型]*
  - 関連: AC-001, AC-007

### 状態駆動要件（WHERE）

- **FR-201**: 試験中（`_in_exam == true`）にある間、システムは `resolve_daily_order_for_delivery()` から常に `null` を返し続けなければならない 🔵 *[`game_state.gd:292-293` の既存確定契約。本Planで変更しない]*
  - 関連: US-009, AC-008
- **FR-202**: 抽選プールが空である間、システムは指定依頼なし（`null`）を「試験中は`null`」と同型の正常な状態として扱い、納品処理をエラーにしてはならない 🔵 *[ヒアリング回答4／`delivery_resolver.gd:12-14` が `daily_order == null` を正常系として処理済み]*
  - 関連: US-004, US-007, AC-003, AC-009
- **FR-203**: 現在ランクで特性が未解禁（`RankMaster.traits_unlocked == false`、Gランク相当）である間、システムは `condition_type == "trait"` の指定依頼を抽選してはならない 🔵 *[ヒアリング回答1／`rank_master.gd:11`「Gランクはfalse固定」]*
  - 関連: US-003, AC-003

### 任意要件（MAY）

- **FR-301**: システムは `condition_type` が `"item"` と `"trait"` のどちらを抽選するかに重み付けを設けてはならない 🔵 *[ヒアリング回答「絞り込み後プール全体から均一抽選」。item/traitを区別せず、絞り込み済みプール全体から等確率で1件選出する]*
  - 関連: US-002, AC-002
- **FR-302**: システムは試験中のターン進行（`advance_exam_turn()`）では指定依頼の再抽選を行ってはならない 🔵 *[ヒアリング回答「再抽選しない」。`resolve_daily_order_for_delivery()`が試験中は常に`null`を返す契約のため実利用への影響はなく、無駄な処理を避ける]*
  - 関連: US-009, AC-008
- **FR-303**: システムは同一の指定依頼が連続ターンで再選出されることを許してもよい 🟡 *[明示的な連続回避要求がヒアリングに存在しない。実装を単純に保つ判断]*
  - 関連: US-002, AC-005
- **FR-304**: システムは指定依頼の表示に、達成状況（現在の投入内容が条件に合致しているか）を併記してもよい 🟡 *[`alchemy_screen.gd:212-220` の `result.order_matched` が既にプレビューへ渡されており、既存機構で実現可能]*
  - 関連: US-008, AC-006

### 禁止要件（MUST NOT）

- **FR-401**: システムは `DailyOrderMaster` の既存スキーマ（`id` / `condition_type` / `target_recipe_id` / `target_trait` / `match_bonus_multiplier` / `clone()`）を変更してはならない 🔵 *[ヒアリング「既にスキーマ確定済み」]*
  - 関連: AC-010
- **FR-402**: システムは `GameState.resolve_daily_order_for_delivery()` の既存契約（試験中は`null`、それ以外は`_current_daily_order`）を変更してはならない 🔵 *[ヒアリング「既に実装済みで契約が確定」]*
  - 関連: AC-008, AC-010
- **FR-403**: システムは `DeliveryResolver.matches_order()` / `DeliveryResolver.resolve()` の判定・算出ロジックを変更してはならない 🔵 *[guild Planで確定済み。本Planは抽選側のみを担う]*
  - 関連: AC-010
- **FR-404**: システムは抽選ロジック（`logic/` 配下の純粋関数）から `GameState` を参照してはならない 🔵 *[`.claude/rules/architecture.md`「Domain層はApplication・Presentationを参照しない」]*
  - 関連: US-002, AC-002
- **FR-405**: システムは常に達成可能なフォールバック用の特別な `DailyOrderMaster` エントリを用意してはならない 🔵 *[ヒアリング回答4で明示的に否定]*
  - 関連: US-003, US-004, AC-003
- **FR-406**: システムは `_current_daily_order` を `get_state()` やUI層へ内部参照のまま露出してはならない（`clone()` を経由すること） 🔵 *[`game_state.gd:127-129` の既存実装／`.claude/rules/state-management.md` 防御的コピー要件]*
  - 関連: US-004, AC-009
- **FR-407**: システムは `match_bonus_multiplier` の倍率を `DeliveryResolver.resolve()` 以外の箇所で乗算してはならない 🔵 *[`delivery_resolver.gd:32`「この倍率を掛けるのは本関数のみ。二重乗算バグ防止」]*
  - 関連: US-006, AC-006

## 非機能要件

### パフォーマンス

- **NFR-001**: 抽選処理は1ターンに1回のイベント駆動でのみ実行し、`_process()` 内で毎フレーム実行してはならない 🔵 *[`.claude/rules/performance.md`「`_process()`内での重い処理禁止」]*
- **NFR-002**: マスターデータのロード（ディスクI/O）はゲーム起動時の初回1回のみとし、毎ターンの再抽選ではロード済みのメモリ上のプールを再利用しなければならない 🟡 *[`load_rank_master_data()` と同型。毎ターンの `DirAccess` 走査は不要なI/O]*

### 保守性

- **NFR-101**: 抽選プールの絞り込み条件（解禁レシピ・特性解禁）の判定式は1箇所にのみ実装し、UI表示側とApplication層で再実装してはならない 🔵 *[`.claude/rules/architecture.md`「検証責務のレイヤー配置原則」／`game_state.gd:256-262` の既存方針]*
- **NFR-102**: `match_bonus_multiplier` 等のバランス数値は `GameBalance`（`shared/constants/game_balance.gd`）に定数として定義し、`.tres` およびコードへの直書きをしてはならない 🔵 *[`daily_order_master.gd:11-14` の既定値が既に `GameBalance.DAILY_ORDER_MATCH_BONUS_MULTIPLIER` を参照済み／`.claude/rules/coding-style.md`]*
- **NFR-103**: 抽選ロジックの純粋関数は、`RngService` をモックせずに乱数値を引数で直接渡す形でユニットテスト可能でなければならない 🔵 *[`.claude/rules/tdd-implementation.md`「Domain層は乱数値を引数で受け取るため`mock()`は基本不要」]*

### ユーザビリティ

- **NFR-201**: 指定依頼の表示は、プレイヤーが調合の素材投入を決める前に確認できる位置になければならない 🟡 *[ヒアリング回答2「AlchemyScreenのプレビューパネル周辺が有力」]*
  - 🔴 具体的な配置・文言は **Phase 2で確定**
- **NFR-202**: 指定依頼なし（`null`）の状態でも、UIは空欄・エラー表示ではなく「指定依頼なし」と読み取れる表示をしなければならない 🟡 *[FR-202「正常な状態として扱う」からの帰結。既存 `AlchemyPreviewPanel.show_empty()` と同型の考え方]*

### 信頼性

- **NFR-301**: `res://data/daily_orders/` が空、またはロードに失敗した場合でも、システムはクラッシュせず「指定依頼なし」の安全側状態で動作を継続しなければならない 🔵 *[`game_state_rank_delegate.gd:34-40`「push_errorのみでクラッシュさせず安全側の状態に留まる」と同型]*
- **NFR-302**: 不正な `DailyOrderMaster`（`condition_type` が未知値、`target_recipe_id`/`target_trait` が空文字）は抽選プールから除外し、クラッシュさせてはならない 🟡 *[`delivery_resolver.gd:16-28` が既に未知値・空文字を非合致として安全に扱っている。抽選側でも同方針を採る]*

## 制約

- **CON-001**: `DailyOrderMaster`（`atelier/features/guild/resources/daily_order_master.gd`）は変更不可の確定済みスキーマである 🔵 *[ヒアリング「既にスキーマ確定済み」／FR-401]*
- **CON-002**: `GameState.resolve_daily_order_for_delivery()`（`game_state.gd:292-293`）は変更不可の確定済み契約である 🔵 *[ヒアリング「既に実装済み」／FR-402]*
- **CON-003**: `DeliveryResolver`（`atelier/features/guild/logic/delivery_resolver.gd`）は guild Plan で確定済みであり、本Planでは変更しない 🔵 *[guild Plan FR-101〜FR-104, FR-403]*
- **CON-004**: バランス数値（`match_bonus_multiplier`、`condition_type` の抽選比率等）は本Planでは**仮値**とする。正式値はバランス設計の別Planで確定する 🔵 *[ヒアリング回答3]*
- **CON-005**: 実装言語は GDScript（静的型付け徹底）、エンジンは Godot 4.7、テストは GdUnit4 とする 🔵 *[context.md Tech Stack]*
- **CON-006**: `.tres` 実データは Godot エディタを使わずテキストで手書きする（`[gd_resource type="Resource" script_class="DailyOrderMaster" ...]` 形式） 🔵 *[main-scene-integration Plan の `data/ranks/*.tres` 実績]*
- **CON-007**: 抽選ロジックは `features/guild/logic/` 配下に配置し、`ui/`・`state/` から他Featureの内部を直接参照しない 🔵 *[`.claude/rules/architecture.md` レイヤー間依存ルール]*
- **CON-008**: テストファイルは `atelier/tests/unit/` および `atelier/tests/integration/` に配置し、`features/` 配下には置かない 🔵 *[`.claude/rules/testing.md`]*
- **CON-009**: 抽選対象のレシピ解禁状況は `RankMaster` ではなく `GameState._unlocked_recipe_ids`（工房強化 `recipe_unlock` で増加）から取得する 🔵 *[`game_state.gd:43`／`game_state_workshop_delegate.gd:76` を実コード確認済み。ヒアリング文中の「`RankMaster.unlocked_recipe_ids`」は実在せず、`RankMaster` にあるのは `traits_unlocked` のみ]*
- **CON-010**: 毎ターン終了時の再抽選フック先は `GameState.advance_turn_growth()` の直後とする 🔵 *[ヒアリング回答／FR-102]*
- **CON-011**: UI表示の具体的な配置・文言は本要件定義では未確定であり、Phase 2 の設計で確定させる 🔴 *[ヒアリング「未解決の設計論点」／FR-007, NFR-201]*
- **CON-012**: `condition_type` の `"item"` / `"trait"` 抽選比率は設けず、絞り込み後プール全体から均一抽選とする 🔵 *[ヒアリング回答／FR-301]*

## 信頼性レベルサマリー

| 分類 | 🔵 | 🟡 | 🔴 | 小計 |
|-----|----|----|----|------|
| 機能要件（FR） | 23 | 4 | 0 | 27 |
| 非機能要件（NFR） | 5 | 4 | 0 | 9 |
| 制約（CON） | 11 | 0 | 1 | 12 |
| **合計** | **39** | **8** | **1** | **48** |

- 🔵 青信号: 39件
- 🟡 黄信号: 8件
- 🔴 赤信号: 1件（CON-011）

> ヒアリング（AskUserQuestion）により再抽選フック先（CON-010, FR-102）・試験中再抽選の要否
> （FR-302）・抽選比率（CON-012, FR-301）はすべて確定した。残る未確定はUI表示の具体的な配置・
> 文言のみ（CON-011, NFR-201, FR-104）。Phase 2 の設計で確定させる。
