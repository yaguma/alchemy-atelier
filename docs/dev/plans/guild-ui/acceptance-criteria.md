# guild-ui 受入基準

## 関連文書

- **要件定義**: [requirements.md](requirements.md)
- **ユーザーストーリー**: [user-stories.md](user-stories.md)

**【信頼性レベル凡例】**:
- 🔵 確実な基準
- 🟡 妥当な推測による基準
- 🔴 AI推論補完（要確認）

---

## AC-001: [FR-001, FR-003, FR-005, FR-008, FR-101] 単一調合物の納品結果表示 🔵

**関連**: FR-001, FR-003, FR-005, FR-008, FR-101, US-001

### Given（前提条件）
- `GuildDeliveryScreen`がシーンツリーに追加され`_ready()`が完了している
- `GameState.reset_for_test()`で初期化済み、`recipe_masters`に対象レシピの`RecipeMaster`（`name`設定済み）が登録されている（`GuildDeliveryScreen`は`CON-005`に従い`recipe_id`→表示名の解決を`GameState.get_state()["recipe_masters"]`経由で行う）
- `ProductInstance`（`recipe_id`, `quality_score`, `activated_traits`設定済み）1件と、対応する`DeliveryResult`1件をテストコード側で用意する

### When（実行条件）
- `guild_delivery_screen.display_results([product], [delivery_result])`を直接呼び出す

### Then（期待結果）
- `GuildDeliveryScreen`のリストに1項目が表示される
- 表示された調合物名が対象`RecipeMaster.name`と一致する
- 表示された品質・発現特性が`ProductInstance.quality_score` / `activated_traits`と一致する
- 表示された貢献度・報酬が`DeliveryResult.final_contribution` / `final_reward`と一致する

### テストチェックリスト

- [ ] **正常系**: 1件納品時にリストへ1項目追加され、全フィールドが一致する 🔵
- [ ] **異常系**: `recipe_masters`に対応する`RecipeMaster`が存在しない`recipe_id`の場合、クラッシュせず「不明な調合物」等のフォールバック名で表示される 🔴
- [ ] **境界値**: `activated_traits`が0件の場合、`AlchemyPreviewPanel`と同様に「なし」等のプレースホルダーテキストが表示される 🟡

---

## AC-002: [FR-002, FR-004] 複数件納品時のリスト表示と合計値 🔵

**関連**: FR-002, FR-004, US-001, US-002

### Given（前提条件）
- 貢献度・報酬が異なる3件の`ProductInstance`と、対応する3件の`DeliveryResult`をテストコード側で用意する

### When（実行条件）
- `guild_delivery_screen.display_results(products, results)`（3件ずつ）を直接呼び出す

### Then（期待結果）
- リストに3項目が表示される
- 合計貢献度が3件の`final_contribution`の総和と一致する
- 合計報酬が3件の`final_reward`の総和と一致する

### テストチェックリスト

- [ ] **正常系**: 3件納品時に合計貢献度・合計報酬が総和と一致する 🔵
- [ ] **異常系**: 該当なし（`display_results()`は戻り値を持たず失敗しない仕様のため） 🔵
- [ ] **境界値**: 1件のみでもリスト・合計値が正しく表示される 🟡
- [ ] **境界値**: 同一`recipe_id`が複数件含まれていても、項目が個別に（合算されず）表示される 🟡

---

## AC-003: [FR-201, FR-202] 指定依頼合致/不合致の表示分岐 🔵

**関連**: FR-201, FR-202, US-003

### Given（前提条件）
- 指定依頼に合致する調合物1件（`order_matched == true`）と、合致しない調合物1件（`order_matched == false`）に対応する`DeliveryResult`をテストコード側で用意する
- （異常系用）`daily_order`が`null`の状態で`DeliveryResolver.resolve()`を呼んだ結果（`order_matched == false`固定）の`DeliveryResult`を用意する

### When（実行条件）
- `guild_delivery_screen.display_results(products, results)`を呼び出す

### Then（期待結果）
- `order_matched == true`の項目には合致テキスト（例:「指定合致」）が表示される
- `order_matched == false`の項目には合致テキストが表示されない

### テストチェックリスト

- [ ] **正常系**: 合致した項目に合致テキストが表示される 🔵
- [ ] **正常系**: 合致しなかった項目に合致テキストが表示されない 🔵
- [ ] **異常系**: `daily_order`が`null`（試験中相当）の場合、全件が不合致表示になる（`DeliveryResolver.matches_order`の`daily_order == null`ガードと整合） 🔵

---

## AC-004: [FR-301, FR-302, CON-001, CON-002] ノルマバー表示とGameState新規APIの利用 🟡

**関連**: FR-301, FR-302, CON-001, CON-002, US-101

### Given（前提条件）
- `GameState.get_current_rank_master()`が返す`RankMaster`が`quota_max = 100.0`, `display_name = "見習い"`を持つ
- `GameState.get_current_rank_quota()`が`40.0`を返す（`GuildDeliveryScreen`はこの2つのAPIのみを呼び、`GameState.get_state()["rank_state"]`や`RankState`型を一切参照しない、CON-005遵守）

### When（実行条件）
- `GuildDeliveryScreen`が表示（`_ready()`または`display_results()`呼び出しに伴う`_refresh_rank_quota()`相当の更新処理が実行）される

### Then（期待結果）
- ノルマバーが`quota / quota_max`（この例では40%）を反映した表示になる
- ランク表示名が`display_name`（「見習い」）と一致する

### テストチェックリスト

- [ ] **正常系**: `quota`/`quota_max`の比率どおりにバーが表示される 🟡
- [ ] **異常系**: 現在ランクの`RankMaster`が未ロード（`_rank_masters`に存在しない）場合、CON-002のフォールバック（`quota_max = 0.0`）が返り、0除算エラーを起こさずバーが空表示になる 🔴
- [ ] **境界値**: `quota == 0.0`（ノルマ達成済み）でバーが空になる／`quota == quota_max`でバーが満タンになる 🟡

---

## AC-005: [FR-102, FR-402] 閉じるボタン押下でのシグナル発行 🟡

**関連**: FR-102, FR-402, US-201

### Given（前提条件）
- `GuildDeliveryScreen`が表示中で、納品結果が表示されている

### When（実行条件）
- 「閉じる/続ける」ボタン（`btn-continue`相当）が押下される

### Then（期待結果）
- 画面遷移導線を表す`signal`（例: `screen_closed`）が1回発行される
- `GameState`の状態（ゴールド・ノルマ・在庫等）は一切変更されない
- `GuildDeliveryScreen`自身はシーン遷移・visible切り替えを一切実行しない（FR-402）

### テストチェックリスト

- [ ] **正常系**: ボタン押下で導線シグナルが1回発行される 🟡
- [ ] **異常系**: 該当なし（ボタン押下に伴うGameState副作用が存在しないため） 🔵
- [ ] **境界値**: 連続で2回押下しても`GameState`への副作用が発生しないこと（シグナル発行回数はボタンの`disabled`制御方針に依存するため本plan内では厳密固定しない） 🟡

---

## AC-006: [FR-007, FR-008, FR-101, CON-003, CON-004] display_results()のindex対応と実結合統合テスト 🔵

**関連**: FR-007, FR-008, FR-101, CON-003, CON-004, US-301

### Given（前提条件）
- 単体テスト（ユニット）: `RECIPE_A`, `RECIPE_B`にそれぞれ対応する`ProductInstance`2件と`DeliveryResult`2件をテストコード側で直接構築する
- 統合テスト: `GameState.reset_for_test()`で初期化済み、`RECIPE_A`→`execute_alchemy()`, `RECIPE_B`→`execute_alchemy()`の順で`pending_products`に2件積む

### When（実行条件）
- 単体テスト: `guild_delivery_screen.display_results([product_a, product_b], [result_a, result_b])`を直接呼び出す
- 統合テスト: `AlchemyScreen._on_end_turn_pressed()`と同じ手順（`GameState.get_state()["pending_products"]`のスナップショット取得 → `GameState.deliver_pending_products()` → 戻り値とスナップショットを`guild_delivery_screen.display_results()`へ渡す）を実行する

### Then（期待結果）
- リストの1件目が`RECIPE_A`の`RecipeMaster.name`・品質・発現特性と対応する
- リストの2件目が`RECIPE_B`の`RecipeMaster.name`・品質・発現特性と対応する
- `get_item_count()`（FR-007）が2を返す

### テストチェックリスト

- [ ] **正常系**: 2件を異なるレシピで`display_results()`に直接渡し、投入順どおりに正しく対応付けられる（ユニットテスト） 🔵
- [ ] **正常系**: `AlchemyScreen`実装経由（スナップショット取得→`deliver_pending_products()`→`display_results()`）でも同様に対応付けられる（統合テスト、CON-003の実現方式そのものを検証する） 🔵
- [ ] **境界値**: `products`と`results`がともに空配列で`display_results([], [])`が呼ばれた場合、リストが0件になり例外が発生しない 🟡

---

## AC-007: [FR-005, FR-405, CON-005] アーキテクチャ制約の遵守 🔵

**関連**: FR-005, FR-405, CON-005, US-001

### Given（前提条件）
- `GuildDeliveryScreen`および関連コンポーネントの実装コード一式

### When（実行条件）
- 実装コードの依存関係をレビューする（`import`文がないGDScriptのため、`preload`/`class_name`参照とディレクトリ配置を確認する）

### Then（期待結果）
- `features/rank/state/*.gd`・`features/alchemy/state/*.gd`への直接参照が存在しない
- `DeliveryResolver`等Domain層の計算式が`GuildDeliveryScreen`側で再実装されていない（`GameState`が返す`DeliveryResult`をそのまま用いている）
- `features/guild/logic/delivery_resolver.gd` / `delivery_result.gd`のフィールド・シグネチャが変更されていない

### テストチェックリスト

- [ ] **正常系**: コードレビューで上記3点が確認できる 🔵
- [ ] **異常系**: 該当なし（静的なアーキテクチャ検証のため） 🔵
- [ ] **境界値**: 該当なし 🔵

---

## AC-008: [FR-006] 0件納品時に表示が空へリセットされる 🔵

**関連**: FR-006, US-401

### Given（前提条件）
- `GuildDeliveryScreen`が直前のターンで2件の納品結果を表示している（`get_item_count() == 2`）
- 今回のターンでは調合が1件も実行されず`pending_products`が空である

### When（実行条件）
- `AlchemyScreen._on_end_turn_pressed()`相当の手順（スナップショット取得→`GameState.deliver_pending_products()`→`display_results()`呼び出し）を実行する。`GameStateGuildDelegate.deliver_pending_products()`は`_pending_products.is_empty()`の場合`Result.ok([])`を即返し`delivered`シグナルは発行しないが（実装確認済み: `atelier/autoload/game_state_guild_delegate.gd` L18-19）、FR-006により`display_results()`の呼び出し自体は`delivered`シグナルの発行有無に関わらず毎回行われる（`display_results([], [])`が呼ばれる）

### Then（期待結果）
- `GuildDeliveryScreen`のリストが0件にリセットされる（前回の2件がそのまま残らない）
- 合計貢献度・合計報酬が0にリセットされる
- 例外・エラーログが発生しない

### テストチェックリスト

- [ ] **正常系**: 直前に2件表示していた状態から`display_results([], [])`を呼ぶと、`get_item_count() == 0`かつ合計値が0になる 🔵
- [ ] **正常系**: `GuildDeliveryScreen`初期状態（`_ready()`直後、`display_results()`未呼び出し）で`get_item_count() == 0`かつ合計値が0である 🟡
- [ ] **境界値**: 該当なし

---

## AC-009: [FR-006, FR-404] AlchemyScreen改修の非破壊確認 🔵

**関連**: FR-006, FR-404, US-001, US-401

### Given（前提条件）
- 本plan適用後の`atelier/features/alchemy/ui/alchemy_screen.gd`

### When（実行条件）
- `_on_end_turn_pressed()`・`_ready()`・`_exit_tree()`の実装内容を確認する

### Then（期待結果）
- `_on_end_turn_pressed()`が呼び出す`GameState`側APIは変更前と同一の`GameState.deliver_pending_products()`のみである（FR-404）
- `_on_end_turn_pressed()`内で、呼び出し直前に`GameState.get_state()["pending_products"]`のスナップショット取得と、呼び出し後に`guild_delivery_screen.display_results(snapshot, result.value)`の呼び出しが追加されている（FR-006）
- `_on_delivered(results)`ハンドラが削除されている
- `_ready()`内の`GameState.delivered.connect(_on_delivered)`、`_exit_tree()`内の対応する`disconnect()`が削除されている
- `_on_delivered`由来のトースト表示（「N件を納品しました」）が発生しなくなる

### テストチェックリスト

- [ ] **正常系**: 既存の調合実行・ターン終了操作（`test_game_state_deliver_pending_products.gd`が検証するGameState側の挙動）に回帰がない 🔵
- [ ] **正常系**: ターン終了操作後、`GuildDeliveryScreen.get_item_count()`が実際に納品された件数と一致する（`AlchemyScreen`↔`GuildDeliveryScreen`間の配線確認） 🔵
- [ ] **異常系**: 該当なし（削除確認が主目的のため） 🔵
- [ ] **境界値**: 該当なし 🔵

---

## 横断的受入基準

### パフォーマンス（NFR-001）

- [ ] ターン終了1回あたりの表示更新（`delivered`受信時のリスト再構築）が、想定件数（数件〜十数件）で体感的な遅延なく完了する 🟡

### セキュリティ

該当なし。2026-08-22の追加ヒアリングで「直接メソッド呼び出し方式」に確定したことにより、`display_results()`呼び出し時点でindex不一致は構造的に発生しないため、旧NFR-101（および対応する横断的チェック項目）は削除した（requirements.md参照）。

### ユーザビリティ（NFR-201）

- [ ] 指定依頼の合致/不合致がテキストの表示/非表示で判別できる（色のみに依存しない） 🔵

---

## テストサマリー

| カテゴリ | 正常系 | 異常系 | 境界値 | 合計 |
|---------|--------|--------|--------|------|
| 機能要件（AC-001〜AC-003, AC-005〜AC-006, AC-008〜AC-009） | 11 | 5 | 6 | 22 |
| アーキテクチャ制約（AC-004, AC-007） | 2 | 2 | 2 | 6 |
| 非機能要件（横断的受入基準） | 0 | 0 | 0 | 2（正常系/異常系/境界値に細分しないNFR単位のチェック項目。NFR-001, NFR-201） |
| **合計** | 13 | 7 | 8 | 30 |

## 信頼性レベル分布

- 🔵 青信号: 7件 (78%)（AC-001, AC-002, AC-003, AC-006, AC-007, AC-008, AC-009）
- 🟡 黄信号: 2件 (22%)（AC-004, AC-005）
- 🔴 赤信号: 0件 (0%)

（AC-001〜AC-009の9件の受入基準本体を母数とした割合。各基準内のテストチェックリスト個別項目の信号は上記本文参照。2026-08-22の追加ヒアリングでAC-006・AC-008の🔴を解消した）
