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

### Godot MCP（godot-ai）: AIによる画面スクショ・ログ取得（任意）

Claude Codeからゲームを起動し、スクリーンショットとゲームログを取得するためのMCPサーバー[godot-ai](https://github.com/hi-godot/godot-ai)（MIT）を導入している（Issue #80）。GdUnit4は`--headless`で実行されるため描画されず、見た目の確認はこちらで行う。

| 構成要素 | 場所 |
|---|---|
| Godotアドオン（v4.3.1） | `atelier/addons/godot_ai/`（`project.godot`でエディタプラグインとして有効化済み） |
| ゲーム側ヘルパー | `_mcp_game_helper` Autoload（プラグインが自動登録する。エクスポート時はプラグインが除去する） |
| MCPサーバー登録 | リポジトリ直下の`.mcp.json`（`uvx`で`godot-ai==4.3.1`をバージョン固定で起動する） |

#### 前提

- [uv](https://docs.astral.sh/uv/getting-started/installation/)（`uvx`コマンド）がPATHにあること。Windowsでは`irm https://astral.sh/uv/install.ps1 | iex`で導入できる
- 匿名テレメトリを送らないよう、ユーザー環境変数`GODOT_AI_DISABLE_TELEMETRY=true`を設定しておく（`.mcp.json`側でも`--disable-telemetry`を指定済みだが、エディタが起動するサーバープロセスにも効かせるため）

#### 使い方

1. Godotエディタで`atelier/`を開く（`godot --path atelier`）。プラグインがMCPサーバーを`127.0.0.1:8000`（HTTP）/`127.0.0.1:9500`（WebSocket）で起動する
2. リポジトリ直下でClaude Codeを起動し、初回のみ`.mcp.json`の`godot-ai`サーバーを承認する
3. Claude Codeから`project_run`（起動）→`editor_screenshot`（`source: "game"`）→`logs_read`（`source: "game"`）→`project_manage`（`op: "stop"`）の順で使える

- `editor_screenshot`は`max_resolution`を`960`以下にする。`0`（1280×720のフル解像度）はMCPの1MB上限を超えて失敗する
- エディタのGodot AIドックの**Configure**ボタンは押さない。`.mcp.json`を書き換え、他スコープの`godot-ai`設定も削除する
- ドックの**Update**ボタンは使わない。アドオンを更新するときは、リリースを手動で取得してハッシュを確認し、`.mcp.json`のバージョン固定と合わせてPRで更新する
- ヘッドレス起動（CIのGdUnit4・エクスポート）では、プラグインは`MCP | plugin disabled in headless mode`と出力して何もしない

## エクスポートビルド（Windows Desktop / Debug）

```bash
godot --headless --path atelier --export-debug "Windows Desktop" build/windows/atelier-alchemy.exe
```

出力先は `atelier/build/windows/atelier-alchemy.exe`（Git管理対象外）。godot-aiアドオン（`addons/godot_ai/*`）は`export_presets.cfg`の`exclude_filter`でビルドから除外している。エクスポートテンプレート未導入の場合は上記コマンドがエラーで終了するため、先に「エクスポートテンプレート（初回のみ）」を実施すること。

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
