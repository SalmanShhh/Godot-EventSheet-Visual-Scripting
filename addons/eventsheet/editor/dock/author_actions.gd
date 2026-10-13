@tool
class_name EventSheetAuthorActions
extends RefCounted
# Surface-level authoring shortcuts driven from the toolbar / menu / context-menu - the quick-add
# bar's fuzzy match+apply, Run Scene, and Save/Insert row Snippets. This helper owns:
#   • the quick-add bar's brain: _quick_match (best-ACE fuzzy match of a "type to insert" query,
#     honoring the picker's synonym phrasing, filling parameters positionally) and _quick_add (apply
#     the match - triggers/conditions become a new event, actions append via the standard flow),
#   • Run Scene: save-then-play the scene(s) attaching this sheet's script (the doctor's reverse
#     lookup; single scene plays, multiple offer a pick menu),
#   • row Snippets: Save Selection as Snippet… (serialize the top-level selection into the project
#     library) and Insert Snippet… (paste a library snippet back - fresh uids, missing variables
#     created), each with its own small dialog Window.
#
# Extracted from event_sheet_dock.gd to keep that file maintainable.
#
# WHAT STAYS ON THE DOCK (reached here through `_dock`):
#   • the quick-add WIDGET `_quick_add_edit` - it stays declared on the dock and is built + assigned
#     by menu_bar.gd; its text_submitted closure calls `_dock._quick_add(text)` (the dock delegate),
#   • `_paste_snippet_text` - it lives in the dock's copy/paste cluster (paste flow + snippet_share_test
#     call it); `_insert_snippet_path` reaches it via `_dock._paste_snippet_text`,
#   • the seam the moved bodies lean on: `_ensure_sheet_for_editing`, `_apply_ace_definition`,
#     `_ace_registry`, `_active_view`, `_top_level_selected_resources`, `_on_save_requested`,
#     `_current_sheet` / `_current_sheet_path`, `_set_status`, `_perform_undoable_sheet_edit`,
#     `add_child`, `is_inside_tree`, `get_global_mouse_position`.
# Globals (EventSheetProjectDoctor, EventSheetSnippetLibrary, EventSheetSnippet, ACEPickerDialog,
# ACEDefinition, EditorInterface, Engine) are unchanged.
#
# The dock keeps thin one-line delegates (original names + signatures + returns) for every method
# reached from outside this helper - the tests (intellisense_test, tedium_test, godot_workflow_test),
# the sibling dock/ helpers (menu_bar → `_quick_add` / `_run_from_sheet`; command_palette →
# `_run_from_sheet`), and the in-file context-menu dispatchers (`_open_insert_snippet` /
# `_open_save_snippet_dialog`) - so those callers resolve unchanged.
#
# CLOSURE NOTES (all self-contained - every lambda captures helper-local state and calls sibling
# helper methods that ALSO moved here):
#   • `_run_from_sheet`'s `_run_scene_menu.index_pressed` lambda captures the moved `_run_scene_menu`
#     and calls the moved `_play_scene_path`,
#   • `_open_save_snippet_dialog`'s three lambdas capture the moved `_snippet_name_window` and call
#     the moved `_confirm_save_snippet`,
#   • `_open_insert_snippet`'s two lambdas capture the moved `_snippet_list_window` / `_snippet_list`
#     and call the moved `_insert_snippet_path`.
#   Inside them only dock STATE / STAY-methods (`_current_sheet`, `add_child`, …) reach through `_dock.`.

var _dock: Control = null


func init(dock: Control) -> void:
	_dock = dock

# ── Quick-add bar ("type to insert") ──────────────────────────────────────


## Best ACE for a quick-add query. Leading words match a definition (display name / id,
## with the picker's synonym phrasing honored); trailing words fill its parameters
## positionally as raw values. Returns {definition, params} or {}.
func _quick_match(query: String) -> Dictionary:
	var ranked: Array = _quick_match_ranked(query, 1)
	if ranked.is_empty():
		return {}
	return {"definition": (ranked[0] as Dictionary).get("definition"), "params": (ranked[0] as Dictionary).get("params")}


## The ranked quick-add candidates for a query - the same scoring _quick_match uses, kept as a LIST so
## the Ghost Row can offer the top matches while the quick-add bar takes the best. Each entry is
## {definition, params, score}: exact name = 100, name + trailing params = 90, name-prefix = 60,
## substring = 40; a candidate whose kind matches `prefer_type` (the add key that summoned the ghost
## row: A prefers actions, C conditions, E triggers) earns +5 - a nudge WITHIN a quality band, never
## across one. Higher scores first; at equal score the verb the user has applied more often wins
## (learn-as-you-type), then shorter matched names (the query "process" should rank OnProcess above
## OnPhysicsProcess). Trailing words fill each candidate's own parameters positionally (quote-aware).
## Empty when nothing matches.
func _quick_match_ranked(query: String, limit: int = 5, prefer_type: int = -1) -> Array:
	var text: String = query.strip_edges().to_lower()
	if text.is_empty() or _dock._ace_registry == null:
		return []
	var queries: Array[String] = [text]
	for synonym_query: String in ACEPickerDialog._c3_synonym_queries(text):
		queries.append(synonym_query.to_lower())
	# The importer's names answer here too, by verb id - the quick-add bar compares ids as well as
	# names, so "go to layout" lands on ChangeScene exactly as it does in the picker. The phrase is
	# REPLACED by the id inside what was typed rather than added bare: "set value greeting 5" must
	# still carry "greeting 5" into the parameters, and a bare id would win as an exact match with
	# nothing to fill them. A phrase only held inside a longer one ("go to" of "go to layout") adds
	# nothing here, so a half-typed name never outranks what the reader actually wrote.
	var foreign: Dictionary = ACEPickerDialog.foreign_query_matches(text)
	for ace_id: String in foreign:
		var phrase: String = str(foreign[ace_id]).to_lower()
		if text.contains(phrase):
			var swapped: String = text.replace(phrase, ace_id.to_lower())
			if not queries.has(swapped):
				queries.append(swapped)
	var candidates: Array = []
	for definition: ACEDefinition in _dock._ace_registry.get_all_definitions():
		if bool(definition.metadata.get("hidden", false)):
			continue
		var best_score: int = 0
		var best_rest: String = ""
		var best_name_length: int = 1 << 30
		for candidate_name: String in [definition.display_name.to_lower(), definition.id.to_lower()]:
			if candidate_name.is_empty():
				continue
			for candidate_query: String in queries:
				var score: int = 0
				var rest: String = ""
				if candidate_query == candidate_name:
					score = 100
				elif candidate_query.begins_with(candidate_name + " "):
					score = 90
					rest = candidate_query.substr(candidate_name.length() + 1)
				elif candidate_name.begins_with(candidate_query):
					score = 60
				elif candidate_name.contains(candidate_query):
					score = 40
				if score > best_score or (score == best_score and candidate_name.length() < best_name_length):
					best_score = score
					best_rest = rest
					best_name_length = candidate_name.length()
		if best_score == 0:
			continue
		if prefer_type >= 0 and definition.ace_type == prefer_type:
			best_score += 5
		var params: Dictionary = {}
		var values: PackedStringArray = tokenize_quick_params(best_rest)
		for index in range(mini(values.size(), definition.parameters.size())):
			var parameter: Variant = definition.parameters[index]
			if parameter is Dictionary:
				params[str((parameter as Dictionary).get("id", ""))] = values[index]
		candidates.append({"definition": definition, "params": params, "score": best_score,
			"name_length": best_name_length,
			"usage": EventSheetAceUsageStats.count_for(definition.provider_id, definition.id)})
	# Ties are broken EXPLICITLY, because several packs can publish the same verb name (three of the
	# bundled packs ship a `Heal`) and sort_custom is not stable - without this the top suggestion for
	# such a word could differ between sessions, and adding an unrelated ACE elsewhere could silently
	# change it. Fewest parameters wins first: a verb the typed sentence can fill on its own beats one
	# that also needs a target. Provider + id settle anything still level, so the list is reproducible.
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["score"]) != int(b["score"]):
			return int(a["score"]) > int(b["score"])
		# Learn-as-you-type: at equal match quality the verb the user actually applies wins.
		# Deterministic for a given usage store, exactly like the provider|id tail below.
		if int(a["usage"]) != int(b["usage"]):
			return int(a["usage"]) > int(b["usage"])
		if int(a["name_length"]) != int(b["name_length"]):
			return int(a["name_length"]) < int(b["name_length"])
		var a_definition: ACEDefinition = a["definition"]
		var b_definition: ACEDefinition = b["definition"]
		if a_definition.parameters.size() != b_definition.parameters.size():
			return a_definition.parameters.size() < b_definition.parameters.size()
		return "%s|%s" % [a_definition.provider_id, a_definition.id] < "%s|%s" % [b_definition.provider_id, b_definition.id])
	return candidates.slice(0, limit)


## Splits a quick-add query's trailing parameter text into positional values, QUOTE-AWARE: a
## `"`-opened run stays ONE token with its quotes kept (param values are raw GDScript expressions, so
## a string param needs them), while unquoted runs split on spaces. The naive split(" ") mis-filled
## `play "jump land"` as two params ("jump / land"). Kept as the name the bar, the Ghost Row and the
## gate already call it by; the splitting itself lives with the rest of the quick-add reading, so
## the bar and the picker's own sentence filter cannot come to disagree about what one token is.
static func tokenize_quick_params(rest: String) -> PackedStringArray:
	return EventSheetQuickAdd.tokenize(rest)


## The ghost row's before-you-type suggestions: the most-used verbs of the kind the add key
## asked for ("event" = triggers, "condition" = conditions, anything else = actions), most
## used first. With no usage history yet the picker's featured verbs of that kind stand in,
## so the chips teach the everyday vocabulary from the first session. Deterministic: usage
## desc, then featured first, then provider|id. Returns ACEDefinitions.
func suggested_definitions(origin: String, limit: int = 4) -> Array:
	if _dock._ace_registry == null:
		return []
	var wanted: int = ACEDefinition.ACEType.ACTION
	if origin == "event":
		wanted = ACEDefinition.ACEType.TRIGGER
	elif origin == "condition":
		wanted = ACEDefinition.ACEType.CONDITION
	var scored: Array = []
	for definition: ACEDefinition in _dock._ace_registry.get_all_definitions():
		if definition.ace_type != wanted or bool(definition.metadata.get("hidden", false)):
			continue
		var usage: int = EventSheetAceUsageStats.count_for(definition.provider_id, definition.id)
		var featured: bool = bool(definition.metadata.get("featured", false)) \
			or ACEPickerDialog.FEATURED.has("%s/%s" % [definition.provider_id, definition.id])
		if usage == 0 and not featured:
			continue
		scored.append({"definition": definition, "usage": usage, "featured": featured})
	scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["usage"]) != int(b["usage"]):
			return int(a["usage"]) > int(b["usage"])
		if bool(a["featured"]) != bool(b["featured"]):
			return bool(a["featured"])
		var a_definition: ACEDefinition = a["definition"]
		var b_definition: ACEDefinition = b["definition"]
		return "%s|%s" % [a_definition.provider_id, a_definition.id] < "%s|%s" % [b_definition.provider_id, b_definition.id])
	var out: Array = []
	# The open script's OWN functions lead the chips when the add key means an action: a file's own
	# verbs are the vocabulary its author reaches for first, and they exist in no usage table and no
	# featured list. Capped at half the row so the everyday verbs below are never pushed off entirely.
	if wanted == ACEDefinition.ACEType.ACTION:
		var own_functions: Array = ACEPickerDialog.function_call_definitions(_dock._current_sheet, _dock._ace_registry)
		for definition: ACEDefinition in own_functions.slice(0, maxi(1, limit / 2)):
			out.append(definition)
	for entry: Dictionary in scored.slice(0, maxi(0, limit - out.size())):
		out.append(entry["definition"])
	return out


## Applies the best match: triggers/conditions become a new event; actions append via the
## standard apply flow (below the current selection). Returns true when something landed.
func _quick_add(query: String) -> bool:
	if not _dock._ensure_sheet_for_editing():
		return false
	var matched: Dictionary = _quick_match(query)
	if matched.is_empty():
		_dock._set_status("Quick add: nothing matches \"%s\"." % query.strip_edges(), true)
		return false
	var definition: ACEDefinition = matched.get("definition")
	var selected_resource: Resource = _dock._active_view().get_selected_context().get("source_resource", null)
	# An action lands ON the selected event (append_action - same as the toolbar's Add Action);
	# "" was falling into the apply's default branch, which wraps the action in a NEW event -
	# the fallback that's only right when nothing is selected.
	var mode: String = "new_condition_event"
	if definition.ace_type == ACEDefinition.ACEType.ACTION:
		mode = "append_action" if selected_resource is EventRow else ""
	var context: Dictionary = {
		"mode": mode,
		"selected_resource": selected_resource
	}
	_dock._apply_ace_definition(definition, matched.get("params", {}), context)
	return true

# ── Run Scene - sheet → playing game in one click ──────────────────────────
var _run_scene_menu: PopupMenu = null


## Sheet → playing game in one click: save (compile-on-save keeps the script fresh),
## find the scene(s) attaching this sheet's script (the doctor's reverse lookup),
## play the only one - or offer the pick menu.
func _run_from_sheet() -> void:
	if _dock._current_sheet == null:
		return
	if _dock._current_sheet.behavior_mode:
		_dock._set_status("Behaviors run on a host - use Tools → Test Bench.", true)
		return
	_dock._on_save_requested()
	if _dock._current_sheet_path.is_empty():
		return  # Unsaved sheet: the Save As flow took over.
	var script_path: String = _run_target_script_path()
	var scenes: PackedStringArray = EventSheetProjectDoctor.scenes_attaching(script_path)
	if scenes.is_empty():
		_dock._set_status("No scene attaches %s yet - attach it to a scene and run again." % script_path.get_file(), true)
		return
	if scenes.size() == 1:
		_play_scene_path(scenes[0])
		return
	if _run_scene_menu == null:
		_run_scene_menu = PopupMenu.new()
		_run_scene_menu.index_pressed.connect(func(index: int) -> void:
			_play_scene_path(str(_run_scene_menu.get_item_metadata(index))))
		_dock.add_child(_run_scene_menu)
	_run_scene_menu.clear()
	for scene_path: String in scenes:
		_run_scene_menu.add_item(scene_path.get_file())
		_run_scene_menu.set_item_metadata(_run_scene_menu.item_count - 1, scene_path)
	_run_scene_menu.popup(Rect2i(Vector2i(_dock.get_screen_transform() * _dock.get_local_mouse_position()), Vector2i(0, 0)))


## The script scenes actually attach for this sheet: GDScript-backed sheets ARE their
## .gd (review catch: pairing-rule resolution would invent <name>_generated.gd for
## them); .tres sheets resolve through the pairing rule.
func _run_target_script_path() -> String:
	if _dock._current_sheet != null and not _dock._current_sheet.external_source_path.is_empty():
		return _dock._current_sheet.external_source_path
	return EventSheetProjectDoctor.output_path_for(_dock._current_sheet_path)


func _play_scene_path(scene_path: String) -> void:
	if Engine.is_editor_hint() and _dock.is_inside_tree():
		EditorInterface.play_custom_scene(scene_path)
	_dock._set_status("Running %s." % scene_path.get_file())

# ── Row snippets - save the selection, insert from the project library
# (EventSheetSnippetLibrary; the clipboard text format is the file format) ────────────
const INSERT_SNIPPET_DIALOG_PATH := "res://addons/eventsheet/editor/dock/insert_snippet_dialog.gd"
var _snippet_name_dialog: ConfirmationDialog = null
var _snippet_name_edit: LineEdit = null
var _snippet_name_note: EventSheetPopupUI.StateNote = null
var _snippet_name_strip: EventSheetPopupUI.HelpStrip = null


func _open_save_snippet_dialog() -> void:
	var count: int = _dock._top_level_selected_resources().size()
	if count == 0:
		_dock._set_status("Select rows to save as a snippet.", true)
		return
	if _snippet_name_dialog == null:
		_snippet_name_dialog = ConfirmationDialog.new()
		_snippet_name_dialog.ok_button_text = EventSheetL10n.translate("Save to the project snippet library")
		_snippet_name_dialog.dialog_hide_on_ok = false
		_snippet_name_dialog.confirmed.connect(_confirm_save_snippet)
		var form: VBoxContainer = EventSheetPopupUI.form_box()
		_snippet_name_edit = LineEdit.new()
		_snippet_name_edit.placeholder_text = "fade_and_free"
		_snippet_name_edit.text_changed.connect(func(_typed: String) -> void: _refresh_snippet_name())
		_snippet_name_dialog.register_text_enter(_snippet_name_edit)
		var card: VBoxContainer = EventSheetPopupUI.form_box()
		card.add_child(EventSheetPopupUI.form_row(EventSheetL10n.translate("Name"), _snippet_name_edit))
		form.add_child(EventSheetPopupUI.titled_card(EventSheetL10n.translate("Snippet"), card))
		_snippet_name_note = EventSheetPopupUI.StateNote.new(EventSheetPalette.scaled_f(360.0))
		form.add_child(_snippet_name_note)
		_snippet_name_strip = EventSheetPopupUI.help_strip(EventSheetL10n.translate("Name"),
			EventSheetL10n.translate("Insert Snippet… lists it by this name."), "", "", EventSheetPalette.scaled_f(360.0))
		var strip: EventSheetPopupUI.HelpStrip = _snippet_name_strip
		strip.follow(_snippet_name_edit, EventSheetL10n.translate("Name"),
			EventSheetL10n.translate("Insert Snippet… lists it by this name."))
		form.add_child(strip)
		_snippet_name_dialog.add_child(EventSheetPopupUI.margined(form))
		_dock.add_child(_snippet_name_dialog)
	_snippet_name_dialog.title = EventSheetL10n.translate("Save {n} row(s) as a snippet").replace("{n}", str(count))
	_refresh_snippet_name()
	if _dock.is_inside_tree():
		_snippet_name_dialog.popup_centered(Vector2i(int(EventSheetPalette.scaled_f(420.0)), 0))
		_snippet_name_edit.grab_focus()


## Says before Save what the name will do: nothing to save under yet, or a name the library already
## has - which is kept, and this one written beside it under the next free file name.
func _refresh_snippet_name() -> void:
	var snippet_name: String = _snippet_name_edit.text.strip_edges()
	_snippet_name_dialog.get_ok_button().disabled = snippet_name.is_empty()
	var taken: String = EventSheetSnippetLibrary.snippet_path_for(snippet_name)
	# The file it will be written to, where the strip shows code everywhere else.
	_snippet_name_strip.set_reading("", "" if snippet_name.is_empty() else EventSheetSnippetLibrary.free_path_for(snippet_name))
	if snippet_name.is_empty() or not FileAccess.file_exists(taken):
		_snippet_name_note.say("")
		return
	_snippet_name_note.say(EventSheetL10n.translate("{name} already exists - this writes {file}.").replace(
		"{name}", taken.get_file().get_basename()).replace(
		"{file}", EventSheetSnippetLibrary.free_path_for(snippet_name).get_file()), EventSheetPopupUI.TONE_WARNING)


func _confirm_save_snippet() -> void:
	var saved: String = _save_selection_snippet_named(_snippet_name_edit.text.strip_edges())
	if not saved.is_empty():
		_snippet_name_dialog.hide()


## The testable save core: serializes the top-level selection with the SAME serializer Copy uses and
## files it in the library - under the next free name when the name is taken, which the window has
## already said. Returns the path, or "" on a problem.
func _save_selection_snippet_named(snippet_name: String) -> String:
	var targets: Array = _dock._top_level_selected_resources()
	if targets.is_empty() or snippet_name.is_empty():
		_dock._set_status("Name the snippet and select at least one row.", true)
		return ""
	var path: String = EventSheetSnippetLibrary.save_snippet(snippet_name, EventSheetSnippet.serialize_rows(targets, _dock._current_sheet))
	if path.is_empty():
		_dock._set_status("Couldn't write the snippet.", true)
		return ""
	if Engine.is_editor_hint() and _dock.is_inside_tree():
		EditorInterface.get_resource_filesystem().scan()
	_dock._set_status("Snippet saved: %s - Insert Snippet… lists it now." % path)
	return path


## The name a snippet is listed and titled by: its file's name exactly as saved, never re-cased.
static func snippet_label(snippet_path: String) -> String:
	return snippet_path.get_file().get_basename()


func _open_insert_snippet() -> ConfirmationDialog:
	var snippets: PackedStringArray = EventSheetSnippetLibrary.list_snippets()
	if snippets.is_empty():
		_dock._set_status("No snippets yet - select rows and Save Selection as Snippet… first.", true)
		return null
	return load(INSERT_SNIPPET_DIALOG_PATH).open_for(_dock, snippets)


## Insert one snippet by path. A snippet with BLANKS ({{blank:Label}}) opens the Insert Snippet window
## on it, so its fields are filled first; any other one lands straight away through the normal paste
## (fresh uids, missing variables created - the whole paste contract for free).
func _insert_snippet_path(snippet_path: String) -> void:
	var snippet_text: String = EventSheetSnippetLibrary.read_snippet(snippet_path)
	if EventSheetSnippet.has_blanks(snippet_text):
		var dialog: ConfirmationDialog = load(INSERT_SNIPPET_DIALOG_PATH).open_for(_dock, EventSheetSnippetLibrary.list_snippets())
		dialog.call("select_snippet", snippet_path)
		return
	if not _dock._paste_snippet_text(snippet_text):
		_dock._set_status("That file isn't a sheet snippet: %s" % snippet_path.get_file(), true)
