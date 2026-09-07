---
id: "002"
title: "PurchaseConfirmDialogを実装する"
status: done
priority: 1
dependencies: ["001"]
estimated_complexity: medium
---

# Task: PurchaseConfirmDialogを実装する

## Goal

アイテム名・価格・効果説明を表示し「購入する」「キャンセル」の2択を提示する確認ダイアログコンポーネントを実装する。確認/キャンセルいずれの場合も自身を`queue_free()`し、呼び出し元へシグナルで結果を通知する。

## Interfaces

```gdscript
# atelier/features/workshop/ui/purchase_confirm_dialog.gd
class_name PurchaseConfirmDialog
extends Control

signal confirmed(upgrade_id: StringName)  # 🔵 「購入する」押下時。呼び出し元がGameState.apply_upgrade()を実行する起点
signal cancelled  # 🔵 「キャンセル」押下・Escapeキー押下時。状態は一切変更しない

## 表示内容を設定する。UpgradeEffectDescriber.describe()の結果が空文字列の場合、
## 効果説明ラベルは空表示のままにする（🟡 未知effect_typeは実運用では到達しない防御的分岐）
func setup(upgrade: UpgradeMaster) -> void:  # 🔵
	pass

## 現在表示中のアイテム名/価格/効果説明を返す（テスト用）
func get_name_text() -> String: pass  # 🔵 SettingsPanel.get_bgm_slider_value()と同型のテスト用ゲッター
func get_price_text() -> String: pass  # 🔵
func get_effect_text() -> String: pass  # 🔵

## SettingsPanel.open_singleton() / PauseMenu.open_singleton()と同型の多重起動防止パターン。
## 本ダイアログは「確認」「キャンセル」で呼び出し元の後続処理が異なるため、
## 単一のclosedシグナルではなくon_confirmed/on_cancelledの2コールバックを受け取る点が差分
static func open_singleton(
	current: PurchaseConfirmDialog,
	overlay_parent: Node,
	upgrade: UpgradeMaster,
	on_confirmed: Callable,
	on_cancelled: Callable,
) -> PurchaseConfirmDialog:  # 🔵
	pass
```

信号機:
- 🔵 シグナル/`setup()`/`open_singleton()`のシグネチャ: `SettingsPanel`/`PauseMenu`の確立済みパターンをそのまま踏襲
- 🟡 Escapeキー（`ui_cancel`）の扱い: `SettingsPanel._unhandled_input()`と同じ実装（`get_viewport().set_input_as_handled()`後に`_on_cancel_pressed()`相当を呼ぶ）。確認ダイアログでのEscape既定動作は明示要件がないため、既存コンポーネントとの一貫性を優先する判断

## Test Strategy

- [ ] `setup(upgrade)`呼び出し後、`get_name_text()`が`upgrade.name`と一致する
- [ ] `setup(upgrade)`呼び出し後、`get_price_text()`が`"%d G" % upgrade.price`形式と一致する（`UpgradeItemRow._price_label`と同一フォーマット）
- [ ] `setup(upgrade)`呼び出し後、`get_effect_text()`が`UpgradeEffectDescriber.describe(upgrade)`の結果と一致する
- [ ] 「購入する」ボタン押下で`confirmed(upgrade.id)`が発行され、ノードが`queue_free()`される
- [ ] 「キャンセル」ボタン押下で`cancelled`が発行され、ノードが`queue_free()`される。GameStateの状態は変更されない（本コンポーネント自体はGameStateを一切参照しないため、シグナル未接続時に副作用が起きないことで代替検証する）
- [ ] Escapeキー（`ui_cancel`アクション）押下でキャンセルボタン押下と同じ結果（`cancelled`発行＋`queue_free()`）になる
- [ ] エッジケース: `open_singleton(null, overlay, upgrade_a, ...)`で新規生成された後、解放前に`open_singleton(existing, overlay, upgrade_b, ...)`を呼んでも新規生成されず既存インスタンスがそのまま返る（`SettingsPanel.open_singleton()`と同じ多重起動防止の検証パターン）
- [ ] エッジケース: `queue_free()`呼び出し後の同一フレーム内に確認・キャンセルが重複して押されても、2回目以降は`is_queued_for_deletion()`で早期returnしシグナルが二重発行されない（`SettingsPanel._on_close_pressed()`の防御パターンを踏襲）

## Implementation Notes

- 参照すべき既存コード: `atelier/shared/ui/settings_panel.gd`（`_unhandled_input()`によるEscape処理、`open_singleton()`の多重起動防止、`is_queued_for_deletion()`ガード）
- 参照すべき既存コード: `atelier/shared/ui/settings_panel.tscn`（フラットな`VBoxContainer`構成、テーマは`project.godot`の`theme/custom`がプロジェクト全体に適用されるため本ダイアログのシーンで明示的な`theme = MAIN_THEME`指定は不要 — `workshop_screen.tscn`も同様に指定していない）
- 参照すべき既存コード: `atelier/features/workshop/ui/upgrade_item_row.gd`（`"%d G" % price`という価格表示フォーマット）
- `.tscn`のノード構成（案）: ルート`Control`（`PurchaseConfirmDialog`）→ `RootContainer`(`VBoxContainer`, `unique_name_in_owner`) → `NameLabel`, `PriceLabel`, `EffectLabel`, `ButtonRow`(`HBoxContainer`) → `ConfirmButton`, `CancelButton`（いずれも`unique_name_in_owner = true`）
- 依存: `UpgradeEffectDescriber`（task 001）を`setup()`内で呼び出す

## Files

- 新規: `atelier/features/workshop/ui/purchase_confirm_dialog.gd`
- 新規: `atelier/features/workshop/ui/purchase_confirm_dialog.tscn`
- テスト: `atelier/tests/integration/test_purchase_confirm_dialog.gd`
