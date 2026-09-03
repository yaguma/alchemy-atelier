# 🔵 設定値の永続化（user://settings.json）と、AudioServer・DisplayServerへの即時反映を担う
# Imperative Shell（Autoload）。永続化形式の組み立て・検証はSettingsCodec（Functional Core）へ
# 委譲し、本クラスはファイルI/Oとエンジンサーバーへの反映のみを担う。
extends Node

## 🔵 CON-003: SaveServiceのスロット（user://saves/slot_N.json）とは独立したグローバル設定。
## スロットを切り替えても設定は引き継がれる。
const SETTINGS_PATH := "user://settings.json"

## 🔴 現状のプロジェクトにはAudioBusLayoutが無く、これらのバスは未定義。
## get_bus_index()が-1を返すため音量反映はno-opになる（バス追加時に自動で有効化される）。
const BUS_BGM := "BGM"
const BUS_SE := "SE"

var _data := SettingsData.new()


## 🔵 user://settings.jsonを読み込み、内部状態へ反映する。
## ファイル不在・オープン失敗・JSONパース失敗・型不正のいずれの場合も
## デフォルト値へフォールバックする（例外を投げない。FR-005, FR-008, AC-010）。
## 読み込み後はAudioServer・DisplayServerへ即時反映する。
func load_settings() -> void:
	_data = _read_settings_file()
	_apply_bus_volume(BUS_BGM, _data.bgm_volume)
	_apply_bus_volume(BUS_SE, _data.se_volume)
	_apply_window_mode(_data.window_mode)


## 🔵 現在の設定値をuser://settings.jsonへ書き込む。
## 🟡 書き込み失敗時はpush_error()するのみで呼び出し元へ伝播しない
## （設定保存の失敗でUI操作を止めないため。NFR-301）。
func save_settings() -> void:
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file == null:
		push_error("設定ファイルの書き込みオープンに失敗しました: %s" % error_string(FileAccess.get_open_error()))
		return

	file.store_string(JSON.stringify(SettingsCodec.to_dict(_data)))
	file.close()


func get_bgm_volume() -> float:
	return _data.bgm_volume


func get_se_volume() -> float:
	return _data.se_volume


func get_window_mode() -> int:
	return _data.window_mode


func get_reduced_effects() -> bool:
	return _data.reduced_effects


## 🔵 BGM音量を0.0〜1.0へクランプして保持し、AudioServerへ即時反映する（FR-104）。
func set_bgm_volume(value: float) -> void:
	_data.bgm_volume = clampf(value, SettingsCodec.MIN_VOLUME, SettingsCodec.MAX_VOLUME)
	_apply_bus_volume(BUS_BGM, _data.bgm_volume)


## 🔵 SE音量を0.0〜1.0へクランプして保持し、AudioServerへ即時反映する（FR-105）。
func set_se_volume(value: float) -> void:
	_data.se_volume = clampf(value, SettingsCodec.MIN_VOLUME, SettingsCodec.MAX_VOLUME)
	_apply_bus_volume(BUS_SE, _data.se_volume)


## 🔵 ウィンドウモードを保持し、DisplayServerへ即時反映する（FR-106）。
## 反映に失敗してもUIには通知せず、内部状態は要求値のまま保持する
## （設定画面のトグル表示と操作結果を一致させるため）。
func set_window_mode(mode: int) -> void:
	_data.window_mode = mode
	_apply_window_mode(mode)


## 🔵 演出簡略化フラグを保持する。既存画面への適用はスコープ外（CON-005, FR-302）。
func set_reduced_effects(value: bool) -> void:
	_data.reduced_effects = value


## 🔵 SettingsServiceはAutoload（プロセス内で単一）のため、SaveServiceと同様に
## テスト分離用のリセットAPIを持つ（state-management.md「テスト用API」準拠）。
func reset_for_test() -> void:
	if not GameStateTestSupport.guard("reset_for_test"):
		return
	_data = SettingsData.new()


## 🟡 設定ファイルを読み、SettingsDataへ復元して返す。読めない場合はデフォルト値を返す。
func _read_settings_file() -> SettingsData:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return SettingsData.new()

	var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if file == null:
		push_warning("設定ファイルの読み込みオープンに失敗しました: %s" % error_string(FileAccess.get_open_error()))
		return SettingsData.new()

	var raw_text := file.get_as_text()
	file.close()

	var json := JSON.new()
	if json.parse(raw_text) != OK:
		push_warning("設定ファイルのJSONパースに失敗しました。デフォルト値で起動します")
		return SettingsData.new()

	return SettingsCodec.parse(json.data)


## 🔵 対象バスが未定義（get_bus_index()が-1）の環境ではno-opにする。
func _apply_bus_volume(bus_name: String, volume: float) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		return
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(volume))


## 🔵 DisplayServer.window_set_mode()は成否を返さないため、事後にwindow_get_mode()で
## 検証し、不一致の場合のみpush_warning()する（UIへは通知しない。NFR-301）。
func _apply_window_mode(mode: int) -> void:
	DisplayServer.window_set_mode(mode)
	if DisplayServer.window_get_mode() != mode:
		push_warning("ウィンドウモードの変更に失敗しました: mode=%d" % mode)
