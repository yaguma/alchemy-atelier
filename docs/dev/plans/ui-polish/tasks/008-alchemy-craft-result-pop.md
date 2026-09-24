---
id: "008"
title: "調合画面で調合実行時の完成品生成演出を追加する"
status: done
priority: 3
dependencies: ["001"]
estimated_complexity: low
---

# Task: 調合画面で調合実行時の完成品生成演出を追加する

## Goal

`_execute_button`押下直後、完成品が生成される一瞬の演出を追加する（`alchemy.md` L84前半）。ギルド納品画面側への遷移演出自体はタスク010（フェードイン）が担当するため、本タスクは調合実行そのものの生成エフェクトに限定する。

## Interfaces

```gdscript
# atelier/features/alchemy/ui/alchemy_screen.gd の既存 _on_product_crafted() 相当の処理に追加
# 変更方針: 完成品確定直後、_deliver_and_display() を呼ぶ前に、
#   一時的な完成品アイコン表示ノードに対して UiEffects.play_pop_in() を呼ぶ
```

## Test Strategy

- [ ] 調合実行成功時、完成品生成演出（`play_pop_in()`）が呼ばれる
- [ ] 演出完了を待たずに`_deliver_and_display()`（ギルド納品画面への遷移処理）が呼ばれる、または演出完了後に呼ばれる（どちらの順序にするかはtdd-implementer裁量、テストでは採用した順序を明記する）
- [ ] エッジケース: 調合実行が失敗（素材不足等）した場合、演出は発生しない

## Implementation Notes

- 参照すべき既存コード: `atelier/features/alchemy/ui/alchemy_screen.gd`の調合実行ハンドラ、`_deliver_and_display()`
- タスク010（ギルド納品フェードイン）と処理順序が絡むため、実装順は001→008→010を推奨するが依存関係としては独立（010は008の完了を待たず着手可能）

## Files

- 変更: `atelier/features/alchemy/ui/alchemy_screen.gd`
- テスト: `atelier/tests/integration/test_alchemy_screen_craft_result_animation.gd`
