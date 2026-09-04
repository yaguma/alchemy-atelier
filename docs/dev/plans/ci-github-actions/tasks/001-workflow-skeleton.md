---
id: "001"
title: "CIワークフローの土台（トリガー・ジョブ定義・checkout）を作成する"
status: done
priority: 1
dependencies: []
estimated_complexity: low
---

# Task: CIワークフローの土台（トリガー・ジョブ定義・checkout）を作成する

## Goal

`.github/workflows/ci.yml` を新規作成し、トリガー条件・単一ジョブの骨格・`actions/checkout`ステップのみを定義する。後続タスク（002〜004）がこの骨格にステップを追記していく前提の土台とする。

## Interfaces

```yaml
# .github/workflows/ci.yml（骨格）
name: CI                                    # 🔵 implement-workflow.md/pipeline-rules.mdの品質ゲート運用に対応する名称
on:
  push:
    branches: [main]                        # 🔵 ユーザー確認済み（main/develop等へのpush）。developブランチは現時点で存在しないため対象からは一旦除外（🟡 存在しないブランチをbranches:に含めても実害はないが、実在確認できないため最小構成でmainのみ指定）
  pull_request:                             # 🔵 ユーザー確認済み（全ブランチからのPR作成・更新時、branchesフィルタなし=全ターゲットブランチ対象）
jobs:
  ci:
    runs-on: ubuntu-latest                  # 🔵 ユーザー確認済み（単一ジョブ構成）
    steps:
      - name: Checkout
        uses: actions/checkout@v4           # 🔵 GitHub公式Action、業界標準バージョン
```

## Test Strategy

- [ ] YAML構文として妥当である（`python -c "import yaml,sys; yaml.safe_load(open('.github/workflows/ci.yml'))"`がエラーなく終了する）
- [ ] `on.push.branches`に`main`のみが含まれ、`on.pull_request`にbranchesフィルタが存在しない（全ブランチ対象であることの確認）
- [ ] `jobs.ci.runs-on`が`ubuntu-latest`である
- [ ] `actions/checkout@v4`ステップが1つだけ存在する
- エッジケース: この時点ではlint/test系ステップが空でも、GitHub Actions上でジョブ自体は成功する（後続タスクで実処理を追加する前提の中間状態であることを確認）

## Implementation Notes

- 参照すべき既存ファイル: なし（`.github/`ディレクトリ自体が本タスクで新規作成対象）
- 実装のヒント: このタスクは設定ファイルの新規作成のみのため`.claude/rules/implement-workflow.md`の「Directモード」に該当する（TDDサイクルは適用しない）
- 注意事項: `.claude/rules/git-workflow.md`のコミットメッセージ規則（`feat:`等）に従いコミットする。このタスク単体でのコミットは「CIワークフローの土台のみ」であり、実チェック処理は含まれない旨をコミットメッセージまたはPR説明に明記するとレビューしやすい

## Files

- 新規: `.github/workflows/ci.yml`
- 変更: なし
- テスト: なし（GdUnit4テスト対象外。検証はYAML構文チェックと後続タスクでの実行結果で行う）
