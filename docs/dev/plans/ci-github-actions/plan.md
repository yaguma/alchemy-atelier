# Plan: ci-github-actions

## Requirements Summary

GitHub Actionsで本プロジェクト（Godot 4.x + GDScript）のCIパイプラインを新規構築する。`.github/workflows/`が存在しない状態からの初回構築（`docs/dev/context.md`のDocker Environment節「CI (GitHub Actions) | 未構築」に対応）。

- **トリガー**: `main`へのpush、および全ブランチからのPull Request（作成・更新時）
- **チェック項目**: `implement-workflow.md`のコミット前必須チェックリストと同一の3点
  1. GdUnit4全テスト（`cd atelier && ./addons/gdUnit4/runtest.sh -a res://tests/ -c`、`-c`で全件実行し失敗を洗い出す）
  2. `gdlint atelier/features/ atelier/shared/ atelier/autoload/`（`atelier/.gdlintrc`設定を使用）
  3. `gdformat --check atelier/features/ atelier/shared/ atelier/autoload/`
- **実行環境**: 単一ジョブ（ubuntu-latest）。Godot公式バイナリをCI上でダウンロードして`GODOT_BIN`を設定する（Dockerイメージは使わない）
- **Godotバージョン**: 4.7.1-stable固定（🔵 `README.md`に記載の動作確認済みバージョン、`gh api repos/godotengine/godot-builds/releases/tags/4.7.1-stable`で実在確認済み。Linux向けアセットは`Godot_v4.7.1-stable_linux.x86_64.zip`の1種類のみで、headless専用ビルドは別途存在しない＝dlopenベースでheadless実行可能という前提）
- **gdtoolkitバージョン**: `4.5.0`固定（🔵 `pip show gdtoolkit`でローカル開発環境の実測値と一致させた。バージョン差異によるlint/format結果の食い違いを防ぐ）

## Design Overview

`.github/workflows/ci.yml` を単一ファイルとして新規作成する。単一ジョブ内でステップを以下の順に実行する（安価なチェックを先に配置し、失敗時のフィードバックを早める設計 🟡）:

1. `actions/checkout@v4`
2. `actions/setup-python@v5` + `pip install gdtoolkit==4.5.0`
3. `gdlint atelier/features/ atelier/shared/ atelier/autoload/`
4. `gdformat --check atelier/features/ atelier/shared/ atelier/autoload/`
5. Godotバイナリのセットアップ（`actions/cache@v4`でバージョン別にキャッシュし、キャッシュミス時のみ`Godot_v4.7.1-stable_linux.x86_64.zip`をダウンロード・展開・`chmod +x`）、`GODOT_BIN`を`$GITHUB_ENV`に設定
6. `godot --headless --path atelier --import`（クリーン環境の初回インポート、`.claude/rules/bash-commands.md`準拠）
7. GdUnit4全テスト実行（`cd atelier && ./addons/gdUnit4/runtest.sh -a res://tests/ -c`）。**終了コード101（警告ありだが成功）を失敗扱いしないハンドリングが必須**（`.claude/rules/testing.md`「GdUnit4は失敗時に非ゼロ終了コード（101警告あり成功、それ以外は失敗）を返す」に準拠、🔵）

### 終了コードハンドリング（Interfaces相当・シェルスクリプトの契約）

```bash
# cd atelier && ./addons/gdUnit4/runtest.sh -a res://tests/ -c 実行後
set +e
./addons/gdUnit4/runtest.sh -a res://tests/ -c
exit_code=$?
set -e
if [ "$exit_code" -ne 0 ] && [ "$exit_code" -ne 101 ]; then
  exit "$exit_code"
fi
```

この分岐を持たないと、GdUnit4が警告付き成功（101）を返すたびにCIが誤って失敗表示になる。既存の`.claude/rules/bash-commands.md`にも同様の注意書きがあるため、CIワークフローでも同じ規約を踏襲する。

## Task Dependency Graph

```
001 (ワークフロー土台: トリガー+ジョブ定義+checkout)
 ├─→ 002 (Godotセットアップ+キャッシュ+インポート)
 │     └─→ 004 (GdUnit4テスト実行ステップ)
 └─→ 003 (gdlint/gdformat --checkステップ)
       ↓
004, 003 ─→ 005 (実PRでの動作検証・調整)
```

- 002と003は001完了後に並行して着手可能（同一ファイルへの追記だが依存関係はない）
- 004は002（Godotインポート完了）に依存
- 005は002・003・004すべてのステップがワークフローに揃った後の最終検証

## Cross-Plan Dependencies

なし（既存の`atelier/`実装・`atelier/.gdlintrc`・`atelier/addons/gdUnit4/`をそのまま利用するのみで、他Featureのコード変更は発生しない）
