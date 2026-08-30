# daily-orders 受入基準

## 関連文書

- **要件定義**: [requirements.md](requirements.md)
- **ユーザーストーリー**: [user-stories.md](user-stories.md)

**【信頼性レベル凡例】**:
- 🔵 確実な基準
- 🟡 妥当な推測による基準
- 🔴 AI推論補完（要確認）

**テスト配置方針**: ユニットテストは `atelier/tests/unit/`、統合テストは `atelier/tests/integration/` に配置する（CON-008）。
実行コマンドは `cd atelier` してから `./addons/gdUnit4/runtest.sh -a res://tests/`。

---

## AC-001: [FR-001, FR-002, FR-003] 指定依頼マスターデータのロード 🔵

**関連**: FR-001, FR-002, FR-003, FR-105, US-001

### Given（前提条件）
- `res://data/daily_orders/` に `DailyOrderMaster` の `.tres` が1件以上配置されている
- `MasterDataLoader` に `&"daily_orders"` カテゴリが追加されている

### When（実行条件）
- `MasterDataLoader.load_all(&"daily_orders")` を呼び出す

### Then（期待結果）
- 配置した全 `.tres` が `DailyOrderMaster` として返る
- 各要素の `id` / `condition_type` / `target_recipe_id` / `target_trait` / `match_bonus_multiplier` が `.tres` の記述値と一致する
- `condition_type` は `"item"` または `"trait"` のいずれかである

### テストチェックリスト

- [ ] **正常系**: `load_all(&"daily_orders")` が配置件数と同数の `DailyOrderMaster` を返す 🔵
- [ ] **正常系**: `condition_type == "item"` のエントリは `target_recipe_id` が非空である 🔵
- [ ] **正常系**: `condition_type == "trait"` のエントリは `target_trait` が非空である 🔵
- [ ] **異常系**: `&"daily_orders"` ディレクトリに `RankMaster` 等の他型 `.tres` を置いても結果に含まれない（`_is_allowed_type()`） 🔵
- [ ] **異常系**: 未知のカテゴリ（例 `&"unknown"`）を渡すと空配列を返す（既存契約の非退行） 🔵
- [ ] **境界値**: `res://data/daily_orders/` が空ディレクトリの場合、空配列を返しクラッシュしない 🔵
- [ ] **境界値**: `id` が重複する2件をロードした場合、`push_error()` される（FR-105） 🟡

---

## AC-002: [FR-004, FR-005, FR-006, FR-301, FR-404] 抽選プールの絞り込みと抽選（純粋関数） 🔵

**関連**: FR-004, FR-005, FR-006, FR-301, FR-404, NFR-103, US-002, US-003

### Given（前提条件）
- 抽選ロジックが `features/guild/logic/` 配下の `class_name` 付き `static func` として実装されている
- 全 `DailyOrderMaster` の配列、解禁済みレシピID配列、`traits_unlocked` フラグ、乱数値が引数として渡せる

### When（実行条件）
- 絞り込み関数に「全マスター配列・解禁済みレシピID配列・`traits_unlocked`」を渡す
- 抽選関数に「絞り込み済みプール・`RngService` から払い出した乱数値」を渡す

### Then（期待結果）
- 絞り込み結果には、`condition_type == "item"` かつ `target_recipe_id` が解禁済みレシピIDに含まれるものだけが残る
- 絞り込み結果には、`condition_type == "trait"` は `traits_unlocked == true` の場合のみ残る
- 抽選関数は同じ乱数値に対して常に同じ `DailyOrderMaster` を返す（決定的）
- 抽選関数は `GameState` を参照せず、内部で乱数を生成しない

### テストチェックリスト

- [ ] **正常系**: 解禁済みレシピを対象とする `"item"` エントリが絞り込み結果に含まれる 🔵
- [ ] **正常系**: `traits_unlocked == true` のとき `"trait"` エントリが絞り込み結果に含まれる 🔵
- [ ] **正常系**: 同一の乱数値を2回渡すと同一の `DailyOrderMaster` が返る（決定性） 🔵
- [ ] **正常系**: 異なる乱数値でプール内の異なる要素が選出されうる 🔵
- [ ] **異常系**: 未解禁レシピを対象とする `"item"` エントリが絞り込み結果から除外される 🔵
- [ ] **異常系**: `traits_unlocked == false` のとき `"trait"` エントリがすべて除外される 🔵
- [ ] **異常系**: `condition_type` が `"item"`/`"trait"` 以外の未知値のエントリが除外される（NFR-302） 🟡
- [ ] **異常系**: `target_recipe_id` / `target_trait` が空文字のエントリが除外される（NFR-302） 🟡
- [ ] **境界値**: 全マスター配列が空の場合、絞り込み結果も空になる 🔵
- [ ] **境界値**: 解禁済みレシピID配列が空の場合、`"item"` エントリがすべて除外される 🔵
- [ ] **境界値**: プールが1件のみの場合、どの乱数値でもその1件が返る 🔵
- [ ] **境界値**: 乱数値が範囲の下端・上端の場合でも、プール外のインデックスにアクセスしない 🟡

---

## AC-003: [FR-103, FR-202, FR-203, FR-405] 抽選プールが空のときの扱い 🔵

**関連**: FR-103, FR-202, FR-203, FR-405, NFR-301, US-003, US-004, US-007

### Given（前提条件）
- `GameState.reset_for_test()` 済み
- 絞り込み後の抽選プールが空になる状況（例: Gランク相当で `traits_unlocked == false`、かつ解禁レシピを対象とする `"item"` エントリが1件も存在しない）

### When（実行条件）
- 抽選の適用（初回ロード時 or ターン終了時）が実行される

### Then（期待結果）
- `_current_daily_order` が `null` になる
- `GameState.resolve_daily_order_for_delivery()` が `null` を返す
- 続けて `deliver_pending_products()` を呼んでもエラーにならず、倍率1.0倍で貢献度・報酬が確定する
- フォールバック用の特別な `DailyOrderMaster` は生成されない

### テストチェックリスト

- [ ] **正常系**: プールが空のとき `get_state()["current_daily_order"]` が `null` になる 🔵
- [ ] **正常系**: 指定依頼が `null` の状態で納品しても `DeliveryResult.order_matched` が `false`、倍率1.0倍になる 🔵
- [ ] **異常系**: `res://data/daily_orders/` が空でもゲーム起動〜納品まで例外なく進む（NFR-301） 🔵
- [ ] **異常系**: プールが空でも `push_error()` によるクラッシュや処理中断が発生しない 🔵
- [ ] **境界値**: Gランク（`traits_unlocked == false`）かつ解禁レシピ1件のみで、`"item"` エントリがそのレシピを対象にしない場合、プールが空になる 🔵
- [ ] **境界値**: Gランクで `"trait"` エントリしか存在しない場合、プールが空になる（FR-203） 🔵

---

## AC-004: [FR-008, FR-101] 初回ロード時の抽選 🔵

**関連**: FR-008, FR-101, NFR-002, US-001

### Given（前提条件）
- `GameState.reset_for_test()` 済みで `_current_daily_order == null`
- `res://data/daily_orders/` に達成可能な `DailyOrderMaster` が1件以上存在する

### When（実行条件）
- `GameState.load_daily_order_master_data()`（相当の新規関数）を呼び出す

### Then（期待結果）
- マスターデータがメモリ上にロードされる
- 抽選が1回実行され `_current_daily_order` に非 `null` の `DailyOrderMaster` が設定される
- `MainScene._enter_tree()` からも既存4関数（garden/alchemy/workshop/rank）と同じ経路で呼ばれる

### テストチェックリスト

- [ ] **正常系**: `load_daily_order_master_data()` 呼び出し後、`_current_daily_order` が非 `null` になる 🔵
- [ ] **正常系**: `MainScene` 起動後（`_enter_tree()` 完了時点）に `resolve_daily_order_for_delivery()` が非 `null` を返す 🔵
- [ ] **正常系**: 初回ターン（`current_turn == 1`）の時点で指定依頼が機能している 🔵
- [ ] **異常系**: マスターデータが0件でも `load_daily_order_master_data()` がクラッシュせず `_current_daily_order` は `null` のままになる 🔵
- [ ] **境界値**: `load_daily_order_master_data()` を2回呼んでも、ロード自体は冪等でクラッシュしない 🟡
- [ ] **境界値**: 再抽選はロード済みプールを再利用し、毎ターンの `DirAccess` 走査が発生しない（NFR-002） 🟡

---

## AC-005: [FR-102, FR-303] 通常ターン終了時の再抽選 🔵

**関連**: FR-102, FR-303, NFR-001, US-002

> フック先は `GameState.advance_turn_growth()` の直後に確定した（CON-010）。

### Given（前提条件）
- 指定依頼マスターデータがロード済みで、達成可能なエントリが複数存在する
- `_current_daily_order` に何らかの `DailyOrderMaster` が設定されている

### When（実行条件）
- `GameState.advance_turn_growth()` が実行される

### Then（期待結果）
- 抽選が再実行され `_current_daily_order` が新しい抽選結果で上書きされる
- 抽選は `_process()` ではなくイベント駆動でのみ実行される（NFR-001）

### テストチェックリスト

- [ ] **正常系**: `advance_turn_growth()` の呼び出し後、`_current_daily_order` が再抽選される 🔵
- [ ] **正常系**: `RngService.set_seed()` で乱数を固定すると、ターン終了後の指定依頼が決定的に再現される 🔵
- [ ] **正常系**: 同一の指定依頼が連続ターンで再選出されてもエラーにならない（FR-303） 🟡
- [ ] **異常系**: 再抽選時にプールが空になった（例: 直前に条件が変わった）場合、`_current_daily_order` が `null` に更新される 🔵
- [ ] **境界値**: プールが1件のみの場合、ターンを跨いでも常に同じ指定依頼が設定される 🔵
- [ ] **境界値**: `_process()` 内から抽選が呼ばれていない（コード上の確認） 🟡

---

## AC-006: [FR-007, FR-104, FR-304, FR-407] 指定依頼のUI表示 🟡

**関連**: FR-007, FR-104, FR-304, FR-407, NFR-201, NFR-202, US-005, US-006, US-007, US-008

> 🔴 **具体的な配置・文言は Phase 2 で確定**（CON-011, NFR-201）。
> 本ACは「表示されること」「内容が正しいこと」「更新に追随すること」の3点のみを規定する。

### Given（前提条件）
- `MainScene` が起動し、調合画面が表示されている
- `_current_daily_order` に `condition_type == "item"` の `DailyOrderMaster` が設定されている

### When（実行条件）
- プレイヤーが調合画面を開き、素材を投入する前の状態で画面を見る

### Then（期待結果）
- 現在の指定依頼の対象（レシピ名 or 特性名）が表示されている
- 合致時のボーナス倍率が表示されている
- 素材投入を決める前に確認できる位置にある（NFR-201）
- 指定依頼が更新されたとき、UIが再描画され新しい内容に追随する（FR-104）

### テストチェックリスト

- [ ] **正常系**: `condition_type == "item"` のとき、対象レシピが識別できる内容が表示される 🟡
- [ ] **正常系**: `condition_type == "trait"` のとき、対象特性が識別できる内容が表示される 🟡
- [ ] **正常系**: 合致時のボーナス倍率が表示される 🟡
- [ ] **正常系**: `_set_current_daily_order_for_test()` で指定依頼を差し替えた後に再描画すると、表示が新しい内容へ追随する 🟡
- [ ] **正常系**: 投入内容が指定依頼に合致する場合、プレビューの `order_matched` が `true` になる（FR-304、既存機構） 🔵
- [ ] **異常系**: `_current_daily_order == null` のとき、空欄やエラーではなく「指定依頼なし」と読み取れる表示になる（NFR-202） 🟡
- [ ] **異常系**: 指定依頼の `target_recipe_id` に対応する `RecipeMaster` が見つからない場合でも、UIがクラッシュせず安全側の表示になる 🟡
- [ ] **境界値**: 表示側で `match_bonus_multiplier` を独自に乗算しておらず、最終貢献度・報酬の算出は `DeliveryResolver.resolve()` のみが行う（FR-407 二重乗算防止） 🔵

---

## AC-007: [FR-105, NFR-302] 不正・重複マスターデータの扱い 🟡

**関連**: FR-105, NFR-301, NFR-302

### Given（前提条件）
- `id` が重複する `DailyOrderMaster`、または `condition_type` が未知値・対象フィールドが空文字の `DailyOrderMaster` がプールに含まれる

### When（実行条件）
- マスターデータのロードおよび抽選プールの絞り込みが実行される

### Then（期待結果）
- `id` 重複時は `push_error()` で警告される
- 不正エントリは抽選プールから除外され、抽選結果として選出されない
- いずれの場合もクラッシュせず、残りの正常なエントリで抽選が成立する

### テストチェックリスト

- [ ] **正常系**: 不正エントリ1件と正常エントリ1件が混在する場合、正常エントリのみが抽選される 🟡
- [ ] **異常系**: `condition_type == "unknown"` のエントリが選出されない 🟡
- [ ] **異常系**: `condition_type == "item"` かつ `target_recipe_id == ""` のエントリが選出されない 🟡
- [ ] **異常系**: `condition_type == "trait"` かつ `target_trait == ""` のエントリが選出されない 🟡
- [ ] **境界値**: 全エントリが不正な場合、プールが空になり `_current_daily_order` が `null` になる（AC-003へ合流） 🟡

---

## AC-008: [FR-201, FR-302, FR-402] 昇格試験中の挙動（既存契約の非退行） 🔵

**関連**: FR-201, FR-302, FR-402, US-009

### Given（前提条件）
- `_current_daily_order` に非 `null` の `DailyOrderMaster` が設定されている
- `GameState._set_exam_state_for_test()` により `_in_exam == true` になっている

### When（実行条件）
- `GameState.resolve_daily_order_for_delivery()` を呼び出す / 試験中に納品する / 調合プレビューを再計算する

### Then（期待結果）
- `resolve_daily_order_for_delivery()` が `null` を返す
- 試験中の納品では倍率1.0倍が適用され `order_matched == false` になる
- 調合プレビューも同じく指定合致ボーナスなしで計算され、実際の納品結果と乖離しない

### テストチェックリスト

- [ ] **正常系**: `_in_exam == true` のとき `resolve_daily_order_for_delivery()` が `null` を返す（既存契約の非退行） 🔵
- [ ] **正常系**: 試験終了後（`_in_exam == false`）は再び `_current_daily_order` が返る 🔵
- [ ] **正常系**: 試験中の調合プレビューと実納品結果の倍率が一致する 🔵
- [ ] **異常系**: 本Planの変更後も `resolve_daily_order_for_delivery()` のシグネチャ・戻り値契約が変わっていない 🔵
- [ ] **境界値**: 試験中のターン進行（`advance_exam_turn()`）を実行しても `_current_daily_order` が変化しない（再抽選しない、FR-302） 🔵

---

## AC-009: [FR-202, FR-406] 状態の防御的コピーと納品の成立 🔵

**関連**: FR-202, FR-406, US-004

### Given（前提条件）
- `_current_daily_order` に `DailyOrderMaster` が設定されている

### When（実行条件）
- `GameState.get_state()["current_daily_order"]` を取得し、呼び出し元でフィールドを書き換える

### Then（期待結果）
- 書き換えは複製インスタンスに対して行われ、`GameState` 内部の `_current_daily_order` は変化しない
- 続けて納品しても、書き換え前の値（元の `match_bonus_multiplier` 等）で判定される

### テストチェックリスト

- [ ] **正常系**: `get_state()["current_daily_order"]` が内部インスタンスとは別インスタンス（`clone()` 済み）である 🔵
- [ ] **正常系**: 取得した複製の `match_bonus_multiplier` を書き換えても、次の納品結果に影響しない 🔵
- [ ] **異常系**: `_current_daily_order == null` のとき `get_state()["current_daily_order"]` が `null` を返す（既存契約） 🔵
- [ ] **境界値**: 抽選直後に `get_state()` を呼んでも、抽選結果と同一内容の複製が得られる 🔵

---

## AC-010: [FR-401, FR-402, FR-403] 確定済み資産の非変更 🔵

**関連**: FR-401, FR-402, FR-403, CON-001, CON-002, CON-003

### Given（前提条件）
- 本Planの実装が完了している

### When（実行条件）
- `atelier/features/guild/resources/daily_order_master.gd`、`GameState.resolve_daily_order_for_delivery()`、`atelier/features/guild/logic/delivery_resolver.gd` の差分を確認する

### Then（期待結果）
- `DailyOrderMaster` のフィールド定義・`clone()` に変更がない
- `resolve_daily_order_for_delivery()` の実装（`return null if _in_exam else _current_daily_order`）に変更がない
- `DeliveryResolver.matches_order()` / `resolve()` のロジックに変更がない

### テストチェックリスト

- [ ] **正常系**: guild Plan で作成済みの既存テスト（`DeliveryResolver` / `daily_order_master` 関連）が全件パスし続ける 🔵
- [ ] **正常系**: `git diff` 上で上記3ファイルのロジック行に変更がない 🔵
- [ ] **異常系**: 既存の統合テスト（`test_alchemy_screen.gd` の `_set_current_daily_order_for_test()` を使うケース）が全件パスし続ける 🔵

---

## 横断的受入基準

### パフォーマンス（NFR-001, NFR-002）

- [ ] 抽選処理が `_process()` / `_physics_process()` から呼ばれていない 🔵
- [ ] マスターデータのディスクロードが起動時1回のみで、毎ターンの再抽選ではメモリ上のプールを再利用している 🟡

### 保守性（NFR-101, NFR-102, NFR-103）

- [ ] 絞り込み条件の判定式が1箇所（`logic/` の純粋関数）にのみ存在し、UI層・Application層で再実装されていない 🔵
- [ ] `match_bonus_multiplier` 等のバランス数値が `GameBalance` 定数を参照しており、`.tres`・コードに数値が直書きされていない 🔵
- [ ] 抽選ロジックのユニットテストが `RngService` を `mock()` せず、乱数値を引数で直接渡す形で書かれている 🔵
- [ ] `gdlint atelier/features/ atelier/shared/ atelier/autoload/` が警告なしで通る 🔵
- [ ] `gdformat --check atelier/features/ atelier/shared/ atelier/autoload/` がフォーマット崩れなしで通る 🔵

### 信頼性（NFR-301, NFR-302）

- [ ] `res://data/daily_orders/` が空、または全エントリが不正でも、起動〜庭〜調合〜納品〜ターン終了の一巡が例外なく完走する 🔵
- [ ] 不正な `DailyOrderMaster` によるクラッシュが発生しない 🟡

### ユーザビリティ（NFR-201, NFR-202）

- [ ] 指定依頼の表示が、素材投入を決める前に確認できる位置にある 🟡
- [ ] 指定依頼なしの状態が「空欄」ではなく明示的な表示になっている 🟡

---

## テストサマリー

| カテゴリ | 正常系 | 異常系 | 境界値 | 合計 |
|---------|--------|--------|--------|------|
| AC-001（ロード） | 3 | 2 | 2 | 7 |
| AC-002（抽選・絞り込み） | 4 | 4 | 4 | 12 |
| AC-003（プール空） | 2 | 2 | 2 | 6 |
| AC-004（初回抽選） | 3 | 1 | 2 | 6 |
| AC-005（再抽選） | 3 | 1 | 2 | 6 |
| AC-006（UI表示） | 5 | 2 | 1 | 8 |
| AC-007（不正データ） | 1 | 3 | 1 | 5 |
| AC-008（試験中） | 3 | 1 | 1 | 5 |
| AC-009（防御的コピー） | 2 | 1 | 1 | 4 |
| AC-010（非変更） | 2 | 1 | 0 | 3 |
| **機能要件 小計** | **28** | **18** | **16** | **62** |
| 横断的（非機能要件） | - | - | - | 11 |
| **合計** | **28** | **18** | **16** | **73** |

## 信頼性レベル分布

AC単位（10件）:

- 🔵 青信号: 8件 (80%) — AC-001, AC-002, AC-003, AC-004, AC-005, AC-008, AC-009, AC-010
- 🟡 黄信号: 2件 (20%) — AC-006, AC-007
- 🔴 赤信号: 0件

テストチェックリスト項目単位（73件）:

- 🔵 青信号: 47件 (64%)
- 🟡 黄信号: 26件 (36%)
- 🔴 赤信号: 0件 (0%)

> フック先（CON-010）・試験中再抽選の要否（FR-302）はヒアリングで確定済み。AC-005・AC-008の
> 該当項目は🔵に更新した。残る未確定はUI表示の配置・文言（AC-006関連、CON-011）のみ。
