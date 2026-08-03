# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## プロジェクト概要

「Atelier」は錬金術をテーマにしたギルドランク制デッキ構築RPGの個人開発プロジェクト。

> ⚠️ **現在の状態（2026-08-03時点）**: 本リポジトリには**まだ実装コードが存在しない**。存在するのは `docs/concept/`（コンセプト設計）と `docs/design/atelier-alchemy-core/`（技術設計）のみ。過去バージョンで検討された Phaser 3 + TypeScript版（`atelier-guild-rank/`）や Unity版（`Assets/`）は本リポジトリには含まれていない。実装はこれから、設計文書に従って新規に開始する。

### ゲームコンセプト（v7.0・調合主軸モデル）

詳細: [`docs/concept/atelier-concept.md`](docs/concept/atelier-concept.md)

錬金術師が庭で品質・特性を持つ素材を仕込み、調合台の投入枠（4枠）で「品質を盛るか特性を宿すか」のトレードオフをしながら狙った調合物を作り、ギルドに自動納品してランク（＝敵）のHPを削っていくデッキ・リソース管理RPG。

- **庭（仕込み層・戦略）→ 調合（主戦場・戦術、★ゲームの核心）→ ギルド納品（決算・自動）** の三段構成
- 特性は「貢献度向き／報酬向き」に二分され、庭で何を仕込むかの時点から先行投資として分岐する（真のトレードオフ）
- 依頼受注システム・庭の空間配置パズルはv6.0までに廃止済み（経緯はコンセプト文書末尾の変更履歴を参照）

> `docs/concept/experience-core.md`（体験コア言語化）は **v4.0時点のまま更新されておらず**、v7.0（調合主軸）のコンセプトとは内容が食い違っている。参照する場合は `atelier-concept.md` を優先すること。

## 技術スタック（決定済み・実装未着手）

2026-07-09、技術設計フェーズにて **Godot 4.x + GDScript** を正式採用することが確定した（決定経緯: [`docs/design/atelier-alchemy-core/design-interview.md`](docs/design/atelier-alchemy-core/design-interview.md)）。ただし **Godotプロジェクト（`atelier-godot/`）のスキャフォールディングはまだ行われていない**。実装着手時は設計文書に従って新規プロジェクトを作成するところから始める。

| Category | Technology |
|----------|------------|
| Engine | Godot 4.x（実装着手時点の最新安定版を採用） |
| Language | GDScript |
| Unit Test | GUT（Godot Unit Test）を採用予定 |

セーブ/ロード機能、タイトル画面・設定画面等の周辺機能は現時点の設計スコープ外（[`design-interview.md`](docs/design/atelier-alchemy-core/design-interview.md) Q3, Q6）。

## アーキテクチャ方針（設計のみ・実装未着手）

詳細: [`architecture.md`](docs/design/atelier-alchemy-core/architecture.md) / [`dataflow.md`](docs/design/atelier-alchemy-core/dataflow.md) / [`data-model.md`](docs/design/atelier-alchemy-core/data-model.md)

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

計画中のディレクトリ構造（未作成）は `architecture.md` 内「ディレクトリ構造（案）」を参照。実装着手時にこの案に従って `atelier-godot/` を新規作成する。

## ゲームフロー（v7.0）

```
庭（仕込み・戦略層） → 調合（★核心：品質 vs 特性のトレードオフ） → ギルド納品（自動決算）
                                                                       ↓
                                                          ランクHP 0 → 昇格試験 → 工房強化（恒久投資）
```

## ドキュメントマップ

| ファイル | 内容 | 状態 |
|---|---|---|
| `docs/concept/atelier-concept.md` | コンセプト設計（v7.0） | 最新 |
| `docs/concept/experience-core.md` | 体験コア言語化 | 古い（v4.0のまま。参照時は`atelier-concept.md`を優先） |
| `docs/design/atelier-alchemy-core/architecture.md` | 技術アーキテクチャ設計 | 最新 |
| `docs/design/atelier-alchemy-core/dataflow.md` | データフロー図 | 最新 |
| `docs/design/atelier-alchemy-core/data-model.md` | データモデル定義（GDScript） | 最新 |
| `docs/design/atelier-alchemy-core/design-interview.md` | 技術スタック決定のヒアリング記録 | 最新 |
| `docs/design/atelier-alchemy-core/prototype-validation-report.md` | 1画面プロトタイプの検証記録 | ⚠️下記参照 |
| `docs/spec/atelier-alchemy-core/requirements.md` | 要件定義書 | **未作成**（design配下の各文書がリンク・前提にしているが本リポジトリには存在しない） |
| `docs/tasks/atelier-alchemy-core/` | タスク一覧 | **未作成** |

> ⚠️ `prototype-validation-report.md` は `atelier-godot/features/prototype/...` の実装やTASK-0009/0010の存在を前提に書かれているが、本リポジトリには該当コード・タスク管理文書のいずれも存在しない。別環境で行われた作業の記録が紛れ込んでいる可能性があるため、内容を実装の前提にする前に整合性を確認すること。

## 次のステップ（実装着手前に必要な作業）

- 要件定義書（`docs/spec/atelier-alchemy-core/requirements.md`）の作成（design配下の文書群が前提として参照しているが未作成）
- タスク分割（`docs/tasks/atelier-alchemy-core/`）
- `atelier-godot/` プロジェクトのスキャフォールディング（Phase 1基盤構築）
- バランス数値（TBD項目。`architecture.md`内の🟡項目を参照）の確定
- 1画面プロトタイプでの「調合で一瞬迷うか」の人間による検証（`prototype-validation-report.md`はAIによる代替記録であり、正式な人間プレイテストは別途必要）

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
