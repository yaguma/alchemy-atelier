---
id: "003"
title: "gdlint・gdformat --checkステップを追加する"
status: done
priority: 3
dependencies: ["001"]
estimated_complexity: low
---

# Task: gdlint・gdformat --checkステップを追加する

## Goal

`.github/workflows/ci.yml`（001で作成した骨格）に、Python + gdtoolkitをセットアップし、`gdlint`と`gdformat --check`を実行するステップを追加する。Godotバイナリのセットアップ（002）に依存しないため、002と並行して着手できる。

## Interfaces

```yaml
# 001の`steps:`に以下を追記する（順序はcheckoutの直後が望ましい。002のGodotダウンロードより先に安価なチェックを走らせるため 🟡）
      - name: Set up Python
        uses: actions/setup-python@v5              # 🔵 GitHub公式Action
        with:
          python-version: "3.x"

      - name: Install gdtoolkit
        run: pip install gdtoolkit==4.5.0           # 🔵 `pip show gdtoolkit`によるローカル開発環境の実測値と一致させる

      - name: Run gdlint
        run: gdlint atelier/features/ atelier/shared/ atelier/autoload/
        # 🔵 atelier/.gdlintrc の設定（max-line-length: 100, max-public-methods: 28 等）をgdlintが自動的に参照する

      - name: Run gdformat --check
        run: gdformat --check atelier/features/ atelier/shared/ atelier/autoload/
```

## Test Strategy

- [ ] `pip install gdtoolkit==4.5.0`が成功し、`gdlint --version`が`4.5.0`を含む出力を返す
- [ ] 現状の`atelier/features/`, `atelier/shared/`, `atelier/autoload/`に対して`gdlint`を実行し、既存コードが規約違反ゼロで通過する（既存コードは`.claude/rules/implement-workflow.md`のコミット前チェックリストで既にパス済みの想定のため、CI上でも同じ結果になるはず）
- [ ] 同様に`gdformat --check`が既存コードに対して差分ゼロで通過する
- [ ] 意図的にインデントを崩した一時的な検証（ローカルのみ、コミットしない）で`gdformat --check`が非ゼロ終了コードを返すことを確認する（CIが本当に違反を検出できるかの動作確認）
- [x] エッジケース: `atelier/.gdlintrc`のパス解決はgdlintの実行時カレントディレクトリ基準（`.claude/rules/bash-commands.md`同様の注意点）。**実測で確認済み**: リポジトリルートから`gdlint atelier/features/ atelier/shared/ atelier/autoload/`を実行すると`.gdlintrc`が自動検出されず、デフォルトルール（`max-public-methods: 20`）が適用されて`game_state.gd`が誤検知（false positive）した。`cd atelier`してから相対パス（`gdlint features/ shared/ autoload/`）で実行すると`.gdlintrc`が検出され問題なく通過する。この検証結果を受け、ワークフローでは`--config`オプションではなく`working-directory: atelier`を指定する方式を採用した

## Implementation Notes

- 参照すべき既存コード: `atelier/.gdlintrc`（lint設定）、`.claude/rules/implement-workflow.md`「コミット前チェックリスト」のコマンド例
- 実装のヒント: ローカルでのコマンド`gdlint atelier/features/ atelier/shared/ atelier/autoload/`はリポジトリルートから実行する想定（`.claude/rules/bash-commands.md`「テスト実行以外は`--path`で対象プロジェクトを明示する」の原則と同様、gdlint/gdformatはリポジトリルートからの相対パス指定で動作する）。CIのcheckoutディレクトリもリポジトリルート相当になるため、ローカルと同じコマンドがそのまま使えるはず
- 注意事項: `.gdlintrc`が自動検出されずデフォルトルールで実行されてしまうと、`max-public-methods: 28`等のプロジェクト固有の緩和設定が適用されず誤検知（GameStateのfalse positive等）が発生する。Test Strategyのエッジケース検証を必ず実施すること

## Files

- 新規: なし
- 変更: `.github/workflows/ci.yml`（Python+gdtoolkitセットアップ、gdlint/gdformat --checkステップを追記）
- テスト: なし（GitHub Actions実行結果で検証）
