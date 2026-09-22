---
id: "007"
title: "調合画面で特性発現時のハイライト演出を追加する"
status: done
priority: 3
dependencies: ["001"]
estimated_complexity: medium
---

# Task: 調合画面で特性発現時のハイライト演出を追加する

## Goal

投入内容変化により新規に特性が発現した瞬間、該当スロットを光らせるフィードバックを追加する（`alchemy.md` L83）。判定ロジックは既存の`TraitActivation.resolve_traits()`（Functional Core）を再利用し、UI層に新規の判定ロジックを書かない。

## Interfaces

```gdscript
# atelier/features/alchemy/ui/alchemy_slot_view.gd への追加
func play_trait_highlight() -> Tween  # 🟡 UiEffects.play_highlight_pulse(self, UiTheme.COLOR_TRAIT_HIGHLIGHT, ...) の薄いラッパー
```

```gdscript
# atelier/features/alchemy/ui/alchemy_screen.gd の既存 _on_preview_inputs_changed() を変更
# 変更方針:
#   1. 変更前の activated_traits（前回のプレビュー結果、既存で保持していない場合は新規に _previous_activated_traits: Array[StringName] を追加）と
#      変更後の activated_traits（TraitActivation.resolve_traits()の戻り値、既存で取得済み）を比較
#   2. 新規に発現したタグを検出したら、該当タグを含む素材が入っているスロットを _slot_views から特定し play_trait_highlight() を呼ぶ
#   3. _previous_activated_traits を今回の結果で更新する
```

## Test Strategy

- [ ] 2個目の素材投入で特性タグが新規発現した場合、該当スロットの`play_trait_highlight()`が呼ばれる
- [ ] 既にハイライト済み（前回から継続して発現している）タグは再度演出が発火しない（「新規発現」のみ検出）
- [ ] 素材を取り消して発現条件を満たさなくなった場合、演出は発生しない（消灯の演出は本タスクのスコープ外、静的な非発光表示に戻るのみ）
- [ ] エッジケース: 複数タグが同時に新規発現した場合、対象スロットすべてに演出が適用される

## Implementation Notes

- 参照すべき既存コード: `atelier/features/alchemy/logic/trait_activation.gd`の`resolve_traits()`（Functional Core、UI層はこの戻り値を比較するだけ）, `alchemy_screen.gd`の`_recompute_preview()`
- architecture.md準拠: 判定ロジック自体をUI層に新規実装しない。あくまで「前回との差分検出」というUI表示都合の比較のみをScreen側に置く
- `_slot_views`のうちどのスロットが該当タグの素材を含むかは、投入済み素材の`trait_tags`プロパティで判定する

## Files

- 変更: `atelier/features/alchemy/ui/alchemy_slot_view.gd`, `atelier/features/alchemy/ui/alchemy_screen.gd`
- テスト: `atelier/tests/integration/test_alchemy_screen_trait_highlight.gd`
