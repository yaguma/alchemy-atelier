---
id: "002"
title: "エクスポート成果物の出力ディレクトリを.gitignoreに追加する"
status: done
priority: 2
dependencies: ["001"]
estimated_complexity: low
---

# Task: エクスポート成果物の出力ディレクトリを.gitignoreに追加する

## Goal

タスク001で`export_path`に設定した出力先（`atelier/build/`配下）をGitの追跡対象外にし、ビルド成果物（`.exe`・`.pck`等のバイナリ）が誤ってコミットされないようにする。

## Interfaces

`atelier/.gitignore`への追記内容（GDScriptではなくgitignoreパターン）。

```gitignore
# エクスポートビルド成果物（export_presets.cfgのexport_path出力先）
build/                                            # 🔵 タスク001のexport_pathと一致させる
```

## Test Strategy

Directモード対象（TDD対象外）。以下を手動確認する。

- [ ] `atelier/.gitignore`に`build/`パターンが追加されている
- [ ] `git status`で、`atelier/build/windows/atelier-alchemy.exe`（存在する場合）が追跡対象外（untracked扱いされない）になっている
- [ ] 既存の`.godot/`・`reports/`除外設定が変更されていない（差分が`build/`追加のみであること）

## Implementation Notes

- 参照すべき既存ファイル: `atelier/.gitignore`（現状`.godot/`と`reports/`の2エントリのみ）
- タスク001で`export_path`を`build/windows/...`以外に変更した場合、このパターンも追従させること

## Files

- 変更: `atelier/.gitignore`
