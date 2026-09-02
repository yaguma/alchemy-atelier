---
id: "001"
title: "SaveDataCodecのチェックサム計算・ラップ関数を実装する"
status: done
priority: 1
dependencies: []
estimated_complexity: low
---

# Task: SaveDataCodecのチェックサム計算・ラップ関数を実装する

## Goal

セーブデータ本体（Dictionary）から偶発的破損検出用のSHA-256チェックサムを計算し、`{"data": ..., "checksum": ...}`形式でラップする純粋関数を実装する。`.claude/rules/security.md`の`calculate_checksum()`パターンをそのまま具体化する。

## Interfaces

```gdscript
# atelier/features/save_load/logic/save_data_codec.gd
class_name SaveDataCodec

const SAVE_FORMAT_VERSION := 1  # 🔴 将来のセーブフォーマット変更時のマイグレーション判定用に予約。今回のスコープでは書き込むのみで読み込み側は値を検証しない

## data（保存対象のプリミティブDictionary）のSHA-256チェックサムを返す。
## JSON.stringify(data)の文字列に対しsha256_text()を適用する（🔵 security.md calculate_checksum()そのまま）
static func calculate_checksum(data: Dictionary) -> String

## dataをchecksum付きの永続化用Dictionary {"data": data, "checksum": calculate_checksum(data)} でラップして返す
static func wrap_with_checksum(data: Dictionary) -> Dictionary
```

## Test Strategy

- [ ] 同一のDictionaryに対し`calculate_checksum()`を2回呼ぶと同じ文字列が返る（決定性）
- [ ] 内容が異なるDictionary（キーの値を1つ変更）では異なるチェックサムが返る
- [ ] キーの順序が異なっても中身が同じDictionaryなら同じチェックサムが返る、またはこの前提が崩れる場合はその挙動を明記する（GDScriptの`JSON.stringify()`はDictionaryの挿入順を保持するため、呼び出し元は常に同じ順序でキーを構築する前提とし、その前提をコメントに明記する）
- [ ] `wrap_with_checksum({"gold": 100})`が`{"data": {"gold": 100}, "checksum": "<calculate_checksumの戻り値と一致>"}`を返す
- [ ] 空Dictionary`{}`に対しても例外を投げずチェックサムを計算できる（境界値）

## Implementation Notes

- 参照すべき既存コード: `.claude/rules/security.md`の`calculate_checksum()`サンプル（`JSON.stringify(data).sha256_text()`）
- 実装のヒント: `String.sha256_text()`はGodot組み込み。`JSON.stringify()`の第2引数（インデント等）は指定せずデフォルトのコンパクト出力を使う
- 注意事項: このファイルは`logic/`配下のFunctional Coreのため、ファイルI/O・`GameState`参照等の副作用を一切持たせない

## Files

- 新規: `atelier/features/save_load/logic/save_data_codec.gd`
- テスト: `atelier/tests/unit/features/save_load/test_save_data_codec.gd`
