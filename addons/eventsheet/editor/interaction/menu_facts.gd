# EventForge - The menus a tool builds in code, read as the menus they are.
#
# Every tool has a menu, and in Godot every menu is the same two halves written twenty rows apart:
# a run of `add_item("Save", 2)` calls that says what is IN the menu, and a `match id:` somewhere
# else that says what each item DOES. Nothing in either half names the other - the run knows the
# labels and the handler knows the numbers - so a reader has to hold "2 means Save" in their head
# while scrolling between them.
#
# This file is the one walk that joins them: per file, which add_item run went into which menu
# variable with which id, and which handler answers that menu. With both facts in hand the run
# collapses into ONE bar naming its items in order, and every `N:` arm reads as the trigger
# `On "Save" chosen` - the number resolved back to the word the user clicks.
#
# Everything here is DISPLAY ONLY and every function is static and pure. No reading decides what is
# emitted, so a file opened and saved untouched reproduces every byte, whichever spelling its menu
# was written in.
#
# Two spellings of the same handler are read, because real code uses both:
#   popup.id_pressed.connect(func(id: int) -> void: match id: ...)   - the lambda
#   popup.id_pressed.connect(_on_chosen)  +  func _on_chosen(id): match id: ...  - the named handler
@tool
class_name EventSheetMenuFacts
extends RefCounted

## The pattern id this reading claims. Frozen once shipped.
const PATTERN_ID := "menu"

## The word an item list separator reads as, and the word a menu's object column ends with: a menu
## called `sheet_popup` is the "Sheet menu", so a row of it says where the reader would click.
const SEPARATOR_GLYPH := "─"
const OBJECT_WORD := "menu"

## The tick an `add_check_item` wears in the item list, and the arrow a submenu wears.
const TICK_GLYPH := "✓"
const SUBMENU_GLYPH := "▸"

## The signals a menu says "this one was chosen" with. `id_pressed` hands the id the item was added
## with; `index_pressed` and `item_selected` (the dropdown's own) hand the item's POSITION, which is
## a different number and is resolved differently below.
const ID_SIGNAL := "id_pressed"
const INDEX_SIGNALS: PackedStringArray = ["index_pressed", "item_selected"]

## The add_* calls that put something in a menu, and where each of them keeps its label and its id.
## `label` / `id` are ARGUMENT POSITIONS, -1 when the call has none: an icon item names its icon
## first, and a plain `add_item("Save")` with no id gets the position it was added at.
const ITEM_CALLS: Dictionary = {
	"add_item": {"label": 0, "id": 1, "kind": "item"},
	"add_check_item": {"label": 0, "id": 1, "kind": "check"},
	"add_radio_check_item": {"label": 0, "id": 1, "kind": "check"},
	"add_icon_item": {"label": 1, "id": 2, "kind": "item"},
	"add_submenu_item": {"label": 0, "id": 2, "kind": "submenu"},
	"add_separator": {"label": 0, "id": 1, "kind": "separator"}
}

## The call that greys an item out, by the POSITION it was added at.
const DISABLE_CALL := "set_item_disabled"

## The words a variable name ends with that say "this is the menu" rather than naming it: a
## `sheet_popup` is the Sheet menu, not the "Sheet popup menu". Longest first, so `option_button`
## is stripped whole rather than leaving "option" behind.
const NAME_TAILS: PackedStringArray = [
	"option_button", "popup_menu", "context_menu", "menu_button", "popup", "menu", "options", "button"
]


## Everything the readings need to know about the menus in one FILE, or {} when it builds none -
## which is every game script, so the common case costs one walk and nothing else.
##
##   menus           {menu key: {variable, name, object, signal, items, ids, indexes}}
##   menu_handlers   {function name: menu key} - the named-handler spelling
##
## The menu key is the variable the menu was built through, exactly as the file spells it
## (`sheet_popup`, `_dock._tree_context_menu`), because that is the only name both halves share.
static func facts(lines: PackedStringArray) -> Dictionary:
	var menus: Dictionary = {}
	var handlers: Dictionary = {}
	for raw_line: String in lines:
		var line: String = raw_line.strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		_read_item_line(line, menus)
		_read_disable_line(line, menus)
		_read_connect_line(line, menus, handlers)
	if menus.is_empty():
		return {}
	for key: String in menus:
		_index_items(menus[key] as Dictionary)
	return {"menus": menus, "menu_handlers": handlers}


## The menu one `add_item` line builds into, "" for a line that builds none. This is what lets the
## row builder recognise a run without re-walking the file.
static func item_menu_key(line: String) -> String:
	return str(item_parts(line).get("menu", ""))


## One `add_*` line as {menu, kind, label, id_text, submenu}, or {} for anything else. The label is
## the literal the user reads when it is one, and the expression's own text when it is not - a menu
## whose labels come from a variable still reads as a menu, it just says the variable.
static func item_parts(line: String) -> Dictionary:
	var call: Dictionary = EventSheetSentence.call_parts(line.strip_edges())
	if call.is_empty():
		return {}
	var method: String = str(call.get("method", ""))
	if not ITEM_CALLS.has(method):
		return {}
	var target: String = str(call.get("target", ""))
	if target.is_empty() or not EventSheetSentence.is_simple_target(target):
		return {}
	var shape: Dictionary = ITEM_CALLS[method] as Dictionary
	var args: PackedStringArray = call.get("args", PackedStringArray()) as PackedStringArray
	var kind: String = str(shape.get("kind", "item"))
	var label_at: int = int(shape.get("label", -1))
	var id_at: int = int(shape.get("id", -1))
	var label: String = SEPARATOR_GLYPH
	if kind != "separator" or args.size() > label_at:
		label = label_text(args[label_at]) if args.size() > label_at else ""
	var submenu: String = ""
	if kind == "submenu" and args.size() > 1:
		submenu = label_text(args[1])
	return {
		"menu": target.trim_prefix("self."),
		"kind": kind,
		"label": label,
		"id_text": str(args[id_at]).strip_edges() if args.size() > id_at else "",
		"submenu": submenu
	}


## The words an item shows. A quoted literal comes out as the text between the quotes; a label
## wrapped in one call (`tr("Save")`, the plugin's own translate helper) comes out of the wrapper,
## because the wrapper is plumbing and the words inside it are what the user reads; anything else
## keeps its own spelling so nothing is invented.
static func label_text(argument: String) -> String:
	var text: String = argument.strip_edges()
	if text.length() >= 2 and text.begins_with("\"") and text.ends_with("\""):
		return text.substr(1, text.length() - 2)
	var call: Dictionary = EventSheetSentence.call_parts(text)
	if not call.is_empty():
		var args: PackedStringArray = call.get("args", PackedStringArray()) as PackedStringArray
		if args.size() == 1:
			var inner: String = str(args[0]).strip_edges()
			if inner.begins_with("\"") and inner.ends_with("\"") and inner.length() >= 2:
				return inner.substr(1, inner.length() - 2)
	return text


## The menu a named handler answers, "" when this function answers none.
static func handler_menu(context: Dictionary, function_name: String) -> String:
	var handlers: Variant = context.get("menu_handlers", null)
	if not (handlers is Dictionary):
		return ""
	return str((handlers as Dictionary).get(function_name.strip_edges(), ""))


## One menu by key, {} when the file has no such menu.
static func menu_of(context: Dictionary, key: String) -> Dictionary:
	var menus: Variant = context.get("menus", null)
	if not (menus is Dictionary):
		return {}
	var entry: Variant = (menus as Dictionary).get(key, null)
	return (entry as Dictionary) if entry is Dictionary else {}


## The menu a `x.id_pressed.connect(...)` line wires up, "" for any other line. The row builder asks
## this of the connect statement a lambda came in on, which is how an arm inside the lambda knows
## which menu it answers without any function to hang a name on.
static func connected_menu_key(line: String) -> String:
	var text: String = line.strip_edges()
	var at: int = text.find(".connect(")
	if at < 0:
		return ""
	var head: String = text.substr(0, at)
	var dot_at: int = head.rfind(".")
	if dot_at < 0:
		return ""
	var signal_name: String = head.substr(dot_at + 1).strip_edges()
	if signal_name != ID_SIGNAL and not INDEX_SIGNALS.has(signal_name):
		return ""
	var target: String = head.substr(0, dot_at).strip_edges().trim_prefix("self.")
	return target if EventSheetSentence.is_simple_target(target) else ""


## The display name of a menu - what the bar calls it and what the trigger rows file themselves
## under. `sheet_popup` is the Sheet menu; `_tree_context_menu` is the Tree context menu.
static func display_name(variable: String) -> String:
	var bare: String = variable.strip_edges().trim_prefix("self.")
	var dot_at: int = bare.rfind(".")
	if dot_at >= 0:
		bare = bare.substr(dot_at + 1)
	bare = bare.lstrip("_")
	for tail: String in NAME_TAILS:
		if bare.length() > tail.length() + 1 and bare.ends_with("_%s" % tail):
			bare = bare.substr(0, bare.length() - tail.length() - 1)
			break
	if bare.is_empty():
		return OBJECT_WORD.capitalize()
	return bare.replace("_", " ").capitalize()


## The object column a row of this menu wears: "Sheet menu".
static func object_words(variable: String) -> String:
	return "%s %s" % [display_name(variable), EventSheetL10n.translate(OBJECT_WORD)]


## The bar a whole add_item run reads as: {text, note}. The text names the menu, the note is the
## variable's own words and every item in the order the file adds them - separators as a dash, tick
## items with their tick, submenus with the menu they open, and an item whose id was already taken
## marked as the dead one it is.
static func bar_words(menu: Dictionary) -> Dictionary:
	var items: PackedStringArray = PackedStringArray()
	for entry: Variant in (menu.get("items", []) as Array):
		items.append(item_words(entry as Dictionary))
	var variable_words: String = str(menu.get("variable", "")).lstrip("_").replace("_", " ")
	return {
		"text": "%s %s" % [EventSheetL10n.translate("Menu"), str(menu.get("name", ""))],
		"note": "%s · %s %s" % [variable_words, EventSheetL10n.translate("items:"), " · ".join(items)]
	}


## One item as the bar says it.
static func item_words(item: Dictionary) -> String:
	var kind: String = str(item.get("kind", "item"))
	if kind == "separator":
		return SEPARATOR_GLYPH
	var words: String = str(item.get("label", ""))
	if kind == "check":
		words = "%s %s" % [TICK_GLYPH, words]
	elif kind == "submenu":
		words = "%s %s %s" % [words, SUBMENU_GLYPH, str(item.get("submenu", ""))]
	if bool(item.get("disabled", false)):
		words = "%s (%s)" % [words, EventSheetL10n.translate("off")]
	if int(item.get("duplicate_of", -1)) >= 0:
		words = "%s (%s)" % [words, EventSheetL10n.translate("never chosen")]
	return words


## What one `match` arm of a menu handler reads as: {text, label, known}. `known` is false for an id
## no add_item ever declared - the arm still reads, in the warning colour, saying the number it is
## waiting for, because an unreachable branch a reader cannot see is the bug this reading exists to
## show.
static func arm_words(menu: Dictionary, pattern: String) -> Dictionary:
	var wanted: String = pattern.strip_edges()
	if wanted.is_empty() or wanted == "_":
		return {}
	var label: String = item_label(menu, wanted)
	if label.is_empty():
		return {
			"text": EventSheetL10n.translate("On item %s chosen") % wanted,
			"label": "", "known": false
		}
	return {"text": EventSheetL10n.translate("On %s chosen") % label, "label": label, "known": true}


## The label an id (or, for a dropdown, a position) stands for, "" when nothing declared it. The
## FIRST item with that id answers - which is exactly what the engine does, and why a second item
## sharing it is dead.
static func item_label(menu: Dictionary, id_text: String) -> String:
	var table: String = "indexes" if _reads_positions(menu) else "ids"
	var lookup: Variant = menu.get(table, null)
	if not (lookup is Dictionary):
		return ""
	var index: Variant = (lookup as Dictionary).get(id_text.strip_edges(), null)
	if index == null:
		return ""
	var items: Array = menu.get("items", []) as Array
	return str((items[int(index)] as Dictionary).get("label", "")) if int(index) < items.size() else ""


## Every arm of every menu handler whose id no item declared, as {menu, name, id} - what the Doctor
## says out loud. Answered from the same walk, so the note and the row can never disagree.
static func unknown_arms(context: Dictionary, lines: PackedStringArray) -> Array:
	var found: Array = []
	for arm: Dictionary in _arms(context, lines):
		var menu: Dictionary = menu_of(context, str(arm.get("menu", "")))
		if menu.is_empty() or not item_label(menu, str(arm.get("id", ""))).is_empty():
			continue
		found.append({"menu": str(arm.get("menu", "")), "name": str(menu.get("name", "")), "id": str(arm.get("id", ""))})
	return found


## Every item whose id a previous item already took, as {menu, name, label, id, first}. The engine
## sends one number, the handler answers it once, and the later item is dead however clearly it was
## written - the bug this file's own menus were once shipped with.
static func duplicate_items(context: Dictionary) -> Array:
	var found: Array = []
	var menus: Variant = context.get("menus", null)
	if not (menus is Dictionary):
		return found
	for key: String in (menus as Dictionary):
		var menu: Dictionary = (menus as Dictionary)[key] as Dictionary
		var items: Array = menu.get("items", []) as Array
		for entry: Variant in items:
			var item: Dictionary = entry as Dictionary
			var first: int = int(item.get("duplicate_of", -1))
			if first < 0:
				continue
			found.append({
				"menu": key, "name": str(menu.get("name", "")), "label": str(item.get("label", "")),
				"id": str(item.get("id_text", "")),
				"first": str((items[first] as Dictionary).get("label", ""))
			})
	return found


# ── Internals ─────────────────────────────────────────────────────────────────────────────────────


## Records one add_* line under the menu it builds.
static func _read_item_line(line: String, menus: Dictionary) -> void:
	var parts: Dictionary = item_parts(line)
	if parts.is_empty():
		return
	var key: String = str(parts.get("menu", ""))
	if not menus.has(key):
		menus[key] = {
			"variable": key, "name": display_name(key), "object": object_words(key),
			"signal": "", "items": [], "ids": {}, "indexes": {}
		}
	var menu: Dictionary = menus[key] as Dictionary
	var items: Array = menu["items"] as Array
	var id_text: String = str(parts.get("id_text", ""))
	items.append({
		"label": str(parts.get("label", "")), "kind": str(parts.get("kind", "item")),
		"submenu": str(parts.get("submenu", "")),
		# An item added without an id gets the position it was added at, which is the id the engine
		# then sends for it - so the reading resolves it exactly as the engine would. A SEPARATOR is
		# the exception: it is not something the menu can send, so it takes no id at all. Giving it
		# the position it was added at would have it collide with whichever item really carries that
		# number, and the reading would call a perfectly good item dead.
		"id_text": "" if str(parts.get("kind", "item")) == "separator" \
			else (id_text if not id_text.is_empty() else str(items.size())),
		"disabled": false, "duplicate_of": -1, "line": line
	})


## Records a `set_item_disabled(3, true)` against the item at that position.
static func _read_disable_line(line: String, menus: Dictionary) -> void:
	var call: Dictionary = EventSheetSentence.call_parts(line)
	if call.is_empty() or str(call.get("method", "")) != DISABLE_CALL:
		return
	var key: String = str(call.get("target", "")).trim_prefix("self.")
	if not menus.has(key):
		return
	var args: PackedStringArray = call.get("args", PackedStringArray()) as PackedStringArray
	if args.size() < 2 or not str(args[0]).strip_edges().is_valid_int():
		return
	if str(args[1]).strip_edges() != "true":
		return
	var items: Array = (menus[key] as Dictionary)["items"] as Array
	var at: int = int(str(args[0]))
	if at >= 0 and at < items.size():
		(items[at] as Dictionary)["disabled"] = true


## Records which signal a menu answers with, and - for the named-handler spelling - which function
## answers it. A lambda is not recorded here: it has no name, so the row builder asks
## `connected_menu_key` of the statement it came in on instead.
static func _read_connect_line(line: String, menus: Dictionary, handlers: Dictionary) -> void:
	var key: String = connected_menu_key(line)
	if key.is_empty():
		return
	if not menus.has(key):
		menus[key] = {
			"variable": key, "name": display_name(key), "object": object_words(key),
			"signal": "", "items": [], "ids": {}, "indexes": {}
		}
	var text: String = line.strip_edges()
	var head: String = text.substr(0, text.find(".connect("))
	(menus[key] as Dictionary)["signal"] = head.substr(head.rfind(".") + 1).strip_edges()
	var handed: String = text.substr(text.find(".connect(") + 9).strip_edges().trim_suffix(")")
	if handed.begins_with("func("):
		return
	var handler: String = handed.split(",")[0].strip_edges().trim_prefix("self.").trim_suffix(")")
	if EventSheetSentence.is_identifier(handler):
		handlers[handler] = key


## Fills a menu's two lookup tables - id to item, and position to item - and marks every item whose
## id an earlier one already took.
static func _index_items(menu: Dictionary) -> void:
	var ids: Dictionary = {}
	var indexes: Dictionary = {}
	var items: Array = menu["items"] as Array
	for index in range(items.size()):
		var item: Dictionary = items[index] as Dictionary
		indexes[str(index)] = index
		var id_text: String = str(item.get("id_text", ""))
		if id_text.is_empty():
			continue
		if ids.has(id_text):
			item["duplicate_of"] = int(ids[id_text])
			continue
		ids[id_text] = index
	menu["ids"] = ids
	menu["indexes"] = indexes


## True when this menu's chosen signal hands a POSITION rather than an id - a dropdown's
## `item_selected` and a popup's `index_pressed`.
static func _reads_positions(menu: Dictionary) -> bool:
	return INDEX_SIGNALS.has(str(menu.get("signal", "")))


## Every `N:` arm of every menu handler in the file, as {menu, id}. Walked here rather than in the
## row builder because the Doctor asks the same question of a file nobody has opened.
static func _arms(context: Dictionary, lines: PackedStringArray) -> Array:
	var arms: Array = []
	var menu_key: String = ""
	var in_match: bool = false
	var match_indent: int = 0
	for raw_line: String in lines:
		var line: String = raw_line.strip_edges()
		var indent: int = raw_line.length() - raw_line.lstrip("\t").length()
		if line.is_empty() or line.begins_with("#"):
			continue
		if line.begins_with("func ") or line.begins_with("static func "):
			var name_text: String = line.substr(line.find("func ") + 5)
			menu_key = handler_menu(context, name_text.substr(0, maxi(name_text.find("("), 0)))
			in_match = false
			continue
		var connected: String = connected_menu_key(line)
		if not connected.is_empty() and line.contains(".connect(func("):
			menu_key = connected
			in_match = false
			continue
		if menu_key.is_empty():
			continue
		if line.begins_with("match ") and line.ends_with(":"):
			in_match = true
			match_indent = indent
			continue
		if not in_match:
			continue
		if indent <= match_indent:
			in_match = false
			continue
		if indent == match_indent + 1 and line.ends_with(":"):
			arms.append({"menu": menu_key, "id": line.substr(0, line.length() - 1).strip_edges()})
	return arms
