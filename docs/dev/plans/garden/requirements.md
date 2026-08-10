# garden 要件定義書

## 概要

「Atelier」（Godot 4.x + GDScript）の Phase 2 最初の機能実装として、庭（garden）機能を実装する。庭はゲームフロー「庭（仕込み・戦略層）→ 調合（核心）→ ギルド納品（自動決算）」の起点であり、プレイヤーが手持ちの種を植え、ターン経過で生育させ、収穫して素材（`MaterialInstance`）を得る一連のサイクルを提供する。

本要件は `docs/design/atelier-alchemy-core/core-systems.md`「GardenSystem詳細設計」（L22-96）・`docs/design/atelier-alchemy-core/data-schema.md`・`docs/design/atelier-alchemy-core/ui-design/screens/garden.md` に既に確定的に定義された契約をそのまま踏襲し、EARS形式に翻訳したものである。矛盾がある場合は既存設計文書を正とする。

### スコープ境界（ユーザーヒアリングで確定済み）

**含む**:
- `features/garden/logic/`（`Planting`, `Harvest`, `TraitRoll`）
- `features/garden/state/`（`GardenState`, `PlantState`）
- `features/garden/resources/`（`SeedMaster`, `MaterialMaster`）
- `shared/entities/material_instance.gd`（`MaterialInstance`、複数Feature共有のため）
- `autoload/game_state.gd` への統合メソッド（`plant_seed`, `harvest`, `advance_turn_growth`相当）
- `features/garden/ui/`（`GardenScreen` 等、単体テスト可能な画面。`MainScene`非組み込み）

**含まない**（別task・別planの対象）:
- `MainScene`へのタブ切替・`visible`制御組み込み
- ショップでの種の指名買い（`seed_name_purchase`）の実購入ロジック（UI導線ボタンのプレースホルダーのみ許可）
- 昇格試験中（`exam_state.in_exam`）のガーデン遷移禁止制御（RankSystem側が別plan未実装のため）

## 関連文書

- **ユーザーストーリー**: [user-stories.md](user-stories.md)
- **受入基準**: [acceptance-criteria.md](acceptance-criteria.md)
- **設計・タスク**: plan.md（未作成、後続フェーズで生成）
- **既存設計資産**: [`core-systems.md`](../../../design/atelier-alchemy-core/core-systems.md) GardenSystem節 / [`data-schema.md`](../../../design/atelier-alchemy-core/data-schema.md) / [`ui-design/screens/garden.md`](../../../design/atelier-alchemy-core/ui-design/screens/garden.md)

## 用語集

| 用語 | 定義 |
|-----|------|
| 庭（Garden） | 種を植え生育・収穫を行う仕込み層の機能。`features/garden/` |
| 種（Seed） | 庭に植えるマスターデータ。`SeedMaster`。収穫すると`produces_material_id`の素材になる |
| 素材（Material） | 収穫または購入で得られるアイテム。ランタイムでは`MaterialInstance`、マスターは`MaterialMaster` |
| スロット（Slot） | 庭に種を植えられる区画。`GardenState.plants`の1要素（`PlantState`）に対応。上限は`player.permanent_upgrades.garden_slot_count` |
| 生育（Growth） | ターン経過で`PlantState.grown_turns`が増加すること。`Harvest.advance_growth`が担う |
| 成熟（Maturity） | `grown_turns >= SeedMaster.maturity_turns`になった状態。`Harvest.is_matured`で判定 |
| 収穫（Harvest） | 成熟したスロットから`MaterialInstance`を得る操作。`Harvest.harvest`が担う |
| 枯死（Withering） | 成熟後`death_grace_turns`を超えて未収穫のまま全損すること。`Harvest.is_dead`/`Harvest.resolve_withering`が担う |
| 品質（Quality） | `MaterialInstance.quality_score`（1〜5、S=5が上限） |
| 特性（Trait） | `MaterialInstance.trait_tags`。収穫時に`TraitRoll.roll_trait`が`SeedMaster.trait_pool`から一様乱数で選択する |
| `GameState` | Application層Autoload。庭関連の統合メソッド（`plant_seed`, `harvest`, `advance_turn_growth`）を持つ |
| `RngService` | 乱数払い出しAutoload。Domain層（`logic/`）は直接乱数を生成せず引数で受け取る |
| `seed_inventory` | 未収穫の「手持ちの種」を`{seed_id, count}`で管理する`GameState`内配列 |
| `inventory` | 収穫済み・未使用の`MaterialInstance`一覧。上限なし |
| 恒久投資（Permanent Upgrade） | `player.permanent_upgrades`配下の、降格でもリセットされない強化（例: `garden_slot_count`） |
| 昇格試験（Promotion Exam） | `exam_state.in_exam`で管理される特殊局面。本plan外 |
| 日替わり指定調合物（Daily Order） | `daily_order`状態。本plan外だがUI上にプレースホルダー導線を置く |

## 機能要件（EARS記法）

**【信頼性レベル凡例】**:
- 🔵 PRD・設計文書・ヒアリングに基づく確実な要件
- 🟡 妥当な推測による要件
- 🔴 AI推論補完による要件（要確認）

### 普遍要件（SHALL）

- **FR-001**: システムは庭の生育状態を`GardenState.plants: Array[PlantState]`として管理しなければならない 🔵 *[data-schema.md L30-39]*
  - 関連: US-001, AC-001
- **FR-002**: システムは各庭スロットの状態を`PlantState`（`slot_index: int, seed_id: String, grown_turns: int, is_matured: bool`）として保持しなければならない 🔵 *[data-schema.md L30-39]*
  - 関連: US-002, AC-010
- **FR-003**: システムは`Planting`, `Harvest`, `TraitRoll`を`features/garden/logic/`配下に副作用を持たない`static func`として実装しなければならない 🔵 *[architecture.md「レイヤー間依存ルール」/ tdd-implementation.md]*
  - 関連: US-001, US-004, AC-001, AC-005
- **FR-004**: システムは収穫成功時に`shared/entities/material_instance.gd`の`MaterialInstance`（`instance_id, material_id, quality_score, trait_tags`）を生成しなければならない 🔵 *[ヒアリング結果/ data-schema.md L46-53]*
  - 関連: US-004, AC-005
- **FR-005**: システムは庭関連の数値（`GARDEN_SLOT_COUNT`, `DEATH_GRACE_TURNS_DEFAULT`, `QUALITY_UP_CHANCE`等）を`shared/constants/game_balance.gd`の`GameBalance`に定数として定義し、コード中にマジックナンバーを直書きしてはならない 🔵 *[coding-style.md「定数管理」]*
  - 関連: US-001, US-004, AC-001, AC-006
- **FR-006**: システムは庭スロット数の実行時権威を`player.permanent_upgrades.garden_slot_count`とし、`GameBalance.GARDEN_SLOT_COUNT`は当該フィールドのゲーム開始時初期値としてのみ使用しなければならない 🔵 *[core-systems.md L63「実装レディネス監査#5対応」/ data-schema.md L81]*
  - 関連: US-001, AC-002

### イベント駆動要件（WHEN-THEN）

- **FR-101**: プレイヤーが手持ちの種の植え付け操作を行った場合、システムは`GameState.plant_seed(seed_id)`を呼び出し、(1)`seed_inventory`の対象`count`確認 (2)`Planting.plant`実行 (3)両方成功時のみ`count`を1減算、の順で処理しなければならない 🔵 *[core-systems.md L86-94]*
  - 関連: US-001, AC-001
- **FR-102**: 空きスロットがある状態で`Planting.plant`が実行された場合、システムは新しい`PlantState`を`GardenState.plants`に追加しなければならない 🔵 *[core-systems.md L34, L63]*
  - 関連: US-001, AC-001
- **FR-103**: ターン終了操作（庭に関する生育進行の範囲）が行われた場合、システムは`GameState.advance_turn_growth()`相当の処理として、全生育中スロットに`Harvest.advance_growth`を適用した直後に必ず`Harvest.resolve_withering`を呼び出さなければならない 🔵 *[core-systems.md L65「PRレビューCritical#11対応」/ ヒアリング結果「ターン終了時の一括処理順序」]*
  - 関連: US-003, US-006, AC-004, AC-008
- **FR-104**: プレイヤーが収穫可能なスロットへ収穫操作を行った場合、システムは`GameState.harvest(slot_index)`を呼び出し、`RngService`から品質用・特性用の乱数を個別に払い出して`Harvest.harvest(plant_state, rng_roll_quality, rng_roll_trait)`に渡さなければならない 🔵 *[core-systems.md L68, L78]*
  - 関連: US-004, AC-005
- **FR-105**: 収穫が成功した場合、システムは生成された`MaterialInstance`を`inventory`に追加し、該当スロットを`GardenState.plants`から除去して空きに戻さなければならない 🔵 *[data-schema.md L46-53]*
  - 関連: US-004, AC-005
- **FR-106**: 成熟直後（待機ターン0）に収穫が行われた場合、システムは品質を`SeedMaster.base_quality`で確定しなければならない 🔵 *[core-systems.md L75]*
  - 関連: US-004, AC-005
- **FR-107**: 成熟後さらに待機してから収穫が行われた場合、システムは待機1ターンごとに`GameBalance.QUALITY_UP_CHANCE`の確率で品質を1段階上昇させ、上限S（quality_score=5）でクランプしなければならない 🔵 *[core-systems.md L76 / ヒアリング結果「バランス数値の扱い」でユーザーが仮値0.3の採用を確認済み。数値自体の妥当性は🟡TBDとしてコードコメントに明記する]*
  - 関連: US-005, AC-006
- **FR-108**: `Harvest.is_dead`が真のスロットに対して収穫操作が行われた場合、システムは`Harvest.harvest`が失敗を表す`Result`を返し、`GardenState`を変更してはならない 🔵 *[core-systems.md L68]*
  - 関連: US-004, AC-007
- **FR-109**: 庭スロットが満杯（`Planting.can_plant`が偽）の状態で植え付け操作が行われた場合、システムは`Planting.plant`が失敗を表す`Result`を返し、`GardenState`を変更してはならない 🔵 *[core-systems.md L34, L63 / ヒアリング結果「エッジケース」]*
  - 関連: US-001, AC-002
- **FR-110**: `seed_inventory`内の対象`seed_id`の`count`が0（または未所持）の状態で植え付け操作が行われた場合、システムは`Planting.plant`を呼び出さずに`GameState.plant_seed`が失敗を返さなければならない 🔵 *[core-systems.md L90]*
  - 関連: US-001, AC-003
- **FR-111**: 成熟後`SeedMaster.death_grace_turns`を超えて未収穫のスロットが検出された場合、システムはターン終了処理内の`Harvest.resolve_withering`により該当スロットを自動的に`GardenState.plants`から除去しスロットを解放しなければならない（プレイヤーの収穫操作は不要） 🔵 *[ヒアリング結果「エッジケース：枯死」/ ui-design/screens/garden.md L84]*
  - 関連: US-006, AC-008

### 状態駆動要件（WHERE）

- **FR-201**: 庭スロットが空きの間、システムは`GardenScreen`上で当該スロットを「空き」状態として表示しなければならない 🔵 *[ui-design/screens/garden.md L40]*
  - 関連: US-002, AC-010
- **FR-202**: 庭スロットが生育中（`is_matured == false`）の間、システムは当該スロットを「生育中」状態として表示しなければならない 🔵 *[ui-design/screens/garden.md L40, L54-56]*
  - 関連: US-002, AC-010
- **FR-203**: 庭スロットが収穫可能（`is_matured == true` かつ `is_dead == false`）の間、システムは当該スロットを「収穫可能」状態として表示し収穫ボタンを有効化しなければならない 🔵 *[ui-design/screens/garden.md L40, L58-60]*
  - 関連: US-002, US-004, AC-010
- **FR-204**: 庭スロットが枯死猶予ターンの残り僅少（具体的な閾値は🟡TBD、実装時に妥当な値を仮決めしてよい）の間、システムは当該スロットを「枯死警告」状態として色・アイコン・テキストの併記で強く警告表示しなければならない 🟡 *[ui-design/screens/garden.md L40, L62-64「閾値は🟡TBD」]*
  - 関連: US-002, US-006, AC-010
- **FR-205**: プレイヤーが降格した状態にある間も、システムは庭の生育状況（`garden_state.plants`）・`inventory`・`seed_inventory`を維持し、初期化してはならない 🔵 *[data-schema.md L86-88「リセットされない（降格時も維持）」/ ヒアリング結果]*
  - 関連: US-008, AC-009

### 任意要件（MAY）

- **FR-301**: システムは`GardenScreen`にショップ画面への遷移導線ボタン（`btn-shop`）を配置してもよい。ただし本plan内では購入処理を実装せず、押下時のシグナル発行のみとする 🔵 *[ヒアリング結果「スコープ境界」/ ui-design/screens/garden.md L45]*
  - 関連: US-007, AC-012
- **FR-302**: システムは収穫可能スロットに対し「待つ」ことを明示する導線（`btn-wait`、実質何もしない操作）を提供してもよい 🟡 *[ui-design/screens/garden.md L43]*
  - 関連: US-005, AC-006
- **FR-303**: システムは枯死発生時にトースト等の通知を表示してもよい（文言は🟡仮でよい） 🟡 *[ui-design/screens/garden.md L84]*
  - 関連: US-006, AC-008

### 禁止要件（MUST NOT）

- **FR-401**: `features/garden/logic/`配下の関数は副作用（状態変更・I/O・乱数の自己生成）を持ってはならない 🔵 *[architecture.md「Functional Coreに置くもの」/ tdd-implementation.md]*
  - 関連: AC-013
- **FR-402**: `Harvest.harvest`・`TraitRoll.roll_trait`は乱数を自己生成してはならず、`RngService`が払い出した値を引数（`rng_roll_quality`, `rng_roll_trait`, `rng_value`）として受け取らなければならない 🔵 *[core-systems.md L78, L82-84]*
  - 関連: AC-013
- **FR-403**: `GameState.get_state()`は`garden_state`・`seed_inventory`・`inventory`を含む戻り値について、呼び出し元が内部状態を直接改変できる参照をそのまま返してはならない（`duplicate(true)`によるディープコピー必須） 🔵 *[state-management.md「`get_state()`戻り値の防御的コピー必須」]*
  - 関連: AC-014
- **FR-404**: 本plan内の実装は`MainScene`へのタブ切替・`visible`制御組み込みを行ってはならない（別task・別planの対象） 🔵 *[ヒアリング結果「スコープ境界」]*
  - 関連: CON-004
- **FR-405**: 本plan内の実装はショップでの種の指名買い（`seed_name_purchase`）の実購入ロジックを実装してはならない（プレースホルダーボタンのみ許可） 🔵 *[ヒアリング結果「スコープ境界」]*
  - 関連: US-007, AC-012
- **FR-406**: `GardenScreen`側のロジックは昇格試験状態（`exam_state.in_exam`）を判定条件として直接参照してはならない（RankSystem側が別plan未実装のため、参照しなくても成立する設計にする） 🔵 *[ヒアリング結果「スコープ境界」]*
  - 関連: CON-004

## 非機能要件

### パフォーマンス

- **NFR-001**: 庭スロット一覧・手持ち種一覧のUI更新は`_process()`を用いず、`GameState`のsignal駆動（イベント駆動）で行わなければならない 🟡 *[performance.md「`_process()`に書くべきでない処理」]*

### セキュリティ

- **NFR-101**: `plant_seed`/`harvest`が受け取る`seed_id`/`slot_index`は、`MasterDataLoader`が提供する実在のマスターID・現在の`GardenState`に存在するスロットのみを正当な入力として扱い、不正な値には失敗の`Result`を返さなければならない 🟡 *[security.md「入力検証」の一般原則をgarden機能に適用]*

### ユーザビリティ

- **NFR-201**: 庭スロットの4状態（空き/生育中/収穫可能/枯死警告）は色だけでなくアイコン・テキストも併記しなければならない 🔵 *[design-guide.md/ui-design/screens/garden.md L92「色覚多様性対応」]*
- **NFR-202**: 植え付け失敗（スロット満杯・種在庫切れ）はトースト等でプレイヤーにフィードバックしなければならない 🟡 *[ui-design/screens/garden.md L68「エラー状態」]*

### 保守性・アーキテクチャ整合性

- **NFR-301**: `features/garden/`配下の実装は`logic/`・`state/`・`resources/`・`ui/`のディレクトリ構成に従わなければならない 🔵 *[.claude/rules/architecture.md]*
- **NFR-302**: 他Featureから庭機能を参照する場合は`features/garden/logic/*.gd`および`features/garden/resources/*.gd`のみを参照可能とし、`state/`・`ui/`への直接参照を行ってはならない 🔵 *[.claude/rules/architecture.md「公開APIパターン」]*

### テスト容易性

- **NFR-401**: `features/garden/logic/`配下の全public `static func`は、正常系・異常系・境界値のテストをGdUnit4で最低1本ずつ持たなければならない 🔵 *[.claude/rules/testing.md「カバレッジ目標」]*
- **NFR-402**: テストファイルは`tests/unit/features/garden/`または`tests/integration/`に配置しなければならない（`features/garden/`配下への配置は禁止） 🔵 *[.claude/rules/architecture.md「テストファイル配置」]*

## 制約

- **CON-001**: 実装言語はGDScript、対象エンジンはGodot 4.xとする 🔵 *[CLAUDE.md]*
- **CON-002**: テストフレームワークはGdUnit4を使用し、`tests/unit/features/garden/`・`tests/integration/`に配置する 🔵 *[.claude/rules/testing.md]*
- **CON-003**: `MaterialInstance`は複数Featureで共有されるため`shared/entities/material_instance.gd`に配置する（`features/garden/`配下には置かない） 🔵 *[ヒアリング結果「スコープ境界」/ architecture.md ディレクトリ構造]*
- **CON-004**: 本plan完了時点で`autoload/game_state.gd`は`plant_seed`, `harvest`, `advance_turn_growth`の3メソッドを追加するが、`end_turn()`自体（日替わり指定調合物再抽選・制限ターン判定を含む統合処理）はGuildSystem/RankSystem側が未実装のため本plan外とする 🔵 *[ヒアリング結果「スコープ境界」/ ui-design/screens/garden.md L85「OnTurnEnded」は将来別planでadvance_turn_growthを呼び出す想定]*
- **CON-005**: `shared/loaders/master_data_loader.gd`は現状スタブ（常に空配列/true返却）であるため、本plan内のGdUnit4テストは`SeedMaster`/`MaterialMaster`のテスト用フィクスチャ（`tests/mocks/`等）を個別に用意しなければならない 🟡 *[プロジェクトコンテキスト「現状」]*
- **CON-006**: 庭スロット数・枯死猶予ターン数・品質上昇確率等のバランス数値は`balance-design.md`記載の仮値をそのまま`GameBalance`定数として採用し、コード上に🟡TBDである旨をコメントで明記する 🔵 *[ヒアリング結果「バランス数値の扱い」]*
- **CON-007**: ゲーム開始時の初期手持ち種（`seed_inventory`）の具体的な構成は`data-schema.md`のJSON例に準拠する形で本plan内で仮決めする 🔵 *[ヒアリング結果「初期手持ち種」]*
- **CON-008**: テスト用の初期2種を`seed_herb`（早熟、成熟1〜2ターン）・`seed_ore`（晩成、成熟4〜5ターン）として本plan内で仮決めする。`base_quality`・`trait_pool`の具体値も本plan内でテスト可能な仮値として新規決定する 🔵 *[ヒアリング結果「バランス数値の扱い」「未確定事項」]*

## 信頼性レベルサマリー

- 🔵 青信号: 40件（FR 28件 + NFR 5件 + CON 7件）
- 🟡 黄信号: 7件（FR 3件: FR-204, FR-302, FR-303 / NFR 3件: NFR-001, NFR-101, NFR-202 / CON 1件: CON-005）
- 🔴 赤信号: 0件（要確認なし）
