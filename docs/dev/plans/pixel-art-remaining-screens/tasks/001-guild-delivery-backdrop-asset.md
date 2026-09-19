---
id: "001"
title: "ギルド納品結果画面用の背景ドット絵アセットを生成する"
status: done
priority: 1
dependencies: []
estimated_complexity: low
---

> 🔵 2026-09-19実施: `GEMINI_API_KEY`設定済みのため`atelier-image-gen`スキル（`gemini-2.5-flash-image`、`alchemy_backdrop_pixel.png`を`--reference-image`に指定してスタイル統一）でギルドカウンター・紋章のドット絵背景を生成した。同モデルはアスペクト比指定への追従が不安定で、複数回の試行で1024x1024正方形出力や、プロンプト中の「結果リスト・ノルマバー・ボタン」という説明を誤って画像内の英語UIモックアップ文字として描画する事象が発生したため、最終的にはUI要素への言及を避けたプロンプトで生成した上位帯（上下の余白）付き1024x1024画像から中央のコンテンツ帯をPillowでクロップし、1344x768へ`Image.NEAREST`でリサイズして他背景と解像度を揃えた。目視確認・インポート確認済み。

# Task: ギルド納品結果画面用の背景ドット絵アセットを生成する

## Goal

`atelier-image-gen`スキルを使い、ギルド納品結果画面（`GuildDeliveryScreen`）の背景1枚絵（ドット絵）を生成する。

## Interfaces

```
出力ファイル: atelier/assets/ui/guild/guild_delivery_backdrop_pixel.png  # 🟡 新規
```

> 信号機: 🟡 解像度・構図・生成手順はgarden/alchemy背景（`garden-alchemy-visual-refresh`Plan 002/003）の生成手順を踏襲した妥当な推測

## Test Strategy

自動テストなし（画像アセット生成のため）。以下を確認する:

- [ ] `atelier/assets/ui/guild/guild_delivery_backdrop_pixel.png`が生成され、Godotエディタでインポートエラーが出ない
- [ ] design-guide.mdのギルド納品フェーズアクセント（コーラル `#E8A87C`系）を基調にした構図になっている
- [ ] `godot --headless --path atelier --import`がエラーなく完了する

## Implementation Notes

- 参照すべき既存コード: `atelier/assets/ui/garden/garden_backdrop_pixel.png`・`atelier/assets/ui/alchemy/alchemy_backdrop_pixel.png`（構図・解像度・生成コマンドの参考）、`docs/design/atelier-alchemy-core/nanobanana-prompts.md`（存在する場合）
- 実装のヒント: ギルド納品の世界観（`docs/concept/atelier-concept.md`「ギルドに自動納品してランクのノルマをこなしていく」）を踏まえ、ギルドのカウンター・納品台・受付を思わせる構図にする。GEMINI_API_KEY未設定時はPillow製プレースホルダー（単色〜グラデーション+PLACEHOLDER表記）で代替し、後続タスクをブロックしない（garden-alchemy-visual-refresh Plan 002と同じ運用）
- 注意事項: `GuildDeliveryScreen`は調合画面へ埋め込み表示されるオーバーレイのため、前面に配置される結果リスト・ノルマバー・「続ける」ボタンが読みやすいよう、背景は情報量を抑えたシンプルな構図にする

## Files

- 新規: `atelier/assets/ui/guild/guild_delivery_backdrop_pixel.png`
- 新規: `atelier/assets/ui/guild/guild_delivery_backdrop_pixel.png.import`（Godotが自動生成）
