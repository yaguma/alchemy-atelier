---
name: atelier-image-gen
description: |
  Google AI Studio（Gemini API）を使って、本プロジェクト（Atelier）のゲームアセット画像——素材アイコン、
  調合物アイコン、背景イラスト、UI装飾パーツなど——をテキストプロンプトから生成し、Godotプロジェクト内
  （atelier/assets/配下）にPNGとして保存するスキル。「素材のアイコンを生成して」「〇〇の画像がほしい」
  「イラストを描いて」「アセットを作って」「画像生成して」「Gemini/Imagenで画像を作って」といった依頼、
  および画面実装・演出追加（screen-craftスキル等）の途中で新規ビジュアル素材が必要になった場面で
  積極的に使うこと。明示的に「画像生成」と言われていなくても、design-guide.mdの水彩ファンタジー
  スタイルに沿ったゲーム内アイコン・イラストが必要になったら検討する。GEMINI_API_KEY（または
  GOOGLE_API_KEY）環境変数からAPIキーを読み、Gemini 2.5 Flash Image（通称Nano Banana）または
  Imagen 4系モデルを選んで画像を生成する。
compatibility: Python 3が実行できる環境、GEMINI_API_KEY（またはGOOGLE_API_KEY）環境変数、Gemini APIへの
  アウトバウンドHTTPS通信が必要。
---

# Atelier 画像生成（Google AI Studio / Gemini API）

本プロジェクトはGodot 4.x + GDScriptで開発中のデッキ構築RPG「Atelier」で、ビジュアルスタイルは
`.claude/rules/design-guide.md`の「水彩ファンタジースタイル」に統一する方針が決まっている一方、
実際の画像アセット（素材アイコン・調合物アイコン・背景イラスト等）はほぼ未着手（`atelier/assets/`
配下には現状フォントしか存在しない）。このスキルは、Google AI Studio（Gemini API）のテキスト→画像
生成モデルを使って、そのスタイルに沿ったアセットをその場で作り、Godotが読み込める形で保存するまでを
担う。

## 全体の流れ

1. APIキーが使える状態か確認する
2. 何を作るか（種別・用途・置き場所）を決める
3. スタイルガイド（[references/style-guide.md](references/style-guide.md)）を踏まえてプロンプトを組み立てる
4. `scripts/generate_image.py`で生成し、Godotの命名規則に沿ったパスへ保存する
5. 生成結果をレビューし、必要なら微調整して再生成する

計画ルール（`.claude/rules/planning.md`）に従い、この5ステップ自体を都度説明する必要はない。
1回の依頼が「アイコン1枚」程度なら黙って通して進めてよい。

## 1. 事前準備: APIキー

このスキルは`GEMINI_API_KEY`（優先）または`GOOGLE_API_KEY`環境変数からAPIキーを読む。
`.claude/rules/security.md`の「機密情報の管理」に従い、キーをコード・コマンドライン引数・
コミット対象ファイルに直接書き込まない。

```bash
# 未設定の場合はまずこれで確認する（値そのものは表示しないこと）
[ -n "$GEMINI_API_KEY" ] && echo "GEMINI_API_KEY is set" || echo "GEMINI_API_KEY is NOT set"
```

未設定なら、ユーザーに[Google AI Studio](https://aistudio.google.com/app/apikey)でキーを発行し
`export GEMINI_API_KEY=...`のように設定してもらう。ユーザーの代わりにキーを取得することはできない。

## 2. 何を作るか決める

以下を確認してから生成に入る（すでに文脈から明らかな場合は聞き直さない）。

- **種別**: 素材アイコン / 調合物アイコン / 背景イラスト / UI装飾パーツ / その他
- **用途・置き場所**: どの機能（garden/alchemy/guild/rank/workshop）のどの画面で使うか
- **枚数**: 1枚だけか、シリーズ（複数の素材アイコンをまとめて等）か
- **参考にする既存アセットの有無**: 既存アイコンとトーンを揃えたいなら`--reference-image`で渡す

保存先はGodotの既存の命名規則（`.claude/rules/godot-best-practices.md`「リソースパスの命名規則」）に
倣い、`res://assets/<category>/<name>.png`の形にする。例:

```
atelier/assets/icons/materials/herb_common.png
atelier/assets/icons/products/healing_potion.png
atelier/assets/backgrounds/garden_bg.png
atelier/assets/ui/decorations/leaf_accent.png
```

`atelier/assets/`配下に該当カテゴリのディレクトリがまだ無ければ新規作成してよい（Godotは
インポート時に`.import`ファイルを自動生成するため、ディレクトリを手動で用意すること自体に
特別な手順は不要）。命名は`.claude/rules/coding-style.md`の命名規則に合わせ、対象のマスターデータ
ID（例: `MaterialMaster`の`id`）と一致させておくと、後でGDScript側から`preload()`しやすい。

## 3. プロンプトを組み立てる

水彩ファンタジースタイルのベーステンプレートとアセット種別ごとのプロンプト例は
[references/style-guide.md](references/style-guide.md)にまとめてある。必ず目を通し、ベーステンプレート
＋対象物の説明の形でプロンプトを組み立てる。フェーズごとのアクセントカラー（庭=リーフグリーン等）は
「背景色・カード枠には使わない」という`design-guide.md`の制約が画像アセットにも及ぶ点に注意する
（ワンポイント・縁取り程度に留める）。

プロジェクトの正式なカラーパレット（背景色の正確なHEX等）は2026-09-13時点でも一部が
`docs/design/atelier-alchemy-core/ui-design/overview.md`上で暫定案のままであることが
`CLAUDE.md`「次のステップ」に明記されている。確定値がある場合は`atelier/shared/theme/theme.gd`
（`UiTheme`）を都度参照し、無ければスタイルガイドの緩い指定（暖色系のクリーム背景等）で進め、
正式なパレット確定後に差し替える前提で扱う。

## 4. 画像を生成する

`scripts/generate_image.py`を使う。APIキーは環境変数から自動で読むため、コマンドラインには渡さない。

```bash
python3 .claude/skills/atelier-image-gen/scripts/generate_image.py \
  --prompt "Soft watercolor fantasy illustration style, ... a single healing herb icon, centered, icon-style simplification" \
  --output atelier/assets/icons/materials/herb_common.png
```

### 主なオプション

| オプション | 説明 | デフォルト |
|---|---|---|
| `--prompt` | 生成プロンプト（必須） | - |
| `--output` | 保存先パス（必須） | - |
| `--model` | 使用モデルID | `gemini-2.5-flash-image` |
| `--count` | 生成枚数（Imagen系モデルのみ有効） | `1` |
| `--aspect-ratio` | アスペクト比（Imagen系モデルのみ有効。例: `1:1`, `16:9`） | `1:1` |
| `--reference-image` | 参考画像のパス（Gemini系モデルのみ、複数指定可）。既存アイコンとのスタイル統一に使う | なし |

### モデルの選び方

| モデル | 向いている用途 |
|---|---|
| `gemini-2.5-flash-image`（デフォルト、通称Nano Banana） | アイコン1枚単位の生成、既存画像を参照したスタイル統一・簡易編集。基本はこれでよい |
| `imagen-4.0-generate-001` / `imagen-4.0-ultra-generate-001` / `imagen-4.0-fast-generate-001` | 背景イラスト等、より高精細・高品質な1枚絵が欲しい場合。`--count`で複数案を一度に比較できる |

どちらが良いか判断に迷う場合や、ユーザーが特にモデルを指定していない場合はデフォルトの
`gemini-2.5-flash-image`から始め、品質が足りなければImagen系を試す。モデルID・エンドポイント仕様は
Google側で更新されることがあるため、API呼び出しがモデル未検出エラー等で失敗した場合は
[Gemini APIのモデル一覧](https://ai.google.dev/gemini-api/docs/models)を確認する。

生成に成功すると、保存したファイルパスが標準出力に1行ずつ出力される（`--count`指定時は
`<name>_1.png`, `<name>_2.png`, ...のように連番で保存される）。

## 5. 生成後のレビューと反復

- 保存したPNGをRead（画像として閲覧可能）し、意図通りか目視確認する
- 小サイズ表示時の視認性、他アイコンとのトーンの統一感を[references/style-guide.md](references/style-guide.md)
  「生成後のチェック」に沿って確認する
- 気に入らない場合はプロンプトを調整して再生成する。同じファイル名で上書きしてよい
  （Godotは`.import`キャッシュを自動更新する）
- 複数案から選びたい場合はImagen系で`--count`を上げるか、`--output`を変えて複数回実行し比較する

## 注意点

- 生成コストとレート制限を考慮し、依頼された分だけ生成する（バリエーション違いを大量生成しない）
- 生成物には著作権・利用規約上の制約がありうる。実在の人物・キャラクター・企業ロゴの模倣を
  プロンプトに含めない
- 生成したPNGは通常のバイナリアセットとしてコミット対象になる。サイズが大きい場合は
  `.claude/rules/performance.md`「テクスチャ最適化」（2の累乗サイズ推奨、アトラス化検討）も踏まえる
- APIキーをログ・コミット・チャット出力に含めない（`.claude/rules/security.md`）
