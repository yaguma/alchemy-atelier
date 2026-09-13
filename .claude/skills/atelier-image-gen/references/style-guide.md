# Atelier 水彩ファンタジー スタイルガイド（画像生成プロンプト用）

本プロジェクトの統一ビジュアルは`.claude/rules/design-guide.md`の「水彩ファンタジースタイル」に
準拠する。画像生成時は以下の基本スタイル記述をプロンプトの先頭に含め、対象物の説明を続ける。

## 基本スタイル記述（ベーステンプレート）

Gemini/Imagenは英語プロンプトの方がスタイルの再現性が安定しやすい傾向があるため、基本スタイル部分は
英語、対象物の説明は日本語・英語どちらでもよい（固有名詞が多いなら日本語の方が伝わりやすいこともある）。

```
Soft watercolor fantasy illustration style, warm and gentle, hand-painted texture,
soft rounded shapes, no harsh outlines, warm cream/ivory background, gentle diffused
lighting, pastel color palette with warm gold accents, cozy and inviting mood,
clean and readable silhouette suitable for a small game icon, no text, no watermark.
```

## フェーズアクセントカラー（design-guide.md参照）

`design-guide.md`は背景色・カード枠にフェーズアクセントカラーを使うことを禁止している。画像生成物でも
同じ制約を踏襲し、「縁取りの一部」「淡いグロー」「小さなワンポイント」程度の使用に留める。

| フェーズ | アクセント | 使いどころの目安 |
|---|---|---|
| 庭 | リーフグリーン `#8CC084` | 植物・種・葉のモチーフ |
| 調合 | アンバー `#D4A76A` | 調合台・炎・ポーションの液色 |
| ギルド納品 | コーラル `#E8A87C` | 納品箱・証書・スタンプ |
| 工房強化 | ラベンダー `#B8A9D4` | 道具・強化エフェクトの光 |

⚠️ 上記以外の色（クリーム系背景の正確なHEX等）は、`docs/design/atelier-alchemy-core/ui-design/overview.md`
に記載の通り2026-09-13時点でも**暫定案のまま未確定**（正式なビジュアルデザインガイド策定は
`CLAUDE.md`「次のステップ」参照）。確定値があるかは`atelier/shared/theme/theme.gd`（`UiTheme`）を
都度確認し、無ければ上記ベーステンプレートの緩い指定（暖色系のクリーム背景）程度に留めておき、
正式なパレット確定後に生成物を差し替える前提で進める。

## アセット種別ごとの追加プロンプト例

### 素材アイコン（garden/alchemy の `MaterialMaster` 用）

```
A single icon of [具体的な素材名 / e.g. "a common healing herb"], centered composition,
plain simple background that is easy to crop or key out, no shadow cast beyond the
object, icon-style simplification, single object only.
```

### 調合物アイコン（`ProductMaster` 用）

```
An icon of a [ポーション瓶 / 魔法の粉 / etc.] representing [調合物名], glowing softly
with a [品質・特性を示す色], centered, icon-style, no text or label lettering.
```

### 背景イラスト（画面背景。screen-craftスキルと連携する場合）

```
A wide background illustration of [庭 / 工房の内部 / ギルドの受付 / etc.], soft focus,
no foreground characters, plenty of empty, low-detail space in the center-bottom area
so Godot UI elements can be layered on top without visual clutter.
```

### UI装飾パーツ（枠飾り・区切り線・ワンポイントイラスト等）

```
A small decorative [leaf / vine / potion bottle / etc.] ornament, isolated on a plain
background, suitable as a corner or divider accent in a UI panel, consistent line
weight, no drop shadow.
```

## 生成後のチェック

- 想定サイズ（アイコンなら64px相当）に縮小しても主要シルエットが判別できるか
- 既存アイコンとトーン・線の太さ・光の当たり方が揃っているか
  （揃えたい既存PNGがあれば`generate_image.py --reference-image <path>`で参照渡しする）
- 意図しない文字・ウォーターマーク・実在の商標的モチーフが写り込んでいないか
- 背景を透過や単色にしたい用途なのに、複雑な背景が生成されていないか
