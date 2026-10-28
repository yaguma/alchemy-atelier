---
name: godot-visual-check
description: |
  Godot MCP（godot-ai）を使って、atelier/のゲーム画面を実際に起動し、スクリーンショット・UI要素・
  ゲームログを取得して見た目を確認するスキル。変更ファイルから確認すべき画面を判定し、
  起動 → 画面遷移 → 撮影 → 検証 → レポートまでを行う。
  使用タイミング:
  (1) 「ビジュアル確認」「画面確認」「見た目を確認」「スクショを撮って」と言われた時
  (2) 「/godot-visual-check」コマンドが実行された時
  (3) screen-craftスキルの「動作確認する」手順、またはfeatures/*/ui/・shared/ui/・scenes/を
      変更したPRの作成後に、目視確認が必要になった時
  引数: [画面名]（省略時: 変更ファイルから自動判定。title / slot_select / garden / alchemy /
  guild_delivery / workshop / result / pause_menu）
  オプション: --all（全画面を確認）, --pr <PR番号>（結果をPRコメントに投稿）
  CIでは使わない（回帰テストはGdUnit4で書く）。
---

# Godot Visual Check

Godot MCP（godot-ai、Issue #80で導入）を使って、ゲーム画面の見た目を確認する。
GdUnit4は`--headless`で実行されるため描画されず、見た目の崩れはテストでは検出できない。
このスキルはその穴を埋める**調査用**の手順であり、回帰テストの代わりにはならない
（見つけた不具合は、可能な範囲でGdUnit4テストに昇格する。[`godot-debug-tools.md`](../../rules/godot-debug-tools.md)参照）。

## 引数

| 引数 | 必須 | 説明 | 例 |
|------|------|------|-----|
| `screen` | - | 確認する画面名（省略時: 変更ファイルから自動判定） | `alchemy` |
| `--all` | - | 全画面を確認する | - |
| `--pr N` | - | 結果をPR #Nにコメントとして投稿する | `--pr 85` |

## 前提条件

- Godotエディタで`atelier/`が開かれ、Godot AIプラグインが接続済みであること
  （`session_manage`の`op: "list"`で`count >= 1`）。未接続なら、ユーザーにエディタの起動を依頼するか、
  `godot --path atelier --editor`を`run_in_background: true`で起動し、接続されるまで`session_manage`で確認する
- 導入手順・運用上の注意は[`README.md`](../../../README.md)「Godot MCP（godot-ai）」節を参照
- VOICEVOXは利用可能なら使う（使えなければ音声通知を省略する）

## 使うMCPツール（2026-10-29に実機で動作確認済み）

| ツール | 用途 |
|--------|------|
| `session_manage`（`op: "list"`） | エディタとの接続確認 |
| `project_run`（`mode: "custom"`, `scene`, `autosave: false`） | 指定シーンの起動 |
| `editor_state` | 起動完了待ち（`game_status.status == "live"`かつ`game_capture_ready == true`まで再確認） |
| `editor_screenshot`（`source: "game"`, `max_resolution: 960`） | 実行中ゲームの画面を撮影 |
| `game_manage`（`op: "get_ui_elements"`） | 表示中のControlのパス・種類・テキスト・矩形を取得 |
| `game_manage`（`op: "input_mouse"`） | ボタン押下（`pressed: true`→`false`の2回送る。座標はゲーム解像度1280×720基準） |
| `editor_manage`（`op: "game_eval"`） | 実行中ゲームでGDScriptを実行（状態の確認・画面への移動） |
| `logs_read`（`source: "game"`） | ゲームの`push_error`/`push_warning`/標準出力 |
| `project_manage`（`op: "stop"`） | ゲームの停止 |

> 🔴 `editor_screenshot`の`max_resolution`は`960`以下にする。`0`（フル解像度）はMCPの1MB上限を超えて失敗する。
> 撮影結果は画像としてツール結果に返るだけで、ファイルには保存されない。

## 実行フロー

```
Step 0: 確認する画面を決める
Step 1: 接続確認 → ゲーム起動（project_run） → live待ち
Step 2: 画面ごとに［移動 → 撮影 → UI要素取得 → 観点チェック → ログ確認］
Step 3: ゲーム停止（project_manage stop）
Step 4: レポート出力（--pr指定時はPRコメント投稿）
```

## Step 0: 確認する画面を決める

引数で画面が指定されていればそれだけを確認する。`--all`なら下表の全画面を確認する。
指定がなければ`git diff origin/main --name-only`の結果を下表と突き合わせる。

| 変更ファイル（`atelier/`配下） | 確認する画面 |
|------------------------------|------------|
| `features/title/ui/`, `scenes/boot.*` | title |
| `features/save_load/ui/` | slot_select |
| `features/garden/ui/` | garden |
| `features/alchemy/ui/` | alchemy |
| `features/guild/ui/` | guild_delivery |
| `features/workshop/ui/` | workshop |
| `features/rank/ui/` | result（試験結果オーバーレイの変更なら alchemy も） |
| `shared/ui/pause_menu.*`, `shared/ui/settings_panel.*` | pause_menu |
| `shared/ui/rank_hud.*`, `scenes/main.*` | garden, alchemy |
| `shared/theme/`, `shared/ui/`（上記以外）, `assets/` | title, garden, alchemy（代表） |

どれにも当たらなければ「UI変更なし」としてスキップし、その旨を報告する。

## Step 1: 起動

1. `session_manage`（`op: "list"`）で接続を確認する
2. 起動するシーンを選ぶ
   - title: `res://scenes/boot.tscn`（Boot → Title と遷移する）
   - slot_select: `res://features/save_load/ui/slot_select_screen.tscn`
   - それ以外: `res://scenes/main.tscn`（スロット未選択で起動するため、セーブデータは読み込まれず初期状態になる）
3. `project_run`（`mode: "custom"`, `scene: <上記>`, `autosave: false`）
4. `project_run`の応答が`status: "not_live"`でも起動途中のことが多い。`editor_state`を呼び直し、
   `game_status.status == "live"`になるまで待つ。`"break"`ならスクリプトエラーで止まっているので、
   `logs_read`（`source: "editor"`, `include_details: true`）で原因を確認して`project_manage`（`op: "stop"`）する

## Step 2: 画面ごとの確認

### 2-1: 画面への移動（main.tscn起動時）

UIのボタンを実際に押して移動するのを優先する（ユーザー操作と同じ経路を通るため）。
ボタンの座標は`get_ui_elements`の`global_rect`の中心を使う。

| 画面 | 移動方法 |
|------|---------|
| garden | 起動直後の画面（初期フェーズ） |
| alchemy | 「調合」タブ（`/Main/RootLayout/HeaderBar/TabBar/AlchemyTabButton`）を押す |
| guild_delivery | alchemyで「ターンを終了する」を押す（納品結果画面が重なって表示される） |
| workshop | garden/alchemyの「ショップ」を押す |
| pause_menu | RankHudの「メニュー」を押す |
| result | `game_eval`で`GameState.set_phase(&"result")`（実際の終局を経ずに画面だけ確認する場合） |

ボタンでたどり着けない状態は`game_eval`で作ってよい（例: `GameState.set_phase(&"alchemy")`、
デバッグパネルの`G+1000`ボタン）。ただし`game_eval`で作った状態は実際のプレイで起こりうるとは限らない。
レポートには「どうやってその状態にしたか」を書く。

### 2-2: 撮影

`editor_screenshot`（`source: "game"`, `max_resolution: 960`）。結果に`stale_frame: true`が付いたら、
ゲームウィンドウが裏に回って描画が止まっているので、ユーザーにウィンドウを前面に出してもらい撮り直す。

### 2-3: 観点チェック

スクリーンショットと`get_ui_elements`の結果を見て、以下を確認する。

| 観点 | 確認方法 |
|------|---------|
| ドット絵のにじみ（`texture_filter`） | 画像でぼやけていないか見る。加えて下記「にじみ検出スニペット」を`game_eval`で実行する（[`design-guide.md`](../../rules/design-guide.md)「禁止事項」） |
| 9-sliceの崩れ | パネル・ボタンの枠の角が引き伸ばされていないか、枠が途切れていないか |
| 日本語フォント（DotGothic16） | 文字が豆腐（□）になっていないか、ドット絵フォントで描かれているか（[`godot-best-practices.md`](../../rules/godot-best-practices.md)「日本語テキスト描画の注意」） |
| ボタン4種の使い分け | 確定=プライマリ／戻る=セカンダリ／ターン終了・破棄=デンジャー／設定等=ターシャリになっているか（[`design-guide.md`](../../rules/design-guide.md)「ボタン」。タイトル画面は全ボタンがセカンダリの例外） |
| レイアウト | `get_ui_elements`の`global_rect`が画面（1280×720）からはみ出していないか、行が高さ0に潰れて重なっていないか（`ForwardingControl`の付け忘れ。[`ui-components.md`](../../rules/ui-components.md)参照） |
| テキスト | ラベル・ボタンの`text`が空でないか、枠からはみ出していないか |

#### にじみ検出スニペット

テクスチャを使って描画しているノード（`TextureRect`/`NinePatchRect`/`Sprite2D`と、
StyleBoxTextureを使う`Button`/`Panel`/`PanelContainer`）のうち、実際に効いている`texture_filter`が
NEARESTでないもののパスを返す。空配列なら問題なし。

```gdscript
var root_nearest: bool = get_tree().root.canvas_item_default_texture_filter == Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
var blurry := []
for n in get_tree().root.find_children("*", "CanvasItem", true, false):
	if not n.is_visible_in_tree():
		continue
	var uses_texture := false
	if n is TextureRect or n is NinePatchRect or n is Sprite2D:
		uses_texture = true
	elif n is Button:
		uses_texture = n.get_theme_stylebox("normal") is StyleBoxTexture
	elif n is PanelContainer or n is Panel:
		uses_texture = n.get_theme_stylebox("panel") is StyleBoxTexture
	if not uses_texture:
		continue
	var cur: Node = n
	while cur is CanvasItem and (cur as CanvasItem).texture_filter == CanvasItem.TEXTURE_FILTER_PARENT_NODE:
		cur = cur.get_parent()
	var f: int = (cur as CanvasItem).texture_filter if cur is CanvasItem else CanvasItem.TEXTURE_FILTER_PARENT_NODE
	if not (f == CanvasItem.TEXTURE_FILTER_NEAREST or (f == CanvasItem.TEXTURE_FILTER_PARENT_NODE and root_nearest)):
		blurry.append(str(n.get_path()))
return blurry
```

> プロジェクト既定の`default_texture_filter`はLinearのため、NEARESTを明示していないノードはにじむ。

### 2-4: ログ確認

`logs_read`（`source: "game"`）で`level`が`error`/`warning`の行がないか確認する。
`[godot_ai game_helper] registered mcp capture`はMCPヘルパー自身の起動ログなので無視してよい。
応答に`editor_errors_hint`が付いている場合は、起動時のパースエラーなどがゲームログに出ていないので、
`logs_read`（`source: "editor"`）も確認する。

## Step 3: 停止

すべての画面を確認したら`project_manage`（`op: "stop"`）でゲームを止める。途中で失敗した場合も必ず止める。

## Step 4: レポート

画面ごとに、確認した内容と結果を表にまとめてユーザーに報告する。スクリーンショットはツール結果として
会話に表示されているので、レポートでは「どの画面をどう撮ったか」を書く。

```markdown
## 🖥️ Godot Visual Check Report

**実行日時**: 2026-10-29 01:30
**対象画面**: garden, alchemy（変更ファイル: features/alchemy/ui/alchemy_screen.gd）
**起動方法**: res://scenes/main.tscn を直接起動（セーブデータなし・初期状態）

### alchemy（「調合」タブを押して移動）

| 観点 | 結果 | 詳細 |
|------|------|------|
| ドット絵のにじみ | ✅ Pass | にじみ検出スニペットの結果は空 |
| 9-slice | ✅ Pass | 崩れなし |
| 日本語フォント | ✅ Pass | 豆腐なし |
| ボタン4種 | ✅ Pass | 「ショップ」がセカンダリ、「ターンを終了する」がデンジャー（設計通り） |
| レイアウト | ❌ Fail | `/Main/.../PreviewPanel`の高さが0で、下の行と重なっている |
| ゲームログ | ✅ Pass | error/warningなし |
```

問題が見つかった場合は、修正が必要な箇所（ノードパス・ファイル）と、GdUnit4テストに昇格できるか
（例: `texture_filter`の値や`get_combined_minimum_size()`は統合テストで検証できる）を添える。

### `--pr N`指定時

スクリーンショットはファイルに保存されないため、PRコメントにはテキストのレポートだけを投稿する。

```bash
gh pr comment N --body "$(cat <<'EOF'
## 🖥️ Godot Visual Check Report
{レポート内容}

🤖 Generated by `/godot-visual-check`（Godot MCPによる調査用の確認。CIでは実行しない）
EOF
)"
```

## エラーハンドリング

| 状況 | 対応 |
|------|------|
| `PLUGIN_DISCONNECTED` / `session_manage`が`count: 0` | エディタが起動していないか、プラグインが未接続。エディタを起動して待つ。それでも繋がらなければユーザーに伝えて中止する |
| `project_run`が`not_live` | 起動途中。`editor_state`を呼び直して`live`を待つ |
| `game_status.status == "break"` | 起動時のスクリプトエラー。`logs_read`（`source: "editor"`）で原因を確認し、`project_manage`（`op: "stop"`）する |
| `EVAL_GAME_NOT_READY` | ゲームがまだ起動中か、ウィンドウが裏に回っている。少し待つか前面に出して再実行する |
| `stale_frame: true` | ゲームウィンドウを前面に出して撮り直す |
| 撮影が1MB上限で失敗 | `max_resolution`を下げる（960以下） |

MCPが使えない環境では、エディタでの手動プレイによる確認に切り替え、
「スクリーンショットによる確認はできていない」とユーザーに明言する（確認していないことを確認済みと言わない）。

## 音声通知

| タイミング | メッセージ |
|-----------|-----------|
| 開始 | 「ビジュアル確認を開始するのだ」 |
| 画面ごとの完了 | 「{画面名}の確認が完了したのだ」 |
| 問題検出 | 「{画面名}で問題を{N}件見つけたのだ」 |
| 全体の完了 | 「ビジュアル確認が完了したのだ」 |
| スキップ | 「ユーアイの変更がないので、ビジュアル確認をスキップするのだ」 |

設定: `speaker=3, speedScale=1.3`
