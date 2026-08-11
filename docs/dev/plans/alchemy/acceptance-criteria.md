# alchemy 受入基準

## 関連文書

- **要件定義**: [requirements.md](requirements.md)
- **ユーザーストーリー**: [user-stories.md](user-stories.md)

**【信頼性レベル凡例】**:
- 🔵 確実な基準
- 🟡 妥当な推測による基準
- 🔴 AI推論補完（要確認）

---

## AC-001: [FR-105] 品質スコアの平均四捨五入 🔵

**関連**: FR-105, US-001

### Given（前提条件）
- `traits_unlocked = true`、触媒を含まない`MaterialInstance`配列（例: `quality_score = [3, 4]`）

### When（実行条件）
- `QualityCalculator.calculate_quality(materials, true)`を呼び出す

### Then（期待結果）
- 平均`3.5`を四捨五入した`4`が返る

### テストチェックリスト

- [ ] **正常系**: `[3, 3]` → `3`（割り切れる平均） 🔵
- [ ] **異常系**: 空配列`[]`が渡された場合にクラッシュせず定義された挙動（0除算を避ける実装）になることを確認する 🟡
- [ ] **境界値**: 四捨五入の境界（`[2, 3]`平均2.5 → `3`、`[2, 2, 3]`平均2.33 → `2`）を検証する 🔵

---

## AC-002: [FR-106, FR-202] 触媒+1クランプ 🔵

**関連**: FR-106, FR-202, US-002

### Given（前提条件）
- `traits_unlocked = true`、`quality_score = [4, 5]`（平均4.5→四捨五入5）の素材に加え`trait_tags = [&"catalyst"]`を持つ素材を1個投入

### When（実行条件）
- `QualityCalculator.calculate_quality(materials, true)`を呼び出す

### Then（期待結果）
- 四捨五入後の品質`5`に+1され、上限5でクランプされた`5`が返る

### テストチェックリスト

- [ ] **正常系**: 四捨五入後`4`の素材+触媒 → `5`（クランプ未発動） 🔵
- [ ] **異常系**: `traits_unlocked = false`で同じ素材構成（触媒含む）を渡すと、ボーナスが適用されず四捨五入値のまま返る（FR-202） 🔵
- [ ] **境界値**: 四捨五入後`5`の素材+触媒 → `5`のまま（クランプが実際に効く） 🔵

---

## AC-003: [FR-107, FR-201] 特性発現の2個閾値 🔵

**関連**: FR-107, FR-201, US-003

### Given（前提条件）
- `traits_unlocked = true`、`&"holy"`タグを持つ素材が0〜3個投入されたパターンをそれぞれ用意する

### When（実行条件）
- `TraitActivation.resolve_traits(materials, true)`を呼び出す

### Then（期待結果）
- `&"holy"`の出現数が2個以上のときのみ`activated_traits`に`&"holy"`が1つだけ含まれる

### テストチェックリスト

- [ ] **正常系**: `&"holy"`2個 → `activated_traits = [&"holy"]` 🔵
- [ ] **異常系**: `&"holy"`1個のみ → `activated_traits`に含まれない（不発） 🔵
- [ ] **境界値**: `&"holy"`3個以上でも`activated_traits`に`&"holy"`は1つだけ（据え置き、重複追加されない） 🔵
- [ ] **境界値**: `traits_unlocked = false`の場合は`&"holy"`が3個投入されていても`activated_traits`が空配列になる 🔵

---

## AC-004: [FR-108, FR-109, FR-406] 特性ボーナスの系統別乗算合成 🔵

**関連**: FR-108, FR-109, FR-406, US-004

### Given（前提条件）
- `activated_traits = [&"holy", &"purify"]`（貢献度系2種が発現済み）

### When（実行条件）
- 貢献度系ボーナスを`GameBalance.TRAIT_CONTRIBUTION_BONUS`から乗算合成し、`ProductValueCalculator.calculate_contribution(base_contribution, quality_mult, contribution_bonus)`を呼び出す

### Then（期待結果）
- `contribution_bonus = TRAIT_CONTRIBUTION_BONUS[&"holy"] * TRAIT_CONTRIBUTION_BONUS[&"purify"]`となり、`calculate_reward`側の`reward_bonus`は`1.0`（報酬系特性が発現していないため）のまま影響を受けない

### テストチェックリスト

- [ ] **正常系**: 貢献度系1種のみ発現 → `contribution_bonus`はその特性の倍率そのまま、`reward_bonus = 1.0` 🔵
- [ ] **正常系**: 報酬系1種のみ発現（例: `&"gold"`） → `reward_bonus`はその倍率、`contribution_bonus = 1.0` 🔵
- [ ] **異常系**: `activated_traits`が空配列 → `contribution_bonus = reward_bonus = 1.0` 🔵
- [ ] **境界値**: 貢献度系3種すべて発現 → 3つの倍率がすべて乗算される 🟡
- [ ] **異常系**: `calculate_contribution`・`calculate_reward`が`match_bonus_multiplier`相当の引数を受け取らない（シグネチャに存在しないことをコードで確認、FR-406） 🔵

---

## AC-005: [FR-102] 投入素材の実在チェック 🔵

**関連**: FR-102, US-006

### Given（前提条件）
- 解禁済み・実在するレシピが選択されている
- `material_instance_ids`に`inventory`へ実在しない`instance_id`が1件含まれる

### When（実行条件）
- `GameState.execute_alchemy(recipe_id, material_instance_ids)`を呼び出す

### Then（期待結果）
- `error_code = &"material_not_owned"`の失敗`Result`が返る
- `inventory`・`pending_products`はいずれも変化しない
- `execute_alchemy_failed(recipe_id, &"material_not_owned")`シグナルが発行される

### テストチェックリスト

- [ ] **正常系**: 全`instance_id`が`inventory`に実在する場合は本チェックを通過する（AC-010で確認） 🔵
- [ ] **異常系**: 実在しない`instance_id`が1件でも含まれると即座に失敗する 🔵
- [ ] **境界値**: `material_instance_ids`が空配列の場合は本チェックではなく`AC-008`（0個投入不可）で検出される 🟡

---

## AC-006: [FR-102] 投入枠内の重複ID禁止 🔵

**関連**: FR-102, US-006

### Given（前提条件）
- `inventory`に実在する`instance_id`が1件のみ存在する
- `material_instance_ids`に同一`instance_id`を2回指定する

### When（実行条件）
- `GameState.execute_alchemy(recipe_id, material_instance_ids)`を呼び出す

### Then（期待結果）
- `error_code = &"duplicate_material_in_slot"`の失敗`Result`が返る
- `inventory`・`pending_products`はいずれも変化しない

### テストチェックリスト

- [ ] **正常系**: 重複のない`instance_id`配列は本チェックを通過する 🔵
- [ ] **異常系**: 同一`instance_id`が2回指定されると失敗する 🔵
- [ ] **境界値**: 3回以上の重複でも同じ`error_code`で失敗する 🟡

---

## AC-007: [FR-103, FR-006] 投入枠数超過での実行不可 🔵

**関連**: FR-103, FR-006, US-007

### Given（前提条件）
- 現在の`alchemy_slot_count = 4`
- `material_instance_ids`に5件の実在する`instance_id`を指定する

### When（実行条件）
- `GameState.execute_alchemy(recipe_id, material_instance_ids)`を呼び出す

### Then（期待結果）
- `SlotState.can_execute()`が偽となり`error_code = &"slot_execution_invalid"`の失敗`Result`が返る
- `inventory`・`pending_products`はいずれも変化しない

### テストチェックリスト

- [ ] **正常系**: ちょうど4件（`max_slots`と同数）は成功する 🔵
- [ ] **異常系**: 5件（`max_slots`超過）は失敗する 🔵
- [ ] **境界値**: `max_slots`が恒久投資で5に拡張された状態では5件が成功する 🟡

---

## AC-008: [FR-103] 0個投入での実行不可 🔵

**関連**: FR-103, US-007

### Given（前提条件）
- `material_instance_ids = []`

### When（実行条件）
- `GameState.execute_alchemy(recipe_id, [])`を呼び出す

### Then（期待結果）
- `SlotState.can_execute()`が偽となり`error_code = &"slot_execution_invalid"`の失敗`Result`が返る

### テストチェックリスト

- [ ] **正常系**: 1件のみの投入は成功する（他条件を満たす場合） 🔵
- [ ] **異常系**: 0件投入は失敗する 🔵

---

## AC-009: [FR-101, FR-102, FR-007] 未解禁・未知レシピでの実行不可 🔵

**関連**: FR-101, FR-102, FR-007, US-005

### Given（前提条件）
- ケースA: `recipe_id`がどの`RecipeMaster`にも存在しない
- ケースB: `recipe_id`は`RecipeMaster`として実在するが`unlocked_recipe_ids`に含まれない

### When（実行条件）
- `GameState.execute_alchemy(recipe_id, material_instance_ids)`を呼び出す

### Then（期待結果）
- ケースAは`error_code = &"unknown_recipe_id"`、ケースBは`error_code = &"recipe_not_unlocked"`の失敗`Result`が返る
- いずれも`inventory`・`pending_products`は変化しない

### テストチェックリスト

- [ ] **正常系**: `unlocked_recipe_ids`に含まれる実在レシピは本チェックを通過する 🔵
- [ ] **異常系**: 未知の`recipe_id`（マスター自体が存在しない）は`unknown_recipe_id`で失敗する 🔵
- [ ] **異常系**: 実在するが未解禁の`recipe_id`は`recipe_not_unlocked`で失敗する 🔵
- [ ] **境界値**: `unlocked_recipe_ids`が初期状態（最低1件、`GameBalance.INITIAL_RECIPE_ID`のみ）でもそのレシピは成功する 🔵

---

## AC-010: [FR-110, FR-111, FR-112, FR-008] 調合成功時のProductInstance生成・在庫消費・キュー追加 🔵

**関連**: FR-110, FR-111, FR-112, FR-008, US-005, US-008, US-011

### Given（前提条件）
- 解禁済みレシピ（`base_contribution = 10.0, base_reward = 5.0`）が選択されている
- `traits_unlocked = true`、投入素材が全て`inventory`に実在し重複なく枠数以内

### When（実行条件）
- `GameState.execute_alchemy(recipe_id, material_instance_ids)`を呼び出す

### Then（期待結果）
- `ProductInstance.recipe_id`が投入した`recipe_id`と一致する
- `contribution = base_contribution × quality_multiplier × contribution_bonus`、`reward = base_reward × quality_multiplier × reward_bonus`で算出される
- 投入した全`MaterialInstance`が`inventory`から除去される
- 生成された`ProductInstance`が`pending_products`に追加される
- `product_crafted(product)`シグナルが発行され、`product`の内容が上記算出結果と一致する

### テストチェックリスト

- [ ] **正常系**: 特性なし・触媒なしの単純ケースで`contribution`/`reward`が式通りに算出される 🔵
- [ ] **正常系**: 調合後`inventory.size()`が投入前より投入数分減っている 🔵
- [ ] **異常系**: 調合失敗時（AC-005〜AC-009）は`pending_products`が増えないことをあわせて確認する 🔵
- [ ] **境界値**: 特性・触媒がすべて発現した最大ボーナスケースでも`contribution`/`reward`が式通りに算出される 🟡

---

## AC-011: [FR-104, FR-201, FR-202] traits_unlocked=falseでの特性封印動作 🔵

**関連**: FR-104, FR-201, FR-202, US-002, US-003, US-012

### Given（前提条件）
- `_traits_unlocked = false`（Gランク相当）
- 投入素材に触媒1個と`&"holy"`タグ2個を含む

### When（実行条件）
- `GameState.execute_alchemy(recipe_id, material_instance_ids)`を呼び出す

### Then（期待結果）
- 品質は触媒ボーナスなしの平均四捨五入値のまま確定する
- `activated_traits`は空配列になり、`contribution`/`reward`のいずれにも特性ボーナスが乗らない（倍率1.0）

### テストチェックリスト

- [ ] **正常系**: `traits_unlocked = false`で触媒+特性2個投入しても品質・特性ボーナスがともに無効 🔵
- [ ] **異常系**: 同じ素材構成で`traits_unlocked = true`に切り替えると触媒・特性ボーナスの両方が有効になる（対比確認） 🔵

---

## AC-012: [FR-403] pending_products/inventoryの防御的コピー 🔵

**関連**: FR-403, US-009

### Given（前提条件）
- `GameState`が調合成功後、`pending_products`・`inventory`に既存データを保持している

### When（実行条件）
- 呼び出し元が`GameState.get_state()`の戻り値の`pending_products`（`Array`）に対し`append`/`clear`等の変更操作を行う

### Then（期待結果）
- `GameState`内部の実際の`pending_products`・`inventory`は変化しない（`duplicate(true)`または`clone()`によるディープコピーが機能している）

### テストチェックリスト

- [ ] **正常系**: 戻り値の`pending_products`を変更しても`GameState`内部状態が変化しないことをテストで確認する 🔵
- [ ] **境界値**: `ProductInstance`が保持するネストした配列（`activated_traits`）まで独立コピーされている 🟡

---

## AC-013: [FR-401, FR-402] Domain層の純粋性・乱数非依存 🔵

**関連**: FR-401, FR-402

### Given（前提条件）
- `QualityCalculator`・`TraitActivation`・`ProductValueCalculator`の各`static func`の実装

### When（実行条件）
- 同一引数でユニットテストを複数回実行する、およびコードを静的に検査する

### Then（期待結果）
- いずれの関数も`GameState`等の外部状態を参照せず、常に同じ入力に対して同じ出力を返す
- `logic/`配下で`RandomNumberGenerator`等の乱数生成APIを直接呼び出していない

### テストチェックリスト

- [ ] **正常系**: 同一引数を渡した`calculate_quality`等の呼び出しが常に同じ結果を返す 🔵
- [ ] **異常系**: `features/alchemy/logic/`配下のソースを`grep`し、乱数生成APIの直接呼び出しがないことを確認する 🔵

---

## AC-014: [FR-002, FR-007] 初期解禁レシピ・RecipeMasterフィクスチャ 🔵

**関連**: FR-002, FR-007, US-005

### Given（前提条件）
- 新規ゲーム開始直後の状態（`GameState.reset_for_test()`相当）

### When（実行条件）
- `GameState`が初期化される

### Then（期待結果）
- `unlocked_recipe_ids`に`GameBalance.INITIAL_RECIPE_ID`（`&"recipe_healing_potion"`）が最低1件含まれる
- `recipe_healing_potion`の`RecipeMaster`フィクスチャが`base_contribution = 10.0, base_reward = 5.0`を持つ

### テストチェックリスト

- [ ] **正常系**: 初期化直後に`unlocked_recipe_ids.size() >= 1`である 🔵
- [ ] **正常系**: `recipe_healing_potion`が初期状態で調合実行可能（AC-009の正常系と一致）である 🔵

---

## AC-015: [FR-113] 実行失敗時のシグナル発行と状態不変 🔴

**関連**: FR-113, US-006, US-007, US-010

### Given（前提条件）
- AC-005〜AC-009いずれかの失敗条件を満たす入力

### When（実行条件）
- `GameState.execute_alchemy(recipe_id, material_instance_ids)`を呼び出す

### Then（期待結果）
- `execute_alchemy_failed(recipe_id, error_code)`シグナルが、対応する`error_code`とともに発行される
- `inventory`・`pending_products`はいずれも呼び出し前と完全に一致する

### テストチェックリスト

- [ ] **正常系**: 各失敗ケース（`unknown_recipe_id`, `recipe_not_unlocked`, `material_not_owned`, `duplicate_material_in_slot`, `slot_execution_invalid`）ごとにシグナルが期待通りの`error_code`で発行される 🔴
- [ ] **異常系**: シグナル発行と同時に`inventory`・`pending_products`が変化していないことをあわせて確認する 🔵

---

## 横断的受入基準

### パフォーマンス（NFR-001）

- [ ] `GameState.execute_alchemy`が`_process()`を用いず、呼び出し時の同期処理のみで完結する実装になっていることをコードレビューで確認する 🟡

### セキュリティ（NFR-101）

- [ ] 存在しない`recipe_id`または範囲外・不正な`material_instance_ids`を`execute_alchemy`に渡した場合、システムが失敗の`Result`を返しクラッシュしないことをテストする 🔵

### ユーザビリティ（NFR-201）

- [ ] 調合実行の5種類の失敗ケースそれぞれで異なる`error_code`が返ることを確認する（AC-015のテストチェックリストと重複確認） 🟡

### 保守性・アーキテクチャ整合性（NFR-301, NFR-302）

- [ ] `features/alchemy/`が`logic/`・`state/`・`resources/`の構成に従っていることを`gdlint`・ディレクトリ構成確認で検証する 🔵
- [ ] 他Featureのコードが`features/alchemy/state/`を直接`grep`で参照していないことを確認する（`logic/*.gd`・`resources/*.gd`・`shared/entities/product_instance.gd`のみ参照可） 🔵

### テスト容易性（NFR-401, NFR-402）

- [ ] `features/alchemy/logic/`配下の全public `static func`について、正常系・異常系・境界値のテストが最低1本ずつ存在することを数え上げで確認する 🔵
- [ ] `alchemy`関連のテストファイルが`tests/unit/features/alchemy/`または`tests/integration/`にのみ配置され、`features/alchemy/`配下に`test_*.gd`が存在しないことを確認する 🔵

---

## テストサマリー

| カテゴリ | 正常系 | 異常系 | 境界値 | 合計 |
|---------|--------|--------|--------|------|
| 機能要件（AC-001〜AC-015） | 17 | 13 | 11 | 41 |
| 非機能要件（横断的受入基準） | 5 | 0 | 0 | 5 |
| **合計** | 22 | 13 | 11 | 46 |

## 信頼性レベル分布

- 🔵 青信号: 14件 (93.3%)
- 🟡 黄信号: 0件 (0%)
- 🔴 赤信号: 1件 (6.7%): AC-015（GameStateシグナルの新規補完設計）

（AC-001〜AC-015の各基準見出しの信号機を集計。AC-015のみ🔴、他14件は🔵）
