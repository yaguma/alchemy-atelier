---
id: "005"
title: "実際のPRでCIワークフローの動作を検証し、必要な調整を行う"
status: pending
priority: 5
dependencies: ["002", "003", "004"]
estimated_complexity: high
---

# Task: 実際のPRでCIワークフローの動作を検証し、必要な調整を行う

## Goal

001〜004で組み上げた`.github/workflows/ci.yml`を実際にリモートへpushし、GitHub Actions上でジョブが意図通りに成功/失敗判定されることを確認する。002・003で残した🔴🟡の未検証事項（共有ライブラリ不足、`.gdlintrc`自動検出、改行コード問題）を実行結果から解消する。

## Interfaces

このタスクはコード変更ではなく検証作業が中心。検証項目ごとに`.github/workflows/ci.yml`への差分修正が発生し得る（002・003で洗い出した🔴🟡事項への対処が主）。

```yaml
# 想定される追加修正の例（🔴実行結果次第で要否確定）
      - name: Install runtime libraries for headless Godot
        if: false  # 002のGodot起動が共有ライブラリ不足で失敗した場合にtrue化
        run: sudo apt-get update && sudo apt-get install -y libgl1 libglu1-mesa libxcursor1 libxinerama1 libxrandr1 libxi6
```

## Test Strategy

- [ ] `feat/ci-github-actions`ブランチ（または相当のブランチ）からmainへのPRを作成し、Actionsタブでジョブが起動することを確認する
- [ ] ジョブの全ステップ（checkout→lint→format→Godotセットアップ→import→test）が実行され、既存コード基準でジョブ全体が成功（緑）になる
- [ ] 002の🔴（共有ライブラリ不足）が実際に発生するか確認し、発生した場合は対処ステップを追加した上で再度成功することを確認する
- [ ] 003のエッジケース（`.gdlintrc`自動検出）が実際にプロジェクト固有ルール（`max-public-methods: 28`等）を反映した結果になっているか、ジョブログから確認する
- [ ] 004の🟡（`runtest.sh`の実行権限・改行コード）が問題にならないことを確認する
- [ ] 2回目以降のPR更新（再push）で、Godotバイナリの`actions/cache`がヒットし、ダウンロードステップがスキップされることをジョブログの実行時間短縮で確認する
- [ ] mainブランチへのpush（PRマージ後）でも同一ワークフローが起動することを確認する
- エッジケース: フォークからのPR、または`GITHUB_TOKEN`権限が制限されるケースは本プロジェクトの運用（個人開発・単一リポジトリ）では想定外のためスコープ外とする

## Implementation Notes

- 参照すべき既存コード: `.github/workflows/ci.yml`（001〜004で作成済み）
- 実装のヒント: `gh run list` / `gh run view --log`（`gh` CLI）でActionsの実行ログをターミナルから確認できる
- 注意事項: このタスクで発覚した恒久的な修正（apt依存追加等）は`.github/workflows/ci.yml`への差分としてコミットする。一時的な検証用の意図的な失敗コミット（Test Strategy中の「意図的に崩す」系）は検証後に必ず取り消し、mainへは反映しない

## Files

- 新規: なし
- 変更: `.github/workflows/ci.yml`（検証結果に応じた調整。变更が不要であれば無変更のまま完了とする）
- テスト: なし（GitHub Actions実行そのものが検証手段）
