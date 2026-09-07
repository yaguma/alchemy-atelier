class_name PurchaseConfirmDialog
extends Control

## 🔵 恒久投資アイテムの購入前に挟む確認ダイアログ。表示専用コンポーネントであり、
## GameStateもDomain層も参照しない（購入の実行は呼び出し元がconfirmedを受けて行う）。
## SettingsPanel/PauseMenuと同型のオーバーレイコンポーネントだが、確認とキャンセルで
## 呼び出し元の後続処理が分岐するため、closedではなく2種のシグナルを発行する。

## 🔵 「購入する」押下時。呼び出し元がGameState.apply_upgrade()を実行する起点
signal confirmed(upgrade_id: StringName)
## 🔵 「キャンセル」押下・Escapeキー押下時。状態は一切変更しない
signal cancelled

## 🔵 Godot組み込みアクション。既定でEscapeキーが割り当てられている
const ACTION_CANCEL: StringName = &"ui_cancel"
# 🔵 workshop_screen.gd/upgrade_item_row.gdのゴールド・価格表示フォーマットを踏襲する
# （rank_hud.gd GOLD_FORMATと同じく、他Featureのui/を参照しない運用ルールに従い
# 定数自体をコンポーネントごとに再定義する）
const PRICE_FORMAT := "%d G"

var _upgrade_id: StringName = &""

@onready var _name_label: Label = %NameLabel
@onready var _price_label: Label = %PriceLabel
@onready var _effect_label: Label = %EffectLabel
@onready var _confirm_button: Button = %ConfirmButton
@onready var _cancel_button: Button = %CancelButton


func _ready() -> void:
	# 🔵 自ノード配下のsignalのため_exit_tree()でのdisconnectは不要
	_confirm_button.pressed.connect(_on_confirm_pressed)
	_cancel_button.pressed.connect(_on_cancel_pressed)


## 🟡 SettingsPanel._unhandled_input()と同じ扱い。確認ダイアログでのEscape既定動作は
## 明示要件がないため、既存コンポーネントとの一貫性を優先しキャンセル扱いとする
func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(ACTION_CANCEL):
		return
	get_viewport().set_input_as_handled()
	_on_cancel_pressed()


## 🔵 表示内容を設定する。UpgradeEffectDescriber.describe()が空文字列を返す場合
## （🟡 未知effect_type。実運用では到達しない防御的分岐）は効果説明を空表示のままにする
func setup(upgrade: UpgradeMaster) -> void:
	_upgrade_id = upgrade.id
	_name_label.text = upgrade.name
	_price_label.text = PRICE_FORMAT % upgrade.price
	_effect_label.text = UpgradeEffectDescriber.describe(upgrade)


## 🔵 現在表示中のアイテム名を返す（テスト用の観測点）
func get_name_text() -> String:
	return _name_label.text


## 🔵 現在表示中の価格を返す（テスト用の観測点）
func get_price_text() -> String:
	return _price_label.text


## 🔵 現在表示中の効果説明を返す（テスト用の観測点）
func get_effect_text() -> String:
	return _effect_label.text


func _on_confirm_pressed() -> void:
	# 🔴 queue_free()はフレーム終了まで解放を遅らせるため、同一フレーム内に届いた
	# 2つ目の操作（連打・確認とキャンセルの重複）でシグナルが二重に発行されうる
	if is_queued_for_deletion():
		return

	confirmed.emit(_upgrade_id)
	_detach_and_free()


func _on_cancel_pressed() -> void:
	if is_queued_for_deletion():
		return

	cancelled.emit()
	_detach_and_free()


## 🔴 コードレビュー指摘対応。queue_free()は実際の解放をフレーム終了まで遅延させるため、
## その間ノードはツリーに残り続ける。同一フレーム内で別アイテムの購入要求によりopen_singleton()
## が新規ダイアログをoverlay_parentへadd_child()すると、name一意化により新規ノードの方が
## リネームされ、find_child("PurchaseConfirmDialog", ...)（テストヘルパーが使用）が
## 解放待ちの本ノードに誤って一致してしまう。
## 🔴 当初はremove_child()でツリーから即座に切り離す実装にしたが、GdUnit4のscene_runnerは
## _unhandled_input()呼び出し直後に無条件でcurrent_scene.get_viewport()を呼ぶ実装のため
## （GdUnitSceneRunnerImpl.gd _handle_input_event()）、ダイアログ自身がscene_runner()の
## シーンルートであるテスト（Escapeキー押下テスト）でget_viewport()がnullを返しクラッシュした。
## 実際に問題なのは「find_child()が名前で古いノードを誤って拾うこと」のみなので、
## ツリーからの離脱ではなく名前の変更で解決する（ノードはツリーに残るためget_viewport()は
## 引き続き有効。実運用上も名前が変わるだけで見た目・入力には影響しない）
func _detach_and_free() -> void:
	name = "PurchaseConfirmDialog_PendingFree"
	queue_free()


## 🔵 SettingsPanel.open_singleton()と同型の多重起動防止ヘルパー。既存インスタンスが
## 生存していれば新規生成せずそれを返す（表示内容の差し替えも行わない）。
## 確認/キャンセルで呼び出し元の後続処理が異なるため、コールバックを2つ受け取る点が差分
static func open_singleton(
	current: PurchaseConfirmDialog,
	overlay_parent: Node,
	upgrade: UpgradeMaster,
	on_confirmed: Callable,
	on_cancelled: Callable
) -> PurchaseConfirmDialog:
	if is_instance_valid(current):
		return current
	var dialog: PurchaseConfirmDialog = (
		(preload("res://features/workshop/ui/purchase_confirm_dialog.tscn") as PackedScene)
		. instantiate()
	)
	dialog.confirmed.connect(on_confirmed)
	dialog.cancelled.connect(on_cancelled)
	overlay_parent.add_child(dialog)
	# 🔵 @onreadyの解決後（add_child後）でなければラベルへ代入できないため、ここでsetupする
	dialog.setup(upgrade)
	return dialog
