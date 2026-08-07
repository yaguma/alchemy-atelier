# テストルール

> 🔴 2026-08-06改訂: 技術スタックがGodot 4.x + GDScriptに確定済み（`CLAUDE.md`参照）のため、本ファイルはVitest+Playwright前提からGUT（Godot Unit Test）前提に全面書き換えした。ブラウザ前提だったPlaywrightMCPの運用は[`godot-debug-tools.md`](./godot-debug-tools.md)（調査・手動検証専用）に置き換えている。

## 基本原則

- TDD（テスト駆動開発）を推奨
- テストをスキップせず、問題があれば修正
- 実装詳細ではなく振る舞いをテスト
- **回帰テストは GUT（`tests/`配下）で書く**。Godotエディタでの手動プレイ・リモートデバッガでの調査は[`godot-debug-tools.md`](./godot-debug-tools.md)を参照（CI実行しない調査専用）

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

Godot/GUTには「E2E専用ディレクトリ」に相当する標準構成がない。クリティカルパスのシーン往復確認は`integration/`内でシーンをロードするGUTテストとして書くか、手動プレイテストで代替する（下記「E2E相当のテスト」参照）。

### テスト種別

| 種別 | ツール | 対象 | カバレッジ目標 |
|------|--------|------|--------------|
| ユニット | GUT | 純粋関数（`logic/*.gd`） | 90%+ |
| 統合 | GUT | Autoload連携、シグナル発行、シーンツリー経由の動作 | 70%+ |
| E2E相当 | GUTのシーンテスト + 手動プレイテスト | ユーザーフロー | クリティカルパス |

---

## ユニットテスト

### ファイル命名

- `test_{対象ファイル名}.gd`（GUTの既定規則、`extends GutTest`）
- 配置: `tests/unit/`以下（`features/`内に配置しない）

### 構造

```gdscript
extends GutTest

class TestNormalCases:
	extends GutTest

	func test_投入素材の平均品質を算出する() -> void:
		var materials: Array[MaterialInstance] = [_make_material(4), _make_material(2)]

		var result := QualityCalculator.calculate_quality(materials)

		assert_eq(result, 3) # (4+2)/2

	func test_触媒タグ保有時に品質へボーナスが加算される() -> void:
		var materials: Array[MaterialInstance] = [_make_material(3, [&"catalyst"]), _make_material(3)]

		var result := QualityCalculator.calculate_quality(materials)

		assert_eq(result, 4)

class TestErrorCases:
	extends GutTest

	func test_品質上限を超えないようクランプされる() -> void:
		var materials: Array[MaterialInstance] = [_make_material(5, [&"catalyst"]), _make_material(5)]

		var result := QualityCalculator.calculate_quality(materials)

		assert_eq(result, 5)
```

### テストダブル

```gdscript
const RngServiceScript = preload("res://autoload/rng_service.gd")

var _doubled_rng

func before_each() -> void:
	# RngServiceはAutoload（インスタンス）のため、double()にはスクリプト自体を渡す
	_doubled_rng = double(RngServiceScript).new()
	stub(_doubled_rng, "roll_quality").to_return(0.5)

func after_each() -> void:
	pass  # GUTはbefore_each/after_eachごとにダブルを再生成するのが基本
```

---

## 統合テスト

### 配置

`tests/integration/`以下

### 例: GameState + signal連携

```gdscript
extends GutTest

func before_each() -> void:
	# GameStateはAutoload（プロセス内で単一）のため、テストごとにreset_for_test()で初期化する
	GameState.reset_for_test()

func test_フェーズ変更時にシグナルが発行される() -> void:
	watch_signals(GameState)

	GameState.set_phase(&"alchemy")

	assert_signal_emitted_with_parameters(
		GameState, "phase_changed", [&"garden", &"alchemy"]
	)
```

> 🔵 `GameState`はAutoload（シングルトン）であるため、テストごとに新規インスタンスを生成して差し替えることはできない。テスト分離のため`GameState`自身に`reset_for_test()`（内部状態を初期値へ戻すメソッド）を実装することを前提とする。ローカルインスタンスを生成する`GameStateType.new()`のようなパターンは、Autoload本体にもUIにも反映されないため使用しない。

GUTの`watch_signals()` / `assert_signal_emitted_with_parameters()`を使うと、Vitestの`vi.fn()`によるイベント検証に相当する検証ができる。

---

## E2E相当のテスト（シーンレベル統合テスト + 手動プレイテスト）

Godotには Playwright CLI のようなブラウザ操作ベースのE2Eフレームワークが存在しない。クリティカルパス（ターン一巡・調合実行・納品決算等）は以下の2段構えでカバーする。

### 1. GUTのシーンテスト（自動回帰用）

シーンを`add_child_autofree()`でロードし、ノードのメソッド呼び出し・シグナル発行で操作をシミュレートする。

```gdscript
extends GutTest

func test_調合を実行して納品まで到達する() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child_autofree(main)

	var alchemy_screen: AlchemyScreen = main.get_node("%AlchemyScreen")
	alchemy_screen.select_recipe(&"healing_potion")
	alchemy_screen.insert_material(_mock_material_instance())
	alchemy_screen.execute()

	assert_eq(GameState.get_state().current_phase, &"guild_delivery")
```

### 2. 手動プレイテスト（調査・目視確認専用）

Godotエディタでの実行、またはエクスポートしたデバッグビルドでの実プレイによる確認。手順は[`godot-debug-tools.md`](./godot-debug-tools.md)を参照（CI実行はしない）。

### 回帰テストへの昇格

手動プレイテストで見つけたバグは、再現手順を1のGUTシーンテストへ昇格することを必ず検討する。

---

## テスト実行

### コマンド

```bash
# ユニット/統合テスト（全体）
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/ -ginclude_subdirs -gexit

# 特定ディレクトリ
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/features/garden/ -ginclude_subdirs -gexit

# 特定ファイル
godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/features/alchemy/test_quality_calculator.gd -gexit

# パターンマッチ（テスト名でフィルタ）
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/ -ginclude_subdirs -gunit_test_name="calculate_quality" -gexit
```

`-gexit`を付けないとテスト完了後もGUTがメインループを保持し続けプロセスが終了しない。`-gdir`は指定ディレクトリ直下のみ走査するため、`tests/unit/features/{feature}/`のようなネストした配置規約では`-ginclude_subdirs`を必ず付ける（付け忘れると「0 tests, 0 failures」のまま成功終了する偽グリーンになる）。

具体的なCLIオプションは実装着手時に確定する（[`docs/design/atelier-alchemy-core/architecture.md`](../../docs/design/atelier-alchemy-core/architecture.md)「テスト運用規約」🟡参照）。

---

## カバレッジ目標

| 領域 | 目標 |
|------|------|
| 全体 | 80%+ |
| Functional Core（`logic/`） | 90%+ |
| 共通ユーティリティ（`shared/`） | 90%+ |
| UIコンポーネント（`ui/`） | 60%+ |

### 除外対象

- マスターデータ型定義（`resources/*.gd`）
- 設定ファイル（`project.godot`）
- モック・フィクスチャ（`tests/mocks/`）

GDScript/GUTには標準のカバレッジ計測機構がない点は[`tdd-implementation.md`](./tdd-implementation.md)「カバレッジ目標」参照。

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
	assert_eq(result.gold, 150)
```

### 境界値テスト（`use_parameters`）

```gdscript
func test_数量が範囲内に丸められる(params = use_parameters([
	[0, 1],      # 最小値以下
	[1, 1],      # 最小値
	[50, 50],    # 中間値
	[99, 99],    # 最大値
	[100, 99],   # 最大値超過
])) -> void:
	assert_eq(QuantityValidator.validate(params[0]), params[1])
```

### 非同期処理のテスト

```gdscript
func test_データ読み込み後に表示更新される() -> void:
	var component := DataComponent.new()
	add_child_autofree(component)

	await component.load_data()

	assert_eq(component.get_text(), "Loaded")
```

GUTは`await`を使ったコルーチンテストをネイティブにサポートする。

---

## 禁止事項

- `pending()`（GUTのスキップ相当）を放置しない
- テスト内で`print()`を残さない
- CI環境で`-gselect`（単一テストのみ実行）を使ったまま放置しない
- テスト間に依存関係を作らない（各`before_each`で状態を作り直す）
- 実装詳細（`_`prefixのprivateメソッド）を直接テストしない
- `features/`内にテストファイルを配置しない
