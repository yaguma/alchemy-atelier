---
id: "002"
title: "ドット絵風日本語フォント（DotGothic16）をプロジェクトに追加する"
status: done
priority: 1
dependencies: []
estimated_complexity: low
---

# Task: ドット絵風日本語フォント（DotGothic16）をプロジェクトに追加する

## Goal

日本語対応のドット絵風フォント「DotGothic16」をプロジェクトに追加し、`UiTheme.FONT_PIXEL_JP`として他タスクから参照できるようにする。

## Interfaces

```gdscript
# shared/theme/theme.gd（既存クラスへの追加分）
class_name UiTheme

# 🔵 既存のFONT_MAIN（Noto Sans JP、main_theme.tresのdefault_font）と並存させる。
# main_theme.tres自体は変更しない（プロジェクト全体のデフォルトフォントは変えないため、
# ノード単位でadd_theme_font_override()する運用を006/009タスクで行う）
const FONT_PIXEL_JP: FontFile = preload("res://assets/fonts/dotgothic16_regular.ttf")
```

## Test Strategy

自動テストなし（フォントアセット追加タスクのため）。代わりに以下を確認する:

- [ ] `atelier/assets/fonts/dotgothic16_regular.ttf`（または入手したファイル名そのまま）が配置されている
- [ ] ライセンス全文（SIL Open Font License 1.1）を`atelier/assets/fonts/`配下に`OFL.txt`または`DotGothic16-OFL.txt`として同梱する（既存の`atelier/assets/fonts/`のライセンス同梱慣習に倣う。既存フォントのライセンスファイル名をGlobで確認してから合わせる）
- [ ] `UiTheme.FONT_PIXEL_JP`の`preload()`がGodotエディタ/GdUnit4実行時にパースエラーを起こさない（存在しないパスをpreloadするとスクリプト全体がコンパイルエラーになるため、ファイル実在の確認が必須）
- [ ] 日本語グリフ（「アトリエ」「はじめから」「つづきから」「せってい」「終了」に含まれる文字）が欠落なく表示できるフォントであることを確認する（DotGothic16はJIS第1水準漢字までカバーするため通常問題ない）

## Implementation Notes

- 参照すべき既存コード: `atelier/assets/fonts/`配下の既存フォント（Noto Sans JP）の配置形式・ライセンスファイル同梱パターンをGlobで確認してから踏襲する
- 実装のヒント: DotGothic16はGoogle Fonts（`fonts.google.com`）で配布されているSIL OFL 1.1ライセンスのフォント。ダウンロード後、`.ttf`ファイルとライセンス全文を`atelier/assets/fonts/`に配置する
- 注意事項: `main_theme.tres`の`default_font`（プロジェクト全体のデフォルト）は変更しない。あくまで`UiTheme.FONT_PIXEL_JP`として個別ノードから`add_theme_font_override()`で使う設計（他画面への意図しない影響を避けるため）

## Files

- 新規: `atelier/assets/fonts/dotgothic16_regular.ttf`（＋ライセンスファイル）
- 変更: `atelier/shared/theme/theme.gd`（`FONT_PIXEL_JP`定数追加）
