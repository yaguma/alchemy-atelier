---
id: "004"
title: "AlchemyPreviewPanel（ライブプレビュー表示コンポーネント）を実装する"
status: pending
priority: 2
dependencies: []
estimated_complexity: low
---

# Task: AlchemyPreviewPanel（ライブプレビュー表示コンポーネント）を実装する

## Goal

品質・発現特性・見込み貢献度・見込み報酬を表示する純粋表示専用の`Control`継承コンポーネント`AlchemyPreviewPanel`を実装する（US-101, AC-007）。計算パイプライン（`QualityCalculator`〜`DeliveryResolver`）は本コンポーネントの責務外とし、計算済みの値を受け取って表示するのみとする。

## Interfaces

```gdscript
# atelier/features/alchemy/ui/alchemy_preview_panel.gd
class_name AlchemyPreviewPanel
extends Control

## 計算済みの見込み値を表示する。order_matchedがtrueの場合は指定合致を示す視覚的強調を行う 🔵
func show_preview(
	quality_score: int,
	activated_traits: Array[StringName],
	final_contribution: float,
	final_reward: float,
	order_matched: bool
) -> void:
	pass

## レシピ未選択・0投入時の初期/空表示に戻す（AC-007異常系） 🔵
func show_empty() -> void:
	pass
```

## Test Strategy

- [ ] **正常系**: `show_preview(3, [&"holy"], 12.5, 8.0, false)`を呼ぶと品質・特性・貢献度・報酬がそれぞれ表示テキストに反映される
- [ ] **正常系**: `order_matched = true`で呼ぶと指定合致を示す視覚的強調（テキストまたは色）が表示される
- [ ] **正常系**: `order_matched = false`で呼ぶと指定合致の強調表示がない
- [ ] **正常系**: `activated_traits = []`（未発現）で呼んでもクラッシュせず「特性なし」相当の表示になる
- [ ] **異常系**: `show_empty()`を呼ぶと品質・特性・貢献度・報酬の表示が初期状態（空またはプレースホルダーテキスト）に戻る

## Implementation Notes

- 参照すべき既存コード: `docs/design/atelier-alchemy-core/ui-design/screens/alchemy.md`（`txt-preview-quality`/`txt-preview-traits`/`txt-preview-value`のUI要素定義）、`atelier/features/guild/logic/delivery_result.gd`（`DeliveryResult`のフィールド構成、呼び出し元がここから値を取り出して本メソッドへ渡す）
- 実装のヒント: このコンポーネントは`GameState`にも`QualityCalculator`等のDomain層にも一切依存しない（`extends Control`のみ、`class_name`以外のpreload/参照を持たない）。計算ロジックのテストは本タスクの対象外（呼び出し元であるタスク005側でカバーする）
- 注意事項: 特性の「あと1個で発現」ヒント表示は実装しない（FR-404で明示的に禁止）。`activated_traits`は発現済みのタグのみを受け取る前提とする

## Files

- 新規: `atelier/features/alchemy/ui/alchemy_preview_panel.gd`
- 新規: `atelier/features/alchemy/ui/alchemy_preview_panel.tscn`
- テスト: `atelier/tests/unit/features/alchemy/test_alchemy_preview_panel.gd`
