---
id: "002"
title: "Godotバイナリのセットアップ・キャッシュ・プロジェクトインポートステップを追加する"
status: done
priority: 2
dependencies: ["001"]
estimated_complexity: medium
---

# Task: Godotバイナリのセットアップ・キャッシュ・プロジェクトインポートステップを追加する

## Goal

`.github/workflows/ci.yml`（001で作成した骨格）に、Godot 4.7.1-stable公式バイナリをダウンロード・キャッシュ・展開して`GODOT_BIN`環境変数を設定し、クリーン環境の初回インポート（`.godot/`キャッシュ生成）を行うステップを追加する。

## Interfaces

```yaml
# 001の`steps:`に以下を追記する
      - name: Cache Godot binary
        id: godot-cache
        uses: actions/cache@v4                                    # 🔵 GitHub公式Action
        with:
          path: /opt/godot
          key: godot-4.7.1-stable-linux-x86_64                     # 🟡 バージョン変更時にキー変更を忘れないよう、バージョン番号自体をキーに含める設計

      - name: Download Godot binary
        if: steps.godot-cache.outputs.cache-hit != 'true'
        run: |
          curl -fsSL -o /tmp/godot.zip \
            "https://github.com/godotengine/godot-builds/releases/download/4.7.1-stable/Godot_v4.7.1-stable_linux.x86_64.zip"
          # 🔵 gh api repos/godotengine/godot-builds/releases/tags/4.7.1-stable で実在確認済みのアセット名
          mkdir -p /opt/godot
          unzip -q /tmp/godot.zip -d /opt/godot
          mv "/opt/godot/Godot_v4.7.1-stable_linux.x86_64" /opt/godot/godot
          chmod +x /opt/godot/godot

      - name: Set GODOT_BIN
        run: echo "GODOT_BIN=/opt/godot/godot" >> "$GITHUB_ENV"     # 🔵 README.md記載のGODOT_BIN運用と同じ変数名

      - name: Import project
        run: "$GODOT_BIN" --headless --path atelier --import        # 🔵 docs/dev/context.md「クリーン環境の初回インポート」コマンドと同一
```

> 🔴 未検証事項: Godot 4.7系のLinux版バイナリは動的リンクの遅延ロード（dlopen）によりX11/OpenGL系の共有ライブラリが実行時に存在しなくても`--headless`実行が可能という前提を置いている（Linux向けアセットに専用headlessビルドが存在しないことから逆算した推測）。CI実行時に共有ライブラリ不足エラー（`error while loading shared libraries`等）が出た場合は、`apt-get install -y libgl1 libglu1-mesa libxcursor1 libxinerama1 libxrandr1 libxi6`等の追加ステップを本タスクの後続修正として挿入する。
>
> 【実装時の追加修正】`actions/cache`の`path`/展開先を当初案の`/opt/godot`から`~/godot`（`$HOME/godot`）に変更した。GitHub Actionsのubuntu-latestランナーの既定ユーザー（`runner`）は`/opt`への書き込み権限を持たず、`sudo`なしでは`mkdir -p /opt/godot`が失敗するため。また、シェルスクリプト内では`~`をダブルクォート内で使うとbashのチルダ展開が効かない（`GITHUB_ENV`へ書き込んだ値も後続ステップでのシェル再展開時にチルダ展開されない）ため、`run:`ブロック内は`~`ではなく`$HOME`で統一した。

## Test Strategy

- [ ] キャッシュミス時（初回実行）: Godotバイナリのダウンロード→展開→`chmod +x`が成功し、`$GODOT_BIN --version`が`4.7.1.stable`を含む文字列を出力する
- [ ] キャッシュヒット時（2回目以降の実行）: ダウンロードステップがスキップされ、`$GODOT_BIN --version`が同じ結果を返す
- [ ] `godot --headless --path atelier --import`がエラー終了コード以外（0）で完了する
- [ ] インポート実行後、`atelier/.godot/`ディレクトリ（またはインポートキャッシュの生成物）が存在する
- エッジケース: 共有ライブラリ不足でバイナリ起動自体が失敗する場合、エラーメッセージを確認しApt依存パッケージ追加で対処する（上記🔴の対応）

## Implementation Notes

- 参照すべき既存コード: `README.md`（GODOT_BINの用途説明）、`docs/dev/context.md`「クリーン環境の初回手順」
- 実装のヒント: `actions/cache@v4`の`key`にバージョン文字列を含めることで、将来Godotバージョンを上げた際にキャッシュキーの更新漏れを防ぐ（キーが変わらないと古いバイナリが使われ続けるリスクがあるため）
- 注意事項: ダウンロードURLの`godot-builds`リポジトリは`godotengine/godot`本体とは別リポジトリ（公式ビルド配布専用）。誤って`godotengine/godot`のreleasesを参照しないこと

## Files

- 新規: なし
- 変更: `.github/workflows/ci.yml`（Godotセットアップ・インポートステップを追記）
- テスト: なし（GitHub Actions実行結果で検証。005タスクで実PR検証を行う）
