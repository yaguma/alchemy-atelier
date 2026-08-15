# guild 受入基準

## 関連文書

- **要件定義**: [requirements.md](requirements.md)
- **ユーザーストーリー**: [user-stories.md](user-stories.md)

**【信頼性レベル凡例】**:
- 🔵 確実な基準
- 🟡 妥当な推測による基準
- 🔴 AI推論補完（要確認）

---

## AC-001: [FR-101] condition_type="item"の品目合致判定 🔵

**関連**: FR-101, US-001

### Given（前提条件）
- `condition_type = "item"`・`target_recipe_id = "recipe_healing_potion"`の`DailyOrderMaster`フィクスチャ
- `recipe_id = &"recipe_healing_potion"`の`ProductInstance`

### When（実行条件）
- `DeliveryResolver.matches_order(product, daily_order)`を呼び出す

### Then（期待結果）
- `product.recipe_id == daily_order.target_recipe_id`の比較結果として`true`が返る
- `activated_traits`の内容は判定に影響しない

### テストチェックリスト

- [ ] **正常系**: `recipe_id`が`target_recipe_id`と一致 → `true` 🔵
- [ ] **正常系**: `recipe_id`が`target_recipe_id`と不一致（別レシピ） → `false` 🔵
- [ ] **異常系**: `condition_type = "item"`だが`target_recipe_id`が空文字の指定 → `false`を返しクラッシュしない 🟡
- [ ] **境界値**: `target_trait`に値が入っていても`condition_type = "item"`なら特性は判定に使われない 🟡

---

## AC-002: [FR-102] condition_type="trait"の特性合致判定 🔵

**関連**: FR-102, US-002

### Given（前提条件）
- `condition_type = "trait"`・`target_trait = "holy"`の`DailyOrderMaster`フィクスチャ
- `activated_traits = [&"holy", &"gold"]`の`ProductInstance`

### When（実行条件）
- `DeliveryResolver.matches_order(product, daily_order)`を呼び出す

### Then（期待結果）
- `product.activated_traits.has(daily_order.target_trait)`の結果として`true`が返る
- `recipe_id`の内容は判定に影響しない

### テストチェックリスト

- [ ] **正常系**: `activated_traits`に`target_trait`が含まれる → `true` 🔵
- [ ] **正常系**: `activated_traits`に`target_trait`が含まれない → `false` 🔵
- [ ] **異常系**: `target_trait`が空文字の指定 → `false`を返しクラッシュしない 🟡
- [ ] **境界値**: `activated_traits`が空配列（特性未発現・Gランク相当） → `false` 🔵
- [ ] **境界値**: `activated_traits`が複数要素でそのうち1つだけ一致 → `true` 🔵

---

## AC-003: [FR-101, FR-201, FR-407] daily_order=nullでの非合致契約 🔵

**関連**: FR-101, FR-201, FR-407, US-007

### Given（前提条件）
- 任意の`ProductInstance`（`condition_type`の両パターンに合致しうる内容でよい）
- `daily_order = null`（昇格試験からの呼び出しを想定）

### When（実行条件）
- `DeliveryResolver.matches_order(product, null)`および`DeliveryResolver.resolve(product, null)`を呼び出す

### Then（期待結果）
- `matches_order`は必ず`false`を返す
- `resolve`は`order_matched = false`・`final_contribution = product.contribution`・`final_reward = product.reward`（倍率1.0）を返す
- いずれの呼び出しでもnullアクセスによるクラッシュが発生しない

### テストチェックリスト

- [ ] **正常系**: `matches_order(product, null)` → `false` 🔵
- [ ] **正常系**: `resolve(product, null)` → `order_matched = false`かつボーナス非適用 🔵
- [ ] **異常系**: `null`を渡してもエンジンエラー（`Invalid get index`等）が発生しない 🔵
- [ ] **境界値**: 品目一致・特性一致それぞれを満たす`ProductInstance`でも`null`指定なら`false`になる 🔵

---

## AC-004: [FR-004, FR-103] 指定合致時のボーナス倍率適用 🔵

**関連**: FR-004, FR-103, US-001, US-002

### Given（前提条件）
- 合致する`DailyOrderMaster`フィクスチャ（`match_bonus_multiplier = 1.3`、`GameBalance.DAILY_ORDER_MATCH_BONUS_MULTIPLIER`と同値）
- `contribution = 10.0`・`reward = 5.0`の`ProductInstance`

### When（実行条件）
- `DeliveryResolver.resolve(product, daily_order)`を呼び出す

### Then（期待結果）
- `order_matched = true`
- `final_contribution = 13.0`（`10.0 × 1.3`）・`final_reward = 6.5`（`5.0 × 1.3`）
- 貢献度・報酬の**両方**に同一の倍率が掛かる

### テストチェックリスト

- [ ] **正常系**: 合致時に`final_contribution`・`final_reward`の双方が1.3倍になる 🔵
- [ ] **正常系**: `match_bonus_multiplier = 1.5`のインスタンスでは1.5倍が適用される（インスタンス値が`GameBalance`定数より優先、CON-006） 🔵
- [ ] **境界値**: `contribution = 0.0`・`reward = 0.0`の`ProductInstance`でも`0.0`のまま（乗算が破綻しない） 🟡

---

## AC-005: [FR-104] 非合致時の倍率1.0 🔵

**関連**: FR-104, US-003

### Given（前提条件）
- 合致しない`DailyOrderMaster`フィクスチャ（`match_bonus_multiplier = 1.3`を保持している）
- `contribution = 10.0`・`reward = 5.0`の`ProductInstance`

### When（実行条件）
- `DeliveryResolver.resolve(product, daily_order)`を呼び出す

### Then（期待結果）
- `order_matched = false`
- `final_contribution = 10.0`・`final_reward = 5.0`（元の値がそのまま返る）

### テストチェックリスト

- [ ] **正常系**: 非合致時に`final_contribution`・`final_reward`が元の値と等しい 🔵
- [ ] **境界値**: `match_bonus_multiplier`に大きい値（例: 3.0）が設定されていても非合致なら一切適用されない 🔵

---

## AC-006: [FR-002] DeliveryResultのフィールド定義 🔵

**関連**: FR-002, US-006

### Given（前提条件）
- `features/guild/logic/delivery_result.gd`の`DeliveryResult`実装

### When（実行条件）
- `DeliveryResolver.resolve`の戻り値を受け取り、各フィールドへアクセスする

### Then（期待結果）
- `final_contribution: float`・`final_reward: float`・`order_matched: bool`の3フィールドをすべて型注釈付きで保持している
- `features/guild/logic/`配下に配置され、他Featureおよび`GameState`から参照可能である

### テストチェックリスト

- [ ] **正常系**: 3フィールドが期待どおりの型・値で読み出せる 🔵
- [ ] **異常系**: 3フィールド以外の状態（内部キャッシュ等）を持たず、同一入力から生成した2つのインスタンスの全フィールドが一致する 🟡

---

## AC-007: [FR-003] DailyOrderMasterのResource型定義 🔵

**関連**: FR-003, US-001, US-002

### Given（前提条件）
- `features/guild/resources/daily_order_master.gd`の`DailyOrderMaster`実装（`Resource`継承）

### When（実行条件）
- テストコード上で`DailyOrderMaster.new()`によりフィクスチャを生成し、各フィールドへ値を設定する（CON-005: `.tres`実データは本plan外）

### Then（期待結果）
- `id: String`・`condition_type: String`・`target_recipe_id: String`・`target_trait: String`・`match_bonus_multiplier: float`の5フィールドを保持している
- `data-schema.md` L170-189のスキーマと一致している

### テストチェックリスト

- [ ] **正常系**: 5フィールドすべてが`data-schema.md`の型どおりに定義されている 🔵
- [ ] **正常系**: `.tres`実データなしでコード上のフィクスチャのみでテストが成立する 🔵
- [ ] **異常系**: `condition_type`が`"item"`/`"trait"`以外の未知値の場合、`matches_order`が`false`を返しクラッシュしない（NFR-101） 🟡

---

## AC-008: [FR-005, FR-105, FR-301] 未納品キューの全件消費 🔴

**関連**: FR-005, FR-105, FR-301, US-004

### Given（前提条件）
- `GameState._pending_products`に`ProductInstance`が3件積まれている状態
- `_current_daily_order`がテスト専用API（FR-301）で設定済み、または`null`のまま

### When（実行条件）
- `GameState.deliver_pending_products()`を呼び出す（CON-009）

### Then（期待結果）
- 3件それぞれについて`DeliveryResolver.resolve`が1回ずつ、キューの先頭から順に呼ばれる
- 処理完了後`_pending_products`が空になる
- 成功の`Result`が返り、`value`に3件分の`DeliveryResult`配列が格納される

### テストチェックリスト

- [ ] **正常系**: 3件投入 → 戻り値の`DeliveryResult`配列が3要素で`_pending_products`が空になる 🔴
- [ ] **正常系**: キュー先頭から順に処理され、戻り値配列の順序が投入順と一致する 🔴
- [ ] **異常系**: 同じ納品処理を連続で2回呼ぶと、2回目は0件成功になる（二重納品されない） 🟡
- [ ] **境界値**: 1件のみのキューでも正常に処理される 🟡

---

## AC-009: [FR-106] final_rewardのゴールド加算と丸め 🔴

**関連**: FR-106, CON-007, US-004

### Given（前提条件）
- `GameState._gold = 0`、`reward = 5.0`の`ProductInstance`1件がキューにあり、`match_bonus_multiplier = 1.3`の指定に合致する状態

### When（実行条件）
- `GameState.deliver_pending_products()`を呼び出す

### Then（期待結果）
- `final_reward = 6.5`が`roundi()`で丸められ、`_gold`が`7`になる（CON-007）
- `get_state().gold`からも同じ値が読み出せる

### テストチェックリスト

- [ ] **正常系**: 複数件の納品で各`final_reward`の丸め値が累積加算される 🔴
- [ ] **異常系**: 加算前の`_gold`が0でない場合も既存値へ正しく加算される（上書きされない） 🟡
- [ ] **境界値**: `final_reward = 6.4` → `+6`、`6.5` → `+7`（四捨五入の境界） 🔴
- [ ] **境界値**: `final_reward = 0.0` → `_gold`が変化しない 🔴

---

## AC-010: [FR-006, FR-107] final_contributionの暫定フィールドへの累積 🔴

**関連**: FR-006, FR-107, US-005, US-011

### Given（前提条件）
- `GameState._accumulated_contribution = 0.0`（初期値）、`contribution = 10.0`の`ProductInstance`がキューにある状態

### When（実行条件）
- `GameState.deliver_pending_products()`を呼び出す

### Then（期待結果）
- `_accumulated_contribution`に`final_contribution`が`float`のまま（丸めずに）加算される
- ランクノルマの減算・降格判定・昇格試験は一切実行されない（FR-404）

### テストチェックリスト

- [ ] **正常系**: 1件納品で`_accumulated_contribution`が`final_contribution`分だけ増える 🔴
- [ ] **正常系**: 納品処理を複数回実行すると値が累積する（リセットされない） 🔴
- [ ] **異常系**: `GameState.reset_for_test()`で`_accumulated_contribution`が`0.0`に戻る 🟡
- [ ] **境界値**: 初期値が`0.0`であることを新規初期化直後に確認する 🔵

---

## AC-011: [FR-108] deliveredシグナルの発行 🔴

**関連**: FR-108, NFR-201, US-006

### Given（前提条件）
- `_pending_products`に2件（1件は指定合致、1件は非合致）が積まれている状態
- GdUnit4の`monitor_signals(GameState, false)`でシグナルを監視（Autoloadのため第2引数`false`必須）

### When（実行条件）
- `GameState.deliver_pending_products()`を呼び出す

### Then（期待結果）
- `delivered(results: Array[DeliveryResult])`シグナルが1回発行される
- `results`は2要素で、`order_matched`が件別に`true`/`false`として正しく設定されている

### テストチェックリスト

- [ ] **正常系**: シグナルが発行され、要素数が納品件数と一致する 🔴
- [ ] **正常系**: 合致件・非合致件の`order_matched`が件別に正しい 🔴
- [ ] **異常系**: 納品0件のときのシグナル発行仕様（空配列で発行する／発行しない）を決めたうえで、その挙動をテストで固定する 🔴

---

## AC-012: [FR-109] 空キューでの安全動作 🟡

**関連**: FR-109, US-009

### Given（前提条件）
- `_pending_products`が空、`_gold`と`_accumulated_contribution`に任意の既存値がある状態

### When（実行条件）
- `GameState.deliver_pending_products()`を呼び出す

### Then（期待結果）
- 成功の`Result`（`value`は空配列）が返る
- `_gold`・`_accumulated_contribution`・`_pending_products`のいずれも変化しない

### テストチェックリスト

- [ ] **正常系**: 空キューで`Result.success == true`かつ`value`が空配列 🟡
- [ ] **異常系**: `_gold`・`_accumulated_contribution`が呼び出し前後で完全に一致する 🟡

---

## AC-013: [FR-001, FR-401, FR-402] Domain層の純粋性・乱数非依存 🔵

**関連**: FR-001, FR-401, FR-402

### Given（前提条件）
- `features/guild/logic/delivery_resolver.gd`の`matches_order`・`resolve`の実装

### When（実行条件）
- 同一引数でユニットテストを複数回実行する、およびコードを静的に検査する

### Then（期待結果）
- いずれの関数も`GameState`等の外部状態を参照せず、常に同じ入力に対して同じ出力を返す
- `logic/`配下で`RandomNumberGenerator`・`RngService`等の乱数生成APIを呼び出していない

### テストチェックリスト

- [ ] **正常系**: 同一引数の`matches_order`・`resolve`呼び出しが常に同じ結果を返す 🔵
- [ ] **異常系**: `features/guild/logic/`配下のソースを`grep`し、乱数生成APIおよび`GameState`への参照がないことを確認する 🔵

---

## AC-014: [FR-103, FR-403] 指定合致ボーナスの適用箇所一元化 🔵

**関連**: FR-103, FR-403, US-008

### Given（前提条件）
- alchemy planで実装済みの`ProductValueCalculator`と、本planの`DeliveryResolver.resolve`

### When（実行条件）
- 調合（`GameState.execute_alchemy`）→ 納品（`GameState.deliver_pending_products`）の一連の統合テストを実行する

### Then（期待結果）
- 指定合致ボーナスは`resolve`の1箇所でのみ適用され、`final_contribution`が`base × quality_mult × trait_bonus × match_bonus`（`match_bonus`は1回だけ）となる
- `ProductInstance.contribution`/`reward`には合致ボーナスが含まれていない

### テストチェックリスト

- [ ] **正常系**: 統合テストで合致ボーナスが1回だけ乗ることを期待値計算と突き合わせて確認する 🔵
- [ ] **異常系**: `ProductValueCalculator.calculate_contribution`/`calculate_reward`のシグネチャに`match_bonus_multiplier`相当の引数が存在しないことをコードで確認する（FR-403） 🔵

---

## AC-015: [FR-408] pending_productsの防御的コピー維持 🔵

**関連**: FR-408, US-010

### Given（前提条件）
- 納品処理の追加後、`GameState`が`_pending_products`に既存データを保持している状態

### When（実行条件）
- 呼び出し元が`GameState.get_state()`の戻り値の`pending_products`（`Array`）に対し`append`/`clear`等の変更操作を行う

### Then（期待結果）
- `GameState`内部の実際の`_pending_products`は変化しない（`clone()`によるディープコピーが機能している）

### テストチェックリスト

- [ ] **正常系**: 戻り値の`pending_products`を変更しても`GameState`内部状態が変化しない 🔵
- [ ] **境界値**: `ProductInstance`が保持するネストした配列（`activated_traits`）まで独立コピーされている 🟡

---

## AC-016: [FR-404, FR-405, FR-406, FR-407] スコープ外機能の非実装確認 🔵

**関連**: FR-404, FR-405, FR-406, FR-407, US-011

### Given（前提条件）
- 本plan完了時点のリポジトリ状態

### When（実行条件）
- ディレクトリ構成・ソースを静的に検査する

### Then（期待結果）
- `features/guild/ui/`が存在しない（FR-406）
- `res://data/daily_orders/`に`.tres`実データが存在せず、再抽選ロジックのコードもない（FR-405）
- ランクノルマの減算・降格判定・昇格試験の実装が`features/guild/`・`GameState`のいずれにも存在しない（FR-404, FR-407）

### テストチェックリスト

- [ ] **正常系**: `features/guild/`配下が`logic/`・`resources/`のみで構成されている 🔵
- [ ] **正常系**: `data/daily_orders/`に`.tres`が0件である 🔵
- [ ] **異常系**: `grep`でランクノルマ減算・昇格試験関連の識別子が本planの成果物に含まれないことを確認する 🔵

---

## 横断的受入基準

### パフォーマンス（NFR-001）

- [ ] `GameState.deliver_pending_products`が`_process()`を用いず、呼び出し時の同期処理のみで完結する実装になっていることをコードレビューで確認する 🟡

### セキュリティ（NFR-101）

- [ ] `daily_order = null`・空の`_pending_products`・未知の`condition_type`のいずれを渡してもクラッシュせず、定義された結果を返すことをテストする（AC-003, AC-007, AC-012と重複確認） 🔵

### ユーザビリティ（NFR-201）

- [ ] `delivered`シグナルの`results`から件別の`order_matched`が読み取れ、将来のUIが「指定合致」表示を実装可能であることを確認する 🟡

### 保守性・アーキテクチャ整合性（NFR-301, NFR-302）

- [ ] `features/guild/`が`logic/`・`resources/`の構成に従っていることを`gdlint`・ディレクトリ構成確認で検証する 🔵
- [ ] 他Featureのコードが`features/guild/`の`state/`・`ui/`を参照していないことを確認する（本planでは両ディレクトリを作成しない） 🔵

### テスト容易性（NFR-401, NFR-402）

- [ ] `features/guild/logic/`配下の全public `static func`（`matches_order`・`resolve`）について、正常系・異常系・境界値のテストが最低1本ずつ存在することを数え上げで確認する 🔵
- [ ] `guild`関連のテストファイルが`tests/unit/features/guild/`または`tests/integration/`にのみ配置され、`features/guild/`配下に`test_*.gd`が存在しないことを確認する 🔵

---

## テストサマリー

| カテゴリ | 正常系 | 異常系 | 境界値 | 合計 |
|---------|--------|--------|--------|------|
| 機能要件（AC-001〜AC-016） | 25 | 13 | 11 | 49 |
| 非機能要件（横断的受入基準） | 7 | 0 | 0 | 7 |
| **合計** | 32 | 13 | 11 | 56 |

## 信頼性レベル分布

- 🔵 青信号: 11件 (68.8%): AC-001〜AC-007, AC-013〜AC-016
- 🟡 黄信号: 1件 (6.3%): AC-012
- 🔴 赤信号: 4件 (25.0%): AC-008, AC-009, AC-010, AC-011（GameState納品API・ゴールド丸め・暫定累積フィールド・deliveredシグナルの新規補完設計）

（AC-001〜AC-016の各基準見出しの信号機を集計。合計16件）
