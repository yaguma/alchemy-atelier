# workshop 受入基準

## 関連文書

- **要件定義**: [requirements.md](requirements.md)
- **ユーザーストーリー**: [user-stories.md](user-stories.md)

**【信頼性レベル凡例】**:
- 🔵 確実な基準
- 🟡 妥当な推測による基準
- 🔴 AI推論補完（要確認）

---

## AC-001: [FR-001] PurchaseValidator.can_purchaseの判定式 🔵

**関連**: FR-001, FR-003, US-201, US-202

### Given（前提条件）
- `PurchaseValidator.can_purchase(gold, price, already_purchased_count, max_purchase_count)`が呼び出し可能な状態にある

### When（実行条件）
- 任意の`gold`・`price`・`already_purchased_count`・`max_purchase_count`の組み合わせで`can_purchase`を呼び出す

### Then（期待結果）
- `gold >= price and already_purchased_count < max_purchase_count`の論理積と一致する`bool`が返る

### テストチェックリスト

- [ ] **正常系**: `gold=500, price=500, already_purchased_count=0, max_purchase_count=1` → `true` 🔵
- [ ] **正常系**: `gold=1000, price=500, already_purchased_count=0, max_purchase_count=1` → `true` 🔵
- [ ] **異常系**: `gold=499, price=500, already_purchased_count=0, max_purchase_count=1` → `false`（ゴールド不足） 🔵
- [ ] **境界値**: `gold == price`（ちょうど価格と同額）→ `true`（`>=`であり`>`ではない） 🔵
- [ ] **境界値**: `gold == price - 1` → `false` 🔵
- [ ] **境界値**: `already_purchased_count == max_purchase_count - 1`（上限到達直前）→ `true`（ゴールド条件を満たす場合） 🔵
- [ ] **境界値**: `already_purchased_count == max_purchase_count`（上限到達直後）→ `false` 🔵
- [ ] **境界値**: `max_purchase_count`が実質無制限の大きな値（消耗投資想定）の場合、`already_purchased_count`が多少増えても`true`のまま 🟡

---

## AC-002: [FR-002] PurchaseValidator.is_permanent_upgradeの判別 🔵

**関連**: FR-002, FR-403, US-004

### Given（前提条件）
- `is_permanent = true`の`UpgradeMaster`インスタンスと`is_permanent = false`の`UpgradeMaster`インスタンスがそれぞれ用意されている

### When（実行条件）
- 各インスタンスに対し`PurchaseValidator.is_permanent_upgrade(upgrade)`を呼び出す

### Then（期待結果）
- `upgrade.is_permanent`の値がそのまま返る

### テストチェックリスト

- [ ] **正常系**: `is_permanent = true`の`UpgradeMaster`（投入枠+1相当）→ `true` 🔵
- [ ] **正常系**: `is_permanent = false`の`UpgradeMaster`（触媒常備相当）→ `false` 🔵

---

## AC-003: [FR-101, FR-102, FR-401, FR-402] ゴールド不足時の購入拒否と状態無変更 🔵

**関連**: FR-101, FR-102, FR-401, FR-402, US-201

### Given（前提条件）
- `GameState.reset_for_test()`済み
- `_gold`が`upgrade.price`未満に設定されている
- `_can_purchase_permanent = true`（恒久投資側の検証は別途AC-004でカバーするため、ここではフラグを満たした状態にしておく）

### When（実行条件）
- `GameState.apply_upgrade(upgrade)`を呼び出す

### Then（期待結果）
- `Result.fail()`が返る
- `_gold`・`_inventory`・`_alchemy_slot_count`・`_garden_slot_count`・`_unlocked_recipe_ids`・`_seed_inventory`・`_purchased_upgrade_counts`のいずれも呼び出し前と変わらない
- `gold_changed`シグナルが発行されない

### テストチェックリスト

- [ ] **正常系**: ゴールドが十分な場合は`Result.ok()`が返り購入が成立する（対照ケース） 🔵
- [ ] **異常系**: `_gold = upgrade.price - 1`で呼び出すと`Result.fail()`が返り、`_gold`が変化しない 🔵
- [ ] **境界値**: `_gold == upgrade.price`（ちょうど同額）では購入が成立する 🔵

---

## AC-004: [FR-009, FR-103, FR-110, FR-111, FR-201, FR-202] 恒久投資フラグによる購入可否 🔵

**関連**: FR-009, FR-103, FR-110, FR-111, FR-201, FR-202, US-001, US-002, US-003, US-004

### Given（前提条件）
- `GameState.reset_for_test()`済み（`_can_purchase_permanent = false`が既定値）
- `is_permanent = true`の`UpgradeMaster`（例: 投入枠+1）と、購入可能な`_gold`が用意されている

### When（実行条件）
1. `_can_purchase_permanent = false`のまま`apply_upgrade(upgrade)`を呼び出す
2. 昇格試験成功パス相当の操作（またはテスト専用API）で`_can_purchase_permanent`を`true`にした後、再度`apply_upgrade(upgrade)`を呼び出す
3. `close_workshop()`を呼び出した後、再度`apply_upgrade(upgrade)`を呼び出す

### Then（期待結果）
- 手順1: `Result.fail()`が返り、`_alchemy_slot_count`等の恒久効果が反映されない
- 手順2: `Result.ok()`が返り、恒久効果が反映される
- 手順3: `close_workshop()`後は`_can_purchase_permanent`が`false`に戻っており、再度`Result.fail()`が返る

### テストチェックリスト

- [ ] **正常系**: `_can_purchase_permanent = true`かつゴールド十分な場合、恒久投資が購入できる 🔵
- [ ] **異常系**: `_can_purchase_permanent = false`の場合、ゴールドが十分でも恒久投資は拒否される 🔵
- [ ] **境界値**: `_can_purchase_permanent`が`false`→`true`に切り替わった直後は購入が許可される 🔵
- [ ] **境界値**: `close_workshop()`呼び出し直後、`_can_purchase_permanent`が`true`→`false`に戻り再び拒否される 🔵

---

## AC-005: [FR-015, FR-110, FR-111] close_workshop()と昇格試験成功によるフラグ遷移 🔵

**関連**: FR-015, FR-110, FR-111, US-004

### Given（前提条件）
- `GameState.reset_for_test()`済み

### When（実行条件）
1. 昇格試験成功を確定させる操作（`_commit_exam_success()`の成功パス、または既存の`_set_exam_state_for_test()`等でSUCCESS確定直前の状態を再現した上で`commit_exam_outcome()`を呼ぶ）
2. `GameState.close_workshop()`を呼び出す

### Then（期待結果）
- 手順1の直後: `_can_purchase_permanent == true`
- 手順2の直後: `_can_purchase_permanent == false`

### テストチェックリスト

- [ ] **正常系**: 昇格試験成功確定後、`_can_purchase_permanent`が`true`になる 🔵
- [ ] **正常系**: `close_workshop()`呼び出し後、`_can_purchase_permanent`が`false`になる 🔵
- [ ] **異常系**: 昇格試験が失敗（FAILURE）確定した場合は`_can_purchase_permanent`が`true`にならない 🟡

---

## AC-006: [FR-203] 消耗投資はフラグに関わらず常時購入可能 🔵

**関連**: FR-203, US-101, US-102

### Given（前提条件）
- `GameState.reset_for_test()`済み（`_can_purchase_permanent = false`）
- `is_permanent = false`の`UpgradeMaster`（触媒常備または種の指名買い）と、購入可能な`_gold`が用意されている

### When（実行条件）
- `_can_purchase_permanent = false`のまま`apply_upgrade(upgrade)`を呼び出す

### Then（期待結果）
- `Result.ok()`が返り、消耗投資の効果（`_inventory`への触媒追加、または`_seed_inventory`のcount増加）が反映される

### テストチェックリスト

- [ ] **正常系**: `_can_purchase_permanent = false`のまま触媒常備を購入できる 🔵
- [ ] **正常系**: `_can_purchase_permanent = false`のまま種の指名買いを購入できる 🔵
- [ ] **正常系**: `_can_purchase_permanent = true`の状態でも同様に消耗投資が購入できる（対照ケース） 🟡

---

## AC-007: [FR-104] 購入成立時のゴールド減算とgold_changedシグナル発行 🔵

**関連**: FR-104, US-001, US-002, US-101, US-102

### Given（前提条件）
- `GameState.reset_for_test()`済み
- `_gold = 1000`、`upgrade.price = 300`の購入可能なUpgradeMasterが用意されている
- `gold_changed`シグナルを監視可能な状態にある（`monitor_signals(GameState, false)`）

### When（実行条件）
- `GameState.apply_upgrade(upgrade)`を呼び出す

### Then（期待結果）
- `_gold`が`1000 - 300 = 700`になる
- `gold_changed(700 + 300, 700, -300)`相当のシグナル（`previous_amount=1000, new_amount=700, delta=-300`）が発行される

### テストチェックリスト

- [ ] **正常系**: 購入成立時に`_gold`が正しく減算される 🔵
- [ ] **正常系**: `gold_changed`シグナルが正しい引数（`previous_amount`, `new_amount`, `delta`）で発行される 🔵
- [ ] **異常系**: 購入が拒否された場合は`gold_changed`が発行されない（AC-003と重複検証） 🔵

---

## AC-008: [FR-105] alchemy_slot_increaseの反映 🔵

**関連**: FR-105, US-001

### Given（前提条件）
- `GameState.reset_for_test()`済み（`_alchemy_slot_count = GameBalance.ALCHEMY_SLOT_COUNT_DEFAULT`）
- `_can_purchase_permanent = true`
- `effect_type = &"alchemy_slot_increase"`, `effect_value = 1`のUpgradeMasterが用意されている

### When（実行条件）
- `GameState.apply_upgrade(upgrade)`を呼び出す

### Then（期待結果）
- `_alchemy_slot_count`が購入前の値+1になる

### テストチェックリスト

- [ ] **正常系**: 購入後に`_alchemy_slot_count`が`effect_value`分加算される 🔵
- [ ] **境界値**: `max_purchase_count = 1`の場合、2回目の購入要求は拒否され`_alchemy_slot_count`はそれ以上増加しない 🔵

---

## AC-009: [FR-106] garden_slot_increaseの反映 🔵

**関連**: FR-106, US-002

### Given（前提条件）
- `GameState.reset_for_test()`済み（`_garden_slot_count = GameBalance.GARDEN_SLOT_COUNT`）
- `_can_purchase_permanent = true`
- `effect_type = &"garden_slot_increase"`, `effect_value = 1`のUpgradeMasterが用意されている

### When（実行条件）
- `GameState.apply_upgrade(upgrade)`を呼び出す

### Then（期待結果）
- `_garden_slot_count`が購入前の値+1になる

### テストチェックリスト

- [ ] **正常系**: 購入後に`_garden_slot_count`が`effect_value`分加算される 🔵

---

## AC-010: [FR-107] recipe_unlockの反映 🔵

**関連**: FR-107, US-003

### Given（前提条件）
- `GameState.reset_for_test()`済み（`_unlocked_recipe_ids = [GameBalance.INITIAL_RECIPE_ID]`）
- `_can_purchase_permanent = true`
- `effect_type = &"recipe_unlock"`, `effect_value`に第2レシピのidが設定されたUpgradeMasterが用意されている

### When（実行条件）
- `GameState.apply_upgrade(upgrade)`を呼び出す

### Then（期待結果）
- `_unlocked_recipe_ids`に対象レシピIDが追加され、`execute_alchemy()`でそのレシピを使った調合が実行可能になる

### テストチェックリスト

- [ ] **正常系**: 購入後に`_unlocked_recipe_ids`へ対象レシピIDが追加される 🔵
- [ ] **正常系**: 購入後、対象レシピIDで`execute_alchemy()`を呼び出すと`&"recipe_not_unlocked"`エラーが発生しなくなる 🟡

---

## AC-011: [FR-016, FR-108] material_catalystの新規作成とcatalyst_stockの反映 🔵

**関連**: FR-016, FR-108, US-101

### Given（前提条件）
- `res://data/materials/`に専用`MaterialMaster` `.tres`（`id: &"material_catalyst"`, `shop_purchasable: true`, `shop_base_quality: 3`）が存在する
- `GameState.reset_for_test()`済み（`_inventory = []`）
- `effect_type = &"catalyst_stock"`のUpgradeMasterが用意されている（`is_permanent = false`のため`_can_purchase_permanent`の値は問わない）

### When（実行条件）
- `GameState.apply_upgrade(upgrade)`を呼び出す

### Then（期待結果）
- `_inventory`に新規`MaterialInstance`が1件追加される
- 追加された`MaterialInstance`の`material_id`は`&"material_catalyst"`と一致する
- 追加された`MaterialInstance`の`trait_tags`は`[&"catalyst"]`を含む
- 追加された`MaterialInstance`の`quality_score`は`GameBalance.CATALYST_BASE_QUALITY_SCORE`と一致する

### テストチェックリスト

- [ ] **正常系**: `material_catalyst.tres`が`MasterDataLoader.load_all(&"materials")`で読み込める 🔵
- [ ] **正常系**: 購入後、`_inventory`のサイズが1増え、`material_id`が`&"material_catalyst"`、`trait_tags`に`&"catalyst"`が含まれる 🔵
- [ ] **正常系**: 追加された`MaterialInstance.quality_score`が`GameBalance.CATALYST_BASE_QUALITY_SCORE`と一致する 🔵
- [ ] **境界値**: 連続して2回購入すると`_inventory`に触媒素材が2件独立して追加される（`clone()`と同様、参照共有していないこと） 🟡

---

## AC-012: [FR-109] seed_name_purchaseの反映 🔵

**関連**: FR-109, US-102

### Given（前提条件）
- `GameState.reset_for_test()`済み（`_seed_inventory = [{seed_id: GameBalance.INITIAL_SEED_ID, count: GameBalance.INITIAL_SEED_COUNT}]`）
- `effect_type = &"seed_name_purchase"`のUpgradeMasterが用意されている（`effect_value`は既存`seed_id`のケースと未所持`seed_id`のケースの両方を検証する）

### When（実行条件）
1. `effect_value`が既に`_seed_inventory`に存在する`seed_id`（例: `GameBalance.INITIAL_SEED_ID`）の場合に`apply_upgrade(upgrade)`を呼び出す
2. `effect_value`が`_seed_inventory`に存在しない`seed_id`の場合に`apply_upgrade(upgrade)`を呼び出す

### Then（期待結果）
- 手順1: 該当エントリの`count`が+1される
- 手順2: `{seed_id: effect_value, count: 1}`の新規エントリが`_seed_inventory`に追加される

### テストチェックリスト

- [ ] **正常系**: 既存`seed_id`の`count`が+1される 🔵
- [ ] **正常系**: 未所持`seed_id`が新規エントリとして追加される 🔵

---

## AC-013: [FR-010, FR-013, FR-102, FR-113] 購入回数上限の境界値 🔵

**関連**: FR-010, FR-013, FR-102, FR-113, US-202

### Given（前提条件）
- `GameState.reset_for_test()`済み
- `max_purchase_count = 1`の恒久投資UpgradeMaster（投入枠+1相当）が用意されている
- `_can_purchase_permanent = true`、ゴールドは常に十分

### When（実行条件）
1. 1回目の`apply_upgrade(upgrade)`を呼び出す
2. 引き続き2回目の`apply_upgrade(upgrade)`を呼び出す

### Then（期待結果）
- 手順1: `Result.ok()`が返り、`_purchased_upgrade_counts[upgrade.id]`が`1`になる
- 手順2: `Result.fail()`が返り、`_alchemy_slot_count`等の効果が二重に反映されない

### テストチェックリスト

- [ ] **正常系**: `already_purchased_count = 0`（初回）は購入できる（`max_purchase_count - 1`到達直前） 🔵
- [ ] **異常系**: `already_purchased_count = max_purchase_count`到達後の3回目以降の要求も拒否され続ける 🔵
- [ ] **境界値**: `max_purchase_count`が実質無制限（消耗投資想定の大きな値）の場合、`_purchased_upgrade_counts`が増加し続けても拒否されない 🔵

---

## AC-014: [FR-101, FR-102, FR-401, FR-402] 検証失敗時のアトミック性（総合） 🔵

**関連**: FR-101, FR-102, FR-401, FR-402, US-201

### Given（前提条件）
- `GameState.reset_for_test()`済み
- ゴールド不足・恒久フラグfalse・購入回数上限到達のいずれか1つ以上に該当する`UpgradeMaster`が用意されている

### When（実行条件）
- `GameState.apply_upgrade(upgrade)`を呼び出す

### Then（期待結果）
- `Result.fail()`が返る
- `_gold`・`_inventory`・`_alchemy_slot_count`・`_garden_slot_count`・`_unlocked_recipe_ids`・`_seed_inventory`・`_purchased_upgrade_counts`のいずれも呼び出し前と完全に一致する（部分的な適用が発生しない）

### テストチェックリスト

- [ ] **異常系**: ゴールド不足時に他の状態（`_inventory`等）も一切変化しない 🔵
- [ ] **異常系**: 恒久フラグfalse時に`_purchased_upgrade_counts`も加算されない 🔵
- [ ] **異常系**: 購入回数上限到達時にゴールドも減算されない 🔵

---

## AC-015: [FR-004, FR-005, FR-006, FR-011, FR-115, FR-404] MasterDataLoaderのupgradesカテゴリ対応 🔵

**関連**: FR-004, FR-005, FR-006, FR-011, FR-115, FR-404, US-301

### Given（前提条件）
- `res://data/upgrades/`に5件の`UpgradeMaster` `.tres`が配置されている
- （検証用に）`res://data/upgrades/`以外の場所には他カテゴリのリソースが混在しないディレクトリ構成である

### When（実行条件）
- `MasterDataLoader.load_all(&"upgrades")`を呼び出す

### Then（期待結果）
- 5件すべてが`UpgradeMaster`型の要素として返る
- 各要素の`id`・`name`・`is_permanent`・`price`・`effect_type`・`effect_value`・`max_purchase_count`が`.tres`の内容と一致する

### テストチェックリスト

- [ ] **正常系**: `load_all(&"upgrades")`が5件の`UpgradeMaster`を返す 🔵
- [ ] **正常系**: `GameState.load_workshop_master_data()`呼び出し後、`_upgrade_masters`に5件が登録される 🟡
- [ ] **異常系**: `res://data/upgrades/`に`UpgradeMaster`以外の`.tres`が混在していても結果に含まれない（既存`_is_allowed_type`パターンの踏襲確認） 🔵

---

## AC-016: [FR-007] 第2レシピの存在とrecipe_unlock購入後の解禁確認 🔵

**関連**: FR-007, FR-107, US-003, US-302

### Given（前提条件）
- `res://data/recipes/`に`recipe_healing_potion`とは別の第2の`RecipeMaster` `.tres`が存在する
- `GameState.reset_for_test()`済み（`_unlocked_recipe_ids = [GameBalance.INITIAL_RECIPE_ID]`のみ）

### When（実行条件）
1. 購入前に第2レシピIDで`execute_alchemy()`を呼び出す
2. `recipe_unlock`（`effect_value`=第2レシピID）のUpgradeMasterを購入する
3. 購入後、再度第2レシピIDで`execute_alchemy()`を呼び出す

### Then（期待結果）
- 手順1: `&"recipe_not_unlocked"`エラーで失敗する
- 手順3: レシピ未解禁エラーは発生しない（他の検証条件を満たしていれば成功する）

### テストチェックリスト

- [ ] **正常系**: 第2レシピの`.tres`が`MasterDataLoader.load_all(&"recipes")`で読み込める 🔵
- [ ] **正常系**: `recipe_unlock`購入前は第2レシピで調合できず、購入後は調合できるようになる 🔵

---

## AC-017: [FR-012, FR-013, FR-014] テスト専用APIとreset_for_testの初期化 🔵

**関連**: FR-012, FR-013, FR-014, US-201, US-202

### Given（前提条件）
- `GameState`が任意の状態（`_can_purchase_permanent = true`、`_purchased_upgrade_counts`に複数件、`_upgrade_masters`に複数件）になっている

### When（実行条件）
1. `_set_can_purchase_permanent_for_test(true)`を呼び出す
2. `_set_purchased_upgrade_counts_for_test({...})`を呼び出す
3. `GameState.reset_for_test()`を呼び出す

### Then（期待結果）
- 手順1・2: 該当フィールドが指定値に直接反映される（実プレイ操作を介さない）
- 手順3: `_can_purchase_permanent == false`、`_purchased_upgrade_counts == {}`、`_upgrade_masters == {}`になる

### テストチェックリスト

- [ ] **正常系**: テスト専用APIで`_can_purchase_permanent`を直接注入できる 🔵
- [ ] **正常系**: テスト専用APIで`_purchased_upgrade_counts`を直接注入できる 🔵
- [ ] **正常系**: `reset_for_test()`後、両フィールドが既定値に戻る 🔵
- [ ] **異常系**: リリースビルド相当のガード下では、テスト専用APIが`GameStateTestSupport.guard()`により無効化される（既存パターンの踏襲確認） 🟡

---

## AC-018: [FR-112] null upgradeの拒否 🟡

**関連**: FR-112, US-201

### Given（前提条件）
- `GameState.reset_for_test()`済み

### When（実行条件）
- `GameState.apply_upgrade(null)`を呼び出す

### Then（期待結果）
- `Result.fail(&"invalid_upgrade")`が返る
- いかなる状態も変更されない
- 例外・クラッシュが発生しない

### テストチェックリスト

- [ ] **異常系**: `null`を渡してもクラッシュせず`Result.fail()`が返る 🟡
- [ ] **異常系**: `null`渡し後も`_gold`等の状態が変化しない 🟡

---

## 横断的受入基準

### パフォーマンス（NFR-001）

- [ ] `apply_upgrade()`の1回の呼び出しが同期的に完了し、`_seed_inventory`の線形探索を含めてもフレーム内で完結する 🟡

### セキュリティ・データ整合性（NFR-101, NFR-102）

- [ ] UI層が「購入可能」と誤って表示していても、`GameState.apply_upgrade()`側の再検証により不正な購入が成立しないことを統合テストで確認する 🔵
- [ ] `GameState.get_state()`が返す`Dictionary`/`Array`（将来`can_purchase_permanent`等を含める場合）を呼び出し元で直接変更しても、`GameState`内部の正本データが汚染されないことを確認する 🟡

### アクセシビリティ

- 該当なし（本plan外。UI層実装時に別途定義する） 🔵

---

## テストサマリー

| カテゴリ | 正常系 | 異常系 | 境界値 | 合計 |
|---------|--------|--------|--------|------|
| 機能要件（AC-001〜AC-018） | 30 | 13 | 11 | 54 |
| 非機能要件（横断的受入基準のチェック項目） | 3 | 0 | 0 | 3 |
| **合計** | 33 | 13 | 11 | 57 |

上記に加え、AC-001〜AC-018の各見出し自体にも信頼性レベルを付与している（18件）。下記「信頼性レベル分布」はAC見出し18件・上表のチェック項目57件・横断的受入基準内の注記1件（アクセシビリティ「該当なし」）を合わせた全76件を対象とする（ユーザーヒアリングでAC-011に`material_catalyst`読み込み確認項目を1件追加したため、生成時点の75件から1件増加）。

## 信頼性レベル分布

- 🔵 青信号: 64件 (84%)
- 🟡 黄信号: 12件 (16%)
- 🔴 赤信号: 0件（ユーザーヒアリングで全て解消済み）
