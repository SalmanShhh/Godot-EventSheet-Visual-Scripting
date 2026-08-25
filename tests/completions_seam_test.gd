# The one completion seam, the one popup, and typing a row as a sentence.
#
# Three claims, and each of them is a value rather than a count.
#
# THE SEAM answers per FIELD KIND, and what it answers is a name plus the line that explains it. A
# sheet's own variable is offered before the host class's members, a function is explained by the
# parameters it takes, and a kind nobody answers comes back empty - which is what keeps an
# unrecognised parameter hint a plain typed field instead of a wrong list.
#
# THE POPUP has ONE keyboard model wherever it appears, and the model is decided apart from any
# window: Tab and Enter accept, Escape keeps what was typed, Up and Down move. An expression field
# swaps the word under the caret; every other field holds one value and is replaced whole.
#
# QUICK ADD reads the whole sentence. "boss fla 0.4" is an object, a verb and a value: the words
# find the row, the value fills its first parameter that can take one, and neither is asked to do
# the other's job.
#
# And the performance contract, which is the reason any of it can run on every keystroke: a kind's
# list is built once and only filtered afterwards, until the sheet is edited.
@tool
class_name CompletionsSeamTest
extends RefCounted

const Pins := preload("res://tests/pin_table.gd")

## The seam's own script object. Statics are reached through the script rather than the class name,
## and the cache is what says whether a list was rebuilt or handed back.
const CompletionsScript := preload("res://addons/eventsheet/editor/autocomplete/completion_sources.gd")


static func run() -> bool:
	var ok: bool = true
	ok = _test_the_seam_answers_per_field_kind() and ok
	ok = _test_the_expression_field_reads_the_caret() and ok
	ok = _test_ranking_puts_the_answer_first() and ok
	ok = _test_an_unknown_kind_answers_nothing() and ok
	ok = _test_the_keyboard_model() and ok
	ok = _test_accepting_replaces_the_right_thing() and ok
	ok = _test_the_popup_moves_and_closes() and ok
	ok = _test_quick_add_reads_the_sentence() and ok
	ok = _test_quick_add_fills_the_first_parameter() and ok
	ok = _test_a_list_is_built_once_and_only_filtered() and ok
	ok = _test_a_pack_can_add_a_source() and ok
	ok = _test_the_public_surface() and ok
	ok = _test_an_edit_drops_the_lists_of_the_sheet_it_replaced() and ok
	return ok


## An edit drops what it changed, while the sheet those lists were built for is still findable.
##
## The lists are held against the sheet OBJECT, and the undo funnel commits by REPLACING that object
## with a snapshot duplicate - so a drop made after the swap is handed a brand-new resource with no
## entries and erases nothing. The superseded version's lists then sit there until the cap evicts
## them, pushing out project-wide lists that are still being asked for. Counted through the cache
## itself, because the answer a list gives is the same either way; what is measured is whether it
## was rebuilt.
static func _test_an_edit_drops_the_lists_of_the_sheet_it_replaced() -> bool:
	EventSheetCompletions.clear_cache()
	var dock: EventSheetDock = EventSheetDock.new()
	dock.setup(_fixture())
	var edited: EventSheetResource = dock._current_sheet
	EventSheetCompletions.for_field(edited, EventSheetCompletions.FIELD_VARIABLE, "")
	var held_before: int = _lists_held_for(edited)
	# What the funnel does on commit, and on every undo and redo after it.
	dock._restore_sheet_snapshot(edited.duplicate(true))
	var ok: bool = Pins.check_value("completions_invalidation",
		"an edit drops the lists of the sheet it replaced",
		PackedStringArray([str(held_before), str(_lists_held_for(edited))]),
		PackedStringArray(["1", "0"]))
	dock.free()
	EventSheetCompletions.clear_cache()
	return ok


## How many built lists the cache is holding for one sheet. Reached through the script object, which
## is the only way to a static, and read rather than counted from outside: a list handed back by
## `for_field` is ranked into a fresh array every time, so identity says nothing about the cache.
static func _lists_held_for(sheet: EventSheetResource) -> int:
	var prefix: String = "%d|" % sheet.get_instance_id()
	var held: int = 0
	for key: Variant in (CompletionsScript as Object).get("_cache").keys():
		if str(key).begins_with(prefix):
			held += 1
	return held


## The four calls a pack actually holds, through the public class rather than the implementation.
## Their shapes freeze the moment they ship, so what is pinned here is that each one is reachable,
## typed as documented, and answers the same thing the seam does.
static func _test_the_public_surface() -> bool:
	var sheet: EventSheetResource = _fixture()
	var ok: bool = Pins.check_value("completions_public_api", "completions_for answers the seam",
		EventSheets.completions_for(sheet, EventSheetCompletions.FIELD_VARIABLE, "hp"),
		EventSheetCompletions.for_field(sheet, EventSheetCompletions.FIELD_VARIABLE, "hp"))
	EventSheets.register_completion_source("a_public_kind", func(_sheet: EventSheetResource,
			_kind: String) -> Array:
		return ["one", "two"])
	ok = Pins.check_value("completions_public_api", "a registered source answers",
		EventSheets.completions_for(sheet, "a_public_kind", "tw"),
		[{"text": "two", "detail": "", "kind": "variable"}]) and ok
	EventSheets.unregister_completion_source("a_public_kind")
	ok = Pins.check_value("completions_public_api", "and stops when it is removed",
		EventSheets.completions_for(sheet, "a_public_kind", "tw"), []) and ok
	# The popup rides a field, marks it as completing, and answers for that kind. Built with no
	# window, which is the point of the model living apart from the widget.
	var field: LineEdit = LineEdit.new()
	var popup: EventSheetCompletionPopup = EventSheets.attach_completions(field,
		EventSheetCompletions.FIELD_CLASS)
	ok = Pins.check_value("completions_public_api", "attach_completions marks the field",
		EventSheetCompletionPopup.rides(field), true) and ok
	ok = Pins.check_value("completions_public_api", "and a class field is replaced whole",
		popup.replaces_word, false) and ok
	field.free()
	return ok


## A sheet with one of everything a field can be completed with: two variables, a function that
## takes a parameter, an enum and a signal of its own.
static func _fixture() -> EventSheetResource:
	EventSheetCompletions.clear_cache()
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.custom_class_name = "Player"
	sheet.host_class = "Node2D"
	sheet.variables["hp"] = {"type": "int", "default": 100}
	sheet.variables["speed"] = {"type": "float", "default": 220.0}
	var event_function: EventFunction = EventFunction.new()
	event_function.function_name = "take_damage"
	var parameter: ACEParam = ACEParam.new()
	parameter.id = "amount"
	event_function.params.append(parameter)
	sheet.functions.append(event_function)
	var enum_row: EnumRow = EnumRow.new()
	enum_row.enum_name = "State"
	enum_row.members = PackedStringArray(["IDLE", "RUN"])
	sheet.events.append(enum_row)
	var signal_row: SignalRow = SignalRow.new()
	signal_row.signal_name = "died"
	sheet.events.append(signal_row)
	return sheet


## What each kind's FIRST entry is, as the reader would read it: the name it inserts, the line under
## it, and the id naming what sort of thing it is. Pinned as whole entries because a name without
## its explaining line is exactly the half-answer this seam exists to replace.
static func _test_the_seam_answers_per_field_kind() -> bool:
	var sheet: EventSheetResource = _fixture()
	return Pins.check("completions_per_field_kind", {
		EventSheetCompletions.FIELD_VARIABLE: {"text": "hp",
			"detail": "Player · Instance whole number hp = 100", "kind": "variable"},
		EventSheetCompletions.FIELD_FUNCTION: {"text": "take_damage",
			"detail": "function(amount)", "kind": "function"},
		EventSheetCompletions.FIELD_SIGNAL: {"text": "died", "detail": "signal", "kind": "signal"},
		"enum_value:State": {"text": "State.IDLE", "detail": "State · enum value", "kind": "enum"},
	}, func(kind: String) -> Variant:
		var answered: Array[Dictionary] = EventSheetCompletions.for_field(sheet, kind, "")
		return answered[0] if not answered.is_empty() else {})


## The expression field is the one whose answer depends on where the caret is: a bare word offers
## the flat vocabulary, `hp.` offers that type's members and nothing else, and `$` offers the
## scene's nodes. The readings that decide which are pinned first, because they are what a wrong
## answer would come from.
static func _test_the_expression_field_reads_the_caret() -> bool:
	var ok: bool = Pins.check("completions_caret_reading", {
		"health + ma": "ma",
		"hp": "hp",
		"": "",
		"hp.": "",
		"$Sprite": "Sprite",
	}, func(text: String) -> Variant: return EventSheetCompletions.trailing_word(text))
	# The receiver is what the caret sits BEHIND, and the word being typed after the dot is no part
	# of it: `hp.` and `hp.hea` reach through the same `hp`.
	ok = Pins.check("completions_member_receiver", {
		"hp.": "hp",
		"hp.hea": "hp",
		"if body.": "body",
		"$Sprite.": "$Sprite",
		"$Sprite.mod": "$Sprite",
		"%Health.": "%Health",
		"health + ": "",
		"hp": "",
	}, func(text: String) -> Variant: return EventSheetCompletions.member_receiver(text)) and ok
	ok = Pins.check("completions_modulo_reading", {
		"score %": true,
		"\"%d\" %": true,
		"target = %": false,
		"%": false,
	}, func(text: String) -> Variant: return EventSheetCompletions.is_modulo_context(text)) and ok
	# Which sigil the caret sits behind, which is the whole of "am I addressing a node". A typed
	# name does not move the caret out of that position, and a `%` after a value is a modulo however
	# much is typed after it.
	ok = Pins.check("completions_node_sigil", {
		"$": "$",
		"$Spr": "$",
		"= %": "%",
		"= %Spr": "%",
		"score %": "",
		"score %Spr": "",
		"hp": "",
	}, func(text: String) -> Variant: return EventSheetCompletions.node_sigil(text)) and ok
	var sheet: EventSheetResource = _fixture()
	# The sheet's own variable leads its host class's members, and a function's parameter is offered
	# by name - the one thing the flat vocabulary used to be missing.
	ok = Pins.check("completions_expression_first_answer", {
		"hp": {"text": "hp", "detail": "Player · Instance whole number hp = 100", "kind": "variable"},
		"take": {"text": "take_damage", "detail": "function(amount)", "kind": "function"},
		"amou": {"text": "amount", "detail": "take_damage · parameter", "kind": "variable"},
		"ma": {"text": "max()", "detail": "built-in · max(a, b, ...) - the largest", "kind": "builtin"},
	}, func(typed: String) -> Variant:
		var answered: Array[Dictionary] = EventSheetCompletions.for_field(sheet,
			EventSheetCompletions.FIELD_EXPRESSION, typed)
		return answered[0] if not answered.is_empty() else {}) and ok
	return _test_a_position_survives_the_next_keystroke(sheet) and ok


## WHERE the caret is, as opposed to what has been typed there. A member list that turns back into
## the sheet's own vocabulary on the next keystroke is worse than no list at all: the popup replaces
## only the word under the caret, so accepting an entry from the flat list writes a top-level name
## after the dot - `hp.health`, a member `hp` has never had. The same for the two node sigils, where
## one typed letter used to lose the scene's paths.
static func _test_a_position_survives_the_next_keystroke(sheet: EventSheetResource) -> bool:
	var scene_root: Node = Node2D.new()
	scene_root.name = "Level"
	var sprite: Node2D = Node2D.new()
	sprite.name = "Sprite"
	scene_root.add_child(sprite)
	sprite.owner = scene_root
	sprite.unique_name_in_owner = true
	EventSheetCompletions.scene_root_override = scene_root
	EventSheetCompletions.clear_cache()
	var ok: bool = Pins.check("completions_position_survives_typing", {
		"State.": "member:IDLE,member:RUN",
		"State.R": "member:RUN",
		"if State.": "member:IDLE,member:RUN",
		"$": "node:Sprite",
		"$Spr": "node:Sprite",
		"= %Spr": "node:Sprite",
	}, func(typed: String) -> Variant:
		var said: PackedStringArray = PackedStringArray()
		for entry: Dictionary in EventSheetCompletions.for_field(sheet,
				EventSheetCompletions.FIELD_EXPRESSION, typed):
			said.append("%s:%s" % [str(entry.get("kind", "")), str(entry.get("text", ""))])
		return ",".join(said))
	EventSheetCompletions.scene_root_override = null
	EventSheetCompletions.clear_cache()
	scene_root.free()
	return ok


## The tiers, on one list, by the order they come back in. The whole name beats a name that starts
## with the query, which beats a word of the name starting with it, which beats the name merely
## containing it, which beats a hit in the explaining line. Two letters never reach the
## letters-in-order tier, because `hp` is inside half the engine's method names.
static func _test_ranking_puts_the_answer_first() -> bool:
	var pool: Array[Dictionary] = [
		{"text": "show_behind_parent", "detail": "", "kind": "member"},
		{"text": "hitpoints", "detail": "", "kind": "variable"},
		{"text": "player_hp", "detail": "", "kind": "variable"},
		{"text": "hp", "detail": "", "kind": "variable"},
		{"text": "max_hp_bonus", "detail": "", "kind": "variable"},
		{"text": "armour", "detail": "the hp it saves you", "kind": "variable"},
	]
	var ranked: PackedStringArray = PackedStringArray()
	for entry: Dictionary in EventSheetCompletions.rank(pool, "hp"):
		ranked.append(str(entry["text"]))
	# `hitpoints` and `show_behind_parent` are not here on purpose: neither contains "hp", and two
	# letters do not reach the letters-in-order tier. That floor is what keeps a short query from
	# burying its own answer.
	var ok: bool = Pins.check_value("completions_ranking", "hp over a list of six", ranked,
		PackedStringArray(["hp", "player_hp", "max_hp_bonus", "armour"]))
	# An empty query is not a ranking at all: everything is offered, in the order the source built
	# it, so a field opened with nothing typed reads as the source meant it to.
	var untyped: PackedStringArray = PackedStringArray()
	for entry: Dictionary in EventSheetCompletions.rank(pool, ""):
		untyped.append(str(entry["text"]))
	return Pins.check_value("completions_ranking", "an empty query keeps the source's order", untyped,
		PackedStringArray(["show_behind_parent", "hitpoints", "player_hp", "hp", "max_hp_bonus",
			"armour"])) and ok


## A hint this build has never heard of - a pack's own, a hint from a newer version - answers with
## nothing. That is what keeps its field an ordinary typed one rather than one offering a list
## belonging to something else.
static func _test_an_unknown_kind_answers_nothing() -> bool:
	var sheet: EventSheetResource = _fixture()
	return Pins.check("completions_unknown_kind", {
		"a_hint_from_a_pack_that_is_not_installed": [],
		"": [],
	}, func(kind: String) -> Variant:
		return EventSheetCompletions.for_field(sheet, kind, "a"))


## One keyboard model, decided without a window: this is what makes the popup behave the same in a
## dialog, in an inline row edit and in a pack's own field.
static func _test_the_keyboard_model() -> bool:
	return Pins.check("completion_popup_keys", {
		KEY_TAB: EventSheetCompletionPopup.ACT_ACCEPT,
		KEY_ENTER: EventSheetCompletionPopup.ACT_ACCEPT,
		KEY_KP_ENTER: EventSheetCompletionPopup.ACT_ACCEPT,
		KEY_ESCAPE: EventSheetCompletionPopup.ACT_CANCEL,
		KEY_UP: EventSheetCompletionPopup.ACT_UP,
		KEY_DOWN: EventSheetCompletionPopup.ACT_DOWN,
		KEY_A: EventSheetCompletionPopup.ACT_NONE,
	}, func(keycode: int) -> Variant:
		var event: InputEventKey = InputEventKey.new()
		event.keycode = keycode
		event.pressed = true
		return EventSheetCompletionPopup.key_action(event))


## What accepting WRITES. An expression keeps everything the reader already typed and swaps only the
## word under the caret; a name, a file or a class field holds one value and is replaced whole.
## Getting this backwards would either eat a half-written expression or leave a name doubled.
static func _test_accepting_replaces_the_right_thing() -> bool:
	var popup: EventSheetCompletionPopup = EventSheetCompletionPopup.new()
	popup.entries = [{"text": "hitpoints", "detail": "", "kind": "variable"}]
	popup.replaces_word = true
	var ok: bool = Pins.check("completion_popup_accepts", {
		"health + hi": "health + hitpoints",
		"hi": "hitpoints",
		"health + ": "health + hitpoints",
	}, func(current: String) -> Variant: return popup.accepted_text(current))
	popup.replaces_word = false
	ok = Pins.check("completion_popup_accepts", {
		"Char": "hitpoints",
		"": "hitpoints",
	}, func(current: String) -> Variant: return popup.accepted_text(current)) and ok
	# Nothing on offer means nothing to accept, and the field is left exactly as it is.
	popup.entries = []
	return Pins.check_value("completion_popup_accepts", "an empty list changes nothing",
		popup.accepted_text("half typed"), "half typed") and ok


## Moving wraps at both ends, and closing empties the offer so the next key press is ordinary
## typing again - which is what Escape KEEPING what was typed actually means.
static func _test_the_popup_moves_and_closes() -> bool:
	var popup: EventSheetCompletionPopup = EventSheetCompletionPopup.new()
	popup.entries = [{"text": "one"}, {"text": "two"}, {"text": "three"}]
	var walked: PackedStringArray = PackedStringArray()
	for step: int in [1, 1, 1, -1]:
		popup.move(step)
		walked.append(str(popup.entries[popup.index]["text"]))
	var ok: bool = Pins.check_value("completion_popup_moves", "down three then up once", walked,
		PackedStringArray(["two", "three", "one", "three"]))
	popup.close()
	ok = Pins.check_value("completion_popup_moves", "closing leaves nothing on offer",
		popup.entries.size(), 0) and ok
	return Pins.check_value("completion_popup_moves", "and nothing to accept",
		popup.accept(), false) and ok


## The whole sentence, read. Every WORD has to hit something, in any order; a VALUE is not a word
## and is taken out of the filter, because no row's name contains 0.4 and leaving it in is what
## made the whole query find nothing.
static func _test_quick_add_reads_the_sentence() -> bool:
	var ok: bool = Pins.check("quick_add_splits", {
		"boss fla 0.4": ["boss fla", "0.4"],
		"flash white": ["flash white", ""],
		"say \"hello\"": ["say", "\"hello\""],
		# One tokenizer for both places a sentence is typed: quoted text with a space in it is ONE
		# value here exactly as it is in the quick-add bar, where a naive split once filled two
		# parameters with the halves of one name.
		"say \"hello world\"": ["say", "\"hello world\""],
		"12": ["", "12"],
	}, func(query: String) -> Variant:
		var parts: Dictionary = EventSheetQuickAdd.split(query)
		return [EventSheetQuickAdd.words_query(query), " ".join(parts["values"] as PackedStringArray)])
	# The ranking table: one query, three rows it could mean, in the order the picker will offer
	# them. The verb whose name starts a word with "fla" wins; the row the words do not reach at all
	# scores nothing and is not offered.
	var rows: Array[Dictionary] = [
		{"name": "Fade effect.dissolve", "object": "$Boss", "keywords": "Effects"},
		{"name": "Flash white", "object": "$Boss", "keywords": "Effects pack"},
		{"name": "Set flip_h", "object": "$Boss", "keywords": "Sprite"},
	]
	var scored: Array[Dictionary] = []
	for row: Dictionary in rows:
		scored.append({"name": str(row["name"]), "score": EventSheetQuickAdd.score("boss fla 0.4",
			str(row["name"]), str(row["object"]), str(row["keywords"]))})
	scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["score"]) > int(b["score"]))
	var best: String = str(scored[0]["name"])
	ok = Pins.check_value("quick_add_ranks", "boss fla 0.4 lands on the flash", best, "Flash white") and ok
	var reached: PackedStringArray = PackedStringArray()
	for entry: Dictionary in scored:
		if int(entry["score"]) > 0:
			reached.append(str(entry["name"]))
	return Pins.check_value("quick_add_ranks", "and only the rows the words reach are offered",
		reached, PackedStringArray(["Flash white"])) and ok


## A value lands in the FIRST parameter that can take it. A dropdown, a colour or a node reference
## takes none, because a value dropped into one of those is a value the field cannot show.
static func _test_quick_add_fills_the_first_parameter() -> bool:
	var flash_params: Array = [
		{"id": "target", "type_name": "String", "hint": "scene_node"},
		{"id": "colour", "type_name": "Color", "hint": "color"},
		{"id": "seconds", "type_name": "float", "hint": "expression"},
	]
	var say_params: Array = [
		{"id": "channel", "type_name": "String", "hint": "", "options": ["a", "b"]},
		{"id": "text", "type_name": "String", "hint": ""},
	]
	var ok: bool = Pins.check("quick_add_prefill", {
		"boss fla 0.4": {"seconds": "0.4"},
		"boss fla": {},
		"fla 0.4 2": {"seconds": "0.4"},
	}, func(query: String) -> Variant:
		return EventSheetQuickAdd.prefill(query, flash_params))
	ok = Pins.check("quick_add_prefill_text", {
		"say \"hello\"": {"text": "\"hello\""},
		"say 12": {},
	}, func(query: String) -> Variant: return EventSheetQuickAdd.prefill(query, say_params)) and ok
	# A parameter something else already answered - the node a picker shelf chose - is never
	# overwritten by a value from the query.
	return Pins.check_value("quick_add_prefill", "an answered parameter is left alone",
		EventSheetQuickAdd.prefill("0.4", flash_params, {"seconds": "1.0"}), {}) and ok


## THE PERFORMANCE CONTRACT, as a value: the source is asked ONCE and then only filtered, however
## many keystrokes go through it, and it is asked again exactly when the sheet's edit says the
## answer has changed. A keystroke that rebuilt the list would show as a second ask here.
static func _test_a_list_is_built_once_and_only_filtered() -> bool:
	var sheet: EventSheetResource = _fixture()
	var asks: Dictionary = {"count": 0}
	EventSheetCompletions.register_source("a_counted_kind", func(_sheet: EventSheetResource,
			_kind: String) -> Array:
		asks["count"] = int(asks["count"]) + 1
		return ["alpha", "beta", "gamma"])
	for typed: String in ["a", "al", "alp", "b", "be"]:
		EventSheetCompletions.for_field(sheet, "a_counted_kind", typed)
	var ok: bool = Pins.check_value("completions_cache", "five keystrokes ask the source once",
		int(asks["count"]), 1)
	# The edit that changed the sheet is what drops it - and nothing else does.
	EventSheetCompletions.invalidate(sheet)
	EventSheetCompletions.for_field(sheet, "a_counted_kind", "a")
	ok = Pins.check_value("completions_cache", "an edit to the sheet asks it again",
		int(asks["count"]), 2) and ok
	EventSheetCompletions.for_field(sheet, "a_counted_kind", "g")
	ok = Pins.check_value("completions_cache", "and typing after that does not",
		int(asks["count"]), 2) and ok
	EventSheetCompletions.unregister_source("a_counted_kind")
	return ok


## A pack feeds the same popup by naming a source, and what it hands back is completed exactly like
## a built-in's - including the simplest case, a plain list of Strings.
static func _test_a_pack_can_add_a_source() -> bool:
	var sheet: EventSheetResource = _fixture()
	EventSheetCompletions.register_source("a_pack_kind", func(_sheet: EventSheetResource,
			_kind: String) -> Array:
		return ["quest_start", "quest_end", {"text": "quest_fail", "detail": "the losing branch",
			"kind": "variable"}])
	var ok: bool = Pins.check("completions_pack_source", {
		"quest_s": [{"text": "quest_start", "detail": "", "kind": "variable"}],
		"losing": [{"text": "quest_fail", "detail": "the losing branch", "kind": "variable"}],
	}, func(typed: String) -> Variant:
		return EventSheetCompletions.for_field(sheet, "a_pack_kind", typed))
	EventSheetCompletions.unregister_source("a_pack_kind")
	return Pins.check_value("completions_pack_source", "and it stops answering once removed",
		EventSheetCompletions.for_field(sheet, "a_pack_kind", "quest"), []) and ok
