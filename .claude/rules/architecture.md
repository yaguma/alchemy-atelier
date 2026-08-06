# アーキテクチャ・ディレクトリ構成ルール

> 🔴 2026-08-06改訂: 技術スタックがGodot 4.x + GDScriptに確定済み（`CLAUDE.md`参照）のため、本ファイルはTypeScript/Phaser前提からGDScript/Godot前提に全面書き換えした。設計時点の対応表は[`docs/design/atelier-alchemy-core/architecture.md`](../../docs/design/atelier-alchemy-core/architecture.md)を正とし、本ファイルはその実装運用ルールを抜粋・翻訳したものである。

## 採用アーキテクチャ

本プロジェクトでは以下のアーキテクチャパターンを採用する。

1. **Feature-Based Architecture** - 機能単位でのコード配置
2. **Functional Core, Imperative Shell** - 純粋関数とI/Oの分離

---

## Feature-Based Architecture

### 概要

コードを技術的なレイヤー（controllers, services, models等）ではなく、**機能（Feature）単位**で整理する。各機能は自己完結的で、その機能に必要なすべてのコード（UI、ロジック、状態、マスターデータ定義）を`res://features/{feature}/`配下に含む。

### メリット

- **高凝集**: 関連するコードが近くに配置される
- **低結合**: 機能間の依存が明確になる
- **スケーラビリティ**: 新機能追加時に既存コードへの影響が少ない
- **削除容易性**: 機能をフォルダごと削除できる

### ディレクトリ構成

```
atelier-alchemy/
├── project.godot
├── autoload/                    # Application層（シングルトンNode）
│   ├── game_state.gd            # GameState Autoload（状態の一元管理）
│   └── rng_service.gd           # RngService Autoload（乱数の一元管理）
├── features/                    # 機能単位のモジュール
│   ├── garden/                  # 庭（仕込み層）
│   ├── alchemy/                 # 調合（主戦場）★ゲームの核心
│   ├── guild/                   # ギルド納品
│   ├── workshop/                # 工房強化・ショップ
│   └── rank/                    # ランク進行・昇格試験
├── shared/                      # 機能横断の共通コード
│   ├── constants/
│   │   └── game_balance.gd      # GameBalance（ゲームバランス定数）
│   ├── theme/
│   │   └── theme.gd             # UiTheme（見た目の定数）
│   └── entities/                # 複数Featureにまたがるインスタンス型
│       ├── material_instance.gd
│       └── product_instance.gd
├── data/                        # マスターデータ実データ（.tres）
│   ├── materials/*.tres
│   ├── recipes/*.tres
│   └── ...
├── scenes/                      # ルートシーン（機能を組み合わせる）
│   ├── boot.tscn
│   ├── main.tscn
│   └── result.tscn
└── tests/                       # GUTテスト
    └── unit/
        └── features/
```

詳細な完全版は[`docs/design/atelier-alchemy-core/architecture.md`](../../docs/design/atelier-alchemy-core/architecture.md)「ディレクトリ構造（案）」を参照。

### 機能モジュールの構成例

```
features/alchemy/
├── logic/                       # Domain層（純粋関数、副作用なし）
│   ├── quality_calculator.gd
│   ├── trait_activation.gd
│   └── product_value_calculator.gd
├── state/                       # ランタイム状態型（RefCounted継承）
│   └── slot_state.gd
├── resources/                   # マスターデータ型定義（Resource継承）
│   ├── material_master.gd
│   └── recipe_master.gd
└── ui/                          # Presentation層（Control継承）
    ├── alchemy_screen.tscn
    └── alchemy_screen.gd
```

### 公開APIパターン（GDScriptでの代替）

GDScriptには`import`文や`index.ts`に相当する明示的なモジュール公開の仕組みがない。`class_name`を付けたクラスはプロジェクト全体から暗黙にグローバル参照可能になる。そのため、TypeScriptのような「公開APIファイル経由の輸出制御」は言語機能では強制できず、以下を**運用ルール**として徹底する。

- 他Featureから参照してよいのは、当該Featureの`logic/*.gd`（`static func`群）と`resources/*.gd`（マスターデータ型）のみ
- 他Featureの`state/`（ランタイム状態）・`ui/`（UI）を直接参照しない
- Domain層のシステム同士は互いを参照しない。すべてのデータ受け渡しはApplication層（`GameState`）が仲介する（[`core-systems.md`](../../docs/design/atelier-alchemy-core/core-systems.md)「システム間相互作用まとめ」参照）

### クラス参照方法

```gdscript
# 推奨: class_name経由のグローバル参照（プロジェクト全体で統一）
var quality := QualityCalculator.calculate_quality(materials)

# class_nameを使わない場合はpreloadで明示的に参照する
const QualityCalculator = preload("res://features/alchemy/logic/quality_calculator.gd")
```

---

## Functional Core, Imperative Shell

### 概要

アプリケーションを2つの部分に分離する。

| 部分 | 責務 | 特徴 |
|------|------|------|
| **Functional Core** | ビジネスロジック | `static func`、副作用なし、テスト容易 |
| **Imperative Shell** | I/O、状態管理、UI | 副作用あり、外部との境界 |

### Functional Core（純粋関数）

入力のみに依存し、常に同じ結果を返す。副作用を持たない。乱数が必要な場合は`RngService`から払い出した値を**引数として受け取る**（内部で乱数を生成しない）。

```gdscript
# features/alchemy/logic/quality_calculator.gd
class_name QualityCalculator

## 投入素材の品質スコア平均を四捨五入し、触媒タグ保有時は+1して返す（純粋関数）
static func calculate_quality(materials: Array[MaterialInstance]) -> int:
	var total := 0
	for m in materials:
		total += m.quality_score
	var avg := roundi(float(total) / materials.size())
	if _has_catalyst(materials):
		avg += 1
	return clampi(avg, 1, 5)

static func _has_catalyst(materials: Array[MaterialInstance]) -> bool:
	for m in materials:
		if m.trait_tags.has(&"catalyst"):
			return true
	return false
```

### Imperative Shell（副作用を持つ層）

外部とのI/O、状態の更新、シーン/UIの生成を担当。

```gdscript
# autoload/game_state.gd（Imperative Shell）
extends Node

signal product_crafted(quality: int)

func execute_alchemy(recipe_id: StringName, material_ids: Array[String]) -> void:
	# 状態の読み取り（副作用）
	var materials := _resolve_materials(material_ids)

	# 純粋関数の呼び出し（Functional Core）
	var quality := QualityCalculator.calculate_quality(materials)

	# 状態の更新（副作用）
	_inventory.erase_many(material_ids)

	# signal発行（副作用、EventBus相当）
	product_crafted.emit(quality)
```

### 設計指針

#### Functional Core に置くもの

- 計算ロジック（報酬計算、品質計算、貢献度計算等）
- バリデーション（`can_execute`等の判定関数）
- データ変換
- ビジネスルール判定

→ すべて`res://features/{feature}/logic/*.gd`（`class_name`付き`static func`集合、`Node`非継承）に配置する。

#### Imperative Shell に置くもの

- `Control`継承のUIシーン（`res://features/{feature}/ui/*.tscn` + `*.gd`）
- Autoload（`GameState`, `RngService`）の状態操作
- `signal`の発行・購読
- `Resource`のロード（マスターデータ参照）
- 将来のセーブ/ロード等のファイルI/O

### テスト戦略

| 部分 | テスト方法 | カバレッジ目標 |
|------|-----------|--------------|
| Functional Core | GUTユニットテスト（モック不要） | 90%+ |
| Imperative Shell | GUT統合テスト・手動プレイテスト | 60%+ |

```gdscript
# tests/unit/features/alchemy/test_quality_calculator.gd
extends GutTest

func test_素材の平均品質を計算する() -> void:
	var materials: Array[MaterialInstance] = [
		_make_material(4),
		_make_material(2),
	]

	var result := QualityCalculator.calculate_quality(materials)

	assert_eq(result, 3) # (4+2)/2
```

---

## レイヤー間依存ルール

- **Presentation層（`ui/`）** → Application, Domain, Infrastructureすべて参照可
- **Application層（`autoload/`）** → Domain, Infrastructure参照可。Presentationは参照しない
- **Domain層（`logic/`）** → Infrastructure（マスターデータ型の参照のみ）可。Application・Presentationは参照しない
- **Infrastructure層（`resources/`, `data/`）** → 他レイヤーに依存しない

検証責務の配置原則（Presentationは先出しフィードバックのみ、Applicationが実行直前に必ずDomain層を再評価する等）は[`docs/design/atelier-alchemy-core/architecture.md`](../../docs/design/atelier-alchemy-core/architecture.md)「検証責務のレイヤー配置原則」を参照。

---

## テストファイル配置

GUT（Godot Unit Test）の規約に従い**専用ディレクトリ配置**パターンを採用する。

```
tests/
├── unit/
│   ├── features/           # 機能単位のテスト（features/と対応）
│   │   ├── garden/
│   │   ├── alchemy/
│   │   └── ...
│   └── shared/              # 共通コードのテスト
└── integration/             # 統合テスト
```

### 禁止事項

- `features/` 配下にテストファイル（`test_*.gd`）を配置しない
- GUTの既定命名規則`test_*.gd`（`extends GutTest`）から外れたファイル名を使わない

---

## 禁止事項

- 機能モジュール間の直接的な内部参照（他Featureの`state/`・`ui/`への直接参照）
- Functional Core内での副作用（状態変更、I/O、乱数生成等。乱数は`RngService`から引数で受け取る）
- Imperative Shell内での複雑なビジネスロジック
- Domain層システム同士の直接参照（`GameState`を介さない呼び出し）
- 循環依存の発生
