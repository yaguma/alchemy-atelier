# Plan: workshop-ui

## Requirements Summary

「Atelier」のPhase 2機能実装として、UI設計文書 [`docs/design/atelier-alchemy-core/ui-design/screens/workshop-shop.md`](../../../design/atelier-alchemy-core/ui-design/screens/workshop-shop.md) が定義する SCR-004「工房強化・ショップ画面」を実装する。先行Plan `workshop`（`docs/dev/plans/workshop/`）がDomain層（`PurchaseValidator`, `UpgradeMaster`）と`GameState`統合（`apply_upgrade()`, `close_workshop()`, `get_purchased_count()`, `load_workshop_master_data()`）を実装済みで、UI（`WorkshopScreen`）は明示的にスコープ外としていた。本Planはそのフォローアップ。

`WorkshopScreen`単体（`.tscn`+`.gd`、および子コンポーネント`UpgradeItemList`/`UpgradeItemRow`）の新規作成のみを対象とし、先行UI Plan（`garden`, `alchemy-ui`, `guild-ui`, `rank-up-ui`）と同じ境界線（MainSceneへの組み込み・`GardenScreen`/`AlchemyScreen`の`shop_requested`シグナルへの接続は別task）を踏襲する。

詳細: [requirements.md](requirements.md)（FR24件+NFR4件+CON5件、🔵27/🟡6/🔴0、赤信号は解消済み） | [user-stories.md](user-stories.md)（US8件、🔵7/🟡1） | [acceptance-criteria.md](acceptance-criteria.md)（AC13件、テストチェック項目36件+横断3件）

## Design Overview

Plan サブエージェントによるインターフェース設計を実施済み（本セクションはその要約。詳細な擬似コードは各タスクファイル参照）。

`WorkshopScreen`は既存の`GardenScreen`/`GuildDeliveryScreen`と同型の「Screen（親、GameState購読・`_refresh()`）＋List（子、`setup()`で配列受け取り）＋Row（孫、`setup()`で表示内容注入）」3層構成（NFR-301）で実装する。

1. **`UpgradeItemRow`**（`features/workshop/ui/upgrade_item_row.gd`/`.tscn`）: アイテム1行の表示専用コンポーネント。`setup(upgrade, gold, already_purchased_count, locked)`で「購入する/ゴールド不足/購入済み」の3状態をボタンのdisabled+テキストで表現する（優先順位: 購入済み＞ゴールド不足＞タブロック＞購入可能）。`purchase_pressed(upgrade_id)`シグナルを発行する。
2. **`UpgradeItemList`**（`features/workshop/ui/upgrade_item_list.gd`/`.tscn`）: 1タブ分の一覧。`setup(upgrades, gold, purchased_counts, locked)`で受け取った配列（呼び出し元がソート済み）から`UpgradeItemRow`を全行破棄→再生成する（`SeedInventoryList`と同型）。`purchase_requested(upgrade_id)`シグナルを中継する。GameStateには依存しない。
3. **`WorkshopScreen`**（`features/workshop/ui/workshop_screen.gd`/`.tscn`）: 画面本体。`_refresh()`で`GameState.get_state()`を取得し、`is_permanent`で絞り込み価格降順（同価格はid昇順）にソートした配列を各`UpgradeItemList`へ渡す。タブボタンで`%PermanentList`/`%ConsumableList`の`visible`を排他的に切り替える（初回`_refresh()`時のみ、`can_purchase_permanent`がtrueなら恒久投資タブを初期選択にする🟡）。恒久投資タブは`can_purchase_permanent`がfalseの間disabledにする。購入ボタン押下は`GameState.apply_upgrade()`を呼び、成功時は再構築+成功トースト、失敗時はトーストのみ（NFR-101: UI側判定は先出しに過ぎず、最終権威は`apply_upgrade()`内の`PurchaseValidator`再検証）。閉じるボタンは`GameState.close_workshop()`呼び出し後に`screen_closed`を発行する。
4. **`GameState.get_state()`変更**: `upgrade_masters`（`_upgrade_masters.duplicate()`）・`purchased_upgrade_counts`（`_purchased_upgrade_counts.duplicate()`）の2キーを追加する。Domain層（`PurchaseValidator`, `UpgradeMaster`, `GameStateWorkshopDelegate`）・その他の公開APIは変更しない。

### レイヤー構成

```
Presentation層  features/workshop/ui/workshop_screen.gd/.tscn        ← 本Planの新規作成
               features/workshop/ui/upgrade_item_list.gd/.tscn       ← 同上
               features/workshop/ui/upgrade_item_row.gd/.tscn        ← 同上
       ↓ GameState.get_state() / apply_upgrade() / close_workshop()
Application層   autoload/game_state.gd（get_state()に2キー追加のみ）
               autoload/game_state_workshop_delegate.gd（変更なし）
       ↓ 参照のみ
Domain層        features/workshop/logic/purchase_validator.gd（変更なし、UI側では直接呼ばない）
               features/workshop/resources/upgrade_master.gd（変更なし、型として参照）
```

### 既知のリスク・設計判断（実装判断、ゴール/スコープには影響しない）

- **タブUI方式**: `workshop-shop.md`ワイヤーフレームは恒久/消耗を縦積み同時表示するASCII図だが、ユーザーヒアリングで「クリックで排他切替え」方式に確定した（`%PermanentList`/`%ConsumableList`の`visible`を排他制御）。
- **初期タブ選択**: `can_purchase_permanent == true`での初回表示時は恒久投資タブを初期選択にする（🟡設計判断。workshop-shop.md「昇格直後の強制表示状態」からの合理的推測。以降の購入操作等による再構築ではプレイヤーが選択中のタブを維持する）。
- **閉じるボタンの`close_workshop()`呼び出し**: FR-104として🟡確定済み（`close_workshop()`は`_can_purchase_permanent`をfalseにするだけの冪等操作のため、通常アクセス時に呼んでも副作用なし）。

## Task Dependency Graph

トポロジカル順（001が最も基盤、番号順に実行すればすべての依存が解決済みになる）:

```
001 GameState.get_state()にupgrade_masters/purchased_upgrade_counts追加
002 UpgradeItemRow新規作成
       │（001, 002は依存なし・並行可）
       ↓
003 UpgradeItemList新規作成（dep: 002）
       ↓
004 WorkshopScreen表示基盤・タブ切替（dep: 001, 003）
       │
       ├─→ 005 WorkshopScreen購入フロー（dep: 004）
       └─→ 006 WorkshopScreen閉じるボタン（dep: 004）
```

実行順序の目安: **001・002（並行可） → 003 → 004 → 005・006（並行可、いずれも004に依存。同一ファイルを編集するため実務上は直列実行を推奨）**

| タスク | 依存 |
|---|---|
| 001 GameState.get_state()フィールド追加 | - |
| 002 UpgradeItemRow新規作成 | - |
| 003 UpgradeItemList新規作成 | 002 |
| 004 WorkshopScreen表示基盤・タブ切替 | 001, 003 |
| 005 WorkshopScreen購入フロー | 004 |
| 006 WorkshopScreen閉じるボタン | 004 |

## 検証結果（task-breakdown Phase 4）

- MECE（漏れ・重複なし）: ✅ FR-001〜FR-008・FR-101〜FR-105・FR-201〜FR-206・FR-301・FR-401〜FR-404の全24件が001〜006いずれかのタスクに対応（FR-301は「実装しない」ことの確認としてタスク004のTest Strategyに含める）
- 依存関係（循環なし・順序が成立）: ✅ 上表の通り。循環なし
- 各葉にDoDあり: ✅ 全タスクの`## Test Strategy`がAC-001〜AC-013のGiven/When/Thenに対応するチェックリストを持つ
- 粒度が揃っている: ✅ low 2件（001, 006）/ medium 4件（002, 003, 004, 005）。004がタブ切替+ソート+初期選択+ゴールド表示と要素が多いためmedium上限だが、rank-up-ui plan前例（1画面を複数taskに分割）と同様の粒度に収まる
- 実行順序（トポロジカル順の目安）: 001・002（並行可） → 003 → 004 → 005・006（並行可、004依存。同一ファイル編集のため直列実行推奨）

## Cross-Plan Dependencies

- [`workshop/plan.md`](../workshop/plan.md): `PurchaseValidator`, `UpgradeMaster`, `GameStateWorkshopDelegate`（`apply_upgrade()`/`close_workshop()`/`get_purchased_count()`/`load_workshop_master_data()`）を本Planが権威として利用する（変更はしない）。
- **`atelier/features/garden/ui/garden_screen.gd`の`shop_requested`シグナル・`atelier/features/alchemy/ui/alchemy_screen.gd`の`shop_requested`シグナル**: 本Planでは接続しない（FR-401）。`WorkshopScreen`を実際に開く導線の配線は将来Planのスコープ。
- **`atelier/scenes/main.tscn`への統合**: 本Planでは行わない（`alchemy-ui`/`rank-ui`/`rank-up-ui`Planと同じ境界線）。
