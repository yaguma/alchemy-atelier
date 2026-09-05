# Alchemy Atelier

錬金術をテーマにしたギルドランク制デッキ構築RPGの個人開発プロジェクト。ゲームコンセプト・技術スタック・ドキュメントマップの詳細は[`CLAUDE.md`](./CLAUDE.md)を参照。

## 開発環境セットアップ

### 前提

- Godot 4.x（Godot 4.7系で動作確認済み）
- GdUnit4（`atelier/addons/gdUnit4/`に導入済み）

### 環境変数: `GODOT_BIN`

`GODOT_BIN`はGdUnit4のテスト実行スクリプト（`runtest.sh`/`runtest.cmd`）がGodot実行ファイルの場所を特定するために参照する環境変数。**システム環境変数として一度だけ永続設定**しておくことで、`.claude/rules/`配下のコマンド例をそのままコピー&ペーストして実行できる（コマンドごとに`GODOT_BIN="/c/Godot/godot.exe"`のようにインライン指定する必要はない）。

| 変数名 | 値 | 用途 |
|---|---|---|
| `GODOT_BIN` | Godot実行ファイルの絶対パス（例: `C:\Godot\godot.exe`） | GdUnit4 CLI（`runtest.sh`/`runtest.cmd`）がGodotバイナリを特定するために参照する |

#### 設定手順（Windows・GUIから設定する場合）

1. 「環境変数を編集」（`Win`キー → 「環境変数」で検索）を開く
2. 「ユーザー環境変数」に新規変数`GODOT_BIN`を追加する
3. 値にGodot実行ファイルの絶対パスを指定する（例: `C:\Godot\godot.exe`）
4. 新しいターミナルを開き直し、Git Bashで`echo $GODOT_BIN`が値を返すことを確認する

#### 設定手順（シェルプロファイルに追記する場合）

```bash
# ~/.bashrc 等に追記（MSYS/Git Bash形式のパスを使う）
export GODOT_BIN="/c/Godot/godot.exe"
```

Windows環境変数として設定した場合、値は`C:\Godot\godot.exe`のようなバックスラッシュ形式で保持されるが、Git Bash上では`"$GODOT_BIN"`のようにダブルクォートで囲えばそのまま利用できるため、変換は不要。

#### 動作確認

```bash
"$GODOT_BIN" --version
```

Godotのバージョン文字列（例: `4.7.1.stable.official.a13da4feb`）が出力されればOK。

### エクスポートテンプレート（初回のみ）

Godotエディタのメニューから「エディタ > エクスポートテンプレートの管理」を開き、
使用中のGodotバージョン（4.7系）に対応するテンプレートをダウンロード・インストールする。
数百MB〜1GB程度のダウンロードを伴うため、CI等では別途キャッシュ戦略が必要（本READMEの対象外）。

## エクスポートビルド（Windows Desktop / Debug）

```bash
godot --headless --path atelier --export-debug "Windows Desktop" build/windows/atelier-alchemy.exe
```

出力先は `atelier/build/windows/atelier-alchemy.exe`（Git管理対象外）。エクスポートテンプレート未導入の場合は上記コマンドがエラーで終了するため、先に「エクスポートテンプレート（初回のみ）」を実施すること。

## テスト実行

```bash
cd atelier
./addons/gdUnit4/runtest.sh -a res://tests/
```

コマンドの詳細な使い分けは[`.claude/rules/bash-commands.md`](./.claude/rules/bash-commands.md)・[`.claude/rules/testing.md`](./.claude/rules/testing.md)を参照。

## 関連ドキュメント

- プロジェクト概要・現況: [`CLAUDE.md`](./CLAUDE.md)
- Bashコマンド運用ルール: [`.claude/rules/bash-commands.md`](./.claude/rules/bash-commands.md)
- テスト運用ルール: [`.claude/rules/testing.md`](./.claude/rules/testing.md)
- Godotデバッグ・調査ツール運用ルール: [`.claude/rules/godot-debug-tools.md`](./.claude/rules/godot-debug-tools.md)
