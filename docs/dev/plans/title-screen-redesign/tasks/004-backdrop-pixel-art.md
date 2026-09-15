---
id: "004"
title: "タイトル背景のドット絵1枚絵をatelier-image-genで生成する"
status: done
priority: 2
dependencies: []
estimated_complexity: low
---

# Task: タイトル背景のドット絵1枚絵をatelier-image-genで生成する

## Goal

前Planの`TitleBackdrop`（`GradientTexture2D`＋`_draw()`による丘・草の自前プロシージャル描画）を置き換える、朝の庭のドット絵背景を1枚絵として`atelier-image-gen`で生成する。

## Interfaces

このタスクにコード上のインターフェースはない（アセット生成のみ）。生成対象:

```
atelier/assets/ui/title/title_backdrop_pixel.png
```

構図・配色の方向性（🟡 具体的な構図はAI裁量、前Planの水彩背景の要素を踏襲する）:

- 暖色系の朝の空のグラデーション、朝日または六芒星のグロー（前Planの`COLOR_TITLE_SKY_TOP/MID/BOTTOM`, `COLOR_TITLE_SUN_GLOW`の配色を参考にする）
- なだらかな丘と背の高い草の額縁シルエット（前Planの`COLOR_TITLE_HILL_BACK/FRONT`, `COLOR_TITLE_GRASS_FRAME`の配色を参考にする）
- ドット絵らしいくっきりした輪郭・限定色数（レトロゲーム風パレット、ディザリング可）
- タスク001で設定する内部ビューポート解像度（例: 480x270、実際の値はタスク001の実装結果を確認する）に近いアスペクト比・十分な解像度で生成する

## Test Strategy

自動テストなし（画像アセット生成タスクのため）。代わりに以下を確認する:

- [ ] `atelier/assets/ui/title/title_backdrop_pixel.png`が生成されている
- [ ] Readツールで目視確認し、ドット絵らしい輪郭・配色であることを確認する。滲んだイラスト調になっている場合はプロンプトを調整し再生成する（最大3回まで）
- [ ] `.claude/rules/design-guide.md`の「ダーク背景禁止」「青紫系禁止」を満たしていることを確認する
- [ ] `atelier/features/title/ui/title_backdrop.tscn`（前Plan成果物、`TextureRect`+`show_behind_parent`構成）の画面比率で表示した際に、極端なトリミングで構図が破綻しないことを確認する（`STRETCH_KEEP_ASPECT_COVERED`を想定）

## Implementation Notes

- 参照すべき既存コード: `atelier/shared/theme/theme.gd`の`COLOR_TITLE_*`定数（前Plan成果物、配色参考用）、`docs/design/atelier-alchemy-core/nanobanana-prompts.md`（構図参考、ただし技法は水彩からドット絵に変更する）
- 実装のヒント: `.claude/skills/atelier-image-gen/SKILL.md`を参照し、ドット絵スタイルのプロンプト指定を行う
- 注意事項: 前Planの`title_backdrop.gd`/`.tscn`は本タスクでは変更しない（実装はタスク008で行う）。本タスクは画像生成のみ

## Files

- 新規: `atelier/assets/ui/title/title_backdrop_pixel.png`
