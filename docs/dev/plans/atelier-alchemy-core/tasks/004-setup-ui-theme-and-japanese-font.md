---
id: "004"
title: "UiThemeと日本語（CJK）フォント対応をセットアップする"
status: pending
priority: 2
dependencies: ["001"]
estimated_complexity: medium
---

# Task: UiThemeと日本語（CJK）フォント対応をセットアップする

## Goal

Noto Sans JP（SIL OFL 1.1）フォントを `res://assets/fonts/` に配置し、`UiTheme`（`shared/theme/theme.gd`）にフォント定数を定義した上で、プロジェクト共通`Theme`リソースの `default_font` に適用する。Godot 4.xの既定フォントはCJK非対応のため、これを怠ると日本語テキストが一切描画されない（NFR-201）。

## Interfaces

```gdscript
# shared/theme/theme.gd
class_name UiTheme

const FONT_MAIN: FontFile = preload("res://assets/fonts/noto_sans_jp_regular.ttf")  # 🔵 ユーザー確認済み: Noto Sans JP採用
const FONT_SIZE_DEFAULT := 16  # 🟡 Phase1での目視確認用の仮値。本格的な値は後続Planのui-design反映時に確定
```

適用配線:
1. `res://shared/theme/main_theme.tres`（`Theme`リソース）を新規作成し、`default_font` に `UiTheme.FONT_MAIN` 相当のフォントを設定する 🔵
2. Godotエディタ `Project > Project Settings > GUI > Theme > Custom` に `res://shared/theme/main_theme.tres` を設定し、プロジェクト全体のデフォルトテーマとする 🔵
3. `boot.gd`（007タスク）側でも `theme = preload("res://shared/theme/main_theme.tres")` を明示的に再設定する 🟡（Project Settings適用と重複するが、AC-008をGUTテストで検証可能な具体的ステップにするため）

## Test Strategy

フォント描画はGUTの自動テスト（`--headless`では描画結果を検証できない）ではなく、Godotエディタでの目視確認で検証する（`.claude/rules/godot-debug-tools.md`参照）。

- [ ] `res://assets/fonts/noto_sans_jp_regular.ttf` が配置され、Godotエディタ上でインポートエラーが出ない
- [ ] `res://shared/theme/main_theme.tres` の `default_font` に `UiTheme.FONT_MAIN` が設定されている
- [ ] `Project Settings > GUI > Theme > Custom` に `main_theme.tres` が設定されている
- [ ] （007完了後）`boot.tscn` をGodotエディタでF6実行し、日本語仮ラベル「アトリエ 起動確認」が矩形/豆腐文字にならず正しく表示される（NFR-201, AC-015。画数の多い漢字「起動確認」を含めることで字形欠けの有無も確認する）
- [ ] Noto Sans JPのライセンスファイル（OFL.txt等）を `res://assets/fonts/` またはリポジトリのライセンス表記箇所に同梱する

## Implementation Notes

- 参照すべき既存文書: `.claude/rules/godot-best-practices.md`「日本語テキスト描画の注意」節（`res://assets/fonts/noto_sans_jp.ttf`という具体パス例あり。本タスクではファイル名を`noto_sans_jp_regular.ttf`とする）
- Noto Sans JPはGoogle Fonts / Google Noto Projectから入手する（SIL Open Font License 1.1、商用・改変利用可）
- `GameBalance`（ゲームバランス定数）と`UiTheme`（見た目定数）は分離管理する方針（`.claude/rules/coding-style.md`「定数管理」）。本タスクでは`UiTheme`のみを扱い、`GameBalance`はこのPlanの対象外
- フォントサイズ16px相当以上のテキスト、画数の多い漢字（受・愛・変等）を含むテキストで字形欠けが疑われる場合はフォントの言語カバレッジ設定を確認する

## Files

- 新規: `atelier/assets/fonts/noto_sans_jp_regular.ttf`, `atelier/assets/fonts/OFL.txt`（ライセンス表記）, `atelier/shared/theme/theme.gd`, `atelier/shared/theme/main_theme.tres`
- 変更: `atelier/project.godot`（GUI Themeカスタム設定）
- テスト: なし（目視確認のみ、GUT自動テスト対象外）
