# 実装ワークフロールール

## 概要

タスク実装の標準ワークフローとモード判定基準を定義する。
アーキテクチャ詳細は `architecture.md`、テスト詳細は `testing.md`、コーディングスタイルは `coding-style.md` を参照。

---

## ワークフロー全体

```
/start-task
  → /dev-cycle
      [context-gather → test-design → implement → simplify(標準コマンド) → verify]
  → /commit-push-pr
  → /pr-review-team
```

### 各フェーズの概要

| フェーズ | 内容 | 使用スキル/エージェント |
|---------|------|----------------------|
| start-task | mainからブランチ作成 | /start-task |
| context-gather | 関連コード・定数・テストパターン収集 | /context-gather, context-researcher |
| test-design | テストケース設計 | /test-design |
| implement | TDDまたはDirect実装 | tdd-implementer |
| simplify | 不要な複雑性の除去 | /simplify（Claude Code標準コマンド） |
| verify | 品質チェック | quality-checker |
| commit-push-pr | コミット・プッシュ・PR作成 | /commit-push-pr |
| pr-review-team | チームレビュー | /pr-review-team |

---

## モード判定基準

タスクの対象に応じて実装モード（TDD / Direct）を判定する。

### TDDモード

テスト駆動開発（Red→Green→Refactor）で実装する対象:

| 対象 | 理由 |
|------|------|
| `logic/` 配下の純粋関数 | Functional Coreの品質保証 |
| ビジネスロジック・計算処理 | 正確性の担保 |
| バリデーション関数 | 境界値テストが重要 |
| データ変換関数 | 入出力の明確な定義 |
| `ui/` 配下のUI（`Control`継承） | シグナル連携テスト中心 |

### Directモード

テストを先行せず直接実装する対象:

| 対象 | 理由 |
|------|------|
| 設定ファイル変更 | 宣言的な変更のため |
| ディレクトリ作成・環境構築 | インフラ作業のため |
| 依存パッケージ追加 | 設定作業のため |
| 型定義のみの変更 | 実行時の振る舞いがないため |
| ドキュメント更新 | コードではないため |

---

## 実装チェックリスト

実装完了時に以下を確認する。

### アーキテクチャ

- [ ] Feature-Based Architectureのディレクトリ規約（`logic/` / `state/` / `resources/` / `ui/`）に従っている
- [ ] `class_name`が適切に付与され、命名衝突がない
- [ ] Functional Core（`logic/`）に副作用がない
- [ ] 他Featureへの参照は`logic/*.gd`・`resources/*.gd`のみ（`state/`・`ui/`への直接参照禁止）

### コード品質

- [ ] マジックナンバーが`GameBalance`または`UiTheme`に定数化されている
- [ ] `Variant` 型を型ガードなしで使用していない
- [ ] 命名規則に従っている（`coding-style.md` 参照）

### テスト

- [ ] テストファイルが `tests/unit/` または `tests/integration/` に配置されている（`features/`配下ではない）
- [ ] テストファイルが`test_*.gd`命名規則・`extends GutTest`に従っている
- [ ] 正常系・異常系・境界値のテストがある

### リソース管理

- [ ] Autoloadへのsignal購読には`_exit_tree()`での`disconnect()`処理がある
- [ ] `Tween`・`Timer`が適切に停止される
- [ ] シーン跨ぎのノード参照が残っていない（`queue_free()`後の参照保持がない）

---

## コミット前の必須確認

以下の3つが全てPassしていることを確認してからコミットする。

```bash
# 1. 全テスト
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/

# 2. 静的解析
gdlint features/ shared/ autoload/

# 3. フォーマットチェック
gdformat --check features/ shared/ autoload/
```

いずれかが失敗している場合はコミットしない。
pre-commitフックが設定されていれば同様に自動チェックされるが、事前に確認することを推奨する。

---

## エラー対応フロー

### テスト失敗時

1. 失敗テストのエラーメッセージを確認
2. 期待値と実際の値の差異を分析
3. 実装コードを修正（テストコードの修正は慎重に）
4. 再実行して確認

### 型エラー時

1. エラー箇所と型定義を確認
2. 型の不整合を修正
3. 関連する型のインポートを確認
4. 再実行して確認

### リント違反時

1. `gdformat features/ shared/ autoload/` で自動フォーマットを試行
2. `gdlint`が指摘する手動修正が必要な項目を対応
3. 再実行して確認
