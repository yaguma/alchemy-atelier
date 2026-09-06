# Plan: title-settings-screens-extension

## 前提（重要）

`/dev-plan title-settings-screens` 実行直後、`dev-run`着手前のブランチ準備で **同名機能が過去に実装・マージ済み** であることが判明した（PR #46「タイトル画面・設定画面を追加する」、2026-09-04マージ、1018テスト全通過）。ただしマージ先が`main`ではなく`feat/save-load-system`ブランチ（既にmainへマージ済みの側）だったため、PR #46の2コミット分だけが`main`に取り込まれず宙に浮いていた。

ユーザーの判断（2026-09-06ヒアリング）: **旧実装を採用して拡張する**。旧実装をゼロから再実装するのではなく、`feat/title-settings-screens-integration`ブランチ（`main`基点で旧ブランチを`git merge`済み、コンフリクトなし、1026テスト/gdlint/gdformatすべてクリーン確認済み）の上に、不足分のみを追加する。

本Planは元の`docs/dev/plans/title-settings-screens/`（Lightweightモード、6タスク、ゼロから構築する前提）を置き換える。元Planの成果（GameStateリセット問題の発見、一時停止メニュー設計）はそのまま本Planに引き継ぐ。

## 旧実装の到達点（そのまま活用、再実装しない）

- `atelier/features/title/ui/title_screen.{tscn,gd}`: 「はじめる」「せってい」の2ボタン
- `atelier/features/settings/{logic/settings_codec.gd, state/settings_data.gd}`: 純粋関数・値オブジェクト
- `atelier/autoload/settings_service.gd`: 永続化（`user://settings.json`）＋AudioServer/DisplayServerへの反映
- `atelier/shared/ui/settings_panel.{tscn,gd}`: BGM/SE音量・ウィンドウモード・演出簡略化の4項目（音量2項目のみという today's要件より実は範囲が広い。追加項目は削らずそのまま残す）
- `atelier/shared/ui/rank_hud.gd`: 歯車ボタン＋`settings_requested`シグナルでゲーム中から`SettingsPanel`を直接開ける
- `atelier/scenes/boot.gd`: 遷移先が`title_screen.tscn`に変更済み
- テスト94スイート1026ケース、gdlint/gdformatクリーン（`feat/title-settings-screens-integration`で再確認済み）

### 既知の未解決事項（旧実装のコメントに明記済み、今回のスコープ外）

- 🔴 `SettingsService`のBGM/SEバスは`project.godot`にAudioBusLayoutが無いため`AudioServer.get_bus_index()`が`-1`を返し、音量反映は事実上no-op（バス追加は将来の音声実装タスクで対応）。

## 今回追加する差分（今日確定した要件との差分）

| 差分 | 今日の要件 | 旧実装の状態 |
|---|---|---|
| タイトルの終了ボタン | 「終了」ボタンで`get_tree().quit()` | 存在しない |
| タイトルのはじめから/つづきから分割 | 別ラベルの2ボタン（遷移先は同じでよい） | 「はじめる」1ボタンのみ |
| ゲーム中の一時停止導線 | 常時HUDボタン→「閉じる／設定／タイトルに戻る」の3択 | 歯車ボタン→設定パネル直行のみ、「タイトルに戻る」導線が無い |
| GameStateリセット | 「タイトルに戻る→はじめから」で前回値を引き継がない | 「タイトルに戻る」自体が存在しないため未対応。追加すると即座に必要になる |

## タスク一覧

1. **E1**: `GameState.reset_for_new_game()`を追加し、新規スロット選択時にリセットする
2. **E2**: `TitleScreen`に「はじめから」「つづきから」「終了」を追加する（「せってい」は既存のまま）
3. **E3**: ゲーム中の一時停止導線（`PauseMenu`新設、`RankHud`の歯車ボタンの遷移先を差し替え）を追加する
4. **E4**: ドキュメント（`CLAUDE.md`・`ui-design/overview.md`）を実装済み状態に更新する
5. **E5**: 結合確認（全テスト・gdlint・gdformat）とverifyレポート作成

## Task Dependency Graph

```
E1 ─────────────┐
E2 ──────────────┼──▶ E3 ──▶ E4 ──▶ E5
```

E1・E2は独立。E3はE1（リセットAPI）とE2（TitleScreenのシーンパス）の両方を使うため両方の後に実施する。

## Cross-Plan Dependencies

- `docs/dev/plans/title-settings-screens/`（旧Plan、`feat/title-settings-screens`ブランチ由来）: 実装済み部分の一次情報源。本Planはこれを再実装しない。
- 作業ブランチ: `feat/title-settings-screens-integration`（`main`から分岐し旧ブランチを`git merge`済み）。本Planの全タスクはこのブランチ上で継続する。
