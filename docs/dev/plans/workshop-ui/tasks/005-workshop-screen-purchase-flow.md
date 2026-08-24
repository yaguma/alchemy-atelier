---
id: "005"
title: "WorkshopScreenに購入フローを実装する"
status: done
priority: 3
dependencies: ["004"]
estimated_complexity: medium
---

# Task: WorkshopScreenに購入フローを実装する

## Goal

`WorkshopScreen`（task 004で作成済み）に、`UpgradeItemList.purchase_requested`シグナルを受けて`GameState.apply_upgrade()`を呼び出す購入フローを追加する。成功時は一覧を再構築し成功トーストを表示、失敗時は再構築せず失敗トーストを表示する（FR-101, FR-102, FR-103, NFR-101）。

## Interfaces

```gdscript
# atelier/features/workshop/ui/workshop_screen.gd への追加分（既存の_ready()を拡張する）

const TOAST_PURCHASE_SUCCESS_FORMAT := "購入しました：%s"    # 🟡 文言は暫定
const TOAST_PURCHASE_FAILURE_FORMAT := "購入できませんでした（%s）"  # 🟡 文言は暫定。%sはResult.error_code

func _ready() -> void:
	_permanent_tab_button.pressed.connect(_on_permanent_tab_pressed)
	_consumable_tab_button.pressed.connect(_on_consumable_tab_pressed)
	# 🔵 本タスクで追加: 両リストからの購入要求を受ける
	_permanent_list.purchase_requested.connect(_on_purchase_requested)
	_consumable_list.purchase_requested.connect(_on_purchase_requested)
	_refresh()

## 現在表示中のトーストメッセージを返す（テスト用）。🔵 GardenScreen.get_toast_text()踏襲
func get_toast_text() -> String:
	if _toast_label == null:
		return ""
	return _toast_label.text

## FR-101: 購入要求を受けてGameState.apply_upgrade()を呼び出す。
## upgrade_idからUpgradeMasterへの解決に失敗した場合（マスター未登録ID）は状態変更を一切行わず
## 早期returnする（🟡 UpgradeItemList/UpgradeItemRowは常にGameState.get_state()由来の
## upgrade.idしか発行しないため実運用では起こらないが、防御的分岐として残す）
func _on_purchase_requested(upgrade_id: StringName) -> void:
	var state := GameState.get_state()
	var upgrade_masters: Dictionary = state["upgrade_masters"]
	var upgrade: Variant = upgrade_masters.get(upgrade_id)
	if not (upgrade is UpgradeMaster):
		return

	var result := GameState.apply_upgrade(upgrade as UpgradeMaster)
	if result.success:
		_refresh()  # 🔵 FR-102
		_show_toast(TOAST_PURCHASE_SUCCESS_FORMAT % (upgrade as UpgradeMaster).name)
	else:
		_show_toast(TOAST_PURCHASE_FAILURE_FORMAT % result.error_code)  # 🔵 FR-103

func _show_toast(message: String) -> void:
	if _toast_label == null:
		return
	_toast_label.text = message
```

> 信号機: 🔵 FR-101〜FR-103・NFR-101（既存パターン踏襲）に基づく。トースト文言そのもの（`TOAST_PURCHASE_SUCCESS_FORMAT`等の具体的な日本語）は🟡（workshop-shop.md未確定、`GardenScreen`の文言慣習に倣った妥当な推測）。

## Test Strategy

- [ ] ゴールドが十分な状態で購入ボタン相当（`%ConsumableList`内の対象行の購入ボタン、または`_on_purchase_requested()`を直接呼び出す形でも可）を実行すると、`GameState.get_state()["gold"]`が価格分減少し、`%GoldLabel`の表示も再構築後の値に更新される
- [ ] 購入成功後、`get_toast_text()`が成功を示すメッセージ（購入したアイテム名を含む）を返す
- [ ] 購入成功後、`GameState.get_purchased_count(upgrade.id)`が1増加し、対象行の購入ボタンが再構築後の一覧上で「購入済み」または新しい状態を正しく反映する（`max_purchase_count == 1`のアイテムで確認する）
- [ ] ゴールド不足の状態で購入を試みると（`apply_upgrade()`が`Result.fail`を返す状態を`_set_gold_for_test()`で作る）、`GameState.get_state()["gold"]`は変化せず、`get_toast_text()`が失敗を示すメッセージを返す
- [ ] 購入済み上限到達の状態で購入を試みると、同様に状態が変化せず失敗トーストが表示される（`_set_purchased_upgrade_counts_for_test()`で上限到達状態を注入して確認する）
- [ ] 恒久投資タブが非活性（`can_purchase_permanent == false`）の状態で、恒久投資アイテムに対する購入要求（`_on_purchase_requested()`を直接呼び出す形で、UIのdisabledをすり抜けたケースを模擬する）が発生しても、`apply_upgrade()`内の`PurchaseValidator`再検証により状態変更が起きず失敗トーストになる（NFR-101: UI側の先出し判定を信頼しないことの検証）
- [ ] エッジケース: マスター未登録の`upgrade_id`で`_on_purchase_requested()`を直接呼び出しても、クラッシュせず`GameState`の状態（ゴールド・購入回数）が変化しない

## Implementation Notes

- 参照すべき既存コード: `atelier/features/garden/ui/garden_screen.gd`（`_on_seed_plant_requested()`のようなリクエスト受信→GameState API呼び出しのパターン、`_show_toast()`実装）、`atelier/autoload/game_state_workshop_delegate.gd`（`apply_upgrade()`が失敗時に一切状態変更しないことをテストの前提として利用する）
- 実装のヒント: `_on_purchase_requested()`はGameStateの`apply_upgrade()`一回の呼び出しに閉じる。成功/失敗の分岐後の`_refresh()`は成功時のみ（失敗時は`GameState`側で状態変更が起きていないため、再構築しても表示は変わらず無駄な処理になる、FR-103）
- 注意事項: `PurchaseValidator`をこのファイルから直接呼び出さない。UI側で「ゴールド不足だから送信しない」といった事前フィルタは`UpgradeItemRow`のdisabled制御に既に存在するため、`_on_purchase_requested()`自体に追加のガードロジックを重複させない（`apply_upgrade()`が最終権威、NFR-101）

## Files

- 変更: `atelier/features/workshop/ui/workshop_screen.gd`
- テスト: `atelier/tests/integration/test_workshop_screen.gd`（task 004で作成したファイルにテストケース追加）
