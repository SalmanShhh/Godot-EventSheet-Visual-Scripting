# EventForge — the quote-aware quick-add tokenizer (spec §12.2's hard gate for the Ghost Row).
# EventSheetAuthorActions.tokenize_quick_params splits trailing parameter text positionally but keeps a
# `"`-quoted run as ONE token (quotes included — param values are raw GDScript expressions). The naive
# split(" ") mis-filled `play "jump land"` as two params. Pins the tokenizer + the _quick_match e2e.
@tool
extends RefCounted
class_name QuickAddTokenizerTest

class NoopUndoManager:
	extends RefCounted
	func create_action(_a = null) -> void: pass
	func add_do_method(_a = null, _b = null, _c = null, _d = null, _e = null) -> void: pass
	func add_undo_method(_a = null, _b = null, _c = null, _d = null, _e = null) -> void: pass
	func commit_action() -> void: pass
	func has_undo() -> bool: return false
	func has_redo() -> bool: return false
	func undo() -> void: pass
	func redo() -> void: pass
	func clear_history() -> void: pass

static func run() -> bool:
	var ok: bool = true

	# ── The tokenizer (static + pure) ──
	ok = _tokens("plain values split on spaces", "score 5 true", ["score", "5", "true"]) and ok
	ok = _tokens("a quoted run stays one token (quotes kept)", "greeting \"hello world\"", ["greeting", "\"hello world\""]) and ok
	ok = _tokens("multiple quoted values", "\"a b\" \"c d\"", ["\"a b\"", "\"c d\""]) and ok
	ok = _tokens("quote glued to a prefix stays one token", "path \"res://a b.ogg\"", ["path", "\"res://a b.ogg\""]) and ok
	ok = _tokens("unterminated quote is forgiven (rest = one token)", "say \"oops no close", ["say", "\"oops no close"]) and ok
	ok = _tokens("empty text yields nothing", "", []) and ok
	ok = _tokens("runs of spaces collapse", "a   b", ["a", "b"]) and ok

	# ── End-to-end through the real quick-add brain ──
	var editor: EventSheetEditor = EventSheetEditor.new()
	editor.setup(EventSheetResource.new())
	editor.set_undo_redo_manager(NoopUndoManager.new())
	var quoted: Dictionary = editor._quick_match("set variable greeting \"hello world\"")
	ok = _check("quoted e2e matches Set Variable",
		not quoted.is_empty() and (quoted.get("definition") as ACEDefinition).id == "SetVar", true) and ok
	if not quoted.is_empty():
		var params: Dictionary = quoted.get("params", {})
		ok = _check("first param fills positionally", str(params.get("var_name", "")), "greeting") and ok
		ok = _check("quoted value stays ONE param (quotes kept)", str(params.get("value", "")), "\"hello world\"") and ok
	var plain: Dictionary = editor._quick_match("heal 7")
	ok = _check("regression: plain positional fill still works",
		not plain.is_empty() and str((plain.get("params") as Dictionary).get("amount", "")) == "7", true) and ok
	editor.free()

	return ok

static func _tokens(label: String, text: String, expected: Array) -> bool:
	var actual: PackedStringArray = EventSheetAuthorActions.tokenize_quick_params(text)
	var expected_packed: PackedStringArray = PackedStringArray(expected)
	return _check(label, actual, expected_packed)

static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] quick_add_tokenizer_test: %s" % label)
		return true
	print("[FAIL] quick_add_tokenizer_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
