---
id: "006"
title: "MainSceneのプレースホルダを作成する"
status: done
priority: 3
dependencies: ["001"]
estimated_complexity: low
---

# Task: MainSceneのプレースホルダを作成する

## Goal

`scenes/main.tscn` を空の`Control`ノードのみで作成する。実際の画面実装（`GardenScreen`等）は本Planのスコープ外（FR-403）であり、後続Planで子ノードとして追加される前提のプレースホルダとする。

## Interfaces

シーンファイルのみで、スクリプトはアタッチしない（🟡 「空のControlのみ」という要件を最も厳密に満たす解釈。将来のFeature Plan側で`main_screen.gd`を新規追加する前提）。

```
scenes/main.tscn
└── Control (ルートノード、名前は "Main" 程度で可)
    # 子ノードなし、スクリプト非アタッチ
```

## Test Strategy

Directモードのため自動テストは不要。以下を確認する。

- [ ] `scenes/main.tscn` をGodotエディタで開き、ルート`Control`ノード1つのみで構成されていることを確認する
- [ ] （007完了後）`boot.tscn`から`get_tree().change_scene_to_file("res://scenes/main.tscn")`でエラーなく遷移できる

## Implementation Notes

- 参照すべき既存文書: `docs/dev/plans/atelier-alchemy-core/requirements.md` 用語集「MainScene: 本Planではプレースホルダ（空のControlのみ）として作成するルートシーン」
- 007（BootScene）から遷移先として参照されるため、ファイルパス `res://scenes/main.tscn` は固定とする

## Files

- 新規: `atelier/scenes/main.tscn`
- 変更: なし
- テスト: なし
