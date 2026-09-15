---
id: "001"
title: "project.godotにピクセルパーフェクト用Viewportストレッチ設定を追加する"
status: done
priority: 1
dependencies: []
estimated_complexity: high
---

# Task: project.godotにピクセルパーフェクト用Viewportストレッチ設定を追加する

## Goal

`atelier/project.godot`に低解像度の内部ビューポート＋整数倍スケールのストレッチ設定を追加し、ドット絵アセットが滲まず・非整数倍率で歪まずに表示されるようにする。この変更は**ゲーム全体**（既存の庭・調合・ギルド納品・ランク・工房強化の5画面を含む）に影響するグローバル設定変更である（ユーザー承認済み、`plan.md`のCross-Plan Dependencies参照）。

## Interfaces

`atelier/project.godot`に以下の`[display]`セクションを新規追加する（現状`[display]`セクション自体が存在しない、Godotデフォルト設定のまま）:

```ini
[display]

window/size/viewport_width=480     # 🔴 具体的な内部解像度はAI裁量。既存5画面のUIレイアウト（Control/Container主体）が
window/size/viewport_height=270    # 極端な低解像度で崩れないか、実装後にGodotエディタでの目視確認が必須
window/stretch/mode="viewport"     # 🔵 ビューポート単位でスケールする標準的な方式
window/stretch/aspect="keep"       # 🔵 アスペクト比を保ちレターボックスを許容（引き伸ばし歪み防止）
window/stretch/scale_mode="integer"  # 🟡 Godot 4.2+で追加された整数倍スケールモード。バージョン仕様はContext7または
                                      # 公式ドキュメントで`ProjectSettings`の`display/window/stretch/scale_mode`を必ず確認すること
```

## Test Strategy

自動テストなし（プロジェクト設定ファイルの変更のため、GdUnit4での直接検証は困難）。代わりに以下を確認する:

- [ ] `godot --headless --path atelier --import`がエラーなく完了する（設定ファイルの構文エラーがないことの確認）
- [ ] 変更後に`cd atelier && ./addons/gdUnit4/runtest.sh -a res://tests/`を実行し、既存の全テスト（1102件以上）が引き続きPASSすることを確認する（`[display]`設定はヘッドレステスト実行そのものには影響しない見込みだが、念のため確認）
- [ ] Godotエディタでの手動プレイ確認（可能であれば）で、既存画面（例: 庭画面）のレイアウトが破綻していないか目視確認する。`--headless`実行では確認できないため、できない場合はその旨をタスク完了報告に明記する
- [ ] `window/size/viewport_width/height`の値が、既存UIの最小要求サイズ（既存Controlノードの`custom_minimum_size`等）を極端に下回っていないか、`Grep`で主要画面の`custom_minimum_size`設定を確認する

## Implementation Notes

- 参照すべき既存コード: `atelier/project.godot`（現状`[display]`セクション無し、Godotデフォルトのまま）
- 実装のヒント: Godot 4.xの`stretch/scale_mode="integer"`はGodot 4.2で追加された機能。使用前にContext7またはGodot公式ドキュメントで`ProjectSettings`の該当プロパティ名・値の正確な仕様（プロパティ名の綴り、許容値）を確認すること（CLAUDE.md「最新情報の検索」ルールに従う）
- 注意事項:
  - `window/size/viewport_width/height`の具体的な数値はAI裁量（480x270は16:9・ドット絵でよく使われる解像度帯の一例）。既存5画面のUIがこの解像度で著しく崩れる場合は、より高い基準解像度（例: 960x540）に調整してもよい
  - この変更は他Plan（garden/alchemy/guild/rank/workshop）の画面にも影響するグローバル変更である。既存テストスイートが壊れないことは確認するが、見た目の破綻は自動検出できないため、タスク011（全体回帰確認）で改めて明記すること
  - `run/main_scene`（`res://scenes/boot.tscn`）や`autoload`設定は変更しないこと

## Files

- 変更: `atelier/project.godot`
