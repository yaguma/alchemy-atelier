# atelier-alchemy-core 受入基準

## 関連文書

- **要件定義**: [requirements.md](requirements.md)
- **ユーザーストーリー**: [user-stories.md](user-stories.md)

**【信頼性レベル凡例】**:
- 🔵 確実な基準
- 🟡 妥当な推測による基準
- 🔴 AI推論補完（要確認）

---

## AC-001: [FR-001, FR-002] ディレクトリスキャフォールディング 🔵

**関連**: FR-001, FR-002, US-001

### Given（前提条件）
- リポジトリルートに`atelier/`プロジェクトが未作成の状態

### When（実行条件）
- `docs/design/atelier-alchemy-core/architecture.md`「ディレクトリ構造（案）」に従い、`atelier/`配下にディレクトリツリーを作成する

### Then（期待結果）
- `autoload/`, `features/{garden,alchemy,guild,workshop,rank}/{logic,state,resources,ui}/`, `shared/{constants,theme,entities}/`, `data/{materials,recipes,ranks,upgrades,daily_orders}/`, `scenes/`, `tests/unit/features/{garden,alchemy,guild,workshop,rank}/`, `tests/integration/`のすべてが存在する
- 中身が空のディレクトリには`.gitkeep`が配置され、`git status`でディレクトリが追跡対象になる

### テストチェックリスト

- [ ] **正常系**: `find atelier -type d`の出力がarchitecture.mdのディレクトリ案と一致する 🔵
- [ ] **正常系**: 空ディレクトリをコミットした際、git履歴に`.gitkeep`が含まれる 🔵
- [ ] **異常系**: architecture.mdに存在しないディレクトリが誤って作成されていないことを確認する 🟡

---

## AC-002: [FR-003] Godotバージョン固定 🔵

**関連**: FR-003, US-001

### Given（前提条件）
- `atelier/project.godot`が作成済みである

### When（実行条件）
- `project.godot`の内容を確認する

### Then（期待結果）
- Godot 4.7（安定版）向けの設定として保存されている（`config_version`等がGodot 4.7が生成する値と一致する）

### テストチェックリスト

- [ ] **正常系**: Godot 4.7エディタで`atelier/`を開いてもバージョン変換ダイアログが出ない 🔵
- [ ] **異常系**: Godot 4.6以前や4.8以降のエディタで開いた場合に互換性警告が出ることを許容する（対象外バージョンでの動作保証はしない） 🟡

---

## AC-003: [FR-004, FR-005] GameState最小フィールド・signal 🔵

**関連**: FR-004, FR-005, US-002

### Given（前提条件）
- `autoload/game_state.gd`が`project.godot`のAutoloadに登録済みである

### When（実行条件）
- GUTテストから`GameState.get_state()`を呼び出し、また`GameState.set_phase()`相当の操作で`phase_changed`を発行させる

### Then（期待結果）
- `get_state()`の戻り値に`current_phase: StringName`, `gold: int`, `current_turn: int`が含まれる
- `phase_changed` signalが`(previous: StringName, next: StringName)`で発行される

### テストチェックリスト

- [ ] **正常系**: `GameState.get_state().current_phase`が初期値`&"garden"`相当であることを確認する 🔵
- [ ] **正常系**: `watch_signals(GameState)`+`assert_signal_emitted_with_parameters`で`phase_changed`発行を検証する 🔵
- [ ] **境界値**: フィールド未初期化時（Autoload登録直後）でも`get_state()`が例外を投げない 🟡

---

## AC-004: [FR-103, FR-406] GameState.get_state()のディープコピー 🔵

**関連**: FR-103, FR-406, US-002

### Given（前提条件）
- `GameState`が初期化済み（`reset_for_test()`実行済み）である

### When（実行条件）
- `var state := GameState.get_state()`で取得した`Dictionary`内の`Array`/`Dictionary`フィールドを呼び出し元で変更する（例: 将来追加されるinventory等の配列フィールドがある場合はそれを、本Planの最小フィールドでは`get_state()`が返す`Dictionary`自体を書き換える）

### Then（期待結果）
- `GameState`内部の状態（再度`get_state()`した結果）が変更前と一致する（外部からの変更が反映されない）

### テストチェックリスト

- [ ] **正常系**: `state["current_phase"] = &"dummy"`のように戻り値を書き換えた後、再度`get_state()`した結果が影響を受けないことを確認する 🔵
- [ ] **異常系**: `get_state()`の実装が`_state`をそのまま返す（`duplicate(true)`を経由しない）退行が起きた場合にこのテストが失敗することを確認する（テスト自体の有効性検証） 🟡

---

## AC-005: [FR-104, FR-201] reset_for_test()の初期化とデバッグビルドガード 🔵

**関連**: FR-104, FR-201, US-008, US-012

### Given（前提条件）
- `GameState`の状態が初期値から変更されている（例: `gold`が0以外）

### When（実行条件）
- デバッグビルド下で`GameState.reset_for_test()`を呼び出す

### Then（期待結果）
- `GameState.get_state()`の全フィールドが初期値に戻る
- `reset_for_test()`の実装に`OS.is_debug_build()`ガード（`assert()`または`push_error()`+早期return）が存在する

### テストチェックリスト

- [ ] **正常系**: `gold`を変更後`reset_for_test()`を呼び、`get_state().gold == 0`（初期値）になることを確認する 🔵
- [ ] **正常系**: GUT自体がデバッグビルド相当で動作するため、テスト実行時は`reset_for_test()`が正常に完走することを確認する 🔵
- [ ] **境界値**: `OS.is_debug_build()`が`false`相当のケースはGUT実行環境では再現できないため、コードレビューでガード実装の存在を確認する（自動テスト対象外） 🟡

---

## AC-006: [FR-006, FR-105] RngServiceのseed再現性 🔵

**関連**: FR-006, FR-105, US-003

### Given（前提条件）
- `RngService`が初期化済みである

### When（実行条件）
- `RngService.set_seed(12345)`を呼び出した直後に`randf()`を複数回呼び出し、値の列を記録する。その後再度`set_seed(12345)`し、同様に`randf()`を複数回呼び出す

### Then（期待結果）
- 2回目の`randf()`列が1回目と完全に一致する

### テストチェックリスト

- [ ] **正常系**: 同一seedで5回連続`randf()`した結果の配列が2回とも一致することを確認する 🔵
- [ ] **異常系**: 異なるseed（例: 1と2）では列が一致しない（偶然の一致を除き通常は異なる）ことを確認する 🟡
- [ ] **境界値**: `set_seed(0)`のような境界値seedでも例外を投げず動作することを確認する 🟡

---

## AC-007: [FR-007, FR-008, NFR-201] 日本語フォント表示 🔵

**関連**: FR-007, FR-008, NFR-201, US-004

### Given（前提条件）
- `UiTheme`にCJK対応フォント定数が定義され、プロジェクト共通`Theme`リソースに適用済みである
- `boot.tscn`上に日本語テキストを含む`Label`（仮ラベル）が配置されている

### When（実行条件）
- Godotエディタで`boot.tscn`をF6等で実行する

### Then（期待結果）
- 日本語テキストが矩形/豆腐文字にならず、正しいグリフで描画される

### テストチェックリスト

- [ ] **正常系**: 目視確認により、画数の多い漢字（例:「錬金術師」）を含むテキストが正しく表示されることを確認する（手動確認、`.claude/rules/godot-debug-tools.md`のスクリーンショット運用に従う） 🔵
- [ ] **異常系**: フォント未適用状態（デグレ時）で矩形/豆腐文字になることを事前に確認し、適用後との違いを比較する 🟡
- [ ] **境界値**: フォントサイズ16px相当以上の見出しテキストでも字形欠けがないことを確認する 🟡

---

## AC-008: [FR-101, FR-102] BootScene→MainScene遷移 🔵

**関連**: FR-101, FR-102, US-005

### Given（前提条件）
- `scenes/boot.tscn`が起動シーンとして`project.godot`に設定されている
- `scenes/main.tscn`（空のControlのみのプレースホルダ）が存在する

### When（実行条件）
- Godotエディタでプロジェクトを実行する（F5相当）、または`godot --headless --path atelier`でBootSceneを起動する

### Then（期待結果）
- `UiTheme`のフォント適用処理が実行される
- `MasterDataLoader.validate_references()`の呼び出し配線が実行される（スタブのため常にtrue等を返す想定）
- `get_tree().change_scene_to_file("res://scenes/main.tscn")`によりMainSceneへ遷移する

### テストチェックリスト

- [ ] **正常系**: GUTのシーンテストで`boot.tscn`をロードし、一定フレーム後に現在シーンが`main.tscn`になっていることを確認する 🔵
- [ ] **異常系**: `validate_references()`がfalseを返すスタブに差し替えた場合の遷移抑止有無を確認する（本Planではスタブが常にtrueのため通過することのみ確認） 🟡

---

## AC-009: [FR-009] MasterDataLoader.validate_references()スタブ 🔵

**関連**: FR-009, US-006

### Given（前提条件）
- `MasterDataLoader`クラスが`res://shared/`配下等に作成済みである

### When（実行条件）
- `MasterDataLoader.validate_references()`を引数なし、またはダミー引数で呼び出す

### Then（期待結果）
- 関数が例外を投げずに戻り値（スタブとして`true`固定、またはTODOコメント付きの未実装挙動）を返す
- 呼び出し元（`BootScene`）から実際に配線・呼び出しされている

### テストチェックリスト

- [ ] **正常系**: `MasterDataLoader.validate_references()`の呼び出しが例外を投げないことを確認する 🔵
- [ ] **正常系**: `boot.gd`内に`MasterDataLoader.validate_references()`の呼び出し箇所が存在することをコードレビューで確認する 🔵

---

## AC-010: [FR-106] クリーンチェックアウト直後のインポート成功 🔵

**関連**: FR-106, US-010

### Given（前提条件）
- `atelier/.godot/`インポートキャッシュディレクトリが存在しない（新規clone直後を模擬）

### When（実行条件）
- `godot --headless --path atelier --import`を実行する

### Then（期待結果）
- コマンドが終了コード0で正常終了し、`.godot/`にインポートキャッシュが生成される

### テストチェックリスト

- [ ] **正常系**: `.godot/`を手動削除した状態から`--import`を実行し、終了コードが0であることを確認する 🔵
- [ ] **異常系**: インポートとGUT実行を同時に行うと不安定になることがあるため、`--import`完了後に別コマンドとしてGUTを実行する運用になっていることを確認する 🟡

---

## AC-011: [FR-107] GUT全テスト実行パス 🔵

**関連**: FR-107, US-008

### Given（前提条件）
- GUTアドオンが`addons/gut/`にインストール済みである
- `tests/integration/`にGameState/RngServiceのテストファイルが作成済みである

### When（実行条件）
- `godot --headless --path atelier -s addons/gut/gut_cmdln.gd -gdir=res://tests/ -ginclude_subdirs -gexit`を実行する

### Then（期待結果）
- すべてのテストがパスし、失敗（failures）が0件で終了する

### テストチェックリスト

- [ ] **正常系**: コマンド実行後の出力サマリーで`0 failures`であることを確認する 🔵
- [ ] **異常系**: `-ginclude_subdirs`を付け忘れた場合に「0 tests, 0 failures」の偽グリーンになる既知の罠を踏んでいないか確認する 🟡

---

## AC-012: [FR-108] gdlint実行 🔵

**関連**: FR-108, US-009

### Given（前提条件）
- `atelier/features/`, `shared/`, `autoload/`配下に本Planで作成したGDScriptファイル（`game_state.gd`, `rng_service.gd`, `theme.gd`等）が存在する

### When（実行条件）
- `gdlint atelier/features/ atelier/shared/ atelier/autoload/`を実行する

### Then（期待結果）
- リント違反エラーが0件で終了する

### テストチェックリスト

- [ ] **正常系**: コマンドの終了コードが0であることを確認する 🔵
- [ ] **異常系**: 型注釈欠落や命名規則違反があれば検出され、修正後に再実行して0件になることを確認する 🟡

---

## AC-013: [FR-109] gdformat --check実行 🔵

**関連**: FR-109, US-009

### Given（前提条件）
- 本Planで作成したGDScriptファイルが存在する

### When（実行条件）
- `gdformat --check atelier/features/ atelier/shared/ atelier/autoload/`を実行する

### Then（期待結果）
- フォーマット崩れが検出されず終了コード0で終了する

### テストチェックリスト

- [ ] **正常系**: コマンドの終了コードが0であることを確認する 🔵
- [ ] **異常系**: フォーマット崩れがある場合`gdformat`（`--check`なし）で修正し、再実行してパスすることを確認する 🟡

---

## AC-014: [FR-010, CON-002] GUT導入手順書の提示と動作確認 🔵

**関連**: FR-010, CON-002, US-007

### Given（前提条件）
- `addons/gut/`が未インストールの状態

### When（実行条件）
- 提示された手順書（GodotエディタのAssetLibからGUTを検索・インストールする手順）に従ってユーザーが手動インストールを行う

### Then（期待結果）
- インストール後、`godot --headless --path atelier -s addons/gut/gut_cmdln.gd -gdir=res://tests/ -ginclude_subdirs -gexit`が実行可能になる（コマンド自体は成功し、テストが0件でも「アドオン未検出」エラーにならない）

### テストチェックリスト

- [ ] **正常系**: 手順書通りに操作した後、`addons/gut/gut_cmdln.gd`が存在することを確認する 🔵
- [ ] **正常系**: インストール後の動作確認コマンドが「アドオンが見つからない」エラーを出さないことを確認する 🔵
- [ ] **異常系**: 手動ステップが自動化できない旨がタスク文書に明記されていることを確認する 🔵

---

## AC-015: [FR-301] BootSceneでの日本語フォント目視確認 🟡

**関連**: FR-301, US-011

### Given（前提条件）
- `boot.tscn`に日本語の仮ラベル（例:「アトリエ 起動確認」）が配置されている

### When（実行条件）
- Godotエディタで`boot.tscn`を実行し、目視確認手順書に従って確認する

### Then（期待結果）
- 仮ラベルが矩形/豆腐文字にならず表示され、手順書通りの操作で誰でも再現確認できる

### テストチェックリスト

- [ ] **正常系**: 手順書に記載の操作のみでフォント表示状態を確認できることを確認する 🟡
- [ ] **正常系**: スクリーンショットを撮る場合は`.claude/rules/godot-debug-tools.md`の保存先命名規則（`user://debug-screenshots/`、リポジトリへの混入禁止）に従っていることを確認する 🔵

---

## AC-016: [FR-401〜FR-405] スコープ外実装の非混入確認 🔵

**関連**: FR-401, FR-402, FR-403, FR-404, FR-405, US-013

### Given（前提条件）
- 本Planの実装コミット・PR差分が作成されている

### When（実行条件）
- PRレビュー時に差分ファイル一覧を確認する

### Then（期待結果）
- `features/{garden,alchemy,guild,workshop,rank}/logic/*.gd`の実ロジックファイル、`data/**/*.tres`の実データ、`features/**/ui/*.tscn`の画面実装、セーブ/ロード関連コード、エクスポートプリセット設定のいずれも差分に含まれない

### テストチェックリスト

- [ ] **正常系**: `git diff --stat`の対象ファイルが本Planのスコープ（scaffolding, autoload, shared/theme, scenes/boot・main, tests）に収まっていることを確認する 🔵
- [ ] **異常系**: スコープ外ファイルが混入していた場合、PRレビューでCritical/Warning指摘として扱う（`.claude/rules/code-review.md`のアーキテクチャルール違反基準を準用） 🟡

---

## 横断的受入基準

### パフォーマンス（NFR-001）

- [ ] 起動時間の体感確認（数値目標なし、TBD）。Godotエディタでの実行時に明らかな数秒以上の待たされ感がないことを目視で確認する 🔴

### セキュリティ（NFR-101）

- [ ] 本Planではネットワーク通信・認証機能を追加しないことをコードレビューで確認する（該当性が低いため追加のセキュリティテストは実施しない） 🔵

### ユーザビリティ（NFR-201）

- [ ] AC-007と同一（日本語テキストの正常描画） 🔵

### 保守性（NFR-401）

- [ ] `GameState`/`RngService`/`UiTheme`が`.claude/rules/architecture.md`のレイヤー配置（Autoload=Application層、`shared/theme`=Infrastructure層相当）に従っていることをコードレビューで確認する 🟡

---

## テストサマリー

| カテゴリ | 正常系 | 異常系 | 境界値 | 合計 |
|---------|--------|--------|--------|------|
| 機能要件 | 20 | 10 | 6 | 36 |
| 非機能要件 | 3 | 0 | 0 | 3 |
| **合計** | 23 | 10 | 6 | 39 |

## 信頼性レベル分布

（AC見出し16件＋横断的受入基準4件、計20件の信頼性レベルを集計。各AC内のテストチェックリスト個別項目のレベルは項目ごとの表記を正とする）

- 🔵 青信号: 17件 (85%)
- 🟡 黄信号: 2件 (10%)
- 🔴 赤信号: 1件 (5%)
