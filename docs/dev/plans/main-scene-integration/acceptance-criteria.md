# main-scene-integration 受入基準

## 関連文書

- **要件定義**: [requirements.md](requirements.md)
- **ユーザーストーリー**: [user-stories.md](user-stories.md)

**【信頼性レベル凡例】**:
- 🔵 確実な基準
- 🟡 妥当な推測による基準
- 🔴 AI推論補完（要確認）

**【テスト実行前提】**: すべての GdUnit4 テストは `cd atelier && ./addons/gdUnit4/runtest.sh -a res://tests/` で実行する。統合テストは `atelier/tests/integration/` 配下に配置し、`before_test()` で `GameState.reset_for_test()` を呼んでテスト間の状態を分離する。Autoload を監視する場合は必ず `monitor_signals(GameState, false)` と第2引数を明示する。

---

## AC-001: [FR-001, FR-103] 4画面の常駐と排他表示 🔵

**関連**: FR-001, FR-103, US-001

### Given（前提条件）
- `scenes/main.tscn` が `scene_runner()` でロードされている
- `GameState.reset_for_test()` 実行済みで、初期フェーズが `&"garden"` である

### When（実行条件）
- MainScene の `_ready()` が完了する

### Then（期待結果）
- GardenScreen / AlchemyScreen / WorkshopScreen / ResultScreen の4ノードがすべてシーンツリーに存在する
- `GardenScreen.visible == true`、他3画面は `visible == false` である
- いずれの画面も `queue_free()` されておらず、以降のフェーズ切替で再インスタンス化されない

### テストチェックリスト

- [ ] **正常系**: `_ready()` 直後に4画面が存在し、GardenScreen のみ可視である 🔵
- [ ] **正常系**: `set_phase(&"alchemy")` 後、AlchemyScreen のみ可視で他3画面が不可視である 🔵
- [ ] **異常系**: 未知のフェーズ値（例 `&"unknown"`）を `set_phase()` した場合、いずれの画面も表示を破壊せず（4画面のうち高々1つのみ可視の不変条件を維持し）警告を出す 🟡
- [ ] **境界値**: 同一フェーズへ連続で `set_phase()` した場合も可視状態が変化しない（冪等） 🟡

---

## AC-002: [FR-002, FR-114] RankHud の常時表示と更新 🔵

**関連**: FR-002, FR-114, NFR-202, US-002

### Given（前提条件）
- MainScene がロードされ、ランクマスターが `_set_rank_masters_for_test()` で投入されている
- 所持ゴールドが初期値である

### When（実行条件）
- `GameState.add_gold(100)` 相当の操作によって `gold_changed` が発行される
- フェーズを garden → alchemy → workshop → result と順に切り替える

### Then（期待結果）
- RankHud の4要素（ランク名 / ノルマ残量バー / 残ターン / 所持ゴールド）がすべてのフェーズで `visible == true` を維持する
- ゴールド表示が `gold_changed` 受信後に最新値へ更新される
- ランク名は `GameState.get_current_rank_master().display_name` に、ノルマ残量バーは `rank_state.quota` / `RankMaster.quota_max` に一致する

### テストチェックリスト

- [ ] **正常系**: 4フェーズすべてで RankHud が可視である 🔵
- [ ] **正常系**: `gold_changed` 受信で所持ゴールド表示が更新される 🔵
- [ ] **正常系**: `turn_growth_advanced` 受信で残ターン表示が更新される 🟡
- [ ] **異常系**: 現在ランクの `RankMaster` が未登録の場合、フォールバック値（ノルマ0・制限ターン0）で描画しクラッシュしない 🟡
- [ ] **境界値**: `quota <= 0`（ノルマ達成）でバーが0%表示になり、負値でも下限0%にクランプされる 🟡
- [ ] **正常系**: RankHud の色・角丸・フォントサイズがすべて `UiTheme` 定数経由で指定されている（`Color("#...")` 直書きが grep で0件） 🔵

---

## AC-003: [FR-003, FR-101, FR-102] タブバーによる庭⇔調合切替 🔵

**関連**: FR-003, FR-101, FR-102, NFR-201, US-001

### Given（前提条件）
- MainScene がロードされ、フェーズが `&"garden"` である

### When（実行条件）
- タブバーの「調合」ボタンを押下する
- 続けてタブバーの「庭」ボタンを押下する

### Then（期待結果）
- 「調合」押下で `GameState.set_phase(&"alchemy")` が呼ばれ `phase_changed(&"garden", &"alchemy")` が発行され、AlchemyScreen のみ可視になる
- 「庭」押下で `phase_changed(&"alchemy", &"garden")` が発行され、GardenScreen のみ可視になる
- `GardenScreen` / `AlchemyScreen` のスクリプトにタブ切替用 signal が追加されていない（両者の `signal` 宣言が `shop_requested` のみのまま）
- 選択中のタブが視覚的に強調表示される（NFR-201）

### テストチェックリスト

- [ ] **正常系**: 調合タブ押下で `phase_changed` が `&"alchemy"` を伴って発行される 🔵
- [ ] **正常系**: 庭タブ押下で `phase_changed` が `&"garden"` を伴って発行される 🔵
- [ ] **正常系**: `garden_screen.gd` / `alchemy_screen.gd` の `signal` 宣言が既存分から増えていない（`delivery_confirmed` を除く） 🔵
- [ ] **境界値**: 現在表示中のタブを再度押下しても `phase_changed` の発行が表示状態を壊さない 🟡

---

## AC-004: [FR-004] 表示フェーズと GameState の一致 🟡

**関連**: FR-004, FR-103, US-001

**Given** MainScene がロードされている / **When** タブバー経由・signal 経由の両方でフェーズを複数回切り替える / **Then** 任意の時点で `GameState.get_state()["current_phase"]` に対応する画面がちょうど1つだけ `visible == true` であり、MainScene は独自のフェーズ変数を `GameState` と二重に保持していない（FR-105 のための「工房を開く直前のフェーズ」の記録のみ例外として許容する）。

### テストチェックリスト

- [ ] **正常系**: garden → alchemy → workshop → garden の遷移後、各時点で `current_phase` と可視画面が一致する 🟡
- [ ] **異常系**: MainScene 外から直接 `GameState.set_phase()` を呼んでも表示が追随する 🔵
- [ ] **境界値**: 可視画面数が常に 0 または 1 であり、2つ以上同時に可視にならない 🟡

---

## AC-005: [FR-005] signal 購読の確実な解除 🔵

**関連**: FR-005, US-005

**Given** MainScene がロードされ `GameState` の各 signal へ購読済みである / **When** MainScene を `queue_free()` し `_exit_tree()` を通過させる / **Then** 購読していた全 signal について `is_connected()` が `false` になり、解除処理はすべて `if GameState.<signal>.is_connected(<handler>):` のガード付きで行われている。

### テストチェックリスト

- [ ] **正常系**: `_exit_tree()` 後に購読対象の全 signal が未接続になる 🔵
- [ ] **異常系**: MainScene を2回連続で解放しても `disconnect()` がエラーを出さない（ガードが機能する） 🟡
- [ ] **境界値**: `_ready()` 後すぐに `queue_free()` した場合も解除処理が完走する 🟡

---

## AC-006: [FR-006] 起動時のマスターデータロード 🔵

**関連**: FR-006, US-006

### Given（前提条件）
- `GameState.reset_for_test()` 実行直後で、種・レシピ・強化項目のマスターが未ロードである

### When（実行条件）
- `scene_runner("res://scenes/main.tscn")` で MainScene をロードする

### Then（期待結果）
- `GameState.get_state()["seed_masters"]` / `["recipe_masters"]` / `["upgrade_masters"]` がいずれも空でない
- GardenScreen の種一覧・AlchemyScreen のレシピ一覧・WorkshopScreen の強化項目一覧が実データで描画される

### テストチェックリスト

- [ ] **正常系**: MainScene ロード後に4種のマスター（garden/alchemy/workshop/rank）がすべてロード済みである 🔵
- [ ] **異常系**: マスターデータのロードを複数回行っても件数が重複増加しない（既存の `load_alchemy_master_data()` の冪等性に依存） 🔵
- [ ] **境界値**: `data/` 配下に該当ファイルが1件も無いカテゴリでも、警告を出すのみでクラッシュしない 🟡
- [ ] **正常系**: 新規実装する `load_rank_master_data()` により、G〜Sランク分の `RankMaster`（最小限の仮値）が `GameState.get_state()["rank_masters"]` 相当へロードされる 🔵

> 🔵 **確定**: ロード責務は MainScene に確定（2ラウンド目AskUserQuestion）。BootScene は変更しない。`load_rank_master_data()` は本Planで新規実装し、既存3関数と同型のパターンに従う。

---

## AC-007: [FR-104, FR-105] 工房への往復 🔵

**関連**: FR-104, FR-105, US-003

**Given** MainScene がロードされフェーズが `&"alchemy"` である / **When** AlchemyScreen のショップボタンを押下し `shop_requested` を発行させ、続けて WorkshopScreen の閉じるボタンを押下し `screen_closed` を発行させる / **Then** `shop_requested` 受信で `set_phase(&"workshop")` が呼ばれ WorkshopScreen のみ可視になり、`screen_closed` 受信で工房を開く直前のフェーズ（この場合 `&"alchemy"`）へ復帰する。

### テストチェックリスト

- [ ] **正常系**: garden から工房を開き、閉じたら garden に戻る 🔵
- [ ] **正常系**: alchemy から工房を開き、閉じたら alchemy に戻る 🔵
- [ ] **異常系**: 直前フェーズの記録がない状態（試験合格による自動表示直後など）で `screen_closed` を受けた場合、既定の `&"garden"` へ復帰する 🟡
- [ ] **境界値**: 工房表示中に再度 `shop_requested` を受けても、直前フェーズの記録が workshop に上書きされない 🟡

---

## AC-008: [FR-106, FR-107, FR-402] 納品結果確認後の庭復帰 🔵

**関連**: FR-106, FR-107, FR-402, US-102

### Given（前提条件）
- MainScene がロードされ、フェーズが `&"alchemy"` である
- 納品が実行され GuildDeliveryScreen に結果が表示されている

### When（実行条件）
- GuildDeliveryScreen の「続ける」ボタンを押下し `screen_closed` を発行させる

### Then（期待結果）
- AlchemyScreen が `screen_closed` を購読し `delivery_confirmed` を発行する
- MainScene が `delivery_confirmed` を受信し `set_phase(&"garden")` を呼ぶ
- GardenScreen のみ可視になる
- `main.gd` に `GuildDeliveryScreen` 型・`%GuildDeliveryScreen` ノードパスへの参照が一切存在しない（FR-402）

### テストチェックリスト

- [ ] **正常系**: 「続ける」押下 → `delivery_confirmed` 発行 → 庭画面表示、の連鎖が成立する 🔵
- [ ] **正常系**: `main.gd` の grep で `GuildDeliveryScreen` が0件である 🔵
- [ ] **異常系**: 納品結果が未表示の状態で `delivery_confirmed` を強制発行しても庭へ遷移するのみでクラッシュしない 🟡
- [ ] **境界値**: 「続ける」を短時間に2回押下しても `set_phase(&"garden")` が冪等に扱われる 🟡

---

## AC-009: [FR-108] 昇格試験開始時の調合フェーズ切替 🟡

**関連**: FR-108, US-201

**Given** MainScene がロードされフェーズが `&"garden"` である / **When** ランク判定が PROMOTION_ELIGIBLE となり `_start_exam()` が走って `GameState.exam_started` が発行される / **Then** MainScene が alchemy フェーズへ切り替えて AlchemyScreen のみ可視になり、AlchemyScreen が既存実装どおり試験モードUI（残りターン表示・「ターンを進める」ボタン）を表示する。

### テストチェックリスト

- [ ] **正常系**: `exam_started` 受信で alchemy フェーズへ切り替わる 🟡
- [ ] **正常系**: 既に alchemy フェーズにいる状態で `exam_started` を受けても表示が壊れない 🟡
- [ ] **異常系**: workshop フェーズ表示中に `exam_started` を受けた場合も alchemy へ切り替わる 🟡

---

## AC-010: [FR-109, FR-110] 昇格試験の合否による分岐 🔵

**関連**: FR-109, FR-110, US-202, US-203

### Given（前提条件）
- MainScene がロードされ、`in_exam == true` の昇格試験中である
- 現在ランクが最終ランクではなく、連続降格回数がゲームオーバー閾値未満である

### When（実行条件）
- ケースA: 試験ノルマを達成し `exam_outcome_confirmed(SUCCESS)` が発行される
- ケースB: 制限ターンに到達し `exam_outcome_confirmed(FAILURE)` が発行される

### Then（期待結果）
- ケースA: workshop フェーズへ切り替わり WorkshopScreen のみ可視になる。`can_purchase_permanent == true` が既に `GameState` 側でセット済みのため、WorkshopScreen は無改修で恒久投資タブが活性化した状態になる
- ケースB: garden フェーズへ切り替わり GardenScreen のみ可視になる

### テストチェックリスト

- [ ] **正常系**: SUCCESS（非最終ランク・`game_cleared` 発行なし）で工房強化画面が表示される 🔵
- [ ] **正常系**: SUCCESS 直後の `GameState.get_state()["can_purchase_permanent"] == true` である 🔵
- [ ] **正常系**: FAILURE（`game_over` 発行なし）で庭画面が表示される 🔵
- [ ] **異常系**: `exam_outcome_confirmed(CONTINUE)` を受信した場合、フェーズを変更しない 🟡
- [ ] **境界値**: FAILURE かつ連続降格回数がゲームオーバー閾値の「1つ手前」の場合、庭画面へ戻る（Result にしない） 🟡

---

## AC-011: [FR-111, FR-112, FR-403] ゲームクリア／ゲームオーバー画面の表示 🔵

**関連**: FR-111, FR-112, FR-403, US-204, US-205

**Given** MainScene がロードされている / **When** ケースA `GameState.game_cleared` が発行される、ケースB `GameState.game_over(demotion_count)` が発行される / **Then** いずれも result フェーズへ切り替わり ResultScreen のみ可視になる。ResultScreen は自身が両 signal を購読しているためケースAでクリア表示、ケースBでゲームオーバー表示に排他的に切り替わる。以降 MainScene は自動的に garden / alchemy / workshop へ復帰しない（FR-403）。

### テストチェックリスト

- [ ] **正常系**: `game_cleared` 受信で ResultScreen が可視になりクリア表示になる 🔵
- [ ] **正常系**: `game_over` 受信で ResultScreen が可視になりゲームオーバー表示になる 🔵
- [ ] **異常系**: ResultScreen 表示後に `phase_changed` 以外の signal（`gold_changed` 等）を受けても result フェーズが維持される 🟡
- [ ] **境界値**: `game_over` が冪等ガードにより2回発行されないこと、および万一2回受信しても表示が壊れないこと 🟡

---

## AC-012: [FR-113] 試験結果確定時の signal 連続発行と最終画面の上書き 🔵

**関連**: FR-113, FR-109, FR-110, FR-111, FR-112, US-204, US-205

### Given（前提条件）
- MainScene がロードされ、`in_exam == true` である
- ケースA: 現在ランクが真の最終ランク（`RankProgression.is_true_final_rank()` が真）である
- ケースB: 連続降格回数がゲームオーバー閾値の直前で、試験に不合格となる状況である

### When（実行条件）
- `GameState.commit_exam_outcome()` を1回呼び出す

### Then（期待結果）
- ケースA: `exam_outcome_confirmed(SUCCESS)` → `game_cleared` の順に2回 signal が発行される。MainScene は FR-109 でいったん workshop フェーズへ暫定遷移した後、FR-111 により result フェーズへ上書きされ、**最終的に ResultScreen（CLEAR）のみが可視**になる
- ケースB: `exam_outcome_confirmed(FAILURE)` → `game_over(demotion_count)` の順に2回発行される。MainScene は FR-110 でいったん garden へ暫定遷移した後、FR-112 により result フェーズへ上書きされ、**最終的に ResultScreen（OVER）のみが可視**になる
- 両ケースとも同一フレーム内の同期呼び出しであるため、中間状態（workshop / garden）がプレイヤーに描画されることはない

### テストチェックリスト

- [ ] **正常系（ケースA）**: `monitor_signals(GameState, false)` で `exam_outcome_confirmed` と `game_cleared` の**両方**が発行されたことを検証する 🔵
- [ ] **正常系（ケースA）**: `commit_exam_outcome()` 呼び出し完了後の可視画面が ResultScreen ただ1つである（WorkshopScreen が `visible == false` である） 🔵
- [ ] **正常系（ケースB）**: `exam_outcome_confirmed` と `game_over` の両方が発行され、最終的な可視画面が ResultScreen ただ1つである（GardenScreen が `visible == false` である） 🔵
- [ ] **境界値（発行順序）**: `exam_outcome_confirmed` のハンドラ内で `GameState.get_state()` を読んだ時点で、`current_rank_id` / `can_purchase_permanent` / `demotion_count` が既に更新後の値になっている（`commit_exam_outcome()` の「状態更新を signal 発行より先に完了させる」規約の検証） 🔵
- [ ] **異常系**: 既にゲームクリア／ゲームオーバー確定済みの状態で `commit_exam_outcome()` を再度呼んだ場合、signal が再発行されず（冪等ガード）画面も変化しない 🔵
- [ ] **境界値**: SUCCESS だが `game_cleared` が発行されないケース（非最終ランク）で、workshop フェーズのまま result へ上書きされないことを確認する 🔵

---

## AC-013: [FR-115, FR-116] ランク判定・試験合否の確定呼び出し 🔵

**関連**: FR-115, FR-116, US-103, US-201, US-202

### Given（前提条件）
- MainScene がロードされ、ランクマスターが投入されている
- 通常ターン中で、当該ランクのノルマ達成条件を満たす納品が可能な状態である

### When（実行条件）
- ケースA: 通常ターンの納品を完了させる
- ケースB: 昇格試験中にターンを進行させる

### Then（期待結果）
- ケースA: `GameState.commit_rank_outcome()` が呼ばれ、条件を満たす場合に `exam_started` または `game_over` が発行される
- ケースB: `GameState.commit_exam_outcome()` が呼ばれ、`exam_outcome_confirmed` が発行される

### テストチェックリスト

- [ ] **正常系**: 納品完了後に `rank_outcome_confirmed` が発行される 🔵
- [ ] **正常系**: ノルマ達成状態で納品を完了させると `exam_started` が発行され試験が開始される 🔵
- [ ] **正常系**: 試験中のターン進行後に `exam_outcome_confirmed` が発行される 🔵
- [ ] **異常系**: `in_exam == false` の状態でケースBの経路を通っても `not_in_exam` の失敗 `Result` を握り潰さずクラッシュしない 🟡
- [ ] **境界値**: ゲームオーバー／ゲームクリア確定後に再度確定呼び出しを行っても、冪等ガードにより状態も画面も変化しない 🔵

> 🔵 **確定**: `commit_rank_outcome()` / `commit_exam_outcome()` の呼び出しをスコープに含めることが確定（2ラウンド目AskUserQuestion）。呼び出し主体は AlchemyScreen の既存ターン終了系ハンドラの延長（CON-003の改修許容範囲内）を軸に、Phase 2設計で確定する。

---

## AC-014: [FR-201, FR-202] 試験中・終局時のタブバー操作制限 🟡

**関連**: FR-201, FR-202, US-201, US-204, US-205

### Given（前提条件）
- MainScene がロードされている

### When（実行条件）
- ケースA: `exam_started` が発行され `in_exam == true` になる
- ケースB: `game_cleared` または `game_over` が発行され result フェーズになる

### Then（期待結果）
- ケースA: タブバーの「庭」ボタンが `disabled == true` になる
- ケースB: タブバーの両ボタンが `disabled == true` になる
- ケースA の試験終了後（`exam_outcome_confirmed` 受信で `in_exam == false` に戻った時点）、庭ボタンの `disabled` が解除される

### テストチェックリスト

- [ ] **正常系**: `exam_started` 後に庭タブが押下不能になる 🟡
- [ ] **正常系**: 試験終了（SUCCESS / FAILURE いずれも）後に庭タブが再び押下可能になる 🟡
- [ ] **正常系**: result フェーズで両タブが押下不能になる 🟡
- [ ] **異常系**: 試験中に庭タブを強制的に押下（`emit_signal("pressed")`）してもフェーズが変化しない 🟡
- [ ] **境界値**: 試験終了と同時に `game_over` が発行された場合、庭タブの解除より result フェーズの無効化が優先され、最終的に両タブが押下不能である 🟡

---

## AC-015: [FR-203] ギルド納品オーバーレイの条件付き表示 🔵

**関連**: FR-203, US-101

### Given（前提条件）
- MainScene がロードされ、alchemy フェーズを表示している
- まだ一度も納品を実行していない

### When（実行条件）
- ケースA: 何も操作しない
- ケースB: 納品を実行し `display_results(products, results)` が呼ばれる
- ケースC: 「続ける」を押下し `screen_closed` が発行される

### Then（期待結果）
- ケースA: GuildDeliveryScreen が `visible == false` である
- ケースB: GuildDeliveryScreen が `visible == true` になり結果が表示される
- ケースC: GuildDeliveryScreen が `visible == false` に戻る

### テストチェックリスト

- [ ] **正常系**: 調合画面の初期表示時に GuildDeliveryScreen が不可視である（既存の常時表示バグの回帰テスト） 🔵
- [ ] **正常系**: `display_results()` 呼び出しで可視になる 🔵
- [ ] **正常系**: 「続ける」押下で不可視に戻る 🔵
- [ ] **異常系**: 空の結果配列で `display_results([], [])` を呼んだ場合の挙動が定義どおりである（表示するか不可視のままかを実装時に確定し、テストで固定する） 🟡
- [ ] **境界値**: 試験中の自動納品（`_deliver_and_display()` 経由）でも同じ可視制御が働く 🔵

---

## AC-016: [FR-301, FR-302] 任意要件の扱い 🟡

**関連**: FR-301, FR-302, US-002, US-004

**Given** MainScene が実装完了している / **When** フェーズを切り替える、または RankHud のノルマバーを目視する / **Then** トランジション演出・ノルマ数値併記は実装の有無を問わず受入可とする。実装する場合、演出は `create_tween()` を用いノード破棄時に自動停止する範囲に留める（ノード跨ぎの `Tween` 保持は行わない）。

### テストチェックリスト

- [ ] **正常系**: トランジション演出を実装した場合、演出中でも `visible` の最終状態が FR-103 の期待どおりに収束する 🟡
- [ ] **正常系**: ノルマ数値を併記した場合、`quota` / `quota_max` の表記がバー表示と矛盾しない 🟡

---

## AC-017: [FR-401, FR-402, FR-404, FR-405, FR-406] アーキテクチャ規約とスコープ境界の遵守 🔵

**関連**: FR-401, FR-402, FR-404, FR-405, FR-406, US-302, US-401

### Given（前提条件）
- 本Planの実装が完了しコミット候補になっている

### When（実行条件）
- 静的検証（grep / `gdlint` / `gdformat --check`）を実施する

### Then（期待結果）
- `main.gd` に他Feature の `state/` 型への直接参照・書き込みが存在しない
- `main.gd` に `GuildDeliveryScreen` への参照が存在しない
- `autoload/game_state.gd` の `signal` 宣言が本Plan着手前から増えていない
- `workshop_screen.gd` に確認ダイアログ関連のコードが追加されていない
- `alchemy_screen.tscn` の `%GuildDeliveryScreen` 埋め込み構造が維持されている（別Feature への分離が行われていない）

### テストチェックリスト

- [ ] **正常系**: `Grep: pattern="GuildDeliveryScreen", path="atelier/scenes/main.gd"` が0件 🔵
- [ ] **正常系**: `autoload/game_state.gd` の `^signal ` 行数が着手前と同数である 🔵
- [ ] **正常系**: `gdlint atelier/features/ atelier/shared/ atelier/autoload/ atelier/scenes/` が警告0件 🔵
- [ ] **正常系**: `gdformat --check` でフォーマット崩れ0件 🔵
- [ ] **正常系**: `main.gd` が300行以内である（超過時は RankHud / タブバーを独立コンポーネントへ分割済み、CON-004） 🟡
- [ ] **異常系**: `main.gd` に `_process()` が定義されていない（NFR-002） 🟡

---

## 横断的受入基準

### AC-018: 5画面横断の通しプレイ結合シナリオ（本Planの受入の中核） 🔵

**関連**: NFR-301, NFR-302, NFR-001, US-301、および FR-001〜FR-116 の統合検証

`atelier/tests/integration/` 配下に `scene_runner("res://scenes/main.tscn")` ベースの GdUnit4 統合テストを実装し、以下のシナリオを1本ないし複数本のテストとして自動検証する。`before_test()` で `GameState.reset_for_test()` を呼び、ランクマスターは `_set_rank_masters_for_test()` で投入する。

#### シナリオ1: 通常ターンの1周（ハッピーパス）

```
Given: main.tscn ロード直後（garden フェーズ、マスターデータ投入済み）
When:  庭で種を植える → 収穫する → タブで調合へ切替 → レシピ選択 → 素材投入
       → 調合を実行する → ターンを終了する（納品）
       → ギルド納品オーバーレイの「続ける」を押下
Then:  庭フェーズに復帰し、GardenScreen のみが可視である
       RankHud のゴールド表示が納品報酬分だけ増加している
```

#### シナリオ2: 工房への往復（ターン中いつでも）

```
Given: シナリオ1の途中（alchemy フェーズ）
When:  ショップボタン押下 → 工房強化画面で閉じるボタン押下
Then:  alchemy フェーズへ復帰し、AlchemyScreen のみが可視である
```

#### シナリオ3: 昇格試験の開始から合格まで

```
Given: ランクノルマ達成条件を満たすようマスターと状態を構成した通常ターン
When:  納品を完了しランク判定を確定させる（exam_started 発行）
       → 試験中に調合／ターン進行を行い試験ノルマを達成
       → 試験合否を確定させる（exam_outcome_confirmed(SUCCESS) 発行）
Then:  非最終ランクの場合、WorkshopScreen のみが可視で can_purchase_permanent == true
       最終ランクの場合、game_cleared も続けて発行され ResultScreen のみが可視（AC-012 ケースA）
```

#### シナリオ4: 昇格試験の不合格

```
Given: 試験中（in_exam == true）
When:  制限ターンに到達し試験合否を確定させる（exam_outcome_confirmed(FAILURE) 発行）
Then:  ゲームオーバー閾値未満なら GardenScreen のみが可視
       閾値到達なら game_over も続けて発行され ResultScreen のみが可視（AC-012 ケースB）
```

#### 横断チェックリスト

- [ ] **正常系**: シナリオ1が完走し、最終状態が garden フェーズである 🔵
- [ ] **正常系**: シナリオ2が完走し、直前フェーズへ正しく復帰する 🔵
- [ ] **正常系**: シナリオ3（非最終ランク）が完走し WorkshopScreen が可視である 🔵
- [ ] **正常系**: シナリオ3（最終ランク）が完走し ResultScreen が可視である 🔵
- [ ] **正常系**: シナリオ4（両分岐）が完走する 🔵
- [ ] **正常系**: すべてのシナリオで `GameState` を監視する際に `monitor_signals(GameState, false)` を用いている（第2引数省略が grep で0件、NFR-302） 🔵
- [ ] **正常系**: 全シナリオを通じてフェーズ切替が `visible` 切替のみで行われ、`change_scene_to_file()` が一度も呼ばれない（NFR-001） 🔵
- [ ] **異常系**: 各シナリオ実行中に `push_error()` による想定外エラーが出力されない 🟡
- [ ] **境界値**: シナリオを連続実行してもテスト間で状態が漏れない（`reset_for_test()` による分離） 🔵

### パフォーマンス（NFR-001, NFR-002）

- [ ] フェーズ切替時に画面ノードが `queue_free()` / 再 `instantiate()` されていない 🔵
- [ ] `main.gd` に `_process()` / `_physics_process()` が定義されていない 🟡

### セキュリティ（NFR-101）

- [ ] 本Planに固有のセキュリティ検証項目はない（オフライン単体アプリ、外部入力・ネットワーク通信・機密情報を扱わない） 🔵

### ユーザビリティ（NFR-201, NFR-202）

- [ ] 選択中タブが非選択タブと視覚的に区別できる 🟡
- [ ] RankHud・タブバーの見た目の値がすべて `UiTheme` 定数経由である（色のハードコードが grep で0件） 🔵

---

## テストサマリー

| カテゴリ | 正常系 | 異常系 | 境界値 | 合計 |
|---------|--------|--------|--------|------|
| 機能要件（AC-001〜AC-017） | 38 | 12 | 16 | 66 |
| 横断シナリオ（AC-018） | 7 | 1 | 1 | 9 |
| 非機能要件（横断的受入基準） | 5 | 0 | 0 | 5 |
| **合計** | **50** | **13** | **17** | **80** |

## 信頼性レベル分布

> 🔵 2026-08-26追記: 初版で🔴だった AC-006 / AC-013 は、2ラウンド目のAskUserQuestionでスコープに含めることが確定したため🔵へ更新した。

| レベル | 件数（受入基準単位） |
|-------|------------------|
| 🔵 青信号 | 14件（AC-001, 002, 003, 005, 006, 007, 008, 010, 011, 012, 013, 015, 017, 018） |
| 🟡 黄信号 | 4件（AC-004, 009, 014, 016） |
| 🔴 赤信号 | 0件 |
| **合計** | **18件** |

- 🔵 青信号: 14件 (77.8%)
- 🟡 黄信号: 4件 (22.2%)
- 🔴 赤信号: 0件
