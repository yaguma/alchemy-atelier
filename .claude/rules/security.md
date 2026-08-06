# セキュリティルール

> 🔴 2026-08-06改訂: 技術スタックがGodot 4.x + GDScriptに確定済み（`CLAUDE.md`参照）のため、Web前提（localStorage/XSS/.env等）の記述をGodotのオフライン単体デスクトップアプリという文脈に合わせて調整した。本ゲームはオフライン・シングルプレイでネットワーク通信を行わないため、Web版で重要だった項目の多くは**現状該当性が低い**。将来オンライン機能（ランキング等）やセーブ/ロード機能（現行スコープ外、`CLAUDE.md`参照）を追加する場合に備えて指針を残す。

## 基本原則

- すべての外部入力を検証
- 最小権限の原則に従う
- セキュリティは後付けではなく設計段階から考慮

---

## セーブデータの検証（🟡将来のセーブ/ロード機能追加時に適用。現行スコープ外）

セーブ/ロード機能は現時点で設計スコープ外（`CLAUDE.md`参照）だが、将来追加する場合は以下の方針を踏襲する。Godotでは`user://`ディレクトリへの`FileAccess`書き込みがブラウザの`localStorage`に相当する。

```gdscript
# セーブデータ読み込み時は必ず検証する
func load_save_data() -> Dictionary:
	if not FileAccess.file_exists("user://save_data.json"):
		return {}

	var file := FileAccess.open("user://save_data.json", FileAccess.READ)
	var raw := file.get_as_text()
	var json := JSON.new()
	if json.parse(raw) != OK:
		push_warning("Failed to parse save data")
		return {}

	var data: Variant = json.data
	if not _is_valid_save_data(data):
		push_warning("Invalid save data format")
		return {}
	return data

# 型ガードで検証する
func _is_valid_save_data(data: Variant) -> bool:
	if not (data is Dictionary):
		return false
	var d: Dictionary = data
	return (
		d.get("version") is int
		and d.get("gold") is int
		and d.gold >= 0
		and d.get("inventory") is Array
	)
```

---

## 入力検証

### ユーザー入力（プレイヤー名等、将来追加する場合）

```gdscript
# 名前入力の例
func validate_player_name(name: String) -> String:
	# 長さチェック
	if name.length() < 1 or name.length() > 20:
		return ""

	# 危険な文字を除去（GDScriptではDOM挿入がないためXSS目的の除去は不要だが、
	# 保存データの破損防止・表示崩れ防止のため制御文字は除去する）
	var sanitized := name.strip_edges()

	if sanitized.is_empty():
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

func validate_game_state(state: Dictionary) -> bool:
	# ゴールドが負になっていないか
	if state.gold < 0:
		return false

	# 所持アイテム数が上限を超えていないか
	if state.inventory.size() > GameBalance.MAX_INVENTORY_SIZE:
		return false

	# ランクが正しい範囲か
	if not GameBalance.VALID_RANKS.has(state.current_rank):
		return false

	return true
```

### セーブデータの改ざん検出（🟡将来のセーブ/ロード機能追加時に適用）

```gdscript
# 簡易チェックサム
func calculate_checksum(data: Dictionary) -> String:
	var json_string := JSON.stringify(data)
	return json_string.sha256_text()

# 保存時
func save(data: Dictionary) -> void:
	var checksum := calculate_checksum(data)
	var file := FileAccess.open("user://save_data.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"data": data, "checksum": checksum}))

# 読み込み時
func load_and_verify() -> Dictionary:
	var loaded := load_save_data()
	if loaded.is_empty():
		return {}
	if calculate_checksum(loaded.data) != loaded.checksum:
		push_warning("Save data may be corrupted")
		return {}
	return loaded.data
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
