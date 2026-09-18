---
id: "001"
title: "庭/調合/RankHud/TabBar共通のカードパネル用ドット絵アセットを生成する"
status: done
priority: 1
dependencies: []
estimated_complexity: low
---

> 🔴 2026-09-18実施: `GEMINI_API_KEY`/`GOOGLE_API_KEY`が未設定のため`atelier-image-gen`スキルが使用できず、Pillowによる簡易プレースホルダー（`atelier/assets/ui/pixel/panel_pixel.png`, 64x64、9-slice判別用の3層フレーム）で代替した。APIキー設定後、本物のドット絵アセットに差し替えること（ユーザー承認済み、ヒアリング参照）。
>
> 🔵 2026-09-18追記: `GEMINI_API_KEY`設定後、`atelier-image-gen`スキル（`gemini-2.5-flash-image`、既存`button_secondary.png`を`--reference-image`に指定）で本番のドット絵カードパネルを生成し、Pillow製プレースホルダーと差し替えた（生成時は1024x1024、既存ボタンテクスチャと同じ64x64にNEARESTでダウンサンプル）。9-slice分割・インポートともに確認済み。これに伴い004の`PANEL_TEXTURE_MARGIN`を再計測・更新した。

# Task: 庭/調合/RankHud/TabBar共通のカードパネル用ドット絵アセットを生成する

## Goal

`atelier-image-gen`スキルを使い、庭・調合・RankHud・TabBarで共通利用する9-slice用カードパネルのドット絵PNGを1枚生成する。

## Interfaces

```
出力ファイル: atelier/assets/ui/pixel/panel_pixel.png  # 🟡 新規、共通1枚
```

> 信号機: 🟡 解像度・配色は妥当な推測（タイトルのボタンテクスチャ生成時の手順を踏襲）。🔴 実際の見た目・9-slice分割時の枠幅はアセット生成後に実測が必要（004で対応）

## Test Strategy

自動テストなし（画像アセット生成のため）。以下を目視・機械的に確認する:

- [ ] `atelier/assets/ui/pixel/panel_pixel.png`が生成され、Godotエディタでインポートエラーが出ない
- [ ] 既存の`button_primary.png`等（`atelier/assets/ui/pixel/`）と統一感のあるドット絵タッチ・配色になっている
- [ ] 9-slice分割（四隅・辺・中央）が視覚的に判別できる枠デザインになっている（中央が単色または単純パターンで、四隅に装飾がある構図）
- [ ] `godot --headless --path atelier --import`がエラーなく完了する

## Implementation Notes

- 参照すべき既存コード: `atelier/assets/ui/pixel/button_primary.png`等（既存4種ボタンテクスチャ、配色・ドット密度の参考）、`docs/design/atelier-alchemy-core/nanobanana-prompts.md`（既存のプロンプト生成パターン）
- 実装のヒント: `atelier-image-gen`スキルを使用し、Gemini API経由で生成する。生成後は`.import`ファイルが自動生成されることを確認する
- 注意事項: 庭（リーフグリーン）・調合（アンバー）どちらの背景にも乗せる想定のため、パネル自体は中間色（クリーム〜薄茶系、既存`COLOR_BUTTON_SECONDARY_TOP/BOTTOM`系統）にして、状態別の色分けは呼び出し側の`self_modulate`で行う設計（004・007・008参照）と矛盾しない配色にすること

## Files

- 新規: `atelier/assets/ui/pixel/panel_pixel.png`
- 新規: `atelier/assets/ui/pixel/panel_pixel.png.import`（Godotが自動生成）
