# Bashコマンドルール

> 🔴 2026-08-06改訂: 技術スタックがGodot 4.x + GDScriptに確定済み（`CLAUDE.md`参照）のため、pnpm/Vitest/TypeScript前提だったコマンド例をGodot/GUT前提に更新した（`cd`運用・並列実行・Windows/MSYS注意等の一般原則は変更なし）。
> 🔴 2026-08-10改訂: テストフレームワークをGUTからGdUnit4に切り替えたため（Asset Store移行期にGUTがAsset Libraryで検索不能だったことが契機）、GUT前提だったコマンド例を全面的にGdUnit4に置き換えた。GdUnit4の`runtest.sh`/`runtest.cmd`はプロジェクトディレクトリ内から実行する前提で`--path`相当のオプションを持たないため、テスト実行コマンドに限り「`cd`してから実行」が必須の例外となる点に注意（下記「Godot / GdUnit4 実行ルール」参照）。

## 基本原則

- 作業ディレクトリはBash呼び出し間で永続化される
- 冗長な`cd`を避け、絶対パスを活用する
- 独立したコマンドは並列実行し、依存するコマンドはチェーンする

---

## `cd` の使用ルール

### 原則: 毎回 `cd` しない

Bashツールの作業ディレクトリは呼び出し間で永続化されるため、毎回 `cd` する必要はない。ただし**GdUnit4のテスト実行コマンドのみ`atelier/`への`cd`が必須**（`--path`相当のオプションがGdUnit4のCLIツールに存在しないため。下記「Godot / GdUnit4 実行ルール」参照）。

```bash
# NG: 毎回cdを繰り返す（GdUnit4以外のコマンドで）
cd atelier && gdlint features/
cd atelier && godot --headless --export-release "Windows Desktop" build/atelier.exe

# OK: --pathを活用（GdUnit4のテスト実行以外）
godot --headless --path atelier --import

# OK: 最初の1回だけcd（以降は不要）
cd atelier
# 次のBash呼び出しではcdなしで実行可能
GODOT_BIN="/c/Godot/godot.exe" ./addons/gdUnit4/runtest.sh -a res://tests/
```

---

## コマンドの分割・結合ルール

### 独立したコマンド → 並列実行

結果が次のコマンドに影響しない場合、**複数のBashツール呼び出しに分割**して並列実行する。

```bash
# NG: 独立したコマンドを1つにチェーン
gh issue create --title "Issue 1" --body "..." && gh issue create --title "Issue 2" --body "..." && gh issue create --title "Issue 3" --body "..."

# OK: 3つの並列Bash呼び出しに分割
# 呼び出し1: gh issue create --title "Issue 1" --body "..."
# 呼び出し2: gh issue create --title "Issue 2" --body "..."
# 呼び出し3: gh issue create --title "Issue 3" --body "..."
```

### 依存関係のあるコマンド → `&&` でチェーン

前のコマンドの成功が次のコマンドの前提条件となる場合、**1つのBash呼び出し内で `&&` チェーン**する。

```bash
# OK: 依存関係がある（addが成功してからcommit）
git add specific-file.ts && git commit -m "feat: 機能を追加"

# OK: ディレクトリ作成後にファイル操作
mkdir -p /path/to/dir && cp source.txt /path/to/dir/
```

### チェーンの長さ制限

1つのBash呼び出しに大量のコマンドをチェーンしない。失敗時の影響範囲が広がるため。

```bash
# NG: 長すぎるチェーン
cmd1 && cmd2 && cmd3 && cmd4 && cmd5 && cmd6 && cmd7 && cmd8 && cmd9 && cmd10

# OK: 論理的なまとまりで分割
# 呼び出し1: cmd1 && cmd2 && cmd3（ビルド関連）
# 呼び出し2: cmd4 && cmd5（テスト関連）
# 呼び出し3: cmd6 && cmd7（デプロイ関連）
```

---

## 禁止パターン

### 並列呼び出し全てに同じ `cd` を付ける

```bash
# NG: 全並列呼び出しで同じcdを繰り返す
# 呼び出し1: cd atelier && gdlint features/
# 呼び出し2: cd atelier && gdformat --check features/

# OK: cdなしで直接実行（作業ディレクトリが既に正しい場合）
# 呼び出し1: gdlint features/
# 呼び出し2: gdformat --check features/
```

### 独立コマンドの過剰チェーン

```bash
# NG: 独立した10個以上のgh issue createを&&でチェーン
gh issue create ... && gh issue create ... && gh issue create ... && ...

# OK: 各issueを個別の並列Bash呼び出しで実行
```

---

## 推奨パターン

| シナリオ | 方法 |
|---------|------|
| 複数の独立したテスト実行 | 並列Bash呼び出し |
| git add → commit → push | `&&` チェーン（1つの呼び出し） |
| 複数のIssue作成 | 並列Bash呼び出し |
| ビルド → テスト | `&&` チェーン（依存関係あり） |
| 複数ファイルの情報取得 | 並列Bash呼び出し |

---

## Godot / GdUnit4 実行ルール

本プロジェクトは`atelier/`配下に単一のGodotプロジェクトを持つ構成（モノレポではない）。テスト実行以外のコマンドはリポジトリルートまたは`atelier/`のいずれからでも、`--path`指定で絶対パスを渡すのが安全。

### 原則: テスト実行以外は`--path`で対象プロジェクトを明示する

```bash
# OK: --pathでプロジェクトディレクトリを明示（cd不要）
godot --headless --path atelier --import

# OK: 最初の1回だけcd（以降は不要）
cd atelier
gdlint features/
```

### 例外: GdUnit4のテスト実行は`cd`必須

GdUnit4の`runtest.sh`（Windows版`runtest.cmd`）は`--path`相当のオプションを持たず、`res://`パス解決がカレントディレクトリ基準で行われるため、**`atelier/`に`cd`してから実行する必要がある**（実証済み。リポジトリルートから絶対パスでスクリプトを呼ぶと`res://addons/gdUnit4/bin/GdUnitCmdTool.gd`が見つからずエラーになる）。`GODOT_BIN`環境変数でGodot実行ファイルの絶対パスを指定する。

```bash
# NG: リポジトリルートから絶対パス指定で実行（res://解決に失敗する）
GODOT_BIN="/c/Godot/godot.exe" atelier/addons/gdUnit4/runtest.sh -a res://tests/

# OK: cdしてから実行（GdUnit4のみの例外）
cd atelier
GODOT_BIN="/c/Godot/godot.exe" ./addons/gdUnit4/runtest.sh -a res://tests/
```

### 利用可能な主要コマンド

| コマンド | 内容 |
|---------|------|
| `godot --path atelier` | エディタをGUIで起動（対話操作、調査用。[`godot-debug-tools.md`](./godot-debug-tools.md)参照） |
| `cd atelier && GODOT_BIN="/c/Godot/godot.exe" ./addons/gdUnit4/runtest.sh -a res://tests/` | 全GdUnit4テストをヘッドレス実行 |
| `cd atelier && GODOT_BIN="/c/Godot/godot.exe" ./addons/gdUnit4/runtest.sh -a res://tests/unit/features/{feature}/test_{file}.gd` | 特定テストファイルのみ実行 |
| `gdlint atelier/features/ atelier/shared/ atelier/autoload/` | 静的解析（gdtoolkit） |
| `gdformat atelier/features/ atelier/shared/ atelier/autoload/` | 自動フォーマット |
| `godot --headless --path atelier --export-release "<preset>" <output>` | エクスポートビルド（プリセット名は実装着手時に確定） |

`GODOT_BIN`にはリネーム済みのGodot実行ファイル絶対パス（`/c/Godot/godot.exe`）を指定する。

クリーンチェックアウト直後（CI・新規clone）は`.godot/`インポートキャッシュが存在しないため、初回のみ`godot --headless --path atelier --import`でインポートを完了させてからGdUnit4を実行する。インポートと同時にテストを走らせると不安定になることがある。

### サブディレクトリでの直接実行が許される場合

- デバッグ目的で一時的に`atelier/`に`cd`して実行する場合
- GdUnit4のテスト実行（上記の通り必須）

---

## 長時間実行プロセス

### `run_in_background` の活用

devサーバーなど終了しないプロセスは `run_in_background: true` で起動する。

```bash
# OK: バックグラウンドで起動
godot --path atelier  # run_in_background: true を設定（エディタ/実機プレイの起動）

# NG: フォアグラウンドで起動（タイムアウトする）
godot --path atelier
```

### タイムアウト設定

長いテストやビルドにはタイムアウトを明示する。

| コマンド | 推奨タイムアウト |
|---------|---------------|
| `GODOT_BIN=... ./addons/gdUnit4/runtest.sh -a res://tests/` | 120000ms（2分） |
| `godot --headless --export-release ...` | 300000ms（5分、初回エクスポートは特に時間がかかる） |

---

## Windows/MSYS 環境の注意

本プロジェクトは MSYS2 (Git Bash) 上で動作する。Unix シェル構文を使用するが、一部注意が必要。

### パス区切り

```bash
# OK: フォワードスラッシュ
ls /c/Users/syagu/Desktop/work/UnityProjects/atelier.worktrees/wt1

# NG: バックスラッシュ
ls C:\Users\syagu\Desktop\work
```

### リダイレクト

```bash
# OK: Unix形式
command > /dev/null 2>&1

# NG: Windows形式
command > NUL 2>&1
```

### パスにスペースが含まれる場合

```bash
# OK: ダブルクォートで囲む
cd "/c/Users/syagu/My Documents"

# NG: クォートなし
cd /c/Users/syagu/My Documents
```

---

## テスト出力の管理

### 絞り込み実行

テストは対象を絞って実行し、出力を読みやすく保つ。

```bash
# 特定ディレクトリ（cd atelier実施済み前提）
GODOT_BIN="/c/Godot/godot.exe" ./addons/gdUnit4/runtest.sh -a res://tests/unit/features/garden/

# 特定ファイル
GODOT_BIN="/c/Godot/godot.exe" ./addons/gdUnit4/runtest.sh -a res://tests/unit/features/alchemy/test_quality_calculator.gd

# 全テスト実行（CIまたは最終確認）
GODOT_BIN="/c/Godot/godot.exe" ./addons/gdUnit4/runtest.sh -a res://tests/
```

### ヘッドレス実行の徹底

GdUnit4の`runtest.sh`は内部で`--headless`相当のGodot起動オプションを付与するため、GUTのような明示的な`--headless`フラグの付け忘れによるGUIハングは基本的に発生しない。ただし`godot --path atelier`でエディタ自体を起動する場合は、`--headless`を付けないとGUIウィンドウが起動する点は変わらない（対話操作が目的の場合は意図通り）。

### 出力が長い場合

`tail` でBash出力の末尾を取得し、結果サマリーのみ確認する。

```bash
# 末尾30行のみ表示
GODOT_BIN="/c/Godot/godot.exe" ./addons/gdUnit4/runtest.sh -a res://tests/ 2>&1 | tail -30
```

> `| tail -30`を挟むとパイプの終了コードが`tail`のもの（常に0）になり、`$?`によるテスト失敗の機械判定ができなくなる。終了コードを見る場合は`tail`を通さないか、`set -o pipefail`と併用する。GdUnit4は失敗時に非ゼロ終了コード（101警告あり成功、それ以外は失敗）を返す。

---

## 安全性ルール

### 破壊的コマンドの禁止

以下のコマンドは原則禁止する。

| コマンド | 理由 | 代替手段 |
|---------|------|----------|
| `rm -rf` | 意図しないファイル・ディレクトリの完全削除 | `git clean -n`で確認後、個別に削除 |
| `> file` | ファイル内容の消失 | バックアップ後に操作 |

ファイル・ディレクトリの削除が必要な場合は、以下の手順に従う。

```bash
# 1. 削除対象を事前に確認
ls -la target_directory/

# 2. 個別ファイルを削除（ワイルドカードは避ける）
rm specific-file.txt

# 3. 空ディレクトリの削除
rmdir target_directory/

# 4. 中身のあるディレクトリの削除が必要な場合
#    中身を確認 → 個別にファイルを削除 → rmdirで空ディレクトリを削除
ls target_directory/
rm target_directory/file1.txt
rm target_directory/file2.txt
rmdir target_directory/
```

### コミット前チェックリスト

コードを変更した場合、コミット前に以下を必ず実行する。

```bash
# 1. テスト実行（cd atelier後に実行）
cd atelier
GODOT_BIN="/c/Godot/godot.exe" ./addons/gdUnit4/runtest.sh -a res://tests/

# 2. 静的解析（gdlint、リポジトリルートまたはatelier配下いずれからでも可）
gdlint atelier/features/ atelier/shared/ atelier/autoload/

# 3. フォーマットチェック
gdformat --check atelier/features/ atelier/shared/ atelier/autoload/
```

全てパスしてからコミットすること。pre-commitフックが設定されていれば同様に検証されるが、事前に確認することで修正の手戻りを減らせる。

### `cd` の安全な使用

`cd`は作業ディレクトリを変更するため、後続コマンドに影響を与える。

```bash
# NG: cdで移動後、意図しないディレクトリで操作する危険性
cd /some/directory
rm *.tmp  # 現在のディレクトリが想定と異なる場合に危険

# OK: 絶対パスを使用してcdを避ける
rm /some/directory/*.tmp

# OK: サブシェルでcdの影響を局所化する
(cd /some/directory && ls)
# 元のディレクトリに戻っている
```

---

## エラー発生時の対応

### リトライ前に原因を確認

コマンドが失敗した場合、同じコマンドを繰り返さず原因を調査する。

```bash
# NG: 同じコマンドを何度もリトライ
godot --headless --export-release ...  # 失敗
godot --headless --export-release ...  # また失敗

# OK: エラーメッセージを確認し対処
godot --headless --export-release ... 2>&1 | tail -50  # エラー詳細を確認
# → 原因に応じた修正を行う
```

### pre-commit フック失敗時の手順

pre-commit フックが失敗した場合、コミットは作成されていない。

```bash
# 1. エラー内容を確認（lint エラー、型エラー等）
# 2. コードを修正
# 3. 修正をステージング
git add <修正ファイル>
# 4. 新しいコミットを作成（--amend は使わない）
git commit -m "fix: エラーを修正"
```

### よくあるエラーと対処

| エラー | 原因 | 対処 |
|--------|------|------|
| `Node not found` | シーンツリー未接続でのノード参照 | `auto_free()`でノードを生成し`add_child()`しているか確認（[`godot-debug-tools.md`](./godot-debug-tools.md)参照） |
| `Identifier not found` | `class_name`未登録、または`preload`パス誤り | スクリプトの`class_name`宣言とファイルパスを確認 |
| `Nonexistent function 'xxx' in base 'previously freed'` | `monitor_signals(obj)`のデフォルト引数`_auto_free=true`によりAutoloadが誤って解放された | Autoload等テスト終了後も生存すべきオブジェクトには`monitor_signals(obj, false)`を明示する |
| `Attempt to open script '...GdUnitCmdTool.gd' resulted in error 'File not found'` | `atelier/`に`cd`せずリポジトリルートから`runtest.sh`を呼んだ（`res://`解決失敗） | 必ず`cd atelier`してから実行する |
| `Invalid get index` | Resourceのプロパティ名誤り、またはnullアクセス | マスターデータ（`.tres`）のスキーマとロード順序を確認 |

---

## リファクタリング後検証

マルチファイルにまたがるリファクタリング（リネーム、インポートパス変更、型名変更等）を行った後は、必ずgrep検証を実施して変更漏れがないことを確認する。

### リネーム後の検証

関数名・変数名・クラス名を変更した場合、旧名が残っていないことを確認する。

Grepツールを使用して検証する（0件であればOK、ヒットした場合は変更漏れ）。

```
# 例: calculate_reward → compute_reward にリネームした場合
Grep: pattern="calculate_reward", glob="*.gd"
```

### インポートパス変更後の検証

ファイル移動やディレクトリ構造変更でインポートパスが変わった場合、旧パスが残っていないことを確認する。

```
# 例: res://shared/utils/calc.gd → res://shared/services/calc.gd に移動した場合
Grep: pattern="shared/utils/calc", glob="*.gd"
```

### 型名変更後の検証

型名・インターフェース名を変更した場合、旧型名が残っていないことを確認する。

```
# 例: MaterialData → MaterialMaster にリネームした場合
Grep: pattern="MaterialData", glob="*.gd"
```

### 検証の実施タイミング

- リファクタリング完了後、コミット前に必ず実施
- CIで検出される前にローカルで変更漏れを防止する
