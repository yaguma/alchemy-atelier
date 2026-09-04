---
id: "001"
title: "SettingsDataとSettingsCodecを実装する"
status: done
priority: 1
dependencies: []
estimated_complexity: medium
---

# Task: SettingsDataとSettingsCodecを実装する

## Goal

設定値（BGM音量・SE音量・ウィンドウモード・演出簡略化フラグ）を保持するランタイム状態型`SettingsData`と、そのJSON化・パース・型検証を行う純粋関数群`SettingsCodec`を実装する。破損・型不正な入力からはデフォルト値へフォールバックする（改ざん検出用チェックサムは持たない）。

## Interfaces

```gdscript
# atelier/features/settings/state/settings_data.gd
class_name SettingsData
extends RefCounted

var bgm_volume: float = 1.0        # 🔵 0.0〜1.0、デフォルト100%
var se_volume: float = 1.0         # 🔵 0.0〜1.0、デフォルト100%
var window_mode: int = DisplayServer.WINDOW_MODE_WINDOWED  # 🔵 デフォルトはウィンドウモード
var reduced_effects: bool = false  # 🔵 デフォルトOFF
```

```gdscript
# atelier/features/settings/logic/settings_codec.gd
class_name SettingsCodec

## SettingsDataを永続化用Dictionaryへ変換する（チェックサムなし。FR-404）
static func to_dict(data: SettingsData) -> Dictionary:  # 🔵 save_data_codec.gdのwrap_with_checksum()相当だがラップしない

## JSON.parse()の生Variantを検証し、正当ならSettingsDataを、不正・破損時はデフォルト値のSettingsDataを返す
## （NFR-101, FR-005, FR-008, AC-010）
static func parse(raw: Variant) -> SettingsData:  # 🔵 save_data_codec.gdのvalidate_and_unwrap()と同型の型検証パターン

## rawがトップレベルキーの型を満たすかを返す（save_data_codec.gd _is_valid_save_data()と同水準の検証範囲）
static func _is_valid(raw: Variant) -> bool:  # 🔵
```

## Test Strategy

- [ ] `SettingsData.new()`の初期値がBGM音量1.0・SE音量1.0・`DisplayServer.WINDOW_MODE_WINDOWED`・`reduced_effects=false`であること
- [ ] `SettingsCodec.to_dict()`が4キー（`bgm_volume`, `se_volume`, `window_mode`, `reduced_effects`）を持つDictionaryを返すこと
- [ ] `to_dict()`→`parse()`のラウンドトリップで元の値と一致すること（AC-012相当のユニットレベル確認）
- [ ] `parse()`にDictionary以外（`null`, `String`, `Array`等）を渡すとデフォルト値のSettingsDataが返ること
- [ ] `parse()`にトップレベルキーが欠損したDictionaryを渡すとデフォルト値のSettingsDataが返ること
- [ ] `parse()`に型不正な値（`bgm_volume`が文字列等）を渡すとデフォルト値のSettingsDataが返ること
- [ ] エッジケース: `bgm_volume`に範囲外の値（`-0.5`や`1.5`）を渡すと`0.0`〜`1.0`にクランプされること
- [ ] エッジケース: GodotのJSON数値は常にfloatで復元されるため、`window_mode`が`float`（例: `1.0`）で渡されても`int`として正しく解釈されること

## Implementation Notes

- 参照すべき既存コード: `atelier/features/save_load/logic/save_data_codec.gd`（`_is_valid_save_data()`の型検証パターン）、`atelier/features/save_load/state/save_slot_summary.gd`（RefCountedのシンプルな状態型）
- `SaveDataCodec`と異なり`wrap_with_checksum()`/チェックサム照合は実装しない（FR-404、CON-005とは別に、設定データはゲームバランスに影響しないため改ざん検出不要という要件判断）
- `_is_valid()`は`bgm_volume`/`se_volume`/`window_mode`が`int`または`float`であること、`reduced_effects`が`bool`であることを確認する（GodotのJSONパーサは数値を常にfloatで返すため`int`/`float`両方を許容する必要がある。save_data_codec.gdの既存パターンと同じ）
- 注意事項: 本ファイルはFunctional Core（副作用なし、ファイルI/O禁止、`Node`非継承）。ファイルI/Oは次タスク（002 SettingsService）が担う

## Files

- 新規: `atelier/features/settings/state/settings_data.gd`
- 新規: `atelier/features/settings/logic/settings_codec.gd`
- テスト: `atelier/tests/unit/features/settings/test_settings_codec.gd`
