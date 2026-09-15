# タイトル画面 詳細設計

作成日: 2026-09-15
準拠要件: 要件定義書（[`../../../../spec/atelier-alchemy-core/requirements.md`](../../../../spec/atelier-alchemy-core/requirements.md)）には本画面の規定がない（[`../overview.md`](../overview.md)「画面一覧」節参照）。実装根拠は[`../../../../dev/plans/title-screen-design/plan.md`](../../../../dev/plans/title-screen-design/plan.md)（水彩ファンタジー装飾、本文書の直接の対象）および[`../../../../dev/plans/title-settings-screens-extension/plan.md`](../../../../dev/plans/title-settings-screens-extension/plan.md)（4ボタン構成・分岐なしの導線を規定したPlan）。

## 基本情報

| 項目 | 値 |
|------|-----|
| 画面ID | SCR-008 |
| 親画面 | なし（`BootScene`の直後に表示される起動直後の最初の画面） |
| 子画面 | SCR-009 設定パネル（`SettingsPanel`、`%OverlayLayer`上にオーバーレイ表示。画面遷移は伴わない） |

対応実装ファイル: `atelier/features/title/ui/title_screen.gd` / `.tscn`（背景は`atelier/features/title/ui/title_backdrop.gd` / `.tscn`として分離実装）。

## ワイヤーフレーム

```
┌─────────────────────────────────────────────┐
│ TitleBackdrop（全面背景。朝の庭イメージ）        │
│  ├─ SkyRect: 空のグラデーション（上→中→下の3色） │
│  ├─ SunGlow: 朝日のグロー（加算合成）            │
│  └─ _draw(): 丘2層のシルエット + 両端の草の額縁   │
│                                                │
│              ┌─────────────┐                  │
│              │ EmblemRect   │ ← LogoContainer  │
│              │ （紋章画像）  │                  │
│              │ 「アトリエ」  │ ← LogoLabel      │
│              └─────────────┘                  │
│                                                │
│              [ はじめから ]  ← NewGameButton    │
│              [ つづきから ]  ← ContinueButton   │
│              [  せってい  ]  ← SettingsButton   │
│              [   終了    ]  ← QuitButton        │
│                                                │
│ (OverlayLayer: せってい押下時にSettingsPanelを重ねて表示) │
└─────────────────────────────────────────────┘
```

🔵 `LogoContainer`（画面上部6%〜42%）に紋章＋ロゴ文字、`RootContainer`（画面上部46%〜100%）に4ボタンを縦積みで配置するレイアウトは`title_screen.tscn`の`anchor_top`/`anchor_bottom`値をそのまま反映したもの（実装済み、提案ではない）。

## UI要素

| 要素ID | 種類 | 対応ノード | 説明 | 状態 |
|--------|------|-----------|------|------|
| bg-title-backdrop | 背景（`TitleBackdrop`シーン） | `TitleBackdrop`（`SkyRect`/`SunGlow`+`_draw()`の丘・草シルエット） | 朝の庭をイメージした静的背景。`GameState`非依存の純粋装飾で、`resized`時のみ再描画する | 常時表示（状態を持たない） |
| img-logo-emblem | 画像 | `%EmblemRect` | ゲームロゴの紋章画像（`res://assets/ui/title/title_emblem.png`） | 常時表示 |
| txt-logo-title | テキスト | `%LogoLabel` | ロゴ文字「アトリエ」。`UiTheme.FONT_MAIN`・フォントサイズ40（`TitleScreen.LOGO_FONT_SIZE`、🟡design-guide.md未確定のため画面専用の暫定値） | 常時表示 |
| btn-new-game | プライマリボタン | `%NewGameButton` | 「はじめから」。押下すると`%ContinueButton`と同じ遷移先（SCR-007）へ進む。新規/継続の実際の判定は本画面では行わない | 常時有効 |
| btn-continue | セカンダリボタン | `%ContinueButton` | 「つづきから」。`btn-new-game`と同一の遷移先（SCR-007）へ進む | 常時有効 |
| btn-settings | ターシャリボタン | `%SettingsButton` | 「せってい」。`%OverlayLayer`上に`SettingsPanel`をオーバーレイ表示する（画面遷移なし） | 常時有効 |
| btn-quit | セカンダリボタン | `%QuitButton` | 「終了」。`get_tree().quit()`を呼ぶ | 常時有効 |

🔵 4ボタンのvariant割り当て（プライマリ/セカンダリ/ターシャリ）は`title_screen.gd`の`_apply_theme()`で`ButtonStyleApplier.apply_button_style()`により実装済み。`design-guide.md`のボタン4種のうち、本画面では確定アクション以外にターシャリ（「せってい」、最も控えめなアクション）を用いており、デンジャーバリアントは使用しない。

## 状態遷移

### 初期状態

起動直後（`BootScene`完了後）に表示される。`%OverlayLayer`は空で、4ボタンはすべて常時有効。

### 設定パネル表示状態

`btn-settings`押下で`SettingsPanel.open_singleton()`が`_settings_panel`（多重起動防止ガード）・`%OverlayLayer`・クローズコールバックを渡して呼ばれ、パネルが`%OverlayLayer`上にオーバーレイ表示される。パネルが閉じられると`_on_settings_panel_closed()`で`_settings_panel`が`null`に戻り、再度「せってい」を押下可能になる（多重起動防止、実装コメントFR-102・FR-407参照）。

### 遷移待ち状態

`btn-new-game`/`btn-continue`押下時は、ボタンのシグナル処理中に`change_scene_to_file`を直接呼ぶと「Parent node is busy adding/removing children」エラーになるため、`get_tree().change_scene_to_file.call_deferred(...)`で次フレームへ遅延させている（`title_screen.gd`実装コメント参照）。この間、画面上は特別な表示変化を伴わない。

### エラー状態

本画面はプレイヤー入力の検証を伴わないため、該当するエラー状態はない（🔵）。

## アニメーション

| トリガー | アニメーション | 手法 | 時間 | イージング |
|----------|---------------|------|------|-----------|
| （画面表示時のフェードイン等） | 🟡TBD | 🟡TBD | 🟡TBD | 🟡TBD |
| ボタンホバー/押下時のフィードバック | 🟡TBD | 🟡TBD | 🟡TBD | 🟡TBD |

🟡 本Plan（title-screen-design）では静的背景（`TitleBackdrop`）と4ボタンのスタイル適用までが対象で、Tweenによる演出は未着手（`screen-craft`スキルの演出レイヤー区分でいう「HUD/操作UI」のフィードバック演出）。将来のTween演出は別タスクとして扱う。

## イベント

| イベント名 | トリガー | 処理内容 |
|-----------|----------|----------|
| OnNewGamePressed | `%NewGameButton`押下 | `_go_to_slot_select()`を呼び、`_requested_next_scene_path`にSCR-007のシーンパスを記録した上で`change_scene_to_file`を遅延実行 |
| OnContinuePressed | `%ContinueButton`押下 | `OnNewGamePressed`と同一処理（`_go_to_slot_select()`） |
| OnSettingsPressed | `%SettingsButton`押下 | `SettingsPanel.open_singleton(_settings_panel, _overlay_layer, _on_settings_panel_closed)`を呼び、`%OverlayLayer`上に設定パネルを開く |
| OnSettingsPanelClosed | 設定パネルの閉じる操作（パネル側の責務） | `_settings_panel`を`null`に戻す |
| OnQuitPressed | `%QuitButton`押下 | `_has_requested_quit`を立てた上で（`quit_enabled`時のみ）`get_tree().quit()`を呼ぶ |

🔵 `TitleScreen`自身は`signal`を宣言していない（ボタンの`pressed`シグナルを内部で直接`connect()`する構成）。テスト用の観測点として`get_requested_next_scene_path()`（要求された遷移先シーンパスを返す。未要求時は空文字列）・`has_requested_quit()`（終了要求の有無）の2つのpublicメソッドを公開している。`scene_transition_enabled`/`quit_enabled`をfalseにすると実際の遷移・終了を伴わずに要求の発生のみを検証できる（GdUnit4統合テスト用、`boot.gd`/`slot_select_screen.gd`と同方針）。

## アクセシビリティ

- [ ] キーボード操作対応（🟡TBD、Godotの`Control`フォーカスチェーンで対応予定）
- [ ] スクリーンリーダー対応（🔴要件定義書に規定なし、対応方針未定）
- [x] 色覚多様性対応（4ボタンはいずれもテキストラベル付きで、variant差はレイアウト上の並び順とテキスト内容でも判別できるため、色のみに依存しない。`.claude/rules/design-guide.md`の「明瞭さ: アイコン+テキスト併記」の方針を踏襲🔵）
- [ ] フォーカス表示（🟡TBD）
