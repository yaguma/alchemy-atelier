---
id: "007"
title: "BootSceneを実装する（フォント適用→マスターデータ検証配線→MainScene遷移）"
status: done
priority: 2
dependencies: ["004", "005", "006"]
estimated_complexity: medium
---

# Task: BootSceneを実装する（フォント適用→マスターデータ検証配線→MainScene遷移）

## Goal

`scenes/boot.tscn` + `boot.gd` を実装し、起動時に (1) `UiTheme`のフォント適用 → (2) `MasterDataLoader.validate_references()`呼び出し（スタブ） → (3) `scenes/main.tscn`への遷移、という順序で処理する。日本語仮ラベルを表示し、フォント動作の目視確認手段とする。

## Interfaces

```gdscript
# scenes/boot.gd
class_name BootScene
extends Control

@onready var _status_label: Label = %StatusLabel  # 🔵 日本語仮ラベル（FR-301, US-011）

func _ready() -> void:
	_apply_theme()                                             # 1. フォント適用（FR-101）
	_status_label.text = "アトリエ 起動確認"                   # 🔵 画数の多い漢字を含む文言で字形欠けも確認
	if not MasterDataLoader.validate_references([]):           # 2. マスターデータ検証配線（FR-009, CON-003のスタブ呼び出し）
		push_error("マスターデータのID相互参照が解決できません")
		return
	get_tree().change_scene_to_file("res://scenes/main.tscn")  # 3. MainSceneへ遷移（FR-102）

func _apply_theme() -> void:
	theme = preload("res://shared/theme/main_theme.tres")  # 🟡 Project Settings適用と重複だが明示化（004タスク参照）
```

`validate_references([])` の引数は空配列固定（🔴 本Planでは実データが無いため。スタブは常にtrueを返すため実質無害だが、実データ検証を後続Planで実装する際にこの呼び出し箇所自体を書き換える必要がある点をコメントで明記する）。

`project.godot`の`run/main_scene`は`res://scenes/boot.tscn`に設定する（🔵 AC-008前提）。

## Test Strategy

`_ready()`のシーンライフサイクル・遷移ロジックはGUTのシーンテストで検証できる部分と、目視確認が必要な部分（フォント描画）に分かれる。

- [ ] `boot.tscn`をロードして`add_child_autofree()`した際、`MasterDataLoader.validate_references()`が呼ばれ`true`が返る（スタブなので必ず成功パス）ことを確認する
- [ ] `validate_references()`が`false`を返す場合（将来のテスト用に`double()`で差し替え）、`push_error`が呼ばれシーン遷移が行われないことを確認する（異常系）
- [ ] （目視確認、GUT対象外）Godotエディタで`boot.tscn`をF6実行し、日本語仮ラベルが正しく表示され、数秒以内に`main.tscn`へ自動遷移することを確認する

## Implementation Notes

- 参照すべき既存文書: `.claude/rules/godot-best-practices.md`「シーン/ノードライフサイクル」節、`docs/design/atelier-alchemy-core/architecture.md`「シーン構成」節（BootScene定義）
- `%StatusLabel`はシーン内ユニーク名で取得する（深い`get_node()`パス直書きは禁止、`.claude/rules/architecture.md`「禁止事項」）
- `MasterDataLoader`は005タスクで実装済みの`res://shared/loaders/master_data_loader.gd`を`class_name`経由でグローバル参照する

## Files

- 新規: `atelier/scenes/boot.tscn`, `atelier/scenes/boot.gd`
- 変更: `atelier/project.godot`（`run/main_scene`設定）
- テスト: `atelier/tests/integration/test_boot_scene.gd`（任意、シーン遷移ロジックのみ）
