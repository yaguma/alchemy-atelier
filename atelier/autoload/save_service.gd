# 🔵 3固定スロットへのセーブデータ読み書きを担うImperative Shell（Autoload）。
# 永続化形式の組み立て・検証はSaveDataCodec（Functional Core）へ委譲し、
# 本クラスはファイルI/OとGameStateとの受け渡しのみを担う。
extends Node

const SLOT_COUNT := 3
const SAVE_DIR := "user://saves"

## 🟡 error_codeはドメインごとに呼び出し側が定義するResultの規約に従い、本クラス内で定義する。
## UIはこれらを見分けて「破損しています」「保存に失敗しました」等のメッセージを出し分ける。
const ERROR_INVALID_SLOT := &"invalid_slot"
const ERROR_DIR_CREATE_FAILED := &"dir_create_failed"
const ERROR_FILE_OPEN_FAILED := &"file_open_failed"
const ERROR_FILE_NOT_FOUND := &"file_not_found"
const ERROR_PARSE_FAILED := &"parse_failed"
const ERROR_CORRUPTED := &"corrupted"
## 🟡 スロット選択時にのみ返す破損コード。load_from_slot()のERROR_CORRUPTED/ERROR_PARSE_FAILED等を
## UI向けに1つへ畳んだもの（スロット選択画面は「読めない理由」を区別せず警告を出すため）。
const ERROR_SAVE_DATA_CORRUPTED := &"save_data_corrupted"

## 🔵 以後のオートセーブ書き込み先スロット。-1は未選択（スロット選択画面より前、テスト環境等）。
var active_slot: int = -1

## 🔵 マスターデータロード前に読み込んだセーブデータの一時保持先。
## 空Dictionaryは「復元不要（新規ゲーム）」を意味する。
var _pending_restore: Dictionary = {}


## 🔵 slot（0〜SLOT_COUNT-1）に対応する保存先ファイルパスを返す。
static func _slot_path(slot: int) -> String:
	return "%s/slot_%d.json" % [SAVE_DIR, slot]


static func _is_valid_slot(slot: int) -> bool:
	return slot >= 0 and slot < SLOT_COUNT


## 🔵 現在のGameStateの状態をslotへ即座に保存する。
## 🟡 保存直前にsaved_at_unixを付与する（スロット選択UIの「いつのデータか」表示用）。
## I/O失敗時（ディレクトリ作成失敗・ファイルオープン失敗）はResult.fail()を返す。
## 成功時は書き込んだDictionary本体をResult.ok()のvalueへ載せる。
func save_to_slot(slot: int) -> Result:
	if not _is_valid_slot(slot):
		return Result.fail(ERROR_INVALID_SLOT)

	var data := GameStateSaveDelegate.collect_save_data(GameState)
	data["saved_at_unix"] = int(Time.get_unix_time_from_system())

	# 🔴 コードレビュー指摘対応。初回セーブ以降はSAVE_DIRが既に存在するため、
	# 毎回のオートセーブでmake_dir_recursive_absolute()を再実行する（ディレクトリ存在確認の
	# syscallが無駄になる）のを避け、未作成の場合のみ作成する
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		var dir_error := DirAccess.make_dir_recursive_absolute(SAVE_DIR)
		if dir_error != OK:
			push_error("セーブディレクトリの作成に失敗しました: %s" % error_string(dir_error))
			return Result.fail(ERROR_DIR_CREATE_FAILED)

	var file := FileAccess.open(_slot_path(slot), FileAccess.WRITE)
	if file == null:
		push_error("セーブファイルの書き込みオープンに失敗しました: %s" % error_string(FileAccess.get_open_error()))
		return Result.fail(ERROR_FILE_OPEN_FAILED)

	file.store_string(JSON.stringify(SaveDataCodec.wrap_with_checksum(data)))
	file.close()
	return Result.ok(data)


## 🔵 slotから読み込み、検証済みDictionaryをResult.ok(value)で返す。
## ファイル不在・パース失敗・破損（チェックサム不一致・型不一致）はいずれもResult.fail()を返す。
func load_from_slot(slot: int) -> Result:
	if not _is_valid_slot(slot):
		return Result.fail(ERROR_INVALID_SLOT)

	var path := _slot_path(slot)
	if not FileAccess.file_exists(path):
		return Result.fail(ERROR_FILE_NOT_FOUND)

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("セーブファイルの読み込みオープンに失敗しました: %s" % error_string(FileAccess.get_open_error()))
		return Result.fail(ERROR_FILE_OPEN_FAILED)

	var raw_text := file.get_as_text()
	file.close()

	var json := JSON.new()
	if json.parse(raw_text) != OK:
		push_warning("セーブファイルのJSONパースに失敗しました: slot=%d" % slot)
		return Result.fail(ERROR_PARSE_FAILED)

	var data := SaveDataCodec.validate_and_unwrap(json.data)
	if data.is_empty():
		push_warning("セーブデータが破損しています: slot=%d" % slot)
		return Result.fail(ERROR_CORRUPTED)

	return Result.ok(data)


## 🔵 スロット選択画面表示用の要約を返す。ファイル不在ならis_empty=true、
## 破損していればis_corrupted=trueのSaveSlotSummaryを返す（例外を投げない）。
## 🟡 範囲外slotはファイル不在と同じく「空スロット」として扱う（UI側で分岐を増やさないため）。
func get_slot_summary(slot: int) -> SaveSlotSummary:
	var summary := SaveSlotSummary.new()
	summary.slot_index = slot

	if not _is_valid_slot(slot) or not FileAccess.file_exists(_slot_path(slot)):
		return summary

	summary.is_empty = false

	var result := load_from_slot(slot)
	if not result.success:
		summary.is_corrupted = true
		return summary

	var data: Dictionary = result.value
	summary.gold = int(data["gold"])
	summary.current_rank_id = String(data["current_rank_id"])
	summary.current_turn = int(data["current_turn"])
	summary.saved_at_unix = int(data["saved_at_unix"])
	return summary


## 🔵 slotを以後のオートセーブ書き込み先として選択し、既存セーブがあれば読み込んで
## _pending_restoreへ保持する。この時点ではGameStateへ一切書き込まない
## （スロット選択はマスターデータロード（MainScene._enter_tree()）より前に起きるため）。
## 新規スロット（ファイル不在）は復元不要としてResult.ok()を返す。
## 破損スロットはERROR_SAVE_DATA_CORRUPTEDで失敗を返すが、
## 🟡 active_slotは選択済みのまま維持する（UIが警告表示後、そのスロットで新規開始できるようにする）。
func select_slot_and_restore(slot: int) -> Result:
	if not _is_valid_slot(slot):
		return Result.fail(ERROR_INVALID_SLOT)

	active_slot = slot
	_pending_restore = {}

	var result := load_from_slot(slot)
	if result.success:
		_pending_restore = result.value
		return Result.ok(_pending_restore)

	if result.error_code == ERROR_FILE_NOT_FOUND:
		return Result.ok()

	return Result.fail(ERROR_SAVE_DATA_CORRUPTED)


## 🔵 保留中のセーブデータをGameStateへ適用し、保留をクリアする。
## 保留が空（新規ゲーム）の場合は何もしない。
## 呼び出し前提: GameState.load_*_master_data()が全て実行済みであること
## （current_daily_order_id等のID→Resource解決に必要）。
func apply_pending_restore() -> void:
	if _pending_restore.is_empty():
		return
	GameStateSaveDelegate.restore_save_data(GameState, _pending_restore)
	_pending_restore = {}


## 🔵 active_slotへ現在の状態を保存する。未選択（active_slot < 0）の場合は何もしない
## （テスト環境・スロット選択前からの誤書き込み防止）。
## 🟡 失敗してもpush_warning()するのみで呼び出し元へ伝播しない
## （オートセーブ失敗でフェーズ遷移を止めないため）。
func autosave() -> void:
	if active_slot < 0:
		return

	var result := save_to_slot(active_slot)
	if not result.success:
		push_warning("オートセーブに失敗しました: slot=%d error=%s" % [active_slot, result.error_code])


## 🔴 コードレビュー指摘対応。SaveServiceはAutoload（プロセス内で単一）のため、
## GameStateと同様にテスト分離用のリセットAPIを持つ（state-management.md「テスト用API」・
## godot-debug-tools.md「雛形1」準拠）。従来は各テストファイルがactive_slot/_pending_restoreへ
## 直接アクセスしてリセットしており、リセット漏れがあると以後のテストでset_phase()経由の
## autosave()が実ファイルへ書き込み続けてしまっていた。GameStateTestSupport.guard()は
## GameStateScript非依存の共有ヘルパーのためそのまま流用する。
func reset_for_test() -> void:
	if not GameStateTestSupport.guard("reset_for_test"):
		return
	active_slot = -1
	_pending_restore = {}
