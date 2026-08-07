# セキュリティルール

> 🔴 2026-08-06改訂: 技術スタックがGodot 4.x + GDScriptに確定済み（`CLAUDE.md`参照）のため、Web前提（localStorage/XSS/.env等）の記述をGodotのオフライン単体デスクトップアプリという文脈に合わせて調整した。本ゲームはオフライン・シングルプレイでネットワーク通信を行わないため、Web版で重要だった項目の多くは**現状該当性が低い**。将来オンライン機能（ランキング等）やセーブ/ロード機能（現行スコープ外、`CLAUDE.md`参照）を追加する場合に備えて指針を残す。

## 基本原則

- すべての外部入力を検証
- 最小権限の原則に従う
- セキュリティは後付けではなく設計段階から考慮

---

## セーブデータの検証（🟡将来のセーブ/ロード機能追加時に適用。現行スコープ外）

セーブ/ロード機能は現時点で設計スコープ外（`CLAUDE.md`参照）だが、将来追加する場合は以下の方針を踏襲する。Godotでは`user://`ディレクトリへの`FileAccess`書き込みがブラウザの`localStorage`に相当する。保存ファイルは破損検出用チェックサムを含めた`{"data": {...}, "checksum": "..."}`形式で書き込み、読み込み時はチェックサム照合と型検証の両方を行う（チェックサム計算自体は後述「セーブデータの破損検出」の`calculate_checksum()`を参照）。

```gdscript
# セーブデータ読み込み時は必ず検証する
func load_save_data() -> Dictionary:
	if not FileAccess.file_exists("user://save_data.json"):
		return {}

	var file := FileAccess.open("user://save_data.json", FileAccess.READ)
	if file == null:
		push_warning("Failed to open save data: %s" % error_string(FileAccess.get_open_error()))
		return {}

	var raw := file.get_as_text()
	var json := JSON.new()
	if json.parse(raw) != OK:
		push_warning("Failed to parse save data")
		return {}

	var parsed: Variant = json.data
	if not (parsed is Dictionary):
		push_warning("Invalid save data format")
		return {}
	var wrapper: Dictionary = parsed
	var payload: Variant = wrapper.get("data")

	if not _is_valid_save_data(payload):
		push_warning("Invalid save data format")
		return {}
	if calculate_checksum(payload) != wrapper.get("checksum"):
		push_warning("Save data may be corrupted")
		return {}
	return payload

# 型ガードで検証する（GodotのJSONパーサは数値を常にfloatとして返すため、int/floatの両方を許容する）
func _is_valid_save_data(data: Variant) -> bool:
	if not (data is Dictionary):
		return false
	var d: Dictionary = data
	var version: Variant = d.get("version")
	var gold: Variant = d.get("gold")
	return (
		(version is int or version is float)
		and (gold is int or gold is float)
		and float(gold) >= 0
		and d.get("inventory") is Array
	)
```

---

## 入力検証

### ユーザー入力（プレイヤー名等、将来追加する場合）

```gdscript
# 名前入力の例
func validate_player_name(name: String) -> String:
	# 危険な文字を除去（GDScriptではDOM挿入がないためXSS目的の除去は不要だが、
	# 保存データの破損防止・表示崩れ防止のため前後の空白と制御文字を除去する）
	# 長さチェックより先に行う（末尾の空白・制御文字だけで拒否されるのを防ぐため）
	var sanitized := name.strip_edges().strip_escapes()

	# 長さチェック（サニタイズ後の実効文字数で判定）
	if sanitized.length() < 1 or sanitized.length() > 20:
		return ""

	return sanitized
```

### 数値入力

```gdscript
# 数値の範囲チェック
func validate_quantity(value: Variant) -> int:
	if not (value is int or value is float):
		return 1  # デフォルト値
	var num: int = int(value)
	return clampi(num, 1, 99)  # 1-99の範囲に制限
```

---

## 機密情報の管理

本ゲームは現状、外部API通信・認証を持たないオフライン単体アプリのため、この節の該当性は低い。将来オンライン機能（ランキング送信等）を追加する場合に適用する。

### 禁止事項

- APIキー、パスワードをコード・`project.godot`にハードコードしない
- 機密情報を含む設定ファイルをコミットしない
- ログに機密情報を出力しない
- エラーメッセージでシステム内部情報を露出しない

```gdscript
# NG
const API_KEY := "sk-1234567890abcdef"
print("User password: ", password)

# OK（将来オンライン機能を追加する場合）
var api_key := OS.get_environment("ATELIER_API_KEY")
print("Login attempt for user: ", username)
```

---

## ゲーム固有のセキュリティ

### チート対策の考え方

ローカル単体ゲームでは完全なチート対策は不可能だが、以下を意識する。

```gdscript
# 重要な計算はGameState/Domain層の一貫した経路のみで行う
# （UIから直接値を書き換えられる経路を作らない。state-management.md参照）

# 壊れた/改ざんされた状態を検証する関数自身が、壊れた入力でクラッシュしないよう
# キーアクセスは必ずget()＋型ガードを経由する（_is_valid_save_data()と同じ形に揃える）
func validate_game_state(state: Dictionary) -> bool:
	var gold: Variant = state.get("gold")
	if not (gold is int or gold is float) or float(gold) < 0:
		return false

	var inventory: Variant = state.get("inventory")
	if not (inventory is Array) or (inventory as Array).size() > GameBalance.MAX_INVENTORY_SIZE:
		return false

	return GameBalance.VALID_RANKS.has(state.get("current_rank"))
```

### セーブデータの破損検出（🟡将来のセーブ/ロード機能追加時に適用）

> 🔴 ここで言う「検出」は**偶発的な破損**（ディスクエラー・書き込み中断等）のみを対象とする。`calculate_checksum()`は秘密鍵を持たない素のSHA-256で、チェックサム自体もファイル内に平文で同梱されるため、セーブファイルを書き換えたい者が`data`を編集して`checksum`を再計算するだけで通過してしまい、**意図的な改ざんは一切検出できない**。ローカル単体ゲームである以上これは許容する（改ざん防止には`HMAC`+ビルド埋め込み鍵が必要だが、鍵ごと逆アセンブルされうるため本プロジェクトでは採用しない）。

チェックサムの計算と、それを使った照合はすでに前述「セーブデータの検証」の`load_save_data()`に組み込み済み。ここでは保存時の対となる処理のみを示す。

```gdscript
# 簡易チェックサム（load_save_data()の照合と対になる）
func calculate_checksum(data: Dictionary) -> String:
	var json_string := JSON.stringify(data)
	return json_string.sha256_text()

# 保存時
func save(data: Dictionary) -> void:
	var checksum := calculate_checksum(data)
	var file := FileAccess.open("user://save_data.json", FileAccess.WRITE)
	if file == null:
		push_error("Failed to open save data for writing: %s" % error_string(FileAccess.get_open_error()))
		return
	file.store_string(JSON.stringify({"data": data, "checksum": checksum}))
```

---

## 依存関係（アドオン）

Godotには`pnpm audit`に相当する標準の脆弱性監査ツールはない。アドオン（`addons/`配下、AssetLib経由で導入するもの）追加時は以下を手動確認する。

### 新規アドオン追加時の確認

- ライセンス確認（MIT, Apache 2.0等）
- メンテナンス状況（最終更新日、Godotバージョン対応状況）
- ソースの信頼性（公式AssetLib掲載か、GitHubスター数・Issue対応状況）
- 実行時に外部通信を行わないか（オフライン単体アプリの前提を崩さないか）

---

## エラーハンドリング

### 情報漏洩防止

```gdscript
# NG: スタックトレース相当の内部情報をユーザーに表示
func _on_error(error: String) -> void:
	show_message(error)  # 内部パス等を含む詳細エラーをそのまま表示

# OK: ユーザーには一般的なメッセージ、詳細はログのみ
func _on_error(error: String) -> void:
	push_error("Internal error: " + error)
	show_message("エラーが発生しました。")
```

---

## 禁止事項

- `Expression.execute()`等による未検証の動的コード評価（ユーザー入力を式として実行しない）
- 実行時の動的スクリプトロード（`load()`/`ResourceLoader.load()`に外部由来の未検証パスを渡さない）
- ネットワーク機能を追加する場合の、信頼できないURLへの`OS.shell_open()`等でのリダイレクト
- 検証なしでのセーブデータ・外部入力の使用
