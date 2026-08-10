# atelier-alchemy-core 要件定義書

> 🔴 2026-08-10改訂: Godot 4.7のAsset Store移行期にGUTが導入できなかったため、テストフレームワークをGdUnit4に切り替えた（実装・動作確認済み）。FR-010・FR-107・CON-002・用語集のGUT言及はヒアリング当時の記録として原文を残しつつ、実際の実施結果を注記で追記した。

## 概要

「Atelier」プロジェクト（Godot 4.x + GDScript製、庭→調合→ギルド納品のデッキ構築RPG）の実装における **Phase 1: 基盤構築（プロジェクトスキャフォールディング）** の要件を定義する。

対象範囲は、`atelier/` プロジェクトの新規作成、`docs/design/atelier-alchemy-core/architecture.md`「ディレクトリ構造（案）」に基づくディレクトリスキャフォールディング、`GameState`/`RngService` Autoloadの最小骨組み、日本語（CJK）フォント対応、`BootScene`→`MainScene`の起動フロー、GUT/gdlint/gdformatによる品質チェック基盤の整備である。

庭・調合・ギルド納品・工房強化・ランク進行の各Featureの実際のゲームロジック/UI/マスターデータ実装は本Planのスコープ外であり、後日それぞれ別のPlan名でdev-planする。

## 関連文書

- **ユーザーストーリー**: [user-stories.md](user-stories.md)
- **受入基準**: [acceptance-criteria.md](acceptance-criteria.md)
- **設計・タスク**: [plan.md](plan.md)
- **技術アーキテクチャ設計**: [../../../design/atelier-alchemy-core/architecture.md](../../../design/atelier-alchemy-core/architecture.md)

## 用語集

| 用語 | 定義 |
|-----|------|
| Autoload | Godotのシングルトンノード。プロジェクト全体からグローバルに参照できる（本PlanではGameState, RngService） |
| GameState | ゲーム状態を一元管理するAutoload（StateManager相当） |
| RngService | 乱数を一元管理するAutoload。Domain層の純粋関数へは払い出した値を引数で渡す |
| Functional Core | 副作用のない`static func`群。`features/{feature}/logic/*.gd`に配置する |
| Imperative Shell | 副作用を持つ層。Autoload・UIシーンが該当する |
| GUT | Godot Unit Test。GodotのユニットテストアドオンでAssetLib経由で導入する（🔴2026-08-10実施結果: AssetLib移行期の不具合で導入不可だったため、実際はGdUnit4を採用した） |
| gdtoolkit | `gdlint`（静的解析）・`gdformat`（フォーマッタ）を提供するツール群 |
| BootScene | 起動時に日本語フォント適用・マスターデータ検証配線を行い、MainSceneへ遷移する最初のシーン |
| MainScene | 本Planではプレースホルダ（空のControlのみ）として作成するルートシーン |
| MasterDataLoader | マスターデータの相互参照検証を担う想定のクラス。本Planではシグネチャ・スタブのみ作成 |
| ディープコピー | `Dictionary.duplicate(true)`等により、内部の`Array`/`Dictionary`を含めて値を複製すること |

## 機能要件（EARS記法）

**【信頼性レベル凡例】**:
- 🔵 PRD・設計文書・ヒアリングに基づく確実な要件
- 🟡 妥当な推測による要件
- 🔴 AI推論補完による要件（要確認）

### 普遍要件（SHALL）

- **FR-001**: システムは `atelier/` に、`architecture.md`「ディレクトリ構造（案）」に記載された全ディレクトリツリー（`autoload/`, `features/{garden,alchemy,guild,workshop,rank}/{logic,state,resources,ui}/`, `shared/{constants,theme,entities}/`, `data/{materials,recipes,ranks,upgrades,daily_orders}/`, `scenes/`, `tests/unit/features/{garden,alchemy,guild,workshop,rank}/`, `tests/integration/`）を持たなければならない 🔵 *[ヒアリング: スコープ#1]*
  - 関連: US-001, AC-001
- **FR-002**: システムは、中身が空のディレクトリを`.gitkeep`等でgit追跡しなければならない 🔵 *[ヒアリング: スコープ#1]*
  - 関連: US-001, AC-001
- **FR-003**: システムは `project.godot` にGodot 4.7（安定版）を対象バージョンとして固定しなければならない 🔵 *[ヒアリング: 技術的決定事項]*
  - 関連: US-001, AC-002
- **FR-004**: `GameState`は最小フィールドとして`current_phase: StringName`, `gold: int`, `current_turn: int`を持たなければならない 🔵 *[ヒアリング: スコープ#2]*
  - 関連: US-002, AC-003
- **FR-005**: `GameState`は`phase_changed` signalを持たなければならない 🔵 *[ヒアリング: スコープ#2]*
  - 関連: US-002, AC-003
- **FR-006**: `RngService`は`RandomNumberGenerator`をラップし、`set_seed(seed: int)`, `randf() -> float`等の最小APIを持たなければならない 🔵 *[ヒアリング: スコープ#3]*
  - 関連: US-003, AC-006
- **FR-007**: `UiTheme`（`shared/theme/theme.gd`）はCJK対応フォント（Noto Sans JP等、ライセンス確認済みのもの）への定数を定義しなければならない 🔵 *[ヒアリング: スコープ#4]*
  - 関連: US-004, AC-007
- **FR-008**: プロジェクト共通の`Theme`リソースは、`UiTheme`のフォント定数を`default_font`に適用しなければならない 🔵 *[ヒアリング: スコープ#4]*
  - 関連: US-004, AC-007
- **FR-009**: システムは`MasterDataLoader.validate_references()`という関数シグネチャ・クラスを提供しなければならない（中身は未実装のスタブでよい） 🔵 *[ヒアリング: スコープ#5]*
  - 関連: US-006, AC-009
- **FR-010**: システムはGUTアドオンのAssetLib経由インストール手順書を提示しなければならない 🔵 *[ヒアリング: スコープ#6]*（🔴2026-08-10実施結果: GUTがAssetLib経由で導入不可だったため、GdUnit4をGitHubから導入する手順に切り替えて実施した）
  - 関連: US-007, AC-014

### イベント駆動要件（WHEN-THEN）

- **FR-101**: `BootScene`が起動した場合、システムは`UiTheme`のフォントを適用しなければならない 🔵 *[ヒアリング: スコープ#5]*
  - 関連: US-005, AC-008
- **FR-102**: `BootScene`のフォント適用（および`MasterDataLoader.validate_references()`呼び出しの配線）が完了した場合、システムは空の`scenes/main.tscn`（プレースホルダのMainScene）へ遷移しなければならない 🔵 *[ヒアリング: スコープ#5]*
  - 関連: US-005, AC-008
- **FR-103**: 呼び出し元が`GameState.get_state()`を呼んだ場合、システムは内部状態のディープコピー（`_state.duplicate(true)`相当）を返さなければならない 🔵 *[ヒアリング: スコープ#2, エッジケース・DoD]*
  - 関連: US-002, AC-004
- **FR-104**: 呼び出し元がデバッグビルド下で`GameState.reset_for_test()`を呼んだ場合、システムは内部状態を初期値に戻さなければならない 🔵 *[ヒアリング: スコープ#2]*
  - 関連: US-008, AC-005
- **FR-105**: 呼び出し元が`RngService.set_seed(seed)`で同一のseedを設定した場合、システムは同一の乱数列を再現しなければならない 🔵 *[ヒアリング: スコープ#8]*
  - 関連: US-003, AC-006
- **FR-106**: 開発者がクリーンチェックアウト直後の`atelier/`に対し`godot --headless --path atelier --import`を実行した場合、システムは正常終了しなければならない 🔵 *[ヒアリング: エッジケース・完了条件（DoD）]*
  - 関連: US-010, AC-010
- **FR-107**: 開発者が`godot --headless --path atelier -s addons/gut/gut_cmdln.gd -gdir=res://tests/ -ginclude_subdirs -gexit`を実行した場合、システムは作成済みのGameState/RngServiceのGUTテストを実行しすべてパスさせなければならない 🔵 *[ヒアリング: スコープ#8, エッジケース・DoD]*（🔴2026-08-10実施結果: 上記コマンドはGUT前提であり`addons/gut/`が存在しないため実行不能。実際の受け入れコマンドは`cd atelier && GODOT_BIN="/c/Godot/godot.exe" ./addons/gdUnit4/runtest.sh -a res://tests/`〈GdUnit4〉に置き換え、9件全テストパスを確認済み）
  - 関連: US-008, AC-011
- **FR-108**: 開発者が`gdlint atelier/features/ atelier/shared/ atelier/autoload/`を実行した場合、システムはエラーなく完了しなければならない 🔵 *[ヒアリング: スコープ#7, エッジケース・DoD]*
  - 関連: US-009, AC-012
- **FR-109**: 開発者が`gdformat --check atelier/features/ atelier/shared/ atelier/autoload/`を実行した場合、システムはフォーマット崩れなく完了しなければならない 🔵 *[ヒアリング: スコープ#7, エッジケース・DoD]*
  - 関連: US-009, AC-013

### 状態駆動要件（WHERE）

- **FR-201**: リリースビルド（`OS.is_debug_build() == false`）の状態にある間、システムは`reset_for_test()`の実行を`assert()`および`push_error()`ガードにより本番コードパスから防止しなければならない 🟡 *[state-management.md「テスト用API」の踏襲、ヒアリングでの直接指定なし]*
  - 関連: US-012, AC-005

### 任意要件（MAY）

- **FR-301**: システムは`BootScene`上に日本語の仮ラベルを表示し、フォント動作の目視確認手段を提供してもよい 🔵 *[ヒアリング: 優先順位（MoSCoW）Could]*
  - 関連: US-011, AC-015

### 禁止要件（MUST NOT）

- **FR-401**: 本Planは庭/調合/ギルド納品/工房強化/ランク進行の各Featureの`logic/*.gd`実装（`quality_calculator.gd`等）を行ってはならない 🔵 *[ヒアリング: スコープ「含まれないもの」]*
  - 関連: US-013, AC-016
- **FR-402**: 本Planは各種マスターデータ（`.tres`）の実データを作成してはならない 🔵 *[ヒアリング: スコープ「含まれないもの」]*
  - 関連: US-013, AC-016
- **FR-403**: 本Planはガーデン画面等のUI画面（`garden_screen.tscn`等）を実装してはならない 🔵 *[ヒアリング: スコープ「含まれないもの」]*
  - 関連: US-013, AC-016
- **FR-404**: 本Planはセーブ/ロード機能を実装してはならない 🔵 *[ヒアリング: スコープ「含まれないもの」、CLAUDE.md]*
  - 関連: US-013, AC-016
- **FR-405**: 本Planはエクスポートビルド設定・配布用プリセットを確定してはならない 🔵 *[ヒアリング: スコープ「含まれないもの」]*
  - 関連: US-013, AC-016
- **FR-406**: `GameState`のフィールドは呼び出し元から直接書き換えてはならない（専用メソッド経由でのみ変更する） 🔵 *[state-management.md「禁止事項」]*
  - 関連: US-002, AC-004

## 非機能要件

### パフォーマンス

- **NFR-001**: 起動時間（`BootScene`→`MainScene`遷移まで）について、本Planでは具体的な数値目標を設定しない。Phase1はスキャフォールディング中心でコンテンツ量が少なく計測の意味が薄いため、コンテンツが増えた段階で計測・目標値確定を行う 🔵 *[ユーザー確認済み: 目標値なしで進める（推奨案採用）]*

### セキュリティ

- **NFR-101**: 本ゲームはオフライン単体デスクトップアプリ（ネットワーク通信なし）のためセキュリティ要件の該当性は低い。`.claude/rules/security.md`の指針（将来のセーブ/ロード機能追加時のみ適用）を踏襲し、本Planでは追加のセキュリティ実装を必須としない 🔵 *[ヒアリング: 非機能要件「セキュリティ要件」]*

### ユーザビリティ

- **NFR-201**: Godotエディタで`boot.tscn`を実行したとき、日本語テキスト（BootScene上の仮ラベル等）は矩形/豆腐文字にならず正しく表示されなければならない 🔵 *[ヒアリング: エッジケース・完了条件（DoD）]*

### 保守性

- **NFR-401**: 作成するコード（`GameState`, `RngService`, `UiTheme`, `MasterDataLoader`等）は`.claude/rules/architecture.md`のFeature-Based Architecture / Functional Core, Imperative Shell分離原則に従わなければならない 🟡 *[プロジェクト共通ルールからの適用、本Plan固有のヒアリングでの明示なし]*

### 移植性

- **NFR-301**: 対象OSはWindowsのみとする。他OS（macOS/Linux）での動作検証は本PlanのDoDに含めず、明示的にスコープ外とする。将来クロスプラットフォーム対応が必要になった際に別途検証する 🔵 *[ユーザー確認済み: Windowsのみを対象と明記（推奨案採用）]*

## 制約

- **CON-001**: Godotバージョンは4.7（安定版）を`project.godot`に固定する 🔵 *[ヒアリング: 技術的決定事項]*
- **CON-002**: GUT導入はGodotエディタのAssetLib経由のGUI手動操作を前提とし、CLIでの完全自動化は行わない。Claudeが自動化できない手動ステップがあることをタスクに明記する 🔵 *[ヒアリング: 技術的決定事項、スコープ#6]*（🔴2026-08-10実施結果: GUTがAssetLib経由で導入不可だったため、実際はGdUnit4をGitHubからclone・配置する手順で導入した）
- **CON-003**: `BootScene`のマスターデータ検証は「検証ロジックの骨組みまで作る」（関数シグネチャ定義、中身は未実装のTODOまたは常にtrueを返すスタブ）に限定する 🔵 *[ヒアリング: 技術的決定事項、スコープ#5]*
- **CON-004**: `GameState`/`RngService`には個別Feature用のフィールド・メソッド（在庫操作等）を実装しない。実装範囲は最小骨組みに限定する 🔵 *[ヒアリング: スコープ#2, #3]*
- **CON-005**: 各ファイルは`.claude/rules/coding-style.md`の1ファイル300行上限を目安とする 🟡 *[プロジェクト共通ルールからの適用]*

## 信頼性レベルサマリー

- 🔵 青信号: 34件 (92%)
- 🟡 黄信号: 3件 (8%)
- 🔴 赤信号: 0件（NFR-001, NFR-301はユーザー確認により🔵へ更新済み）
