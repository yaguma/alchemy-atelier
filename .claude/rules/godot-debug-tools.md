# Godot デバッグ・調査ツール運用ルール

> 🔴 2026-08-06新規作成: 旧`playwright-mcp.md`・`playwright-mcp-cookbook.md`（ブラウザ版Phaserゲーム前提）を置き換える。技術スタックがGodot 4.x + GDScriptに確定済み（`CLAUDE.md`参照）だが、**本環境にはGodot用のブラウザ自動操作MCP相当のツールは存在しない**（Unity向けの`UnityMCP`はあるがGodotには非対応）。そのため調査・再現・手動検証のワークフローはPlaywrightMCPとは根本的に異なる形に置き換える。
> 🔴 2026-08-10改訂: Godot 4.7のAsset Store移行期にGUTが導入できなかったため、テストフレームワークをGdUnit4に切り替えた。本ファイルのGUT前提の記述を全面的にGdUnit4に置き換えた（実際に`atelier/tests/integration/`でGdUnit4テストの動作確認済み）。

## 基本原則

- **自動化された状態注入（旧`browser_evaluate`相当）はGodotに標準では存在しない**。再現手順は基本的に**GdUnit4統合テストとして書く**ことで「壊れない再現コード」にする（[`testing.md`](./testing.md)「E2E相当のテスト」参照）
- 一度きりの調査・目視確認は**Godotエディタでの実行 + リモートシーンツリー**で行う
- 調査で得た再現手順は**必ずGdUnit4テストに昇格**を検討する
- **CIでのGodotエディタ手動操作は当然行わない**（CIはGdUnit4 CLI一択）

---

## 調査手法の判断フロー

| 用途 | 手法 |
|------|------|
| バグ1回の再現・スクリーンショット撮影 | Godotエディタでの手動プレイ + `Debugger`パネル |
| ランダム探索・状態の直接確認 | エディタ実行中のリモートシーンツリー（`Remote`タブ） |
| 状態を直接注入して特定シナリオを再現したい | GdUnit4の`before_test`でシーン/Autoloadを直接操作するテストコードを書く（下記「状態セットアップ雛形」参照） |
| 回帰テスト・再発防止 | GdUnit4のシーンレベル統合テスト（`tests/integration/`） |
| CI実行 | GdUnit4 CLI（`cd atelier && ./addons/gdUnit4/runtest.sh`。`GODOT_BIN`は事前にシステム環境変数として設定済み前提）一択 |
| パフォーマンス測定 | Godotエディタ内蔵`Profiler`/`Monitors`（[`performance.md`](./performance.md)参照） |

判断の優先順:

1. 既存のGdUnit4統合テストで再現できるなら、それを拡張する
2. 再現テストがまだ無く一度だけ確認したい場合は、エディタでの手動プレイ + リモートシーンツリー
3. 調査で得た再現手順は、GdUnit4統合テストへ移植して回帰テスト化する

---

## Godotエディタでの調査ライフサイクル

### 実行

エディタの「現在のシーンを再生」（F6）または「プロジェクトを再生」（F5、`main.tscn`起動）で調査対象を起動する。

### リモートシーンツリー

実行中、エディタ下部の`Remote`タブでライブのシーンツリーを閲覧できる。ノードを選択すると`Inspector`でエクスポートされたプロパティの現在値を確認・その場で編集できる（ブラウザ版の`window.gameState()`スナップショットに相当）。

- `Autoload`（`GameState`, `RngService`）もリモートツリーのルート付近に表示される。選択して`Inspector`から内部変数（`@export`されているもの、または`Inspector`のデバッグモードで非exportプロパティ含め）を確認できる
- プロパティ書き換えは調査目的の一時的な操作に限定する。継続利用しない（セッション終了時に破棄する前提で扱う）

### ライフサイクル規約

- 調査セッションは1回の実行で完結させる。長時間（10分以上）実行したまま放置しない
- 複雑な状態を作りたい場合はエディタでの手動操作よりも、GdUnit4テストコードでの状態構築を優先する（再現性・レビュー可能性のため）

---

## 状態セットアップ雛形（GdUnit4統合テストでの記述例）

ブラウザ版の`playwright-mcp-cookbook.md`にあった「雛形」は、Godot版ではGdUnit4統合テストの`before_test`ロジックとして書く。1雛形＝1ヘルパー関数を目安にする。

### 雛形1: セーブデータリセット相当（初期状態からの起動）

セーブ/ロード機能は現行スコープ外（`CLAUDE.md`参照）のため、「リセット」は`GameState`（Autoload、プロセス内で単一）の内部状態を初期値に戻すことを指す。`GameState`はAutoloadのため、雛形2〜4のようにテストコードが直接参照する対象と同じインスタンスでなければ意味がない。ローカルに新規インスタンスを`.new()`しても、Autoload本体にもUIにも反映されず「リセットしたつもり」になるだけなので行わない。

```gdscript
func before_test() -> void:
	GameState.reset_for_test()
```

> 🔵 `GameState`（`autoload/game_state.gd`）に`reset_for_test()`（内部状態を初期値へ戻すメソッド）を実装しておくことが前提（実装例は[`state-management.md`](./state-management.md)「テスト用API」参照）。テスト分離のためだけに使うメソッドであることが分かるよう命名し、`assert(OS.is_debug_build(), ...)`等で本番コードパスから誤って呼び出されないようガードする。

### 雛形2: 特定フェーズへジャンプ

```gdscript
func _jump_to_phase(phase: StringName) -> void:
	GameState.set_phase(phase)
	# UIがsignal購読で追随する設計のため、明示的なUI再取得は不要
	# 追随しないUIがあれば設計不備の可能性が高い（state-management.md参照）
```

### 雛形3: 在庫へアイテム追加

```gdscript
var _test_id_counter := 0

func _add_material_to_inventory(material_id: StringName, quality: int) -> MaterialInstance:
	var master: MaterialMaster = MasterDataLoader.get_material(material_id)
	_test_id_counter += 1
	var instance := MaterialInstance.new("test_%d" % _test_id_counter, master, quality, [])
	GameState.add_item(instance)
	return instance
```

### 雛形4: 調合実行→納品までの一連操作

```gdscript
func test_調合を実行して納品まで到達する() -> void:
	GameState.reset_for_test()
	var runner := scene_runner("res://scenes/main.tscn")

	_jump_to_phase(&"alchemy")
	var material := _add_material_to_inventory(&"herb_common", 3)

	var alchemy_screen: AlchemyScreen = runner.find_child("AlchemyScreen")
	alchemy_screen.select_recipe(&"healing_potion")
	alchemy_screen.insert_material(material)
	alchemy_screen.execute()

	assert_that(GameState.get_state().current_phase).is_equal(&"guild_delivery")
```

> 🔵 `scene_runner("res://scenes/main.tscn")`はGdUnit4のシーンテスト専用API。シーンのロード・シーンツリーへの追加・テスト終了時の解放を一括管理する（GUTの`add_child_autofree(load(...).instantiate())`に相当するが、`find_child()`によるノード検索もあわせて提供する）。

### 実行順のベストプラクティス

複合的な状態を作りたい場合の典型的な順序:

1. 雛形1（初期化）
2. 雛形2（フェーズジャンプ）※必要な場合のみ
3. 雛形3（在庫構築）※必要な場合のみ
4. 対象操作の実行
5. `assert_*`で結果検証
6. 必要ならスクリーンショット（下記「目視確認用スクリーンショット」）で状態を記録。`_save_debug_screenshot()`は`await`を含むコルーチンのため、呼び出し側も`await _save_debug_screenshot(...)`とすること

各ステップ後にアサーションを挟み、失敗したら中断して原因調査する。

---

## 目視確認用スクリーンショット

自動テスト中にスクリーンショットを撮りたい場合は`Viewport.get_texture().get_image().save_png()`を使う。

> 🔴 `res://`はエクスポート後にPCKへ固められ読み取り専用になるため、書き込み先には必ず`user://`を使う。`save_png()`はエラー時に`Error`（非OK）を返すだけで例外を投げないため、戻り値を必ず確認する。また撮影直前に描画完了を待たないとキャプチャが空・前フレームの内容になることがあるため`await RenderingServer.frame_post_draw`を挟む。
>
> 🔴 **`--headless`実行では使用不可**: CIで実行するGdUnit4 CLI（[`bash-commands.md`](./bash-commands.md)参照）は常に`--headless`相当で動作するため、ダミーレンダラで`get_viewport().get_texture().get_image()`が`null`を返し、`img.save_png()`がクラッシュする。この関数はGodotエディタでの手動プレイまたは非headlessのデバッグビルドでの調査専用であり、GdUnit4の自動テスト（`tests/`配下、CI実行対象）からは呼び出さない。

```gdscript
func _save_debug_screenshot(topic: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img == null:
		push_warning("スクリーンショット撮影に失敗しました（--headless実行下では使用できません）: %s" % topic)
		return
	var date_str := Time.get_date_string_from_system().replace("-", "")
	var dir := "user://debug-screenshots/%s" % date_str
	if DirAccess.make_dir_recursive_absolute(dir) != OK:
		push_warning("スクリーンショット保存ディレクトリの作成に失敗しました: %s" % dir)
		return
	var err := img.save_png("%s/%s.png" % [dir, topic])
	if err != OK:
		push_warning("スクリーンショット保存に失敗しました: %s (error=%d)" % [topic, err])
```

### 保存先・命名規則

```
user://debug-screenshots/<YYYYMMDD>/<scene>-<state>-<seq>.png

例:
user://debug-screenshots/20260806/delivery-empty-01.png
user://debug-screenshots/20260806/delivery-item-selected-02.png
```

`user://`の実パスはOS依存（Windowsは`%APPDATA%/Godot/app_userdata/<project>/`相当）。エディタの「プロジェクト > ユーザーデータフォルダを開く」から確認できる。

### 禁止

- リポジトリルート直下に`debug-*.png`を撒く
- 調査用PNGのコミット（バージョン管理対象外の`user://`に保存されるため通常は混入しないが、手動でリポジトリへコピーしない）
- 長期保持（セッション終了時 or 翌日に手動クリーンアップ）

### 共有したい1枚

ドキュメントに貼りたい場合のみ`docs/screenshots/`に明示的に移動してコミットする。

---

## コンソール出力の確認

Godotエディタの`Output`パネル、および`Debugger`パネルの`Errors`タブでエラー・警告を確認する。GdUnit4実行時はターミナル出力にテスト結果とともにエラーが流れる。

### 対応ルール

- 想定外のエラー・警告を検出したら即座に操作を中断し原因調査する
- スクリーンショット撮影前に必ずコンソール（`Output`/`Debugger`）を確認する（不具合の取りこぼしを防ぐ）

---

## 将来検討: 開発用デバッグコンソール

ブラウザ版の`browser_evaluate`のような「実行中に任意の状態を注入する」操作は、Godotには標準機能として存在しない。頻繁に必要になる場合は、以下のような**ゲーム内蔵の開発者コンソール**（デバッグビルド限定で有効化するAutoload + オーバーレイUI）の追加を検討する。

```gdscript
# 将来実装イメージ（未実装、TBD）
# shared/debug/debug_console.gd
extends CanvasLayer

func _unhandled_key_input(event: InputEvent) -> void:
	if OS.is_debug_build() and event.is_action_pressed(&"toggle_debug_console"):
		visible = not visible

func _execute_command(command: String) -> void:
	match command:
		"give_item herb_common 3":
			GameState.add_item(_make_material(&"herb_common", 3))
		_:
			push_warning("unknown command: %s" % command)
```

現時点では未実装。個人開発規模ではGdUnit4テストコードでの状態構築で十分まかなえるため、必要性が明確になった時点で着手を検討する（🟡本文書での提案、確定事項ではない）。

---

## 禁止事項とレビュー観点

### 禁止

- 本番配布ビルドでのデバッグコンソール有効化（`OS.is_debug_build()`ガード必須）
- リモートシーンツリーでの値書き換えを「検証済みの動作」として扱う（あくまで調査用の一時操作）
- `debug-*.png`や`user://debug-screenshots/`から手動コピーした調査用画像のコミット
- CIでのGodotエディタGUI操作（CIはGdUnit4 CLIのみ）

### PRレビュー観点

- 手動調査で見つけたバグがGdUnit4統合テストに昇格されているか
- 調査用スクリーンショットがコミットに混入していないか
- 本ファイルに未カバーの罠が見つかったら追記する

---

## トラブルシュート早見表

| 症状 | 原因 | 対処 |
|------|------|------|
| リモートシーンツリーにAutoloadが出てこない | `project.godot`のAutoload登録漏れ | `Project > Project Settings > Autoload`を確認 |
| GdUnit4テストが`Node not found`で失敗 | `auto_free()`/`scene_runner()`未使用、またはシーンツリー未接続でのノード参照 | テスト対象を`auto_free()`+`add_child()`、またはシーン全体なら`scene_runner()`で構築してから操作する |
| シグナル購読が二重に呼ばれる | `_ready()`が複数回呼ばれるノード構成（シーン再インスタンス化等） | `is_connected()`チェックを徹底する（[`state-management.md`](./state-management.md)参照） |
| パラメータ化テストのケースが想定通り実行されない | `test_parameters`配列の要素の型・順序が関数引数の並びと不一致 | GdUnit4公式ドキュメントの`test_parameters`構文と照合し、関数引数の並びとデータセットの各要素順序が対応しているか確認 |
| `Nonexistent function 'xxx' in base 'previously freed'` | `monitor_signals(obj)`のデフォルト引数`_auto_free=true`によりAutoloadが誤って解放された | Autoload等テスト終了後も生存すべきオブジェクトには`monitor_signals(obj, false)`を明示する |
| `Attempt to open script '...GdUnitCmdTool.gd' resulted in error 'File not found'` | `atelier/`に`cd`せずリポジトリルートから`runtest.sh`を呼んだ | 必ず`cd atelier`してから実行する（[`bash-commands.md`](./bash-commands.md)参照） |

---

## Appendix: 既存ルールとの cross-reference

- [`testing.md`](./testing.md) — GdUnit4テストの配置・記法規定（回帰テストはこちら）
- [`godot-best-practices.md`](./godot-best-practices.md) — シーン/ノードライフサイクル
- [`bash-commands.md`](./bash-commands.md) — GdUnit4 CLI実行コマンド
- [`code-review.md`](./code-review.md) — PRレビュー基準（調査由来のバグの扱い）
