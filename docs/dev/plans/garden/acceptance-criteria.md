# garden 受入基準

## 関連文書

- **要件定義**: [requirements.md](requirements.md)
- **ユーザーストーリー**: [user-stories.md](user-stories.md)

**【信頼性レベル凡例】**:
- 🔵 確実な基準
- 🟡 妥当な推測による基準
- 🔴 AI推論補完（要確認）

---

## AC-001: [FR-101, FR-102] 種を植える 🔵

**関連**: FR-101, FR-102, US-001

### Given（前提条件）
- 庭に空きスロットが1つ以上ある（`Planting.can_plant`が真）
- `seed_inventory`に対象`seed_id`（例: `seed_herb`）のエントリがあり`count >= 1`

### When（実行条件）
- プレイヤーが手持ちの種一覧から`seed_herb`を選択し、空きスロットへ植え付け操作を行う

### Then（期待結果）
- `GardenState.plants`に新規`PlantState(slot_index=空きスロット, seed_id="seed_herb", grown_turns=0, is_matured=false)`が追加される
- `seed_inventory`の`seed_herb.count`が1減算される

### テストチェックリスト

- [ ] **正常系**: 空きスロット・種在庫ありで植え付けが成功する 🔵
- [ ] **異常系**: 植え付け失敗時（AC-002/AC-003）に`GardenState`が変化しないことと合わせて確認する 🔵
- [ ] **境界値**: 残り1個の種を植えて`count`が0になる 🟡

---

## AC-002: [FR-109] 庭スロット満杯時の植え付け失敗 🔵

**関連**: FR-109, US-001

### Given（前提条件）
- `player.permanent_upgrades.garden_slot_count`分すべてのスロットが埋まっている（`Planting.can_plant`が偽）

### When（実行条件）
- プレイヤーが追加の種の植え付け操作を行う

### Then（期待結果）
- `Planting.plant`が失敗を表す`Result`を返す
- `GardenState.plants`・`seed_inventory`のいずれも変化しない
- UI（`GardenScreen`）はトースト等でフィードバックする（文言🟡仮）

### テストチェックリスト

- [ ] **正常系**: スロット満杯で植え付けが正しく拒否される 🔵
- [ ] **異常系**: 満杯状態でも既存の収穫可能スロットへの収穫操作には影響しない 🟡
- [ ] **境界値**: 残り1スロットのときは成功し、0スロットで失敗する 🔵

---

## AC-003: [FR-110] 種在庫切れ時の植え付け失敗 🔵

**関連**: FR-110, US-001

### Given（前提条件）
- `seed_inventory`に対象`seed_id`のエントリが存在しない、または`count == 0`

### When（実行条件）
- プレイヤーがその種を植え付けようとする

### Then（期待結果）
- `GameState.plant_seed`は`Planting.plant`を呼び出さずに失敗を返す
- `GardenState`・`seed_inventory`のいずれも変化しない

### テストチェックリスト

- [ ] **正常系**: `count == 0`で植え付けが失敗する 🔵
- [ ] **異常系**: `seed_inventory`に該当`seed_id`のエントリ自体が存在しない場合も同様に失敗する 🟡
- [ ] **境界値**: `count == 1`では成功する（AC-001と対で確認） 🔵

---

## AC-004: [FR-103] ターン終了時の生育進行と枯死判定の順序 🔵

**関連**: FR-103, US-003, US-006

### Given（前提条件）
- 庭に生育中の`PlantState`と、成熟済みで枯死猶予超過寸前の`PlantState`が混在する

### When（実行条件）
- `GameState.advance_turn_growth()`が呼ばれる

### Then（期待結果）
- 全生育中`PlantState`の`grown_turns`が`Harvest.advance_growth`で進行する
- その直後に必ず`Harvest.resolve_withering`が呼ばれ、枯死判定対象のスロットが除去される
- `advance_growth`より前に`resolve_withering`が呼ばれることはない

### テストチェックリスト

- [ ] **正常系**: 生育進行後に枯死株が正しく除去される 🔵
- [ ] **異常系**: 生育中スロットが0件でもエラーにならない 🟡
- [ ] **境界値**: 猶予ちょうど超過したターンで枯死し、超過前のターンでは枯死しない 🔵

---

## AC-005: [FR-104, FR-105, FR-106] 収穫成功時の品質確定と在庫追加 🔵

**関連**: FR-104, FR-105, FR-106, US-004

### Given（前提条件）
- 成熟直後（待機0ターン）の`PlantState`が存在する

### When（実行条件）
- プレイヤーが当該スロットへ収穫操作を行う

### Then（期待結果）
- `RngService`から品質用・特性用の乱数がそれぞれ払い出され`Harvest.harvest`に渡される
- 品質は`SeedMaster.base_quality`で確定する
- `TraitRoll.roll_trait`の結果を含む`MaterialInstance`が`inventory`に追加される
- 該当スロットが`GardenState.plants`から除去される

### テストチェックリスト

- [ ] **正常系**: 待機0ターンで収穫し`quality_score == base_quality`になる 🔵
- [ ] **異常系**: 収穫後に同じ`slot_index`を再度収穫しようとすると失敗する（スロットが既に存在しない） 🟡
- [ ] **境界値**: `base_quality`が最小値(1)/最大値(5)の種でもクランプされずそのまま反映される 🟡

---

## AC-006: [FR-107] 待機による品質上昇 🟡

**関連**: FR-107, US-005

### Given（前提条件）
- 成熟済み`PlantState`があり、プレイヤーが収穫せず1ターン以上待機する

### When（実行条件）
- 待機1ターンごとに品質上昇判定用の乱数が`GameBalance.QUALITY_UP_CHANCE`未満の値で払い出された状態で収穫する

### Then（期待結果）
- 品質が`base_quality`から1段階上昇し、上限S（`quality_score == 5`）でクランプされる

### テストチェックリスト

- [ ] **正常系**: 判定用乱数が`QUALITY_UP_CHANCE`未満で品質が+1される 🟡
- [ ] **異常系**: 判定用乱数が`QUALITY_UP_CHANCE`以上で品質が変化しない 🟡
- [ ] **境界値**: 既に`quality_score == 5`の状態でさらに上昇判定が成功しても5を超えない 🔵

---

## AC-007: [FR-108] 枯死株の収穫失敗 🔵

**関連**: FR-108, US-004

### Given（前提条件）
- `Harvest.is_dead`が真の`PlantState`が存在する

### When（実行条件）
- プレイヤーがそのスロットへ収穫操作を行う

### Then（期待結果）
- `Harvest.harvest`が失敗を表す`Result`を返す
- `GardenState`・`inventory`はいずれも変化しない

### テストチェックリスト

- [ ] **正常系**: `is_dead == true`のスロットで収穫が失敗する 🔵
- [ ] **異常系**: 失敗時に`MaterialInstance`が生成されないことを確認する 🔵
- [ ] **境界値**: 枯死猶予ちょうど（超過1ターン前）は`is_dead == false`で収穫が成功する 🟡

---

## AC-008: [FR-111] 枯死の自動検出とスロット解放 🔵

**関連**: FR-111, US-006

### Given（前提条件）
- 成熟後`SeedMaster.death_grace_turns`を超えて未収穫の`PlantState`が存在する

### When（実行条件）
- ターン終了処理で`Harvest.resolve_withering`が呼ばれる

### Then（期待結果）
- 該当`PlantState`が`GardenState.plants`から除去され、スロットが空きに戻る
- プレイヤーの収穫操作は不要（自動処理のみで完結する）

### テストチェックリスト

- [ ] **正常系**: 猶予超過株が自動的に除去される 🔵
- [ ] **異常系**: 猶予超過株が複数同時に存在しても全て正しく除去される 🟡
- [ ] **境界値**: 猶予をちょうど超過した直後のターンで除去される 🔵

---

## AC-009: [FR-205] 降格時の庭資産維持 🔵

**関連**: FR-205, US-008

### Given（前提条件）
- `garden_state.plants`・`inventory`・`seed_inventory`に既存データがある

### When（実行条件）
- プレイヤーが降格する（降格処理自体はRankSystem側、本plan外）

### Then（期待結果）
- `garden_state.plants`・`inventory`・`seed_inventory`はいずれも降格前の内容のまま変化しない

### テストチェックリスト

- [ ] **正常系**: `GameState.reset_for_test()`以外の経路では庭関連状態がクリアされないことを確認する 🔵
- [ ] **異常系**: 誤って庭状態をリセットする実装が混入していないことをテストで検出する 🟡

---

## AC-010: [FR-201, FR-202, FR-203, FR-204] 庭スロットの4状態表示 🔵

**関連**: FR-201, FR-202, FR-203, FR-204, US-002, US-006

### Given（前提条件）
- 空き/生育中/収穫可能/枯死警告の各状態に対応する`PlantState`（または空きスロット）が`GardenScreen`に渡される

### When（実行条件）
- `GardenScreen`が描画される

### Then（期待結果）
- 各スロットが対応する状態を色・アイコン・テキストの併記で表示する
- 収穫可能スロットのみ収穫ボタン（`btn-harvest-{slot_id}`）が有効化される

### テストチェックリスト

- [ ] **正常系**: 4状態それぞれが正しい見た目・ボタン有効状態で表示される 🔵
- [ ] **異常系**: マスターデータに存在しない`seed_id`を参照する`PlantState`が渡されてもクラッシュしない 🟡
- [ ] **境界値**: 枯死警告閾値ちょうどで警告表示に切り替わる 🟡

---

## AC-011: [CON-007, CON-008] 初期状態（ゲーム開始時）の庭・手持ち種 🔵

**関連**: FR-001, US-001

### Given（前提条件）
- 新規ゲーム開始直後の状態

### When（実行条件）
- `GameState`が初期化される

### Then（期待結果）
- `garden_state.plants`は空配列で初期化される
- `seed_inventory`は本plan内で仮決めした初期セット（例: `seed_herb` × 2 等）で初期化される
- `SeedMaster`定義に`seed_herb`（早熟、`maturity_turns` 1〜2）・`seed_ore`（晩成、`maturity_turns` 4〜5）の2種が存在する

### テストチェックリスト

- [ ] **正常系**: 初期化直後に`garden_state.plants`が空配列である 🔵
- [ ] **正常系**: 初期化直後に`seed_inventory`が仮決めした初期セットと一致する 🔵
- [ ] **境界値**: `seed_herb`/`seed_ore`の`maturity_turns`がそれぞれ仮決めした範囲内である 🟡

---

## AC-012: [FR-301, FR-405] ショップ導線ボタンのプレースホルダー動作 🔵

**関連**: FR-301, FR-405, US-007

### Given（前提条件）
- `GardenScreen`が表示されている

### When（実行条件）
- プレイヤーが`btn-shop`を押下する

### Then（期待結果）
- ショップ遷移を意図したシグナルのみが発行される
- 実際の購入処理・画面遷移ロジックは本plan内に実装されていない

### テストチェックリスト

- [ ] **正常系**: `btn-shop`押下でシグナルが発行される 🔵
- [ ] **異常系**: `btn-shop`押下が`GardenState`等の状態を変化させない 🔵

---

## AC-013: [FR-401, FR-402] Domain層の純粋性・乱数受け渡し 🔵

**関連**: FR-401, FR-402

### Given（前提条件）
- `Planting`・`Harvest`・`TraitRoll`の各`static func`の実装

### When（実行条件）
- 同一引数でユニットテストを複数回実行する、およびコードを静的に検査する

### Then（期待結果）
- いずれの関数も`GameState`等の外部状態を参照せず、常に同じ入力に対して同じ出力を返す
- 乱数は`RngService`が払い出した値を引数として受け取っており、`logic/`配下で`RandomNumberGenerator`等を直接インスタンス化していない

### テストチェックリスト

- [ ] **正常系**: 同一引数を渡した`Harvest.harvest`等の呼び出しが常に同じ結果を返す（純粋関数の性質をユニットテストで検証） 🔵
- [ ] **異常系**: `logic/`配下のソースを`grep`し、乱数生成APIの直接呼び出しがないことを確認する 🔵

---

## AC-014: [FR-403] GameState.get_state()の防御的コピー 🔵

**関連**: FR-403

### Given（前提条件）
- `GameState`が`garden_state`・`seed_inventory`・`inventory`に既存データを保持している

### When（実行条件）
- 呼び出し元が`GameState.get_state()`の戻り値の`garden_state.plants`（`Array`）に対し`append`等の変更操作を行う

### Then（期待結果）
- `GameState`内部の実際の`garden_state.plants`は変化しない（`duplicate(true)`によるディープコピーが機能している）

### テストチェックリスト

- [ ] **正常系**: 戻り値を変更しても`GameState`内部状態が変化しないことをテストで確認する 🔵
- [ ] **境界値**: `PlantState`が保持するネストした配列（`MaterialInstance.trait_tags`相当）まで独立コピーされている 🟡

---

## 横断的受入基準

### パフォーマンス（NFR-001）

- [ ] `GardenScreen`・`PlantCard`等が`_process()`を定義しておらず、`GameState`のsignal駆動のみでUI更新される実装になっていることをコードレビューで確認する 🟡

### セキュリティ（NFR-101）

- [ ] 存在しない`seed_id`または範囲外の`slot_index`を`plant_seed`/`harvest`に渡した場合、システムが失敗の`Result`を返しクラッシュしないことをテストする 🟡

### ユーザビリティ（NFR-201, NFR-202）

- [ ] 枯死警告状態が色だけでなくアイコン・テキストでも判別できることを確認する 🔵
- [ ] 植え付け失敗（スロット満杯・種在庫切れ）時にトースト等の視覚的フィードバックが表示されることを確認する 🟡

### 保守性・アーキテクチャ整合性（NFR-301, NFR-302）

- [ ] `features/garden/`が`logic/`・`state/`・`resources/`・`ui/`の構成に従っていることを`gdlint`・ディレクトリ構成確認で検証する 🔵
- [ ] 他Featureのコードが`features/garden/state/`・`features/garden/ui/`を直接`grep`で参照していないことを確認する（`logic/*.gd`・`resources/*.gd`のみ参照可） 🔵

### テスト容易性（NFR-401, NFR-402）

- [ ] `features/garden/logic/`配下の全public `static func`について、正常系・異常系・境界値のテストが最低1本ずつ存在することを数え上げで確認する 🔵
- [ ] `garden`関連のテストファイルが`tests/unit/features/garden/`または`tests/integration/`にのみ配置され、`features/garden/`配下に`test_*.gd`が存在しないことを確認する 🔵

---

## テストサマリー

| カテゴリ | 正常系 | 異常系 | 境界値 | 合計 |
|---------|--------|--------|--------|------|
| 機能要件（AC-001〜AC-014） | 15 | 12 | 11 | 38 |
| 非機能要件（横断的受入基準） | 5 | 3 | 0 | 8 |
| **合計** | 20 | 15 | 11 | 46 |

## 信頼性レベル分布

- 🔵 青信号: 13件 (92.9%)
- 🟡 黄信号: 1件 (7.1%)
- 🔴 赤信号: 0件 (0%)

（AC-001〜AC-014の各基準見出しの信号機を集計。AC-006のみ🟡、他13件は🔵）
