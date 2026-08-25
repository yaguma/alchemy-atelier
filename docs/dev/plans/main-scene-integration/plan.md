# Plan: main-scene-integration

## Requirements Summary

`atelier/scenes/main.tscn` はPhase 1構築時から空の`Control`ノード1個のままで、garden/alchemy/guild/rank/workshopの5機能（個別には実装・テスト完了済み）を1本の遊べるループへ繋ぐ配線が存在しない。本Planはこれを解消し、ゲームを最初から最後まで実機で通しプレイできる状態にする。

詳細: [requirements.md](requirements.md) | [user-stories.md](user-stories.md) | [acceptance-criteria.md](acceptance-criteria.md)

スコープに含める主な要素（すべて赤信号解消済み、ユーザー確認済み）:
- MainScene（`scenes/main.gd`新規）による4画面（Garden/Alchemy/Workshop/Result）の常駐・`visible`切替
- RankHud（新規共通ヘッダー）、MainScene保持のタブバー（庭⇔調合）
- AlchemyScreenへの改修（CON-003により改修可能な唯一の既存画面）: `delivery_confirmed`中継signal追加、GuildDeliveryScreen常時表示バグ修正、`commit_rank_outcome()`/`commit_exam_outcome()`呼び出し配線
- 起動時マスターデータロード（garden/alchemy/workshop = 既存3関数、rank = 本Planで新規実装する`load_rank_master_data()`）
- G〜Sランク8件分の`RankMaster` `.tres`（最小限の仮値、正式バランス数値は別Plan）
- 5画面横断の結合シナリオをGdUnit4 `scene_runner()`統合テストで検証

スコープ外（Won't Have）: 恒久投資確認ダイアログ、タイトル/設定/セーブロード画面、正式ビジュアルデザイン、`daily_orders`実データ（`resolve_daily_order_for_delivery()`がnullを許容するため通しプレイのブロッカーではない）。

## Design Overview

### コード調査で判明した追加の前提条件（要件確定後、タスク分解の過程で発見）

- `GameStateRankDelegate`の`_rank_state_initialized`は、既存の本番コードパスでは**昇格成功時（`_commit_exam_success()`）にしかtrueにならない**。ゲーム開始時点（初回rank_g）に`_rank_state`を初期化する経路が本番コードに存在しない。`load_rank_master_data()`は、G〜Sランクのロードに加えて**初回起動時のみ`RankQuotaResolver.reset_for_retry(initial_rank_master)`で`_rank_state`を初期化し`_rank_state_initialized = true`にする**責務も持つ（既存の`RankQuotaResolver.reset_for_retry()`を流用）。
- `MasterDataLoader`（`shared/loaders/master_data_loader.gd`）は現状`&"materials"`/`&"recipes"`/`&"upgrades"`の3カテゴリしかサポートしない。`&"ranks"`カテゴリ（`RANKS_DIR = "res://data/ranks/"`、許容型`RankMaster`）を追加する必要がある。

### インターフェース設計

```gdscript
# atelier/autoload/game_state_rank_delegate.gd への追加
## 🔵 load_garden_master_data()等と同型。MasterDataLoaderに&"ranks"カテゴリを追加して使う。
## 初回ロード時のみ_rank_state_initialized=falseであることを条件に、GameBalance.INITIAL_RANK_ID
## のRankMasterでRankQuotaResolver.reset_for_retry()を呼びRankStateを初期化する
static func load_rank_master_data(state: GameStateScript) -> void

# atelier/autoload/game_state.gd への追加（既存load_*と同型の1行委譲）
func load_rank_master_data() -> void
```

```gdscript
# atelier/shared/loaders/master_data_loader.gd への変更
const RANKS_DIR := "res://data/ranks/"
# _resolve_dir_path()に &"ranks": return RANKS_DIR を追加
# _is_allowed_type()に &"ranks": return resource is RankMaster を追加
```

```gdscript
# atelier/features/alchemy/ui/alchemy_screen.gd への追加（CON-003で改修許容）
signal delivery_confirmed  # 🔵 FR-107。_guild_delivery_screen.screen_closedを中継

# _ready()に追加: _guild_delivery_screen.screen_closed.connect(_on_delivery_screen_closed)
# _exit_tree()に追加: 対応するdisconnect
func _on_delivery_screen_closed() -> void:
    _guild_delivery_screen.visible = false  # FR-203
    delivery_confirmed.emit()

# _deliver_and_display()を変更し、display_results()呼び出し後に visible = true を明示
# _on_end_turn_pressed()の末尾に GameState.commit_rank_outcome() を追加（FR-115。in_exam中の
# 自動納品パス（_on_product_crafted内）には追加しない）
# _on_advance_exam_turn_pressed()の GameState.advance_exam_turn() 直後に
# GameState.commit_exam_outcome() を追加（FR-116）
```

```gdscript
# atelier/shared/ui/rank_hud.gd（新規、shared/には既存ui/サブディレクトリが無いため本Planで新設。
# 単一Featureに属さない横断UIコンポーネントのためshared/に置く 🟡 判断）
class_name RankHud
extends Control

func _ready() -> void  # GameState.gold_changed/turn_growth_advanced/rank_outcome_confirmed/
                        # delivered/exam_started/exam_outcome_confirmedを購読しrefresh()
func _exit_tree() -> void  # 上記すべてdisconnect
func refresh() -> void  # 🔵 テスト用に公開。GameState.get_state()+get_current_rank_master()から再描画
func get_rank_name_text() -> String  # テスト用ゲッター
func get_gold_text() -> String       # テスト用ゲッター
```

```gdscript
# atelier/scenes/main.gd（新規）
class_name MainScene
extends Control

const GardenScreenScene = preload("res://features/garden/ui/garden_screen.tscn")
# ...他4画面も同様にpreload、またはmain.tscn側でinstance済みノードを%参照で取得

var _phase_before_workshop: StringName = &"garden"  # FR-105用の一時記録（例外的にGameStateと二重保持）

func _ready() -> void
    # 1. マスターデータロード: load_garden/alchemy/workshop/rank_master_data() (FR-006)
    # 2. GameState各signal購読 (FR-103,104,105,106,108,109,110,111,112)
    # 3. タブバーpressed購読 (FR-101,102)
    # 4. 初期表示をGameState.get_state()["current_phase"]に合わせる

func _exit_tree() -> void  # 全購読解除 (FR-005)

func get_visible_phase() -> StringName  # テスト用: 現在visible=trueの画面のフェーズ名を返す

func _on_phase_changed(previous: StringName, next: StringName) -> void  # FR-103
func _on_shop_requested() -> void  # FR-104。_phase_before_workshopに現在フェーズを記録してからset_phase(&"workshop")
func _on_workshop_closed() -> void  # FR-105。set_phase(_phase_before_workshop)
func _on_delivery_confirmed() -> void  # FR-106。set_phase(&"garden")
func _on_exam_started() -> void  # FR-108。set_phase(&"alchemy")、庭タブdisabled=true (FR-201)
func _on_exam_outcome_confirmed(outcome: ExamOutcome.Value) -> void  # FR-109,110。
    # SUCCESS→set_phase(&"workshop")、FAILURE→set_phase(&"garden")。庭タブdisabled解除
func _on_game_cleared() -> void  # FR-111。set_phase(&"result")。タブ両方disabled (FR-202)
func _on_game_over(demotion_count: int) -> void  # FR-112。同上
func _on_garden_tab_pressed() -> void  # FR-101
func _on_alchemy_tab_pressed() -> void  # FR-102
```

### データフロー（signal発行順序、FR-113の罠を含む）

```
[通常ターン1周]
GardenScreen: 植付/収穫 (GameState.plant_seed/harvest)
  → タブ「調合」押下 → MainScene.set_phase(&"alchemy") → phase_changed → AlchemyScreen可視
AlchemyScreen: 素材投入 → 「調合を実行する」→ GameState.execute_alchemy() → product_crafted
  → 「ターンを終了する」→ _deliver_and_display() [deliver_pending_products→display_results、
     GuildDeliveryScreen.visible=true]
  → GameState.commit_rank_outcome() [新規呼び出し。DEMOTIONなら即game_over発行の可能性あり]
GuildDeliveryScreen: 「続ける」→ screen_closed
  → AlchemyScreen中継: visible=false、delivery_confirmed.emit()
  → MainScene.set_phase(&"garden") → GardenScreenのみ可視

[昇格試験〜合否分岐（FR-113の同一フレーム内2回発行）]
commit_rank_outcome() 内部で PROMOTION_ELIGIBLE 判定
  → _start_exam() → exam_started.emit() → MainScene.set_phase(&"alchemy")、庭タブdisabled
AlchemyScreen（試験モードUI）: 「ターンを進める」→ GameState.advance_exam_turn()
  → GameState.commit_exam_outcome() [新規呼び出し]
     内部: 状態確定 → exam_outcome_confirmed.emit(outcome) [1回目]
           → (SUCCESSかつ真の最終ランクのみ) game_cleared.emit() [2回目]
           → (FAILUREかつgame_over条件成立のみ) game_over.emit(count) [2回目]
MainScene:
  exam_outcome_confirmed(SUCCESS) 受信 → set_phase(&"workshop") 暫定遷移
  直後に game_cleared 受信 → set_phase(&"result") で上書き（同一フレーム内、描画は最終状態のみ）
  ※ SUCCESSだが非最終ランクの場合は game_cleared が発行されないため workshop 遷移が最終状態のまま確定する
```

## Task Dependency Graph

```
001 rank-master-fixture-and-loader（基盤・独立）
  ├─→ 002 main-scene-scaffold（001のload_rank_master_data()を呼ぶ）
  │     ├─→ 003 tab-bar
  │     ├─→ 004 rank-hud
  │     ├─→ 005 workshop-routing
  │     └─→ 006 alchemy-delivery-relay-and-visibility-fix
  │           └─→ 007 turn-commit-wiring（006のdelivery_confirmed配線と独立だが同一ファイルのため直列）
  │                 └─→ 008 exam-and-result-routing（007のcommit_*呼び出しが発火させるsignalを購読）
  │                       ├─→ 009 integration-test-happy-path
  │                       └─→ 010 integration-test-exam-and-endings
```

トポロジカル順: 001 → 002 → 003, 004, 005（並行可） → 006 → 007 → 008 → 009, 010（並行可）

## Cross-Plan Dependencies

- `atelier/data/ranks/*.tres`（本Plan成果物）は将来のバランス調整Plan（`balance-design.md`の🟡🔴項目解消）が数値を上書きする前提の**仮データ**である。当該Planは本Planの成果物ファイルを変更するが、スキーマ（`RankMaster`）自体は変更しない想定。
- `atelier/data/daily_orders/`の実データ整備は本Planのスコープ外。将来別Planで着手する。
