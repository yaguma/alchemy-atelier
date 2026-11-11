"""実行中ゲームで``game_eval``させるGDScriptの断片。

get_ui_elementsは矩形とテキストしか返さないため、親がContainerか・祖先で切り取られるか・
背景を描くノードがあるか、といった判定材料はここでGDScriptを実行して集める。
判定そのものはchecks.py（Python側）で行い、ここでは値を集めるだけにする。
"""

from __future__ import annotations

import json

# 表示中の全Controlについて、矩形と判定に必要な属性を集める。
LAYOUT_SNAPSHOT = """
var vp := get_tree().root.get_visible_rect()
var scene := get_tree().current_scene
var nodes: Array = [scene]
nodes.append_array(scene.find_children("*", "Control", true, false))
var out := []
for n in nodes:
	if not (n is Control) or not (n as Control).is_visible_in_tree():
		continue
	var c := n as Control
	var parent := c.get_parent()
	var clipped := false
	var p: Node = parent
	while p != null:
		if p is ScrollContainer or (p is Control and (p as Control).clip_contents):
			clipped = true
			break
		p = p.get_parent()
	var has_children := false
	for ch in c.get_children():
		if ch is Control and (ch as Control).visible:
			has_children = true
			break
	var r := c.get_global_rect()
	out.append({
		"path": str(c.get_path()),
		"type": c.get_class(),
		"rect": [r.position.x, r.position.y, r.size.x, r.size.y],
		"parent_is_container": parent is Container,
		"clipped": clipped,
		"has_visible_children": has_children,
	})
return {"viewport": [vp.position.x, vp.position.y, vp.size.x, vp.size.y], "controls": out}
"""

_BACKDROP_PROBE_TEMPLATE = """
var draws_bg := func(c: Control) -> bool:
	if c is ColorRect:
		return (c as ColorRect).color.a > 0.0
	if c is TextureRect:
		return (c as TextureRect).texture != null
	if c is NinePatchRect:
		return (c as NinePatchRect).texture != null
	if c is Panel or c is PanelContainer:
		var sb := c.get_theme_stylebox("panel")
		if sb == null or sb is StyleBoxEmpty:
			return false
		if sb is StyleBoxFlat:
			return (sb as StyleBoxFlat).draw_center and (sb as StyleBoxFlat).bg_color.a > 0.0
		if sb is StyleBoxTexture:
			return (sb as StyleBoxTexture).texture != null
		return true
	return false
var target := get_tree().current_scene.find_child(__TARGET__, true, false) as Control
if target == null or not target.is_visible_in_tree():
	return {"found": false}
var tr := target.get_global_rect()
var covering := []
if draws_bg.call(target):
	covering.append(str(target.get_path()))
var node: Node = target
while node != null and node != get_tree().root:
	var parent := node.get_parent()
	if parent is Control and (parent as Control).is_visible_in_tree():
		if draws_bg.call(parent) and (parent as Control).get_global_rect().encloses(tr):
			covering.append(str(parent.get_path()))
	if parent != null:
		for sib in parent.get_children():
			if sib == node:
				break
			if sib is Control and (sib as Control).is_visible_in_tree() and draws_bg.call(sib):
				if (sib as Control).get_global_rect().encloses(tr):
					covering.append(str(sib.get_path()))
	node = parent
return {"found": true, "rect": [tr.position.x, tr.position.y, tr.size.x, tr.size.y], "covering": covering}
"""


def backdrop_probe(target_name: str) -> str:
    """現在のシーンで名前がtarget_nameのControlの背後に、背景を描くノードがあるかを調べる。

    target自身・祖先・祖先の手前（先に描かれる）兄弟のうち、背景を描き、かつtargetの矩形を
    丸ごと覆うものを``covering``として返す。パスではなく名前で探すのは、背景を足す修正で
    親子関係が変わっても（#89ではTabBarをTabBarPanelで包んだ）同じ判定を使えるようにするため。
    """
    return _BACKDROP_PROBE_TEMPLATE.replace("__TARGET__", json.dumps(target_name))


def discard_new_slot_probe(slot: int) -> str:
    """E2Eが空きスロットに作ったセーブを片付ける。

    以後のオートセーブを止め（active_slotを未選択に戻す）、slotのセーブファイルを削除する。
    呼び出し側は、slotがE2E開始前は空き（新規開始）だったことを確認済みであること。
    ユーザーのセーブデータを壊さないよう、それ以外のスロットには触れない。
    """
    return f"""
SaveService.active_slot = -1
var path := SaveService._slot_path({int(slot)})
if not FileAccess.file_exists(path):
	return {{"removed": false, "error": OK}}
return {{"removed": true, "error": DirAccess.remove_absolute(path)}}
"""


CURRENT_SCENE_AND_PHASE = """
var scene := get_tree().current_scene
var phase := ""
if scene != null and scene.name == "Main":
	phase = str(GameState.get_state().get("current_phase"))
return {"scene": "" if scene == null else str(scene.name), "phase": phase}
"""
