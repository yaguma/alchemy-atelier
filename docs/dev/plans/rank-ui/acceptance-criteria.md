# rank-ui 受入基準

## 関連文書

- **要件定義**: [requirements.md](requirements.md)
- **ユーザーストーリー**: [user-stories.md](user-stories.md)

**【信頼性レベル凡例】**:
- 🔵 確実な基準
- 🟡 妥当な推測による基準
- 🔴 AI推論補完（要確認）

---

## AC-001: [FR-101, FR-102, FR-004] 最終ランク昇格試験成功でgame_clearedが発行されクリア表示に切り替わる 🔵

**関連**: FR-004, FR-101, FR-102, FR-302, US-001

### Given（前提条件）
- 現在ランクがRANK_ORDER末尾（最終ランク、Sランク相当）である
- 昇格試験実施中（`_in_exam = true`）で、試験ノルマ達成によりSUCCESS確定寸前の状態にある
- `RankProgression.get_next_rank_id(current_rank_id)`が空文字列`&""`を返す

### When（実行条件）
- `commit_exam_outcome()`等の経路を通じて`game_state_rank_delegate.gd`の`_commit_exam_success()`が呼び出される

### Then（期待結果）
- `GameState.game_cleared`シグナルが発行される
- `_current_rank_id`は変化しない
- `_in_exam`が`false`になる
- ResultScreenが購読中の場合、内部表示がクリア表示に切り替わる

### テストチェックリスト

- [ ] **正常系**: 最終ランクでSUCCESS確定→`assert_signal(GameState).is_emitted(GameState.game_cleared)`で発行を確認する 🔵
- [ ] **異常系**: 次ランクのRankMaster欄が未登録の分岐（AC-004参照）では`game_cleared`が発行されないことを確認する 🔵
- [ ] **境界値**: RANK_ORDER末尾から2番目のランクでSUCCESS確定した場合は通常昇格処理（`_current_rank_id`が次ランクへ更新）となり、`game_cleared`は発行されないことを確認する 🟡

---

## AC-002: [FR-103] game_over発行でオーバー表示に切り替わる 🔵

**関連**: FR-103, US-002

### Given（前提条件）
- 降格の累積等によりゲームオーバー条件が成立している
- ResultScreenが`_ready()`済みで`GameState.game_over`を購読している

### When（実行条件）
- `GameState.game_over(demotion_count)`シグナルが発行される

### Then（期待結果）
- ResultScreenの内部表示がオーバー表示に切り替わる
- クリア表示は行われない（AC-005参照）

### テストチェックリスト

- [ ] **正常系**: `game_over`発行→ResultScreenの表示状態がオーバー表示になることを確認する 🔵
- [ ] **異常系**: `game_over`発行前はResultScreenが初期状態（未表示または結果種別未確定の状態）のままであることを確認する 🟡
- [ ] **境界値**: `demotion_count`に`0`を渡した場合でも既存シグネチャとの互換性が保たれ、ResultScreenは`demotion_count`の値自体を表示しない（FR-404）ことを確認する 🟡

---

## AC-003: [FR-001, FR-104, FR-301] シグナル自己購読・購読解除の標準パターン 🔵

**関連**: FR-001, FR-104, FR-301, US-003

### Given（前提条件）
- ResultScreenインスタンスが生成されている

### When（実行条件）
- ResultScreenがシーンツリーに追加され`_ready()`が呼ばれる
- その後、ResultScreenが`queue_free()`等でシーンツリーから除去され`_exit_tree()`が呼ばれる

### Then（期待結果）
- `_ready()`後、`GameState.game_over`・`GameState.game_cleared`の両方に`is_connected()`が`true`を返す
- `_exit_tree()`後、両方の接続が解除され`is_connected()`が`false`を返す

### テストチェックリスト

- [ ] **正常系**: `_ready()`後に両シグナルへの接続が確立していることを`is_connected()`で確認する 🔵
- [ ] **異常系**: `_exit_tree()`後に`GameState.game_over`/`game_cleared`を再度emitしてもエラーにならず、かつ解放済みのResultScreenの表示が更新されないことを確認する 🔵
- [ ] **境界値**: `_ready()`が呼ばれる前（シーンツリー未接続時点）にシグナルがemitされても、ResultScreenの初期化前状態に影響しないことを確認する 🟡

---

## AC-004: [FR-201, FR-405] マスターデータ欠落エラー分岐でgame_cleared/game_overが誤発火しない 🔵

**関連**: FR-201, FR-405, US-004

### Given（前提条件）
- 現在ランクは最終ランクではない（次ランクIDが空文字列以外で取得できる）
- 取得した次ランクIDに対応する`RankMaster`が`_rank_masters`に未登録である

### When（実行条件）
- `_commit_exam_success()`が呼び出される

### Then（期待結果）
- `_warn_missing_next_rank_master()`経由の`push_error`相当の警告が呼ばれる
- `GameState.game_cleared`は発行されない
- `GameState.game_over`も発行されない
- `_current_rank_id`・`_rank_state`は変化しない
- `_in_exam`は`false`になる

### テストチェックリスト

- [ ] **正常系**: 欠落分岐実行後も`_in_exam`が`false`に戻り、次回の`commit_exam_outcome()`呼び出しで同じ分岐に無限に入り直さないことを確認する 🔵
- [ ] **異常系**: 欠落分岐実行時に`assert_signal(GameState).is_not_emitted(GameState.game_cleared)`相当の手段で`game_cleared`が発行されないことを確認する 🔵
- [ ] **異常系**: 同様に`game_over`も発行されないことを確認する 🔵
- [ ] **境界値**: 欠落分岐実行後、マスターデータに該当RankMasterを追加登録してから再度SUCCESS確定させると、正常に次ランクへ昇格し`game_cleared`は発行されない（通常昇格）ことを確認する 🟡

---

## AC-005: [FR-401] クリア表示とオーバー表示の排他性 🟡

**関連**: FR-401, US-001, US-002

### Given（前提条件）
- ResultScreenが表示中である

### When（実行条件）
- `game_cleared`または`game_over`のいずれか一方が発行される
- （通常のゲームフローでは発生しないが）両シグナルが同一セッション内で発行される

### Then（期待結果）
- 片方のみ発行された場合は対応する表示のみが有効になる
- 仮に両方発行された場合でも、クリア表示とオーバー表示が同時に表示されることはなく、最後に受信したシグナルに対応する表示のみが有効になる

### テストチェックリスト

- [ ] **正常系**: `game_cleared`のみ発行→クリア表示のみ有効であることを確認する 🔵
- [ ] **正常系**: `game_over`のみ発行→オーバー表示のみ有効であることを確認する 🔵
- [ ] **異常系**: 両シグナルを連続発行した場合、後着のシグナルに対応する表示のみが有効になり、両方同時表示にならないことを確認する 🟡

---

## AC-006: [FR-402] ボタン非実装の確認 🔵

**関連**: FR-402, US-006

### Given（前提条件）
- ResultScreenのシーンファイル（`result_screen.tscn`）が存在する

### When（実行条件）
- シーン構成をレビューする

### Then（期待結果）
- 閉じる・次へ進む等のインタラクティブな`Button`ノードが含まれない

### テストチェックリスト

- [ ] **正常系**: シーンファイルに`Button`ノード（またはそれに類する押下可能なコントロール）が含まれないことをコードレビューで確認する 🔵
- [ ] **異常系**: 該当なし（実装しないことの確認のため） 🔵
- [ ] **境界値**: 該当なし 🔵

---

## AC-007: [FR-403] MainScene非統合の確認 🔵

**関連**: FR-403, US-007

### Given（前提条件）
- 本Planの実装が完了している

### When（実行条件）
- `atelier/scenes/main.tscn`を確認する

### Then（期待結果）
- ResultScreenが`main.tscn`に組み込まれていない（`current_phase`に応じた`visible`切り替えの実装も含め、本Plan外）

### テストチェックリスト

- [ ] **正常系**: `main.tscn`に`ResultScreen`ノードが追加されていないことを確認する 🔵
- [ ] **異常系**: 該当なし 🔵
- [ ] **境界値**: 該当なし 🔵

---

## AC-008: [FR-003, FR-404] 最小限表示内容の確認 🟡

**関連**: FR-003, FR-404, US-005

### Given（前提条件）
- ResultScreenがクリア表示またはオーバー表示のいずれかの状態で表示されている

### When（実行条件）
- 表示内容を確認する

### Then（期待結果）
- 結果種別を示すメッセージ（例:「ゲームクリア」「ゲームオーバー」に相当する文言）のみが表示される
- 到達ランク・降格回数・所持ゴールド等の統計情報を示すラベル・表示ノードが存在しない

### テストチェックリスト

- [ ] **正常系**: 表示ノード構成にメッセージ用`Label`（またはそれに類するテキスト表示ノード）以外の統計表示ノードが存在しないことを確認する 🟡
- [ ] **異常系**: 該当なし 🔵
- [ ] **境界値**: 該当なし 🔵

---

## 横断的受入基準

### パフォーマンス（NFR-001）

- [ ] ResultScreenが`_process()`/`_physics_process()`を定義していない、またはシグナル駆動の表示切替のみで完結していることをコードレビューで確認する 🟡

### セキュリティ（NFR-101）

- [ ] `game_cleared`・`game_over`のシグナルハンドラ引数（`demotion_count: int`等）に明示的な型注釈が付与されていることを`gdlint`・コードレビューで確認する 🔵

### アクセシビリティ／ユーザビリティ（NFR-201）

- [ ] ResultScreenの日本語メッセージ表示に、プロジェクト共通のCJK対応フォント（`UiTheme`経由）が適用され、文字化け（豆腐文字）が発生しないことを目視確認する 🟡

---

## テストサマリー

| カテゴリ | 正常系 | 異常系 | 境界値 | 合計 |
|---------|--------|--------|--------|------|
| 機能要件 | 9 | 7 | 5 | 21 |
| 非機能要件 | 1 | 1 | 1 | 3 |
| **合計** | 10 | 8 | 6 | 24 |

## 信頼性レベル分布

- 🔵 青信号: 6件 (75%)
- 🟡 黄信号: 2件 (25%)
- 🔴 赤信号: 0件 (0%)
