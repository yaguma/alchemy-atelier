# 🔵 設定画面で変更できる値のランタイム状態。SettingsServiceが保持し、UIは読み取り・更新のみ行う。
# new()の初期値がそのまま「設定ファイルが無い／壊れている場合のデフォルト値」を兼ねる。
class_name SettingsData
extends RefCounted

## 0.0〜1.0。デフォルトは100%
var bgm_volume: float = 1.0
## 0.0〜1.0。デフォルトは100%
var se_volume: float = 1.0
## DisplayServer.WindowMode。デフォルトはウィンドウモード
var window_mode: int = DisplayServer.WINDOW_MODE_WINDOWED
## trueなら演出を簡略化する。デフォルトOFF
var reduced_effects: bool = false
