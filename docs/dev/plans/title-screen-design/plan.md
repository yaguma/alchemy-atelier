# Plan: title-screen-design

## Requirements Summary

NanoBanana生成コンセプトアート（`docs/design/atelier-alchemy-core/nanobanana/Gemini_Generated_Image_Atelier_タイトル.jpg`、プロンプトは[`nanobanana-prompts.md`](../../../design/atelier-alchemy-core/nanobanana-prompts.md)「1. タイトル画面」）で固めた「水彩ファンタジー風の朝の庭＋ロゴ紋章」の見た目を、現状ほぼ無装飾（プレーンな`Button`4つを`VBoxContainer`に並べただけ）の`TitleScreen`（`atelier/features/title/ui/title_screen.gd`）実装に反映する。

確定方針（ユーザーヒアリング済み）:
- 対象範囲は**タイトル画面本体（`title_screen.gd`/`.tscn`）のみ**。`SettingsPanel`（タイトルからも一時停止メニューからも開く共通コンポーネント）のスタイル適用は本Planのスコープに含めない（次回以降のPlanで扱う）
- 🔴**重要な前提修正**: `docs/dev/plans/screen-design-update/`（庭・調合画面向けに`UiPanelStyleBox`/`UiTheme`拡張/背景コンポーネントを計画した先行Plan）は、タスクfrontmatterが全件`done`・検証レポートも「テスト1135件全PASS」を記録しているが、**実際のコード（`ui_panel_stylebox.gd`, `theme.gd`拡張分, `garden_backdrop.gd`等）は本リポジトリのどのブランチ・コミット履歴にも一度も存在しない**（`git log --all`で無関係、Plan自体も未コミットの`??`ファイル）。計画書として書かれた内容と実際の実装状況が一致していないため、本Planでは**その設計（インターフェース）だけを踏襲しつつ、基盤クラス自体を本Planの中で新規に実装する**（ユーザー承認済み）
- タイトルロゴ・紋章（乳鉢と乳棒／六芒星の魔法円）は`atelier-image-gen`スキルで画像アセットとして生成する。ただし`nanobanana-prompts.md`冒頭の注記どおりAI画像生成は日本語文字の正確な描画が苦手なため、**「アトリエ」のロゴ文字は画像に焼き込まず、装飾（紋章・六芒星・額縁）のみを画像化し、文字は`UiTheme.FONT_MAIN`を使った`Label`で別途重ねる**（🟡本Planでの解釈）
- 背景（空のグラデーション・朝日のグロー・丘や草の額縁シルエット）はNanoBanana画像を配色・構図の参考のみとし、`GardenBackdrop`と同じ方針でGodotネイティブの`GradientTexture2D`/`_draw()`で再構築する（画像アセットとして取り込まない）
- 既存のゲームロジック（`_go_to_slot_select()`, `_on_quit_pressed()`等の遷移・終了処理）・GdUnit4テスト（`test_title_screen.gd`, `test_title_settings_e2e.gd`）には見た目に無関係な変更をしない

## Design Overview

採用する技術方針（`screen-design-update`のタスク001〜004・006で設計済みだったインターフェースを、実装が存在しないため本Planで新規に作る前提で踏襲）:

1. **`UiPanelStyleBox`（`shared/theme/ui_panel_stylebox.gd`、`StyleBox`継承・`_draw()`オーバーライド）** を新設し、`RenderingServer.canvas_item_add_polygon()`の頂点カラーで縦グラデーション＋縁取り＋内側ハイライト/シャドウ＋外側ドロップシャドウを1クラスで表現する。角丸計算は独立`static func`（`_build_rounded_rect_points()`相当）に切り出しユニットテスト可能にする。
2. **`UiTheme`（`shared/theme/theme.gd`）拡張**: `ButtonVariant`（PRIMARY/SECONDARY/DANGER/TERTIARY）・`ButtonState`（NORMAL/HOVER/PRESSED/DISABLED）enumと、ボタン4種＋カードの暫定カラートークン、`make_card_stylebox()`/`make_button_stylebox()`を追加する。ゲージ/モーダル用ファクトリは本Plan（タイトル画面）では未使用のためインターフェースを用意せず、庭・調合画面向けPlanを再着手する際に追加する（YAGNI、本Planのスコープはタイトル画面に限定するため）。
3. **`UiTheme.apply_button_style(button, variant)`**（`shared/theme/button_style_applier.gd`）で4状態StyleBoxを一括適用するヘルパーを追加する。
4. **`TitleBackdrop`（`features/title/ui/title_backdrop.gd`/`.tscn`）**: `GardenBackdrop`と同じ設計（`GameState`非依存・`mouse_filter = MOUSE_FILTER_IGNORE`・`resized`シグナルで`queue_redraw()`）で、朝の空グラデーション＋朝日/六芒星のグロー＋なだらかな丘と草の額縁シルエットを`_draw()`で自前描画する。
5. **タイトルロゴ画像**: `atelier-image-gen`で生成した装飾画像（乳鉢と乳棒の紋章＋六芒星の魔法円、テキストなし）を`atelier/assets/ui/title/title_emblem.png`に保存し、`TextureRect`で表示。その上に「アトリエ」文字を`Label`（`UiTheme.FONT_MAIN`、大きめフォントサイズ）で重ねる。
6. **`TitleScreen._apply_theme()`**: `_ready()`冒頭で`TitleBackdrop`をルート最初の子として組み込み、ロゴ部を追加し、4ボタンに`UiTheme.apply_button_style()`を適用する。variant割り当て（🔴AI裁量、design-guide.mdの意味論に従う）:
   - `%NewGameButton` → `PRIMARY`（新規開始という一番踏み出したい確定アクション）
   - `%ContinueButton` → `SECONDARY`（新規と並ぶが、既存進行の再開という副次的な導線）
   - `%SettingsButton` → `TERTIARY`（最も控えめな補助アクション、design-guide.md「ターシャリ」の用途と一致）
   - `%QuitButton` → `SECONDARY`（終了は不可逆だが「データ破棄」ではないため、要件定義書に規定のないデンジャー用途には該当しない。overview.mdの「危険ボタンなし」方針を踏襲しSECONDARY扱いとする）
7. 画面設計書`docs/design/atelier-alchemy-core/ui-design/screens/title.md`を新規作成し（screen-craftのstep4手順）、`overview.md`の画面一覧テーブル（SCR-008行）の「詳細ファイル」リンクを更新する。

## Task Dependency Graph

```
001 UiPanelStyleBox基盤クラス新設
  └─▶ 002 UiTheme色トークン+ボタンStyleBoxファクトリ追加
        └─▶ 003 ButtonStyleApplier（apply_button_style）追加
              └─▶ 006 TitleScreen本体へ新スタイル適用 ◀── 004 ◀── 005
004 タイトルロゴ画像アセット生成（atelier-image-gen、001〜003と並行実施可）
005 TitleBackdrop実装（GameState非依存、001〜004と並行実施可）
006 TitleScreen本体へ新スタイル適用（背景・ロゴ・ボタン）
  └─▶ 007 画面設計書（screens/title.md新規＋overview.md反映）
        └─▶ 008 回帰確認（gdlint/gdformat/GdUnit4全件、実際のコミット・実装が存在することの確認を含む）
```

推奨実施順序: 001 → 002 → 003 → (004・005を並行) → 006 → 007 → 008

## Cross-Plan Dependencies

- 本Planで新設する`UiPanelStyleBox`／`UiTheme.make_card_stylebox()`・`make_button_stylebox()`・`apply_button_style()`は、`screen-design-update`（庭・調合画面、未実装のまま）および未着手のギルド納品・工房強化・昇格試験・スロット選択・一時停止設定・結果画面のPlanでもそのまま再利用できる設計にする。ただし**それらのPlanは本Planの成果物を前提に置く前に、対象ファイルが実際にコミットされているかを`git log`等で必ず再確認すること**（本Planの発端となった`screen-design-update`の検証レポートと実装の乖離を繰り返さないため）。
- `SettingsPanel`（`atelier/shared/ui/settings_panel.gd`）・`PauseMenu`へのスタイル適用は本Plan未対応。次回Plan（例: `settings-pause-screen-design`）で本Planの`UiTheme`/`UiPanelStyleBox`を再利用して行う想定。
