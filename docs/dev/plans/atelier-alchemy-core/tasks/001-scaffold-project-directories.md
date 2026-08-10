---
id: "001"
title: "Godotプロジェクトを新規作成しディレクトリをスキャフォールディングする"
status: done
priority: 1
dependencies: []
estimated_complexity: low
---

# Task: Godotプロジェクトを新規作成しディレクトリをスキャフォールディングする

## Goal

Godot 4.7で `atelier/` プロジェクトを新規作成し、`architecture.md`「ディレクトリ構造（案）」+ FR-001の直積解釈（`workshop/state/`を含む全5機能×4サブディレクトリ）に基づく全ディレクトリツリーをスキャフォールディングする。空ディレクトリは`.gitkeep`でgit追跡する。

## Interfaces

このタスクはコード実装ではなくディレクトリ・設定ファイル作成が中心（Directモード）。

```
atelier/                                              # 🔵 Godotエディタでプロジェクト新規作成時に自動生成
├── project.godot                                              # 🔵 Godot 4.7を対象バージョンとして固定（FR-003, CON-001）
├── autoload/                                                  # 🔵 非空（002, 003で使用）
├── features/
│   ├── garden/{logic,state,resources,ui}/                     # 🔵 全て空 → .gitkeep
│   ├── alchemy/{logic,state,resources,ui}/                    # 🔵 全て空 → .gitkeep
│   ├── guild/{logic,state,resources,ui}/                      # 🔵 全て空 → .gitkeep
│   ├── workshop/{logic,state,resources,ui}/                   # 🔵 state/含む（ユーザー確認済み: FR-001直積解釈を採用）
│   └── rank/{logic,state,resources,ui}/                       # 🔵 全て空 → .gitkeep
├── shared/
│   ├── constants/                                             # 🔵 空 → .gitkeep（game_balance.gdは対象外、FR-402相当の範囲外）
│   ├── theme/                                                 # 🔵 非空（004で使用）
│   ├── entities/                                              # 🔵 空 → .gitkeep
│   └── loaders/                                                # 🔵 非空（005で使用。ユーザー確認済み: 新規サブディレクトリとして新設）
├── assets/
│   └── fonts/                                                 # 🔵 非空（004で使用。architecture.mdのツリーには無いがgodot-best-practices.mdの既存例に合わせ新設）
├── data/
│   ├── materials/ recipes/ ranks/ upgrades/ daily_orders/     # 🔵 全て空 → .gitkeep（FR-402: 実データ作成禁止）
├── scenes/                                                    # 🔵 非空（006, 007で使用）
└── tests/
    ├── unit/features/{garden,alchemy,guild,workshop,rank}/     # 🔵 全て空 → .gitkeep（本Planではlogicテストなし）
    └── integration/                                            # 🔵 非空（009で使用）
```

`addons/gut/` はこのタスクでは作成しない（008でユーザーが手動インストール、CON-002）。

## Test Strategy

Directモードのためテストコードは書かない。以下を目視・コマンドで確認する。

- [ ] `godot --headless --path atelier --import` が正常終了する（FR-106, AC-010）
- [ ] `atelier/project.godot` に Godot 4.7 が対象バージョンとして記録されている
- [ ] 上記ディレクトリツリーが全て存在し、空ディレクトリには `.gitkeep` が配置されている（FR-001, FR-002, AC-001）
- [ ] `git status` で全ディレクトリが追跡対象になっている（`.gitkeep`のみのディレクトリも含む）

## Implementation Notes

- 参照すべき既存文書: `docs/design/atelier-alchemy-core/architecture.md`「ディレクトリ構造（案）」
- Godotエディタで「新規プロジェクト」からプロジェクトを作成すると `project.godot` / `.godot/` / `.gitignore` / `.gitattributes` が自動生成される。手動で `project.godot` をゼロから書く必要はない
- `.gitkeep` は空ディレクトリのみに配置する（002〜009で中身が入るディレクトリには不要）
- `workshop/state/` はarchitecture.mdの例示ツリーには無いが、FR-001の文言（5機能×4サブディレクトリの直積）をユーザー確認の上で正とする

## Files

- 新規: `atelier/project.godot`, `atelier/.gitignore`, 上記ディレクトリツリー一式 + 各空ディレクトリの `.gitkeep`
- 変更: なし
- テスト: なし（Directモード）
