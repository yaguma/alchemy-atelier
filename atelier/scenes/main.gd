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

@onready var _garden_screen: GardenScreen = %GardenScreen  # 🔵
@onready var _alchemy_screen: AlchemyScreen = %AlchemyScreen  # 🔵
@onready var _workshop_screen: WorkshopScreen = %WorkshopScreen  # 🔵
@onready var _result_screen: ResultScreen = %ResultScreen  # 🔵
@onready var _garden_tab_button: Button = %GardenTabButton  # 🔵 FR-101
@onready var _alchemy_tab_button: Button = %AlchemyTabButton  # 🔵 FR-102


# 🔴 FR-006。ロードを_ready()ではなく_enter_tree()で行うのは、Godotが_ready()を子→親の順で
# 呼ぶため。_ready()でロードすると4画面の初期描画がマスターデータ未ロード状態で走り、
# ランク名・ノルマバー等がフォールバック値のまま固定される（実際にpush_errorも発生した）。
# _enter_tree()は親→子の順で呼ばれるため、子の_ready()時点でロード完了が保証される
func _enter_tree() -> void:
	GameState.load_garden_master_data()
	GameState.load_alchemy_master_data()
	GameState.load_workshop_master_data()
	GameState.load_rank_master_data()


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

	# 🔵 FR-108〜FR-113。この4本の接続順（記述順）を変更しないこと。
	# commit_exam_outcome()はexam_outcome_confirmed→game_cleared/game_overの順に
	# 同一フレーム内で同期発行するため（game_state_rank_delegate.gd）、
	# 「暫定遷移(workshop/garden) → resultで上書き確定」がこの順序に依存して成立する。
	# 接続順を入れ替えても発行順自体は変わらないが、実行される順序を読み違えないよう
	# 発行順と同じ並びを保つ
	GameState.exam_started.connect(_on_exam_started)  # 🔵 FR-108, FR-201
	GameState.exam_outcome_confirmed.connect(_on_exam_outcome_confirmed)  # 🔵 FR-109, FR-110
	GameState.game_cleared.connect(_on_game_cleared)  # 🔵 FR-111, FR-113
	GameState.game_over.connect(_on_game_over)  # 🔵 FR-112, FR-113

	# 🔵 FR-004。起動時点のcurrent_phaseに表示を合わせる。.tscn側の初期visibleに依存すると
	# 「シーンの初期値」と「GameStateの実際のフェーズ」が二重管理になるため、必ずここで揃える
	_apply_visible_phase(GameState.get_state()["current_phase"])


# 🔵 FR-005。GameStateはAutoloadで本ノードより寿命が長いため明示的なdisconnect()が必須。
# タブボタンは同一シーンツリー内の子のためGodotが自動切断する（disconnect不要）
func _exit_tree() -> void:
	if GameState.phase_changed.is_connected(_on_phase_changed):
		GameState.phase_changed.disconnect(_on_phase_changed)
	if GameState.exam_started.is_connected(_on_exam_started):
		GameState.exam_started.disconnect(_on_exam_started)
	if GameState.exam_outcome_confirmed.is_connected(_on_exam_outcome_confirmed):
		GameState.exam_outcome_confirmed.disconnect(_on_exam_outcome_confirmed)
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


func _on_phase_changed(_previous: StringName, next: StringName) -> void:  # 🔵 FR-103
	_apply_visible_phase(next)


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


# 🔵 FR-108, FR-201。試験は調合画面で行うためalchemyへ切り替え、あわせてタブを操作不能にして
# 庭⇔調合の往復による試験からの離脱を防ぐ
func _on_exam_started() -> void:
	GameState.set_phase(PHASE_ALCHEMY)
	_set_tabs_disabled(true)


# 🔵 FR-109, FR-110, FR-201解除。成功なら工房（恒久投資）へ、失敗なら庭へ戻す。
# CONTINUEは「試験がまだ続いている」ことを表すためフェーズもタブ状態も変えない
# （alchemy_screen.gdの_on_exam_outcome_confirmed()と同じ分岐方針）。
# 🔴 ここでの遷移は最終ランク成功／ゲームオーバー確定時には暫定値にすぎず、
# 直後に同一フレームで発行されるgame_cleared/game_overがresultへ上書きする（FR-113）
func _on_exam_outcome_confirmed(outcome: ExamOutcome.Value) -> void:
	match outcome:
		ExamOutcome.Value.SUCCESS:
			GameState.set_phase(PHASE_WORKSHOP)
			_set_tabs_disabled(false)
		ExamOutcome.Value.FAILURE:
			GameState.set_phase(PHASE_GARDEN)
			_set_tabs_disabled(false)
		_:
			pass


# 🔵 FR-111, FR-113, FR-202, FR-403。終局のためresultへ遷移しタブを操作不能にする。
# MainScene側からresultを離脱させる経路は設けない（外部からのset_phase()は防がない）
func _on_game_cleared() -> void:
	GameState.set_phase(PHASE_RESULT)
	_set_tabs_disabled(true)


# 🔵 FR-112, FR-113, FR-202, FR-403。_on_game_cleared()と同型。
# demotion_countの表示はResultScreenの責務外（FR-404）のため本シーンでも使わない
func _on_game_over(_demotion_count: int) -> void:
	GameState.set_phase(PHASE_RESULT)
	_set_tabs_disabled(true)


# 🔵 FR-201, FR-202。試験開始/終了と終局の双方から流用する
func _set_tabs_disabled(disabled: bool) -> void:
	_garden_tab_button.disabled = disabled
	_alchemy_tab_button.disabled = disabled


# 🟡 NFR-201。Buttonのtoggle_mode（button_pressed）とテーマのpressedステートスタイルを流用し、
# 現在フェーズと一致するタブのみを押下状態にする。_apply_visible_phase()と同じく比較結果を
# 直接代入するため、タブバー対象外のフェーズ（workshop/result）では両方が非選択になる
func _update_tab_selected_visual(phase: StringName) -> void:
	_garden_tab_button.button_pressed = phase == PHASE_GARDEN
	_alchemy_tab_button.button_pressed = phase == PHASE_ALCHEMY


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


func _is_known_phase(phase: StringName) -> bool:
	match phase:
		PHASE_GARDEN, PHASE_ALCHEMY, PHASE_WORKSHOP, PHASE_RESULT:
			return true
		_:
			return false
