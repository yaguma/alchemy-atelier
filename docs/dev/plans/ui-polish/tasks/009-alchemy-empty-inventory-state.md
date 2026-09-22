---
id: "009"
title: "調合画面の在庫リストに空状態表示を追加する"
status: done
priority: 4
dependencies: []
estimated_complexity: low
---

# Task: 調合画面の在庫リストに空状態表示を追加する

## Goal

在庫が空の場合、素材一覧に「収穫した素材がありません」等の空状態表示を追加する（`alchemy.md` L72）。演出ではなく静的な表示切替であり、UiEffects/UiThemeへの依存はない独立タスク。

## Interfaces

```gdscript
# atelier/features/alchemy/ui/material_inventory_list.gd への追加
# シーン(.tscn)に %EmptyStateLabel（Label）を新設
func _rebuild() -> void  # 既存関数を変更: _materials.is_empty() の場合 %EmptyStateLabel を表示し、それ以外は非表示にする
```

## Test Strategy

- [ ] `setup([])`（空配列）で呼び出すと`%EmptyStateLabel`が表示される
- [ ] `setup([...])`（1件以上）で呼び出すと`%EmptyStateLabel`が非表示になる
- [ ] 空状態から素材が追加された場合、再度`setup()`が呼ばれれば表示が正しく切り替わる
- [ ] エッジケース: 空状態のままウィジェットが再描画されても二重表示や表示崩れが起きない

## Implementation Notes

- 参照すべき既存コード: `atelier/features/alchemy/ui/material_inventory_list.gd`の`_rebuild()`
- 文言は仮でよい（`alchemy.md` L72の「収穫した素材がありません」を暫定採用、tdd-implementerが最終決定）

## Files

- 変更: `atelier/features/alchemy/ui/material_inventory_list.gd`, `atelier/features/alchemy/ui/material_inventory_list.tscn`
- テスト: `atelier/tests/integration/test_material_inventory_list_empty_state.gd`
