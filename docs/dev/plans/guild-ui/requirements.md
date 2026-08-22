# guild-ui 要件定義書

## 概要

「Atelier」（Godot 4.7 + GDScript製、錬金術デッキ構築RPG個人開発）のギルド納品画面UI（SCR-003）を新規実装する。

Domain層（`atelier/features/guild/logic/delivery_resolver.gd`, `delivery_result.gd`）とApplication層（`atelier/autoload/game_state_guild_delegate.gd`の`deliver_pending_products()`、`GameState.deliver_pending_products()`委譲窓口）はすでに実装・テスト済み（`atelier/tests/integration/test_game_state_deliver_pending_products.gd`）である。UI層（`atelier/features/guild/ui/`）は`.gitkeep`のみで完全に未着手。

現状、`atelier/features/alchemy/ui/alchemy_screen.gd`の「ターン終了」ボタン（`_on_end_turn_pressed()`）が`GameState.deliver_pending_products()`を直接呼び出し、結果は`GameState.delivered`シグナルを購読した`_on_delivered(results)`が「N件を納品しました」という1行トーストを出すだけの**FR-108プレースホルダー実装**とコード中に明記されている（`atelier/features/alchemy/ui/alchemy_screen.gd` L264-286）。本planはこのプレースホルダーを、`features/guild/ui/`配下の専用画面`GuildDeliveryScreen`による複数件対応のリスト表示へ置き換える。

MainSceneへの組み込み（表示/非表示切替・画面遷移）、演出（フェードイン・ノルマバー減少アニメーション等）、アクセシビリティ対応（キーボード操作・スクリーンリーダー）は本plan外（Won't Have）。

## 関連文書

- **ユーザーストーリー**: [user-stories.md](user-stories.md)
- **受入基準**: [acceptance-criteria.md](acceptance-criteria.md)
- **既存デザイン文書**: [`docs/design/atelier-alchemy-core/ui-design/screens/guild-delivery.md`](../../../design/atelier-alchemy-core/ui-design/screens/guild-delivery.md)（SCR-003詳細設計。単一調合物前提のワイヤーフレームは本plan決定によりリスト内1項目のレイアウトとして流用する）
- **既存デザイン文書**: [`docs/design/atelier-alchemy-core/core-systems.md`](../../../design/atelier-alchemy-core/core-systems.md) L185-219（GuildSystem詳細設計）
- **既存デザイン文書**: [`docs/design/atelier-alchemy-core/ui-design/overview.md`](../../../design/atelier-alchemy-core/ui-design/overview.md)（RankHud定義・ボタン規約・画面遷移図）

## 用語集

| 用語 | 定義 |
|-----|------|
| GuildDeliveryScreen | 本plan新規実装の`Control`継承UIコンポーネント（`features/guild/ui/`配下） |
| `DeliveryResult` | Domain層（`features/guild/logic/delivery_result.gd`）が保持する1件分の納品決算結果値。`final_contribution`, `final_reward`, `order_matched`の3フィールドのみ |
| `ProductInstance` | 調合物のランタイムインスタンス（`shared/entities/product_instance.gd`）。`recipe_id`, `quality_score`, `activated_traits`, `contribution`, `reward`を保持 |
| `pending_products` | `GameState`が保持するギルド納品待ちキュー（`Array[ProductInstance]`）。ターン終了時に`deliver_pending_products()`で一括消費される |
| 指定依頼 / `daily_order` | `DailyOrderMaster`が表す日替わり指定調合物の条件。合致時は`match_bonus_multiplier`が貢献度・報酬に乗算される |
| ノルマ | `RankState.quota`（残量、0に向かって減算される）。上限は`RankMaster.quota_max` |
| スナップショット | `AlchemyScreen`が`GameState.deliver_pending_products()`呼び出し**直前**に`GameState.get_state()["pending_products"]`から取得する複製配列（`Array[ProductInstance]`）。`DeliveryResult`が調合物名・品質・発現特性を持たないため、`display_results()`呼び出しでの結合表示に必要 |
| `display_results()` | `GuildDeliveryScreen`が公開する`display_results(products: Array[ProductInstance], results: Array[DeliveryResult]) -> void`メソッド。`AlchemyScreen`が同一関数スコープ内で取得したスナップショットと`deliver_pending_products()`の戻り値を直接渡すことで、`GameState.delivered`シグナル購読を介さずindex対応付けを実現する（2026-08-22ヒアリング追加確認で確定） |

## 機能要件（EARS記法）

**【信頼性レベル凡例】**:
- 🔵 PRD・設計文書・ヒアリングに基づく確実な要件
- 🟡 妥当な推測による要件
- 🔴 AI推論補完による要件（要確認）

### 普遍要件（SHALL）

- **FR-001**: システムは`features/guild/ui/`配下に`GuildDeliveryScreen`という名前の`Control`継承クラスを新規実装しなければならない 🔵 *[ヒアリング決定1]*
  - 関連: US-001, AC-001
- **FR-002**: システムは`GuildDeliveryScreen`を、1回のターン終了で複数件の調合物が同時に納品されるケース（`GameState.delivered(results: Array[DeliveryResult])`が複数要素を持つケース）を前提としたリスト表示構成で実装しなければならない 🔵 *[ヒアリング決定2]*
  - 関連: US-001, US-002, AC-002
- **FR-003**: システムはリスト内の各項目について、調合物名（`RecipeMaster.name`）・品質（`ProductInstance.quality_score`）・発現特性（`ProductInstance.activated_traits`）・指定依頼合致有無（`DeliveryResult.order_matched`）・貢献度（`DeliveryResult.final_contribution`）・報酬（`DeliveryResult.final_reward`）を表示しなければならない 🔵 *[ヒアリング決定2, guild-delivery.md UI要素表]*
  - 関連: US-001, AC-001
- **FR-004**: システムは納品結果リストの合計貢献度と合計報酬を表示しなければならない 🔵 *[ヒアリング決定2]*
  - 関連: US-002, AC-002
- **FR-005**: システムは`GameState`および Domain層（`DeliveryResolver`等）が提供する計算ロジックを`GuildDeliveryScreen`内で再実装せず、GameStateが発行済みの`DeliveryResult`をそのまま表示に用いなければならない 🔵 *[architecture.md「他Featureから参照してよいのは`logic/*.gd`と`resources/*.gd`のみ」]*
  - 関連: US-001, AC-007
- **FR-006**: システムは`AlchemyScreen`（`atelier/features/alchemy/ui/alchemy_screen.gd`）から`_on_delivered(results)`ハンドラ・`GameState.delivered`シグナルへの購読処理（`_ready()`内の`connect`と`_exit_tree()`内の`disconnect`）・関連するトースト表示ロジックを削除し、代わりに`_on_end_turn_pressed()`内で(1)`GameState.deliver_pending_products()`呼び出し**直前**に`GameState.get_state()["pending_products"]`をスナップショット取得し、(2)呼び出しの戻り値（`Result.value: Array[DeliveryResult]`）とあわせて`GuildDeliveryScreen.display_results(products, results)`を直接呼び出す処理を追加しなければならない。この呼び出しは`pending_products`が空だった場合（スナップショット・戻り値がともに空配列）も省略せず毎回行い、`GuildDeliveryScreen`の表示を常に最新状態へリセットする 🔵 *[ヒアリング決定1、2026-08-22追加確認で直接メソッド呼び出し方式に確定]*
  - 関連: US-001, US-401, AC-009
- **FR-007**: システムは`GuildDeliveryScreen`が現在表示中のリスト件数・合計貢献度・合計報酬をテストコードから取得できる公開メソッド（例: `get_item_count()`, `get_total_contribution()`, `get_total_reward()`）を提供しなければならない 🟡 *[`alchemy_screen.gd`の`get_toast_text()`パターン踏襲]*
  - 関連: US-301, AC-006
- **FR-008**: システムは`GuildDeliveryScreen`に`display_results(products: Array[ProductInstance], results: Array[DeliveryResult]) -> void`という公開メソッドを提供しなければならない。本メソッドが唯一の表示更新経路であり、`GuildDeliveryScreen`は`GameState.delivered`・`GameState.product_crafted`のいずれのシグナルも自前で購読しない 🔵 *[2026-08-22追加確認。「直接メソッド呼び出し方式」の確定に伴う核心的契約]*
  - 関連: US-001, US-301, AC-001, AC-006

### イベント駆動要件（WHEN-THEN）

- **FR-101**: `display_results(products, results)`が呼び出された場合、システムは受け取った2つの配列を同一indexで対応付けてリストを再構築しなければならない（`products[i]`と`results[i]`が同一調合物に対応する） 🔵 *[2026-08-22追加確認。呼び出し元（`AlchemyScreen`）が同一関数スコープ内でスナップショットと`deliver_pending_products()`の戻り値を取得するため、渡された時点で対応関係は保証されている]*
  - 関連: US-001, US-301, AC-001, AC-006
- **FR-102**: ユーザーが「閉じる/続ける」ボタン（`guild-delivery.md`の`btn-continue`相当）を押下した場合、システムは画面遷移導線を表す`signal`（例: `screen_closed`）を発行しなければならない 🟡 *[ヒアリング決定5。シグナル名は「`screen_closed`のような」という例示であり確定名ではない]*
  - 関連: US-201, AC-005

### 状態駆動要件（WHERE）

- **FR-201**: リスト項目が指定依頼に合致している間（`order_matched == true`）、システムは合致を示すテキスト（例:「指定合致」）を当該項目に表示しなければならない 🔵 *[guild-delivery.md `txt-order-match`、`AlchemyPreviewPanel`の`ORDER_MATCHED_TEXT`パターン踏襲]*
  - 関連: US-003, AC-003
- **FR-202**: リスト項目が指定依頼に合致していない間（`order_matched == false`）、システムは合致テキストを非表示にしなければならない 🔵 *[`AlchemyPreviewPanel._apply_display()`の`visible = _order_matched`パターン踏襲]*
  - 関連: US-003, AC-003

### 任意要件（MAY）

- **FR-301**: システムは`GuildDeliveryScreen`専用の簡易ノルマバー（`GameState.get_current_rank_quota()`が返す残量 / `GameState.get_current_rank_master().quota_max`）を画面内に表示してもよい 🔵 *[ヒアリング決定4。全画面共通の`RankHud`は別task。API名はCON-001参照]*
  - 関連: US-101, AC-004
- **FR-302**: システムはノルマバー付近に現在ランクの表示名（`RankMaster.display_name`）を表示してもよい 🟡 *[ヒアリング決定4からの妥当な推測。`ui-design/overview.md`の`RankHud`定義`txt-rank-name`相当だが、本plan内では簡易版のため任意要件とする]*
  - 関連: US-101, AC-004

### 禁止要件（MUST NOT）

- **FR-401**: システムはフェードイン・ノルマバー減少アニメーション・指定合致強調演出などの`Tween`演出を実装してはならない 🔵 *[ヒアリング決定6]*
  - 関連: AC-004
- **FR-402**: システムはMainSceneへの組み込み（表示/非表示切替の実行、シーン遷移の実行）を行ってはならない 🔵 *[ヒアリング決定5]*
  - 関連: AC-005
- **FR-403**: システムはキーボード操作対応・スクリーンリーダー対応を実装してはならない 🔵 *[ヒアリング決定7、Won't Have]*
  - 関連: -
- **FR-404**: システムは`AlchemyScreen._on_end_turn_pressed()`が呼び出す`GameState`側API自体（`GameState.deliver_pending_products()`という呼び出し先）を、代替APIの新設等によって置き換えてはならない。ただし呼び出しの前後にスナップショット取得・`GuildDeliveryScreen.display_results()`呼び出しを追加すること自体はFR-006が要求する変更であり許容される 🔵 *[ヒアリング決定1。2026-08-22追加確認でスコープを明確化]*
  - 関連: US-001, AC-009
- **FR-405**: システムはDomain層（`features/guild/logic/delivery_resolver.gd`, `delivery_result.gd`）の計算式・フィールド構成を変更してはならない 🔵 *[ヒアリング決定3「Domain層は変更しない」]*
  - 関連: AC-006, AC-007

## 非機能要件

### パフォーマンス

- **NFR-001**: 表示更新はターン終了時（`deliver_pending_products()`呼び出し時）の1回のみに限られる低頻度操作であり、特別な最適化（プーリング等）は不要とする 🟡 *[`godot-best-practices.md`オブジェクトプーリング指針との対比からの妥当な推測。1ターンあたりの納品件数は少数（庭・投入枠の仕様上、数件〜十数件程度）と想定される]*

### セキュリティ

該当なし。`display_results(products, results)`は`AlchemyScreen`が同一関数スコープ内で`GameState.get_state()["pending_products"]`のスナップショットと`GameState.deliver_pending_products()`の戻り値を取得した直後に渡すため、両配列のサイズ・順序不一致は構造的に発生しない（2026-08-22追加確認、CON-003参照）。当初検討したindex不一致防御要件（旧NFR-101）は方式確定に伴い不要と判断し削除した。

### ユーザビリティ

- **NFR-201**: 指定依頼の合致/不合致は色のみに依存せず、テキストの表示/非表示でも判別できるようにしなければならない 🔵 *[ヒアリング決定7、`AlchemyPreviewPanel`と同一レベルの「テキストで明示」方針を踏襲]*

## 制約

- **CON-001**: 本plan内で`GameState`に以下2つの新規公開APIを追加すること。(1) 現在ランクの`RankMaster`を取得する`GameState.get_current_rank_master() -> RankMaster`。(2) 現在ランクのノルマ残量を取得する`GameState.get_current_rank_quota() -> float`（`_rank_state.quota`をそのまま返す薄いラッパー）。既存の`GameState.get_state()`（`atelier/autoload/game_state.gd` L88-135で実装内容を確認済み）は`current_rank_id`と`rank_state`（`RankState`インスタンス、`quota`, `elapsed_turn`のみ）は返すが、`rank_masters`辞書・`quota_max`・ランク表示名を一切含まないため、(1)の追加なしにはFR-301/FR-302を実装できない。また`get_state()["rank_state"]`をUI層（`GuildDeliveryScreen`）が直接読むと、`RankState`型ガード（CON-005違反）と無検証`Variant`アクセス（coding-style.md違反）のどちらかを強いられる構造的矛盾が生じるため、(2)の追加によって`GuildDeliveryScreen`が`RankState`を一切参照しなくて済むようにする 🔵 *[ヒアリング決定4、2026-08-22追加確認でAPIを2つに確定（Plan設計フェーズで発見した構造的矛盾の解消）]*
- **CON-002**: CON-001の`get_current_rank_master()`は、既存のprivateメソッド`_get_current_rank_master_or_fallback()`（`atelier/autoload/game_state.gd` L225-236、ランクマスター未ロード時にtraits_unlocked=false・quota_max=0.0・limit_turn=0の安全側フォールバックを返す）を再利用し、判定式を重複実装してはならない。既存の`is_current_rank_traits_unlocked()`（L244-245）と同型の薄いラッパーとして追加することを推奨する。`get_current_rank_quota()`は`_rank_state.quota`を返すだけの単純な薄いラッパーでよく、フォールバック判定は不要（`RankState`は既定値`quota=0.0`を持つため、未初期化でもクラッシュしない） 🟡 *[既存パターンからの妥当な推測]*
- **CON-003**: データ結合方式は「直接メソッド呼び出し方式」に確定した（2026-08-22追加ヒアリングで確認）。`AlchemyScreen._on_end_turn_pressed()`は以下の順で処理する: (1) `GameState.get_state()["pending_products"]`をスナップショット取得、(2) `var result := GameState.deliver_pending_products()`、(3) `GuildDeliveryScreen.display_results(snapshot, result.value)`を直接呼び出す。この3ステップは同一関数スコープ内・同期的に実行されるため、スナップショットと`result.value`の間に他の状態変化が介在する余地がなく、index対応が構造的に保証される。`GuildDeliveryScreen`は`GameState.delivered`・`GameState.product_crafted`のいずれも自前で購読しない（FR-008）。当初検討した「`product_crafted`購読によるスナップショット追随」方式は、AlchemyScreen自身がスナップショット取得と結果受け渡しの両方を担えることが確認できたため採用しなかった 🔵 *[2026-08-22追加ヒアリングで確定]*
- **CON-004**: `DeliveryResult`（`final_contribution`, `final_reward`, `order_matched`）は変更しない。調合物名・品質・発現特性はスナップショットした`ProductInstance`側（`recipe_id`, `quality_score`, `activated_traits`）から取得し、`recipe_id`から`RecipeMaster.name`を`GameState.get_state()["recipe_masters"]`経由で解決する 🔵 *[ヒアリング決定3、`delivery_result.gd`・`product_instance.gd`実地確認済み]*
- **CON-005**: Feature-Based Architectureの「他Featureから参照してよいのは`logic/*.gd`と`resources/*.gd`のみ」規約（`.claude/rules/architecture.md`）により、`GuildDeliveryScreen`は`features/rank/state/rank_state.gd`や`features/alchemy/state/*.gd`を直接参照せず、`GameState.get_state()`が返す値のみから必要な情報を取得しなければならない 🔵 *[architecture.mdレイヤー間依存ルール]*
- **CON-006**: `guild_delivery_screen.gd`が`.claude/rules/coding-style.md`の300行ガイドラインを超える場合、`AlchemyPreviewPanel`と同様の表示専用の子コンポーネント（GameState/Domain層に依存しない）への分割を検討すること 🟡 *[coding-style.md「1ファイルの上限」]*

## 信頼性レベルサマリー

- 🔵 青信号: 21件
- 🟡 黄信号: 6件
- 🔴 赤信号: 0件

2026-08-22の追加ヒアリングで「直接メソッド呼び出し方式」（`AlchemyScreen`が`display_results()`を直接呼ぶ）に確定したことで、当初の赤信号4件（旧FR-102〔`product_crafted`追跡、現在は削除しFR-101/FR-008へ統合〕, 旧FR-406〔削除〕, 旧NFR-101〔削除〕, CON-003）はすべて解消・削除または🔵へ格上げした。
