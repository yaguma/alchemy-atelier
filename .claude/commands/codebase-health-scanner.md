---
description: コードベースの健全性指標をスキャンし、レポート生成・Issue自動作成を行う
allowed-tools: Read, Glob, Grep, Bash, Write, Edit
argument-hint: [--skip-issue | --report-only | --trend]
---
Godot 4.x + GDScript プロジェクト（`atelier/`）の健全性指標（型なし/Variant使用、循環依存・層違反、未使用public API、デッドコード、マジックナンバー、大きすぎるファイル）をスキャンし、レポートを生成する。閾値を超過した場合はGitHub Issueを自動作成する。

# context

ソースディレクトリ=["atelier/features", "atelier/shared", "atelier/autoload", "atelier/scenes"]
テストディレクトリ="atelier/tests"
スキャン除外=["atelier/addons/**"（GdUnit4・godot-ai等のサードパーティ）, "atelier/.godot/**"（インポートキャッシュ）, "atelier/tests/**"（指標ごとに明記した場合のみ対象）]
レポート出力先="docs/reports"
日付={{YYYY-MM-DD形式の今日の日付}}
レポートファイル="docs/reports/health-scan-{{日付}}.md"
オプション=$1
スキャン結果={}
ヘルススコア=100
前回レポート=null

> 設計の前提は[`architecture.md`](../rules/architecture.md)（Feature-Based Architecture / Functional Core, Imperative Shell）、[`coding-style.md`](../rules/coding-style.md)（静的型付け・`GameBalance`/`UiTheme`への定数化）に従う。各指標はこれらのルール違反を機械的に拾うためのものである。

# 閾値定義

| 指標 | 黄色（Warning） | 赤色（Critical） |
|------|----------------|-----------------|
| 型なし/Variant使用 | 5箇所以上 | 10箇所以上 |
| 循環依存・層違反 | 1件以上 | 3件以上 |
| 未使用public API | 10件以上 | 20件以上 |
| 300行超ファイル | 5ファイル以上 | 10ファイル以上 |
| マジックナンバー | 10箇所以上 | 20箇所以上 |
| デッドコード（未参照ファイル） | 3ファイル以上 | 5ファイル以上 |

# ヘルススコア計算

100点満点から以下の減点を行う:
- 型なし/Variant使用: 1箇所あたり -2点
- 循環依存・層違反: 1件あたり -5点
- 未使用public API: 1件あたり -1点
- 300行超ファイル: 1ファイルあたり -2点
- マジックナンバー: 1箇所あたり -1点
- デッドコード: 1ファイルあたり -3点
- 最低スコアは0点

# step

- オプションを解析する
  - `--skip-issue`: Issue自動作成をスキップ
  - `--report-only`: レポート生成のみ（Issue作成もトレンド比較もスキップ）
  - `--trend`: 前回レポートとのトレンド比較のみ表示
- `--trend` の場合は step7 へジャンプ
- step1 を実行する

## step1: スキャン準備

- ソースディレクトリ（`atelier/features/` 等）の存在を確認する。存在しない場合は「`atelier/` が見つからない。リポジトリルートで実行しているか確認すること」と報告して終了する
- レポート出力先ディレクトリを作成する（存在しない場合）

```bash
mkdir -p docs/reports
```

- 前回のレポートファイルを検索して context の前回レポートに設定する

```bash
ls -t docs/reports/health-scan-*.md 2>/dev/null | head -1
```

- step2 を実行する

## step2: Phase 1 - スキャンエンジン実行

以下の6つのスキャンを順番に実行し、結果を context のスキャン結果に格納する。対象は `*.gd`（および指標2-2・2-4では `*.tscn` / `*.tres`）で、`atelier/addons/` と `atelier/.godot/` は除外する。

### 2-1: 型なし/Variant使用検出（TypeScriptの any 相当）

[`coding-style.md`](../rules/coding-style.md)「静的型付け」に反する、型注釈のない宣言と `Variant` の無条件使用を検出する。Grep ツールを `atelier/features/` `atelier/shared/` `atelier/autoload/` に対して実行する。

検出パターン:
- `var x = ...`（型注釈も `:=` 推論もない変数宣言）
- `func f(a, b):` / `func f(a: int):`（引数の型注釈欠落、戻り値型 `->` の欠落）
- `: Variant` / `-> Variant`（`Variant` の明示使用）

```bash
# 検出コマンド例
grep -rnE "^\s*(var|const)\s+[a-z_][A-Za-z0-9_]*\s*=" atelier/features atelier/shared atelier/autoload --include="*.gd"
grep -rnE "^\s*func\s+\w+\([^)]*\)\s*:" atelier/features atelier/shared atelier/autoload --include="*.gd"
grep -rnE ":\s*Variant\b|->\s*Variant\b" atelier/features atelier/shared atelier/autoload --include="*.gd"
```

除外対象:
- `for x in ...` のループ変数・`match` のバインド（GDScriptの構文上、型注釈を付けられない場面）
- 外部入力の型ガード用 `var x: Variant = d.get(...)` で、直後に `is` 演算子で絞り込んでいるもの（[`security.md`](../rules/security.md)のセーブデータ検証など。`Variant` を型ガードなしで使い続けているものだけを対象とする）
- テストファイル（`atelier/tests/`）
- `atelier/addons/`

結果を `スキャン結果.型なし` に格納する（ファイルパス、行番号、該当コードのリスト）。

### 2-2: 循環依存・層違反検出

GDScriptには `import` 文がなく、依存は `class_name` によるグローバル参照と `preload()` / `load()` / `.tscn` の `ext_resource` で表れる。次の2種類を検出する。

**(a) `preload` の循環参照**: 自シーン・自スクリプトを `preload()` すると `Parse Error: Busy` を引き起こす（Issue #91で踏んだ罠）。A→B→A のような `preload` の相互参照も同様に不具合の原因になる。

```bash
# preloadの抽出例
grep -rnE "preload\(\"res://[^\"]+\"\)" atelier/features atelier/shared atelier/autoload atelier/scenes --include="*.gd"
```

手順:
1. 各ファイルの `preload("res://...")` 先を抽出し、依存グラフを構築する
2. DFS（深さ優先探索）で循環を検出する（自己参照は最も単純な循環）

**(b) アーキテクチャ層違反**（[`architecture.md`](../rules/architecture.md)「公開APIパターン」「レイヤー間依存ルール」）:
- 他Featureの `state/`・`ui/` への直接参照（他Featureから参照してよいのは `logic/*.gd` と `resources/*.gd` のみ）
- Domain層（`logic/`）から `GameState` 等のAutoload・`ui/` を参照している（Functional Coreの純粋性違反）
- `shared/` から `features/` への逆向き依存

```bash
# 例: features/garden/ 配下から他featureのui/・state/を参照している箇所
grep -rnE "(PlantSlotView|SeedInventoryList|AlchemyScreen|GuildDeliveryScreen|UpgradeItemList)" atelier/features/garden --include="*.gd"
# 例: logic/ からAutoloadを参照している箇所
grep -rnE "\b(GameState|RngService)\b" atelier/features/*/logic --include="*.gd"
```

> 他Featureの `state/`・`ui/` クラス名は `class_name` 宣言を Grep で列挙してから、自Feature以外のディレクトリに出現していないかを確認する（上の例は代表例であり、固定リストではない）。

結果を `スキャン結果.循環依存` に格納する（関与するファイルのリスト、循環パス・違反内容の説明）。

### 2-3: 未使用public API検出（TypeScriptの未使用export相当）

GDScriptには `export` がなく、`class_name` を持つクラスの `static func`（`logic/` のpublic関数）と `signal` が公開APIにあたる。どこからも呼ばれていないものを検出する。

手順:
1. Grep ツールで `atelier/features/*/logic/*.gd` の public `static func`（`_` で始まらないもの）と、`atelier/autoload/*.gd` の `signal` 宣言を抽出する
2. 各シンボル名で `atelier/` 全体（`tests/` を除く）を Grep 検索し、呼び出し・`connect` 側での使用を確認する
3. 本番コードから使われていないものを未使用と判定する（テストからのみ呼ばれているものも未使用として計上するが、備考にその旨を書く）

```bash
# public static funcの抽出例
grep -rnE "^static func [a-z][A-Za-z0-9_]*\(" atelier/features/*/logic --include="*.gd"
# signal宣言の抽出例
grep -rnE "^signal \w+" atelier/autoload --include="*.gd"
```

除外対象:
- `_` で始まる関数（private）
- `_ready` `_init` `_process` 等のGodotライフサイクルメソッド、`_on_*` のシグナルコールバック
- マスターデータ型定義（`resources/*.gd`、ロジックを持たない `Resource`）

結果を `スキャン結果.未使用API` に格納する（ファイルパス、行番号、シンボル名のリスト）。

### 2-4: デッドコード検出

どこからも参照されていないファイルを検出する。

手順:
1. Glob ツールで `atelier/features/**/*.gd` `atelier/shared/**/*.gd` `atelier/autoload/**/*.gd` と `*.tscn` を列挙する
2. `class_name` を持つ `.gd` は、そのクラス名が自ファイル以外に出現するかを Grep で確認する
3. `class_name` を持たない `.gd` は、`res://` パスが `preload` / `load` / `.tscn` の `ext_resource` / `project.godot`（Autoload）のどこかに出現するかを確認する
4. `.tscn` は、`res://` パスが `change_scene_to_file` / `preload` / `load` / 他 `.tscn` の `ext_resource` / `project.godot` のどこかに出現するかを確認する
5. どこからも参照されていないファイルを未参照と判定する

```bash
# class_nameの抽出例
grep -rnE "^class_name \w+" atelier/features atelier/shared atelier/autoload --include="*.gd"
# パス参照の確認例（target_fileは対象のres://パス）
grep -rn "features/garden/ui/plant_slot_view.tscn" atelier --include="*.gd" --include="*.tscn" --include="project.godot"
```

除外対象:
- Autoload（`project.godot` の `[autoload]` に登録されたスクリプト）
- `.tres` から `script = ExtResource(...)` で参照されるマスターデータ型（`resources/*.gd`）
- `atelier/scenes/` のエントリーポイント（`boot.tscn` / `main.tscn`）
- `@tool` スクリプトや、エディタからのみ使うヘルパー

結果を `スキャン結果.デッドコード` に格納する（未参照ファイルのリスト）。

### 2-5: マジックナンバー検出

定数化されていない数値リテラルを検出する。ゲームバランスに影響する値は `GameBalance`、見た目の値は `UiTheme` に定数化する方針（[`coding-style.md`](../rules/coding-style.md)「定数管理」）。

検出パターン:
- 関数の引数・条件式内の数値リテラル（`0` `1` `-1` `2` 等の一般的な値を除く）
- タイマー・Tween・アニメーション時間の直値（`create_tween().tween_property(..., 0.3)` 等）
- 色の直値（`Color("#...")` / `Color(0.2, 0.3, ...)`。`UiTheme` に定義すべき値）

```bash
# マジックナンバー検出例（一般的な0, 1, -1, 2は除外）
grep -rnE "[^a-zA-Z_0-9.\"][3-9][0-9]*(\.[0-9]+)?[^a-zA-Z_0-9.x\"]" atelier/features atelier/autoload --include="*.gd"
grep -rnE "Color\(\"#|Color\([0-9]" atelier/features atelier/autoload --include="*.gd"
```

除外対象:
- `shared/constants/game_balance.gd`（`GameBalance`）
- `shared/theme/theme.gd`（`UiTheme`）
- `const` / `enum` 定義内の数値
- 配列インデックス（`[0]`, `[1]` 等）
- バランス値を持たないレイアウト用の `custom_minimum_size` 等は `.tscn` 側の値のため対象外（`.gd` のみスキャンする）
- `atelier/tests/` のテストデータ

結果を `スキャン結果.マジックナンバー` に格納する（ファイルパス、行番号、該当コードのリスト）。

### 2-6: 大きすぎるファイル検出

300行を超える `.gd` ファイルを検出する（[`coding-style.md`](../rules/coding-style.md)「1ファイルの上限」）。

```bash
# 行数カウント
find atelier/features atelier/shared atelier/autoload atelier/scenes -name "*.gd" | xargs wc -l | sort -rn | head -20
```

除外対象:
- 自動生成ファイル
- テストファイル（`atelier/tests/`）
- `atelier/addons/`（サードパーティ）

結果を `スキャン結果.大きすぎるファイル` に格納する（ファイルパス、行数のリスト）。

- step3 を実行する

## step3: ヘルススコア計算

context のスキャン結果から以下の計算でヘルススコアを算出する:

```
スコア = 100
スコア -= 型なし/Variant使用数 * 2
スコア -= 循環依存・層違反数 * 5
スコア -= 未使用public API数 * 1
スコア -= 300行超ファイル数 * 2
スコア -= マジックナンバー数 * 1
スコア -= デッドコードファイル数 * 3
スコア = max(0, スコア)
```

各指標の閾値判定を行い、状態（正常/Warning/Critical）を設定する。

- step4 を実行する

## step4: Phase 2 - レポート生成

Write ツールでレポートファイルを `docs/reports/health-scan-{{日付}}.md` に生成する。

### レポートテンプレート

```markdown
# Codebase Health Scan Report

**日付**: {{日付}}
**ヘルススコア**: {{スコア}}/100 {{スコアに応じた評価}}

## サマリー

| 指標 | 件数 | 状態 | 前回比 |
|------|------|------|--------|
| 型なし/Variant使用 | {{数}} | {{正常/Warning/Critical}} | {{+N/-N/=}} |
| 循環依存・層違反 | {{数}} | {{正常/Warning/Critical}} | {{+N/-N/=}} |
| 未使用public API | {{数}} | {{正常/Warning/Critical}} | {{+N/-N/=}} |
| 300行超ファイル | {{数}} | {{正常/Warning/Critical}} | {{+N/-N/=}} |
| マジックナンバー | {{数}} | {{正常/Warning/Critical}} | {{+N/-N/=}} |
| デッドコード | {{数}} | {{正常/Warning/Critical}} | {{+N/-N/=}} |

## スコア評価基準

| スコア | 評価 |
|--------|------|
| 90-100 | Excellent - コードベースは非常に健全 |
| 70-89 | Good - 軽微な改善点あり |
| 50-69 | Fair - 改善が必要 |
| 30-49 | Poor - 早急な対応が必要 |
| 0-29 | Critical - 重大な問題あり |

## 詳細

### 型なし/Variant使用 ({{数}}箇所)

| ファイル | 行 | コード |
|---------|-----|--------|
{{各検出箇所をテーブル行として出力}}

### 循環依存・層違反 ({{数}}件)

{{循環パス・違反内容の説明}}

### 未使用public API ({{数}}件)

| ファイル | 行 | シンボル名 |
|---------|-----|-----------|
{{各検出箇所をテーブル行として出力}}

### デッドコード ({{数}}ファイル)

| ファイル | 備考 |
|---------|------|
{{各未参照ファイルをテーブル行として出力}}

### マジックナンバー ({{数}}箇所)

| ファイル | 行 | コード |
|---------|-----|--------|
{{各検出箇所をテーブル行として出力}}

### 300行超ファイル ({{数}}ファイル)

| ファイル | 行数 |
|---------|------|
{{各ファイルをテーブル行として出力（行数降順）}}

## 推奨アクション

{{Critical/Warningの指標に対する具体的な改善提案を記載}}

## トレンド

{{前回レポートが存在する場合、各指標の増減を比較して記載}}
{{前回レポートが存在しない場合、「初回スキャンのためトレンドデータなし」と記載}}
```

- `--report-only` の場合はここで終了、結果をユーザに報告する
- step5 を実行する

## step5: Phase 2 - トレンド比較

前回レポートが存在する場合:
1. 前回レポートファイルを Read ツールで読み込む
2. 各指標の件数を抽出する
3. 増減を計算し、レポートのトレンドセクションとサマリーの前回比列を更新する

前回レポートが存在しない場合:
- トレンドセクションに「初回スキャンのためトレンドデータなし」と記載

- step6 を実行する

## step6: Phase 2 - Issue自動作成

`--skip-issue` が指定されている場合はスキップして step8 へ。

Critical判定の指標がある場合:
1. `gh issue create` で Issue を作成する
2. Issue のタイトル: `health: コードベースヘルスチェック警告 ({{日付}})`
3. Issue のラベル: `health`, `automated`
4. Issue の本文に Critical/Warning の指標と具体的な改善箇所を記載

```bash
gh issue create \
  --title "health: コードベースヘルスチェック警告 ({{日付}})" \
  --label "health,automated" \
  --body "$(cat <<'EOF'
## コードベースヘルスチェック結果

**ヘルススコア**: {{スコア}}/100

### Critical/Warning指標

{{Critical/Warningの指標一覧}}

### 対応が必要な箇所

{{具体的なファイル・行の情報}}

### レポート

詳細は `docs/reports/health-scan-{{日付}}.md` を参照。

---
このIssueはコードベースヘルススキャナーにより自動作成されました。
EOF
)"
```

> `health` / `automated` ラベルがリポジトリに存在しない場合は `gh issue create` が失敗する。その場合はラベルなしで再作成し、ユーザーにラベル作成を提案する。なお、この環境では `gh` が使えないことがあるため、その場合は GitHub MCP（`mcp__github__issue_write`）で代替する。

Warning のみでCriticalがない場合:
- Issue は作成せず、レポートのみ生成する
- ユーザに警告レベルの問題を報告する

すべて正常の場合:
- Issue は作成しない
- ユーザに健全であることを報告する

- step8 を実行する

## step7: トレンド表示のみ

`--trend` オプション指定時の処理:

1. `docs/reports/` 配下の全 `health-scan-*.md` ファイルを時系列で取得する
2. 各レポートからヘルススコアと指標件数を抽出する
3. 時系列でのトレンドを表形式で表示する

```
日付       | スコア | 型なし | 循環・層違反 | 未使用API | 300行超 | マジックNo | デッドコード
2026-03-01 | 85     | 3      | 0            | 8         | 4       | 7          | 1
2026-03-08 | 78     | 5      | 1            | 12        | 5       | 9          | 2
2026-03-15 | 82     | 4      | 0            | 10        | 5       | 8          | 1
```

- 処理完了後、ユーザに結果を報告する

## step8: 結果報告

ユーザに以下を報告する:
- ヘルススコアとその評価
- Critical/Warning の指標がある場合はその概要
- レポートファイルのパス
- Issue を作成した場合はその URL
- 改善の優先度が高い項目のトップ3

# CI統合指針

> 🔴 本スキャンはローカル（Claude Code）での手動/定期実行を想定している。現状のCI（`.github/workflows/ci.yml`）にはGdUnit4・gdlint・gdformatのみが組み込まれており、本コマンドはCIでは実行しない。CIに組み込む場合は、検出パターンを `gdlint` のカスタムルールやシェルスクリプトとして切り出す必要がある。

## /loop コマンドとの連携

定期的にヘルススキャンを実行する場合は `/loop` スキルまたはスケジュールタスクから `/codebase-health-scanner` を呼び出す。

## PRごとのヘルスチェック

PR作成前（またはレビュー前）に手動で実行する場合:
1. 作業ブランチでヘルススキャンを実行（`/codebase-health-scanner --skip-issue`）
2. 前回（mainブランチ）のスキャン結果と比較
3. スコアが悪化した場合はPR説明に理由を記載する

## 推奨実行頻度

| 実行タイミング | オプション | 目的 |
|---------------|-----------|------|
| 週次（月曜日） | （オプションなし） | 定期的な健全性チェック + Issue作成 |
| PR作成時 | `--skip-issue` | PR差分による悪化検出 |
| スプリント振り返り | `--trend` | トレンド確認と改善計画 |
| リリース前 | （オプションなし） | リリース品質ゲート |
