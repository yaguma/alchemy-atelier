---
id: "002"
title: "工房強化・ショップ画面用の背景ドット絵アセットを生成する"
status: done
priority: 1
dependencies: []
estimated_complexity: low
---

> 🔵 2026-09-19実施: `GEMINI_API_KEY`設定済みのため`atelier-image-gen`スキル（`gemini-2.5-flash-image`、`title_backdrop_pixel.png`を`--reference-image`に指定してスタイル統一）で工房内の作業台・道具棚・薬品棚のドット絵背景を生成した。初回生成はGemini APIのデフォルト出力が1024x1024（正方形）になり、かつプロンプト中のHEXカラー指定（`#B8A9D4`）がそのまま文字として画像に焼き込まれる不具合が出たため、(1) HEXコード表記をやめて色を自然言語（"soft dusty lavender-purple"）で指定し、(2) `generationConfig.imageConfig.aspectRatio: "16:9"`をAPIリクエストに明示指定する形で再生成し、garden/alchemy背景と同じ1344x768解像度を得た。目視確認・`godot --headless --path atelier --import`のエラーなし完了を確認済み。

# Task: 工房強化・ショップ画面用の背景ドット絵アセットを生成する

## Goal

`atelier-image-gen`スキルを使い、工房強化・ショップ画面（`WorkshopScreen`）の背景1枚絵（ドット絵）を生成する。

## Interfaces

```
出力ファイル: atelier/assets/ui/workshop/workshop_backdrop_pixel.png  # 🟡 新規
```

> 信号機: 🟡 解像度・構図・生成手順はgarden/alchemy背景の生成手順を踏襲した妥当な推測

## Test Strategy

自動テストなし（画像アセット生成のため）。以下を確認する:

- [ ] `atelier/assets/ui/workshop/workshop_backdrop_pixel.png`が生成され、Godotエディタでインポートエラーが出ない
- [ ] design-guide.mdの工房強化フェーズアクセント（ラベンダー `#B8A9D4`系）を基調にした構図になっている
- [ ] `godot --headless --path atelier --import`がエラーなく完了する

## Implementation Notes

- 参照すべき既存コード: `atelier/assets/ui/garden/garden_backdrop_pixel.png`・`atelier/assets/ui/alchemy/alchemy_backdrop_pixel.png`（構図・解像度・生成コマンドの参考）
- 実装のヒント: 工房強化の世界観（恒久投資・消耗投資のショップ）を踏まえ、工房内の作業台・道具棚を思わせる構図にする。GEMINI_API_KEY未設定時はPillow製プレースホルダーで代替してよい
- 注意事項: `WorkshopScreen`は2タブ（恒久投資/消耗投資）のリストとダイアログが前面に重なる画面のため、情報量を抑えたシンプルな構図にする

## Files

- 新規: `atelier/assets/ui/workshop/workshop_backdrop_pixel.png`
- 新規: `atelier/assets/ui/workshop/workshop_backdrop_pixel.png.import`（Godotが自動生成）
