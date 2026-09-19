---
id: "003"
title: "ランク結果画面（昇格試験/クリア・オーバー）用の背景ドット絵アセットを生成する"
status: done
priority: 1
dependencies: []
estimated_complexity: low
---

> 🔵 2026-09-19実施: `GEMINI_API_KEY`設定済みのため`atelier-image-gen`スキル（`gemini-2.5-flash-image`、`title_backdrop_pixel.png`を`--reference-image`に指定してスタイル統一）で本物のドット絵アセットを生成した（Pillowプレースホルダーへのフォールバックは発生していない）。構図は石造りのアーチ門越しに夕暮れ/夜明けの山並みを望む「到達・区切り」を表す1枚絵（1344x768、`garden_backdrop_pixel.png`・`alchemy_backdrop_pixel.png`と同解像度）。中央上部の空は低コントラストでテキストラベルの可読性を確保している。`godot --headless --path atelier --import`でインポートエラーなし。

# Task: ランク結果画面用の背景ドット絵アセットを生成する

## Goal

`atelier-image-gen`スキルを使い、結果画面（`ResultScreen`。ゲームクリア/ゲームオーバー表示）の背景1枚絵（ドット絵）を生成する。

## Interfaces

```
出力ファイル: atelier/assets/ui/rank/rank_result_backdrop_pixel.png  # 🔴 新規
```

> 信号機: 🔴 design-guide.mdのフェーズアクセントカラー表に「ランク」に対応する専用色の定義が無いため、配色は生成時の裁量に委ねる（プラン内で暫定決定が必要）

## Test Strategy

自動テストなし（画像アセット生成のため）。以下を確認する:

- [ ] `atelier/assets/ui/rank/rank_result_backdrop_pixel.png`が生成され、Godotエディタでインポートエラーが出ない
- [ ] `godot --headless --path atelier --import`がエラーなく完了する
- [ ] クリア/オーバー両方の表示ケースに違和感のない、汎用的な「到達・区切り」を示す構図になっている（`ResultScreen`は`ResultKind.CLEAR`/`OVER`を同一Control内で排他的に切り替えるのみで背景画像自体は状態で出し分けない、`result_screen.gd`参照）

## Implementation Notes

- 参照すべき既存コード: `atelier/assets/ui/garden/garden_backdrop_pixel.png`・`atelier/assets/ui/alchemy/alchemy_backdrop_pixel.png`（構図・解像度・生成コマンドの参考）
- 実装のヒント: ゲームクリア・オーバーどちらの文脈でも破綻しない、山の頂・扉・夜明けのような「区切り」を象徴する構図が無難（🔴 明確な前例がないための提案）。GEMINI_API_KEY未設定時はPillow製プレースホルダーで代替してよい
- 注意事項: `ResultScreen`はメッセージラベル1つのみの非常にシンプルな画面のため、背景の情報量が多すぎるとテキストの可読性を損なう。中央にテキスト用の余白（明度差の少ない領域）を確保した構図にする

## Files

- 新規: `atelier/assets/ui/rank/rank_result_backdrop_pixel.png`
- 新規: `atelier/assets/ui/rank/rank_result_backdrop_pixel.png.import`（Godotが自動生成）
