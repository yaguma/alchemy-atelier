class_name ForwardingControl
extends Control

## 🔴 コードレビュー指摘対応（PR #62）。素のControlのget_minimum_size()は常に(0,0)を返し、
## 子の内容を自動集計しない（Container系ノードだけが行う特別な機能）。「実コンテンツを持つ
## Container（PanelContainer/VBoxContainer等）を丸ごと包むだけのControlラッパー」を親の
## Container（GridContainer/VBoxContainer等）へ配置すると、親は(0,0)を採用して行を0高さに
## 潰してしまい、内部の実コンテンツだけが表示上あふれ出て次の行と重なって描画される不具合が
## PlantSlotView/SeedInventoryList/AlchemyPreviewPanel/MaterialInventoryList/UpgradeItemList/
## GuildDeliveryScreenの6箇所で個別に見つかり修正された。本クラスはその共通対応を1箇所に集約する。
##
## 使い方: ラッパーのクラス宣言を `extends Control` から `extends ForwardingControl` に変え、
## _ready()内（@onready変数の解決後）で _bind_minimum_size_forward([対象ノード, ...]) を呼ぶ。
## 対象が複数ある場合（例: 通常リストと空状態ラベルのどちらか大きい方を報告したい）は
## 配列に複数渡すと各軸の最大値を報告する。
##
## 🔴 単に_get_minimum_size()を転送するだけでは不十分だった点に注意: 対象ノードの内容が
## setup()の再呼び出し等でノードをツリーから外さずに変化した場合（例: 調合中に素材を
## 投入/取り消しして在庫件数が変わる）、対象のCombinedMinimumSizeは変化していても、
## 誰もラッパー自身のupdate_minimum_size()を呼ばないため、ラッパーを子として持つ親
## Containerへ再レイアウトの通知が届かず、古いサイズのまま次第にズレていく。
## 対象のminimum_size_changedシグナルを購読しupdate_minimum_size()を呼ぶことで、
## 表示中の内容変更にも追従してラッパー自身の再レイアウトを親へ伝播させる。

var _forward_targets: Array[Control] = []


func _bind_minimum_size_forward(targets: Array[Control]) -> void:
	_forward_targets = targets
	for target in _forward_targets:
		if target == null:
			continue
		if not target.minimum_size_changed.is_connected(_on_forward_target_minimum_size_changed):
			target.minimum_size_changed.connect(_on_forward_target_minimum_size_changed)


func _get_minimum_size() -> Vector2:
	var result := Vector2.ZERO
	for target in _forward_targets:
		if target == null:
			continue
		var target_min := target.get_combined_minimum_size()
		result.x = maxf(result.x, target_min.x)
		result.y = maxf(result.y, target_min.y)
	return result


func _on_forward_target_minimum_size_changed() -> void:
	update_minimum_size()
