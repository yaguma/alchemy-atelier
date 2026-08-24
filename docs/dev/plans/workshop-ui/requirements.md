# workshop-ui 要件定義書

## 概要

「Atelier」Phase 2機能実装として、UI設計文書 [`docs/design/atelier-alchemy-core/ui-design/screens/workshop-shop.md`](../../../design/atelier-alchemy-core/ui-design/screens/workshop-shop.md)（SCR-004「工房強化・ショップ画面」）を実装する。要件定義書 [`docs/spec/atelier-alchemy-core/requirements.md`](../../../spec/atelier-alchemy-core/requirements.md) §3「工房強化・ショップ」・§4「ショップ／工房強化」が上位仕様。

先行Plan `workshop`（`docs/dev/plans/workshop/`）がDomain層（`PurchaseValidator`, `UpgradeMaster`）と`GameState`統合（`apply_upgrade()`, `close_workshop()`, `get_purchased_count()`, `load_workshop_master_data()`）を実装済みで、UI（`WorkshopScreen`）は明示的にスコープ外としていた。本Planはそのフォローアップであり、`WorkshopScreen`単体（`.tscn`+`.gd`、および子コンポーネント）の新規作成のみを対象とする。先行UI Plan（`garden`, `alchemy-ui`, `guild-ui`, `rank-up-ui`）と同様、MainSceneへの組み込み・他画面との配線は別task（本Planのスコープ外）とする。

## 関連文書

- **ユーザーストーリー**: [user-stories.md](user-stories.md)
- **受入基準**: [acceptance-criteria.md](acceptance-criteria.md)
- **設計・タスク**: plan.md（未作成）

## 用語集

| 用語 | 定義 |
|-----|------|
| WorkshopScreen | 本Planで新規作成する工房強化・ショップ画面本体（`Control`継承、`.tscn`+`.gd`）。SCR-004に対応 |
| UpgradeMaster | 工房強化・ショップの購入対象マスターデータ型（`Resource`継承）。`id`, `name`, `is_permanent`, `price`, `effect_type`, `effect_value`, `max_purchase_count`の7フィールドを持つ |
| PurchaseValidator | 購入可否判定を担う純粋関数群（`can_purchase`, `is_permanent_upgrade`, `is_valid_effect`）。`features/workshop/logic/purchase_validator.gd` |
| 恒久投資 | `UpgradeMaster.is_permanent == true`の強化。ランク間の工房強化画面遷移時（昇格試験成功直後）のみ購入可能 |
| 消耗投資 | `UpgradeMaster.is_permanent == false`の強化。ターン中いつでも購入可能 |
| `can_purchase_permanent` | `GameState`内部フラグ。恒久投資タブの活性/非活性を左右する唯一の判定根拠（`GameState.get_state()["can_purchase_permanent"]`として公開済み） |
| `apply_upgrade(upgrade)` | `GameState`公開API。ゴールド減算・効果反映・購入回数更新を一括実行し、`Result`型で成否を返す（失敗時は状態変更なし） |
| `close_workshop()` | `GameState`公開API。`can_purchase_permanent`をfalseに戻す冪等操作 |
| `get_purchased_count(upgrade_id)` | `GameState`公開API。指定アップグレードの購入済み回数を返す（未購入は0） |
| `Result` | `shared/entities/result.gd`。成功/失敗とエラーコード（`StringName`）を表現する型。`ok(value)` / `fail(error_code)` |
| screen_closed | 画面を閉じる導線を表すシグナル。`GuildDeliveryScreen`等の既存画面と同型のナビゲーション用シグナル |

## 機能要件（EARS記法）

**【信頼性レベル凡例】**:
- 🔵 PRD・設計文書・ヒアリングに基づく確実な要件
- 🟡 妥当な推測による要件
- 🔴 AI推論補完による要件（要確認）

### 普遍要件（SHALL）

- **FR-001**: システムは工房強化・ショップ画面（`WorkshopScreen`）を`.tscn`+`.gd`のシーンとして提供しなければならない 🔵 *[ヒアリング確定事項1, workshop-shop.md 基本情報]*
  - 関連: US-001, AC-001
- **FR-002**: システムは画面上部に所持ゴールド（`txt-gold`）を表示しなければならない 🔵 *[workshop-shop.md UI要素]*
  - 関連: US-002, AC-001
- **FR-003**: システムは恒久投資タブ（`tab-permanent`）と消耗投資タブ（`tab-consumable`）の2タブ構成でアイテムを表示しなければならない 🔵 *[workshop-shop.md ワイヤーフレーム]*
  - 関連: US-003, AC-001
- **FR-004**: システムは各タブ内のアイテムを、`GameState.get_state()["upgrade_masters"]`から取得した`UpgradeMaster`のうち該当タブ区分（`is_permanent`）に一致するものについて、価格（`price`）降順でソートし、同価格の場合は`id`文字列昇順でタイブレークして一覧表示しなければならない 🔵 *[ヒアリング確定事項4]*
  - 関連: US-001, AC-003
- **FR-005**: システムは各アイテム行（`item-{upgrade_id}`）に名称・価格・購入ボタン（`btn-purchase-{upgrade_id}`）を表示しなければならない 🔵 *[workshop-shop.md UI要素]*
  - 関連: US-001, AC-001
- **FR-006**: システムは閉じるボタン（`btn-close`）を常時表示しなければならない 🔵 *[workshop-shop.md UI要素 btn-close]*
  - 関連: US-201, AC-001
- **FR-007**: システムは`GameState.get_state()`の戻り値に`"upgrade_masters"`（`Dictionary[StringName, UpgradeMaster]`、`_upgrade_masters.duplicate()`によるマスターデータの浅い複製）フィールドを追加しなければならない 🔵 *[ヒアリング「実装者が解決すべき設計判断」]*
  - 関連: US-001, AC-002
- **FR-008**: システムは`GameState.get_state()`の戻り値に`"purchased_upgrade_counts"`（`Dictionary[StringName, int]`、`_purchased_upgrade_counts.duplicate()`または`duplicate(true)`による複製）フィールドを追加しなければならない 🔵 *[ヒアリング「実装者が解決すべき設計判断」]*
  - 関連: US-103, AC-002

### イベント駆動要件（WHEN-THEN）

- **FR-101**: プレイヤーが購入ボタン（`btn-purchase-{upgrade_id}`）を押下した場合、システムは対応する`UpgradeMaster`を引数に`GameState.apply_upgrade(upgrade)`を呼び出さなければならない 🔵 *[ヒアリング確定事項3, game_state_workshop_delegate.gd]*
  - 関連: US-101, AC-008, AC-009
- **FR-102**: `apply_upgrade()`の戻り値`Result`が成功（ok）だった場合、システムはアイテム一覧を再構築し、成功を示すトーストメッセージ（`%ToastLabel`）を表示しなければならない 🔵 *[ヒアリング確定事項3、GardenScreen/AlchemyScreenの`_show_toast()`パターン踏襲]*
  - 関連: US-101, AC-008
- **FR-103**: `apply_upgrade()`の戻り値`Result`が失敗（fail）だった場合、システムはアイテム一覧を再構築せず、失敗したエラーコードを含む失敗トーストメッセージを表示しなければならない 🔵 *[ヒアリング確定事項3]*
  - 関連: US-102, AC-009
- **FR-104**: プレイヤーが閉じるボタン（`btn-close`）を押下した場合、システムは`GameState.close_workshop()`を呼び出した上で`screen_closed`シグナルを発行しなければならない 🟡 *[ヒアリング「実装者が解決すべき設計判断」推奨設計。close_workshop()は`_can_purchase_permanent`をfalseにするだけの冪等操作]*
  - 関連: US-201, AC-010
- **FR-105**: アイテム一覧の再構築（初期表示・購入成功後の再構築）が行われる場合、システムはその都度`GameState.get_state()`のスナップショットのみに基づいて恒久投資タブの活性/非活性を再判定しなければならない 🟡 *[ヒアリング確定事項2から導出]*
  - 関連: US-003, AC-004

### 状態駆動要件（WHERE）

- **FR-201**: `GameState.get_state()["can_purchase_permanent"]`がtrueである間、システムは恒久投資タブ（`tab-permanent`）を活性状態として表示しなければならない 🔵 *[ヒアリング確定事項2, workshop-shop.md 状態遷移「昇格直後の強制表示状態」]*
  - 関連: US-003, AC-004
- **FR-202**: `GameState.get_state()["can_purchase_permanent"]`がfalseである間、システムは恒久投資タブ（`tab-permanent`）を非活性状態として表示しなければならない 🔵 *[ヒアリング確定事項2, workshop-shop.md 状態遷移「通常アクセス状態」]*
  - 関連: US-003, AC-004
- **FR-203**: 消耗投資タブ（`tab-consumable`）である間、システムは常に活性状態として表示しなければならない 🔵 *[workshop-shop.md UI要素 tab-consumable]*
  - 関連: US-003, AC-005
- **FR-204**: 対象アイテムについて所持ゴールド（`state["gold"]`）が価格（`upgrade.price`）未満である間、システムは当該アイテムの購入ボタンを無効化し「ゴールド不足」を示す表示にしなければならない 🔵 *[workshop-shop.md UI要素 item-{upgrade_id}／btn-purchase-{upgrade_id}, ヒアリング「購入不可時の表示」]*
  - 関連: US-103, AC-006
- **FR-205**: 対象アイテムについて`GameState.get_purchased_count(upgrade.id)`が`upgrade.max_purchase_count`以上である間、システムは当該アイテムの購入ボタンを無効化し「購入済み」を示す表示にしなければならない 🔵 *[workshop-shop.md UI要素 item-{upgrade_id}「2026-08-05追加、PRレビューWarning対応」, ヒアリング「購入不可時の表示」]*
  - 関連: US-103, AC-007
- **FR-206**: 対象アイテムが購入可能（所持ゴールドが価格以上、かつ購入済み回数が上限未満）である間、システムは購入ボタンを有効化し「購入する」ラベルで表示しなければならない 🔵 *[workshop-shop.md ワイヤーフレーム, PurchaseValidator.can_purchase]*
  - 関連: US-101, AC-006, AC-007

### 任意要件（MAY）

- **FR-301**: システムは将来的に購入成功時のゴールド減算カウントダウン演出・画面表示時のフェードイン演出を追加してもよい（本Planでは見送る） 🟡 *[ヒアリング確定事項5, workshop-shop.md アニメーション🟡TBD]*
  - 関連: US-301, AC-001

### 禁止要件（MUST NOT）

- **FR-401**: システムは`GardenScreen`/`AlchemyScreen`の`shop_requested`シグナルへの接続、および`MainScene`への組み込みを行ってはならない 🔵 *[ヒアリング確定事項1、先行UI Planと同じスコープ境界]*
  - 関連: AC-011
- **FR-402**: システムは`GameState.get_state()`の戻り値（`upgrade_masters`, `purchased_upgrade_counts`を含む）を防御的コピーなしで公開・保持し、呼び出し元からの直接改変を許してはならない 🔵 *[state-management.md 防御的コピー原則]*
  - 関連: AC-012
- **FR-403**: システムは恒久投資タブが非活性の状態で、恒久投資アイテムの購入ボタンを活性状態として表示してはならない 🔵 *[workshop-shop.md 状態遷移「通常アクセス状態」, architecture.md 検証責務のレイヤー配置原則]*
  - 関連: US-101, AC-013
- **FR-404**: システムは購入不可の理由（ゴールド不足／購入済み上限到達）を区別せず一律に同じ無効化表示にしてはならない 🔵 *[workshop-shop.md item-{upgrade_id}「購入可能/購入不可（ゴールド不足）/購入済み（上限到達）」の3状態要件]*
  - 関連: US-103, AC-013

## 非機能要件

### パフォーマンス

- **NFR-001**: アイテム一覧の再構築（購入成功時・初期表示時）は、既存の`SeedInventoryList._rebuild()`/`GuildDeliveryScreen._rebuild_list()`と同型の「全行破棄→再生成」パターンで行い、体感的な遅延なく完了しなければならない 🟡 *[明確な数値目標のヒアリングなし。ただし対象アイテム数は5件と少なく、他UI Plan（garden/guild）でも同パターンが数値目標なしで採用されている前例があるため、妥当な推測として🟡に確定。ユーザー確認済み]*

### セキュリティ

- **NFR-101**: システムはUI側の購入可否判定（ゴールド比較・購入回数比較）を最終的な実行可否の根拠として信頼せず、状態変更（`apply_upgrade()`）の直前に`GameState`側（Domain層`PurchaseValidator`経由）が再検証した結果のみを状態変更の根拠としなければならない 🔵 *[architecture.md 検証責務のレイヤー配置原則, game_state_workshop_delegate.gd apply_upgrade()実装]*

### ユーザビリティ

- **NFR-201**: システムは購入可否の理由（ゴールド不足/購入済み）を色だけでなくボタンの有効/無効状態＋テキストで併記しなければならない 🔵 *[workshop-shop.md アクセシビリティ「色覚多様性対応」]*
- **NFR-301**: システムはScreen（親、GameState購読・`_refresh()`）＋List（子、`setup()`で配列受け取り）＋Row（孫、`setup()`で表示内容注入）の3層構成パターン（`SeedInventoryList`/`SeedEntryRow`, `GuildDeliveryScreen`/`GuildDeliveryResultRow`踏襲）に従わなければならない 🔵 *[ヒアリング「既存UIコンポーネント設計パターン」]*

## 制約

- **CON-001**: 本Planは`WorkshopScreen`単体（`.tscn`+`.gd`、および子コンポーネント）の新規作成のみをスコープとし、`GardenScreen`/`AlchemyScreen`の`shop_requested`シグナル接続および`MainScene`統合は含まない 🔵 *[ヒアリング確定事項1]*
- **CON-002**: 恒久投資タブの活性判定は呼び出し元からのモード引数を受け取らず、`GameState.get_state()["can_purchase_permanent"]`のみを根拠とする（`setup()`はGameStateのスナップショットのみで完結する） 🔵 *[ヒアリング確定事項2]*
- **CON-003**: 本Planのスコープでは、ゴールド減算カウントダウン・フェードイン等のアニメーションを実装しない 🟡 *[ヒアリング確定事項5]*
- **CON-004**: テストファイルは`tests/integration/test_workshop_screen.gd`（既存の`test_garden_screen.gd`, `test_guild_delivery_screen.gd`と同型の配置・命名）に配置する 🟡 *[既存テスト配置慣例からの類推]*
- **CON-005**: `_can_purchase_permanent`/`_purchased_upgrade_counts`のテスト操作は既存のテスト専用API（`GameState._set_can_purchase_permanent_for_test()`, `GameState._set_purchased_upgrade_counts_for_test()`）を利用し、新規テスト専用APIの追加は不要とする 🔵 *[ヒアリング「テスト方針の前提」]*

## 信頼性レベルサマリー

- 🔵 青信号: 27件
- 🟡 黄信号: 6件
- 🔴 赤信号: 0件
