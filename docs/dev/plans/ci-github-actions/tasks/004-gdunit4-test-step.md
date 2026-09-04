---
id: "004"
title: "GdUnit4全テスト実行ステップを追加する（終了コード101のハンドリング含む）"
status: done
priority: 2
dependencies: ["002"]
estimated_complexity: medium
---

# Task: GdUnit4全テスト実行ステップを追加する（終了コード101のハンドリング含む）

## Goal

`.github/workflows/ci.yml`に、Godotインポート完了後（002）の状態でGdUnit4の全テストを`-c`（fail-fast無効化・全件実行）オプション付きで実行するステップを追加する。GdUnit4の「終了コード101＝警告ありだが成功」を誤ってCI失敗と判定しないようハンドリングする。

## Interfaces

```yaml
# 002のGodotインポートステップの後に追記する
      - name: Run GdUnit4 tests
        working-directory: atelier                  # 🔵 .claude/rules/testing.md「必ずatelier/にcdしてから実行」に対応（GdUnit4のruntest.shは--path相当のオプションを持たないため）
        run: |
          set +e
          ./addons/gdUnit4/runtest.sh -a res://tests/ -c
          exit_code=$?
          set -e
          echo "GdUnit4 exit code: $exit_code"
          if [ "$exit_code" -ne 0 ] && [ "$exit_code" -ne 101 ]; then
            exit "$exit_code"
          fi
        # 🔵 .claude/rules/testing.md「GdUnit4は失敗時に非ゼロ終了コード（101警告あり成功、それ以外は失敗）を返す」に準拠
```

> 🟡 `runtest.sh`はUnix改行のシェルスクリプトを想定しており、GitHub Actions（ubuntu-latest）上では改行コード変換の問題は基本的に発生しないはずだが、Windows環境でのgit checkout設定（`core.autocrlf`）次第では実行権限・改行コードの問題が起きる可能性がある。実PR検証（005）で問題が出た場合は`chmod +x atelier/addons/gdUnit4/runtest.sh`の明示的な追加、または`dos2unix`相当の変換ステップを検討する。
>
> 【実装時の追加修正】上記の懸念は**実測で確認された実害**だった。`git ls-files -s atelier/addons/gdUnit4/runtest.sh`の結果が`100644`（非実行権限）であり、`actions/checkout@v4`でチェックアウトした場合`./addons/gdUnit4/runtest.sh`は`Permission denied`になる。ワークフローではリポジトリ側のファイルモードを変更せず、`bash addons/gdUnit4/runtest.sh ...`のように明示的に`bash`経由で呼び出すことで実行権限に依存しない形にした。
>
> 【追加で判明した🔴】`runtest.sh`の中身を確認したところ、実際のGodot起動コマンド（`"$godot_binary" --path . -s -d --remote-debug ...`）には`--headless`フラグが渡されておらず、`.claude/rules/testing.md`の「GdUnit4は内部で`--headless`相当のオプションを付与する」という記載はこのバージョン（gdUnit4 v6.2.1）の実装と一致しない可能性がある。ディスプレイのないLinux CIランナーで表示初期化に失敗するリスクを避けるため、`xvfb-run --auto-servernum`でラップするステップを追加した（GdUnit4のCI事例で一般的なパターン）。005の実PR検証で本当に必要だったか、あるいは不要な安全策だったかを確認すること。

## Test Strategy

- [ ] 全テストが成功する状態（現状のmainブランチ相当）で本ステップを実行すると、ジョブが成功（緑）になる
- [ ] GdUnit4が終了コード`101`（警告のみ）を返すケースをローカルで再現し、CI相当のシェルスクリプトを手元で実行してジョブが「成功」扱いになることを確認する（`echo $?`で意図的に101を返すダミースクリプトでの検証でも可）
- [ ] 意図的に1件のテストを失敗させた状態（ローカルのみ、コミットしない）で本ステップを実行し、終了コードが0でも101でもない値になりジョブが失敗（赤）になることを確認する
- [ ] `-c`オプションにより、複数のテスト失敗がある場合でも最初の1件で打ち切られず全件の失敗がログに出力される
- エッジケース: `runtest.sh`自体が実行権限を失っている、または改行コード起因で起動できない場合、`exit_code`取得より前の`./addons/gdUnit4/runtest.sh`実行自体が`Permission denied`等でシェルエラーになる。この場合は`set -e`の効力外（サブシェルではない）なので即座にステップ全体が失敗する想定だが、実PR検証（005）で実際の挙動を確認すること

## Implementation Notes

- 参照すべき既存コード: `.claude/rules/testing.md`「テスト実行」節、`.claude/rules/bash-commands.md`「GdUnit4のテスト実行は`cd`必須」節
- 実装のヒント: `working-directory: atelier`はGitHub Actionsのステップ単位で作業ディレクトリを固定できる機能。`cd atelier && ...`をシェルスクリプト内に書くよりも意図が明確
- 注意事項: `$GODOT_BIN`は002のタスクで`$GITHUB_ENV`に設定済みのため、`runtest.sh`内部からは環境変数として自動的に参照される（追加のexportは不要）

## Files

- 新規: なし
- 変更: `.github/workflows/ci.yml`（GdUnit4テスト実行ステップを追記）
- テスト: なし（既存の`atelier/tests/`配下のテストをそのまま実行対象とする。新規テストファイルの追加は本タスクの範囲外）
