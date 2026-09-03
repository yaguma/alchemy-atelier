---
id: "007"
title: "BootSceneの遷移先をTitleScreenへ変更する"
status: done
priority: 2
dependencies: ["004", "002"]
estimated_complexity: low
---

# Task: BootSceneの遷移先をTitleScreenへ変更する

## Goal

`BootScene`のマスターデータ検証成功後の遷移先を、現在の`res://features/save_load/ui/slot_select_screen.tscn`から`res://features/title/ui/title_screen.tscn`へ変更する。既存の`SlotSelectScreen`・`MainScene`への遷移経路自体は変更しない（`TitleScreen`からの遷移として維持される）。

## Interfaces

```gdscript
# atelier/scenes/boot.gd （既存定数の変更のみ）

const NEXT_SCENE_PATH := "res://features/title/ui/title_screen.tscn"  # 🔵 FR-001
# 変更前: "res://features/save_load/ui/slot_select_screen.tscn"
```

## Test Strategy

- [ ] `BootScene._ready()`実行後、`get_requested_next_scene_path()`が`res://features/title/ui/title_screen.tscn`を返すこと（AC-001正常系）
- [ ] マスターデータ検証失敗時（`MasterDataLoader.validate_references()`が`false`）は遷移が要求されないこと（`_requested_next_scene_path`が空文字列のまま）（AC-001異常系。既存の回帰確認）
- [ ] `scene_transition_enabled = false`でも遷移先パスの決定自体は行われること（AC-001境界値。既存の回帰確認）

## Implementation Notes

- 参照すべき既存コード: `atelier/scenes/boot.gd`（`NEXT_SCENE_PATH`定数、`_ready()`のロジック自体は変更不要）
- 変更は`NEXT_SCENE_PATH`定数の値のみ。`boot.gd`の他のロジック（マスターデータ検証、`call_deferred`での遷移、`scene_transition_enabled`）は一切変更しない
- 既存の`test_boot_scene.gd`（存在する場合）が旧パス（`slot_select_screen.tscn`）をハードコードして期待していないか確認し、新パスへ更新する
- 注意事項: `SlotSelectScreen`・`MainScene`側の実装・遷移条件は本タスクでは一切変更しない（`TitleScreen`の「はじめる」ボタンから`SlotSelectScreen`へ遷移する経路はタスク004で実装済み）

## Files

- 変更: `atelier/scenes/boot.gd`
- テスト: `atelier/tests/integration/test_boot_scene.gd`（既存ファイルがあれば更新、なければ新規作成）
