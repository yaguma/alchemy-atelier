---
id: "005"
title: "タイトルロゴ紋章をドット絵で再生成する"
status: done
priority: 2
dependencies: []
estimated_complexity: low
---

# Task: タイトルロゴ紋章をドット絵で再生成する

## Goal

前Planで生成した`title_emblem.png`（乳鉢と乳棒＋六芒星の紋章、水彩イラスト調）を、同じモチーフのままドット絵版に再生成し、同じパスへ上書きする。

## Interfaces

このタスクにコード上のインターフェースはない（アセット生成のみ）。生成対象（既存ファイルを上書き）:

```
atelier/assets/ui/title/title_emblem.png
```

## Test Strategy

自動テストなし（画像アセット生成タスクのため）。代わりに以下を確認する:

- [ ] `atelier/assets/ui/title/title_emblem.png`がドット絵版で上書きされている
- [ ] Readツールで目視確認し、乳鉢と乳棒＋六芒星のモチーフが維持されていることを確認する
- [ ] ドット絵らしいくっきりした輪郭であることを確認する（滲んだイラスト調の場合は再生成、最大3回まで）
- [ ] 前Plan同様、画像内に文字（日本語もどきの模様含む）が焼き込まれていないことを確認する（「アトリエ」の文字は`Label`で別途重ねる設計を維持するため）
- [ ] Godotが`.import`キャッシュを自動更新することを確認する（同一パスへの上書きのため、既存の`.import`ファイル自体は変更不要のはずだが、インポート設定でエラーが出ないか確認する）

## Implementation Notes

- 参照すべき既存コード: `atelier/assets/ui/title/title_emblem.png`（前Plan成果物、目視で構図・モチーフを確認してから着手する）、`.claude/skills/atelier-image-gen/SKILL.md`
- 実装のヒント: 前Planと同じモチーフ（乳鉢・乳棒、六芒星、周囲のルーン風記号）を維持しつつ、スタイルのみドット絵に変更するプロンプトにする
- 注意事項: 本タスクは画像生成のみ。`title_screen.tscn`側の`EmblemRect`の`texture_filter`設定はタスク009で行う

## Files

- 変更: `atelier/assets/ui/title/title_emblem.png`（上書き）
