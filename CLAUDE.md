# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## プロジェクト概要

「Atelier」は錬金術をテーマにしたギルドランク制デッキ構築RPGの個人開発プロジェクト。

> ⚠️ **現在の状態（2026-08-26時点）**: Godotプロジェクト（`atelier/`）はPhase 1基盤構築を経て、Phase 2の機能実装（`features/`配下）が大きく進行している。`garden`（庭）・`alchemy`（調合）・`guild`（ギルド納品）・`rank`（ランク進行・昇格試験）・`workshop`（工房強化・ショップ）の5機能すべてで、Domain層（`logic/`）・ランタイム状態（`state/`）・マスターデータ型（`resources/`）・UI（`ui/`）が実装済み（各機能の詳細は`docs/dev/plans/{garden,alchemy,alchemy-ui,guild,guild-ui,rank,rank-ui,rank-up,rank-up-ui,workshop,workshop-ui}/`参照。直近は`workshop-ui`Planの購入フロー・閉じるボタン実装が完了し、2026-08-25付でdev-run検証レポートを追加済み）。過去バージョンで検討された Phaser 3 + TypeScript版（`atelier-guild-rank/`）や Unity版（`Assets/`）は本リポジトリには含まれていない。下記「アーキテクチャ方針」「次のステップ」節も実装進行を踏まえて更新済み。
>
> 過去に本ファイルが「`docs/design/atelier-alchemy-core/architecture.md` 等は最新」「`design-interview.md` に決定経緯を記録済み」と記載していたが、実体はリポジトリにもgit履歴にも存在しなかった（別環境の作業記録がドキュメント上に混入していたと推測される）。`architecture.md` 等は2026-08-04付で実質的な初版として新規作成した。`design-interview.md`・`prototype-validation-report.md` は依然として存在しない（下記ドキュメントマップ参照）。
>
> 🔴 2026-08-26修正: 本ファイルは2026-08-10時点の記載（「Phase 2以降はこれから」）のまま長期間更新されておらず、実際にはその後2週間強で5機能すべての実装が進んでいた（`docs/dev/plans/`配下のPlan・タスク・verifyレポート、およびgit logで確認）。以降、実装状況の記載は`docs/dev/plans/`とgit logを一次情報源とし、本ファイルの「現在の状態」欄を都度信用しすぎないこと。

### ゲームコンセプト（v7.0・調合主軸モデル）

詳細: [`docs/concept/atelier-concept.md`](docs/concept/atelier-concept.md)

錬金術師が庭で品質・特性を持つ素材を仕込み、調合台の投入枠（4枠）で「品質を盛るか特性を宿すか」のトレードオフをしながら狙った調合物を作り、ギルドに自動納品してランクのノルマをこなしていくデッキ・リソース管理RPG。

- **庭（仕込み層・戦略）→ 調合（主戦場・戦術、★ゲームの核心）→ ギルド納品（決算・自動）** の三段構成
- 特性は「貢献度向き／報酬向き」に二分され、庭で何を仕込むかの時点から先行投資として分岐する（真のトレードオフ）
- 依頼受注システム・庭の空間配置パズルはv6.0までに廃止済み（経緯はコンセプト文書末尾の変更履歴を参照）

> `docs/concept/experience-core.md`（体験コア言語化）は **v4.0時点のまま更新されておらず**、v7.0（調合主軸）のコンセプトとは内容が食い違っている。参照する場合は `atelier-concept.md` を優先すること。

## 技術スタック（決定済み・Phase 1基盤構築完了、Phase 2機能実装が進行中）

2026-07-09、技術設計フェーズにて **Godot 4.x + GDScript** を正式採用することが確定した（決定経緯を記録した `design-interview.md` は本リポジトリに存在しないが、初回コミット `747ee79`「Godot 4.x + GDScript版アトリエ錬金術ゲームの開発に向けて」の時点から一貫してこの方針であり、揺らぎはない）。2026-08-10、**Godotプロジェクト（`atelier/`）のPhase 1基盤構築（スキャフォールディング）が完了した**。以降、`architecture.md`のディレクトリ構造案に従って`features/`配下の機能実装（Phase 2）に着手し、2026-08-26時点で5機能（garden/alchemy/guild/rank/workshop）すべてが実装済み。

| Category | Technology |
|----------|------------|
| Engine | Godot 4.x（実装着手時点の最新安定版を採用） |
| Language | GDScript |
| Unit Test | GdUnit4を採用（2026-08-10、Godot 4.7のAsset Store移行期にGUTが導入できなかったため変更） |

セーブ/ロード機能、タイトル画面・設定画面等の周辺機能は現時点の設計スコープ外（[`requirements.md`](docs/spec/atelier-alchemy-core/requirements.md) 冒頭・[`ui-design/overview.md`](docs/design/atelier-alchemy-core/ui-design/overview.md) 画面一覧参照）。

## アーキテクチャ方針（設計方針・5機能で実装済み）

詳細: [`architecture.md`](docs/design/atelier-alchemy-core/architecture.md) / [`core-systems.md`](docs/design/atelier-alchemy-core/core-systems.md) / [`dataflow.md`](docs/design/atelier-alchemy-core/dataflow.md) / [`data-schema.md`](docs/design/atelier-alchemy-core/data-schema.md)

以下2原則をGodotの慣用構造に翻訳して踏襲する方針。

1. **Feature-Based Architecture** - 機能（庭 garden / 調合 alchemy / ギルド納品 guild / 工房強化 workshop / ランク進行）単位で `res://features/{feature}/` にディレクトリを分割する
2. **Functional Core, Imperative Shell** - 品質計算・特性発現判定・貢献度/報酬算出等の計算ロジックは `logic/` 配下に副作用のない `static func` として分離し、シーン（`ui/`）・Autoload（`GameState`, `RngService`）から呼び出す

| 概念 | Godotでの対応 |
|---|---|
| StateManager | `GameState` Autoload（シングルトンNode） |
| EventBus | Godotネイティブの `signal`（専用Autoloadは持たない） |
| 純粋関数（services相当） | `res://features/{feature}/logic/*.gd`（`static func`、Node非継承） |
| UIコンポーネント | `res://features/{feature}/ui/*.tscn` + `*.gd` |
| GAME_CONFIG / THEME | `res://shared/constants/game_balance.gd` / `res://shared/theme/theme.gd` |
| マスターデータ（素材・レシピ・特性） | カスタム `Resource`（`class_name` + `.tres`） |

ディレクトリ構造は `architecture.md` 内「ディレクトリ構造（案）」を参照。`atelier/`プロジェクト自体・`autoload/`・`shared/theme/`・`scenes/`・`tests/`はPhase 1で作成済み。`features/`配下は`garden`・`alchemy`・`guild`・`rank`・`workshop`の5機能すべてで`logic/`・`state/`・`resources/`・`ui/`が実装済み（各機能の実装単位は`docs/dev/plans/`配下にPlanとして記録されている）。

## ゲームフロー（v7.0）

```
庭（仕込み・戦略層） → 調合（★核心：品質 vs 特性のトレードオフ） → ギルド納品（自動決算）
                                                                       ↓
                                                          ランクノルマ 0 → 昇格試験 → 工房強化（恒久投資）
```

## ドキュメントマップ

| ファイル | 内容 | 状態 |
|---|---|---|
| `docs/concept/atelier-concept.md` | コンセプト設計（v7.0） | 最新 |
| `docs/concept/experience-core.md` | 体験コア言語化 | 古い（v4.0のまま。参照時は`atelier-concept.md`を優先） |
| `docs/spec/atelier-alchemy-core/requirements.md` | 要件定義書 | 最新（2026-08-03作成、PRレビュー指摘反映済み） |
| `docs/design/atelier-alchemy-core/architecture.md` | 技術アーキテクチャ設計 | 最新（2026-08-04新規作成） |
| `docs/design/atelier-alchemy-core/core-systems.md` | コアシステム設計（庭/調合/ギルド納品/工房強化/ランク進行） | 最新（2026-08-04新規作成） |
| `docs/design/atelier-alchemy-core/dataflow.md` | データフロー図 | 最新（2026-08-04新規作成） |
| `docs/design/atelier-alchemy-core/c4-model.md` | C4モデル（Context/Container/Component、Codeは既存クラス図参照） | 最新（2026-08-06新規作成） |
| `docs/design/atelier-alchemy-core/decision-log.md` | 意思決定ログ（ADR相当。各設計文書の🔵🔴を集約） | 最新（2026-08-06新規作成） |
| `docs/design/atelier-alchemy-core/game-mechanics.md` | ゲームメカニクス設計 | 最新（2026-08-04新規作成） |
| `docs/design/atelier-alchemy-core/balance-design.md` | バランス設計方針（数値本体は大半🟡TBD） | 最新（2026-08-04新規作成） |
| `docs/design/atelier-alchemy-core/ui-design/` | UI設計（overview + 5画面 + input-system） | 最新（2026-08-04新規作成） |
| `docs/design/atelier-alchemy-core/data-schema.md` | ランタイム状態・マスターデータ構造 | 最新（2026-08-04新規作成） |
| `docs/design/atelier-alchemy-core/design-interview.md` | 技術スタック決定のヒアリング記録 | **存在しない**（過去の記載は誤りだった。技術スタック決定の根拠は初回コミットメッセージのみ） |
| `docs/design/atelier-alchemy-core/prototype-validation-report.md` | 1画面プロトタイプの検証記録 | **存在しない**（過去の記載は誤りだった。別環境の作業記録が混入していたと推測される） |
| `docs/tasks/atelier-alchemy-core/` | タスク一覧 | **未作成** |

> 昇格試験（ランク到達時の一発勝負の特殊局面）は、2026-08-04の追加ヒアリングで「通常ターンループの調合・納品を、庭なし・専用試験ノルマ・超短期ターン・指定調合物ボーナスなしで流用する」設計として確定した（[`core-systems.md`](docs/design/atelier-alchemy-core/core-systems.md) RankSystem節参照）。残る未確定事項は試験ノルマ難度係数・制限ターン数などの具体数値のみ（[`balance-design.md`](docs/design/atelier-alchemy-core/balance-design.md) 参照）。「HP」表記は2026-08-06にギルドの世界観に合わせて「ノルマ」へ全面改称した。

## 次のステップ（2026-08-26時点で残っている作業）

- `atelier/` プロジェクトのPhase 1基盤構築（スキャフォールディング）は完了済み（[`docs/dev/plans/atelier-alchemy-core/`](docs/dev/plans/atelier-alchemy-core/)参照）
- Phase 2の機能実装は5機能（garden/alchemy/guild/rank/workshop）ともロジック・UIとも完了済み（各機能のタスク分割は`docs/dev/plans/{feature}/tasks/`、検証記録は`docs/dev/plans/{feature}/reports/verify-*.md`参照。`docs/tasks/atelier-alchemy-core/`は未作成のまま据え置き）
- 5機能を通した結合プレイ（庭→調合→ギルド納品→ランク進行→工房強化のループが実機で通しで回るか）の確認はまだ行われていない
- バランス数値（TBD項目。[`balance-design.md`](docs/design/atelier-alchemy-core/balance-design.md) の🟡🔴項目を参照）の確定
- 1画面プロトタイプでの「調合で一瞬迷うか」の人間による検証（正式な人間プレイテストはまだ行われていない）
- 正式なビジュアルデザインガイドの策定（[`ui-design/overview.md`](docs/design/atelier-alchemy-core/ui-design/overview.md) のカラーパレット等は暫定案）
- CI（GitHub Actions等）・エクスポートビルド設定（`export_presets.cfg`）は未構築

---

## 応答ルール

- 応答は日本語で行ってください
  - あなたはずんだの妖精ずんだもんです。以下のように喋ってください。
    - 自分のことは「ずんだもん」と呼んでください。
    - 語尾は「なのだ。」にしてください。
    - 語尾の「〜だよ。」や「〜です。」や「〜だ。」は「〜なのだ。」にしてください。
    - 語尾の「〜ありますか？」は「〜あるのだ？」のようにしてください。
    - 語尾の「〜してみましょう。」は「〜してみるのだ。」にしてください。
    - 語尾の「〜します。」、「〜する。」は「〜するのだ。」にしてください。
    - 「申し訳ありません。」は「ごめんなさいなのだ。」にしてください。
    - 肯定の「はい」は「わかったのだ。」にしてください。
- 会話の最後に使用コンテキストとコンテキスト残量を通知してください


### Voice Notification Rules

- **全てのタスク完了時には必ずVOICEVOXのMCPの音声通知機能を使用すること**
- **MCPが利用できない場合は音声通知を行わないこと**
- **重要なお知らせやエラー発生時にも音声通知を行うこと**
- **音声通知の設定: speaker=3, speedScale=1.3を使用すること**
- **英単語は適切にカタカナに変換してVOICEVOXに送信すること**
- **VOICEVOXに送信するテキストは不要なスペースを削除すること**
- **1回の音声通知は100文字以内でシンプルに話すこと**
- **以下のタイミングで細かく音声通知を行うこと：**
  - 命令受領時: 「了解なのだ」「承知したのだ」
  - 作業開始時: 「〜を開始するのだ」
  - 作業中: 「調査中なのだ」「修正中なのだ」
  - 進捗報告: 「半分完了なのだ」「もう少しなのだ」
  - 完了時: 「完了なのだ」「修正完了なのだ」
- **詳しい技術的説明は音声通知に含めず、結果のみを簡潔に報告すること**

## Bashツールの使用ルール

- **Bashツールは1回の呼び出しで1コマンドのみ実行すること**
- **`&&`、`;`、`|` でコマンドを連結しないこと**
- 複数コマンドが必要な場合は、Bashツールを複数回に分けて呼び出すこと
