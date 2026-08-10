# 意思決定ログ（ADR相当）

作成日: 2026-08-06

## 概要

`docs/design/atelier-alchemy-core/`・`docs/spec/atelier-alchemy-core/`の各設計文書には、決定事項・修正履歴が🔵（確定済み事項の引用）🟡（本文書内での新規推測・提案）🔴（PRレビュー等での重大な修正）の記号付きで個別に埋め込まれている。本文書はそのうち**プロジェクト全体に影響する意思決定**をトピック別に集約し、1箇所から辿れるようにしたものである。

各項目の一次ソース（記載元の設計文書・行）は必ず明記する。**本文書は要約であり、詳細な理由・数式・代替案の検討過程は一次ソース側にのみ記載されている場合がある**。数値の正誤や実装可否を判断する際は必ず一次ソースを確認すること。

凡例: 🔵確定事項の集約 / 🔴PRレビュー等での重大修正の集約（本文書での格付けは元文書の記号をそのまま踏襲）

---

## 1. 技術スタック・アーキテクチャ

| 決定 | 一次ソース | 備考 |
|---|---|---|
| 🔵 Godot 4.x + GDScriptを正式採用 | `CLAUDE.md`（初回コミット`747ee79`時点から一貫） | `design-interview.md`は本リポジトリ・git履歴のいずれにも存在せず、決定経緯の一次ソースはコミットメッセージのみ |
| 🔵 Feature-Based Architecture + Functional Core, Imperative Shell を採用 | `.claude/rules/architecture.md`、[`architecture.md`](./architecture.md)§アーキテクチャパターン | プロジェクト共通方針として確定。2026-08-06に`.claude/rules/`配下をGDScript向けに全面書き換え（本ログ§6参照） |
| 🔵 StateManager→`GameState` Autoload、EventBus→Godot `signal`に対応付け | [`architecture.md`](./architecture.md)§対応表 | RNGサービス行のみ本文書での明確化（🟡新規追記） |
| 🟡→🔵 `logic/*.gd`に`class_name`を付与する方針に統一 | [`architecture.md`](./architecture.md) 2026-08-05修正 | PRレビュー（Naming/Warning#3）で「`class_name`なし」と規定しつつ全文書がグローバル識別子呼び出しを前提にしていた矛盾を解消 |
| 🔵 独立した`interfaces.gd`は作成しない | [`architecture.md`](./architecture.md)§インターフェース定義について | `logic/*.gd`は多態性を要さない`static func`集合、Autoloadは単一実装のためインターフェース化の需要がない |
| 🔴 検証責務の二重化原則を追加（Presentationは先出しフィードバックのみ、Application層が実行直前に必ずDomain層を再評価） | [`architecture.md`](./architecture.md)§検証責務のレイヤー配置原則、2026-08-05追加 | PRレビューで「投入枠上限・在庫重複投入を検証するDomain層関数が存在しない」等の指摘を受け全設計文書共通の原則として確定 |

---

## 2. ゲームコンセプト・ゲームメカニクス

| 決定 | 一次ソース | 備考 |
|---|---|---|
| 🔵 v7.0「調合主軸モデル」を採用（庭→調合→ギルド納品の三段構成） | `CLAUDE.md`、[`docs/concept/atelier-concept.md`](../../concept/atelier-concept.md) | 依頼受注システム・庭の空間配置パズルはv6.0までに廃止済み |
| 🔴 触媒特性の品質ボーナス適用位置を「素材自身の品質」から「平均・四捨五入後の最終品質+1」に変更 | [`core-systems.md`](./core-systems.md)§AlchemySystem、PRレビューCritical#6対応 | 旧仕様は平均計算で効果がほぼ相殺され消える欠陥があった |
| 🔴 指定合致ボーナスの適用責務を`GuildSystem.DeliveryResolver`に一本化（`ProductValueCalculator`からは`order_match_bonus`引数を削除） | [`core-systems.md`](./core-systems.md)§AlchemySystem/GuildSystem、[`game-mechanics.md`](./game-mechanics.md)L119、PRレビューCritical#4対応 | 旧版は両関数に適用責務があるように読め、実装すると二重乗算になるバグが判明したため「調合時点」と「納品時点」の2段階に式を分離 |
| 🔵 特性発現は同一特性タグ2個以上でブール発現（3個目以降は据え置き） | [`core-systems.md`](./core-systems.md)§AlchemySystem | 要件定義書§4「特性タグ（Trait）」に確定済み |
| 🔵 レシピは調合実行前の事前選択方式 | [`core-systems.md`](./core-systems.md)§AlchemySystem、2026-08-04ヒアリング | 解禁済みレシピは最低1件保証 |
| 🔴 `SlotState.can_execute`に投入枠上限チェックを追加 | [`core-systems.md`](./core-systems.md)§AlchemySystem、PRレビューWarning#7対応 | 旧版は下限1個のみで上限`max_slots`の検証が抜けていた |
| 🔴 `Harvest.harvest`の乱数引数を`rng_roll_quality`/`rng_roll_trait`の2値に分離 | [`core-systems.md`](./core-systems.md)§GardenSystem、PRレビューArchitecture-W04/Error Handling-W09対応 | 旧版はDomain層内部で2つ目の乱数を自己生成できる読み取りが可能で純粋性原則に反していた |
| 🔴 `Harvest.resolve_withering`を追加（ターン終了処理で`advance_growth`直後に必ず呼ぶ） | [`core-systems.md`](./core-systems.md)§GardenSystem、PRレビューCritical#11対応 | 枯死した株をスロットから解放する処理が欠落していた |
| 🔴 `end_turn()`の呼び出し元とトリガー操作を明記 | [`dataflow.md`](./dataflow.md)L56、実装レディネス監査対応（2026-08-06） | 旧版は庭/調合画面の「ターン終了」ボタンとの対応関係が全設計文書から欠落していた |

---

## 3. ランクシステム・昇格試験

| 決定 | 一次ソース | 備考 |
|---|---|---|
| 🔵 昇格試験は通常ターンループ（`AlchemySystem`/`GuildSystem`）を庭なし・専用ノルマ・超短期ターンで流用する | [`core-systems.md`](./core-systems.md)§RankSystem、2026-08-04ヒアリング確定 | 新規のゲームメカニクスを発明しない設計判断 |
| 🔴 試験ノルマの算出式を変更（`quota_max × 倍率`→`(quota_max ÷ limit_turn) × exam_turn_limit × exam_difficulty_coefficient`） | [`core-systems.md`](./core-systems.md)§RankSystem、[`data-schema.md`](./data-schema.md)L207、PRレビューCritical#5対応 | 旧式は試験制限ターンが1〜2ターンしかないため要求貢献度が通常ランクの約20倍になり成立しなかった |
| 🔴 「ターンを進める」操作を調合実行なしでも常時選択可能に | [`core-systems.md`](./core-systems.md)§RankSystem、`PromotionExamResolver.advance_turn`、PRレビューCritical#10対応 | 旧版は調合実行時にしかターンが進まず、在庫・解禁レシピが尽きるとデッドロックした |
| 🔴 `RankQuotaResolver.reset_for_retry`を追加、降格回数カウンタのリセット/加算タイミングを確定 | [`core-systems.md`](./core-systems.md)§RankSystem、PRレビューCritical#3対応 | 試験失敗（同ランク再挑戦）時のノルマ・カウンタ挙動が未定義だった |
| 🔵 ランクノルマが制限ターンより先に0になっても、試験への移行は制限ターン到達まで待つ | [`core-systems.md`](./core-systems.md)§RankSystem、2026-08-05ヒアリング | 早期クリア後の残りターンは通常プレイを継続できる意図的なボーナスとする |
| 🔴 シーン遷移図の`WorkshopScreen`配置を修正（`MainScene`の子Controlとして再配置） | [`architecture.md`](./architecture.md)L188、実装レディネス監査対応（2026-08-06） | 旧版は「シーン構成」表の記述と矛盾し、庭/調合画面からのオーバーレイ遷移経路も欠落していた |

---

## 4. 用語統一（HP→ノルマ）

| 決定 | 一次ソース | 備考 |
|---|---|---|
| 🔴 「HP」表記を「ノルマ」に全面改称（`max_hp`→`quota_max`、`RankHpResolver`→`RankQuotaResolver`、`exam_hp`→`exam_quota`等） | [`core-systems.md`](./core-systems.md)L311、[`data-schema.md`](./data-schema.md)L209、[`ui-design/screens/promotion-exam.md`](./ui-design/screens/promotion-exam.md)L42 | 2026-08-06、ギルドの認定制度という世界観に合わせるための全面改称。計算ロジック自体（`max(0, 残量-貢献度)`のクランプ処理）は変更なし |
| 🔵 リネーム漏れの修正 | git commit `59b44c0`「docs: HP→ノルマ用語統一のリネーム漏れ2箇所を修正」 | 全面改称後の追従修正 |

---

## 5. ドキュメント体系そのものに関する決定

| 決定 | 一次ソース | 備考 |
|---|---|---|
| 🔴 旧`CLAUDE.md`が「最新」と参照していた`architecture.md`等の設計文書一式は、本リポジトリ・git履歴のいずれにも実体がなかった | `CLAUDE.md`冒頭の警告文、2026-08-04 | 別環境の作業記録がドキュメント上に混入していたと推測される。`architecture.md`等は2026-08-04付で実質的な初版として新規作成 |
| 🔴 `design-interview.md`・`prototype-validation-report.md`は存在しない | `CLAUDE.md`ドキュメントマップ | 同上の理由。技術スタック決定の根拠は初回コミットメッセージのみに依拠する |
| 🔵 要件定義書§8にユビキタス言語一覧を追記 | git commit `cfcc983`「docs: 要件定義書にユビキタス言語一覧（§8）を追記」 | PR #3 |
| 🔵 C4モデル（Context/Container/Component + Codeは既存クラス図参照）を作成 | [`c4-model.md`](./c4-model.md)、2026-08-06 | `architecture.md`/`core-systems.md`の内容をC4記法に翻訳したもの |

---

## 6. `.claude/rules/`のGodot/GDScript対応（2026-08-06実施）

技術スタックがGodot 4.x + GDScriptに確定していたにもかかわらず、`.claude/rules/`配下の以下のファイルがPhaser 3 + TypeScript + pnpm/Vitest/Playwright前提のまま放置されていたため、全面的にGodot/GDScript/GUT前提へ書き換えた。

| ファイル | 変更内容 |
|---|---|
| `architecture.md` | Feature-Based/FCIS説明をGDScript例に書き換え |
| `coding-style.md` | TypeScript命名規則・型安全性ルールをGDScript（snake_case、静的型付け）に書き換え |
| `phaser-best-practices.md` → `godot-best-practices.md` | Phaserシーンライフサイクル・rexUI前提を、Godotノードライフサイクル・標準`Control`ノード前提に置き換え（ファイル名変更、旧ファイル削除） |
| `state-management.md` | StateManager/EventBus(TS)パターンを`GameState` Autoload + `signal`パターンに書き換え |
| `tdd-implementation.md` | VitestベースのRed/Green/RefactorをGUTベースに書き換え |
| `testing.md` | Vitest+Playwright前提のテスト種別・配置をGUT前提に書き換え。E2Eは「GUTシーンテスト＋手動プレイテスト」に置き換え |
| `ui-components.md` | Phaser `BaseComponent`パターンをGodot `Control`継承コンポーネントパターンに書き換え |
| `performance.md` | Phaserの`update()`/Tween/テクスチャアトラス最適化をGodotの`_process()`/`Tween`ノード/`AtlasTexture`に書き換え |
| `playwright-mcp.md`・`playwright-mcp-cookbook.md` → `godot-debug-tools.md` | ブラウザ自動操作前提のMCP運用ルールを削除し、Godotエディタのリモートシーンツリー＋GUT統合テストによる調査・検証手順に置き換え（旧2ファイル削除） |
| `bash-commands.md` | pnpmコマンド例をGodot/GUTコマンドに更新 |
| `implement-workflow.md` | コミット前必須確認・実装チェックリストをGUT/gdlint/gdformatベースに更新 |
| `pipeline-rules.md` | Step1実装完了確認コマンドを更新 |
| `design-guide.md` | カラー参照のコード例をTypeScript importからGDScriptの`UiTheme`参照構文に更新 |
| `security.md` | Web前提（localStorage/XSS/.env）の記述をGodotオフライン単体アプリの文脈に調整 |
| `code-review.md` | 「Warning の基準」のTypeScript固有項目（any型等）をGDScript向け（`Variant`型等）に調整 |
| `git-workflow.md` | コンフリクト解消手順の検証コマンド例（pnpm test/typecheck/lint）をGUT/gdlint/gdformatに更新 |

**判断の根拠**: `.claude/rules/`はClaude Codeが実装エージェントとして参照する運用ルールであり、内容が実際の技術スタックと乖離していると、実装フェーズで誤ったルール（存在しないpnpm/Vitestコマンドの実行、Phaser APIの誤用等）に従うリスクが高い。設計文書（`docs/design/`）とは異なり実装作業に直接影響するため、実装着手前の対応が必要と判断した。

### 6.1 スコープ外として残っている箇所（未移行、要フォローアップ）🔴

本対応のスコープは`.claude/rules/`配下に限定した。以下は同じくpnpm/Vitest/Phaser/v6.0「依頼（Quest）」前提のまま**未移行**であり、実行すると壊れるか、存在しないディレクトリ・存在しない語彙を対象にする。

| 場所 | 問題 |
|---|---|
| `.claude/commands/self-healing-pipeline.md` | 品質ゲートとして`pnpm test`等を実行し、pnpmが見つからない場合は終了する仕様のため、このコマンドは起動直後に終了する |
| `.claude/commands/codebase-health-scanner.md` | 存在しない`atelier-guild-rank/src`を走査対象にしている |
| `.claude/commands/batch-issue-processor.md` | pnpm前提のコマンド例が残存 |
| `.claude/skills/balance-tuning-cycle/`（SKILL.md・references配下） | pnpm/シミュレーション実行コマンドが旧スタック前提 |
| `.claude/skills/content-gen-pipeline/`（SKILL.md・references配下） | pnpm前提のコマンド例、およびv6.0「依頼（Quest）」語彙のエージェントプロンプトが残存 |
| `.claude/settings.json` | `pnpm --filter atelier-guild-rank`・`mcp__playwright`の許可設定に加え、`Write`/`Edit`のたびに自動実行される`PostToolUse`フックが`atelier-guild-rank`への`cd`とbiome実行を試みる（存在しないディレクトリのため`2>/dev/null \|\| true`で握り潰され現状無害だが、他の許可設定と異なり**現在も毎回自動実行されている**点で緊急性の性質が異なる） |

**判断の根拠**: 上記はいずれも実装着手（`atelier/`スキャフォールディング）より前には実行される見込みが低く、`.claude/rules/`ほど緊急性が高くないと判断してスコープ外とした。ただし`self-healing-pipeline.md`のように今すぐ実行すれば即座に壊れるコマンドや、`settings.json`のPostToolUseフックのように**現在も毎回自動実行されている**設定を含むため、**移行完了と誤解しないこと**。[Issue #5](https://github.com/yaguma/alchemy-atelier/issues/5)で追跡し、実装着手前までに対応する。

### 6.2 再レビューで確定した設計判断（2026-08-07追記）🔵

PR #4への再レビューで指摘を受け、以下を確定した。

- **カバレッジ目標は数え上げ基準に一本化**: `testing.md`・`tdd-implementation.md`・`architecture.md`の3ファイルがそれぞれ異なるカバレッジ基準（%目標 / 数え上げ基準 / 未言及）を掲げていた。GDScript/GUTには標準のカバレッジ計測機構がなく%目標は達成判定不能なため、「`logic/*.gd`の全public `static func`に正常系・異常系・境界値のテストを最低1本ずつ持つ」という数え上げ基準に3ファイルとも統一した。
- **`GameState.get_state()`は`duplicate(true)`で防御的コピーを返す**: GodotのDictionary/Arrayは参照型であり、TypeScript版の`Readonly<T>`のような静的な書き換え禁止保証がGDScriptには存在しない。`get_state()`実装は内部状態をそのまま返さず、必ず`duplicate(true)`したコピーを返す規約とした（[`state-management.md`](../../.claude/rules/state-management.md)参照）。高頻度呼び出し箇所ではコストを踏まえ個別ゲッターへの置き換えも許容する。
- **セーブデータのチェックサムは「破損検出」であり「改ざん検出」ではない**: 秘密鍵を持たない素のSHA-256はローカル保存では改ざん防止にならない（`data`と`checksum`を一緒に書き換えれば通過する）。誤解を招く見出し・文言を修正し、ローカル単体ゲームである以上この制約を受け入れる方針を明記した（[`security.md`](../../.claude/rules/security.md)参照）。
