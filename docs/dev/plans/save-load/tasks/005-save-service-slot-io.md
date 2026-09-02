---
id: "005"
title: "SaveServiceにスロットファイルI/Oを実装する"
status: done
priority: 2
dependencies: ["002", "004"]
estimated_complexity: high
---

# Task: SaveServiceにスロットファイルI/Oを実装する

## Goal

新規Autoload `SaveService` を追加し、3固定スロットへのセーブデータの読み書きと、スロット選択UI向けの要約取得機能を実装する。ファイルI/Oを行うImperative Shellとして`SaveDataCodec`（logic/）を利用する。

## Interfaces

```gdscript
# atelier/features/save_load/state/save_slot_summary.gd
## スロット選択画面表示用の要約データ（🔵 UIコンポーネント設計ルールのstate型パターン）
class_name SaveSlotSummary
extends RefCounted

var slot_index: int = 0
var is_empty: bool = true       # trueならそのスロットにセーブファイルが存在しない
var is_corrupted: bool = false  # trueならファイルは存在するがchecksum不一致等で読めない
var gold: int = 0
var current_rank_id: String = ""
var current_turn: int = 0
var saved_at_unix: int = 0
```

```gdscript
# atelier/autoload/save_service.gd（新規Autoload。project.godotへの登録が必要）
extends Node

const SLOT_COUNT := 3  # 🟡 ゲームバランスに影響しないためGameBalance対象外（coding-style.md判断基準）。専用constとしてSaveService自身に置く
const SAVE_DIR := "user://saves"

## slot（0〜SLOT_COUNT-1）に対応する保存先ファイルパスを返す
static func _slot_path(slot: int) -> String

## 現在のGameStateの状態をslotへ即座に保存する。
## I/O失敗時（ディレクトリ作成失敗・ファイルオープン失敗）はResult.fail()を返す
func save_to_slot(slot: int) -> Result

## slotから読み込み、検証済みDictionaryをResult.ok(value)で返す。
## ファイル不在・破損（チェックサム不一致・型不一致）の場合はResult.fail()を返す
func load_from_slot(slot: int) -> Result

## slot選択画面表示用の要約を返す。ファイル不在ならis_empty=trueのSaveSlotSummaryを返し、
## 破損していればis_corrupted=trueのSaveSlotSummaryを返す（例外を投げない）
func get_slot_summary(slot: int) -> SaveSlotSummary
```

## Test Strategy

- [ ] `save_to_slot(0)`実行後、`user://saves/slot_0.json`相当のファイルが作成され、`load_from_slot(0)`で`Result.success == true`かつ`collect_save_data()`と同内容のDictionaryが返る（ラウンドトリップ）
- [ ] 存在しないスロットに対する`load_from_slot()`は`Result.success == false`を返す
- [ ] `save_to_slot()`で保存したファイルの内容を1文字破壊してから`load_from_slot()`すると`Result.success == false`を返す（チェックサム不一致検出）
- [ ] `get_slot_summary()`が、未保存スロットに対して`is_empty == true`のSaveSlotSummaryを返す
- [ ] `get_slot_summary()`が、保存済みスロットに対して`is_empty == false`かつ`gold`/`current_rank_id`/`current_turn`/`saved_at_unix`が保存時の値と一致するSaveSlotSummaryを返す
- [ ] `get_slot_summary()`が、破損したスロットに対して`is_corrupted == true`のSaveSlotSummaryを返す（例外を投げない）
- [ ] `save_to_slot()`が保存対象データに`saved_at_unix`（`Time.get_unix_time_from_system()`）を自動付与する

## Implementation Notes

- 参照すべき既存コード: `.claude/rules/security.md`の`save()`/`load_save_data()`サンプル（`FileAccess.open()`, `DirAccess.make_dir_recursive_absolute()`のエラーハンドリングパターン）
- 実装のヒント: `save_to_slot()`は`GameStateSaveDelegate.collect_save_data(GameState)`で取得したDictionaryへ`saved_at_unix`を追加してから`SaveDataCodec.wrap_with_checksum()`でラップし、`JSON.stringify()`して書き込む。`load_from_slot()`は`FileAccess.get_as_text()`→`JSON.new().parse()`→`SaveDataCodec.validate_and_unwrap()`の順で処理する
- 注意事項: GdUnit4の`--headless`実行でも`FileAccess`によるユーザーデータ書き込みは可能（`.claude/rules/godot-debug-tools.md`の「スクリーンショット撮影は--headless不可」という制約はレンダリング系APIのみが対象であり、`FileAccess`には該当しない）。テストは`before_test()`/`after_test()`で対象スロットのファイルを確実に削除し、他テストや実プレイデータに影響を残さないこと（テスト専用に予約したスロット番号を使うか、テスト後に`DirAccess.remove_absolute()`で削除する）

## Files

- 新規: `atelier/features/save_load/state/save_slot_summary.gd`
- 新規: `atelier/autoload/save_service.gd`
- 変更: `atelier/project.godot`（`[autoload]`セクションに`SaveService="*res://autoload/save_service.gd"`を追加）
- テスト: `atelier/tests/integration/test_save_service_slot_io.gd`
