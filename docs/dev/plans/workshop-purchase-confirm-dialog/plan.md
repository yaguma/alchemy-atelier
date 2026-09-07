# Plan: workshop-purchase-confirm-dialog

## Requirements Summary

工房強化・ショップ画面（`WorkshopScreen`）で恒久投資（`UpgradeMaster.is_permanent == true`）アイテムの購入ボタンを押した際、即座に`GameState.apply_upgrade()`を実行するのではなく、確認ダイアログ（アイテム名・価格・効果説明を表示し「はい/いいえ」で選択）を挟む。消耗投資（`is_permanent == false`）は現行通り即時購入のまま変更しない。

ヒアリング確定事項:
- 対象: 恒久投資（permanent）タブのアイテムのみ。消耗投資は対象外
- ダイアログ構成: 「購入する」「キャンセル」の2ボタン。キャンセル・Escapeキーでは状態を一切変更しない
- 表示内容: アイテム名・価格（最小限）＋ 効果の説明文

🟡 効果説明文の生成方針: `UpgradeMaster`に説明用フィールドは存在しない（`resources/upgrade_master.gd`参照）。マスターデータへのフィールド追加は本Planのスコープ外とし、`effect_type`から日本語説明文を生成する純粋関数（`UpgradeEffectDescriber`）を新設する。`recipe_unlock`/`seed_name_purchase`は`effect_value`（StringName ID）を他マスター（レシピ名・種名）に解決せず、汎用文言に留める（Domain層の他Feature非参照ルールを保つため）。

## Design Overview

### 新規: `UpgradeEffectDescriber`（Functional Core）

`atelier/features/workshop/logic/upgrade_effect_describer.gd`。`UpgradeMaster`を受け取り、`effect_type`に応じた日本語説明文（String）を返す純粋関数。副作用なし、他Featureのマスターデータを参照しない。

### 新規: `PurchaseConfirmDialog`（Presentation）

`atelier/features/workshop/ui/purchase_confirm_dialog.gd` + `.tscn`。`SettingsPanel`/`PauseMenu`と同型の「オーバーレイに単発生成→シグナルで結果通知→`queue_free()`」パターンを踏襲する。既存2コンポーネントは`closed`という単一の終了シグナルのみを持つが、本ダイアログは「確認」「キャンセル」で呼び出し元の後続処理が異なるため、`confirmed(upgrade_id)` / `cancelled`の2シグナルを持つ点が差分。

### 変更: `WorkshopScreen`

`_on_purchase_requested()`で`is_permanent`を判定し、恒久投資ならダイアログを開いて購入処理を保留、消耗投資なら現行通り即時購入する。実際の購入処理（`GameState.apply_upgrade()`呼び出し＋`_refresh()`＋トースト表示）は`_execute_purchase(upgrade)`に抽出し、即時購入経路とダイアログ確認後経路の両方から呼ぶ（重複排除）。

`workshop_screen.tscn`に`OverlayLayer`ノード（`pause_menu.tscn`と同型、`mouse_filter = 2`でアイテム一覧操作を妨げない）を追加し、ダイアログの親とする。

## Task Dependency Graph

```
001 (UpgradeEffectDescriber, low, 依存なし)
  → 002 (PurchaseConfirmDialog, medium, 依存: 001)
      → 003 (WorkshopScreen統合, medium, 依存: 002)
```

## Cross-Plan Dependencies

なし（`workshop`/`workshop-ui`両Planの既存インターフェース（`PurchaseValidator`, `UpgradeMaster`, `WorkshopScreen`, `GameState.apply_upgrade()`）を変更せず利用するのみ）。
