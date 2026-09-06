---
id: "001"
title: "GameStateに新規ゲーム用リセットAPIを追加する"
status: done
priority: 1
dependencies: []
estimated_complexity: low
---

# Task: GameStateに新規ゲーム用リセットAPIを追加する

## Goal

「タイトルに戻る→新規スロットで はじめから」を選んだ際に前回プレイの`GameState`（ゴールド・ターン等）が引き継がれてしまう潜在バグを防ぐため、本番コードパスから呼べる`GameState.reset_for_new_game()`を追加し、`SaveService.select_slot_and_restore()`の新規スロット分岐から呼び出す。

## Interfaces

```gdscript
# atelier/autoload/game_state_reset_delegate.gd（新設）
class_name GameStateResetDelegate
const GameStateScript = preload("res://autoload/game_state.gd")

## reset_for_test()とreset_for_new_game()が共有する初期値適用の実体。
## 既存reset_for_test()本体（_current_phase等の全フィールド代入）をここへ移設する。 🔵
static func apply_default_state(state: GameStateScript) -> void
```

```gdscript
# atelier/autoload/game_state.gd（既存ファイルの変更）

## 本番コードパスから呼べる新規ゲーム用リセットAPI。reset_for_test()と異なり
## OS.is_debug_build()ガードを持たない（SaveService.select_slot_and_restore()の
## 新規スロット分岐から呼ばれる想定）。 🔵
func reset_for_new_game() -> void:
	GameStateResetDelegate.apply_default_state(self)

## 既存メソッド。内部実装をGameStateResetDelegate.apply_default_state()へ委譲するよう変更する。
## ガード（OS.is_debug_build()アサート）はそのまま維持する。 🔵
func reset_for_test() -> void:
	if not GameStateTestSupport.guard("reset_for_test"):
		return
	GameStateResetDelegate.apply_default_state(self)
```

```gdscript
# atelier/autoload/save_service.gd（既存メソッドの変更、select_slot_and_restore内）

func select_slot_and_restore(slot: int) -> Result:
	# ...既存の前半は変更なし...
	if result.error_code == ERROR_FILE_NOT_FOUND:
		GameState.reset_for_new_game()  # 🔵 新規追加。前回プレイの値をクリアする
		return Result.ok()
	# ...
```

## Test Strategy

- [ ] `reset_for_new_game()`呼び出し後、`GameState.get_state()`の`gold`・`current_turn`・`current_phase`等が初期値に戻る
- [ ] `reset_for_new_game()`は`OS.is_debug_build()`に関わらず（本番ビルド相当でも）呼び出せる（`reset_for_test()`のようなガードで早期returnしない）
- [ ] `reset_for_test()`は従来どおり`OS.is_debug_build()`が偽の状況で早期returnし、内部状態を変更しない（既存挙動の非デグレ確認）
- [ ] `SaveService.select_slot_and_restore(slot)`を「ゴールドを加算した状態」で新規スロット（未使用スロット）に対して呼ぶと、呼び出し後`GameState.get_state()["gold"]`が0に戻る
- [ ] `SaveService.select_slot_and_restore(slot)`を既存スロット（セーブ済み）に対して呼んでも、この時点では`GameState`は変更されない（`_pending_restore`に載るのみ。`apply_pending_restore()`はMainScene側の責務のため本タスクでは検証済み動作を壊さないことのみ確認）
- [ ] 破損スロット（`ERROR_SAVE_DATA_CORRUPTED`）選択時は`reset_for_new_game()`が呼ばれない（既存の「破損時はactive_slotのみ更新」という挙動を変えない）

## Implementation Notes

- 参照すべき既存コード: `atelier/autoload/game_state.gd`の既存`reset_for_test()`実装本体（全フィールド代入部分）、`atelier/autoload/game_state_test_support.gd`の`guard()`、`atelier/autoload/save_service.gd`の`select_slot_and_restore()`
- 既存の`reset_for_test()`が代入している全フィールドを漏れなく`GameStateResetDelegate.apply_default_state()`へ移設すること（コピペミスで一部フィールドだけ本番リセットから漏れると、そのフィールドだけ前回値が残留するバグになる）
- `GameStateResetDelegate`は`features/`配下の機能ロジックではなく`GameState`自身の内部実装分割のため、既存の`game_state_{garden,alchemy,guild,rank,workshop}_delegate.gd`と同じ`atelier/autoload/`配下に置く（500行対策の委譲パターンを踏襲）
- 呼び出し順序に注意: `select_slot_and_restore()`は`active_slot = slot`の代入・`_pending_restore = {}`のクリアの**後**に判定するため、`reset_for_new_game()`の追加はこれらの代入を壊さない位置（`ERROR_FILE_NOT_FOUND`分岐の中）に置くこと

## Files

- 新規: `atelier/autoload/game_state_reset_delegate.gd`
- 変更: `atelier/autoload/game_state.gd`
- 変更: `atelier/autoload/save_service.gd`
- テスト: `atelier/tests/integration/test_game_state_reset.gd`（新規、`reset_for_new_game()`/`reset_for_test()`の非デグレを検証）
- テスト: `atelier/tests/integration/test_save_service_pending_restore.gd`（既存ファイルへ「新規スロット選択でGameStateがリセットされる」ケースを追加）
