---
id: "002"
title: "UpgradeItemRowコンポーネントを新規作成する"
status: done
priority: 1
dependencies: []
estimated_complexity: medium
---

# Task: UpgradeItemRowコンポーネントを新規作成する

## Goal

アイテム一覧の1行分を表示する`UpgradeItemRow`（`HBoxContainer`継承）を新規作成する。名称・価格を表示し、「購入する/ゴールド不足/購入済み」の3状態をボタンのdisabled状態+テキストで表現し、購入ボタン押下で`purchase_pressed(upgrade_id)`シグナルを発行する（FR-005, FR-204, FR-205, FR-206, FR-403, FR-404, NFR-201）。

## Interfaces

```gdscript
# atelier/features/workshop/ui/upgrade_item_row.gd
class_name UpgradeItemRow
extends HBoxContainer

## アイテム一覧の1行分を表示するコンポーネント。UpgradeItemListから動的に生成・破棄される。
## GameStateにもDomain層（PurchaseValidator）にも依存しない表示専用コンポーネント
## （SeedEntryRow/GuildDeliveryResultRowと同型）。

signal purchase_pressed(upgrade_id: StringName)  # 🔵 親（UpgradeItemList）が上位へ中継する起点

const LABEL_PURCHASE := "購入する"          # 🟡 workshop-shop.mdワイヤーフレーム準拠の暫定文言
const LABEL_GOLD_SHORTAGE := "ゴールド不足"  # 🟡 同上
const LABEL_MAX_REACHED := "購入済み"        # 🟡 同上

var _upgrade_id: StringName = &""

@onready var _name_label: Label = %NameLabel          # 🔵
@onready var _price_label: Label = %PriceLabel         # 🔵
@onready var _purchase_button: Button = %PurchaseButton  # 🔵 btn-purchase-{upgrade_id}相当

func _ready() -> void:  # 🔵 自ノードsignalのため_exit_tree()でのdisconnect不要
	_purchase_button.pressed.connect(_on_purchase_pressed)

## upgrade: 表示対象。gold: 現在の所持ゴールド。already_purchased_count: 購入済み回数。
## locked: true の場合、gold/countの結果に関わらずボタンを強制disabledにする（FR-403、
## 恒久投資タブが非活性の間に恒久投資アイテムへ渡すためのフラグ）。
## 判定優先順位は「購入済み上限到達」＞「ゴールド不足」＞「タブロック」＞「購入可能」（🟡
## AC群が組合せケース＝ゴールド不足かつ購入済み等を明示しないための実装判断。「買い切った」は
## 所持ゴールドに関わらず不変の事実であることを根拠に最優先とする）
func setup(
	upgrade: UpgradeMaster, gold: int, already_purchased_count: int, locked: bool
) -> void:  # 🔵 FR-204, FR-205, FR-206, FR-403, FR-404
	_upgrade_id = upgrade.id
	_name_label.text = upgrade.name
	_price_label.text = "%d G" % upgrade.price

	var max_reached := already_purchased_count >= upgrade.max_purchase_count
	var gold_short := gold < upgrade.price

	if max_reached:
		_purchase_button.text = LABEL_MAX_REACHED
		_purchase_button.disabled = true
	elif gold_short:
		_purchase_button.text = LABEL_GOLD_SHORTAGE
		_purchase_button.disabled = true
	else:
		_purchase_button.text = LABEL_PURCHASE
		_purchase_button.disabled = locked  # 🔵 FR-403: 買える状態でもtab非活性なら強制disabled

## 現在のボタンラベルを返す（テスト用）。🟡 SeedEntryRowに同種の公開ゲッターがないための新規補完
func get_purchase_button_text() -> String:
	return _purchase_button.text

## 現在のボタンのdisabled状態を返す（テスト用）。🟡 同上
func is_purchase_button_disabled() -> bool:
	return _purchase_button.disabled

func _on_purchase_pressed() -> void:
	purchase_pressed.emit(_upgrade_id)
```

`.tscn`構造: `HBoxContainer`（ルート、`unique_name_in_owner`は子ノードのみtrue） → `Label(%NameLabel)`, `Label(%PriceLabel)`, `Button(%PurchaseButton)`。行の`name`は親（`UpgradeItemList`）が`"UpgradeItem_%s" % upgrade.id`で設定する契約（本タスクでは`UpgradeItemRow`自身はnameを設定しない）。

## Test Strategy

- [ ] `setup()`後、名称ラベルに`upgrade.name`がそのまま表示される
- [ ] `setup()`後、価格ラベルに`"%d G" % upgrade.price`形式で表示される
- [ ] 所持ゴールドが価格以上・購入済み回数が上限未満・`locked=false`の場合、購入ボタンは有効（`is_purchase_button_disabled() == false`）かつラベルが「購入する」になる
- [ ] 所持ゴールドが価格未満の場合、購入ボタンは無効かつラベルが「ゴールド不足」になる
- [ ] 購入済み回数が`max_purchase_count`以上の場合、購入ボタンは無効かつラベルが「購入済み」になる
- [ ] `locked=true`かつ購入可能な条件（ゴールド十分・未達上限）の場合、購入ボタンは無効になるがラベルは「購入する」のまま変わらない（FR-403: ロックはdisabledのみに影響し、ラベルは変えない）
- [ ] 購入ボタン押下で`purchase_pressed`シグナルが`upgrade.id`を引数に発行される
- [ ] 境界値: 所持ゴールドがちょうど価格と同額の場合、ゴールド不足とは判定されず購入可能になる（`gold >= price`の等号を含む境界）
- [ ] 境界値: 購入済み回数がちょうど`max_purchase_count - 1`の場合は購入可能、`max_purchase_count`ちょうどの場合は購入済み扱いになる
- [ ] エッジケース（優先順位）: ゴールド不足かつ購入済み上限到達の両方に該当する場合、「購入済み」表示が優先される

## Implementation Notes

- 参照すべき既存コード: `atelier/features/garden/ui/seed_entry_row.gd`（3層構成のRowパターン、`_ready()`でのシグナル接続、`setup()`契約）、`atelier/features/guild/ui/guild_delivery_result_row.gd`（Row単体のGdUnit4ユニットテスト構成の実例）、`atelier/features/workshop/logic/purchase_validator.gd`（`can_purchase()`の判定条件そのものは呼び出さないが、同じ入力パラメータ形状を参考にする）
- 実装のヒント: `.tscn`は`seed_entry_row.tscn`をコピーして構造を流用してよい（`HBoxContainer`ルート、`unique_name_in_owner=true`の子ノード構成）。`UiTheme`定数を色・フォントサイズに使用しハードコードしない
- 注意事項: `PurchaseValidator`を直接呼び出さない（NFR-101: 最終権威は`apply_upgrade()`内の再検証。本コンポーネントは表示用の先出し判定のみ）。GameStateにも依存しない（NFR-301のRow契約）

## Files

- 新規: `atelier/features/workshop/ui/upgrade_item_row.gd`
- 新規: `atelier/features/workshop/ui/upgrade_item_row.tscn`
- テスト: `atelier/tests/unit/features/workshop/test_upgrade_item_row.gd`
