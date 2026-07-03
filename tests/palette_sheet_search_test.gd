# EventForge — the command palette's `#` sheet-search mode. EventSheetCommandPalette
# .filter_sheets fuzzily matches project sheet paths by file name (prefix > substring > subsequence),
# best first, so Ctrl+P # jumps to any sheet in the project. Pins the match/rank without a live window.
@tool
class_name PaletteSheetSearchTest
extends RefCounted


static func _paths() -> PackedStringArray:
	return PackedStringArray(["res://a/player.gd", "res://b/enemy.tres", "res://c/player_ui.gd"])


static func run() -> bool:
	var ok: bool = true
	var sheet_paths: PackedStringArray = _paths()

	var matches: Array = EventSheetCommandPalette.filter_sheets(sheet_paths, "player")
	ok = _check("'player' matches both player sheets", matches.size(), 2) and ok
	ok = _check("best match is player.gd (prefix, name-sorted)", _title(matches, 0), "player.gd") and ok
	ok = _check("title is the file name", _title(matches, 0), "player.gd") and ok
	ok = _check("path is preserved for opening", str(matches[0]["path"]) if matches.size() > 0 else "", "res://a/player.gd") and ok
	ok = _check("enemy excluded from a 'player' query", _has(matches, "enemy.tres"), false) and ok

	var all: Array = EventSheetCommandPalette.filter_sheets(sheet_paths, "")
	ok = _check("empty query returns all, name-sorted", "%s,%s,%s" % [_title(all, 0), _title(all, 1), _title(all, 2)], "enemy.tres,player.gd,player_ui.gd") and ok

	var sub: Array = EventSheetCommandPalette.filter_sheets(sheet_paths, "enmy")
	ok = _check("subsequence 'enmy' finds enemy.tres", _has(sub, "enemy.tres"), true) and ok

	ok = _check("a no-match query returns nothing", EventSheetCommandPalette.filter_sheets(sheet_paths, "zzz").size(), 0) and ok

	return ok


static func _title(matches: Array, index: int) -> String:
	return str((matches[index] as Dictionary).get("title", "")) if index < matches.size() else "(none)"


static func _has(matches: Array, title: String) -> bool:
	for entry: Dictionary in matches:
		if str(entry.get("title", "")) == title:
			return true
	return false


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] palette_sheet_search_test: %s" % label)
		return true
	print("[FAIL] palette_sheet_search_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
