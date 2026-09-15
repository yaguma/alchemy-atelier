---
id: "004"
title: "タイトルロゴ用の装飾画像アセットをatelier-image-genで生成する"
status: done
priority: 3
dependencies: []
estimated_complexity: low
---

# Task: タイトルロゴ用の装飾画像アセットをatelier-image-genで生成する

## Goal

乳鉢と乳棒の紋章＋六芒星の魔法円の装飾画像を`atelier-image-gen`スキルで生成し、`TitleScreen`のロゴ部に使えるPNGとして保存する。日本語文字（「アトリエ」）はAI画像生成では正確に描画できないため、**画像には文字を焼き込まず装飾のみとする**（文字は`006`で`Label`として別途重ねる）。

## Interfaces

このタスクにコード上のインターフェースはない（アセット生成のみ）。生成コマンドの形（🟡 具体的なプロンプト文言はAI裁量、`nanobanana-prompts.md`の「1. タイトル画面」の共通スタイル文＋紋章描写を踏まえる）:

```bash
python3 .claude/skills/atelier-image-gen/scripts/generate_image.py \
  --prompt "<水彩ファンタジー共通スタイル文 + 乳鉢と乳棒の紋章、六芒星の魔法円の飾り模様、透過背景寄りの中央配置装飾エンブレム。文字は一切含めない>" \
  --output atelier/assets/ui/title/title_emblem.png \
  --model imagen-4.0-generate-001 \
  --aspect-ratio 1:1
```

## Test Strategy

自動テストなし（画像アセット生成タスクのため）。代わりに以下を確認する:

- [x] `atelier/assets/ui/title/title_emblem.png`が生成され、Readツールで目視レビューし、水彩ファンタジースタイル（暖色系・パステル、ダーク/青紫系でない）に沿っていることを確認する
- [x] 画像内に文字（特に誤字を含む日本語もどきの模様）が焼き込まれていないことを確認する。焼き込まれていた場合はプロンプトを調整し再生成する
- [x] 既存アイコンが存在しないため`--reference-image`でのトーン統一は不要（新規カテゴリのため）
- [x] Godotエディタでインポート後（`.import`ファイル自動生成）、`TextureRect`で正しく表示できるファイル形式（PNG、透過背景可）であることを確認する

## Implementation Notes

- 参照すべき既存コード: `.claude/skills/atelier-image-gen/SKILL.md`, `.claude/skills/atelier-image-gen/references/style-guide.md`
- 実装のヒント: `atelier/assets/`配下はフォント以外ほぼ空のため、`atelier/assets/ui/title/`ディレクトリは本タスクで新規作成する。1枚絵のイラスト品質を優先する場合は`imagen-4.0-generate-001`系、アイコン的な簡易さで良ければデフォルトの`gemini-2.5-flash-image`でもよい（🟡判断はAI裁量、生成結果を見て判断してよい）
- 注意事項: `GEMINI_API_KEY`（または`GOOGLE_API_KEY`）環境変数が未設定の場合は生成できない。未設定ならユーザーに設定を依頼し、設定されるまで本タスクは`pending`のまま次のタスク（`005`）を先に進めてよい（`004`は`006`の前提だが`005`とは独立のため）

## Files

- 新規: `atelier/assets/ui/title/title_emblem.png`（＋Godotが自動生成する`.import`ファイル）
