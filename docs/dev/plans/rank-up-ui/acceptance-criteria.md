# rank-up-ui 受入基準

## 関連文書

- **要件定義**: [requirements.md](requirements.md)
- **ユーザーストーリー**: [user-stories.md](user-stories.md)

**【信頼性レベル凡例】**:
- 🔵 確実な基準
- 🟡 妥当な推測による基準
- 🔴 AI推論補完（要確認）

---

## AC-001: [FR-001, FR-408, CON-001] 新規シーンを作らずAlchemyScreenを拡張し、既存参照構造を維持する 🔵

**関連**: FR-001, FR-408, US-601, US-602

### Given（前提条件）
- `atelier/features/alchemy/ui/`に`alchemy_screen.gd`/`.tscn`が既存実装として存在する
- `atelier/features/rank/ui/`に`promotion_exam_screen.gd`/`.tscn`は存在しない

### When（実行条件）
- 本Planの実装が完了する

### Then（期待結果）
- `atelier/features/rank/ui/`（または他の場所）に新規`promotion_exam_screen.gd`/`.tscn`が作成されていない
- `alchemy_screen.tscn`が引き続き子ノード`%GuildDeliveryScreen`（`GuildDeliveryScreen`型）を直接保持している
- `GuildDeliveryScreen._refresh_rank_quota()`のロジック自体（試験モード表示切替）に変更が加えられていない

### テストチェックリスト

- [ ] **正常系**: `features/rank/ui/`配下に`promotion_exam_screen.*`という名前のファイルが存在しないことをファイル一覧で確認する 🔵
- [ ] **正常系**: `alchemy_screen.tscn`のノード構成に`%GuildDeliveryScreen`が引き続き存在することを確認する 🔵
- [ ] **異常系**: `guild_delivery_screen.gd`の`git diff`が本Planのコミット範囲に含まれていないこと（変更差分なし）を確認する 🔵

---

## AC-002: [FR-004, FR-106, FR-201, FR-202, FR-302] 試験残りターン数の表示と境界値 🟡

**関連**: FR-004, FR-106, FR-201, FR-202, FR-302, US-101, US-102

### Given（前提条件）
- `GameState._set_exam_state_for_test()`等で`in_exam = true`かつ`exam_turn_limit`・`exam_elapsed_turn`が既知の値に設定されている
- `AlchemyScreen`が`scene_runner()`でシーンツリーに追加され`_ready()`済みである

### When（実行条件）
- `exam_turn_limit`・`exam_elapsed_turn`の値を変えて画面を再構築（`_refresh()`相当）する

### Then（期待結果）
- 残りターン表示ラベルのテキストが「残り{n}ターン」（`n = max(exam_turn_limit - exam_elapsed_turn, 0)`）と一致する
- `in_exam = true`の間、当該ラベルの`visible`が`true`である
- `in_exam = false`の間、当該ラベルの`visible`が`false`である

### テストチェックリスト

- [ ] **正常系**: `exam_turn_limit = 5, exam_elapsed_turn = 2`のとき、ラベルが「残り3ターン」と表示されることを確認する 🔵
- [ ] **異常系**: `in_exam = false`のとき、残りターン表示ラベルの`visible`が`false`であることを確認する 🔵
- [ ] **境界値**: `exam_elapsed_turn == exam_turn_limit`（残り0ターン）のとき、ラベルが「残り0ターン」と表示され、負の値やマイナス記号を含まないことを確認する 🟡
- [ ] **境界値**: `exam_turn_limit - exam_elapsed_turn == 1`（残り1ターン）のとき、ラベルが「残り1ターン」と表示されることを確認する 🟡
- [ ] **境界値**: `exam_elapsed_turn > exam_turn_limit`（制限超過、通常は`commit_exam_outcome()`で即FAILURE確定するため到達しない想定の異常値）が渡された場合でも、`max()`クランプにより負の残りターン数が表示されないことを確認する 🟡

---

## AC-003: [FR-005, FR-102, FR-201, FR-202, FR-406] 「ターンを進める」ボタンの表示制御と挙動 🔵

**関連**: FR-005, FR-102, FR-201, FR-202, FR-406, US-201

### Given（前提条件）
- `AlchemyScreen`が`scene_runner()`でシーンツリーに追加され`_ready()`済みである

### When（実行条件）
- `in_exam`を`true`/`false`それぞれに設定した状態で画面を再構築する
- `in_exam = true`の状態で`%AdvanceExamTurnButton`を押下する

### Then（期待結果）
- `in_exam = true`の間、`%AdvanceExamTurnButton`の`visible`が`true`かつ`disabled`が`false`（常時有効）である
- `in_exam = false`の間、`%AdvanceExamTurnButton`の`visible`が`false`である
- ボタン押下時、`GameState.advance_exam_turn()`が呼び出され、`exam_elapsed_turn`が+1される
- ボタン押下後、残りターン表示ラベルが再計算された値に更新される

### テストチェックリスト

- [ ] **正常系**: `in_exam = true`の状態でボタンを押下し、`exam_elapsed_turn`が1増加し、残りターン表示が更新されることを確認する 🔵
- [ ] **正常系**: 投入枠が全て空・在庫0の状態でもボタンの`disabled`が`false`のままであることを確認する（`%ExecuteButton`とは独立して常時有効） 🔵
- [ ] **異常系**: `in_exam = false`の状態では`%AdvanceExamTurnButton`が`visible = false`のため操作できないことを確認する 🔵
- [ ] **境界値**: `exam_elapsed_turn`が`exam_turn_limit`に到達した直後（残り0ターン）でもボタン押下自体はエラーにならず`GameState.advance_exam_turn()`が正常応答（`Result.ok()`）を返すことを確認する（結果確定は`commit_exam_outcome()`側の責務であり本ボタンの押下自体をブロックしない） 🟡

---

## AC-004: [FR-203, FR-204, FR-407] 「終了ターン」ボタンの試験中非表示 🔵

**関連**: FR-203, FR-204, FR-407, US-002

### Given（前提条件）
- `AlchemyScreen`が`scene_runner()`でシーンツリーに追加され`_ready()`済みである

### When（実行条件）
- `in_exam`を`true`/`false`それぞれに設定した状態で画面を再構築する

### Then（期待結果）
- `in_exam = true`の間、`%EndTurnButton`の`visible`が`false`である
- `in_exam = false`の間、`%EndTurnButton`の`visible`が`true`であり、既存の手動納品挙動（`_on_end_turn_pressed()`が`GameState.deliver_pending_products()`を呼び`%GuildDeliveryScreen.display_results()`へ結果を渡す）が変更されていない

### テストチェックリスト

- [ ] **正常系**: `in_exam = true`のとき`%EndTurnButton.visible`が`false`であることを確認する 🔵
- [ ] **正常系**: `in_exam = false`のとき`%EndTurnButton.visible`が`true`であり、押下すると既存どおり`%GuildDeliveryScreen`に結果が反映されることを確認する（既存`test_alchemy_screen.gd`の回帰） 🔵
- [ ] **異常系**: `in_exam = true`から`in_exam = false`へ戻った直後（試験結果確定直後）に`%EndTurnButton`が再び`visible = true`へ復帰することを確認する 🟡
- [ ] **境界値**: 該当なし（bool値の2値のみのため境界値は正常系でカバー済み） 🔵

---

## AC-005: [FR-101] 試験中の調合成功で自動納品が実行される 🔵

**関連**: FR-101, US-001

### Given（前提条件）
- `in_exam = true`の状態で`AlchemyScreen`が`_ready()`済みである
- レシピが選択され、投入枠に有効な素材が投入されている（`%ExecuteButton`が有効）

### When（実行条件）
- `%ExecuteButton`を押下し`GameState.execute_alchemy()`が成功する（`GameState.product_crafted`シグナルが発行される）

### Then（期待結果）
- `AlchemyScreen._on_product_crafted()`内で自動的に`GameState.deliver_pending_products()`が呼び出される
- 呼び出し前に`pending_products`のスナップショットが取得され、`%GuildDeliveryScreen.display_results()`へ`products`と`results`が対応関係を保ったまま渡される（既存`_on_end_turn_pressed()`のCON-003契約と同型）
- `GameState.get_state()["pending_products"]`が空になる
- 試験ノルマ（`exam_quota`）に貢献度が反映される

### テストチェックリスト

- [ ] **正常系**: 調合成功後、`%GuildDeliveryScreen.get_item_count()`が1件増加し、`get_total_contribution()`/`get_total_reward()`が調合結果と一致することを確認する 🔵
- [ ] **正常系**: 調合成功後、`GameState.get_state()["pending_products"]`が空であることを確認する 🔵
- [ ] **異常系**: `in_exam = false`の場合は本フローが発火せず、`pending_products`に調合物が残ったままであること（既存の手動納品フローが維持されること）を確認する 🔵
- [ ] **境界値**: 同一ターン内で連続して2回調合を実行した場合、2回とも自動納品が行われ`%GuildDeliveryScreen`の合計値が2件分の累積になる（`display_results()`が都度リストを再構築するため、直近1回分のみが表示される仕様であれば直近1件分になる。既存`display_results()`の契約どおりであることを確認する） 🟡

---

## AC-006: [FR-002, FR-003, FR-103] 試験開始時の表示切替とメッセージ 🟡

**関連**: FR-002, FR-003, FR-103, US-301

### Given（前提条件）
- `AlchemyScreen`が`_ready()`済みで`GameState.exam_started`を購読している
- `in_exam = false`の通常モードで表示されている

### When（実行条件）
- `GameState.exam_started`シグナルが発行される（統合テストでは`GameState._set_exam_state_for_test()`で状態を設定した上でシグナルを直接`emit()`する、または`commit_rank_outcome()`のPROMOTION_ELIGIBLE分岐経由で発行させる）

### Then（期待結果）
- `AlchemyScreen`が画面表示を再計算し、残りターン表示ラベル・`%AdvanceExamTurnButton`が`visible = true`、`%EndTurnButton`が`visible = false`になる
- トーストメッセージ（`get_toast_text()`）が試験開始を示す文言に更新される

### テストチェックリスト

- [ ] **正常系**: `GameState.exam_started.emit()`後、`get_toast_text()`が試験開始メッセージであることを確認する 🟡
- [ ] **正常系**: `GameState.exam_started.emit()`後、残りターン表示ラベル・`%AdvanceExamTurnButton`が表示され`%EndTurnButton`が非表示になることを確認する 🔵
- [ ] **異常系**: `_ready()`前（シーンツリー未接続時点）に`exam_started`が発行されても、後続の`_ready()`時点の表示に悪影響を与えないことを確認する 🟡

---

## AC-007: [FR-104] 試験結果確定（SUCCESS/FAILURE）時のメッセージ表示 🟡

**関連**: FR-104, US-302

### Given（前提条件）
- `in_exam = true`の試験モードで`AlchemyScreen`が表示されている

### When（実行条件）
- `GameState.commit_exam_outcome()`が呼び出され、`GameState.exam_outcome_confirmed(ExamOutcome.Value.SUCCESS)`が発行される（別ケースとして`FAILURE`も検証する）

### Then（期待結果）
- `AlchemyScreen`が画面表示を再計算し、`in_exam`が`false`に戻ったことを反映して残りターン表示・`%AdvanceExamTurnButton`が非表示、`%EndTurnButton`が表示に戻る
- トーストメッセージが結果（成功/失敗）を示す文言に更新される

### テストチェックリスト

- [ ] **正常系**: `outcome = SUCCESS`で`exam_outcome_confirmed`発行後、トーストメッセージが成功を示す文言であることを確認する 🟡
- [ ] **正常系**: `outcome = FAILURE`で`exam_outcome_confirmed`発行後、トーストメッセージが失敗を示す文言であることを確認する 🟡
- [ ] **異常系**: `exam_outcome_confirmed`発行後、`GameState.get_state()["in_exam"]`が`false`であることを前提に、AlchemyScreen側の表示も通常モードに一致していることを確認する（状態とUIの乖離がないこと） 🔵

---

## AC-008: [FR-105] 試験結果確定（CONTINUE）時は通知しない 🟡

**関連**: FR-105, US-303

### Given（前提条件）
- `in_exam = true`の試験モードで`AlchemyScreen`が表示されている
- 直前のトーストメッセージが既知の文言（例: 空文字列）である

### When（実行条件）
- `GameState.commit_exam_outcome()`が呼び出され、`GameState.exam_outcome_confirmed(ExamOutcome.Value.CONTINUE)`が発行される（試験ノルマ未達・制限ターン未到達の状態で呼び出された場合に相当）

### Then（期待結果）
- トーストメッセージが変化しない（結果確定メッセージが表示されない）
- 画面表示（残りターン表示等）自体は再計算される

### テストチェックリスト

- [ ] **正常系**: `outcome = CONTINUE`で`exam_outcome_confirmed`発行後、`get_toast_text()`が発行前の値から変化していないことを確認する 🟡
- [ ] **異常系**: `outcome = CONTINUE`発行後も`in_exam`が`true`のままであるため、残りターン表示・`%AdvanceExamTurnButton`が引き続き表示されていることを確認する 🔵

---

## AC-009: [FR-002, FR-003, CON-005] シグナル購読・解除のライフサイクルと実プレイ発火ギャップ 🔵

**関連**: FR-002, FR-003, US-603

### Given（前提条件）
- `AlchemyScreen`インスタンスが未生成である

### When（実行条件）
- `AlchemyScreen`がシーンツリーに追加され`_ready()`が呼ばれる
- その後、`queue_free()`等でシーンツリーから除去され`_exit_tree()`が呼ばれる

### Then（期待結果）
- `_ready()`後、`GameState.exam_started`・`GameState.exam_outcome_confirmed`の両方に`is_connected()`が`true`を返す
- `_exit_tree()`後、両方の接続が解除され`is_connected()`が`false`を返す
- 【ユーザー確認済み】本Planの実装完了時点では、`GameState.commit_rank_outcome()`/`commit_exam_outcome()`をプロダクションコードから呼び出す箇所が存在しないため、上記シグナル購読は統合テストで`GameState`のシグナルを直接発行（`emit()`）またはテスト側で`commit_exam_outcome()`を直接呼び出すことでのみ検証され、実プレイ中には発火しない。この配線トリガーの実装は本Planのスコープ外とすることをユーザーに確認済み（別Plan/別Issueで対応）

### テストチェックリスト

- [ ] **正常系**: `_ready()`後に両シグナルへの接続が確立していることを`is_connected()`で確認する 🔵
- [ ] **異常系**: `_exit_tree()`後に`GameState.exam_started`/`exam_outcome_confirmed`を再度emitしてもエラーにならず、解放済みの`AlchemyScreen`の表示が更新されないことを確認する 🔵
- [ ] **境界値**: `_ready()`が呼ばれる前にシグナルが発行されても、初期化前状態に悪影響を与えないことを確認する 🟡
- [ ] **異常系**: `grep -r "commit_exam_outcome\|commit_rank_outcome" atelier/`でプロダクションコード（`autoload/`, `features/*/ui/`）からの呼び出しが本Plan完了後も存在しないままであることを確認し、CON-005の記述が実装完了時点でも正確であることを検証する 🔵

---

## AC-010: [FR-205, FR-206, FR-301] 在庫切れ/解禁レシピ0時の案内メッセージ 🟡

**関連**: FR-205, FR-206, FR-301, US-401

### Given（前提条件）
- `in_exam = true`の試験モードで`AlchemyScreen`が表示されている

### When（実行条件）
- ケースA: `GameState.get_state()["inventory"]`が空になる（全素材投入済み、または未所持）
- ケースB: `GameState.get_state()["unlocked_recipe_ids"]`が空になる
- ケースC: 上記いずれにも該当しない（在庫あり・解禁レシピあり）

### Then（期待結果）
- ケースA・Bでは案内メッセージが表示され、`%ExecuteButton`は無効化されるが`%AdvanceExamTurnButton`は有効のままである
- ケースCでは案内メッセージが非表示である

### テストチェックリスト

- [ ] **正常系**: ケースC（在庫あり・解禁レシピあり）で案内メッセージが非表示であることを確認する 🔵
- [ ] **異常系**: ケースA（在庫0）で案内メッセージが表示され、`%AdvanceExamTurnButton.disabled`が`false`のままであることを確認する 🟡
- [ ] **異常系**: ケースB（解禁レシピ0）で案内メッセージが表示されることを確認する 🟡
- [ ] **境界値**: `in_exam = false`の場合は在庫0・解禁レシピ0であっても本Planの案内メッセージが表示されない（既存の非試験中挙動を変更しない、FR-205はin_exam=trueの間のみの状態駆動要件）ことを確認する 🟡

---

## AC-011: [FR-401〜FR-405, FR-408] 非スコープ項目の未実装確認 🔵

**関連**: FR-401, FR-402, FR-403, FR-404, FR-405, FR-408, US-501, US-502, US-503, US-504, US-602

### Given（前提条件）
- 本Planの実装が完了している

### When（実行条件）
- リポジトリ全体（`atelier/`）を確認する

### Then（期待結果）
- `features/rank/ui/`または他の場所に新規`promotion_exam_screen.*`ファイルが存在しない（FR-401）
- `features/workshop/ui/`が`.gitkeep`のみのままである（FR-402）
- `atelier/scenes/main.tscn`に`AlchemyScreen`の`current_phase`分岐による表示切替や試験モード関連のノード追加が行われていない（FR-403）
- `AlchemyScreen`・`AlchemyScreen.tscn`に`Tween`/`AnimationPlayer`等の新規演出ノード・処理が追加されていない（FR-404）
- `AlchemyScreen`に到達ランク・降格回数・所持ゴールド等の統計表示ラベルが追加されていない（FR-405）
- `guild_delivery_screen.gd`に変更差分がない（FR-408）

### テストチェックリスト

- [ ] **正常系**: 上記6項目をリポジトリのファイル一覧・`git diff`・コードレビューで確認する 🔵
- [ ] **異常系**: 該当なし（実装しないことの確認のため） 🔵
- [ ] **境界値**: 該当なし 🔵

---

## 横断的受入基準

### パフォーマンス（NFR-001）

- [ ] `AlchemyScreen`に`_process()`/`_physics_process()`が追加されておらず、試験モードの表示更新がすべてシグナル駆動（`_refresh()`呼び出し）で完結していることをコードレビューで確認する 🟡

### セキュリティ（NFR-101）

- [ ] `exam_started`・`exam_outcome_confirmed`のシグナルハンドラ引数（`outcome: ExamOutcome.Value`等）に明示的な型注釈が付与されていることを`gdlint`・コードレビューで確認する 🔵

### ユーザビリティ（NFR-201）

- [ ] 残りターン表示・トースト・案内メッセージの日本語テキストが、プロジェクト共通のCJK対応フォント（`UiTheme`経由、`AlchemyScreen`の既存トースト表示と同一の描画経路）で表示され、文字化け（豆腐文字）が発生しないことを目視確認する 🟡

### 保守性（NFR-301）

- [ ] 実装完了時点の`alchemy_screen.gd`の行数を確認し、300行を超えている場合はヘルパー関数抽出等の分割検討がPRレビューコメントまたはコミットメッセージに記録されていることを確認する 🟡

---

## テストサマリー

| カテゴリ | 正常系 | 異常系 | 境界値 | 合計 |
|---------|--------|--------|--------|------|
| 機能要件 | 17 | 13 | 9 | 39 |
| 非機能要件 | 4 | 0 | 0 | 4 |
| **合計** | 21 | 13 | 9 | 43 |

## 信頼性レベル分布

AC見出し単位（AC-001〜AC-011の11件）での分布は以下のとおり。

- 🔵 青信号: 6件 (55%)
- 🟡 黄信号: 5件 (45%)
- 🔴 赤信号: 0件（AC-009はユーザー確認済みのため🔵へ更新）
