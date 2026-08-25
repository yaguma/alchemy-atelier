# main-scene-integration 要件定義書

## 概要

Godot 4.7 + GDScript の錬金術デッキ構築RPG「Atelier Alchemy」において、garden（庭）・alchemy（調合）・guild（ギルド納品）・rank（ランク進行・昇格試験）・workshop（工房強化）の5機能はそれぞれ独立したPlanでロジック・UIとも実装済みである。しかし `atelier/scenes/main.tscn` はPhase 1構築時から `[node name="Main" type="Control"]` 1個のみで、スクリプトも子ノードも存在せず、5画面を1本の遊べるループへ繋ぐ配線が一切ない。

本Planは MainScene（`scenes/main.tscn` + 新規 `scenes/main.gd`）にフェーズ統合レイヤーを実装し、ゲームを最初から最後まで実機で通しプレイできる状態にすることを目的とする。具体的には (1) 4画面の常駐と `visible` 切替によるフェーズ制御、(2) 全画面共通の RankHud、(3) 庭⇔調合の共通タブバー、(4) ギルド納品オーバーレイの表示/復帰配線、(5) 昇格試験合否後の分岐制御、を範囲とする。

## 関連文書

- **ユーザーストーリー**: [user-stories.md](user-stories.md)
- **受入基準**: [acceptance-criteria.md](acceptance-criteria.md)
- **設計・タスク**: [plan.md](plan.md)
- **画面遷移設計（確定済み）**: [../../../design/atelier-alchemy-core/ui-design/overview.md](../../../design/atelier-alchemy-core/ui-design/overview.md)
- **アーキテクチャ規約**: [../../../../.claude/rules/architecture.md](../../../../.claude/rules/architecture.md)
- **状態管理規約**: [../../../../.claude/rules/state-management.md](../../../../.claude/rules/state-management.md)

## 用語集

| 用語 | 定義 |
|-----|------|
| **MainScene** | `atelier/scenes/main.tscn` + 新規 `atelier/scenes/main.gd`。4画面（Garden/Alchemy/Workshop/Result）・RankHud・タブバーを常駐させ、`visible` 切替と signal 購読でフェーズ遷移を制御するルートシーン。本Planの唯一の新規責務保持者 |
| **フェーズ（phase）** | `GameState._current_phase`（`StringName`）が表す現在の画面種別。本Planでは `&"garden"` / `&"alchemy"` / `&"workshop"` / `&"result"` の4値を扱う |
| **RankHud** | 全フェーズ共通で常時表示するヘッダー。`ui-design/overview.md` の定義に従い txt-rank-name（ランク名）/ bar-rank-quota（ノルマ残量バー）/ txt-turn-remaining（残ターン）/ txt-gold（所持ゴールド）の4要素を持つ。本Planで新規実装する |
| **タブバー** | MainScene が保持する庭/調合の2ボタン。押下で `GameState.set_phase()` を呼ぶ。GardenScreen / AlchemyScreen 自体は改修しない |
| **ギルド納品オーバーレイ** | `AlchemyScreen` の `.tscn` 内に `%GuildDeliveryScreen` として既に埋め込まれている `GuildDeliveryScreen`。独立フェーズではなく alchemy フェーズ内のオーバーレイ表示として扱う |
| **昇格試験モード** | 独立画面ではなく `AlchemyScreen` が `GameState.get_state()["in_exam"]` を見て自身のUIを出し分ける実装済みの状態。MainScene は独立フェーズとして扱わない |
| **中継signal** | 本Planで `AlchemyScreen` に新規追加する `delivery_confirmed`。内部で `%GuildDeliveryScreen.screen_closed` を購読し外部へ再発行することで、MainScene が他Feature（guild）の `ui/` を直接参照せずに済むようにする |

## 機能要件（EARS記法）

**【信頼性レベル凡例】**:
- 🔵 PRD・設計文書・ヒアリングに基づく確実な要件
- 🟡 妥当な推測による要件
- 🔴 AI推論補完による要件（要確認）

### 普遍要件（SHALL）

- **FR-001**: MainScene は GardenScreen / AlchemyScreen / WorkshopScreen / ResultScreen の4画面を子ノードとして常駐させ、`visible` プロパティの切替のみでフェーズ表示を制御しなければならない 🔵 *[ヒアリング結果3、`.claude/rules/state-management.md`「MainScene常駐＋子Controlのvisible切替」]*
  - 関連: US-001, US-003, AC-001
- **FR-002**: MainScene は RankHud（ランク名・ノルマ残量バー・残ターン・所持ゴールドの4要素）を全フェーズ共通のヘッダーとして常時表示しなければならない 🔵 *[ヒアリング結果2、ui-design/overview.md RankHud定義]*
  - 関連: US-002, AC-002
- **FR-003**: MainScene は庭フェーズと調合フェーズを切り替えるタブバーを自身のノードとして保持し、GardenScreen / AlchemyScreen 側にタブ切替用 signal を追加せずに表示画面を制御しなければならない 🔵 *[ヒアリング結果3]*
  - 関連: US-001, AC-003
- **FR-004**: MainScene は `GameState.get_state()["current_phase"]` を表示フェーズの唯一の正本（Single Source of Truth）とし、表示中の画面と常に一致させなければならない 🟡 *[`.claude/rules/state-management.md`「単一の情報源」原則からの導出]*
  - 関連: US-001, AC-004
- **FR-005**: MainScene は `GameState`（Autoload）へのすべての signal 購読を `_exit_tree()` で `is_connected()` チェック付きで解除しなければならない 🔵 *[`.claude/rules/ui-components.md`「破棄チェックリスト」]*
  - 関連: US-005, AC-005
- **FR-006**: MainScene は自身の `_ready()` において、4画面が実データで動作するために必要なマスターデータのロード（`GameState.load_garden_master_data()` / `load_alchemy_master_data()` / `load_workshop_master_data()` / 本Planで新設する `load_rank_master_data()`）を実行しなければならない 🔵 *[コード調査で発見した未接続を、ユーザー確認の上スコープに含めることを確定（2ラウンド目AskUserQuestion）。呼び出し主体は MainScene に確定。BootScene は `MasterDataLoader.validate_references([])` の呼び出しのみ据え置き、変更しない]*
  - 関連: US-006, AC-006

### イベント駆動要件（WHEN-THEN）

- **FR-101**: タブバーの「庭」ボタンが押された場合、MainScene は `GameState.set_phase(&"garden")` を呼び出さなければならない 🔵 *[ヒアリング結果3、ui-design/overview.md 画面遷移図 `Alchemy --> Garden: タブ切替`]*
  - 関連: US-001, AC-003
- **FR-102**: タブバーの「調合」ボタンが押された場合、MainScene は `GameState.set_phase(&"alchemy")` を呼び出さなければならない 🔵 *[同上 `Garden --> Alchemy: タブ切替`]*
  - 関連: US-001, AC-003
- **FR-103**: `GameState.phase_changed(previous, next)` を受信した場合、MainScene は `next` に対応する1画面のみ `visible = true` とし、他の3画面を `visible = false` にしなければならない 🔵 *[FR-001・FR-004からの帰結、ヒアリング結果3]*
  - 関連: US-001, AC-001, AC-004
- **FR-104**: `GardenScreen.shop_requested` または `AlchemyScreen.shop_requested` を受信した場合、MainScene は `GameState.set_phase(&"workshop")` を呼び WorkshopScreen を表示しなければならない 🔵 *[既存 signal（garden_screen.gd:8, alchemy_screen.gd:10）、ui-design/overview.md `Garden --> Workshop` / `Alchemy --> Workshop`]*
  - 関連: US-003, AC-007
- **FR-105**: `WorkshopScreen.screen_closed` を受信した場合、MainScene は工房を開く直前のフェーズ（記録がない場合は `&"garden"`）へ `set_phase()` で復帰しなければならない 🔵 *[既存 signal（workshop_screen.gd:8,154）、ui-design/overview.md `Workshop --> Garden`]*
  - 関連: US-003, AC-007
- **FR-106**: `AlchemyScreen.delivery_confirmed`（本Planで新規追加する中継signal）を受信した場合、MainScene は `GameState.set_phase(&"garden")` を呼び庭フェーズへ戻さなければならない 🔵 *[ヒアリング結果4、ui-design/overview.md `GuildDelivery --> Garden: 結果確認後ターン継続`]*
  - 関連: US-102, AC-008
- **FR-107**: `GuildDeliveryScreen.screen_closed` が発行された場合、AlchemyScreen はそれを内部で購読し `delivery_confirmed` として再発行しなければならない 🔵 *[ヒアリング結果4。現状 `screen_closed` はどこからも購読されておらず「続ける」ボタンが無反応]*
  - 関連: US-102, AC-008
- **FR-108**: `GameState.exam_started` を受信した場合、MainScene は alchemy フェーズへ切り替えなければならない 🟡 *[既存 signal（game_state.gd:23）。試験は AlchemyScreen 内のUI状態切替で表現されるため（ヒアリング結果の現状調査）、試験開始時は調合画面を前面に出す必要がある]*
  - 関連: US-201, AC-009
- **FR-109**: `GameState.exam_outcome_confirmed(SUCCESS)` を受信した場合、MainScene は `GameState.set_phase(&"workshop")` を呼び WorkshopScreen を表示しなければならない 🔵 *[ヒアリング結果6、ui-design/overview.md `PromotionExam --> Workshop: 試験成功 かつ 現ランク != S`]*
  - 関連: US-202, AC-010
- **FR-110**: `GameState.exam_outcome_confirmed(FAILURE)` を受信した場合、MainScene は `GameState.set_phase(&"garden")` を呼び庭フェーズへ戻さなければならない 🔵 *[ヒアリング結果6、ui-design/overview.md `PromotionExam --> Garden: 試験失敗`]*
  - 関連: US-203, AC-010
- **FR-111**: `GameState.game_cleared` を受信した場合、MainScene は result フェーズへ切り替え ResultScreen を表示しなければならない 🔵 *[ヒアリング結果6、既存 signal（game_state.gd:22）、ui-design/overview.md `PromotionExam --> Result`]*
  - 関連: US-204, AC-011
- **FR-112**: `GameState.game_over(demotion_count)` を受信した場合、MainScene は result フェーズへ切り替え ResultScreen を表示しなければならない 🔵 *[ヒアリング結果6、既存 signal（game_state.gd:19）、ui-design/overview.md `Garden --> Result: 規定回数連続降格`]*
  - 関連: US-205, AC-011
- **FR-113**: `commit_exam_outcome()` が1回の呼び出しで `exam_outcome_confirmed` → （条件付きで）`game_cleared` または `game_over` の順に最大2回 signal を発行した場合、MainScene は FR-109/FR-110 による暫定遷移の後に FR-111/FR-112 による遷移で最終画面を上書きしなければならない 🔵 *[ヒアリング結果6、`game_state_rank_delegate.gd:133-155` の実装（`exam_outcome_confirmed.emit` の後に `game_cleared.emit` / `game_over.emit`）]*
  - 関連: US-204, US-205, AC-012
- **FR-114**: `GameState.gold_changed` / `turn_growth_advanced` / `rank_outcome_confirmed` / `delivered` / `exam_started` / `exam_outcome_confirmed` のいずれかを受信した場合、RankHud は表示中の4要素を `GameState.get_state()` および `GameState.get_current_rank_master()` の最新値で再描画しなければならない 🟡 *[FR-002の帰結。購読対象 signal の網羅範囲は既存 signal 一覧（game_state.gd:3-24）から導出]*
  - 関連: US-002, AC-002
- **FR-115**: 通常ターンの納品が完了した場合、システムは `GameState.commit_rank_outcome()` を呼び出し、ランク判定（昇格試験開始・降格・ゲームオーバー）を確定させなければならない 🔵 *[コード調査で発見した未接続を、ユーザー確認の上スコープに含めることを確定（2ラウンド目AskUserQuestion）。呼び出し主体は AlchemyScreen（既存「ターンを終了する」処理の延長、CON-003の改修許容範囲内）または MainScene（`GameState.delivered`購読）のいずれかとし、具体的な選定はPhase 2設計で行う]*
  - 関連: US-103, AC-013
- **FR-116**: 昇格試験中にターンが進行した場合、システムは `GameState.commit_exam_outcome()` を呼び出し、試験の合否を確定させなければならない 🔵 *[同上。呼び出し主体は AlchemyScreen の既存「ターンを進める」処理（`_on_advance_exam_turn_pressed()`）の延長とする方針が有力（CON-003の改修許容範囲内）。具体的な実装箇所はPhase 2設計で確定する]*
  - 関連: US-201, US-202, AC-013

### 状態駆動要件（WHERE）

- **FR-201**: 昇格試験中（`GameState.get_state()["in_exam"] == true`）である間、MainScene はタブバーの「庭」ボタンを操作不能（`disabled = true`）にしなければならない 🟡 *[ui-design/overview.md の遷移図に試験中の庭への遷移が存在しないことからの導出。試験は一発勝負の特殊局面であるという core-systems.md の設計意図に整合]*
  - 関連: US-201, AC-014
- **FR-202**: result フェーズにある間、MainScene はタブバーを操作不能にしなければならない 🟡 *[ResultScreen が閉じるボタン・次へ進むボタンを意図的に未実装としている（ゲーム終了画面）という現状調査からの導出]*
  - 関連: US-204, US-205, AC-014
- **FR-203**: 表示すべき納品結果が存在する間のみ、GuildDeliveryScreen は `visible = true` でなければならない。それ以外の間は `visible = false` でなければならない 🔵 *[ヒアリング結果5。現状 `alchemy_screen.tscn` の VBoxContainer 内に `visible=false` 指定なしで埋め込まれており常時表示されるバグがある]*
  - 関連: US-101, AC-015

### 任意要件（MAY）

- **FR-301**: MainScene はフェーズ切替時にフェード等のトランジション演出を提供してもよい 🟡 *[ui-design/overview.md がビジュアル面を暫定案としているため任意扱い]*
  - 関連: US-004, AC-016
- **FR-302**: RankHud はノルマ残量バーに数値（現在値/上限値）を併記してもよい 🟡 *[ui-design/overview.md の bar-rank-quota 定義には数値併記の明示規定がない]*
  - 関連: US-002, AC-016

### 禁止要件（MUST NOT）

- **FR-401**: MainScene は `GameState` を経由せずに他Feature の `state/` を直接読み書きしてはならない 🔵 *[`.claude/rules/architecture.md`「他Feature の `state/`・`ui/` を直接参照しない」「データ受け渡しは Application 層（GameState）が仲介する」]*
  - 関連: AC-017
- **FR-402**: MainScene は `GuildDeliveryScreen` のノード・型を直接参照してはならない。ギルド納品の完了通知は `AlchemyScreen.delivery_confirmed` のみを経由しなければならない 🔵 *[ヒアリング結果4]*
  - 関連: AC-008, AC-017
- **FR-403**: ResultScreen 表示後、MainScene は garden / alchemy / workshop フェーズへ自動復帰してはならない 🔵 *[ヒアリング結果6、ResultScreen が終端画面である現状実装]*
  - 関連: US-204, US-205, AC-011
- **FR-404**: 本Plan は `GameState` に新規 signal を追加してはならない 🔵 *[ヒアリング結果6「GameState 側への新規 signal 追加は行わない」]*
  - 関連: AC-017
- **FR-405**: 本Plan は恒久投資購入時の確認ダイアログを実装してはならない 🔵 *[ヒアリング結果7（Won't Have）]*
  - 関連: US-401, AC-017
- **FR-406**: 本Plan は `AlchemyScreen` → `GuildDeliveryScreen` の既存直接埋め込み構造を是正（別Featureへの分離）してはならない 🔵 *[ヒアリング結果の現状調査「既存実装として受け入れる（本Planで是正しない、スコープ外）」]*
  - 関連: AC-017

## 非機能要件

### パフォーマンス

- **NFR-001**: フェーズ切替は常駐ノードの `visible` 切替のみで行い、シーンの再インスタンス化・`change_scene_to_file()` を伴ってはならない 🔵 *[`.claude/rules/state-management.md`、`.claude/rules/performance.md`「可視性管理」]*
- **NFR-002**: MainScene は `_process()` を定義してはならない（フェーズ制御は signal 駆動で完結する） 🟡 *[`.claude/rules/performance.md`「必要な場合のみ `_process` を定義」]*

### セキュリティ

- **NFR-101**: 本Plan に固有のセキュリティ要件はない。オフライン単体デスクトップゲームであり、ネットワーク通信・外部入力・機密情報を扱わない 🔵 *[ヒアリング結果「非機能・テストに関する方針」、`.claude/rules/security.md`]*

### ユーザビリティ

- **NFR-201**: 現在どのフェーズを表示しているかがタブバー上で視覚的に判別できなければならない（選択中タブの強調表示） 🟡 *[一般的なタブUIのベストプラクティスからの導出。ui-design/overview.md に明示規定なし]*
- **NFR-202**: RankHud・タブバーの色・角丸・フォントサイズは `UiTheme` 定数経由で指定しなければならない（ハードコード禁止）。ビジュアルデザインの完成度自体は暫定でよい 🔵 *[ヒアリング結果2、`.claude/rules/design-guide.md`「色のハードコード禁止」]*

### テスト容易性

- **NFR-301**: 5画面を横断する結合シナリオを、`atelier/tests/integration/` 配下に GdUnit4 の `scene_runner("res://scenes/main.tscn")` ベースの統合テストとして実装しなければならない 🔵 *[ヒアリング結果「非機能・テストに関する方針」、`.claude/rules/testing.md`「E2E相当のテスト」]*
  - 関連: US-301, AC-018
- **NFR-302**: 昇格試験合否後の分岐（FR-113）の signal 発行順序は `monitor_signals(GameState, false)` を用いて検証しなければならない 🔵 *[`.claude/rules/testing.md`「Autoload を監視する場合は必ず `monitor_signals(obj, false)` と明示する」]*
  - 関連: US-301, AC-012, AC-018

## 制約

- **CON-001**: 実装言語は GDScript（静的型付け徹底、`Variant` の無条件使用禁止）、エンジンは Godot 4.7 🔵 *[`atelier/project.godot`、`.claude/rules/coding-style.md`]*
- **CON-002**: `scenes/boot.tscn` → `scenes/main.tscn` の遷移ロジック（`boot.gd:16`）は完成済みであり変更しない 🔵 *[ヒアリング結果の現状調査]*
- **CON-003**: 既存の5画面のうち改修が許されるのは `AlchemyScreen`（`delivery_confirmed` 中継signal の追加、および FR-203 の可視制御）のみ。GardenScreen / WorkshopScreen / ResultScreen は無改修とする 🔵 *[ヒアリング結果3・4・5・6]*
- **CON-004**: 1ファイル300行を超えたら分割を検討する（`main.gd` が肥大化する場合は RankHud・タブバーを独立コンポーネント化する） 🟡 *[`.claude/rules/coding-style.md`「1ファイルの上限」]*
- **CON-005**: `atelier/data/ranks/` および `atelier/data/daily_orders/` は現時点で空ディレクトリであり、ランク進行・日次依頼の実データ（`.tres`）が存在しない。また `GameState` には `load_rank_master_data()` に相当する本番用ローダーが存在せず、`_set_rank_masters_for_test()`（テスト専用）しかない。この状態では `_get_current_rank_master_or_fallback()` がノルマ0・制限ターン0のフォールバックを返すため、実機での通しプレイは成立しない。本Planでは、`load_garden_master_data()` 等と同型の `load_rank_master_data()`（および必要なら `load_daily_order_master_data()`）を新規実装し、G〜Sランク分の `RankMaster` を**最小限の仮値**（バランス未確定の暫定数値）で `atelier/data/ranks/*.tres` に作成することでスコープに含める。正式なバランス数値の確定は別Plan（`balance-design.md` の🟡🔴項目）に委ねる 🔵 *[コード調査で発見した欠落を、ユーザー確認の上スコープに含めることを確定（2ラウンド目AskUserQuestion「最小限の介しデータをこのPlanで用意」）]*
- **CON-006**: タイトル画面・設定画面・セーブ/ロード機能・正式ビジュアルデザインガイドは本Planのスコープ外とする 🔵 *[ヒアリング結果8、`CLAUDE.md`]*
- **CON-007**: テスト実行は `cd atelier && ./addons/gdUnit4/runtest.sh -a res://tests/` で行う（`--path` 相当のオプションがないため `atelier/` への `cd` が必須） 🔵 *[`.claude/rules/bash-commands.md`]*

## 信頼性レベルサマリー

> 🔵 2026-08-26追記: 初版で🔴（赤信号）だった FR-006 / FR-115 / FR-116 / CON-005 は、いずれもユーザーへのAskUserQuestion（2ラウンド目）で「本Planのスコープに含める」ことが確定したため🔵へ更新した。呼び出し主体・実装箇所の詳細（AlchemyScreen経由かMainScene経由か等）はPhase 2設計フェーズで確定する。

| 分類 | 🔵 青信号 | 🟡 黄信号 | 🔴 赤信号 | 合計 |
|------|----------|----------|----------|------|
| 機能要件（FR） | 21 | 8 | 0 | 29 |
| 非機能要件（NFR） | 4 | 3 | 0 | 7 |
| 制約（CON） | 6 | 1 | 0 | 7 |
| **合計** | **31** | **12** | **0** | **43** |

- 🔵 青信号: 31件（72.1%）
- 🟡 黄信号: 12件（27.9%）
- 🔴 赤信号: 0件（要確認事項なし。Phase 2へ進行可能）
