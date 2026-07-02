# EventForge — the command palette's `@` symbol-search mode (Navigate §13.3). collect_symbols gathers a
# sheet's named symbols (functions ƒ, signals ➜, tree variables @), incl. ones nested in groups, and
# filter_symbols fuzzy-matches them by bare name — so Ctrl+P @ jumps to any symbol in the active sheet.
@tool
extends RefCounted
class_name PaletteSymbolSearchTest

static func run() -> bool:
	var ok: bool = true

	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.functions.append(_fn("jump"))
	sheet.functions.append(_fn("is_dead"))
	sheet.events.append(_sig("on_landed"))
	sheet.events.append(_var("max_health"))
	var group: EventGroup = EventGroup.new()
	group.events.append(_var("coyote_time"))      # a symbol nested inside a group must still be found
	sheet.events.append(group)

	var symbols: Array = EventSheetCommandPalette.collect_symbols(sheet)
	ok = _check("collects every named symbol (incl. inside groups)", symbols.size(), 5) and ok
	ok = _check("function title carries the ƒ glyph", _title_of(symbols, "jump"), "ƒ jump") and ok
	ok = _check("signal title carries the ➜ glyph", _title_of(symbols, "on_landed"), "➜ on_landed") and ok
	ok = _check("variable title carries the @ glyph", _title_of(symbols, "max_health"), "@ max_health") and ok

	var jump_match: Array = EventSheetCommandPalette.filter_symbols(symbols, "jump")
	ok = _check("'jump' finds the function", jump_match.size() >= 1 and str((jump_match[0] as Dictionary).get("name")) == "jump", true) and ok
	ok = _check("empty query returns all", EventSheetCommandPalette.filter_symbols(symbols, "").size(), 5) and ok
	ok = _check("subsequence 'coyt' finds coyote_time in the group", _has_name(EventSheetCommandPalette.filter_symbols(symbols, "coyt"), "coyote_time"), true) and ok
	ok = _check("a no-match query returns nothing", EventSheetCommandPalette.filter_symbols(symbols, "zzz").size(), 0) and ok
	ok = _check("null sheet → no symbols", EventSheetCommandPalette.collect_symbols(null).size(), 0) and ok

	return ok

static func _fn(name: String) -> EventFunction:
	var function: EventFunction = EventFunction.new()
	function.function_name = name
	return function

static func _sig(name: String) -> SignalRow:
	var signal_row: SignalRow = SignalRow.new()
	signal_row.signal_name = name
	return signal_row

static func _var(name: String) -> LocalVariable:
	var local_variable: LocalVariable = LocalVariable.new()
	local_variable.name = name
	return local_variable

static func _title_of(symbols: Array, name: String) -> String:
	for symbol: Dictionary in symbols:
		if str(symbol.get("name", "")) == name:
			return str(symbol.get("title", ""))
	return "(none)"

static func _has_name(symbols: Array, name: String) -> bool:
	for symbol: Dictionary in symbols:
		if str(symbol.get("name", "")) == name:
			return true
	return false

static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] palette_symbol_search_test: %s" % label)
		return true
	print("[FAIL] palette_symbol_search_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
