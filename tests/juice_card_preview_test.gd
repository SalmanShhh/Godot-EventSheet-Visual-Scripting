# Godot EventSheets - trying a list in the editor: one card, from a card down, or all, honestly.
#
# THE ONE THING THIS FILE IS ABOUT: the editor preview plays what it can play for real, shows as
# time what is about time, and names what it skips, and it reads the same plan the running game
# reads. The pack stays a plain script: everything here is a static the editor may call, or the
# preview file the plugin loads by path.
#
# The toolbar's beat segment drives the Inspector strip by its four public doors (Play, Stop, Skip,
# Restore). Those four are pinned here because a strip rebuilt for this work must keep them.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const NEW_PACK: String = "res://eventsheet_addons/juice/juice_player.gd"
const OLD_PACK: String = "res://eventsheet_addons/juice/feedback_player.gd"
const STRIP_PATH: String = "res://addons/eventsheet/editor/inspector/feedback_player_strip.gd"
const PREVIEW_PATH: String = "res://addons/eventsheet/editor/inspector/juice_preview.gd"

const TEST_NAME: String = "juice_card_preview"


static func run() -> bool:
	var ok: bool = true
	ok = _strip_door_pins() and ok
	ok = _footer_pins() and ok
	ok = _editor_kind_pins() and ok
	ok = _sub_list_pins() and ok
	ok = _restore_list_pins() and ok
	ok = _pass_pins() and ok
	ok = _mark_pins() and ok
	ok = _try_pins() and ok
	return ok


static func _pack() -> Script:
	return load(NEW_PACK if ResourceLoader.exists(NEW_PACK) else OLD_PACK) as Script


static func _has_static(script: Script, method: String) -> bool:
	if script == null:
		return false
	for listed: Dictionary in script.get_script_method_list():
		if str(listed.get("name")) == method:
			return true
	return false


## The four doors the toolbar segment calls, still on the strip.
static func _strip_door_pins() -> bool:
	var strip: Script = load(STRIP_PATH) as Script
	var doors: PackedStringArray = PackedStringArray()
	for door: String in ["play", "stop", "skip", "restore"]:
		if _has_method(strip, door):
			doors.append(door)
	return SUPPORT.pins(TEST_NAME, [
		["the strip keeps the four doors the toolbar segment presses", doors, PackedStringArray(["play", "stop", "skip", "restore"])]
	])


static func _has_method(script: Script, method: String) -> bool:
	for listed: Dictionary in script.get_script_method_list():
		if str(listed.get("name")) == method:
			return true
	return false


## The strip sits under the list it plays: the list's schema declares it as a footer, the drawer builds
## it for the object it is editing, and the Inspector plugin no longer puts one at the top.
static func _footer_pins() -> bool:
	var schema: Dictionary = load("res://addons/eventsheet/editor/inspector/feedback_card_schema.gd").call("schema")
	var player: Node = _pack().new()
	var drawer: EventSheetCardListDrawer = EventSheetCardListDrawer.new({"schema_dict": schema, "kind_key": "verb", "stripe_key": "category"})
	drawer.set_edited_object(player)
	var footer: Control = drawer.footer()
	var script_path: String = footer.get_script().resource_path if footer != null else ""
	var plugin: Script = load("res://addons/eventsheet/editor/inspector/feedback_player_inspector_plugin.gd") as Script
	var adds_at_top: bool = _has_method(plugin, "_parse_begin")
	var again: Control = drawer.footer()
	drawer.set_edited_object(player)
	var kept: bool = drawer.footer() == again
	var parent_is_drawer: bool = footer != null and drawer.is_ancestor_of(footer)
	var plain: EventSheetCardListDrawer = EventSheetCardListDrawer.new({"schema_dict": {"kinds": []}})
	plain.set_edited_object(player)
	var plain_footer: Control = plain.footer()
	var result: bool = SUPPORT.pins(TEST_NAME, [
		["the juice list declares a footer", schema.get("footer") is Callable, true],
		["the drawer builds the strip for the object it edits", script_path, STRIP_PATH],
		["and puts it under its own cards", parent_is_drawer, true],
		["asking again keeps the one strip", kept, true],
		["the Inspector plugin adds nothing at the top any more", adds_at_top, false],
		["a list whose schema declares no footer gets none", plain_footer == null, true]
	])
	drawer.free()
	plain.free()
	player.free()
	return result


## What the editor does with each kind: plays it for real, shows it as time, or skips it with a
## reason. One pack static, so the strip, Debug view and the guide say the same thing.
static func _editor_kind_pins() -> bool:
	var script: Script = _pack()
	var asked: bool = _has_static(script, "editor_kind")
	var answers: Dictionary = {}
	for word: String in ["shake", "punch", "tween_property", "sound", "pause", "hold_until", "hitstop", "slowmo", "emit_signal", "play_player"]:
		answers[word] = str(script.call("editor_kind", word)) if asked else "(no editor_kind)"
	return SUPPORT.pins(TEST_NAME, [
		["the pack publishes what the editor can show of each kind", asked, true],
		["a shake, a punch, a tween and a sound are played for real",
			[answers["shake"], answers["punch"], answers["tween_property"], answers["sound"]], ["felt", "felt", "felt", "felt"]],
		["waits and time changes are shown as time",
			[answers["pause"], answers["hold_until"], answers["hitstop"], answers["slowmo"]], ["time", "time", "time", "time"]],
		["a signal and another player are skipped, and say why",
			[str(answers["emit_signal"]).begins_with("skipped:"), str(answers["play_player"]).begins_with("skipped:")], [true, true]]
	])


## One card, from a card down, or all: the list the preview walks, cut from the live list without
## copying a card the user did not ask to hear.
static func _sub_list_pins() -> bool:
	var exists: bool = ResourceLoader.exists(PREVIEW_PATH)
	var preview: Script = load(PREVIEW_PATH) as Script if exists else null
	var list: Array = [
		{"verb": "shake", "amount": 0.4, "seconds": 0.2, "label": "Rattle"},
		{"verb": "pause", "seconds": 0.1},
		{"verb": "punch", "amount": 1.2, "seconds": 0.3, "label": "Swell"},
		{"verb": "flash", "amount": 1.0, "seconds": 0.05, "active": false}
	]
	var one: Array = preview.call("sub_list", list, 2, "one") if _has_static(preview, "sub_list") else []
	var down: Array = preview.call("sub_list", list, 1, "from_here") if _has_static(preview, "sub_list") else []
	var all: Array = preview.call("sub_list", list, 0, "all") if _has_static(preview, "sub_list") else []
	return SUPPORT.pins(TEST_NAME, [
		["the preview lives in one file the plugin loads by path", exists, true],
		["playing one card plays that card alone", _labels(one), ["Swell"]],
		["playing from a card plays it and every card under it", _labels(down), ["pause", "Swell", "flash"]],
		["playing all is the list itself", all.size(), 4]
	])


static func _labels(list: Array) -> Array:
	var labels: Array = []
	for entry: Variant in list:
		var card: Dictionary = entry as Dictionary
		labels.append(str(card.get("label", card.get("verb", ""))))
	return labels


## Everything a preview may move is written down first, and the list of what it wrote down is the
## one the strip puts back on Stop, on Restore, at the end of a pass and before a save.
static func _restore_list_pins() -> bool:
	var preview: Script = load(PREVIEW_PATH) as Script if ResourceLoader.exists(PREVIEW_PATH) else null
	var watched: PackedStringArray = PackedStringArray()
	if _has_static(preview, "watched_properties"):
		watched = preview.call("watched_properties", [
			{"verb": "shake", "amount": 0.4, "seconds": 0.2},
			{"verb": "tween_property", "effect": "self_modulate", "amount": 0.5, "seconds": 0.2}
		])
	return SUPPORT.pins(TEST_NAME, [
		["the preview writes down the four it always moved and every tweened property",
			watched, PackedStringArray(["position", "rotation", "scale", "modulate", "self_modulate"])]
	])


## What a pass of the preview lights and says: the plan's cards map back to their places in the live
## list (a card played from the middle lights its own mark, not the first), a Pause is never lit, and
## the strip says each card's fate in the same words the pack's kinds give. The plugin asks the preview
## helper to put everything back before a save.
static func _pass_pins() -> bool:
	var preview: Script = load(PREVIEW_PATH) as Script
	var list: Array = [
		{"verb": "shake", "amount": 0.4, "seconds": 0.2},
		{"verb": "pause", "seconds": 0.1},
		{"verb": "punch", "amount": 1.2, "seconds": 0.3},
		{"verb": "flash", "amount": 1.0, "seconds": 0.05, "active": false}
	]
	var from_two: Array = preview.call("sub_list", list, 2, "from_here")
	var positions: PackedInt32Array = preview.call("sub_indices", list, 2, "from_here")
	var one_position: PackedInt32Array = preview.call("sub_indices", list, 1, "one")
	var all_lit: PackedInt32Array = preview.call("playing_at", list, preview.call("sub_indices", list, 0, "all"), 0.05)
	var later_lit: PackedInt32Array = preview.call("playing_at", list, preview.call("sub_indices", list, 0, "all"), 0.25)
	var down_lit: PackedInt32Array = preview.call("playing_at", from_two, positions, 0.1)
	var strip: Script = load(STRIP_PATH) as Script
	var pack: Script = _pack()
	var plugin: Script = load("res://addons/eventforge/plugin.gd") as Script
	return SUPPORT.pins(TEST_NAME, [
		["a card played from the middle keeps its place in the live list", positions, PackedInt32Array([2, 3])],
		["one card is its own place", one_position, PackedInt32Array([1])],
		["the first card is lit at the start of the whole list", all_lit, PackedInt32Array([0])],
		["a Pause is never lit and the card after it is, once it starts", later_lit, PackedInt32Array([2])],
		["a card played from the middle lights its own place", down_lit, PackedInt32Array([2])],
		["the strip says a shake is played", strip.call("what_editor_does", {"verb": "shake"}, pack), "played"],
		["a hitstop is shown as time", strip.call("what_editor_does", {"verb": "hitstop"}, pack), "shown as time"],
		["a switched off card says so", strip.call("what_editor_does", {"verb": "shake", "active": false}, pack), "switched off"],
		["a signal is not shown, and says why",
			str(strip.call("what_editor_does", {"verb": "emit_signal"}, pack)).begins_with("not shown in the editor: "), true],
		["the plugin puts the previews back before the editor saves or runs a scene",
			[_has_method(plugin, "_apply_changes"), _has_method(plugin, "_save_external_data")], [true, true]]
	])


## The play mark on each card head and "Play from here" in its menu: drawn only where the schema asks,
## handing the request and the card's place to the schema's handler, and lit and unlit in place.
static func _mark_pins() -> bool:
	var asked: Array = []
	var schema: Dictionary = {"kinds": [{"kind": "a", "label": "A", "fields": []}, {"kind": "b", "label": "B", "fields": []}],
		"marks": {"run": func(object: Object, action: String, index: int) -> void: asked.append([object != null, action, index])}}
	var owner_object: Node = Node.new()
	var marked: EventSheetCardListDrawer = EventSheetCardListDrawer.new({"schema_dict": schema})
	marked.set_edited_object(owner_object)
	marked.set_value([{"kind": "a"}, {"kind": "b"}])
	var buttons: Dictionary = marked._marks
	(buttons[1] as Button).pressed.emit()
	marked.set_marks(PackedInt32Array([1]))
	var lit_tip: String = (buttons[1] as Button).tooltip_text
	var rested_tip: String = (buttons[0] as Button).tooltip_text
	(buttons[1] as Button).pressed.emit()
	marked.set_marks(PackedInt32Array())
	var popup: PopupMenu = PopupMenu.new()
	marked._fill_card_menu(popup)
	var entries: PackedStringArray = PackedStringArray()
	for item: int in range(popup.item_count):
		entries.append(popup.get_item_text(item))
	marked._on_menu(0, EventSheetCardListDrawer.MENU_PLAY_FROM)
	var plain: EventSheetCardListDrawer = EventSheetCardListDrawer.new({"schema_dict": {"kinds": [{"kind": "a", "label": "A", "fields": []}]}})
	plain.set_value([{"kind": "a"}])
	var plain_popup: PopupMenu = PopupMenu.new()
	plain._fill_card_menu(plain_popup)
	var result: bool = SUPPORT.pins(TEST_NAME, [
		["every card of a list that asks has a play mark", buttons.size(), 2],
		["pressing a mark plays that one card", asked[0], [true, "play_one", 1]],
		["a sounding card's mark says Stop, and the others still say Play",
			[lit_tip, rested_tip], ["Stop.", "Play this card alone."]],
		["pressing a sounding card's mark stops it", asked[1], [true, "stop", 1]],
		["the card menu offers Play from here", entries.has("Play from here"), true],
		["and choosing it asks for the part of the list from that card", asked[2], [true, "play_from", 0]],
		["a list that does not ask has no marks and no extra menu entry", [plain._marks.size(), plain_popup.item_count], [0, 10]]
	])
	marked.free()
	plain.free()
	popup.free()
	plain_popup.free()
	owner_object.free()
	return result


## Repeat and Try at strength are the strip's own view state: neither is an export on the player, one
## number is shared with the toolbar's box, and the strip is findable by the object it plays for.
static func _try_pins() -> bool:
	var player: Node = _pack().new()
	var strip: Control = (load(STRIP_PATH) as Script).new(player) as Control
	var untouched: float = strip.call("_strength")
	strip.call("set_try_strength", 0.6)
	var tried: float = strip.call("_strength")
	player.set("strength", 2.0)
	var scaled: float = strip.call("_strength")
	(strip.get("_repeat_box") as CheckBox).toggled.emit(true)
	var repeating: bool = strip.get("_repeat")
	var exports: PackedStringArray = PackedStringArray()
	for property: Dictionary in player.get_property_list():
		if int(property.get("usage", 0)) & PROPERTY_USAGE_STORAGE and str(property.get("name")) in ["repeat", "try_strength", "try_at_strength"]:
			exports.append(str(property.get("name")))
	var found: bool = (load(PREVIEW_PATH) as Script).call("strip_for", player) == null
	strip.free()
	player.free()
	return SUPPORT.pins(TEST_NAME, [
		["untouched, the preview plays at the player's own strength", snappedf(untouched, 0.001), 1.0],
		["the number set from the toolbar is the one tried", snappedf(tried, 0.001), 0.6],
		["and it is scaled by the player's own, as a play row's strength is", snappedf(scaled, 0.001), 1.2],
		["ticking Repeat is view state on the strip", repeating, true],
		["and neither is saved on the player", exports, PackedStringArray()],
		["a strip with no list under it is not the one a card mark means", found, true]
	])
