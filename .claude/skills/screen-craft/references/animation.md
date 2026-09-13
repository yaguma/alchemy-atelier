# アニメーション手法リファレンス

3つの技法をトリガー別に使い分ける。すべて`.claude/rules/ui-components.md`・
`.claude/rules/performance.md`のルール（不要な`_process()`を書かない、Tween/Timerの停止漏れ禁止）に従う。

## Tween（主力）

数値・プロパティの補間全般。カードの動き、バーの増減、フェード、ボタンのバウンス、モーダルの開閉。
`create_tween()`はノードにアタッチされ、そのノードの破棄時に自動停止するので、同一ノード内で完結する
Tweenに`_exit_tree()`での`kill()`は不要（ノードを跨いで使い回す場合のみ明示的に停止する）。

```gdscript
# フェードイン
func fade_in() -> void:
	modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.3).set_ease(Tween.EASE_OUT)

# 数値のカウントアップ演出（ゴールド増加等）。ラベルのテキストを毎フレーム書き換えるより
# tween_method()で中間値を渡す方がイージングと一貫する
func _animate_gold_count(from_value: int, to_value: int) -> void:
	var tween := create_tween()
	tween.tween_method(_update_gold_label, from_value, to_value, 0.4)

func _update_gold_label(value: float) -> void:
	_gold_label.text = "%d G" % roundi(value)

# 完了を待ってから次の処理へ進みたい場合
func show_result_async() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.3)
	await tween.finished
```

ボタンのホバー/押下フィードバックは`godot-best-practices.md`のパターンをそのまま使う（`scale`を
`Vector2(1.05, 1.05)`程度に一瞬拡大するだけで十分な「押した感」が出る）。

## スプライトシート（`AnimatedSprite2D`）

現状このプロジェクトでは1件も使われていない。決まった状態を繰り返す見た目変化（歩行・攻撃・被弾の
ような反復モーション）が要る場合のみ検討する。素材アイコンの「輝いている」ような単純な明滅は
`SpriteFrames`を用意するよりTweenで`modulate`を往復させる方が軽量で済むことが多いので、まず
Tweenで足りないか考えてから導入する。

```gdscript
@onready var _sprite: AnimatedSprite2D = %Sprite

func play_state(state_name: StringName) -> void:
	_sprite.play(state_name)  # SpriteFrames側にstate_nameのアニメーションを事前登録しておく
```

## パーティクル（`GPUParticles2D`）

一瞬だけ強調したいエフェクト専用。調合成功のきらめき、収穫の飛び散り、昇格演出など「結果が出た
瞬間」に使う。常時再生し続けるアンビエントな演出は必要になった時に個別検討する（過剰な常時演出は
`.claude/rules/design-guide.md`の「明瞭さ」方針と衝突しやすい）。

```gdscript
@onready var _success_particles: GPUParticles2D = %SuccessParticles

func play_success_effect() -> void:
	_success_particles.restart()
	_success_particles.emitting = true
```

`one_shot = true`・`emitting`をfalseで初期化しておき、演出のタイミングだけ`restart()`する構成が
扱いやすい。

## 判断フローまとめ

1. 繰り返す状態変化か？ → スプライトシート
2. 数値・プロパティが滑らかに変わるだけか？ → Tween（迷ったらまずこれ）
3. 一瞬だけ結果を強調したいか？ → パーティクル

同じ演出に複数の技法を組み合わせてよい（例: 調合成功時は素材が投入枠に飛ぶ動き＝Tween、
成功の瞬間だけ＝パーティクル、を同時に鳴らす）。
