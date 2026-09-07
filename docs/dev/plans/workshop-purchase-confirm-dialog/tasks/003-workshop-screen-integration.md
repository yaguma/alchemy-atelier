---
id: "003"
title: "WorkshopScreenに恒久投資購入時の確認ダイアログを統合する"
status: done
priority: 2
dependencies: ["002"]
estimated_complexity: medium
---

# Task: WorkshopScreenに恒久投資購入時の確認ダイアログを統合する

## Goal

`WorkshopScreen`で恒久投資アイテムの購入要求を受けた場合、即時購入せず`PurchaseConfirmDialog`を開いて確認を挟む。消耗投資は現行通り即時購入のまま変更しない。

## Interfaces

```gdscript
# atelier/features/workshop/ui/workshop_screen.gd（既存クラスへの変更）

@onready var _overlay_layer: Control = %OverlayLayer  # 🔵 新規ノード、pause_menu.tscnのOverlayLayerと同型

var _confirm_dialog: PurchaseConfirmDialog = null  # 🔵 SettingsPanel参照フィールドと同型

## 「恒久投資 かつ can_purchase_permanent(タブ活性)」の場合のみダイアログを開いて保留する。
## それ以外（消耗投資、または恒久投資だがタブ非活性）は即時_execute_purchase()を呼ぶ。
## タブ非活性時に即時実行へ落とすのは、既存テスト
## test_恒久投資タブが非活性の状態で恒久投資アイテムを購入要求すると状態が変化せず失敗トーストが表示される()
## （test_workshop_screen.gd:267-276）がGameState.apply_upgrade()の"workshop_closed"失敗と
## 失敗トースト表示をボタンdisabled状態を経由せず直接検証しているため、ダイアログを挟むと
## この既存の防御的検証（FR-403の多層防御）が壊れることへの対応
func _on_purchase_requested(upgrade_id: StringName) -> void:  # 🔵 既存関数を変更
	pass

## 既存の_on_purchase_requested()内にあった「GameState.apply_upgrade()呼び出し→_refresh()→
## トースト表示」を抽出したもの。即時購入経路（消耗投資）とダイアログ確認後経路（恒久投資）の
## 両方から呼ばれる
func _execute_purchase(upgrade: UpgradeMaster) -> void:  # 🔵 既存ロジックの抽出のみ、挙動変更なし
	pass

## PurchaseConfirmDialog.confirmedのハンドラ。upgrade_idからUpgradeMasterを再解決してから
## _execute_purchase()を呼ぶ（_on_purchase_requested()と同じ解決パターンを踏襲）
func _on_purchase_confirmed(upgrade_id: StringName) -> void:  # 🔵
	pass

## PurchaseConfirmDialog.cancelledのハンドラ。_confirm_dialog参照をnullへ戻すのみ
func _on_purchase_confirm_cancelled() -> void:  # 🔵
	pass

## 確認ダイアログが開いているかを返す（テスト用）
func is_confirm_dialog_open() -> bool:  # 🟡 WorkshopScreen.get_toast_text()等の既存テスト用ゲッターに倣った新規補完
	pass
```

信号機:
- 🔵 ダイアログを開く条件は`PurchaseValidator.is_permanent_upgrade(upgrade) and state["can_purchase_permanent"]`の両方を満たす場合のみ（`purchase_validator.gd:14`、`state["can_purchase_permanent"]`は既存公開フィールド）
- 🔵 `_execute_purchase()`の中身は現行`_on_purchase_requested()`（`workshop_screen.gd:130-143`）の抽出のみで、成功/失敗時のトースト文言・`_refresh()`呼び出しタイミングは一切変更しない
- 🟡 `_on_purchase_confirm_cancelled()`はトースト表示を行わない（キャンセル操作は「何も起きなかった」ことが期待される通常操作であり、`SettingsPanel`/`PauseMenu`の「閉じる」がトースト等の副作用を伴わないことと一貫させる判断）
- 🟡 恒久投資かつゴールド不足/購入済み上限到達の状態で（ボタンdisabledをすり抜けて）ダイアログを開いた場合、「購入する」確定後に`GameState.apply_upgrade()`が改めて失敗し通常の失敗トーストが出る想定（Presentationでの重複バリデーションを避け、architecture.md「検証責務のレイヤー配置原則」＝実行直前の再検証はApplication層(GameState)が行う、をダイアログ確定後の経路でも一貫させる）

## Test Strategy

- [ ] 消耗投資アイテムの購入ボタン押下で、ダイアログを経由せず即座に`GameState.apply_upgrade()`相当の結果（ゴールド減算・購入成功トースト）が反映される（既存挙動の非破壊確認。既存の`atelier/tests/integration/test_workshop_screen.gd`が継続してパスすること）
- [ ] 恒久投資アイテムの購入ボタン押下で、`GameState`のゴールドが変化せず、`is_confirm_dialog_open()`が`true`になる
- [ ] 恒久投資の確認ダイアログで「購入する」を押すと、`GameState.apply_upgrade()`が実行され（ゴールド減算・効果反映）、購入成功トーストが表示され、`is_confirm_dialog_open()`が`false`に戻る
- [ ] 恒久投資の確認ダイアログで「キャンセル」を押すと、`GameState`のゴールド・購入済み回数が一切変化せず、トーストも表示されず、`is_confirm_dialog_open()`が`false`に戻る
- [ ] **回帰確認（必須）**: `can_purchase_permanent == false`の状態で`screen._on_purchase_requested(&"upgrade_recipe_unlock_mana_tonic")`を直接呼んでも、ダイアログを開かず`GameState`のゴールド・購入済み回数が変化せず失敗トースト（`"購入できませんでした"`を含む）が表示される。既存テスト`test_恒久投資タブが非活性の状態で恒久投資アイテムを購入要求すると状態が変化せず失敗トーストが表示される()`（`test_workshop_screen.gd:267-276`）が無改修のまま引き続きパスすることを確認する
- [ ] エッジケース: 確認ダイアログ表示中に同じ恒久投資アイテムへ重複してダイアログを開こうとしても、新規ダイアログが多重生成されない（`PurchaseConfirmDialog.open_singleton()`の多重起動防止がWorkshopScreen経由でも機能することの確認）

## Implementation Notes

- 参照すべき既存コード: `atelier/features/workshop/ui/workshop_screen.gd`の現行`_on_purchase_requested()`（抽出元）、`_on_close_pressed()`（`_refresh()`呼び出しタイミングの参考）
- 参照すべき既存コード: `atelier/shared/ui/pause_menu.gd`の`_on_settings_pressed()`/`_on_settings_panel_closed()`（`open_singleton()`呼び出し→コールバックで参照をnullに戻すペアの書き方）
- `workshop_screen.tscn`に`OverlayLayer`ノード（`pause_menu.tscn`の`OverlayLayer`と同じプロパティ: `unique_name_in_owner = true`, `anchors_preset = 15`, `mouse_filter = 2`）を`VBoxContainer`と同階層（`WorkshopScreen`直下）の最後の子として追加する。最後の子にすることで描画順が最前面になる
- `_on_purchase_confirmed()`内での`upgrade_masters.get(upgrade_id)`解決が失敗するケース（`null`または非`UpgradeMaster`）は、既存の`_on_purchase_requested()`と同じ早期returnガードを踏襲する

## Files

- 変更: `atelier/features/workshop/ui/workshop_screen.gd`
- 変更: `atelier/features/workshop/ui/workshop_screen.tscn`
- テスト: `atelier/tests/integration/test_workshop_screen_purchase_confirm.gd`（既存の購入フローテストファイルがあれば、そちらへのケース追加も可）
