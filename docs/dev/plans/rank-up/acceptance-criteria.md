# rank-up 受入基準

## 関連文書

- **要件定義**: [requirements.md](requirements.md)
- **ユーザーストーリー**: [user-stories.md](user-stories.md)

**【信頼性レベル凡例】**:
- 🔵 確実な基準
- 🟡 妥当な推測による基準
- 🔴 AI推論補完（要確認）

---

## AC-001: [FR-002] start_examによる試験状態の初期化 🔵

**関連**: FR-002, US-001

**Given**: PROMOTION_ELIGIBLE確定直前の現在ランクの`RankMaster`（`quota_max`/`limit_turn`/`exam_turn_limit`/`exam_difficulty_coefficient`が既知の値）が存在する
**When**: `PromotionExamResolver.start_exam(rank_master)` を呼ぶ
**Then**: 返る`ExamState`は `exam_quota == exam_quota_max == (quota_max/limit_turn)*exam_turn_limit*exam_difficulty_coefficient`、`exam_elapsed_turn == 0`、`exam_turn_limit == rank_master.exam_turn_limit`

- [ ] **正常系**: `quota_max=100, limit_turn=10, exam_turn_limit=3, coefficient=1.5` → `exam_quota_max=45` 🔵
- [ ] **異常系**: `limit_turn`が0の`RankMaster`を渡した場合のゼロ除算挙動（NFR-101のフォールバック方針との整合確認） 🟡
- [ ] **境界値**: `exam_difficulty_coefficient=0`（試験ノルマ0で開始し、直後の`resolve_outcome`がSUCCESSになるか） 🟡

---

## AC-002: [FR-003] advance_turnの不変更新 🔵

**関連**: FR-003, US-101, US-102

**Given**: 任意の`exam_elapsed_turn`値を持つ`ExamState`インスタンス`a`が存在する
**When**: `b = PromotionExamResolver.advance_turn(a)` を呼ぶ
**Then**: `b.exam_elapsed_turn == a.exam_elapsed_turn + 1`、`a`の各フィールドは呼び出し前後で不変、`a`と`b`は別インスタンス

- [ ] **正常系**: `exam_elapsed_turn=0` → `1` に更新された新規インスタンスが返る 🔵
- [ ] **異常系**: 該当なし（純粋関数のため実行時エラー系は対象外） 🔵
- [ ] **境界値**: `exam_elapsed_turn == exam_turn_limit - 1` から+1して上限ちょうどに到達するケース 🟡

---

## AC-003: [FR-004, FR-005] resolve_outcomeの3値判定とExamOutcome enum 🟡

**関連**: FR-004, FR-005, US-201, US-203

**Given**: `exam_quota`/`exam_elapsed_turn`/`exam_turn_limit`の組み合わせを持つ`ExamState`
**When**: `PromotionExamResolver.resolve_outcome(exam_state)` を呼ぶ
**Then**: `ExamOutcome.Value`の`SUCCESS`/`FAILURE`/`CONTINUE`のいずれか1値のみを返す（enumはこの3値のみで定義される）

- [ ] **正常系**: `exam_quota=50(>0)`, `exam_elapsed_turn=1 < exam_turn_limit=3` → `CONTINUE` 🔵
- [ ] **境界値①（SUCCESS境界）**: `exam_quota == 0` ちょうど（`<= 0`の境界） → `SUCCESS` 🔵
- [ ] **境界値②（FAILURE境界）**: `exam_elapsed_turn == exam_turn_limit` かつ `exam_quota > 0` → `FAILURE` 🔵
- [ ] **境界値③（CONTINUE）**: `exam_elapsed_turn < exam_turn_limit` かつ `exam_quota > 0` → `CONTINUE` 🔵
- [ ] **異常系**: `exam_quota`が負値の場合も`<= 0`条件によりSUCCESS扱いになることの明示的確認 🟡

---

## AC-004: [FR-006] ExamStateの型定義とclone() 🔵

**関連**: FR-006, US-001

**Given**: 4フィールド（`exam_quota`/`exam_quota_max`/`exam_elapsed_turn`/`exam_turn_limit`）を持つ`ExamState`インスタンス
**When**: `clone()` を呼ぶ
**Then**: 元インスタンスと同値の別インスタンスが返り、どちらか一方のフィールドを事後に変更してももう一方に影響しない

- [ ] **正常系**: `clone()`の戻り値が元と全フィールド等値かつ別参照であること 🔵
- [ ] **異常系**: 該当なし（型定義のみのため） 🔵
- [ ] **境界値**: 全フィールドが0（試験ノルマ0・経過ターン0）の`ExamState`の`clone()` 🟡

---

## AC-005: [FR-007] GameBalance.RANK_ORDERの定義 🔵

**関連**: FR-007, US-201, US-202

**Given**: `shared/constants/game_balance.gd`
**When**: `GameBalance.RANK_ORDER` を参照する
**Then**: `[&"rank_g", &"rank_f", &"rank_e", &"rank_d", &"rank_c", &"rank_b", &"rank_a", &"rank_s"]`の8要素`Array[StringName]`がこの順序で取得できる

- [ ] **正常系**: `RANK_ORDER[0] == &"rank_g"` かつ `RANK_ORDER[7] == &"rank_s"` 🔵
- [ ] **異常系**: 該当なし（定数定義のため） 🔵
- [ ] **境界値**: `RANK_ORDER.size() == 8` であることの確認 🟡

---

## AC-006: [FR-101, FR-302] PROMOTION_ELIGIBLE確定時の試験自動開始 🟡

**関連**: FR-101, FR-302, US-001

**Given**: `in_exam=false`の状態で`TurnLimitResolver.resolve_rank_outcome`が`PROMOTION_ELIGIBLE`を返す状況（`rank_state.quota<=0`かつ`current_turn>=limit_turn`）
**When**: `GameState.commit_rank_outcome()` を呼ぶ
**Then**: `in_exam == true`になり、`_exam_state`が`PromotionExamResolver.start_exam(現在ランクのRankMaster)`相当の値で設定される

- [ ] **正常系**: 呼び出し後に`get_state().in_exam == true`かつ`exam_quota_max`が期待値と一致 🔵
- [ ] **異常系**: 現在ランクの`RankMaster`が`_rank_masters`に存在しない場合、試験を開始せず`push_error()`でログを記録する（NFR-101） 🔵
- [ ] **境界値**: 該当なし 🟡

---

## AC-007: [FR-102] 試験中の調合実行によるターン消費 🔵

**関連**: FR-102, US-101

**Given**: `in_exam=true`、`exam_elapsed_turn=n`の`ExamState`が設定されている
**When**: `GameState.execute_alchemy()` を呼ぶ（通常の調合処理が成功する）
**Then**: 通常の調合処理に加えて`exam_elapsed_turn`が`n+1`に更新される

- [ ] **正常系**: `execute_alchemy()`成功後に`get_state().exam_elapsed_turn == n+1` 🔵
- [ ] **異常系**: `execute_alchemy()`自体がレシピ不成立等で失敗した場合に`exam_elapsed_turn`が加算されるか（要件文言上の明記なし、失敗時は非加算が妥当と推測） 🟡
- [ ] **境界値**: `exam_elapsed_turn == exam_turn_limit - 1` の状態から実行しちょうど上限に到達するケース 🟡

---

## AC-008: [FR-103, FR-104] 試験専用ターン進行メソッドとin_exam=false時のガード 🟡

**関連**: FR-103, FR-104, US-102

**Given**: (a) `in_exam=true`の状態 / (b) `in_exam=false`の状態
**When**: (a) `advance_exam_turn()`相当の試験専用メソッドを呼ぶ / (b) 同メソッドを`in_exam=false`の状態で呼ぶ
**Then**: (a) `exam_elapsed_turn`が+1され成功を表す`Result`が返る / (b) 状態が一切変更されず失敗を表す`Result`が返る

- [ ] **正常系**: `in_exam=true`時に`exam_elapsed_turn`が+1される 🔵
- [ ] **異常系（FR-104）**: `in_exam=false`時に試験専用ターン進行メソッドを誤呼び出しすると状態不変かつ`Result.success == false` 🟡
- [ ] **境界値**: `in_exam=true`状態で`exam_elapsed_turn == exam_turn_limit - 1`から実行しちょうど上限到達 🟡

---

## AC-009: [FR-105, FR-401] 試験中納品の試験ノルマ反映と指定合致ボーナス不適用 🔵

**関連**: FR-105, FR-401, US-103

**Given**: `in_exam=true`、`_current_daily_order`が非null、納品可能な調合物が保留中
**When**: `GameState.deliver_pending_products()` を呼ぶ
**Then**: `DeliveryResolver.resolve`が`daily_order = null`で呼ばれ（指定合致ボーナス不適用）、得られた`final_contribution`が`rank_state.quota`ではなく`exam_quota`に`RankQuotaResolver.apply_contribution`で適用される

- [ ] **正常系**: `_current_daily_order`が非nullでも試験中納品後は`exam_quota`のみ減算され`rank_state.quota`は変化しない 🔵
- [ ] **異常系**: 保留中の調合物が0件の場合の納品呼び出し（既存guild plan仕様との整合確認） 🟡
- [ ] **境界値**: `exam_quota`が残り1件分の貢献度でちょうど0以下になるケース（負値にならずクランプされるか） 🟡

---

## AC-010: [FR-106] 試験中納品でも報酬（ゴールド）は通常通り加算 🔵

**関連**: FR-106, US-103

**Given**: `in_exam=true`、納品可能な調合物が保留中
**When**: `GameState.deliver_pending_products()` を呼ぶ
**Then**: `final_reward`が非試験時と同じロジックで`gold`に加算される（試験中であることによる減額・無効化はない）

- [ ] **正常系**: 試験中/非試験中で同一の調合物構成を納品した場合の`gold`加算量が一致する 🔵
- [ ] **異常系**: 該当なし（報酬計算自体は既存guild planロジックの再利用のため） 🔵
- [ ] **境界値**: 保留中調合物が最大保管数の場合の一括納品 🟡

---

## AC-011: [FR-107] evaluate_exam_outcomeの問い合わせ専用性 🔵

**関連**: FR-107, US-201, US-203

**Given**: 任意の`ExamState`（CONTINUE/SUCCESS/FAILUREいずれかの条件を満たす）
**When**: `GameState.evaluate_exam_outcome()` を呼ぶ
**Then**: `PromotionExamResolver.resolve_outcome(_exam_state)`と同じ結果が返り、呼び出し前後で`GameState`の状態（`in_exam`・`_exam_state`・`gold`等）が一切変化しない

- [ ] **正常系**: 同一状態で複数回呼んでも常に同じ結果・状態不変 🔵
- [ ] **異常系**: 該当なし（問い合わせ専用のため） 🔵
- [ ] **境界値**: SUCCESS/FAILURE/CONTINUEそれぞれの境界（AC-003参照）で一致することを確認 🟡

---

## AC-012: [FR-108] commit_exam_outcome成功時のランク更新 🔵

**関連**: FR-108, FR-010, US-002, US-201

**Given**: `in_exam=true`、実行直前に再評価した`evaluate_exam_outcome()`が`SUCCESS`を返す状態、現在ランクが`RANK_ORDER`末尾ではない（例: `rank_g`）
**When**: `GameState.commit_exam_outcome()` を呼ぶ
**Then**: `_current_rank_id`が次ランク（例: `rank_f`）に更新され、`_demotion_count`が0にリセットされ、`_rank_state`が次ランクの`RankMaster.quota_max`で新規初期化され、`_rank_state_initialized`が`true`に設定され、`in_exam == false`に戻る

- [ ] **正常系**: `rank_g→rank_f`昇格で`current_rank_id`更新・`rank_state.quota==次ランクのquota_max`・`demotion_count==0`・`in_exam==false` 🔵
- [ ] **異常系**: 次ランクの`RankMaster`が`_rank_masters`に存在しない場合のフォールバック（NFR-101） 🟡
- [ ] **境界値**: `_rank_state_initialized`フラグが本FRの経路で初めて本番コードから`true`になること（`game_state_test_support.gd`以外での唯一のセット経路であることの確認） 🔵

---

## AC-013: [FR-109, FR-404] Sランク試験成功時のゲームクリア分岐 🟡

**関連**: FR-109, FR-404, FR-010, US-002, US-202

**Given**: `in_exam=true`、`evaluate_exam_outcome()`が`SUCCESS`を返す状態、現在ランクが`RANK_ORDER`末尾（`rank_s`）
**When**: `GameState.commit_exam_outcome()` を呼ぶ
**Then**: `_current_rank_id`は変更されず`_rank_state`の再初期化も行われず、ゲームクリアとして扱われ`in_exam == false`に戻る（`RANK_ORDER`範囲外アクセスは発生しない）

- [ ] **正常系**: `rank_s`で`SUCCESS`確定時に`current_rank_id`が`rank_s`のまま維持されゲームクリア扱いになる 🟡
- [ ] **異常系**: `RANK_ORDER`のindex+1が範囲外になる操作を試みてもクラッシュしない（配列範囲外アクセス防止の実装確認） 🔵
- [ ] **境界値（RANK_ORDER末尾）**: `RANK_ORDER`末尾（Sランク）での次ランク不在ちょうどの境界ケース 🔵

---

## AC-014: [FR-110] 試験失敗時の同ランク再挑戦リセット 🔵

**関連**: FR-110, US-203

**Given**: `in_exam=true`、実行直前に再評価した`evaluate_exam_outcome()`が`FAILURE`を返す状態
**When**: `GameState.commit_exam_outcome()` を呼ぶ
**Then**: `RankQuotaResolver.reset_for_retry(現在ランクのRankMaster)`で`_rank_state`がリセットされ、`_demotion_count`が+1され、`in_exam == false`に戻る

- [ ] **正常系**: `FAILURE`確定後に`rank_state.quota`が`reset_for_retry`相当の初期値に戻り`demotion_count`が+1される 🔵
- [ ] **異常系**: 現在ランクの`RankMaster`が存在しない場合のフォールバック（NFR-101） 🟡
- [ ] **境界値**: `demotion_count`が`MAX_DEMOTION_COUNT - 1`から+1されちょうど到達するケース（AC-015と連動） 🔵

---

## AC-015: [FR-111] demotion_count上限到達時のゲームオーバー確定 🔵

**関連**: FR-111, US-204

**Given**: `_demotion_count`が`GameBalance.MAX_DEMOTION_COUNT - 1`の状態で`FAILURE`が確定
**When**: `GameState.commit_exam_outcome()` を呼ぶ（FR-110の処理で`_demotion_count`が+1される）
**Then**: `is_game_over()`が`true`になり、既存の`game_over(demotion_count: int)`シグナルが発行される

- [ ] **正常系**: `_demotion_count == MAX_DEMOTION_COUNT`にちょうど到達した瞬間に`game_over`シグナルが発行される 🔵
- [ ] **異常系**: `MAX_DEMOTION_COUNT`未到達（-1の状態）では`game_over`が発行されないこと 🟡
- [ ] **境界値（ゲームオーバー確定境界）**: `_demotion_count`が`MAX_DEMOTION_COUNT`にちょうど到達する境界と、未到達（-1）との比較 🔵

---

## AC-016: [FR-112, FR-113, FR-301] commit_exam_outcomeの冪等性とCONTINUE時のno-op 🟡

**関連**: FR-112, FR-113, FR-301, US-205

**Given**: (a) `in_exam=true`、`evaluate_exam_outcome()`が`CONTINUE`を返す状態 / (b) `is_game_over()==true`が既に確定済みの状態
**When**: (a) `GameState.commit_exam_outcome()` を呼ぶ / (b) ゲームオーバー確定後に同メソッドを再度呼ぶ
**Then**: (a) 状態が一切変更されず`CONTINUE`であることを表す`Result`が返る / (b) 状態が再変更されず直近の確定結果が冪等に返る

- [ ] **正常系（FR-112: CONTINUE誤呼び出し）**: CONTINUE中の呼び出しで`in_exam`・`exam_state`・`rank_state`いずれも変化しない 🟡
- [ ] **異常系（FR-113: ゲームオーバー確定後の冪等呼び出し）**: ゲームオーバー確定後に複数回連続で呼んでも`_demotion_count`が再加算されない 🟡
- [ ] **境界値**: `SUCCESS`/`FAILURE`確定直後（1回目）とその直後の2回目呼び出しの結果が一致すること 🟡

---

## AC-017: [FR-008, FR-201] in_exam中のGameState唯一管理と二重開始防止 🟡

**関連**: FR-008, FR-201, US-001, US-002

**Given**: `in_exam=true`かつ`_exam_state`が進行中の状態（`exam_elapsed_turn > 0`）
**When**: `GameState.commit_rank_outcome()`が再度`PROMOTION_ELIGIBLE`を確定させる状況で呼ばれる
**Then**: 既存の`_exam_state`が上書き再初期化されず、`exam_elapsed_turn`等の進行状態が維持される

- [ ] **正常系**: `in_exam=true`中の再呼び出しでも`_exam_state`の`exam_elapsed_turn`が巻き戻らない 🟡
- [ ] **異常系**: `in_exam=false`からの初回開始時は正常に`start_exam`が呼ばれること（AC-006と重複確認） 🔵
- [ ] **境界値**: 該当なし 🟡

---

## AC-018: [FR-009] get_state()における試験状態ビューの防御的コピー 🔵

**関連**: FR-009, US-003

**Given**: `in_exam=true`かつ`_exam_state`が設定された状態
**When**: `GameState.get_state()` を呼ぶ
**Then**: 戻り値に`in_exam`・`exam_quota`・`exam_quota_max`・`exam_elapsed_turn`・`exam_turn_limit`の5フィールドが含まれ、戻り値側を変更しても`_exam_state`の内部正本に影響しない

- [ ] **正常系**: `get_state()`の戻り値の5フィールドが`_exam_state`の値と一致する 🔵
- [ ] **異常系**: 戻り値の`exam_quota`等を呼び出し元で書き換えても、再度`get_state()`した際に元の値に戻っている（防御的コピーの確認） 🔵
- [ ] **境界値**: `in_exam=false`の状態で`get_state()`を呼んだ場合の`exam_quota`等のデフォルト値（0または初期値） 🟡

---

## AC-019: [FR-403] ExamStateのin-place変更禁止の境界値検証 🔵

**関連**: FR-403, US-104

> 補足: `requirements.md`/`user-stories.md`のいずれからも直接参照されないAC番号だが、Step 3の指示に基づきFR-403（in-place変更禁止）の境界値検証専用ACとして本ドキュメントで新設した。

**Given**: `exam_elapsed_turn == exam_turn_limit - 1`（上限直前）の`ExamState`インスタンス`a`を用意する
**When**: `advance_turn(a)`を複数回連続で呼び、都度返り値を新しい変数に束縛する。同様に`a.clone()`も複数回呼ぶ
**Then**: 毎回`a`の元フィールドが変化せず、返り値のみが`exam_elapsed_turn`をインクリメントし続ける

- [ ] **正常系**: `advance_turn(a)`を3回連続で呼んでも`a.exam_elapsed_turn`が初期値のまま 🔵
- [ ] **異常系**: 該当なし（純粋関数の不変性検証のため） 🔵
- [ ] **境界値**: `exam_elapsed_turn`が上限ちょうど（`exam_turn_limit`）に達した状態でさらに`advance_turn`を呼んだ場合の戻り値（上限超過を許容するかクランプするか） 🟡

---

## AC-020: [FR-001, FR-402, FR-403] PromotionExamResolverの純粋関数性 🔵

**関連**: FR-001, FR-402, FR-403, US-104

**Given**: `PromotionExamResolver`の実装コード（`start_exam`・`advance_turn`・`resolve_outcome`）
**When**: 静的解析および同一入力での複数回呼び出しテストを行う
**Then**: 各`static func`は`Node`非継承の`class_name`配下に定義され、内部で`GameState`/`RngService`への参照や乱数生成を一切持たず、同じ入力に対して常に同じ出力を返す

- [ ] **正常系**: 同一の`ExamState`/`RankMaster`入力に対し3関数すべてが常に同じ結果を返す（決定性） 🔵
- [ ] **異常系**: `GameState.reset_for_test()`を挟んでも`PromotionExamResolver`単体の結果に影響がないこと（`GameState`非依存の確認） 🟡
- [ ] **境界値**: AC-002・AC-003・AC-019の境界値ケースがすべてこの純粋関数性テストの対象に含まれること 🔵

---

## 横断的受入基準

### パフォーマンス（NFR-001）

- [ ] `PromotionExamResolver`の各`static func`がループ・再帰を持たない定数時間相当の処理であることをコードレビューで確認する 🟡

### 信頼性・データ整合性（NFR-101）

- [ ] `RankMaster`が`_rank_masters`に存在しない場合に`start_exam`/`commit_exam_outcome`がクラッシュせず`push_error()`を記録し安全側にフォールバックすることを確認する 🔵
- [ ] `RANK_ORDER`に現在ランクIDが含まれない場合の次ランク決定ロジックのフォールバック動作を確認する 🟡

### 保守性（NFR-201, NFR-202）

- [ ] 新規テスト専用API（`_set_exam_state_for_test`等）が`GameStateTestSupport`への1行委譲パターンに従っていることをコードレビューで確認する 🟡
- [ ] `PromotionExamResolver`/`ExamState`/`ExamOutcome`の全public `static func`に正常系・異常系・境界値テストが最低1本ずつ存在することを`tests/`配下の一覧で確認する 🔵

---

## テストサマリー

| カテゴリ | 正常系 | 異常系 | 境界値 | 合計 |
|---------|--------|--------|--------|------|
| 機能要件（AC-001〜AC-020） | 20 | 20 | 22 | 62 |
| 非機能要件 | 3 | 2 | 0 | 5 |
| **合計** | 23 | 22 | 22 | 67 |

## 信頼性レベル分布

- 🔵 青信号: 14件 (70%)
- 🟡 黄信号: 6件 (30%)
- 🔴 赤信号: 0件（ユーザーヒアリングで解消済み）
