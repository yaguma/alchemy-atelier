# alchemy-ui 要件定義書

## 概要

Godot 4.x + GDScript製ゲーム「Atelier」の調合画面UI（`AlchemyScreen`、SCR-002、`atelier/features/alchemy/ui/`配下）を新規実装する。Functional Core（`features/alchemy/logic/`: `QualityCalculator` / `TraitActivation` / `ProductValueCalculator`、`features/alchemy/state/`: `SlotState`、`features/alchemy/resources/`: `RecipeMaster`）とApplication層（`GameState.execute_alchemy()` 等、`autoload/game_state_alchemy_delegate.gd`）は実装済みであり、本Planはそれらを呼び出すUI層（`ui/`）のみを対象とする。

実装パターンは先行実装済みの`features/garden/ui/`（`GardenScreen`等）を踏襲する。`AlchemyScreen`単体の画面内で完結する機能（レシピ選択・投入枠管理・在庫一覧・ライブプレビュー・調合実行・ショップ/ターン終了のプレースホルダーボタン）のみを扱い、MainSceneへのタブ統合・ギルド納品画面（SCR-003）・ショップ画面（SCR-004）自体は本Planのスコープ外とする。

## 関連文書

- **ユーザーストーリー**: [user-stories.md](user-stories.md)
- **受入基準**: [acceptance-criteria.md](acceptance-criteria.md)
- **設計・タスク**: plan.md（未作成）

## 用語集

| 用語 | 定義 |
|-----|------|
| `AlchemyScreen` | 本Planで新規実装する調合画面のルート`Control`ノード（SCR-002） |
| 投入枠 | 調合に使う素材を仮置きするスロット。上限数は`GameState._alchemy_slot_count`（内部管理） |
| `SlotState` | 投入枠の選択レシピ・投入素材・実行可否判定を保持するランタイム状態型（`features/alchemy/state/slot_state.gd`） |
| `MaterialInstance` | 庭で収穫された個体別の素材インスタンス（`shared/entities/material_instance.gd`） |
| `ProductInstance` | 調合により生成された成果物インスタンス（`shared/entities/product_instance.gd`） |
| `RecipeMaster` | レシピのマスターデータ型（`features/alchemy/resources/recipe_master.gd`） |
| ライブプレビュー | 投入枠の内容から品質・発現特性・貢献度・報酬見込みを同期計算し画面に表示する機能 |
| `DeliveryResolver` | 指定合致ボーナスを含む最終貢献度・報酬を算出する純粋関数（`features/guild/logic/delivery_resolver.gd`） |
| `DailyOrderMaster` | 当日の指定調合物ノルマを表すマスターデータ（`GameState.get_state().current_daily_order`） |
| `execute_alchemy()` | 調合実行API。`GameState.execute_alchemy(recipe_id, material_instance_ids) -> Result` |
| `deliver_pending_products()` | 未納品成果物を一括決算するAPI。`GameState.deliver_pending_products() -> Result` |
| トースト | 一時的なテキストフィードバック表示。gardenの`ToastLabel`パターンを踏襲する |
| プレースホルダーボタン | 本Planでは押下時に単一APIコール/signal発行のみ行い、画面遷移や統合ロジックは実装しないボタン（「ショップ」「ターンを終了する」） |

## 機能要件（EARS記法）

**【信頼性レベル凡例】**:
- 🔵 PRD・設計文書・ヒアリングに基づく確実な要件
- 🟡 妥当な推測による要件
- 🔴 AI推論補完による要件（要確認）

### 普遍要件（SHALL）

- **FR-001**: `AlchemyScreen`は`Control`を継承したシーンとして実装し、`GameState`のsignalを`_ready()`で購読し`_exit_tree()`で明示的に`disconnect()`しなければならない 🔵 *[.claude/rules/ui-components.md, gardenプラン踏襲方針]*
  - 関連: US-001, AC-014
- **FR-002**: システムは`GameState.get_state().unlocked_recipe_ids`に含まれるレシピの一覧を表示しなければならない 🔵 *[ui-design/screens/alchemy.md, ヒアリング「GameStateの実際のAPI」節]*
  - 関連: US-003, AC-001
- **FR-003**: システムは`GameState.get_state().inventory`の素材一覧を表示しなければならない 🔵 *[ui-design/screens/alchemy.md]*
  - 関連: US-001, AC-002
- **FR-004**: システムは投入枠（上限数分）を表示し、各枠の空/投入済み状態を判別可能に表示しなければならない 🔵 *[core-systems.md AlchemySystem節]*
  - 関連: US-001, AC-003
- **FR-005**: システムは色を`UiTheme`（`shared/theme/theme.gd`）定数経由で参照しなければならず、色のハードコーディングを行ってはならない 🔵 *[.claude/rules/design-guide.md, .claude/rules/coding-style.md]*
  - 関連: US-001, AC-003
- **FR-006**: システムはライブプレビュー（品質・発現特性・貢献度見込み・報酬見込み）を表示しなければならない 🔵 *[ヒアリング スコープ確定事項6, core-systems.md]*
  - 関連: US-101, AC-007

### イベント駆動要件（WHEN-THEN）

- **FR-101**: ユーザーが在庫の素材カードをクリックした場合、システムはその素材を空いている投入枠へ自動配置しなければならない 🔵 *[ヒアリング スコープ確定事項2]*
  - 関連: US-001, AC-004
- **FR-102**: ユーザーが投入済みの枠（またはクリア操作）をクリックした場合、システムはその素材を在庫へ戻さなければならない 🔵 *[ヒアリング スコープ確定事項2]*
  - 関連: US-002, AC-005
- **FR-103**: ユーザーがレシピをクリックした場合、システムは選択中レシピを更新し投入枠表示を再構築しなければならない 🟡 *[ui-design/screens/alchemy.md ワイヤーフレームからの妥当な推測]*
  - 関連: US-003, AC-006
- **FR-104**: 投入枠の内容またはレシピ選択が変化するたびに、システムはライブプレビューを再計算しなければならない 🔵 *[本タスク指示（再計算タイミング「投入変更ごと」）, core-systems.md]*
  - 関連: US-101, AC-007
- **FR-105**: ユーザーが「調合実行」ボタンを押下した場合、システムは`GameState.execute_alchemy(recipe_id, material_instance_ids)`を呼び出さなければならない 🔵 *[ヒアリング スコープ確定事項3]*
  - 関連: US-201, AC-008
- **FR-106**: `GameState`が`product_crafted`シグナルを発行した場合、システムは調合完了のトーストを表示し、投入枠を空にリセットし、在庫を再取得しなければならない 🔵 *[ヒアリング スコープ確定事項3]*
  - 関連: US-201, AC-008
- **FR-107**: `GameState`が`execute_alchemy_failed`シグナルを発行した場合、システムはエラーコード（`unknown_recipe_id` / `recipe_not_unlocked` / `material_not_owned` / `duplicate_material_in_slot` / `slot_execution_invalid`）に応じたメッセージのトーストを表示しなければならない 🔵 *[ヒアリング「GameStateの実際のAPI」節, gardenの`plant_seed_failed`/`harvest_failed`トーストパターン]*
  - 関連: US-202, AC-009
- **FR-108**: ユーザーが「ターンを終了する」ボタンを押下した場合、システムは`GameState.deliver_pending_products()`を呼び出さなければならない 🔵 *[ヒアリング スコープ確定事項4]*
  - 関連: US-301, AC-011
- **FR-109**: `GameState`が`delivered`シグナルを発行した場合、システムは納品完了のトーストを表示しなければならない 🟡 *[gardenのトーストパターンからの妥当な推測。ヒアリングはAPI呼び出しのみ明記しフィードバック内容は未確定]*
  - 関連: US-301, AC-011
- **FR-110**: ユーザーが「ショップ」ボタンを押下した場合、システムは`shop_requested`シグナルを発行しなければならない 🔵 *[ヒアリング スコープ確定事項5、`GardenScreen.shop_requested`と同一パターン]*
  - 関連: US-302, AC-012

### 状態駆動要件（WHERE）

- **FR-201**: レシピが未選択である間（`SlotState.selected_recipe_id == &""`）、システムは「調合実行」ボタンを無効化しなければならない 🔵 *[features/alchemy/state/slot_state.gd `can_execute()`実装]*
  - 関連: US-203, AC-010
- **FR-202**: `SlotState.can_execute()`が`false`を返す間（投入0個、または投入枠上限超過に相当する状態を含む）、システムは「調合実行」ボタンを無効化しなければならない 🔵 *[features/alchemy/state/slot_state.gd `can_execute()`実装]*
  - 関連: US-203, AC-010
- **FR-203**: 投入枠が全て埋まっている間、システムは新規の在庫クリックによる投入操作を無効化した状態を維持しなければならない 🟡 *[UIとして必要になる妥当な推測。ヒアリングに明示なし]*
  - 関連: US-004, AC-010

### 任意要件（MAY）

- **FR-301**: システムは発現済み特性をアイコン・タグ等の視覚要素で表示してもよい 🟡 *[ui-design/overview.md 共通コンポーネント方針からの推測]*
  - 関連: US-102, AC-007
- **FR-302**: システムは在庫カードクリックによる投入枠への配置時に、軽い視覚フィードバック（`Tween`アニメーション等）を伴ってもよい 🟡 *[.claude/rules/ui-components.mdのアニメーション節からの推測]*
  - 関連: US-303

### 禁止要件（MUST NOT）

- **FR-401**: システムは投入操作としてドラッグ&ドロップを実装してはならない 🔵 *[ヒアリング スコープ確定事項2]*
  - 関連: US-401, AC-013
- **FR-402**: システムは「調合実行」ボタン押下時に`GameState.deliver_pending_products()`を呼び出してはならない 🔵 *[ヒアリング スコープ確定事項3]*
  - 関連: US-403, AC-013
- **FR-403**: システムは調合実行成功後にギルド納品画面等への自動遷移を行ってはならない 🔵 *[ヒアリング スコープ確定事項3]*
  - 関連: US-403, AC-013
- **FR-404**: システムは未発現特性の「あと1個で発現」ヒント表示を行ってはならない 🔵 *[ヒアリング スコープ確定事項7]*
  - 関連: US-402, AC-013
- **FR-405**: システムはMainSceneへのタブ統合・`main.tscn`へのシーン遷移配線を実装してはならない 🔵 *[ヒアリング スコープ確定事項1・8]*
  - 関連: US-404, AC-013

## 非機能要件

### パフォーマンス

- **NFR-001**: ライブプレビューの再計算（`QualityCalculator`→`TraitActivation`→`ProductValueCalculator`→`DeliveryResolver`の一連の同期呼び出し）は、投入枠変更操作から画面反映まで体感遅延なく（目安1フレーム以内）完了しなければならない 🟡 *[.claude/rules/performance.md 一般原則からの推測。具体的な数値目標のヒアリングなし]*

### セキュリティ・整合性

- **NFR-101**: システムはUI層の先出し判定（ボタン活性制御等）を実行結果の保証として信頼してはならず、状態変更は既存の`GameState.execute_alchemy()`（内部で`SlotState.can_execute()`を実行直前に再評価する）経由でのみ行い、UI層がこの検証をバイパスする独自の状態変更経路を持ってはならない 🔵 *[.claude/rules/state-management.md, docs/design/atelier-alchemy-core/architecture.md「検証責務のレイヤー配置原則」]*

### ユーザビリティ

- **NFR-201**: システムは全UI要素を日本語で表示しなければならない 🔵 *[CLAUDE.md プロジェクト全体方針]*
- **NFR-202**: システムは調合成功・失敗・納品完了等の結果をトースト等の即時視認可能なフィードバックで通知しなければならない 🔵 *[gardenの`_show_toast()`パターン踏襲]*

## 制約

- **CON-001**: `GameState.get_state()`は`recipe_masters`相当のフィールドを公開しておらず、内部の`_recipe_masters`（private、`GameStateAlchemyDelegate.load_alchemy_master_data()`で構築）はテスト専用API（`_set_recipe_masters_for_test()`）経由でのみ操作可能である。レシピ一覧表示のためには実装時に`get_state()`への`recipe_masters`公開（gardenプランの`seed_masters`公開と同一パターン）の要否を判断する必要がある 🔴 *[atelier/autoload/game_state.gd, game_state_alchemy_delegate.gd 実装確認済み。本Planでの対応方針は未確定]*
- **CON-002**: 投入枠数の実行時権威は`GameState._alchemy_slot_count`（private、初期値`GameBalance.ALCHEMY_SLOT_COUNT_DEFAULT`、`game_state_workshop_delegate.gd`により工房強化で加算される）であり、`get_state()`に未公開である。UI側が投入枠の描画上限を正しく取得する手段（アクセッサ追加等）を実装時に確認する必要がある 🔴 *[atelier/autoload/game_state.gd, game_state_alchemy_delegate.gd 実装確認済み。本Planでの対応方針は未確定]*
- **CON-003**: `UiTheme`（`shared/theme/theme.gd`）には現状庭スロット用の色定数のみが存在し、調合画面用の色定数（レシピ選択済み/未選択、投入枠の空/投入済み等）は未定義であるため、本Planの実装時に追加する必要がある 🟡 *[atelier/shared/theme/theme.gd 現況確認済み]*
- **CON-004**: キーボード操作・スクリーンリーダー対応は`ui-design/input-system.md`で全項目TBDのため本Planのスコープ外とし、マウスクリック操作のみに対応する 🔵 *[ヒアリング「非機能・その他」節]*
- **CON-005**: MainSceneへのタブ統合、`main.tscn`への配線は本Plan外（gardenプランでも別task扱いで未実施）とする 🔵 *[ヒアリング スコープ確定事項1、先行実装（gardenプラン）記載]*
- **CON-006**: ギルド納品画面（SCR-003）・ショップ画面（SCR-004）自体の実装は本Plan外とする 🔵 *[ヒアリング スコープ確定事項1・4・5]*
- **CON-007**: `GameState`（Autoload）へのsignal監視を行うテストでは`monitor_signals(GameState, false)`を明示しなければならない（第2引数省略時のデフォルト`_auto_free=true`により`GameState`自体が解放され以降の全テストが失敗する既知の罠があるため） 🔵 *[.claude/rules/testing.md, .claude/rules/godot-debug-tools.md トラブルシュート早見表]*

## 信頼性レベルサマリー

- 🔵 青信号: 28件
- 🟡 黄信号: 7件
- 🔴 赤信号: 2件（要確認: CON-001, CON-002）
