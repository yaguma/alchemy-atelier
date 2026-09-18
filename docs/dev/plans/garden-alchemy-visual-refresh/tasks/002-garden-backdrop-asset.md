---
id: "002"
title: "庭画面用の背景ドット絵アセットを生成する"
status: done
priority: 1
dependencies: []
estimated_complexity: low
---

> 🔴 2026-09-18実施: `GEMINI_API_KEY`/`GOOGLE_API_KEY`が未設定のため`atelier-image-gen`スキルが使用できず、Pillowによる簡易プレースホルダー（`atelier/assets/ui/garden/garden_backdrop_pixel.png`, 1344x768、リーフグリーングラデーション+PLACEHOLDER表記）で代替した。APIキー設定後、本物のドット絵アセットに差し替えること（ユーザー承認済み、ヒアリング参照）。
>
> 🔵 2026-09-18追記: `GEMINI_API_KEY`設定後、`atelier-image-gen`スキル（`gemini-2.5-flash-image`、`title_backdrop_pixel.png`を`--reference-image`に指定してスタイル統一）で朝の庭・畑のドット絵背景（1344x768、タイトル背景と同解像度）を生成し、Pillow製プレースホルダーと差し替えた。目視確認・インポート確認済み。

# Task: 庭画面用の背景ドット絵アセットを生成する

## Goal

`atelier-image-gen`スキルを使い、庭画面の背景1枚絵（ドット絵）を生成する。

## Interfaces

```
出力ファイル: atelier/assets/ui/garden/garden_backdrop_pixel.png  # 🟡 新規
```

> 信号機: 🟡 解像度・構図はタイトル背景（`title_backdrop_pixel.png`）の生成手順を踏襲した妥当な推測

## Test Strategy

自動テストなし（画像アセット生成のため）。以下を確認する:

- [ ] `atelier/assets/ui/garden/garden_backdrop_pixel.png`が生成され、Godotエディタでインポートエラーが出ない
- [ ] design-guide.mdの庭フェーズアクセント（リーフグリーン `#8CC084`系）を基調にした構図になっている
- [ ] `godot --headless --path atelier --import`がエラーなく完了する

## Implementation Notes

- 参照すべき既存コード: `atelier/assets/ui/title/title_backdrop_pixel.png`（構図・解像度の参考）、`docs/design/atelier-alchemy-core/nanobanana-prompts.md`
- 実装のヒント: 庭（仕込み層）のゲームコンセプト（`docs/concept/atelier-concept.md`）を踏まえ、庭・植物・畑を思わせる構図にする
- 注意事項: 前面に配置される`VBoxContainer`のUI要素（ボタン・スロット群）が読みやすいよう、背景は情報量を抑えたシンプルな構図にする（タイトル背景と異なり、常時UI要素が全面に重なる点に注意）

## Files

- 新規: `atelier/assets/ui/garden/garden_backdrop_pixel.png`
- 新規: `atelier/assets/ui/garden/garden_backdrop_pixel.png.import`（Godotが自動生成）
