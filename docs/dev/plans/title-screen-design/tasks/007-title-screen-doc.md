---
id: "007"
title: "タイトル画面の画面設計書を新規作成し overview.md を更新する"
status: done
priority: 4
dependencies: ["006"]
estimated_complexity: low
---

# Task: タイトル画面の画面設計書を新規作成し overview.md を更新する

## Goal

`screen-craft`スキルのstep4手順に従い、`docs/design/atelier-alchemy-core/ui-design/screens/title.md`を新規作成する（既存の`garden.md`と同じ構成：基本情報／ワイヤーフレーム／UI要素／状態遷移／アニメーション／イベント／アクセシビリティ）。`overview.md`のSCR-008行の「詳細ファイル」リンクも「詳細設計ファイルは未作成」から本ファイルへのリンクに更新する。

## Interfaces

コード上のインターフェースはない（ドキュメントのみ）。参照テンプレート:

```
docs/design/atelier-alchemy-core/ui-design/screens/title.md
  ## 基本情報（画面ID SCR-008、対応実装ファイル、遷移元/遷移先）
  ## ワイヤーフレーム（TitleBackdrop→ロゴ→4ボタンの配置をテキストまたは簡易図で）
  ## UI要素（要素ID表: btn-new-game, btn-continue, btn-settings, btn-quit, img-logo-emblem, txt-logo-title, bg-title-backdrop）
  ## 状態遷移（4ボタン押下時の遷移先。既存overview.mdの画面遷移図と矛盾しないこと）
  ## アニメーション（本Planでは静的背景のみのため「🟡TBD」明記でよい。将来のTween演出は別タスク）
  ## イベント（signal一覧、既存title_screen.gdのAPIに合わせる）
  ## アクセシビリティ（色以外の判別手段が必要な要素があるかの確認。本画面はボタンにテキストラベルがあるため通常は問題なし）
```

## Test Strategy

自動テストなし（ドキュメントタスクのため）。代わりに以下を確認する:

- [ ] `screens/garden.md`と同じセクション構成になっている
- [ ] `006`で実装した実際のノード名（`%NewGameButton`等）・variant割り当てと矛盾しない内容になっている
- [ ] `overview.md`の画面一覧テーブル（SCR-008行）の「詳細ファイル」列が`[title.md](screens/title.md)`形式のリンクに更新されている
- [ ] `overview.md`の他の記述（画面遷移図、共通UIコンポーネント節）と矛盾する記述がない

## Implementation Notes

- 参照すべき既存コード/文書: `docs/design/atelier-alchemy-core/ui-design/screens/garden.md`（テンプレートとして踏襲）, `.claude/skills/screen-craft/references/screen-doc-template.md`
- 実装のヒント: `overview.md`の該当行は🔵🟡🔴の信号機コメントが積み重なった編集履歴になっているため、既存の信号機コメントは削除せず、新規の修正コメント（日付付き）を追記する形で更新する（プロジェクトの既存編集スタイルを踏襲）
- 注意事項: `planning.md`の「計画は軽量に」方針により、`overview.md`の他画面の記述まで作り直さない。SCR-008行のみの最小限の更新に留める

## Files

- 新規: `docs/design/atelier-alchemy-core/ui-design/screens/title.md`
- 変更: `docs/design/atelier-alchemy-core/ui-design/overview.md`（SCR-008行のみ）
