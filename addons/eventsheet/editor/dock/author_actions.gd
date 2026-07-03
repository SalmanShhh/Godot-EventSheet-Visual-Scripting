@tool
class_name EventSheetAuthorActions
extends RefCounted
# Surface-level authoring shortcuts driven from the toolbar / menu / context-menu — the quick-add
# bar's fuzzy match+apply, Run Scene, and Save/Insert row Snippets. This helper owns:
#   • the quick-add bar's brain: _quick_match (best-ACE fuzzy match of a "type to insert" query,
#     honoring the picker's synonym phrasing, filling parameters positionally) and _quick_add (apply
#     the match — triggers/conditions become a new event, actions append via the standard flow),
#   • Run Scene: save-then-play the scene(s) attaching this sheet's script (the doctor's reverse
#     lookup; single scene plays, multiple offer a pick menu),
#   • row Snippets: Save Selection as Snippet… (serialize the top-level selection into the project
#     library) and Insert Snippet… (paste a library snippet back — fresh uids, missing variables
#     created), each with its own small dialog Window.
#
# Extracted from event_sheet_dock.gd to keep that file maintainable.
#
# WHAT STAYS ON THE DOCK (reached here through `_dock`):
#   • the quick-add WIDGET `_quick_add_edit` — it stays declared on the dock and is built + assigned
#     by menu_bar.gd; its text_submitted closure calls `_dock._quick_add(text)` (the dock delegate),
#   • `_paste_snippet_text` — it lives in the dock's copy/paste cluster (paste flow + snippet_share_test
#     call it); `_insert_snippet_path` reaches it via `_dock._paste_snippet_text`,
#   • the seam the moved bodies lean on: `_ensure_sheet_for_editing`, `_apply_ace_definition`,
#     `_ace_registry`, `_active_view`, `_top_level_selected_resources`, `_on_save_requested`,
#     `_current_sheet` / `_current_sheet_path`, `_set_status`, `_perform_undoable_sheet_edit`,
#     `add_child`, `is_inside_tree`, `get_global_mouse_position`.
# Globals (EventSheetProjectDoctor, EventSheetSnippetLibrary, EventSheetSnippet, ACEPickerDialog,
# ACEDefinition, EditorInterface, Engine) are unchanged.
#
# The dock keeps thin one-line delegates (original names + signatures + returns) for every method
# reached from outside this helper — the tests (intellisense_test, tedium_test, godot_workflow_test),
# the sibling dock/ helpers (menu_bar → `_quick_add` / `_run_from_sheet`; command_palette →
# `_run_from_sheet`), and the in-file context-menu dispatchers (`_open_insert_snippet` /
# `_open_save_snippet_dialog`) — so those callers resolve unchanged.
#
# CLOSURE NOTES (all self-contained — every lambda captures helper-local state and calls sibling
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


## The ranked quick-add candidates for a query — the same scoring _quick_match uses, kept as a LIST so
## the Ghost Row can offer the top matches while the quick-add bar takes the best. Each entry is
## {definition, params, score}: exact name = 100, name + trailing params = 90, name-prefix = 60,
## substring = 40; higher scores first, and shorter matched names break ties (the query "process"
## should rank OnProcess above OnPhysicsProcess). Trailing words fill each candidate's own parameters
## positionally (quote-aware). Empty when nothing matches.
func _quick_match_ranked(query: String, limit: int = 5) -> Array:
	var text: String = query.strip_edges().to_lower()
	if text.is_empty() or _dock._ace_registry == null:
		return []
	var queries: Array[String] = [text]
	for synonym_query: String in ACEPickerDialog._c3_synonym_queries(text):
		queries.append(synonym_query.to_lower())
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
		var params: Dictionary = {}
		var values: PackedStringArray = tokenize_quick_params(best_rest)
		for index in range(mini(values.size(), definition.parameters.size())):
			var parameter: Variant = definition.parameters[index]
			if parameter is Dictionary:
				params[str((parameter as Dictionary).get("id", ""))] = values[index]
		candidates.append({"definition": definition, "params": params, "score": best_score, "name_length": best_name_length})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["score"]) != int(b["score"]):
			return int(a["score"]) > int(b["score"])
		return int(a["name_length"]) < int(b["name_length"]))
	return candidates.slice(0, limit)


## Splits a quick-add query's trailing parameter text into positional values, QUOTE-AWARE: a
## `"`-opened run stays ONE token with its quotes kept (param values are raw GDScript expressions, so
## a string param needs them), while unquoted runs split on spaces. The naive split(" ") mis-filled
## `play "jump land"` as two params ("jump / land"). An unterminated quote is forgiven — the rest of
## the text becomes the final token. Static + pure (headless-testable); the same tokenizer the Ghost
## Row's zero-dialog add reuses.
static func tokenize_quick_params(rest: String) -> PackedStringArray:
	var tokens: PackedStringArray = PackedStringArray()
	var current: String = ""
	var in_quotes: bool = false
	for character in rest:
		if character == "\"":
			in_quotes = not in_quotes
			current += character
		elif character == " " and not in_quotes:
			if not current.is_empty():
				tokens.append(current)
				current = ""
		else:
			current += character
	if not current.is_empty():
		tokens.append(current)
	return tokens


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
	# An action lands ON the selected event (append_action — same as the toolbar's Add Action);
	# "" was falling into the apply's default branch, which wraps the action in a NEW event —
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

# ── Run Scene — sheet → playing game in one click ──────────────────────────
var _run_scene_menu: PopupMenu = null


## Sheet → playing game in one click: save (compile-on-save keeps the script fresh),
## find the scene(s) attaching this sheet's script (the doctor's reverse lookup),
## play the only one — or offer the pick menu.
func _run_from_sheet() -> void:
	if _dock._current_sheet == null:
		return
	if _dock._current_sheet.behavior_mode:
		_dock._set_status("Behaviors run on a host — use Tools → Test Bench.", true)
		return
	_dock._on_save_requested()
	if _dock._current_sheet_path.is_empty():
		return  # Unsaved sheet: the Save As flow took over.
	var script_path: String = _run_target_script_path()
	var scenes: PackedStringArray = EventSheetProjectDoctor.scenes_attaching(script_path)
	if scenes.is_empty():
		_dock._set_status("No scene attaches %s yet — attach it to a scene and run again." % script_path.get_file(), true)
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
	_run_scene_menu.popup(Rect2i(Vector2i(_dock.get_global_mouse_position()), Vector2i(0, 0)))


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

# ── Row snippets — save the selection, insert from the project library
# (EventSheetSnippetLibrary; the clipboard text format is the file format) ────────────
var _snippet_name_window: Window = null
var _snippet_name_edit: LineEdit = null
var _snippet_list_window: Window = null
var _snippet_list: ItemList = null


func _open_save_snippet_dialog() -> void:
	if _dock._top_level_selected_resources().is_empty():
		_dock._set_status("Select rows to save as a snippet.", true)
		return
	if _snippet_name_window == null:
		_snippet_name_window = Window.new()
		_snippet_name_window.title = "Save Selection as Snippet"
		_snippet_name_window.size = Vector2i(360, 100)
		_snippet_name_window.close_requested.connect(func() -> void: _snippet_name_window.hide())
		var box: VBoxContainer = VBoxContainer.new()
		box.set_anchors_preset(Control.PRESET_FULL_RECT)
		_snippet_name_edit = LineEdit.new()
		_snippet_name_edit.placeholder_text = "Snippet name (e.g. fade_and_free)"
		_snippet_name_edit.text_submitted.connect(func(_t: String) -> void: _confirm_save_snippet())
		box.add_child(_snippet_name_edit)
		var save_button: Button = Button.new()
		save_button.text = "Save to the project snippet library"
		save_button.pressed.connect(_confirm_save_snippet)
		box.add_child(save_button)
		_snippet_name_window.add_child(box)
		_dock.add_child(_snippet_name_window)
	_snippet_name_window.popup_centered()
	_snippet_name_edit.grab_focus()


func _confirm_save_snippet() -> void:
	var saved: String = _save_selection_snippet_named(_snippet_name_edit.text.strip_edges())
	if not saved.is_empty():
		_snippet_name_window.hide()


## The testable save core: serializes the top-level selection with the SAME serializer
## Copy uses and files it in the library. Returns the path, or "" on a problem.
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
	_dock._set_status("Snippet saved: %s — Insert Snippet… lists it now." % path)
	return path


func _open_insert_snippet() -> void:
	var snippets: PackedStringArray = EventSheetSnippetLibrary.list_snippets()
	if snippets.is_empty():
		_dock._set_status("No snippets yet — select rows and Save Selection as Snippet… first.", true)
		return
	if _snippet_list_window == null:
		_snippet_list_window = Window.new()
		_snippet_list_window.title = "Insert Snippet"
		_snippet_list_window.size = Vector2i(380, 320)
		_snippet_list_window.close_requested.connect(func() -> void: _snippet_list_window.hide())
		_snippet_list = ItemList.new()
		_snippet_list.set_anchors_preset(Control.PRESET_FULL_RECT)
		_snippet_list.item_activated.connect(func(index: int) -> void:
			_insert_snippet_path(str(_snippet_list.get_item_metadata(index)))
			_snippet_list_window.hide())
		_snippet_list_window.add_child(_snippet_list)
		_dock.add_child(_snippet_list_window)
	_snippet_list.clear()
	for snippet_path: String in snippets:
		_snippet_list.add_item(snippet_path.get_file().get_basename().capitalize())
		_snippet_list.set_item_metadata(_snippet_list.item_count - 1, snippet_path)
		_snippet_list.set_item_tooltip(_snippet_list.item_count - 1, snippet_path)
	_snippet_list_window.popup_centered()


## Insert = the normal snippet paste (fresh uids, missing variables created — the
## whole paste contract for free).
func _insert_snippet_path(snippet_path: String) -> void:
	if not _dock._paste_snippet_text(EventSheetSnippetLibrary.read_snippet(snippet_path)):
		_dock._set_status("That file isn't a sheet snippet: %s" % snippet_path.get_file(), true)
