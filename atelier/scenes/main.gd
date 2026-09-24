class_name MainScene
extends Control

## ゲーム本編のルートシーン。4画面（庭・調合・工房・結果）を常駐させたまま
## GameState.phase_changedに追随してvisibleを排他的に切り替える（FR-001, FR-103）。
## シーン遷移ではなくvisible切替を採るのは、ターン制で画面往復が頻繁なため
## （architecture.md「シーン構成」）。
## あわせて庭⇔調合の共通タブバーを保持し、押下でset_phase()を呼ぶ（FR-101, FR-102）。
## 庭/調合からの工房呼び出しと工房を閉じたときの復帰も本シーンが仲介する（FR-104, FR-105）。
## 昇格試験の開始・合否分岐・終局（クリア/オーバー）のフェーズ遷移も本シーンが担う
## （FR-108〜FR-113）。

# 🔵 FR-001, FR-103。フェーズ名の綴りをmain.gd内の1箇所に集約し、
# _apply_visible_phase()とget_visible_phase()の対応漏れを防ぐ
const PHASE_GARDEN := &"garden"
const PHASE_ALCHEMY := &"alchemy"
const PHASE_WORKSHOP := &"workshop"
const PHASE_RESULT := &"result"
# 🔴 未知フェーズ時に「どの画面も可視でない」ことを表す番兵値（AC-001異常系）
const PHASE_NONE := &""

# 🟡 FR-104, FR-105。工房を開く直前のフェーズを復帰先として保持する。current_phaseと
# 一時的に二重保持になるが、GameStateへ復帰先フィールドを追加しない方針（FR-404）に沿った
# requirements.md AC-004の許容例外。初期値は既定の復帰先である庭
var _phase_before_workshop: StringName = PHASE_GARDEN

# 🟡 title-settings-screens-extension Plan。多重起動防止のガードに使う。
# closedを受けてnullへ戻す（title_screen.gd/pause_menu.gdと同型）
var _pause_menu: PauseMenu = null

# 🔵 タスク014（ui-polish Plan）。show_outcome()呼び出し時点のoutcomeをacknowledged受信まで保持する。
# acknowledgedシグナル自体は引数を持たないため、遷移先の分岐に必要な値をここに控える。
# 🔴 コードレビュー指摘対応で一度GameState.get_state()["last_exam_outcome"]
# （commit_exam_outcome()が設定する内部キャッシュ）参照に置き換えたが、多数の統合テストが
# GameState.exam_outcome_confirmed/AlchemyScreen.exam_result_pendingを直接emit()して
# commit_exam_outcome()自体を経由せずにこのフローを検証する確立されたパターンのため、
# その場合last_exam_outcomeが更新されず遷移が起きない回帰を起こした（18件のテスト失敗で発覚）。
# シグナル引数こそがこのタイミングでの正しい値であり、GameState内部キャッシュを
# 別途参照する必要はないと判断し元の設計へ戻した
var _pending_exam_outcome: ExamOutcome.Value = ExamOutcome.Value.CONTINUE

@onready var _garden_screen: GardenScreen = %GardenScreen  # 🔵
@onready var _alchemy_screen: AlchemyScreen = %AlchemyScreen  # 🔵
@onready var _workshop_screen: WorkshopScreen = %WorkshopScreen  # 🔵
@onready var _result_screen: ResultScreen = %ResultScreen  # 🔵
@onready var _garden_tab_button: Button = %GardenTabButton  # 🔵 FR-101
@onready var _alchemy_tab_button: Button = %AlchemyTabButton  # 🔵 FR-102
@onready var _rank_hud: RankHud = %RankHud  # 🔵 FR-103
# 🔵 4画面より後ろの子として配置しているため、描画順で常に最前面になる
@onready var _settings_overlay_layer: Control = %SettingsOverlayLayer  # 🔵 FR-103
# 🔴 debug-playtest-support Plan タスク003。SettingsOverlayLayerよりさらに後ろの子として
# 配置しているため、描画順で常に最前面になる（QA用パネルをPauseMenu表示中も操作可能にする）
@onready var _debug_panel: DebugPanel = %DebugPanel
# 🔵 タスク014（ui-polish Plan）。rank featureのUIをMainSceneが直接子として持つことで、
# AlchemyScreen（alchemy feature）とExamOutcomeOverlay（rank feature）間の直接参照を回避する
# （他Featureのui/への直接参照禁止、architecture.md参照）
@onready var _exam_outcome_overlay: ExamOutcomeOverlay = %ExamOutcomeOverlay


# 🔴 FR-006。ロードを_ready()ではなく_enter_tree()で行うのは、Godotが_ready()を子→親の順で
# 呼ぶため。_ready()でロードすると4画面の初期描画がマスターデータ未ロード状態で走り、
# ランク名・ノルマバー等がフォールバック値のまま固定される（実際にpush_errorも発生した）。
# _enter_tree()は親→子の順で呼ばれるため、子の_ready()時点でロード完了が保証される
func _enter_tree() -> void:
	GameState.load_garden_master_data()
	GameState.load_alchemy_master_data()
	GameState.load_workshop_master_data()
	GameState.load_rank_master_data()
	# 🔵 指定依頼の初回抽選は解禁レシピ・ランクの特性解禁状況に依存するため、
	# ランクマスターのロード後に呼ぶ（順序を入れ替えないこと）
	GameState.load_daily_order_master_data()
	# 🔵 スロット選択画面で保留されたセーブデータをここで適用する。マスターデータの
	# ロード完了後でなければならない（current_daily_order_id等のID→Resource解決に必要）。
	# また指定依頼はload_daily_order_master_data()内で毎回抽選し直されるため、
	# 復元は必ずその後に置くこと（前に置くと復元した指定依頼が抽選結果で上書きされる）。
	# 🔵 スロット未選択（テスト・BootSceneを経ない直接起動）では保留が空のため空振りする
	SaveService.apply_pending_restore()


func _ready() -> void:
	# 🔵 FR-103。購読は@onready変数が解決済みの_ready()で行う。_enter_tree()に置くと
	# 子の_ready()中にphase_changedが発行された場合、未解決の@onready変数へ触れてしまう
	GameState.phase_changed.connect(_on_phase_changed)

	_garden_tab_button.pressed.connect(_on_garden_tab_pressed)  # 🔵 FR-101
	_alchemy_tab_button.pressed.connect(_on_alchemy_tab_pressed)  # 🔵 FR-102
	# 🔵 FR-104, FR-105。いずれも同一シーンツリー内の子ノードのsignalのため、
	# ノード破棄時にGodotが自動切断する（_exit_tree()でのdisconnectは不要）
	_garden_screen.shop_requested.connect(_on_shop_requested)
	_alchemy_screen.shop_requested.connect(_on_shop_requested)
	_workshop_screen.screen_closed.connect(_on_workshop_closed)
	_alchemy_screen.delivery_confirmed.connect(_on_delivery_confirmed)  # 🔵 FR-106, FR-107
	# 🔵 タスク013（ui-polish Plan）。GameState.exam_outcome_confirmedを直接購読せず、
	# AlchemyScreenが中継するexam_result_pendingを購読する（delivery_confirmedと同型パターン）。
	# 同一シーンツリー内の子ノードのsignalのため、ノード破棄時にGodotが自動切断する
	# （_exit_tree()でのdisconnectは不要）
	_alchemy_screen.exam_result_pending.connect(_on_alchemy_exam_result_pending)
	# 🔵 タスク014。同一シーンツリー内の子ノードのsignalのため、ノード破棄時にGodotが
	# 自動切断する（_exit_tree()でのdisconnectは不要）
	_exam_outcome_overlay.acknowledged.connect(_on_exam_outcome_acknowledged)
	_rank_hud.menu_requested.connect(_on_menu_requested)  # 🔵 FR-103
	# 🔴 debug-playtest-support Plan タスク003。debug_jump_to_next_rank()はGameStateの内部
	# フィールドを直接書き換えるだけでシグナルを発行しないため、RankHudが追随しない。
	# 新規シグナルを増やさず、既存のButton.pressedとRankHud.refresh()の結線のみで解決する。
	# 同一シーンツリー内の子ノード同士のためGodotが破棄時に自動切断する（disconnect不要）
	_debug_panel.get_jump_rank_button().pressed.connect(_rank_hud.refresh)

	# 🔵 FR-108, FR-111〜FR-113。この3本の接続順（記述順）を変更しないこと。
	# commit_exam_outcome()はexam_outcome_confirmed→game_cleared/game_overの順に
	# 同一フレーム内で同期発行するため（game_state_rank_delegate.gd）。
	# 🔴 タスク014でexam_result_pending受信時の実遷移がacknowledged（プレイヤーの確認操作）まで
	# 遅延されるようになったため、「暫定遷移(workshop/garden) → resultで上書き確定」という
	# タスク013までの同一フレーム内完結の前提は成立しなくなった。GameState.game_cleared/game_over
	# 発行時点ではExamOutcomeOverlayが表示されているだけで、フェーズはまだ試験中のalchemyのまま
	# （_on_exam_started()の遷移が最後）であり、本ブロックの2本（game_cleared/game_over）が
	# resultへの実質的な唯一の遷移経路になる。_on_exam_outcome_acknowledged()側は
	# is_game_cleared()/is_game_over()で終局確定済みかを見て、resultをworkshop/gardenへ
	# 巻き戻さないようガードしている（詳細は_on_exam_outcome_acknowledged()のコメント参照）
	GameState.exam_started.connect(_on_exam_started)  # 🔵 FR-108, FR-201
	GameState.game_cleared.connect(_on_game_cleared)  # 🔵 FR-111, FR-113
	GameState.game_over.connect(_on_game_over)  # 🔵 FR-112, FR-113

	# 🔵 garden-alchemy-visual-refresh タスク010。タイトル画面（title_screen.gd）と同じパターンで
	# タブボタンにドット絵ボタンスタイル・フォントを適用する。新規アセットは生成しない
	_apply_tab_bar_style()

	# 🔵 FR-004。起動時点のcurrent_phaseに表示を合わせる。.tscn側の初期visibleに依存すると
	# 「シーンの初期値」と「GameStateの実際のフェーズ」が二重管理になるため、必ずここで揃える
	_apply_visible_phase(GameState.get_state()["current_phase"])
	# 🔴 コードレビュー指摘対応。SaveService.apply_pending_restore()はGameStateの
	# private fieldを直接書き換えるためphase_changedが発火せず、_on_phase_changed()経由の
	# タブ無効化（_set_tabs_disabled）が復帰しない。試験中/終局のセーブをロードした直後も
	# 庭⇔調合タブが操作可能なままになる（試験からの離脱防止が抜ける）のを防ぐため、
	# 起動時のタブ状態もGameStateの実際の状態から明示的に導出する
	_set_tabs_disabled(_should_tabs_be_disabled_on_load())


# 🔵 FR-005。GameStateはAutoloadで本ノードより寿命が長いため明示的なdisconnect()が必須。
# タブボタンは同一シーンツリー内の子のためGodotが自動切断する（disconnect不要）
func _exit_tree() -> void:
	if GameState.phase_changed.is_connected(_on_phase_changed):
		GameState.phase_changed.disconnect(_on_phase_changed)
	if GameState.exam_started.is_connected(_on_exam_started):
		GameState.exam_started.disconnect(_on_exam_started)
	if GameState.game_cleared.is_connected(_on_game_cleared):
		GameState.game_cleared.disconnect(_on_game_cleared)
	if GameState.game_over.is_connected(_on_game_over):
		GameState.game_over.disconnect(_on_game_over)


## 現在visible == trueの画面に対応するフェーズ名を返す。いずれも不可視ならPHASE_NONE。
## 🔵 テスト用の観測点。_apply_visible_phase()が設定したノードのvisibleを唯一の正とし、
## 別途フィールドにキャッシュしない（表示と内部状態の乖離を構造的に防ぐため）
func get_visible_phase() -> StringName:
	if _garden_screen.visible:
		return PHASE_GARDEN
	if _alchemy_screen.visible:
		return PHASE_ALCHEMY
	if _workshop_screen.visible:
		return PHASE_WORKSHOP
	if _result_screen.visible:
		return PHASE_RESULT
	return PHASE_NONE


## 庭タブが操作不能かを返す。🟡 テスト用ゲッター（disabledの実体はButtonノード側を唯一の正とする）
func get_is_garden_tab_disabled() -> bool:
	return _garden_tab_button.disabled


## 調合タブが操作不能かを返す。🟡 テスト用ゲッター
func get_is_alchemy_tab_disabled() -> bool:
	return _alchemy_tab_button.disabled


func _on_phase_changed(previous: StringName, next: StringName) -> void:  # 🔵 FR-103
	# 🔴 コードレビュー指摘対応。閉じるボタンを経ずタブバーで工房から離脱した場合も
	# 恒久投資購入枠を閉じる。close_workshop()は_can_purchase_permanentをfalseに戻すだけの
	# 冪等操作（workshop_screen.gd _on_close_pressed()のコメント参照）のため、
	# 閉じるボタン経由で既に呼ばれていても二重呼び出しに副作用はない
	if previous == PHASE_WORKSHOP and next != PHASE_WORKSHOP:
		GameState.close_workshop()
	_apply_visible_phase(next)
	# 🔴 コードレビュー指摘対応。_ready()の初回同期（_apply_visible_phase()の直接呼び出し）では
	# 対象画面が自身の_ready()で既に最新描画済みのため、ここでの呼び出しは実際のフェーズ遷移
	# （本ハンドラ経由）に限定する。_apply_visible_phase()側で呼ぶと初回表示のたび二重リフレッシュに
	# なり、1フレーム内でqueue_free()された旧エントリ行がscene_runnerのテスト終了時までに
	# 処理されずorphan node警告として検出されてしまう
	_refresh_visible_screen(next)


# 🔵 FR-101。disabled時もpressedがコード経由で発行されうる（Buttonのdisabledはマウス入力のみ
# 抑止する）ため、workshop_screen.gdの_on_permanent_tab_pressed()と同様にガードする
func _on_garden_tab_pressed() -> void:
	if _garden_tab_button.disabled:
		return
	GameState.set_phase(PHASE_GARDEN)


func _on_alchemy_tab_pressed() -> void:  # 🔵 FR-102。_on_garden_tab_pressed()と同型
	if _alchemy_tab_button.disabled:
		return
	GameState.set_phase(PHASE_ALCHEMY)


# 🔵 FR-104。工房を開く直前のフェーズを控えてから工房へ切り替える。
# 既に工房表示中の再要求では控えを更新しない（更新すると復帰先が工房自身になり、
# 閉じても工房から抜けられなくなるため）
func _on_shop_requested() -> void:
	var current: StringName = GameState.get_state()["current_phase"]
	if current != PHASE_WORKSHOP:
		_phase_before_workshop = current
	GameState.set_phase(PHASE_WORKSHOP)


# 🔵 FR-105。工房を開く直前のフェーズへ復帰する。shop_requestedを経ずに工房へ入った場合は
# 初期値である庭へ戻る（AC-004異常系）
func _on_workshop_closed() -> void:
	GameState.set_phase(_phase_before_workshop)


# 🔵 FR-106, FR-107。納品結果確認後は常に庭へ戻す。AlchemyScreenが自身の
# GuildDeliveryScreen（Guild Featureのシーン）を中継し発行するdelivery_confirmedのみを
# 購読するため、MainSceneはGuildDeliveryScreenの存在を意識しない（FR-402）
func _on_delivery_confirmed() -> void:
	GameState.set_phase(PHASE_GARDEN)


# 🟡 title-settings-screens-extension Plan。多重起動防止・生成・破棄後の参照クリアは
# PauseMenu.open_singleton()（shared/ui/pause_menu.gd）へ委譲する。
# フェーズ遷移もオートセーブも伴わないため、現在の画面表示・GameState・SaveServiceは無影響
# （タイトルへ戻る場合のみPauseMenu自身がシーン遷移を要求する）
func _on_menu_requested() -> void:
	_pause_menu = PauseMenu.open_singleton(
		_pause_menu, _settings_overlay_layer, _on_pause_menu_closed
	)


# 🟡 参照を手放し、次回のメニューボタン押下で再度開けるようにする
func _on_pause_menu_closed() -> void:
	_pause_menu = null


# 🔵 FR-108, FR-201。試験は調合画面で行うためalchemyへ切り替え、あわせてタブを操作不能にして
# 庭⇔調合の往復による試験からの離脱を防ぐ
func _on_exam_started() -> void:
	GameState.set_phase(PHASE_ALCHEMY)
	_set_tabs_disabled(true)


# 🔵 FR-109, FR-110, FR-201解除。成功なら工房（恒久投資）へ、失敗なら庭へ戻す。
# 🔵 タスク013。GameState.exam_outcome_confirmedを直接購読する代わりに、AlchemyScreenが
# 中継するexam_result_pendingを購読する（このシグナルはSUCCESS/FAILURE確定時のみ発行され、
# CONTINUEでは発行されないため、本ハンドラにCONTINUE分岐は不要）。
# 🔵 タスク014。画面遷移（GameState.set_phase()等）は即座に行わず、まずExamOutcomeOverlayで
# 結果演出を表示する。実際の遷移はプレイヤーがオーバーレイを確認した後（acknowledged）に行う
# （オーバーレイ表示中はタブも無効化されたままのため、庭⇔調合の切替でオーバーレイを回避できない）
func _on_alchemy_exam_result_pending(outcome: ExamOutcome.Value) -> void:
	_pending_exam_outcome = outcome
	_exam_outcome_overlay.show_outcome(outcome)


# 🔵 タスク014。ExamOutcomeOverlayの確認ボタン押下後に実際の画面遷移を行う。
# 🔴 FR-113との整合性についての重要な注意: GameState.commit_exam_outcome()は
# exam_outcome_confirmed → game_cleared/game_overを同一フレーム内で同期発行するため、
# 最終ランク成功／ゲームオーバー確定時は_on_alchemy_exam_result_pending()がオーバーレイを
# 表示した直後、同じフレーム内で_on_game_cleared()/_on_game_over()が先にresultへ確定させている。
# タスク013までは「暫定遷移→result上書き」が同一フレームで完結していたが、本タスクで
# 遷移そのものをacknowledged（プレイヤーの確認操作、任意の後続フレーム）まで遅延させたため、
# 終局確定後にオーバーレイを閉じてもresultをworkshop/gardenへ巻き戻さないよう明示的にガードする
func _on_exam_outcome_acknowledged() -> void:
	if GameState.is_game_cleared() or GameState.is_game_over():
		return
	match _pending_exam_outcome:
		ExamOutcome.Value.SUCCESS:
			GameState.set_phase(PHASE_WORKSHOP)
			_set_tabs_disabled(false)
		ExamOutcome.Value.FAILURE:
			GameState.set_phase(PHASE_GARDEN)
			_set_tabs_disabled(false)
		_:
			pass


# 🔵 FR-111, FR-113, FR-202, FR-403。終局のためresultへ遷移しタブを操作不能にする。
# MainScene側からresultを離脱させる経路は設けない（外部からのset_phase()は防がない）。
# 🔴 コードレビュー指摘対応。commit_exam_outcome()はexam_outcome_confirmed→game_cleared/game_overを
# 同一フレーム内で同期発行するため、最終ランク到達時は_on_alchemy_exam_result_pending()が
# ExamOutcomeOverlayを表示した直後、同じフレームで本ハンドラがresultへ確定させる。
# オーバーレイを閉じずにresultへ遷移すると、result構築後もオーバーレイが上に乗ったまま残り、
# プレイヤーは意味のない2回目の確認クリックを強いられるため、遷移前にforce_hide()で閉じる
func _on_game_cleared() -> void:
	_exam_outcome_overlay.force_hide()
	GameState.set_phase(PHASE_RESULT)
	_set_tabs_disabled(true)


# 🔵 FR-112, FR-113, FR-202, FR-403。_on_game_cleared()と同型（force_hide()呼び出しの理由も同じ）。
# demotion_countの表示はResultScreenの責務外（FR-404）のため本シーンでも使わない
func _on_game_over(_demotion_count: int) -> void:
	_exam_outcome_overlay.force_hide()
	GameState.set_phase(PHASE_RESULT)
	_set_tabs_disabled(true)


# 🔵 FR-201, FR-202。試験開始/終了と終局の双方から流用する
func _set_tabs_disabled(disabled: bool) -> void:
	_garden_tab_button.disabled = disabled
	_alchemy_tab_button.disabled = disabled


# 🔵 garden-alchemy-visual-refresh タスク010。title_screen.gd _apply_theme()と同じパターンで
# ButtonStyleApplierを適用する。新規アセットは生成せず既存のドット絵ボタンテクスチャを流用する。
# 🔴 コードレビュー指摘対応: 当初は両タブとも同一のButtonVariant.SECONDARYを適用し、選択中タブは
# toggle_modeのpressedステート（8%暗化のみ）で表現していたが、ドット絵テクスチャ上では
# 差が視認しづらいため、フォント適用のみをここで行い、バリアント自体の切り替えは
# _update_tab_selected_visual()に委ねる（選択中=PRIMARY/非選択=SECONDARYで明確な色差を出す）
func _apply_tab_bar_style() -> void:
	for button: Button in [_garden_tab_button, _alchemy_tab_button]:
		UiTheme.apply_pixel_font(button)


# 🟡 NFR-201。Buttonのtoggle_mode（button_pressed）とテーマのpressedステートスタイルを流用し、
# 現在フェーズと一致するタブのみを押下状態にする。_apply_visible_phase()と同じく比較結果を
# 直接代入するため、タブバー対象外のフェーズ（workshop/result）では両方が非選択になる。
# 🔴 コードレビュー指摘対応: 選択中/非選択の差をtoggle_modeの暗化だけに頼らず、
# ButtonVariant自体をPRIMARY（選択中）/SECONDARY（非選択）で切り替えて明確な色差を付ける
func _update_tab_selected_visual(phase: StringName) -> void:
	var garden_selected := phase == PHASE_GARDEN
	var alchemy_selected := phase == PHASE_ALCHEMY
	_garden_tab_button.button_pressed = garden_selected
	_alchemy_tab_button.button_pressed = alchemy_selected
	ButtonStyleApplier.apply_button_style(
		_garden_tab_button,
		UiTheme.ButtonVariant.PRIMARY if garden_selected else UiTheme.ButtonVariant.SECONDARY
	)
	ButtonStyleApplier.apply_button_style(
		_alchemy_tab_button,
		UiTheme.ButtonVariant.PRIMARY if alchemy_selected else UiTheme.ButtonVariant.SECONDARY
	)


# 🔵 FR-001, FR-004, FR-103。各画面のvisibleを「phaseと一致するか」の比較結果で直接上書きする。
# 真になりうるのは最大1つだけなので、排他性が分岐の書き漏らしに依存せず構造的に保証される。
# 未知フェーズの場合は全画面が不可視となり、直前の画面が残り続けることもない（AC-001異常系）
func _apply_visible_phase(phase: StringName) -> void:
	if not _is_known_phase(phase):
		push_warning("未知のフェーズのため全画面を非表示にします: %s" % phase)

	_garden_screen.visible = phase == PHASE_GARDEN
	_alchemy_screen.visible = phase == PHASE_ALCHEMY
	_workshop_screen.visible = phase == PHASE_WORKSHOP
	_result_screen.visible = phase == PHASE_RESULT

	_update_tab_selected_visual(phase)


# 🔴 コードレビュー指摘対応。4画面は常駐+visible切替のため、各画面の_ready()一度きりの
# 表示構築だけでは他画面での操作（庭の収穫、工房での購入等）が可視化のタイミングで反映されない。
# 可視化するたびに対象画面のrefresh()を呼び、GameStateの最新値で再構築する
func _refresh_visible_screen(phase: StringName) -> void:
	match phase:
		PHASE_GARDEN:
			_garden_screen.refresh()
		PHASE_ALCHEMY:
			_alchemy_screen.refresh()
		PHASE_WORKSHOP:
			_workshop_screen.refresh()
			# 🔵 タスク017（ui-polish Plan）。visible=trueは_apply_visible_phase()側で
			# 設定済みのため、ここではフェードインの開始のみを担う
			_workshop_screen.play_show_animation()
		_:
			pass


func _is_known_phase(phase: StringName) -> bool:
	match phase:
		PHASE_GARDEN, PHASE_ALCHEMY, PHASE_WORKSHOP, PHASE_RESULT:
			return true
		_:
			return false


# 🔴 コードレビュー指摘対応。起動直後（ロード直後を含む）のタブ無効化状態を、
# シグナル発火に頼らずGameStateの現在値から直接導出する。判定基準は既存の
# タブ無効化トリガ（_on_exam_started/_on_alchemy_exam_result_pending/_on_game_cleared/
# _on_game_over）と同じ条件（試験中、または終局でresultへ遷移済み）に揃える
func _should_tabs_be_disabled_on_load() -> bool:
	var state := GameState.get_state()
	return bool(state["in_exam"]) or state["current_phase"] == PHASE_RESULT
