---
id: "003"
title: "ボタン4種類のドット絵テクスチャをatelier-image-genで生成する"
status: done
priority: 1
dependencies: []
estimated_complexity: medium
---

# Task: ボタン4種類のドット絵テクスチャをatelier-image-genで生成する

## Goal

`UiTheme.ButtonVariant`の4種（PRIMARY/SECONDARY/DANGER/TERTIARY）それぞれについて、9-slice拡縮（`StyleBoxTexture`のタイル方式）に耐えるドット絵ボタンテクスチャを`atelier-image-gen`スキルで生成する。

## Interfaces

このタスクにコード上のインターフェースはない（アセット生成のみ）。生成対象:

```
atelier/assets/ui/pixel/button_primary.png     # 既存 COLOR_BUTTON_PRIMARY_TOP/BOTTOM/BORDER の配色を踏襲
atelier/assets/ui/pixel/button_secondary.png   # 既存 COLOR_BUTTON_SECONDARY_* の配色を踏襲
atelier/assets/ui/pixel/button_danger.png      # 既存 COLOR_BUTTON_DANGER_* の配色を踏襲
atelier/assets/ui/pixel/button_tertiary.png    # 既存 COLOR_BUTTON_TERTIARY_* の配色を踏襲
```

各PNGは以下の条件を満たすこと（🟡 具体的な生成手法・プロンプト文言はAI裁量）:

- 9-slice拡縮を前提とした「枠＋均一な中央塗り」のドット絵ボタン背景（中央に文字は含めない。文字は`Button`ノードの`text`プロパティで別途描画される）
- 正方形または横長の低解像度（例: 32x32〜48x16程度、AI裁量）で、ドット絵らしいピクセル単位のくっきりした輪郭・面取りにする（アンチエイリアスがかかったにじみは避ける）
- `atelier/shared/theme/theme.gd`の既存`COLOR_BUTTON_{VARIANT}_TOP/BOTTOM/BORDER`定数の色をプロンプトの配色指定に使い、旧水彩版とのブランド一貫性を保つ

## Test Strategy

自動テストなし（画像アセット生成タスクのため）。代わりに以下を確認する:

- [ ] 4種類全てのPNGが`atelier/assets/ui/pixel/`配下に生成されている
- [ ] Readツールで目視確認し、ドット絵らしいくっきりした輪郭（アンチエイリアスされた滲みでない）であることを確認する。生成モデルの出力がアンチエイリアスされたイラスト調になっている場合はプロンプトを調整し再生成する（最大3回まで）
- [ ] 4種のボタンが色以外の形状で区別できる、または少なくとも色相の違いが明確であることを確認する（`.claude/rules/design-guide.md`のアクセシビリティ観点は本タスクでは色のみで判別する現行仕様を踏襲する。テキストラベルで判別可能なため許容）
- [ ] 9-slice拡縮を想定した際、中央部分が単純な繰り返しパターンとして違和感なく引き伸ばせる構図になっているか確認する（極端に非対称な模様が中央にあると9-sliceで破綻するため）

## Implementation Notes

- 参照すべき既存コード: `.claude/skills/atelier-image-gen/SKILL.md`、`atelier/shared/theme/theme.gd`の`COLOR_BUTTON_*`定数
- 実装のヒント: プロンプトには「ドット絵、8bit/16bitレトロゲーム風、ピクセルアート、アンチエイリアス無し」等のスタイル指定を明記する。`atelier-image-gen`が低解像度ドット絵の生成に対応していない場合（滲んだイラスト調になる場合）は、高解像度で生成後に手動でのダウンサンプリング指示等、代替手段をタスク完了報告に明記する
- 注意事項: 前Planで生成した`title_emblem.png`と統一感のある配色にすること（ただし紋章デザイン自体は本タスクの対象外）

## Files

- 新規: `atelier/assets/ui/pixel/button_primary.png`
- 新規: `atelier/assets/ui/pixel/button_secondary.png`
- 新規: `atelier/assets/ui/pixel/button_danger.png`
- 新規: `atelier/assets/ui/pixel/button_tertiary.png`
