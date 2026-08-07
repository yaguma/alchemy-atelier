# Godot デバッグ・調査ツール運用ルール

> 🔴 2026-08-06新規作成: 旧`playwright-mcp.md`・`playwright-mcp-cookbook.md`（ブラウザ版Phaserゲーム前提）を置き換える。技術スタックがGodot 4.x + GDScriptに確定済み（`CLAUDE.md`参照）だが、**本環境にはGodot用のブラウザ自動操作MCP相当のツールは存在しない**（Unity向けの`UnityMCP`はあるがGodotには非対応）。そのため調査・再現・手動検証のワークフローはPlaywrightMCPとは根本的に異なる形に置き換える。

## 基本原則

- **自動化された状態注入（旧`browser_evaluate`相当）はGodotに標準では存在しない**。再現手順は基本的に**GUT統合テストとして書く**ことで「壊れない再現コード」にする（[`testing.md`](./testing.md)「E2E相当のテスト」参照）
- 一度きりの調査・目視確認は**Godotエディタでの実行 + リモートシーンツリー**で行う
- 調査で得た再現手順は**必ずGUTテストに昇格**を検討する
- **CIでのGodotエディタ手動操作は当然行わない**（CIはGUT CLI一択）

---

## 調査手法の判断フロー

| 用途 | 手法 |
|------|------|
| バグ1回の再現・スクリーンショット撮影 | Godotエディタでの手動プレイ + `Debugger`パネル |
| ランダム探索・状態の直接確認 | エディタ実行中のリモートシーンツリー（`Remote`タブ） |
| 状態を直接注入して特定シナリオを再現したい | GUTの`before_each`でシーン/Autoloadを直接操作するテストコードを書く（下記「状態セットアップ雛形」参照） |
| 回帰テスト・再発防止 | GUTのシーンレベル統合テスト（`tests/integration/`） |
| CI実行 | GUT CLI（`godot --headless -s addons/gut/gut_cmdln.gd`）一択 |
| パフォーマンス測定 | Godotエディタ内蔵`Profiler`/`Monitors`（[`performance.md`](./performance.md)参照） |

判断の優先順:

1. 既存のGUT統合テストで再現できるなら、それを拡張する
2. 再現テストがまだ無く一度だけ確認したい場合は、エディタでの手動プレイ + リモートシーンツリー
3. 調査で得た再現手順は、GUT統合テストへ移植して回帰テスト化する

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
- 複雑な状態を作りたい場合はエディタでの手動操作よりも、GUTテストコードでの状態構築を優先する（再現性・レビュー可能性のため）

---

## 状態セットアップ雛形（GUT統合テストでの記述例）

ブラウザ版の`playwright-mcp-cookbook.md`にあった「雛形」は、Godot版ではGUT統合テストの`before_each`ロジックとして書く。1雛形＝1ヘルパー関数を目安にする。

### 雛形1: セーブデータリセット相当（初期状態からの起動）

セーブ/ロード機能は現行スコープ外（`CLAUDE.md`参照）のため、「リセット」は`GameState`（Autoload、プロセス内で単一）の内部状態を初期値に戻すことを指す。`GameState`はAutoloadのため、雛形2〜4のようにテストコードが直接参照する対象と同じインスタンスでなければ意味がない。ローカルに新規インスタンスを`.new()`しても、Autoload本体にもUIにも反映されず「リセットしたつもり」になるだけなので行わない。

```gdscript
func before_each() -> void:
	GameState.reset_for_test()
```

> 🔵 `GameState`（`autoload/game_state.gd`）に`reset_for_test()`（内部状態を初期値へ戻すメソッド）を実装しておくことが前提。テスト分離のためだけに使うメソッドであることが分かるよう命名し、本番コードパスからは呼び出さない。

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
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child_autofree(main)

	_jump_to_phase(&"alchemy")
	var material := _add_material_to_inventory(&"herb_common", 3)

	var alchemy_screen: AlchemyScreen = main.get_node("%AlchemyScreen")
	alchemy_screen.select_recipe(&"healing_potion")
	alchemy_screen.insert_material(material)
	alchemy_screen.execute()

	assert_eq(GameState.get_state().current_phase, &"guild_delivery")
```

### 実行順のベストプラクティス

複合的な状態を作りたい場合の典型的な順序:

1. 雛形1（初期化）
2. 雛形2（フェーズジャンプ）※必要な場合のみ
3. 雛形3（在庫構築）※必要な場合のみ
4. 対象操作の実行
5. `assert_*`で結果検証
6. 必要ならスクリーンショット（下記「目視確認用スクリーンショット」）で状態を記録

各ステップ後にアサーションを挟み、失敗したら中断して原因調査する。

---

## 目視確認用スクリーンショット

自動テスト中にスクリーンショットを撮りたい場合は`Viewport.get_texture().get_image().save_png()`を使う。

> 🔴 `res://`はエクスポート後にPCKへ固められ読み取り専用になるため、書き込み先には必ず`user://`を使う。`save_png()`はエラー時に`Error`（非OK）を返すだけで例外を投げないため、戻り値を必ず確認する。また撮影直前に描画完了を待たないとキャプチャが空・前フレームの内容になることがあるため`await RenderingServer.frame_post_draw`を挟む。

```gdscript
func _save_debug_screenshot(topic: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var date_str := Time.get_date_string_from_system().replace("-", "")
	var dir := "user://debug-screenshots/%s" % date_str
	DirAccess.make_dir_recursive_absolute(dir)
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

Godotエディタの`Output`パネル、および`Debugger`パネルの`Errors`タブでエラー・警告を確認する。GUT実行時はターミナル出力にテスト結果とともにエラーが流れる。

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

現時点では未実装。個人開発規模ではGUTテストコードでの状態構築で十分まかなえるため、必要性が明確になった時点で着手を検討する（🟡本文書での提案、確定事項ではない）。

---

## 禁止事項とレビュー観点

### 禁止

- 本番配布ビルドでのデバッグコンソール有効化（`OS.is_debug_build()`ガード必須）
- リモートシーンツリーでの値書き換えを「検証済みの動作」として扱う（あくまで調査用の一時操作）
- `debug-*.png`や`user://debug-screenshots/`から手動コピーした調査用画像のコミット
- CIでのGodotエディタGUI操作（CIはGUT CLIのみ）

### PRレビュー観点

- 手動調査で見つけたバグがGUT統合テストに昇格されているか
- 調査用スクリーンショットがコミットに混入していないか
- 本ファイルに未カバーの罠が見つかったら追記する

---

## トラブルシュート早見表

| 症状 | 原因 | 対処 |
|------|------|------|
| リモートシーンツリーにAutoloadが出てこない | `project.godot`のAutoload登録漏れ | `Project > Project Settings > Autoload`を確認 |
| GUTテストが`Node not found`で失敗 | `add_child_autofree()`忘れ、またはシーンツリー未接続でのノード参照 | テスト対象を`add_child_autofree()`してから操作する |
| シグナル購読が二重に呼ばれる | `_ready()`が複数回呼ばれるノード構成（シーン再インスタンス化等） | `is_connected()`チェックを徹底する（[`state-management.md`](./state-management.md)参照） |
| `use_parameters()`のケースが想定通り実行されない | パラメータ配列の要素の型・順序が関数内の参照順と不一致、またはデフォルト引数の構文誤り | GUT公式ドキュメントの`use_parameters`構文と照合し、`params[i]`のインデックス対応を確認 |

---

## Appendix: 既存ルールとの cross-reference

- [`testing.md`](./testing.md) — GUTテストの配置・記法規定（回帰テストはこちら）
- [`godot-best-practices.md`](./godot-best-practices.md) — シーン/ノードライフサイクル
- [`bash-commands.md`](./bash-commands.md) — GUT CLI実行コマンド
- [`code-review.md`](./code-review.md) — PRレビュー基準（調査由来のバグの扱い）
