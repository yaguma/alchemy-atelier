# テストルール

> 🔴 2026-08-06改訂: 技術スタックがGodot 4.x + GDScriptに確定済み（`CLAUDE.md`参照）のため、本ファイルはVitest+Playwright前提からGUT（Godot Unit Test）前提に全面書き換えした。ブラウザ前提だったPlaywrightMCPの運用は[`godot-debug-tools.md`](./godot-debug-tools.md)（調査・手動検証専用）に置き換えている。
> 🔴 2026-08-10改訂: Godot 4.7のAsset Store移行期にGUTが導入できなかったため、テストフレームワークをGdUnit4に切り替えた。本ファイルのGUT前提の記述を全面的にGdUnit4に置き換えた（実際に`atelier/tests/integration/`でGdUnit4テストの動作確認済み）。

## 基本原則

- TDD（テスト駆動開発）を推奨
- テストをスキップせず、問題があれば修正
- 実装詳細ではなく振る舞いをテスト
- **回帰テストは GdUnit4（`tests/`配下）で書く**。Godotエディタでの手動プレイ・リモートデバッガでの調査は[`godot-debug-tools.md`](./godot-debug-tools.md)を参照（CI実行しない調査専用）

---

## テストの種類と配置

### ディレクトリ構成

```
tests/
├── unit/                    # ユニットテスト
│   ├── features/            # 機能単位のテスト
│   │   ├── garden/
│   │   ├── alchemy/
│   │   └── ...
│   └── shared/               # 共通コードのテスト
└── integration/              # 統合テスト（Autoload・シーンツリー経由の連携）
```

Godot/GdUnit4には「E2E専用ディレクトリ」に相当する標準構成がない。クリティカルパスのシーン往復確認は`integration/`内で`scene_runner()`を使うGdUnit4テストとして書くか、手動プレイテストで代替する（下記「E2E相当のテスト」参照）。

### テスト種別

| 種別 | ツール | 対象 | カバレッジ目標 |
|------|--------|------|--------------|
| ユニット | GdUnit4 | 純粋関数（`logic/*.gd`） | 90%+ |
| 統合 | GdUnit4 | Autoload連携、シグナル発行、シーンツリー経由の動作 | 70%+ |
| E2E相当 | GdUnit4の`scene_runner()` + 手動プレイテスト | ユーザーフロー | クリティカルパス |

---

## ユニットテスト

### ファイル命名

- `test_{対象ファイル名}.gd`（GdUnit4の既定規則、`extends GdUnitTestSuite`）
- 配置: `tests/unit/`以下（`features/`内に配置しない）

### 構造

```gdscript
extends GdUnitTestSuite

class TestNormalCases:
	extends GdUnitTestSuite

	func test_投入素材の平均品質を算出する() -> void:
		var materials: Array[MaterialInstance] = [_make_material(4), _make_material(2)]

		var result := QualityCalculator.calculate_quality(materials)

		assert_int(result).is_equal(3) # (4+2)/2

	func test_触媒タグ保有時に品質へボーナスが加算される() -> void:
		var materials: Array[MaterialInstance] = [_make_material(3, [&"catalyst"]), _make_material(3)]

		var result := QualityCalculator.calculate_quality(materials)

		assert_int(result).is_equal(4)

class TestErrorCases:
	extends GdUnitTestSuite

	func test_品質上限を超えないようクランプされる() -> void:
		var materials: Array[MaterialInstance] = [_make_material(5, [&"catalyst"]), _make_material(5)]

		var result := QualityCalculator.calculate_quality(materials)

		assert_int(result).is_equal(5)
```

### テストダブル

```gdscript
var _mocked_rng: RngServiceScript

const RngServiceScript = preload("res://autoload/rng_service.gd")

func before_test() -> void:
	# RngServiceはAutoload（インスタンス）のため、mock()にはスクリプト自体を渡す
	_mocked_rng = mock(RngServiceScript)
	do_return(0.5).on(_mocked_rng).roll_quality()
```

GdUnit4は`before_test()`/`after_test()`ごとにテストケースを分離実行するため、モックの再生成は各テストケースの中で行えばよい（GUTの`before_each`/`after_each`に相当）。

---

## 統合テスト

### 配置

`tests/integration/`以下

### 例: GameState + signal連携

```gdscript
extends GdUnitTestSuite

func before_test() -> void:
	# GameStateはAutoload（プロセス内で単一）のため、テストごとにreset_for_test()で初期化する
	GameState.reset_for_test()

func test_フェーズ変更時にシグナルが発行される() -> void:
	# GameStateはAutoload（テスト終了後も生存し続ける必要がある）のため、
	# monitor_signals()のデフォルト挙動（テスト終了時の自動解放）を明示的に無効化する
	monitor_signals(GameState, false)

	GameState.set_phase(&"alchemy")

	await assert_signal(GameState).is_emitted(GameState.phase_changed, &"garden", &"alchemy")
```

> 🔵 `GameState`はAutoload（シングルトン）であるため、テストごとに新規インスタンスを生成して差し替えることはできない。テスト分離のため`GameState`自身に`reset_for_test()`（内部状態を初期値へ戻すメソッド）を実装することを前提とする。ローカルインスタンスを生成する`GameStateType.new()`のようなパターンは、Autoload本体にもUIにも反映されないため使用しない。

> 🔴 **重大な罠**: `monitor_signals(source: Object, _auto_free := true)`はデフォルトで監視対象をテスト終了時に自動解放する。Autoload等、テスト終了後も生存すべきオブジェクトに対して第2引数を省略すると、`GameState`自体が解放され以降の全テストが`Nonexistent function 'xxx' in base 'previously freed'`で失敗する（実際に発生した障害）。Autoloadを監視する場合は必ず`monitor_signals(obj, false)`と明示する。

GdUnit4の`monitor_signals()` / `assert_signal()`を使うと、Vitestの`vi.fn()`によるイベント検証に相当する検証ができる。`assert_signal()`系のアサーションは`await`が必須。

---

## E2E相当のテスト（シーンレベル統合テスト + 手動プレイテスト）

Godotには Playwright CLI のようなブラウザ操作ベースのE2Eフレームワークが存在しない。クリティカルパス（ターン一巡・調合実行・納品決算等）は以下の2段構えでカバーする。

### 1. GdUnit4のシーンテスト（自動回帰用）

`scene_runner()`でシーンをロードし、ノードのメソッド呼び出し・シグナル発行で操作をシミュレートする。

```gdscript
extends GdUnitTestSuite

func before_test() -> void:
	GameState.reset_for_test()

func test_調合を実行して納品まで到達する() -> void:
	var runner := scene_runner("res://scenes/main.tscn")

	var alchemy_screen: AlchemyScreen = runner.find_child("AlchemyScreen")
	alchemy_screen.select_recipe(&"healing_potion")
	alchemy_screen.insert_material(_mock_material_instance())
	alchemy_screen.execute()

	assert_that(GameState.get_state().current_phase).is_equal(&"guild_delivery")
```

### 2. 手動プレイテスト（調査・目視確認専用）

Godotエディタでの実行、またはエクスポートしたデバッグビルドでの実プレイによる確認。手順は[`godot-debug-tools.md`](./godot-debug-tools.md)を参照（CI実行はしない）。

### 回帰テストへの昇格

手動プレイテストで見つけたバグは、再現手順を1のGdUnit4シーンテストへ昇格することを必ず検討する。

---

## テスト実行

### コマンド

GdUnit4のCLIツール（`runtest.sh`/`runtest.cmd`）は`--path`相当のオプションを持たず、`res://`パス解決がカレントディレクトリ基準で行われるため、**必ず`atelier/`に`cd`してから実行する**（実証済み。リポジトリルートから絶対パスで呼ぶと`res://addons/gdUnit4/bin/GdUnitCmdTool.gd`が見つからずエラーになる）。

```bash
# 最初に一度だけcd
cd atelier

# ユニット/統合テスト（全体）
GODOT_BIN="/c/Godot/godot.exe" ./addons/gdUnit4/runtest.sh -a res://tests/

# 特定ディレクトリ
GODOT_BIN="/c/Godot/godot.exe" ./addons/gdUnit4/runtest.sh -a res://tests/unit/features/garden/

# 特定ファイル
GODOT_BIN="/c/Godot/godot.exe" ./addons/gdUnit4/runtest.sh -a res://tests/unit/features/alchemy/test_quality_calculator.gd

# 特定ディレクトリ全体を実行しつつ、特定テストケースのみ除外
GODOT_BIN="/c/Godot/godot.exe" ./addons/gdUnit4/runtest.sh -a res://tests/ -i "test_quality_calculator.gd:test_境界値ケース"
```

`GODOT_BIN`にはリネーム済みのGodot実行ファイル絶対パスを指定する。デフォルトでは最初の失敗でテスト実行が打ち切られる（fail fast）ため、全件実行したい場合は`-c`（`--continue`）オプションを付ける。

具体的なCLIオプションは`--help-advanced`で確認できる（[`docs/design/atelier-alchemy-core/architecture.md`](../../docs/design/atelier-alchemy-core/architecture.md)「テスト運用規約」参照）。

---

## カバレッジ目標

GDScript/GdUnit4には標準のカバレッジ計測機構がないため、%ベースの数値目標は採用しない。代わりに「`logic/*.gd`の全public `static func`に正常系・異常系・境界値のテストを最低1本ずつ持つ」という数え上げ可能な基準を採用する（[`tdd-implementation.md`](./tdd-implementation.md)「カバレッジ目標」参照。この決定は[`docs/design/atelier-alchemy-core/decision-log.md`](../../docs/design/atelier-alchemy-core/decision-log.md)に記録）。

| 領域 | 基準 |
|------|------|
| Functional Core（`logic/`） | 全public `static func`に正常系・異常系・境界値のテストを最低1本ずつ |
| 共通ユーティリティ（`shared/`） | 同上 |
| UIコンポーネント（`ui/`） | 主要なsignal連携・ユーザー操作パスをGdUnit4シーンテストでカバー（数値目標なし） |

### 除外対象

- マスターデータ型定義（`resources/*.gd`）
- 設定ファイル（`project.godot`）
- モック・フィクスチャ（`tests/mocks/`）

GDScript/GdUnit4には標準のカバレッジ計測機構がない点は[`tdd-implementation.md`](./tdd-implementation.md)「カバレッジ目標」参照。

---

## ベストプラクティス

### Arrange-Act-Assert

```gdscript
func test_ゴールドが加算される() -> void:
	# Arrange
	var initial_gold := 100
	var state := _create_state({"gold": initial_gold})

	# Act
	var result := GoldLogic.add_gold(state, 50)

	# Assert
	assert_int(result.gold).is_equal(150)
```

### 境界値テスト（`test_parameters`）

```gdscript
func test_数量が範囲内に丸められる(value: int, expected: int, _test_parameters := [
	[0, 1],      # 最小値以下
	[1, 1],      # 最小値
	[50, 50],    # 中間値
	[99, 99],    # 最大値
	[100, 99],   # 最大値超過
]) -> void:
	assert_int(QuantityValidator.validate(value)).is_equal(expected)
```

### 非同期処理のテスト

```gdscript
func test_データ読み込み後に表示更新される() -> void:
	var component := auto_free(DataComponent.new())
	add_child(component)

	await component.load_data()

	assert_str(component.get_text()).is_equal("Loaded")
```

GdUnit4は`await`を使ったコルーチンテストをネイティブにサポートする。

---

## 禁止事項

- テストケースパラメータの`do_skip`（GdUnit4のスキップ機構）を放置しない
- テスト内で`print()`を残さない
- CI環境でテストを絞り込んだままの実行設定を放置しない（`-a`の対象パスをCI用に戻す）
- テスト間に依存関係を作らない（各`before_test`で状態を作り直す）
- 実装詳細（`_`prefixのprivateメソッド）を直接テストしない
- `features/`内にテストファイルを配置しない
- Autoloadを`monitor_signals()`する際に`_auto_free`引数（第2引数）を省略しない（デフォルトのAutoload解放を防ぐため）
