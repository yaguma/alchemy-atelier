# rank 受入基準

## 関連文書

- **要件定義**: [requirements.md](requirements.md)
- **ユーザーストーリー**: [user-stories.md](user-stories.md)

**【信頼性レベル凡例】**:
- 🔵 確実な基準
- 🟡 妥当な推測による基準
- 🔴 AI推論補完（要確認）

---

## AC-001: [FR-101] apply_contributionのノルマ減算とクランプ 🔵

**関連**: FR-101, US-002

### Given（前提条件）
- 任意の`current_quota: float`と`contribution: float`

### When（実行条件）
- `RankQuotaResolver.apply_contribution(current_quota, contribution)`を呼び出す

### Then（期待結果）
- `max(0.0, current_quota - contribution)`が返る
- 戻り値が負になることはない（0未満は`0.0`にクランプされ、超過分は切り捨てられる）
- 引数はいずれも書き換えられない（純粋関数）

### テストチェックリスト

- [ ] **正常系**: `apply_contribution(100.0, 30.0)` → `70.0` 🔵
- [ ] **正常系**: `apply_contribution(100.0, 100.0)` → `0.0`（ちょうど削り切る） 🔵
- [ ] **境界値**: `apply_contribution(10.0, 999.0)` → `0.0`（超過分は切り捨て、負にならない） 🔵
- [ ] **境界値**: `apply_contribution(0.0, 50.0)` → `0.0`（既に0のノルマへ追加納品しても0のまま） 🔵
- [ ] **境界値**: `apply_contribution(100.0, 0.0)` → `100.0`（貢献度0の納品でノルマが変化しない） 🔵
- [ ] **異常系**: `apply_contribution(100.0, -20.0)` → `120.0`を返しクラッシュしない（負の貢献度はDomain層では拒否せず素直に加算される。入力の正当性検証は呼び出し元の責務であることをテストで明文化する） 🟡

---

## AC-002: [FR-102] is_rank_clearedのクリア判定 🔵

**関連**: FR-102, US-002

### Given（前提条件）
- 任意の`current_quota: float`

### When（実行条件）
- `RankQuotaResolver.is_rank_cleared(current_quota)`を呼び出す

### Then（期待結果）
- `current_quota <= 0.0`の真偽が返る

### テストチェックリスト

- [ ] **正常系**: `is_rank_cleared(0.0)` → `true` 🔵
- [ ] **正常系**: `is_rank_cleared(50.0)` → `false` 🔵
- [ ] **境界値**: `is_rank_cleared(0.001)` → `false`（わずかでも残っていれば未クリア） 🔵
- [ ] **境界値**: `is_rank_cleared(-5.0)` → `true`（`apply_contribution`を経由しない負値でも`<=`により真） 🔵
- [ ] **異常系**: `apply_contribution`の戻り値をそのまま渡した場合、負値が渡ることはなく常に`0.0`以上で判定される 🟡

---

## AC-003: [FR-104] is_turn_limit_reachedの制限ターン到達判定 🔵

**関連**: FR-104, US-004

### Given（前提条件）
- 任意の`current_turn: int`と`limit_turn: int`

### When（実行条件）
- `TurnLimitResolver.is_turn_limit_reached(current_turn, limit_turn)`を呼び出す

### Then（期待結果）
- `current_turn >= limit_turn`の真偽が返る

### テストチェックリスト

- [ ] **正常系**: `is_turn_limit_reached(10, 15)` → `false` 🔵
- [ ] **正常系**: `is_turn_limit_reached(20, 15)` → `true`（超過していても到達扱い） 🔵
- [ ] **境界値**: `is_turn_limit_reached(15, 15)` → `true`（ちょうど到達。`>`ではなく`>=`であることの検証） 🔵
- [ ] **境界値**: `is_turn_limit_reached(14, 15)` → `false`（到達直前） 🔵
- [ ] **境界値**: `is_turn_limit_reached(0, 0)` → `true`（`limit_turn = 0`の縮退ケースでクラッシュしない） 🟡
- [ ] **異常系**: `is_turn_limit_reached(-1, 15)` → `false`を返しクラッシュしない 🟡

---

## AC-004: [FR-105, FR-106, FR-107, FR-411] resolve_rank_outcomeの4通りの組み合わせ 🔵

**関連**: FR-105, FR-106, FR-107, FR-411, US-004, US-005

### Given（前提条件）
- `quota_cleared: bool`と`turn_limit_reached: bool`の全4通りの組み合わせ

### When（実行条件）
- `TurnLimitResolver.resolve_rank_outcome(quota_cleared, turn_limit_reached)`を呼び出す

### Then（期待結果）
- `turn_limit_reached = false`のとき、`quota_cleared`の値によらず常に`RankOutcome.CONTINUE`が返る（早期クリアボーナス、FR-411）
- `turn_limit_reached = true`かつ`quota_cleared = true`のとき`RankOutcome.PROMOTION_ELIGIBLE`が返る
- `turn_limit_reached = true`かつ`quota_cleared = false`のとき`RankOutcome.DEMOTION`が返る

### テストチェックリスト

- [ ] **正常系**: `(quota_cleared=false, turn_limit_reached=false)` → `CONTINUE` 🔵
- [ ] **正常系**: `(quota_cleared=true, turn_limit_reached=false)` → `CONTINUE`（**ノルマ0でも制限ターン未到達なら試験へ移行しない**、FR-411の中核検証） 🔵
- [ ] **正常系**: `(quota_cleared=true, turn_limit_reached=true)` → `PROMOTION_ELIGIBLE` 🔵
- [ ] **正常系**: `(quota_cleared=false, turn_limit_reached=true)` → `DEMOTION` 🔵
- [ ] **境界値**: 上記4通りを`test_parameters`によるパラメータ化テストで網羅し、返却値が`CONTINUE`/`PROMOTION_ELIGIBLE`/`DEMOTION`の3値以外にならないことを確認する 🔵
- [ ] **異常系**: `turn_limit_reached=false`の2ケースで`PROMOTION_ELIGIBLE`・`DEMOTION`が一度も返らないことを明示的にアサートする（早期クリアの構造的保証） 🔵

---

## AC-005: [FR-101, FR-102] 連続納品によるノルマ枯渇の累積挙動 🔵

**関連**: FR-101, FR-102, US-002

### Given（前提条件）
- `quota_max = 100.0`のランクノルマ
- 貢献度`40.0`の納品を3回連続して適用するシナリオ

### When（実行条件）
- `apply_contribution`の戻り値を次の呼び出しの`current_quota`として順次渡し、各回で`is_rank_cleared`を評価する

### Then（期待結果）
- 1回目: `60.0` / 未クリア、2回目: `20.0` / 未クリア、3回目: `0.0` / クリア
- 3回目で超過した`20.0`分は切り捨てられ、ノルマが負に転じない

### テストチェックリスト

- [ ] **正常系**: 3回の連続適用でノルマが`100.0 → 60.0 → 20.0 → 0.0`と遷移する 🔵
- [ ] **正常系**: 3回目の適用後に`is_rank_cleared`が`true`へ切り替わる 🔵
- [ ] **境界値**: クリア後にさらに納品を適用しても`0.0`のまま維持され、`is_rank_cleared`が`true`を返し続ける 🔵
- [ ] **異常系**: 貢献度`0.0`の納品を挟んでもノルマ・クリア判定が変化しない 🟡

---

## AC-006: [FR-003] RankOutcome enumの定義 🔵

**関連**: FR-003, US-004, US-005

### Given（前提条件）
- `features/rank/logic/rank_outcome.gd`の実装

### When（実行条件）
- `RankOutcome`の各値を参照する

### Then（期待結果）
- `CONTINUE`・`PROMOTION_ELIGIBLE`・`DEMOTION`の3値が定義されている
- `TurnLimitResolver.resolve_rank_outcome`の戻り値型として型注釈付きで使用できる

### テストチェックリスト

- [ ] **正常系**: 3値が全て参照でき、互いに異なる値を持つ 🔵
- [ ] **正常系**: 他Feature（`GameState`・将来のpromotion-exam plan）から`class_name`経由でグローバル参照できる（CON-003の配置根拠の検証） 🔵
- [ ] **境界値**: enumに4値目が定義されていない（スコープ外の`ExamOutcome`の値が混入していない、FR-403） 🔵

---

## AC-007: [FR-004] RankMasterの型定義 🔵

**関連**: FR-004, US-001, US-007

### Given（前提条件）
- `features/rank/resources/rank_master.gd`の実装

### When（実行条件）
- `RankMaster`をコード上でインスタンス化し各フィールドへ値を設定する（CON-006）

### Then（期待結果）
- `id: String, display_name: String, quota_max: float, limit_turn: int, traits_unlocked: bool, exam_turn_limit: int, exam_difficulty_coefficient: float`の7フィールドが全て存在する
- `Resource`を継承しており、将来`.tres`として保存可能である

### テストチェックリスト

- [ ] **正常系**: 7フィールド全てに値を設定・取得できる 🔵
- [ ] **正常系**: `traits_unlocked = false`のGランク相当フィクスチャを構築できる 🔵
- [ ] **境界値**: `exam_turn_limit`・`exam_difficulty_coefficient`は本planのロジックから一切参照されない（CON-012）。値を変えても`RankQuotaResolver`・`TurnLimitResolver`の結果が変化しないことを確認する 🔵
- [ ] **異常系**: `quota_max = 0.0`・`limit_turn = 0`の縮退フィクスチャを渡してもロジックがクラッシュしない 🟡

---

## AC-008: [FR-005, FR-103, FR-401] RankStateとreset_for_retryの初期化 🔵

**関連**: FR-005, FR-103, FR-401, US-003, US-005

### Given（前提条件）
- `quota_max = 100.0`・`limit_turn = 15`の`RankMaster`フィクスチャ
- `quota = 37.5`・`elapsed_turn = 15`まで進行した既存の`RankState`

### When（実行条件）
- `RankQuotaResolver.reset_for_retry(rank_master)`を呼び出す

### Then（期待結果）
- 戻り値の`RankState`は`quota = 100.0`（`rank_master.quota_max`）・`elapsed_turn = 0`である
- 引数の`rank_master`は一切書き換えられていない
- 呼び出し元が保持していた既存の`RankState`インスタンスも書き換えられていない（**新しいインスタンス**が返る、FR-401）

### テストチェックリスト

- [ ] **正常系**: 戻り値の`quota`が`rank_master.quota_max`と等しい 🔵
- [ ] **正常系**: 戻り値の`elapsed_turn`が`0`である 🔵
- [ ] **正常系**: `elapsed_turn`が`GameState._current_turn`（グローバルターン数）と独立しており、リセットしても`_current_turn`が変化しない（US-003の中核検証） 🔵
- [ ] **境界値**: `quota_max = 0.0`の`RankMaster`を渡すと`quota = 0.0`の`RankState`が返る（即クリア状態） 🟡
- [ ] **異常系**: `reset_for_retry`の戻り値と引数前に保持していた`RankState`が別インスタンスであり、一方の変更が他方に波及しない 🔵
- [ ] **異常系**: `rank_master = null`を渡した場合にクラッシュせず、`push_error()`で報告したうえで安全な既定値の`RankState`を返す（NFR-101） 🟡

---

## AC-009: [FR-006, FR-108, FR-408] 納品時のノルマ消費統合と暫定フィールドの撤去 🔵

**関連**: FR-006, FR-108, FR-408, US-002, US-010

### Given（前提条件）
- `GameState.reset_for_test()`後、`_set_rank_masters_for_test()`で`quota_max = 100.0`のランクを注入した状態
- `_pending_products`に`contribution`を持つ`ProductInstance`が複数積まれている状態（guild planの`deliver_pending_products()`が利用可能であること。CON-010）

### When（実行条件）
- `GameState.deliver_pending_products()`を呼び出す

### Then（期待結果）
- 各`DeliveryResult.final_contribution`について`RankQuotaResolver.apply_contribution`が適用され、`_rank_state.quota`が減少している
- `_accumulated_contribution`フィールドおよびそこへの加算処理がソース上に存在しない
- 報酬（`final_reward`）の`_gold`加算など guild plan の他の挙動は変化していない

### テストチェックリスト

- [ ] **正常系**: 貢献度合計が`quota_max`未満の納品後、`_rank_state.quota`が`quota_max - 貢献度合計`になる 🔵
- [ ] **正常系**: 複数件の納品が1回の呼び出しで順次ノルマへ適用される 🔵
- [ ] **境界値**: 貢献度合計が`quota_max`を超える納品後も`_rank_state.quota`が`0.0`で止まる（負にならない） 🔵
- [ ] **境界値**: `_pending_products`が空の状態で呼び出しても`_rank_state.quota`が変化しない（guild FR-109との整合） 🔵
- [ ] **異常系**: `grep`で`_accumulated_contribution`がリポジトリ内に1件も残っていないことを確認する 🔵
- [ ] **異常系**: guild planの既存テストのうち`_accumulated_contribution`を検証していたケースが`_rank_state.quota`ベースへ更新され、全て成功する（NFR-303） 🟡

---

## AC-010: [FR-109] ランク結果評価クエリメソッド 🔴

**関連**: FR-109, US-009

### Given（前提条件）
- `_rank_masters`・`_current_rank_id`・`_rank_state`が設定済みの`GameState`

### When（実行条件）
- ランク結果評価クエリ（`evaluate_rank_outcome()`。CON-009）を呼び出す

### Then（期待結果）
- 内部で`is_rank_cleared(_rank_state.quota)`と`is_turn_limit_reached(_rank_state.elapsed_turn, rank_master.limit_turn)`が評価され、その結果を`resolve_rank_outcome`へ渡した`RankOutcome`が返る
- 呼び出しによって`GameState`の状態は一切変化しない（副作用のない問い合わせ、CON-009）

### テストチェックリスト

- [ ] **正常系**: ノルマ残存・制限ターン未到達 → `CONTINUE`が返る 🔴
- [ ] **正常系**: ノルマ0・制限ターン到達 → `PROMOTION_ELIGIBLE`が返る 🔴
- [ ] **正常系**: ノルマ残存・制限ターン到達 → `DEMOTION`が返る 🔴
- [ ] **境界値**: ノルマ0・制限ターン未到達 → `CONTINUE`が返る（早期クリアボーナスがGameState経由でも保たれる、FR-411） 🔵
- [ ] **異常系**: 連続して2回呼び出しても同じ結果が返り、`_demotion_count`・`_rank_state`のいずれも変化しない（冪等性） 🔴
- [ ] **異常系**: `_rank_masters`に`_current_rank_id`が存在しない場合でもクラッシュせず、CON-008のフォールバック（`limit_turn = 0`）に基づく結果を返す 🔴

---

## AC-011: [FR-007, FR-110, FR-111, FR-113, FR-202] 降格確定・降格回数・ゲームオーバー 🔵

**関連**: FR-007, FR-110, FR-111, FR-113, FR-202, US-005, US-006

### Given（前提条件）
- `GameBalance.MAX_DEMOTION_COUNT = 3`（CON-007）
- `quota_max = 100.0`・`limit_turn = 15`の`RankMaster`を注入し、`quota = 40.0`・`elapsed_turn = 15`（制限ターン到達・ノルマ残存）の`RankState`を設定した`GameState`

### When（実行条件）
- ランク結果確定処理（`commit_rank_outcome()`。CON-009）を呼び出す

### Then（期待結果）
- `RankOutcome.DEMOTION`が確定し、`_demotion_count`が1加算される
- `_rank_state`が`RankQuotaResolver.reset_for_retry(rank_master)`の戻り値（`quota = 100.0`・`elapsed_turn = 0`）へ差し替わる
- 庭・在庫・ゴールド・恒久投資（`_garden_state`・`_inventory`・`_gold`・`_alchemy_slot_count`・`_garden_slot_count`・`_unlocked_recipe_ids`）はいずれも変化しない
- `_demotion_count`が`MAX_DEMOTION_COUNT`に到達した時点でゲームオーバーが確定し、問い合わせ可能になる

### テストチェックリスト

- [ ] **正常系**: 1回目のDEMOTION確定で`_demotion_count`が`0 → 1`になる 🔵
- [ ] **正常系**: DEMOTION確定後に`_rank_state.quota = quota_max`・`_rank_state.elapsed_turn = 0`となる 🔵
- [ ] **正常系**: DEMOTION確定後も`_gold`・`_inventory`・`_garden_state`・`_unlocked_recipe_ids`が変化しない（降格時のリセット規定の検証） 🔵
- [ ] **正常系**: `PROMOTION_ELIGIBLE`確定時は`_demotion_count`が加算されず`_rank_state`もリセットされない 🔵
- [ ] **正常系**: `CONTINUE`確定時は`_demotion_count`・`_rank_state`のいずれも変化しない 🔵
- [ ] **境界値**: 3回目のDEMOTIONで`_demotion_count = 3`となりゲームオーバーが確定する（`MAX_DEMOTION_COUNT`ちょうど） 🔵
- [ ] **境界値**: 2回目のDEMOTION（`_demotion_count = 2`）ではゲームオーバーが確定しない（閾値直前） 🔵
- [ ] **異常系**: ゲームオーバー確定後にさらに確定処理を呼び出しても`_demotion_count`が4以上へ増加せず、状態が変化しない（FR-202の冪等性） 🟡
- [ ] **異常系**: `MAX_DEMOTION_COUNT`がマジックナンバーとして直書きされておらず`GameBalance`から参照されていることを`grep`で確認する（FR-007） 🔵

---

## AC-012: [FR-112, FR-113] ランク結果・ゲームオーバーのシグナル発行 🔴

**関連**: FR-112, FR-113, US-011

### Given（前提条件）
- `GameState`のシグナルを`monitor_signals(GameState, false)`で監視（Autoloadのため第2引数`false`必須）
- ランク結果が確定しうる状態（制限ターン到達）の`GameState`

### When（実行条件）
- ランク結果確定処理を呼び出す

### Then（期待結果）
- 確定した`RankOutcome`を引数に持つランク結果シグナルが1回発行される
- 降格によりゲームオーバーが成立した場合、追加でゲームオーバーシグナルが発行される
- ゲームオーバーが成立しない場合、ゲームオーバーシグナルは発行されない

### テストチェックリスト

- [ ] **正常系**: `DEMOTION`確定時にランク結果シグナルが`DEMOTION`を引数として発行される 🔴
- [ ] **正常系**: `PROMOTION_ELIGIBLE`確定時に同シグナルが`PROMOTION_ELIGIBLE`を引数として発行される 🔴
- [ ] **正常系**: ゲームオーバー成立時にゲームオーバーシグナルが発行され、`_demotion_count`が読み取れる（NFR-201） 🔴
- [ ] **境界値**: `CONTINUE`確定時にゲームオーバーシグナルが発行されない 🔴
- [ ] **異常系**: `monitor_signals(GameState, false)`の第2引数を明示し、テスト終了後もAutoloadが解放されないことを確認する（testing.md「重大な罠」） 🔵

---

## AC-013: [FR-001, FR-002, FR-401, FR-402] Functional Coreの純粋性 🔵

**関連**: FR-001, FR-002, FR-401, FR-402, US-008

### Given（前提条件）
- `features/rank/logic/`配下の実装（`rank_quota_resolver.gd`・`turn_limit_resolver.gd`・`rank_outcome.gd`）

### When（実行条件）
- ソースを静的に検査し、同一入力での反復呼び出しを実行する

### Then（期待結果）
- 全ての公開関数が`static func`であり、クラスは`Node`を継承していない
- `GameState`・`RngService`等のAutoloadへの参照、ファイルI/O、乱数生成が一切存在しない
- 同一入力に対して常に同一の出力が返る

### テストチェックリスト

- [ ] **正常系**: 同じ引数で100回呼び出しても全て同じ結果になる（`apply_contribution`・`resolve_rank_outcome`） 🔵
- [ ] **正常系**: `logic/`配下のクラスが`Node`非継承であり、インスタンス化せず`static func`として呼び出せる 🔵
- [ ] **異常系**: `grep`で`logic/`配下に`GameState`・`RngService`・`randf`・`randi`・`FileAccess`が含まれないことを確認する 🔵
- [ ] **境界値**: `reset_for_retry`が引数・呼び出し元の既存インスタンスを一切変更しない（AC-008と重複確認、FR-401） 🔵

---

## AC-014: [FR-114, FR-201] traits_unlockedのランク由来化と欠落時フォールバック 🔵

**関連**: FR-114, FR-201, US-007

### Given（前提条件）
- `traits_unlocked = false`のGランク相当`RankMaster`、および`traits_unlocked = true`の上位ランク相当`RankMaster`のフィクスチャ
- 調合実行（`GameState.execute_alchemy()`）が可能な在庫・レシピが揃った状態

### When（実行条件）
- 各ランクを`_current_rank_id`として設定し`execute_alchemy()`を実行する
- 併せて`_rank_masters`に`_current_rank_id`が存在しない状態でも実行する

### Then（期待結果）
- `QualityCalculator.calculate_quality`・`TraitActivation.resolve_traits`へ渡される特性解禁フラグが、現在ランクの`RankMaster.traits_unlocked`と一致する
- `_rank_masters`に該当ランクが存在しない場合、クラッシュせず`push_error()`で報告したうえで`false`（特性封印＝安全側、CON-008）が使われる

### テストチェックリスト

- [ ] **正常系**: `traits_unlocked = false`のランクでは特性が発現しない（Gランク相当の挙動） 🔵
- [ ] **正常系**: `traits_unlocked = true`のランクでは特性発現判定が有効になる 🔵
- [ ] **正常系**: ランクを切り替えると同一素材でも特性発現の有無が変わる（権威がランク側にあることの検証） 🔵
- [ ] **異常系**: `_rank_masters`が空の状態で調合してもクラッシュせず、特性が発現しない（`false`フォールバック） 🔵
- [ ] **異常系**: `_rank_masters`に存在しないランクIDが`_current_rank_id`に設定されている状態で`push_error()`が呼ばれることを確認する 🟡
- [ ] **境界値**: alchemy planの既存テストのうち`_set_traits_unlocked_for_test()`に依存していたケースが、ランク注入経由へ移行しても同じ振る舞いを保つ（CON-005, NFR-303） 🟡

---

## AC-015: [FR-301] テスト専用APIによるランク状態の注入 🟡

**関連**: FR-301, US-012

### Given（前提条件）
- `res://data/ranks/`に`.tres`実データが存在しない状態（CON-006）

### When（実行条件）
- `_set_rank_masters_for_test()`・`_set_rank_state_for_test()`・`_set_demotion_count_for_test()`を呼び出す

### Then（期待結果）
- 実データのロードを介さずランクマスター・ランク状態・降格回数を任意の値に設定できる
- 各APIは`assert(OS.is_debug_build(), ...)`と`if not OS.is_debug_build(): push_error(...); return`の二重ガードを持つ

### テストチェックリスト

- [ ] **正常系**: 注入したランクマスターが以降のランク判定に反映される 🟡
- [ ] **正常系**: 注入した`RankState`（任意の`quota`・`elapsed_turn`）で結果評価が期待通りに分岐する 🟡
- [ ] **正常系**: `_set_demotion_count_for_test(2)`により閾値直前の状態を直接構築できる（AC-011の境界値テストの前提） 🟡
- [ ] **異常系**: 各テスト専用APIが二重ガード（`assert` + `push_error`+`return`）を備えていることをコードレビューで確認する 🔵
- [ ] **境界値**: `reset_for_test()`がランク関連フィールド（`_current_rank_id`・`_rank_masters`・`_rank_state`・`_demotion_count`）を全て初期値へ戻し、テスト間の状態が漏れない 🔵

---

## AC-016: [FR-006, FR-302, FR-409, FR-410] 状態のカプセル化と防御的コピー 🔵

**関連**: FR-006, FR-302, FR-409, FR-410, US-009, US-012, US-013

### Given（前提条件）
- ランク状態が設定済みの`GameState`

### When（実行条件）
- `GameState.get_state()`の戻り値に含まれるランク関連フィールドを呼び出し元で変更する
- 併せて`features/rank/state/rank_state.gd`への参照元をソース全体で検査する

### Then（期待結果）
- 戻り値を変更しても`GameState`内部の`_rank_state`・`_demotion_count`が汚染されない（`clone()`によるディープコピー、CON-011）
- `RankState`を参照しているのは`features/rank/logic/`（`reset_for_retry`の戻り値型）と`autoload/game_state.gd`のみであり、他Feature・UIからの直接参照が存在しない

### テストチェックリスト

- [ ] **正常系**: `get_state()`の戻り値の`rank_state.quota`を書き換えても`GameState`内部の値が変化しない 🔵
- [ ] **正常系**: `get_state()`が`current_rank_id`・`demotion_count`・`rank_state`を含む 🔵
- [ ] **異常系**: `grep`で`features/alchemy/`・`features/garden/`・`features/guild/`から`RankState`への参照が0件であることを確認する（FR-409） 🔵
- [ ] **境界値**: `RankState.clone()`が`quota`・`elapsed_turn`の両方を独立コピーする 🔵
- [ ] **正常系**: `_demotion_count`リセットAPI（FR-302、提供する場合）が`_demotion_count`のみを0へ戻し、`_rank_state`・`_current_rank_id`を変更しない 🟡

---

## AC-017: [FR-403, FR-404, FR-405, FR-406, FR-407] スコープ外機能の非実装確認 🔵

**関連**: FR-403, FR-404, FR-405, FR-406, FR-407, US-013

### Given（前提条件）
- 本plan完了時点のリポジトリ状態

### When（実行条件）
- ディレクトリ構成・ソースを静的に検査する

### Then（期待結果）
- `PromotionExamResolver`・`ExamState`・`ExamOutcome`が存在しない（FR-403）
- `_current_rank_id`を次ランクへ進める処理が存在しない（FR-404）
- `res://data/ranks/`に`.tres`実データが存在しない（FR-405）
- `advance_turn()`相当のターン進行メソッド、およびターン進行に連動した自動判定の配線が存在しない（FR-406）
- `features/rank/ui/`にファイルが存在しない（FR-407）

### テストチェックリスト

- [ ] **正常系**: `features/rank/`配下が`logic/`・`resources/`・`state/`のみで構成されている（`ui/`は空、NFR-301） 🔵
- [ ] **正常系**: `data/ranks/`に`.tres`が0件である 🔵
- [ ] **異常系**: `grep`で`PromotionExamResolver`・`ExamState`・`ExamOutcome`・`advance_turn`が本planの成果物に含まれないことを確認する 🔵
- [ ] **異常系**: `_current_rank_id`への代入箇所が初期化・テスト専用APIのみであり、昇格による遷移ロジックが存在しないことを確認する 🔵

---

## 横断的受入基準

### パフォーマンス（NFR-001）

- [ ] ランクノルマ更新・結果判定が`_process()`を用いず、呼び出し時の同期処理のみで完結する実装になっていることをコードレビューで確認する 🟡

### セキュリティ（NFR-101）

- [ ] `rank_master = null`・`_rank_masters`に該当IDなし・負の`contribution`・`limit_turn = 0`のいずれを渡してもクラッシュせず、定義された結果を返すことをテストする（AC-001, AC-003, AC-008, AC-010, AC-014と重複確認） 🔵

### ユーザビリティ（NFR-201）

- [ ] ランク結果シグナル・ゲームオーバーシグナルから`RankOutcome`と`_demotion_count`が読み取れ、将来のUIが「昇格試験へ進める」「あと何回で詰みか」を表示可能であることを確認する 🟡

### 保守性・アーキテクチャ整合性（NFR-301, NFR-302, NFR-303）

- [ ] `features/rank/`が`logic/`・`resources/`・`state/`の構成に従っていることを`gdlint`・ディレクトリ構成確認で検証する 🔵
- [ ] 他Featureのコードが`features/rank/`の`state/`・`ui/`を参照していないことを確認する 🔵
- [ ] guild plan・alchemy planの既存テストが本planの破壊的変更（CON-004, CON-005）後も全て成功する。更新したテストについては更新理由がコミットメッセージに記載されている 🟡

### テスト容易性（NFR-401, NFR-402）

- [ ] `features/rank/logic/`配下の全public `static func`（`apply_contribution`・`is_rank_cleared`・`reset_for_retry`・`is_turn_limit_reached`・`resolve_rank_outcome`の5つ）について、正常系・異常系・境界値のテストが最低1本ずつ存在することを数え上げで確認する 🔵
- [ ] `rank`関連のテストファイルが`tests/unit/features/rank/`または`tests/integration/`にのみ配置され、`features/rank/`配下に`test_*.gd`が存在しないことを確認する 🔵

### 前提依存（CON-010）

- [ ] 本plan着手時点で guild plan の`DeliveryResolver`・`DeliveryResult`・`GameState.deliver_pending_products()`が実装済みであることを確認する（未実装の場合、AC-009は実施不能） 🔴

---

## テストサマリー

| カテゴリ | 正常系 | 異常系 | 境界値 | 合計 |
|---------|--------|--------|--------|------|
| 機能要件（AC-001〜AC-017） | 38 | 18 | 21 | 77 |
| 非機能要件（横断的受入基準） | 9 | 0 | 0 | 9 |
| **合計** | 47 | 18 | 21 | 86 |

## 信頼性レベル分布

- 🔵 青信号: 14件 (82.4%): AC-001〜AC-009, AC-011, AC-013, AC-014, AC-016, AC-017
- 🟡 黄信号: 1件 (5.9%): AC-015（テスト専用APIの提供が任意要件FR-301に基づくため）
- 🔴 赤信号: 2件 (11.8%): AC-010, AC-012（`GameState`のランク結果評価API・シグナル設計が既存設計文書に規定されておらず新規補完）
- 合計: 17件
