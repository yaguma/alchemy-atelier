# TDD実装ルール

> 🔴 2026-08-06改訂: 技術スタックがGodot 4.x + GDScriptに確定済み（`CLAUDE.md`参照）のため、本ファイルはVitest前提からGUT（Godot Unit Test）前提に全面書き換えした。
> 🔴 2026-08-10改訂: Godot 4.7のAsset Store移行期にGUTが導入できなかったため、テストフレームワークをGdUnit4に切り替えた。本ファイルのGUT前提の記述を全面的にGdUnit4に置き換えた（実際に`atelier/tests/integration/`でGdUnit4テストの動作確認済み）。
> 🔴 2026-08-10改訂: `GODOT_BIN`をシステム環境変数として永続設定する運用に変更したため（設定手順は[`README.md`](../../README.md)「開発環境セットアップ」参照）、コマンド例の`GODOT_BIN="/c/Godot/godot.exe"`インライン指定を削除した。

## 概要

プロジェクト固有のTDD（テスト駆動開発）実装ルールを定義する。
テストの基本規約は `testing.md` を参照。本ルールはTDDサイクルの実行手順に特化する。

---

## TDDサイクル

### Red（テスト作成）

#### テストファイル配置

```
tests/unit/features/{feature}/test_{対象サービス名}.gd
```

**禁止**: `features/` 配下へのテストファイル配置

#### クラス参照ルール

```gdscript
# class_name経由のグローバル参照を使用（GDScriptにはimport文がない）
extends GdUnitTestSuite

func test_基本的な動作を検証する() -> void:
	var result := QualityCalculator.calculate_quality(_make_materials())
	assert_int(result).is_equal(3)

# 相対パスpreloadは、class_nameを付けていない補助クラスの参照時のみ使用
const TestFixtures = preload("res://tests/mocks/fixtures.gd")
```

#### 内部テストクラスによるグルーピング（`describe`相当）

GdUnit4はネストした内部クラス（いずれも`GdUnitTestSuite`を継承）でテストをグルーピングできる。正常系と異常系を必ず分離する。

```gdscript
extends GdUnitTestSuite

class TestNormalCases:
	extends GdUnitTestSuite

	func test_基本的な動作を検証する() -> void:
		pass

	func test_別のケースを検証する() -> void:
		pass

class TestErrorCases:
	extends GdUnitTestSuite

	func test_無効な入力でエラーを返す() -> void:
		pass

	func test_境界値で適切に処理する() -> void:
		pass
```

#### 失敗確認コマンド

GdUnit4の`runtest.sh`/`runtest.cmd`は`--path`相当のオプションを持たないため、`atelier/`に`cd`してから実行する（実証済み）。

```bash
cd atelier
./addons/gdUnit4/runtest.sh -a res://tests/unit/features/{feature}/test_{ファイル}.gd
```

テストが**失敗する**ことを必ず確認する。テストが成功してしまう場合はテスト設計を見直す。

---

### Green（最小実装）

#### 実装先

```
features/{feature}/logic/{サービス名}.gd
```

#### 純粋関数の原則

Functional Coreに配置する関数は以下を遵守する:

- 副作用なし（外部状態の読み取り・変更をしない）
- 入力のみに依存（引数以外の情報を使わない）
- 同じ入力に対して常に同じ出力を返す
- 乱数が必要な場合は`RngService`が払い出した値を引数で受け取る

```gdscript
# OK: 純粋関数
class_name RewardCalculator

static func calculate_reward(difficulty: StringName, base_gold: int) -> int:
	return base_gold * GameBalance.DIFFICULTY_MULTIPLIER[difficulty]

# NG: 副作用あり
static func calculate_reward_bad(difficulty: StringName) -> int:
	var base_gold: int = GameState.get_state().gold  # 外部状態の参照
	return base_gold * GameBalance.DIFFICULTY_MULTIPLIER[difficulty]
```

#### 最小実装の原則

テストを通す**最小限のコード**のみ記述する。

- 将来必要になりそうな機能を先に実装しない
- テストケースにない分岐を追加しない
- 過度な抽象化を行わない

#### 成功確認コマンド

```bash
cd atelier
./addons/gdUnit4/runtest.sh -a res://tests/unit/features/{feature}/test_{ファイル}.gd
```

テストが**成功する**ことを確認する。

---

### Refactor（リファクタリング）

#### テスト維持

リファクタリング中は頻繁にテストを実行し、グリーン状態を維持する。

```bash
cd atelier
./addons/gdUnit4/runtest.sh -a res://tests/unit/features/{feature}/
```

#### リファクタリング対象

| 対象 | 具体例 |
|------|--------|
| 重複排除 | 同じ計算ロジックの関数化 |
| 命名改善 | 意図が伝わる変数名・関数名に変更 |
| 関数分割 | 1関数が長い場合にヘルパー関数に分割 |
| 定数化 | マジックナンバーを`GameBalance`に移動 |
| 型改善 | より厳密な型注釈に変更（`Variant`の排除） |

#### 定数化の判断基準

```
その値を変更するとゲームバランスが変わるか？
  → YES: GameBalance（shared/constants/game_balance.gd）
  → NO: UiTheme または feature内の定数ファイル
```

---

## テストパターン

### Arrange-Act-Assert構造

全テストケースでAAA構造を徹底する。

```gdscript
func test_報酬が正しく計算される() -> void:
	# Arrange: テストデータの準備
	var difficulty := &"C"
	var base_gold := 100

	# Act: テスト対象の実行
	var result := RewardCalculator.calculate_reward(difficulty, base_gold)

	# Assert: 結果の検証
	assert_int(result).is_equal(200)
```

### 境界値テスト（`test_parameters`）

GdUnit4のパラメータ化テスト（関数引数のデフォルト値に`test_parameters`データセットを渡す形式）で境界値を網羅する（VitestやJestの`it.each`に相当）。

```gdscript
func test_品質からグレードを判定する(quality: int, expected: StringName, _test_parameters := [
	[0, &"C"],   # 最小値
	[49, &"C"],  # 閾値直前
	[50, &"B"],  # 閾値
	[69, &"B"],  # 次の閾値直前
	[70, &"A"],  # 次の閾値
	[89, &"A"],  # 最大閾値直前
	[90, &"S"],  # 最大閾値
	[100, &"S"], # 最大値
]) -> void:
	assert_that(GradeResolver.get_grade(quality)).is_equal(expected)
```

### テストダブル（モック）使用

```gdscript
const RngServiceScript = preload("res://autoload/rng_service.gd")

var _mocked_rng: RngServiceScript

func before_test() -> void:
	# RngServiceはAutoload（インスタンス）のため、mock()にはスクリプト自体を渡す
	_mocked_rng = mock(RngServiceScript)
	do_return(0.9).on(_mocked_rng).roll_quality()

func test_乱数結果を差し替えて検証する() -> void:
	var result := Harvest.harvest(_plant_state(), _mocked_rng.roll_quality(), 0.5)
	assert_bool(result.success).is_true()
```

Domain層（`logic/*.gd`）は乱数値を**引数で直接受け取る**設計のため、単体テストでは`mock()`は基本不要（値をそのまま渡せばよい）。`mock()`が必要になるのは、Application層（Autoload）の統合テストで`RngService`そのものを差し替える場合に限られる。

---

## サイクル完了後の作業

### クラス参照の確認

GDScriptには`index.ts`のような明示的な公開APIファイルはない。新規クラスが`class_name`を持ち、プロジェクト全体からグローバル解決可能であることをGodotエディタの「スクリプトにエラーがないこと」で確認する。

### 全体確認

```bash
# 全テスト（atelier/にcd済み前提）
cd atelier
./addons/gdUnit4/runtest.sh -a res://tests/

# gdlint（静的解析。型の欠落やスタイル違反を検出。リポジトリルートまたはatelier配下いずれからでも可）
gdlint atelier/features/ atelier/shared/ atelier/autoload/
```

---

## カバレッジ目標

GDScript/GdUnit4には標準のカバレッジ計測機構がないため、%ベースの数値目標は採用しない。「`logic/*.gd`の全public `static func`に正常系・異常系・境界値のテストを最低1本ずつ持つ」という数え上げ可能な基準に一本化する（個人開発規模での運用を踏まえた決定。[`docs/design/atelier-alchemy-core/decision-log.md`](../../docs/design/atelier-alchemy-core/decision-log.md)に記録）。

### 除外対象

- マスターデータ型定義ファイル（`resources/*.gd`、ロジックを持たない`Resource`定義）
- 設定ファイル（`project.godot`等）
- モック・フィクスチャ（`tests/mocks/`）

---

## よくある間違いと対策

| 間違い | 対策 |
|--------|------|
| テスト未作成で実装を始める | 必ずRedフェーズから開始する |
| テストが失敗中にリファクタリング | Greenを確認してからRefactorに進む |
| 過度な実装（テストにないケース） | テストケースに対応するコードのみ書く |
| `features/`にテストファイルを配置 | `tests/unit/`に配置する |
| `logic/*.gd`に副作用を含む関数 | 副作用はImperative Shell（`autoload/`, `ui/`）に分離 |
| Domain層で乱数を自己生成 | `RngService`から払い出された値を引数で受け取る |
| リポジトリルートから`runtest.sh`を絶対パス実行 | `res://`解決に失敗するため必ず`cd atelier`してから実行する |
| Autoloadを`monitor_signals(obj)`と第2引数省略で監視 | デフォルトで自動解放されるため`monitor_signals(obj, false)`を明示する |
