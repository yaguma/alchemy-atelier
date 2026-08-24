# workshop-ui 受入基準

## 関連文書

- **要件定義**: [requirements.md](requirements.md)
- **ユーザーストーリー**: [user-stories.md](user-stories.md)

**【信頼性レベル凡例】**:
- 🔵 確実な基準
- 🟡 妥当な推測による基準
- 🔴 AI推論補完（要確認）

---

## AC-001: [FR-001, FR-003, FR-005, FR-006] 画面の基本表示 🔵

**関連**: FR-001, FR-003, FR-005, FR-006, US-001, US-002

### Given（前提条件）
- `GameState.reset_for_test()`済みで、`load_workshop_master_data()`によりマスターデータがロードされている

### When（実行条件）
- `scene_runner("res://features/workshop/ui/workshop_screen.tscn")`で`WorkshopScreen`をシーンツリーへ追加する

### Then（期待結果）
- 恒久投資タブ（`tab-permanent`相当）と消耗投資タブ（`tab-consumable`相当）が両方表示される
- 各アイテム行に名称・価格・購入ボタンが表示される
- 閉じるボタンが常時表示される
- 所持ゴールド表示（`txt-gold`相当）が`GameState.get_state()["gold"]`と一致する

### テストチェックリスト

- [ ] **正常系**: `data/upgrades/`の5件（`upgrade_alchemy_slot`等）が読み込まれた状態でシーンを開き、恒久タブに3件・消耗タブに2件のアイテム行が表示される 🔵
- [ ] **異常系**: `upgrade_masters`が空の`Dictionary`の場合でもクラッシュせず、アイテム行0件・タブ自体は表示された状態になる 🟡
- [ ] **境界値**: 所持ゴールドが0の場合でも`txt-gold`相当の表示が例外なく描画される 🟡

---

## AC-002: [FR-007, FR-008] GameState.get_state()のフィールド拡張 🔵

**関連**: FR-007, FR-008, US-001, US-103

### Given（前提条件）
- `GameState.reset_for_test()`後、`load_workshop_master_data()`でマスターをロードし、`_set_purchased_upgrade_counts_for_test({&"upgrade_catalyst": 1})`で購入済みカウントを注入する

### When（実行条件）
- `GameState.get_state()`を呼び出す

### Then（期待結果）
- 戻り値に`"upgrade_masters"`キーが存在し、`Dictionary[StringName, UpgradeMaster]`として全マスターを含む
- 戻り値に`"purchased_upgrade_counts"`キーが存在し、`{&"upgrade_catalyst": 1}`を含む
- 取得した`Dictionary`を呼び出し元で書き換えても、再度`get_state()`した結果に影響しない（防御的コピー）

### テストチェックリスト

- [ ] **正常系**: `get_state()["upgrade_masters"]`のサイズが`load_workshop_master_data()`でロードした件数と一致する 🔵
- [ ] **正常系**: `get_state()["purchased_upgrade_counts"]`が注入した値と一致する 🔵
- [ ] **異常系**: `get_state()["upgrade_masters"]`に対し`.erase()`等の破壊的操作を行った後、再度`get_state()`しても`GameState`内部の`_upgrade_masters`は影響を受けない 🔵

---

## AC-003: [FR-004] 価格降順ソート順序 🔵

**関連**: FR-004, US-001

### Given（前提条件）
- `data/upgrades/`の5件（恒久: `upgrade_alchemy_slot`(2000), `upgrade_garden_slot`(800), `upgrade_recipe_unlock_mana_tonic`(800)、消耗: `upgrade_catalyst`(150), `upgrade_seed_name_purchase_ore`(50)）がロード済み

### When（実行条件）
- `WorkshopScreen`を表示する

### Then（期待結果）
- 恒久投資タブのアイテム順序が「投入枠+1(2000) → 庭拡張(800) → レシピ解禁(800)」（同価格800はid文字列昇順でタイブレーク）になる
- 消耗投資タブのアイテム順序が「触媒(150) → 種の指名買い(50)」になる

### テストチェックリスト

- [ ] **正常系**: 恒久投資タブの1行目が`upgrade_alchemy_slot`（価格2000）であることを確認する 🔵
- [ ] **境界値**: 同価格800の`upgrade_garden_slot`と`upgrade_recipe_unlock_mana_tonic`が、id文字列昇順（`upgrade_garden_slot` < `upgrade_recipe_unlock_mana_tonic`）で並ぶことを確認する 🔵
- [ ] **異常系**: タブ区分（`is_permanent`）が混在しても、恒久投資タブに消耗投資アイテムが混入しないことを確認する 🟡

---

## AC-004: [FR-105, FR-201, FR-202] 恒久投資タブの活性/非活性切替 🔵

**関連**: FR-105, FR-201, FR-202, US-003

### Given（前提条件）
- `GameState.reset_for_test()`済みで`load_workshop_master_data()`実行済み

### When（実行条件）
- ケースA: `_set_can_purchase_permanent_for_test(true)`後に`WorkshopScreen`を表示する
- ケースB: `_set_can_purchase_permanent_for_test(false)`後に`WorkshopScreen`を表示する

### Then（期待結果）
- ケースAでは恒久投資タブが活性状態（選択・購入操作可能）で表示される
- ケースBでは恒久投資タブが非活性状態（選択不可、または選択できてもボタンがすべて無効）で表示される

### テストチェックリスト

- [ ] **正常系**: ケースAで恒久投資タブの購入ボタンが`disabled == false`になり得る状態であることを確認する 🔵
- [ ] **正常系**: ケースBで恒久投資タブの全購入ボタンが`disabled == true`になることを確認する 🔵
- [ ] **境界値**: `_set_can_purchase_permanent_for_test(true)`→`false`へ変化した直後に画面が再構築され、活性状態が即座に非活性へ切り替わることを確認する 🟡

---

## AC-005: [FR-203] 消耗投資タブの常時活性 🔵

**関連**: FR-203, US-003

### Given（前提条件）
- `_set_can_purchase_permanent_for_test(false)`（恒久投資タブが非活性の状態）

### When（実行条件）
- `WorkshopScreen`を表示し、消耗投資タブのアイテムを確認する

### Then（期待結果）
- 消耗投資タブは恒久投資タブの状態に関わらず常に選択・操作可能である

### テストチェックリスト

- [ ] **正常系**: `can_purchase_permanent`がfalseでも消耗投資タブのアイテム行・購入ボタンが表示・操作可能であることを確認する 🔵
- [ ] **異常系**: `can_purchase_permanent`がtrueの場合でも消耗投資タブの活性状態に変化がないことを確認する 🟡

---

## AC-006: [FR-204, FR-206] 購入可能/購入不可（ゴールド不足）の表示切替 🔵

**関連**: FR-204, FR-206, US-101, US-103

### Given（前提条件）
- `GameState.reset_for_test()`後、`load_workshop_master_data()`実行済み。所持ゴールドを対象アイテムの価格未満に設定する（`GameState`のゴールド操作用テストAPIまたは既存の`add_gold`/`spend_gold`で調整）

### When（実行条件）
- `WorkshopScreen`を表示する

### Then（期待結果）
- 所持ゴールドが価格未満のアイテムは購入ボタンが無効化され、「ゴールド不足」を示す表示になる
- 所持ゴールドが価格以上（かつ未購入上限内）のアイテムは購入ボタンが有効化され「購入する」ラベルになる

### テストチェックリスト

- [ ] **正常系**: 所持ゴールド >= 価格のアイテムの購入ボタンが有効（`disabled == false`）かつラベルが「購入する」であることを確認する 🔵
- [ ] **異常系**: 所持ゴールド < 価格のアイテムの購入ボタンが無効（`disabled == true`）かつ「ゴールド不足」を示すテキストが表示されることを確認する 🔵
- [ ] **境界値**: 所持ゴールド == 価格ちょうどのとき、購入可能（無効化されない）と判定されることを確認する（`PurchaseValidator.can_purchase`は`gold >= price`） 🔵

---

## AC-007: [FR-205, FR-206] 購入可能/購入済み（上限到達）の表示切替 🔵

**関連**: FR-205, FR-206, US-103

### Given（前提条件）
- `GameState.reset_for_test()`後、`load_workshop_master_data()`実行済み。`_set_purchased_upgrade_counts_for_test({<対象id>: <max_purchase_count>})`で上限到達状態を注入する

### When（実行条件）
- `WorkshopScreen`を表示する

### Then（期待結果）
- 購入済み回数が`max_purchase_count`以上のアイテムは購入ボタンが無効化され「購入済み」を示す表示になる
- 上限未到達のアイテムは通常通り購入可能表示になる

### テストチェックリスト

- [ ] **正常系**: 購入済み回数が上限未満のアイテムの購入ボタンが有効であることを確認する 🔵
- [ ] **異常系**: 購入済み回数が`max_purchase_count`と同値のアイテムの購入ボタンが無効化され「購入済み」表示になることを確認する 🔵
- [ ] **境界値**: 購入済み回数が`max_purchase_count - 1`（上限直前）のアイテムはまだ購入可能表示であることを確認する 🟡

---

## AC-008: [FR-101, FR-102] 購入成功時のトースト表示と一覧再構築 🔵

**関連**: FR-101, FR-102, US-101

### Given（前提条件）
- `GameState.reset_for_test()`後、`load_workshop_master_data()`実行済み。対象アイテムが購入可能な状態（ゴールド充足・上限未到達）にする

### When（実行条件）
- 対象アイテムの購入ボタンを押下する

### Then（期待結果）
- `GameState.apply_upgrade(upgrade)`が呼び出され、戻り値`Result`が成功（ok）を返す
- アイテム一覧が再構築され、購入済み回数・所持ゴールドの変化が反映される（上限到達していれば「購入済み」表示へ切り替わる）
- 成功を示すトーストメッセージが表示される

### テストチェックリスト

- [ ] **正常系**: 購入後、`GameState.get_state()["gold"]`が価格分減少し、`get_purchased_count(upgrade.id)`が1増加していることを確認する 🔵
- [ ] **正常系**: 購入後のトーストメッセージ（`get_toast_text()`相当）に成功を示す文言が含まれることを確認する 🔵
- [ ] **境界値**: `max_purchase_count == 1`のアイテムを購入した直後、当該アイテムの購入ボタンが即座に「購入済み」表示へ切り替わることを確認する 🟡

---

## AC-009: [FR-101, FR-103] 購入失敗時のトースト表示 🔵

**関連**: FR-101, FR-103, US-102

### Given（前提条件）
- `GameState.reset_for_test()`後、`load_workshop_master_data()`実行済み。恒久投資アイテムかつ`_set_can_purchase_permanent_for_test(false)`（恒久投資購入不可）の状態にする

### When（実行条件）
- UI側の無効化を回避して`apply_upgrade()`相当の購入操作をトリガーする、またはUIの購入ハンドラを直接呼び出す（`workshop_closed`エラーを発生させる）

### Then（期待結果）
- `GameState.apply_upgrade(upgrade)`の戻り値`Result`が失敗（fail）を返す
- アイテム一覧は再構築されない（所持ゴールド・購入済み回数に変化がない）
- 失敗を示すトーストメッセージ（エラーコードを含む）が表示される

### テストチェックリスト

- [ ] **正常系**: `workshop_closed`エラーで失敗した場合、トーストメッセージにエラーコード（またはそれに対応する日本語文言）が含まれることを確認する 🔵
- [ ] **異常系**: 失敗後も`GameState.get_state()["gold"]`が変化していないことを確認する（状態変更なしのアトミック性） 🔵
- [ ] **境界値**: `cannot_purchase`（ゴールド不足で通過した場合）・`invalid_effect`など複数のエラーコードそれぞれでトースト表示が破綻しないことを確認する 🟡

---

## AC-010: [FR-104] 閉じるボタンでのclose_workshop()呼び出しとscreen_closed発行 🟡

**関連**: FR-104, US-201

### Given（前提条件）
- `GameState.reset_for_test()`後、`_set_can_purchase_permanent_for_test(true)`（恒久投資強制表示中を模した状態）にする

### When（実行条件）
- 閉じるボタンを押下する

### Then（期待結果）
- `GameState.close_workshop()`が呼び出され、`GameState.get_state()["can_purchase_permanent"]`がfalseになる
- `WorkshopScreen.screen_closed`シグナルが発行される

### テストチェックリスト

- [ ] **正常系**: 閉じるボタン押下後、`GameState.get_state()["can_purchase_permanent"]`がfalseになっていることを確認する 🟡
- [ ] **正常系**: `monitor_signals(workshop_screen, false)`後、閉じるボタン押下で`screen_closed`が発行されることを`assert_signal`で確認する 🟡
- [ ] **異常系**: 通常アクセス（`can_purchase_permanent`が既にfalse）の状態で閉じるボタンを押下しても、`close_workshop()`が副作用なく呼べる（冪等性、エラーにならない）ことを確認する 🟡

---

## AC-011: [FR-401] MainScene統合・shop_requested接続の非実施 🔵

**関連**: FR-401

### Given（前提条件）
- 本Planの実装完了時点のコードベース

### When（実行条件）
- `GardenScreen`, `AlchemyScreen`, `MainScene`のソースを確認する

### Then（期待結果）
- `GardenScreen.shop_requested` / `AlchemyScreen.shop_requested`から`WorkshopScreen`への`connect()`呼び出しが存在しない
- `MainScene`（`main.tscn`/`main.gd`）に`WorkshopScreen`のインスタンス化・組み込みが存在しない

### テストチェックリスト

- [ ] **正常系**: `Grep`で`shop_requested.*connect`および`WorkshopScreen`のインスタンス化箇所を検索し、`GardenScreen`/`AlchemyScreen`/`MainScene`内にヒットしないことを確認する 🔵
- [ ] **異常系**: レビュー時点で誤って接続コードが混入していた場合、CIやレビューで検出できるよう`WorkshopScreen`のシーンファイルが独立して`scene_runner()`から起動可能であることを確認する（依存が疎結合であることの裏付け） 🟡

---

## AC-012: [FR-402] get_state()戻り値の防御的コピー 🔵

**関連**: FR-402, US-001, US-103

### Given（前提条件）
- `GameState.reset_for_test()`後、`load_workshop_master_data()`実行済み

### When（実行条件）
- `var state := GameState.get_state()`で取得した`state["upgrade_masters"]`または`state["purchased_upgrade_counts"]`に対し、キーの追加・削除・値の書き換えを行う

### Then（期待結果）
- 再度`GameState.get_state()`を呼び出した結果には、上記の書き換えが一切反映されない（`GameState`内部の`_upgrade_masters`/`_purchased_upgrade_counts`が保護されている）

### テストチェックリスト

- [ ] **正常系**: `state["purchased_upgrade_counts"][&"dummy"] = 999`のように書き換えても、再取得した`get_state()`の値に`dummy`キーが存在しないことを確認する 🔵
- [ ] **異常系**: `state["upgrade_masters"].clear()`しても、再取得した`get_state()["upgrade_masters"]`のサイズが元のマスター件数のままであることを確認する 🔵

---

## AC-013: [FR-403, FR-404] 購入不可理由の区別（ゴールド不足 vs 購入済み）とタブ非活性中の恒久投資保護 🔵

**関連**: FR-403, FR-404, US-101, US-103

### Given（前提条件）
- `GameState.reset_for_test()`後、`load_workshop_master_data()`実行済み。以下2つの状態を用意する
  - 状態X: 恒久投資アイテムのうち1件をゴールド不足の状態にする
  - 状態Y: 恒久投資アイテムのうち1件を購入済み上限到達の状態にする（`_set_purchased_upgrade_counts_for_test`）

### When（実行条件）
- 状態X・状態Yそれぞれで`WorkshopScreen`を表示する

### Then（期待結果）
- 状態Xと状態Yで、当該アイテム行の表示テキスト（「ゴールド不足」/「購入済み」）が異なる
- `can_purchase_permanent`がfalseの間は、上記の判定結果に関わらず恒久投資アイテムの購入ボタンがすべて無効化される（FR-403優先）

### テストチェックリスト

- [ ] **正常系**: 状態Xと状態Yで表示テキストが一致しない（同一の「購入不可」に丸められていない）ことを確認する 🔵
- [ ] **異常系**: `can_purchase_permanent == true`かつ状態X（ゴールド不足）の場合でも、当該アイテムの購入ボタンは無効化されたままであることを確認する（3状態のうちゴールド不足が優先される） 🟡
- [ ] **境界値**: `can_purchase_permanent == false`かつ本来ならゴールド充足・未購入で「購入可能」なはずのアイテムでも、タブ非活性の間は購入ボタンが無効化されることを確認する 🔵

---

## 横断的受入基準

### パフォーマンス（NFR-001）

- [ ] アイテム一覧の再構築（購入成功後）が既存パターン（全行破棄→再生成）を踏襲し、フリーズ等の体感遅延を発生させないことを目視確認する 🟡

### セキュリティ（NFR-101）

- [ ] UI側でボタンを無効化していても、`apply_upgrade()`側で`PurchaseValidator.can_purchase`による再検証が行われ、UIの判定をバイパスした呼び出しでも不正な購入が成立しないことをGdUnit4テストで確認する（AC-009関連） 🔵

### アクセシビリティ（NFR-201）

- [ ] 購入不可の3状態（購入可能/ゴールド不足/購入済み）が、色のみに依存せずテキストラベルの違いで判別可能であることを確認する（AC-006, AC-007, AC-013で検証済み） 🔵

---

## テストサマリー

| カテゴリ | 正常系 | 異常系 | 境界値 | 合計 |
|---------|--------|--------|--------|------|
| 機能要件（AC-001〜AC-013） | 15 | 12 | 9 | 36 |
| 非機能要件（横断的受入基準） | 0 | 0 | 0 | 3（チェックリスト形式、系統分類なし） |
| **合計** | 15 | 12 | 9 | 39 |

## 信頼性レベル分布

- 🔵 青信号: 10件 (77%)
- 🟡 黄信号: 3件 (23%)
- 🔴 赤信号: 0件 (0%)

（AC単位の分布。個別テストチェックリスト項目単位の内訳は各AC節を参照）
