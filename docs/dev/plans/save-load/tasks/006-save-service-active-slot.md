---
id: "006"
title: "SaveServiceにactive_slot管理と保留復元の受け渡しを実装する"
status: done
priority: 2
dependencies: ["005"]
estimated_complexity: medium
---

# Task: SaveServiceにactive_slot管理と保留復元の受け渡しを実装する

## Goal

スロット選択画面で選ばれたスロットを「以後のオートセーブ書き込み先」として記憶し、マスターデータロード前に読み込んだセーブデータを、マスターデータロード後まで一時保持してから`GameState`へ適用する2段階復元の受け渡し口を実装する（`plan.md`の「マスターデータ参照解決の順序問題と対策」節を参照）。

## Interfaces

```gdscript
# atelier/autoload/save_service.gd に追記

var active_slot: int = -1  # -1 = 未選択（スロット選択前、またはテスト環境のデフォルト）
var _pending_restore: Dictionary = {}  # 空Dictionary = 復元不要（新規ゲーム）

## slotを選択する。既存セーブがあれば読み込み・検証し、_pending_restoreへ保持する
## （この時点ではGameStateへは一切書き込まない。まだマスターデータがロードされていない可能性があるため）。
## 新規スロット（is_empty）の場合は_pending_restoreを空Dictionaryのままにする。
## 破損スロット（is_corrupted）の場合も_pending_restoreを空Dictionaryのままにし、
## Result.fail(&"save_data_corrupted")を返す（呼び出し元UIが警告表示に使う）
func select_slot_and_restore(slot: int) -> Result

## _pending_restoreが空でなければGameStateSaveDelegate.restore_save_data()経由でGameStateへ適用し、
## _pending_restoreをクリアする。空の場合は何もしない（新規ゲームのため）。
## 呼び出し前提: state.load_*_master_data()が全て実行済みであること（MainScene._enter_tree()末尾から呼ばれる想定）
func apply_pending_restore() -> void

## active_slot < 0 の場合は何もしない（テスト環境等での誤書き込み防止）。
## それ以外の場合はsave_to_slot(active_slot)を呼び、失敗時はpush_warning()するのみで例外を投げない
## （🔴 呼び出し元GameState.set_phase()がフェーズ遷移を止めないよう、戻り値を握りつぶす設計）
func autosave() -> void
```

## Test Strategy

- [ ] 空スロットに対し`select_slot_and_restore(0)`を呼ぶと`Result.success == true`かつ`active_slot == 0`、`_pending_restore`は空のままである
- [ ] 事前に`save_to_slot(1)`で保存済みのスロットに対し`select_slot_and_restore(1)`を呼ぶと`Result.success == true`かつ`_pending_restore`が保存内容と一致するDictionaryになる
- [ ] 破損したスロットに対し`select_slot_and_restore(2)`を呼ぶと`Result.success == false`（`error_code == &"save_data_corrupted"`）かつ`_pending_restore`は空のままである
- [ ] `_pending_restore`が非空の状態で`apply_pending_restore()`を呼ぶと、`GameState`の該当フィールド（例: `gold`）が復元され、呼び出し後`_pending_restore`が空になる
- [ ] `_pending_restore`が空の状態で`apply_pending_restore()`を呼んでも`GameState`に変化がない（新規ゲームのケース）
- [ ] `active_slot == -1`（未選択）の状態で`autosave()`を呼んでもファイルが作成されない
- [ ] `active_slot`を設定後`autosave()`を呼ぶと、対応するスロットファイルが更新される

## Implementation Notes

- 参照すべき既存コード: 本Plan task 004の`GameStateSaveDelegate.restore_save_data()`、task 005の`load_from_slot()`/`get_slot_summary()`
- 実装のヒント: `select_slot_and_restore()`は内部で`get_slot_summary(slot)`相当の判定（空/破損/正常）と`load_from_slot(slot)`を組み合わせる。二重読み込みを避けたい場合は`load_from_slot()`の結果だけで空/破損/正常を判定してもよい（実装者の裁量、テストが通れば内部実装は問わない）
- 注意事項: テストは`before_test()`/`after_test()`で`active_slot`を`-1`にリセットし、使用したスロットファイルを削除すること（他テストとの独立性、`.claude/rules/testing.md`）

## Files

- 変更: `atelier/autoload/save_service.gd`
- テスト: `atelier/tests/integration/test_save_service_pending_restore.gd`
