---
name: screen-craft
description: |
  Godot（atelier/）の画面・UI実装を「背景」「ゲームプレイ空間」「HUD/操作UI」「モーダル/オーバーレイ」の
  4レイヤーに分解し、各要素にスプライトシート／Tween／パーティクルのどれが向くかを選んでから実装する
  スキル。「〇〇画面を作って」「〇〇画面を実装して」のような明示的な画面実装依頼はもちろん、
  「いい感じにして」「見栄えを良くして」「演出を追加して」「なんか味気ない」のような曖昧な演出強化依頼、
  features/{feature}/ui/配下の新規UI実装・既存画面の改修全般でも積極的に使うこと。本プロジェクトの
  5機能は全てロジック実装済みだが背景装飾・遷移演出・操作フィードバックはほぼ未着手（各screens/*.mdの
  アニメーション表が🟡TBDのまま）なので、UI関連の作業依頼では基本的にこのスキルの手順を通すのが安全。
  design-guide.md・ui-components.md・godot-best-practices.md・architecture.mdの既存ルールと
  docs/design/atelier-alchemy-core/ui-design/の設計書フォーマットに沿わせた上で、実際にGodotの
  Control/CanvasLayer/Tween/AnimatedSprite2D/GPUParticles2Dへ落とし込むところまで面倒を見る。
---

# 画面クラフト（screen-craft）

本プロジェクトの5機能（庭・調合・ギルド納品・工房・ランク）はUI画面としてはすでに動くが、背景装飾・
画面遷移・操作フィードバックのアニメーションはほとんど手つかずのまま残っている（各
`docs/design/atelier-alchemy-core/ui-design/screens/*.md`の「アニメーション」表が🟡TBDのまま、
実コードにも`Tween`/`AnimatedSprite2D`/`GPUParticles2D`が1件も使われていない）。このスキルは
「動くUI」を「見て気持ちいいUI」に仕上げる作業を、思いつきの装飾追加ではなく次の手順で行う。

## なぜレイヤーで考えるのか

Godotのシーンツリーはそのまま描画順になる。「背景」「操作対象」「常時表示UI」「一時的なポップアップ」を
最初から別ノード群として分離しておくと、後から一つだけ差し替えたり演出を足したりしやすい。逆に全部を
1つの`Control`階層に混ぜて作ると、モーダルを開いた時に裏のボタンが押せてしまう、背景の模様替えのために
本体UIまで触る羽目になる、といった事故が起きやすい。

## ワークフロー

### 0. スタイルを確認する

本プロジェクトは「水彩ファンタジースタイル」（`.claude/rules/design-guide.md`）に統一済みなので、
まずは以下を読んで既にある答えを使う。新しい色・角丸値が本当に必要になった時だけ`UiTheme`に追加し、
直書きはしない。

- `.claude/rules/design-guide.md` — 色・角丸・ボタン種別・フェーズアクセントカラーの規約（ダーク背景禁止）
- `docs/design/atelier-alchemy-core/ui-design/overview.md` — 画面一覧・共通コンポーネント（`RankHud`等）
- `atelier/shared/theme/theme.gd`（`UiTheme`） — 実際に定義済みの色・フォント定数

これらに答えがない新規要素（新しいエフェクト色など）が本当に必要な場合のみ、ユーザーに一言確認する。

### 1. 画面を必要なレイヤーだけに分解する

4つ全部を毎回使う必要はない。本プロジェクトの画面はスクロールする2Dワールドやプレイヤーキャラクターを
持たない、基本的に静的な`Control`ツリーなので、多くの画面は「背景」+「HUD」の2層で十分で、ポップアップを
開く画面だけ「モーダル」が加わる。「ゲームプレイ空間」は素材カード・調合スロットのような操作対象の
一群を指すだけで、`Camera2D`のようなワールド描画は基本的に不要と考えてよい。

| レイヤー | このプロジェクトでの実体 | 必要になる場面 |
|---|---|---|
| 背景 | `UiTheme`の背景色を敷いた`ColorRect`/`Panel`、装飾したい場合は`TextureRect` | ほぼ全画面 |
| ゲームプレイ空間 | カード・スロットを並べる`Container`系ノード一式（`GridContainer`等） | 庭・調合など操作対象の「モノ」がある画面 |
| HUD/操作UI | 全画面共通の`RankHud`＋画面固有の常時ボタン・表示 | 全画面 |
| モーダル/オーバーレイ | `open_singleton()`パターンで最前面に出すポップアップ | ポップアップ・割り込み表示がある画面のみ |

各レイヤーの具体的なノード構成とコード例は[references/layers.md](references/layers.md)を参照。
特にモーダルは`PauseMenu`/`SettingsPanel`が既に使っている`open_singleton(current, overlay_parent,
on_closed)`という多重起動防止パターンがあるので、新規に別方式を発明しない。

**重要**: このレイヤー分解はあくまで「考え方」であり、既存画面の`.tscn`が実際にこの4層に分離された
ノード構成を持っているとは限らない（実際、現状の`garden_screen.tscn`/`workshop_screen.tscn`等は
背景専用ノードを持たず、ヘッダー行〔ゴールド表示・タブ等〕と本体コンテンツが同じ`VBoxContainer`に
混在している）。手を入れる画面では必ず`.tscn`を開いて実際のノードツリーを確認し、以下のように
その場でレイヤーを実体化させる。

- 背景レイヤーが存在しない → 画面ルートの最初の子として`Background`ノード（`ColorRect`等）を追加する
- ヘッダー的な要素（画面固有の常時表示ボタン・ラベル）が本文コンテンツと同じコンテナに混在している →
  可能なら別コンテナに分離する。ただしテストコードが`%UniqueName`で既存ノードパスを参照している場合は
  リネーム・移動でテストが壊れないか必ず確認してから行う（壊れそうならレイヤー分離は見送り、視覚的な
  区別〔余白・区切り線〕で代替してよい）
- モーダル用の`OverlayLayer`ノードは既に一部画面にあるが名称が画面ごとに揺れている
  （`OverlayLayer`, `SettingsOverlayLayer`等）。新規に追加する時は`OverlayLayer`に揃える。
  既存の名前を持つノードは、今回のタスクに関係ないなら統一のためだけにリネームしない

### 2. 要素ごとにアニメーション手法を割り当てる

「動きをつける」と考える前に、どの技法が向いているかを要素ごとに割り振る。

| 手法 | 向いている場面 | 判断の目安 |
|---|---|---|
| スプライトシート（`AnimatedSprite2D`） | 決まった状態を繰り返す見た目変化 | 「歩く」「待機」のような反復モーションが要る時 |
| Tween（`create_tween()`） | 数値・プロパティの補間全般。本プロジェクトの演出の主力 | カードを引く動き、バーの増減、フェード、ボタンのバウンス |
| パーティクル（`GPUParticles2D`） | 一瞬だけ強調したいエフェクト | 調合成功のきらめき、収穫の飛び散り、昇格演出 |

迷ったら「繰り返す状態か→スプライトシート」「数値やプロパティが変わるだけか→Tween」「一瞬だけ
盛り上げたいか→パーティクル」の順で考える。コード例は[references/animation.md](references/animation.md)。
演出も`.claude/rules/performance.md`（`_process()`で重い処理をしない）・`godot-best-practices.md`
（`Tween`/`Timer`の停止漏れ禁止、繰り返し生成するカードはオブジェクトプーリングを検討）に従う。

### 3. 画面設計書を書く・更新する

`docs/design/atelier-alchemy-core/ui-design/screens/{screen}.md`に、既存の`screens/garden.md`と
同じ構成（基本情報／ワイヤーフレーム／UI要素／状態遷移／アニメーション／イベント／アクセシビリティ）で
書く。テンプレートと埋め方は[references/screen-doc-template.md](references/screen-doc-template.md)。

- **新規画面**: ファイルを新規作成し、`overview.md`の画面一覧テーブルにも1行追加する
- **既存画面の演出追加**: 対象ファイルの「アニメーション」セクションなど該当箇所のみ更新する。
  設計書全体を作り直す必要はない（`.claude/rules/planning.md`の「計画は軽量に」を踏襲）

### 4. Godotシーンとして実装する

`architecture.md`のFeature-Based構成（`features/{feature}/ui/`）・`coding-style.md`の命名規則・
`ui-components.md`のライフサイクル規約に従う。既存実装で徹底されている以下は必ず踏襲する。

- 色・フォントサイズは`UiTheme`経由（直書き禁止）
- `GameState`のsignal購読は`_ready()`で`connect`、`_exit_tree()`で`disconnect`
  （[state-management.md](../../rules/state-management.md)。自ノードの子が発行するsignalは対象外）
- 繰り返し生成するカード等は[godot-best-practices.md](../../rules/godot-best-practices.md)の
  「オブジェクトプーリング」を検討する
- 日本語テキストは`UiTheme.FONT_MAIN`系のCJK対応フォントが当たっていることを確認する（豆腐文字対策）

### 5. 動作確認する

- signal発火・状態更新などロジック連携は`tests/integration/`にGdUnit4シーンテストを追加する
- 見た目・アニメーションのタイミングは自動テストで検証できないため、Godotエディタでの手動プレイか
  デバッグビルドで目視確認する（[godot-debug-tools.md](../../rules/godot-debug-tools.md)参照。
  `--headless`実行下ではスクリーンショットが撮れない点に注意）
- 何を確認してどう見えたかをユーザーに一言報告する。実機確認ができない環境なら、その旨を明言し
  「コードレビューはできたが目視確認はできていない」と伝える（できてもいない確認を「完了」と言わない）

## このスキルを使わなくていい場合

テキストの文言修正だけ、既存ボタンの配置換えだけなど、レイヤー構成にもアニメーションにも関わらない
軽微な修正では、このワークフロー全体を回す必要はない。関連箇所だけ直接編集すればよい。
