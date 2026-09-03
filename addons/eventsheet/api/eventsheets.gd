@tool
class_name EventSheets
extends RefCounted
# ═══════════════════════════════════════════════════════════════════════════════════════
# The PUBLIC API for building on top of Godot EventSheets.
#
# Everything here is a compatibility promise (like ace_ids and codegen templates):
# method names and shapes are stable once shipped - new capabilities are added, existing
# ones are never renamed. Tool scripts, other plugins, and the plugin's OWN features call
# through this one class instead of reaching into editor internals, so extensions keep
# working across refactors of the dock/viewport.
#
# Three groups of services:
#
#   VOCABULARY - add words to the language. Register a provider script (its methods,
#   signals, and exported vars become ACEs), register a Custom Block kind (a new row
#   type with byte-gated round-trip), look definitions up, or reflect any engine /
#   class_name class into vocabulary on demand.
#
#   EDITOR - drive the live editor. Read the current sheet, open one, mutate it through
#   edit() (THE undo funnel: your change is one undo step, and you must re-fetch rows
#   from the live sheet afterwards - commits replace resources with snapshot duplicates),
#   set the status line, and add your own Command Palette entries.
#
#   CODEGEN - the compiler and importer as plain services, dock-free: compile a sheet to
#   GDScript, open GDScript back as a sheet, or byte-verify a round-trip - the same gate
#   the plugin's own lifts must pass.
#
#   PROJECT HEALTH - the Doctor as a service: run the whole audit, or register your own
#   check so it runs everywhere the Doctor runs (dock panel, headless CLI, CI, MCP).
#
# Editor services require the EventSheet dock to be open (they no-op safely headless and
# return null/false); vocabulary, codegen and health services work anywhere, including tests.
# ═══════════════════════════════════════════════════════════════════════════════════════

## The live dock, registered by the dock itself at setup. Weak by contract: every use
## checks validity, so a closed workspace never leaves the API pointing at a freed node.
static var _dock: Control = null

## Palette entries registered from code: Array of {"title": String, "run": Callable}.
## The Command Palette appends these after the built-in commands on every open.
static var _palette_commands: Array[Dictionary] = []


# ── Vocabulary ─────────────────────────────────────────────────────────────────────────


## Registers a @tool class_name script as an ACE provider: its public methods, signals,
## and @export vars become actions/conditions/expressions/triggers (see the Custom ACEs
## guide for the annotation and registrar dialects). Project-wide; idempotent.
static func register_provider_script(script_path: String) -> bool:
	if script_path.strip_edges().is_empty():
		return false
	if _dock_alive():
		return _dock.add_ace_provider_script(script_path)
	EventForgeBridgeRuntime.register_provider_script(script_path)
	return true


## Registers a Custom Block kind (a new NON-ACE row type: markers, notes, data blocks).
## The kind gets the Add menu, Command Palette, edit dialog, compile and lift wiring
## automatically; its round-trip is byte-verify gated like every built-in.
static func register_block_kind(kind: EventSheetBlockKind) -> void:
	EventSheetBlockRegistry.register_kind(kind)


## Builds a Custom Block kind from a plain Dictionary, so a beginner never has to subclass:
##   {"kind_id": "my_pack.note", "title": "Note", "category": "Blocks",
##    "fields": [{"id": "text", "label": "Text", "type": TYPE_STRING, "default": "hi"}],
##    "emit": "## NOTE: {text}", "summary": "note: {text}"}
## `emit` is a template (one output line per line of the string) with {field} placeholders; `summary`
## is the one-line viewport display. Forward emission and the summary work immediately; pass an
## optional `lift` Callable (func(lines, i) -> Dictionary) for reverse recovery, else the block still
## emits perfectly and re-imports as a verbatim GDScript block. Register the result with
## register_block_kind(). See the Custom Blocks guide for the field types and the byte-gate.
static func simple_block_kind(config: Dictionary) -> EventSheetBlockKind:
	var kind: EventSheetSimpleBlockKind = EventSheetSimpleBlockKind.new()
	kind.kind_id = str(config.get("kind_id", ""))
	kind.title = str(config.get("title", kind.kind_id))
	kind.category = str(config.get("category", "Blocks"))
	var schema: Array[Dictionary] = []
	for field: Variant in config.get("fields", []):
		if field is Dictionary:
			schema.append(param_spec(field as Dictionary))
	kind.field_schema = schema
	kind.emit_template = str(config.get("emit", ""))
	kind.summary_template = str(config.get("summary", ""))
	var lift_value: Variant = config.get("lift", null)
	if lift_value is Callable:
		kind.lift_callable = lift_value
	return kind


## Looks a definition up in the live editor's registry ("Core", "Print"). Editor-only:
## returns null when no dock is open.
static func find_ace(provider_id: String, ace_id: String) -> ACEDefinition:
	if not _dock_alive():
		return null
	return _dock._ace_registry.find_definition(provider_id, ace_id)


## Reflects ANY class - engine or class_name script - into browsable vocabulary: methods
## classify by return type, signals become triggers, editor properties become Set/Get
## pairs. Session-cached shared instances; treat the definitions as IMMUTABLE.
static func class_vocabulary(target_class: String) -> Array[ACEDefinition]:
	# A COPY of the session cache's array: the definitions themselves are shared and
	# immutable by contract, but handing out the backing array let a caller's append or
	# clear corrupt the cache for every other consumer.
	return EventSheetClassDBSource.definitions_for_class(target_class).duplicate()


## The classes THIS project publishes (global `class_name` scripts + autoloads) as scan
## entries {name, path, kind, autoload} - the input set behind the picker's Your Project
## section. Node-derived only: data classes and helpers are reachable in expressions, but
## nobody picks an action on them.
static func project_classes() -> Array:
	return EventSheetProjectScanner.list_project_classes()


## Refines how a REFLECTED verb presents - `{"display_name": "Deal Damage"}`,
## `{"category": "Combat"}`, `{"hidden": true}` - stored in the project's override catalog,
## never in the user's script. Passing null (or "") for a field clears it.
##
## Presentation only: ids and emitted calls never change, so deleting the catalog restores
## the inferred vocabulary and leaves every compiled sheet byte-identical. A verb whose
## identity comes from `@ace_*` annotations is not affected - the source outranks the
## catalog.
static func override_verb(provider_id: String, ace_id: String, edits: Dictionary) -> void:
	EventSheetVocabularyCatalog.set_override(provider_id, ace_id, edits)


## Hides (or restores) a whole reflected class: its card and all its verbs.
static func exclude_class(class_id: String, excluded: bool = true) -> void:
	EventSheetVocabularyCatalog.set_class_excluded(class_id, excluded)


## Writes a class's catalog overrides INTO its script as `## @ace_*` annotations, making the
## script self-describing for teammates and for anyone who never opens this editor.
##
## Uses the same safe write every curation takes - the file is backed up first, only `##`
## comment lines are added or removed, no signature or body is touched, and re-applying is a
## no-op. On success the baked overrides are dropped from the catalog, because the source now
## owns those facts and source outranks the catalog; keeping both would be a second truth
## that silently does nothing.
##
## Returns curate_provider's result ({ok, reason, changed, skipped, backup}), plus "baked":
## how many overrides were actually WRITTEN into the file.
##
## Only the members the writer could anchor are cleared from the catalog. The writer reports
## a member it could not find in `skipped` while still returning ok (a partial write is not a
## failure), so clearing the whole class on ok would DESTROY curation that never reached the
## file - and with the wrong script_path, every edit skips, the source is unchanged, the
## write short-circuits as "Already up to date", and the entire class's overrides would go
## with no backup taken. Data loss on a success path is the worst failure this feature could
## have, so the clear is per-member and driven by what the writer confirms it wrote.
static func bake_overrides(script_path: String, class_id: String) -> Dictionary:
	var edits: Array = EventSheetVocabularyCatalog.bake_edits_for(class_id)
	if edits.is_empty():
		return {"ok": true, "reason": "Nothing to bake - this class has no overrides.", "baked": 0,
			"changed": 0, "skipped": [], "backup": ""}
	var result: Dictionary = curate_provider(script_path, edits)
	if not bool(result.get("ok", false)):
		result["baked"] = 0
		return result
	var skipped: Array = result.get("skipped", [])
	var written: Array = []
	for edit: Variant in edits:
		if not skipped.has(str((edit as Dictionary).get("member", ""))):
			written.append(edit)
	result["baked"] = written.size()
	EventSheetVocabularyCatalog.clear_baked_overrides(class_id, written)
	if written.is_empty():
		result["reason"] = "Nothing was written: none of those members were found in %s, so every override was kept." % script_path.get_file()
	elif not skipped.is_empty():
		result["reason"] = "Baked %d; kept %d whose member was not found in the script." % [written.size(), skipped.size()]
	return result


# ── Editor ─────────────────────────────────────────────────────────────────────────────


## The sheet open in the active editor tab, or null (no dock / no sheet).
static func current_sheet() -> EventSheetResource:
	if not _dock_alive():
		return null
	return _dock.get_current_sheet()


## Makes the toolbar control with this exact label pulse, so a step that says "click Add Action"
## points at the button. False when the workspace is closed or carries no such control.
static func pulse_control(control_label: String) -> bool:
	if not _dock_alive():
		return false
	return bool(_dock.pulse_control(control_label))


## Puts the keyboard focus back on the sheet itself - what Esc in the Manual means. False when no
## workspace is open.
static func focus_sheet() -> bool:
	if not _dock_alive():
		return false
	var view: Control = _dock.get("_viewport") as Control
	if view == null:
		return false
	view.grab_focus()
	return true


## Opens a sheet (.gd or .tres) in the editor. Returns false when no dock is open.
static func open_sheet(path: String) -> bool:
	if not _dock_alive():
		return false
	_dock._load_sheet_from_path(path)
	return true


## THE way to mutate the current sheet from an extension: `mutation` receives the live
## EventSheetResource, and the whole change lands as ONE undo step with the given label,
## followed by a rebuild and a dirty mark. Return false from `mutation` to signal
## "nothing changed" (no undo step, no dirty). RULES: never cache rows across calls -
## the funnel's commit replaces resources with snapshot duplicates, so re-fetch from
## current_sheet() every time.
static func edit(label: String, mutation: Callable) -> bool:
	if not _dock_alive() or not mutation.is_valid():
		return false
	var changed: bool = _dock._perform_undoable_sheet_edit(label, func() -> bool:
		var result: Variant = mutation.call(_dock._current_sheet)
		return bool(result) if result is bool else true)
	if changed:
		_dock._refresh_after_edit()
		_dock._mark_dirty(label)
	return changed


## Signal-to-sheet connect (the "wire a signal into events" flow the Node dock uses):
## appends an On <Signal> trigger event to the CURRENT sheet. Core signals map to their
## named triggers (body_entered becomes On Body Entered); anything else becomes a
## signal:<name> trigger with the argument signature baked so the handler emits with the
## right parameters. Returns false when the workspace is closed.
static func add_trigger_for_signal(signal_name: String, args_signature: String = "") -> bool:
	return edit("Connect Signal: %s" % signal_name, func(sheet: EventSheetResource) -> bool:
		sheet.events.append(build_signal_trigger_event(signal_name, args_signature))
		return true)


## The trigger event for one signal - pure and static so tests pin the mapping. Core
## signals get their named trigger id (no args needed - the compiler knows their
## signatures); everything else rides the generic signal:<name> trigger with args baked.
static func build_signal_trigger_event(signal_name: String, args_signature: String = "") -> EventRow:
	var row: EventRow = EventRow.new()
	if EventSheetACELifter.CORE_SIGNAL_TRIGGERS.has(signal_name):
		row.trigger_provider_id = "Core"
		row.trigger_id = str(EventSheetACELifter.CORE_SIGNAL_TRIGGERS[signal_name])
	else:
		row.trigger_provider_id = ""
		row.trigger_id = "signal:%s" % signal_name
		row.trigger_args = args_signature
	return row


## Every signal a node offers (script signals AND its native class's), each as
## {"name": String, "args": String} where args is the baked handler signature
## ("body: Node" style - the exact format trigger_args expects). The connect-signal
## dialog lists these; also handy for tooling that reflects over a scene.
static func signals_of(node: Object) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if node == null:
		return out
	for signal_info: Dictionary in node.get_signal_list():
		var parts: PackedStringArray = PackedStringArray()
		for arg: Dictionary in signal_info.get("args", []):
			var arg_name: String = str(arg.get("name", ""))
			var arg_type: int = int(arg.get("type", TYPE_NIL))
			var arg_class: String = str(arg.get("class_name", ""))
			if not arg_class.is_empty():
				parts.append("%s: %s" % [arg_name, arg_class])
			elif arg_type != TYPE_NIL:
				parts.append("%s: %s" % [arg_name, type_string(arg_type)])
			else:
				parts.append(arg_name)
		out.append({"name": str(signal_info.get("name", "")), "args": ", ".join(parts)})
	return out


## Writes to the editor's status line (is_error tints it as a problem).
static func set_status(text: String, is_error: bool = false) -> void:
	if _dock_alive():
		_dock._set_status(text, is_error)


## Reports a runtime error from a running game in the SHEET's words: the source map says which row
## the failing generated line came from, and the row's own reading says what it was trying to do,
## so "Attempt to call function 'hit' in base 'null instance'" is said again as
## "player.gd · event 12 · Enemy ▸ Call Hit: target is empty (nothing was picked before this
## action)" - on the strip under the sheet and in the Output panel, with Jump to event, Explain and
## Godot's own message beside it. Returns the report ({sentence, translated, said, why, explain,
## original}), or an empty Dictionary when no dock is open.
static func report_runtime_error(message: String, script_path: String, line: int = 0) -> Dictionary:
	if not _dock_alive():
		return {}
	return _dock.report_runtime_error(message, script_path, line)


## Rebuilds the editor's rows from the current sheet (after out-of-funnel changes;
## prefer edit(), which refreshes for you).
static func refresh() -> void:
	if _dock_alive():
		_dock._refresh_after_edit()


## Builds a sheet-native CONDITION/ACTION row so a construct reads as an EVENT, not a text blob - the model
## the whole tool is built on. The discriminating text (a pattern, a guard, a case) goes in the CONDITION
## cell; each `action_lines` entry is an ACTION cell. Returns an EventRowData laid out with the condition |
## action lane divider (or null with no dock). This is the primitive for mapping ANY feature onto the event
## model: the built-in switch/case dogfoods it for its case rows, and a Custom Block's renderer can return
## these so its rows read as events. `source` is the resource a double-click on the row should route to.
static func build_condition_action_row(condition_text: String, action_lines: PackedStringArray, indent: int = 0, source: Resource = null) -> EventRowData:
	if not _dock_alive():
		return null
	var view: EventSheetViewport = _dock._active_view()
	if view == null:
		return null
	return view._row_builder._build_condition_action_row(condition_text, action_lines, indent, source)


## Marks a row as a LANGUAGE block - a row that renders a GDScript construct (a class, a switch case, a
## host binding...) rather than a regular ACE event. The viewport draws such rows with a quiet accent
## stripe + faint wash (the theme's `language_block_accent_color`), so the distinction reads at a glance
## without dimming the row. Returns the same row, so it chains:
## `EventSheets.mark_language_block(EventSheets.build_condition_action_row("case X", lines))`.
## Use it whenever a Custom Block or a feature renders language structure as event rows - every built-in
## language block (data class, methods class, switch case, host binding) carries the same mark.
static func mark_language_block(row: EventRowData) -> EventRowData:
	if row != null:
		row.language_block = true
	return row


## Appends a condition-style CELL to a row: a filled chip whose `label` leads it (the bold lead a
## condition uses for its object) and whose `text` says what the slot holds, stacked one per line down
## the condition lane. Use it for any construct with NAMED SLOTS - a resource's fields, a block's
## options - so they read as cells you click, not as text beside a title. A published verb's parameters
## dogfood this exact call. `metadata` merges over the defaults: carry your own `kind` and an index
## there, and the same `kind` in your row-menu / edit handling routes the click back. Chains:
## `EventSheets.add_field_cell(EventSheets.add_field_cell(row, "id", "text"), "seconds", "number")`.
static func add_field_cell(row: EventRowData, label: String, text: String, metadata: Dictionary = {}) -> EventRowData:
	if row == null or not _dock_alive():
		return row
	var view: EventSheetViewport = _dock._active_view()
	if view == null:
		return row
	return view._row_builder.append_field_cell(row, label, text, metadata)


## Builds a muted, wrapping CAPTION row welded to the row directly below it - one line of prose above
## the thing it describes, the way a published verb shows its `@ace_description`. Insert it immediately
## before the row it explains; the inter-block gap then opens above the pair, so the two read as one
## block. The caption is inert (no resource behind it), so nothing edits, drags or deletes it. Pass an
## `accent` with a low alpha to tint it to whatever the subject's colour is. Returns null with no dock.
static func build_caption_row(text: String, indent: int = 0, row_uid: String = "", accent: Color = Color(0, 0, 0, 0)) -> EventRowData:
	if not _dock_alive():
		return null
	var view: EventSheetViewport = _dock._active_view()
	if view == null:
		return null
	var uid: String = row_uid if not row_uid.strip_edges().is_empty() else "caption_%d" % text.hash()
	return view._row_builder.build_caption_row(text, indent, uid, accent)


## Adds an entry to the Command Palette (Ctrl+P). `action` runs when picked. Re-register
## under the same title to replace; unregister_palette_command removes it. Works before
## the dock opens - entries appear once a palette exists.
static func register_palette_command(title: String, action: Callable, category: String = "") -> void:
	# An optional category prefixes the display title ("My Pack: Reroll Loot") so extension
	# commands group together in the palette's fuzzy filter.
	if not category.is_empty():
		title = "%s: %s" % [category, title]
	unregister_palette_command(title)
	_palette_commands.append({"title": title, "run": action})


static func unregister_palette_command(title: String) -> void:
	for index in range(_palette_commands.size() - 1, -1, -1):
		if str(_palette_commands[index].get("title", "")) == title:
			_palette_commands.remove_at(index)


## The registered extension commands, in registration order (read by the palette).
static func palette_commands() -> Array[Dictionary]:
	return _palette_commands.duplicate()


## Builds the same live Inspector mock the Variable dialog shows - decor, group heading, widget
## miniature, and the plain-language sentence - as a plain Control for YOUR dialogs and panels.
## Dock-free. `attributes` uses the compiler's keys (range/drawer/group/header/info/options/...).
static func build_inspector_preview(variable_name: String, type_name: String, default_text: String, attributes: Dictionary, exported: bool = true, constant: bool = false) -> Control:
	var card: EventSheetInspectorPreviewCard = EventSheetInspectorPreviewCard.new()
	card.update_preview(variable_name, type_name, default_text, attributes, exported, constant)
	return card


## One plain sentence describing an exported variable's Inspector look ("A whole number, from 0
## to 100, shown as a progress bar, grouped under Combat."). Dock-free; the same source of truth
## as the preview card, so your tooling never drifts from the editor's own wording.
static func describe_inspector(type_name: String, attributes: Dictionary, exported: bool = true, constant: bool = false) -> String:
	return EventSheetInspectorPreviewCard.describe(type_name, attributes, exported, constant)


# ── Autocomplete ───────────────────────────────────────────────────────────────────────


## Every name a field of this kind could hold, ranked best first: `[{"text", "detail", "kind"}]`,
## where `text` is what typing the entry inserts, `detail` the line that explains it, and `kind` a
## stable id naming what sort of thing it is ("variable", "function", "file", ...). THE completion
## seam - the expression boxes, the inline value editor in the sheet, the name fields and the file
## fields all ask this one call, so a name completes the same way wherever it is typed.
##
## `field_kind` is the parameter's own `hint` wherever a parameter has one ("expression",
## "input_action", "group_reference", "scene_node", "variable_reference", "signal_reference",
## "shader_dial", "scene_path", "audio_path"), so a pack shipping a hint gets completion without
## doing anything. Three kinds have no hint behind them and are named directly: "function_name",
## "class_name" and "file". A kind may carry an argument after a colon - "file:PackedScene",
## "enum_value:State" - exactly as the hints already do.
##
## `prefix` is what the reader has typed. For "expression" pass the whole text BEFORE THE CARET
## (`hp.` and `hp` want different answers, and only that can tell them apart); for every other kind
## pass the word itself. An unknown kind answers with nothing, which is what keeps an unrecognised
## hint a plain typed field rather than a wrong list.
##
## Fast by contract: each kind's list is built once per sheet and only FILTERED per keystroke.
static func completions_for(sheet: EventSheetResource, field_kind: String, prefix: String = "") -> Array[Dictionary]:
	return EventSheetCompletions.for_field(sheet, field_kind, prefix)


## Adds (or replaces) the source behind one field kind. `source` is
## `Callable(sheet: EventSheetResource, field_kind: String) -> Array` and returns entries shaped
## like completions_for's (a plain Array of Strings is accepted for the simplest case). It is asked
## BEFORE the built-in for that kind, so a pack can sharpen a kind the plugin already answers as
## well as add one of its own. The result is cached exactly like a built-in's, so a source is free
## to be slow: it is asked when a field is first completed, not on every keystroke.
static func register_completion_source(field_kind: String, source: Callable) -> void:
	EventSheetCompletions.register_source(field_kind, source)


static func unregister_completion_source(field_kind: String) -> void:
	EventSheetCompletions.unregister_source(field_kind)


## Rides the completion popup on one of YOUR dialog's fields, with the same keyboard model every
## field in this editor uses: Tab or Enter accepts the highlighted entry, Escape closes and keeps
## what was typed, Up and Down move. The entries come from completions_for for `field_kind`, in the
## context of the sheet currently open. Returns the popup, so a caller that wants a list of its own
## can drive it directly.
static func attach_completions(field: LineEdit, field_kind: String) -> EventSheetCompletionPopup:
	return EventSheetCompletionPopup.attach(field, field_kind,
		func() -> EventSheetResource: return current_sheet())


# ── Codegen ────────────────────────────────────────────────────────────────────────────


## Builds a ready-to-fill EventSheetResource from a plain Dictionary, so you can author a sheet,
## behavior, autoload, or tool script from code (there is no other public "create sheet" entry).
## All keys optional:
##   {"class_name": "Enemy", "host_class": "CharacterBody2D", "behavior_mode": false,
##    "autoload_mode": false, "autoload_name": "", "tool_mode": false, "test_mode": false,
##    "category": "My Pack", "tags": ["ai"], "description": "..."}
## For a tool script pass {"tool_mode": true, "host_class": "EditorScript"}; for a Test sheet pass
## {"test_mode": true}, which adds the runner's start signal and the discovery marker. Append events and
## functions to the returned sheet, then compile() it or open_sheet() its saved path.
## A singleton needs BOTH autoload keys: `autoload_name` alone names nothing, and every surface asks
## `sheet.autoload_singleton_name()`, which answers "" until the kind is set as well.
static func new_sheet(config: Dictionary = {}) -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = str(config.get("host_class", "Node"))
	sheet.custom_class_name = str(config.get("class_name", ""))
	sheet.behavior_mode = bool(config.get("behavior_mode", false))
	sheet.autoload_mode = bool(config.get("autoload_mode", false))
	sheet.autoload_name = str(config.get("autoload_name", ""))
	sheet.tool_mode = bool(config.get("tool_mode", false))
	sheet.test_mode = bool(config.get("test_mode", false))
	sheet.addon_category = str(config.get("category", ""))
	sheet.class_description = str(config.get("description", ""))
	if config.has("tags"):
		var tags: PackedStringArray = PackedStringArray()
		for tag: Variant in config.get("tags", []):
			tags.append(str(tag))
		sheet.addon_tags = tags
	return sheet


## Compiles a sheet to plain GDScript. Returns the compiler's result Dictionary:
## "output" (the source text), "success", "errors", "warnings", "source_map".
static func compile(sheet: EventSheetResource, output_path: String = "") -> Dictionary:
	return SheetCompiler.compile(sheet, output_path)


## ALL the GDScript a variable compiles to - its "Ships as:" truth, decor comments, tooltip, grouping
## and the @export annotation included. Deterministic: same variable, same bytes. More than one line
## whenever the declaration needs one (a doc comment above it, a Static local's marker). For the ONE
## line out of that which declares the variable - the line a row echoes - ask `row_code_line()`.
static func variable_code(variable: LocalVariable) -> String:
	return SheetCompiler._emit_tree_variable_line(variable)


## ONE line of the emitted file - the line a ROW stands for, which is what the sheet echoes at that
## row's right edge, for any row an extension might draw. `variable_code()` is the other half of the
## pair: everything a variable compiles to, where this is the single line out of it that declares.
##   * a variable  -> its declaration, out of everything `variable_code()` writes for it. The doc
##     comment above it, the `@export_group` header that opens an Inspector section and a Static
##     local's marker are all true of the file, and none of them is the declaration.
##   * an event group -> the `## @ace_group(...)` line it declares itself on. A group's line names
##     its parent, which only the whole sheet knows, so pass `sheet` for one; drawing MANY heads
##     asks `group_declaration_lines(sheet)` once instead, which is the same walk done once.
##   * a Custom Block row -> the last line its kind emits, so a marker written above the line does
##     not steal the echo. A kind that emits nothing has no line.
## Every other row answers "": those three are the rows the sheet draws an echo on, and an event is
## not one of them in any case - it compiles to a block, not to a line.
static func row_code_line(row: Resource, sheet: EventSheetResource = null) -> String:
	if row is LocalVariable:
		return EventSheetCodeEcho.line_for(row as LocalVariable)
	if row is EventGroup:
		return str(group_declaration_lines(sheet).get(row, ""))
	if row is CustomBlockRow:
		var kind: EventSheetBlockKind = EventSheetBlockRegistry.get_kind((row as CustomBlockRow).kind_id)
		if kind == null:
			return ""
		var emitted: PackedStringArray = kind.emit_lines(row)
		return emitted[emitted.size() - 1] if not emitted.is_empty() else ""
	return ""


## The `## @ace_group(...)` line the compiler writes for each of a sheet's event groups, keyed by the
## EventGroup itself: `{EventGroup: String}`. A group head echoes its own line from here, so an
## extension drawing groups says the same thing the file does - uid, name, parent, description,
## colour and the two flags, exactly as they are emitted and read back. Derived in one walk, so a
## caller with many heads to draw asks once.
static func group_declaration_lines(sheet: EventSheetResource) -> Dictionary:
	return SheetCompiler.group_declaration_lines(sheet.events) if sheet != null else {}


## Every variable a sheet can name, and who owns each - the ONE list the rows, the picker, the
## Anatomy rail and the expression picker read. Entries are
## `{"name", "type_name", "type_word", "value", "scope", "owner", "group", "inspector",
## "description", "insert_text", "resource", "autoload"}`, in reading order: this object's own
## variables, then the globals it reaches for, then the locals in scope.
##
## `owner` is the object column a row carrying that variable reads with (the sheet's own object, an
## autoload's name, or "System" for a local), and `insert_text` is what a parameter field must
## actually receive - bare for an instance variable or a local, `Game.Score` for a global, where the
## prefix is real code and cannot be dropped.
static func sheet_variables(sheet: EventSheetResource) -> Array[Dictionary]:
	return EventSheetVariableOwners.catalog(sheet)


## Every value the sheet's rows hold in a parameter of one HINT, in sheet order - the sheet's own
## events first, then its functions'. Entries are
## `{"value", "param", "provider_id", "ace_id", "event"}`.
##
## "Which animations does this sheet play", "which groups does it name", "which input actions does
## it use" are one question asked of a different hint, and this is the one walk that answers all of
## them: a pack that ships a hint of its own gets the same answer as a builtin one. `distinct` is
## the same walk with the values deduplicated, first mention first - what a band or a picker wants,
## where the same name used by six rows is one name.
static func values_for_hint(sheet: EventSheetResource, hint: String) -> Array[Dictionary]:
	return EventForgeSheetParamValues.of_hint(sheet, hint)


## The distinct values of `values_for_hint`, first mention first.
static func distinct_values_for_hint(sheet: EventSheetResource, hint: String) -> PackedStringArray:
	return EventForgeSheetParamValues.distinct(sheet, hint)


## Every function a sheet publishes as a MESSAGE - the ones carrying an `@rpc` annotation, which
## is what makes a call travel to the other peers. Entries are
## `{"name", "params", "annotation", "words", "note"}`, in declaration order: the function name, its
## parameter names in order, the annotation verbatim, that annotation read back in the sheet's own
## words ("from anyone · also here · reliable"), and the amber line an annotation carrying an option
## Godot does not take earns ("" for every other).
##
## Read-only and derived from the sheet - nothing about a message is stored in a second place. This
## is the list a Send row picks from, so a pack building its own send surface offers exactly what the
## shipped one offers.
static func sheet_messages(sheet: EventSheetResource) -> Array[Dictionary]:
	return EventSheetMessageFacts.messages_in(sheet)


## The `@rpc(...)` line a set of answers writes, and the reverse - what a line already says. Pass
## `{"Who may send": "any_peer", "Where it runs": "call_local", "Delivery": "reliable",
## "channel": 0}`; the field words are `EventSheetMessageFacts.FIELD_*`. Handing back the ORIGINAL
## line when the answers still mean what it said is the byte-exactness rule, so a pack that edits a
## message through this cannot rewrite a `.gd` it did not change.
static func message_annotation(original: String, answers: Dictionary) -> String:
	return EventSheetMessageFacts.rewrite(original, answers)


## Every function of this sheet that a `MultiplayerSynchronizer` asks whether a player may see
## its node - one entry each, `{"name", "synchronizer"}`, in the order the rows name them.
## `synchronizer` is the node the asking row addresses, and "" when that row acts on the sheet's own
## node.
##
## Read-only and derived like `sheet_messages`: being a visibility filter is not a flag on the
## function, it is the fact that a row hands the function to `add_visibility_filter` - so a filter
## nobody asks stops being one the moment that row goes, with nothing to clean up.
static func sheet_visibility_filters(sheet: EventSheetResource) -> Array[Dictionary]:
	return EventSheetSceneVerbs.visibility_filters_in(sheet)


## The object column a row naming this variable belongs in, or "" when the sheet declares no such
## variable and the ordinary provider reading should stand. Pass the list `sheet_variables()`
## returned - the answer is a lookup, so a caller drawing many rows derives the list once.
static func variable_owner(variables: Array[Dictionary], variable_name: String) -> String:
	return EventSheetVariableOwners.owner_for(variables, variable_name)


## One ENTRY of `sheet_variables()` written the way its ROW reads it, minus the owner:
## "Instance whole number hp = 100". Composed through the same call the canvas makes, so a pack's
## own panel and the sheet can never disagree about how a variable is spelled.
static func variable_sentence(entry: Dictionary) -> String:
	return EventSheetVariableOwners.sentence(entry)


## The glyph a ROW shows for a comparison operator: `<=` reads ≤, `>=` reads ≥, `!=` reads ≠ and
## `==` reads a single `=` (a row is a question, so there is nothing for the doubled character to
## disambiguate). Anything that is not one of the six operators comes back unchanged, so a pack can
## call this on any param value it is about to draw. The two-character forms stay the truth in
## templates and in every emitted line.
static func comparison_glyph(operator: String) -> String:
	return EventForgeACEFactory.comparison_glyph(operator)


## The operator that is true exactly when this one is false - `<=` ↔ `>`, `==` ↔ `!=`. "" when the
## text is not one of the six. This is the same table the sheet uses to write an inverted comparison
## as the opposite question rather than as a `not (...)`, so a pack that offers its own invert reads
## and writes the row the same way the built-in one does.
static func opposite_operator(operator: String) -> String:
	return EventForgeACEFactory.opposite_operator(operator)


## Builds one Inspector-GRID variable descriptor (the `"drawer": "table"` payload) from plain
## column phrases, so nobody hand-assembles the column-hint syntax: this is the ONE owner of
## it - the Custom Resource wizard, pack builders, and extensions all converge here.
##
## Each column is a String phrase or a pass-through Dictionary:
##   "name"                      -> {"name": "name", "type": "String"}
##   "weight: float"             -> {"name": "weight", "type": "float"}   (float/int/bool/String)
##   "kind: coin|gem|key"        -> {"name": "kind", "type": "enum(coin|gem|key)"} (a dropdown)
## Options (all optional): tooltip, group, required (bool). Returns the full variable
## descriptor - drop it into EventSheetResource.variables under the grid's name:
##   sheet.variables["drops"] = EventSheets.resource_grid(["name", "kind: coin|gem|key",
##       "weight: float"], {"tooltip": "One drop per row.", "group": "Loot"})
static func resource_grid(columns: Array, options: Dictionary = {}) -> Dictionary:
	var table_columns: Array = []
	for column: Variant in columns:
		if column is Dictionary:
			table_columns.append((column as Dictionary).duplicate(true))
			continue
		var phrase: String = str(column).strip_edges()
		if phrase.is_empty():
			continue
		var column_name: String = phrase
		var column_type: String = "String"
		var colon: int = phrase.find(":")
		if colon >= 0:
			column_name = phrase.substr(0, colon).strip_edges()
			var kind: String = phrase.substr(colon + 1).strip_edges()
			if kind.begins_with("enum(") and kind.ends_with(")"):
				# An ALREADY-FORMED token, checked before the plain-choices branch below because
				# every multi-option token contains a `|` and would otherwise be split as if the
				# wrapper were part of the first choice, yielding enum(enum(a|b)). Round-tripping
				# it through the codec validates and canonicalises it, and keeps any `key=Label`
				# choice labeled rather than flattening it.
				var formed: String = SheetCompiler.table_enum_type(SheetCompiler.table_enum_options(kind))
				column_type = formed if not formed.is_empty() else "String"
			elif kind.contains("|"):
				# Plain choices become a dropdown column; spaces around the | are forgiven, and a
				# `key=Label` choice keeps its label (the codec reads the pair back out).
				var choices: PackedStringArray = PackedStringArray()
				for choice: String in kind.split("|"):
					if not choice.strip_edges().is_empty():
						choices.append(choice.strip_edges())
				column_type = "enum(%s)" % "|".join(choices)
			elif kind in ["float", "int", "bool", "String"]:
				column_type = kind
			elif not kind.is_empty():
				column_type = kind
		table_columns.append({"name": column_name, "type": column_type})
	var attributes: Dictionary = {"drawer": "table", "table_columns": table_columns}
	if not str(options.get("tooltip", "")).is_empty():
		attributes["tooltip"] = str(options.get("tooltip"))
	if not str(options.get("group", "")).is_empty():
		attributes["group"] = str(options.get("group"))
	if bool(options.get("required", false)):
		attributes["required"] = true
	return {"type": "Array", "default": [], "exported": true, "attributes": attributes}


## Gives a variable a LIVE validation check without the author learning the machinery: creates
## a `validate_<variable>` sheet function (returns a warning String, "" = valid - the body is a
## ready-to-edit condition/action skeleton) and wires the variable's `validate` attribute to it,
## so the Inspector shows the returned message above the field while it is edited (@tool sheets).
## Reuses an existing function of that name instead of duplicating. Returns the function name,
## or "" when the sheet/variable doesn't exist. The Custom Resource wizard's "Add a validation
## check" box calls this; packs and extensions can too.
static func attach_validator(sheet: EventSheetResource, variable_name: String) -> String:
	if sheet == null or not sheet.variables.has(variable_name):
		return ""
	var function_name: String = "validate_%s" % variable_name
	var exists: bool = false
	for candidate: Resource in sheet.functions:
		if candidate is EventFunction and (candidate as EventFunction).function_name == function_name:
			exists = true
			break
	if not exists:
		var validator: EventFunction = EventFunction.new()
		validator.function_name = function_name
		validator.return_type = TYPE_STRING
		validator.doc_comment = "Checked live while %s is edited in the Inspector: return a warning to show, or \"\" when the data is fine." % variable_name
		var body: RawCodeRow = RawCodeRow.new()
		var descriptor: Dictionary = sheet.variables.get(variable_name, {})
		if str(descriptor.get("type", "")) == "Array":
			body.code = "if %s.is_empty():\n\treturn \"Add at least one row.\"\nreturn \"\"" % variable_name
		else:
			body.code = "# Return a warning message when %s looks wrong, e.g.:\n# if %s == null:\n#\treturn \"Set %s first.\"\nreturn \"\"" % [variable_name, variable_name, variable_name]
		validator.events.append(body)
		sheet.functions.append(validator)
	var variable_descriptor: Dictionary = sheet.variables.get(variable_name, {})
	var variable_attributes: Dictionary = variable_descriptor.get("attributes", {})
	variable_attributes["validate"] = function_name
	variable_descriptor["attributes"] = variable_attributes
	sheet.variables[variable_name] = variable_descriptor
	return function_name


## Opens GDScript source as an editable sheet (the lossless external path: everything
## liftable lifts, everything else stays verbatim - never corrupted).
static func open_gd_as_sheet(source: String) -> EventSheetResource:
	return GDScriptImporter.new().import_external_source(source)


## Publishes a behaviour sheet as an ADDON PACK .gd at base_path + ".gd" - the ONE pack
## pipeline, shared by the bundled builders and the dock's Export Addon (they can never
## drift apart). In order: a pack-local icon.svg beside base_path is adopted when the sheet
## has no icon (then icon_path, when given); raw code de-codes into rows wherever it
## recompiles byte-identically (function bodies, event bodies, trigger signals, helper
## declarations - per-item byte-gated, unliftable code stays verbatim); row uids become
## deterministic (same sheet, same bytes - version-control friendly); and the sheet compiles
## banner-less, so the .gd IS the pack: the editable event sheet AND the runtime script.
## MUTATES `sheet` (lifts + uids + icon) - pass a duplicate to keep an original untouched.
## Returns the compile result Dictionary ({"success", "output", "warnings", ...}).
static func publish_pack(sheet: EventSheetResource, base_path: String, icon_path: String = "") -> Dictionary:
	if sheet == null:
		return {"success": false, "errors": ["No sheet."]}
	if sheet.custom_class_icon.strip_edges().is_empty():
		var local_icon: String = base_path.get_base_dir() + "/icon.svg"
		if FileAccess.file_exists(local_icon):
			sheet.custom_class_icon = local_icon
		elif not icon_path.strip_edges().is_empty():
			sheet.custom_class_icon = icon_path
	EventSheetACELifter.lift_function_bodies(sheet)
	EventSheetACELifter.lift_event_bodies(sheet)
	EventSheetACELifter.lift_signal_declarations(sheet, false)
	EventSheetACELifter.lift_function_declarations(sheet, false)
	stabilize_row_uids(sheet)
	DirAccess.make_dir_recursive_absolute(base_path.get_base_dir())
	return SheetCompiler.compile(sheet, base_path + ".gd", true)


## Stamps deterministic row uids derived from each row's structural path, so an unchanged
## sheet regenerates byte-for-byte (EventRow/EventGroup otherwise mint a random uid per
## _init(), churning every regeneration). publish_pack calls this; generators that compile
## sheets themselves (showcase builders) call it directly before compiling.
static func stabilize_row_uids(sheet: EventSheetResource) -> void:
	var class_seed: String = sheet.custom_class_name if not sheet.custom_class_name.is_empty() else "sheet"
	_publish_assign_uids_in_list(sheet.events, class_seed + "/events")
	for function_resource: Variant in sheet.functions:
		if function_resource is EventFunction:
			_publish_assign_uids_in_list((function_resource as EventFunction).events, class_seed + "/fn/" + (function_resource as EventFunction).function_name)


static func _publish_assign_uids_in_list(rows: Array, path_prefix: String) -> void:
	var index: int = 0
	for row: Variant in rows:
		var row_path: String = "%s/%d" % [path_prefix, index]
		if row is EventRow:
			(row as EventRow).event_uid = row_path.sha256_text().substr(0, 6)
			_publish_assign_uids_in_list((row as EventRow).sub_events, row_path)
		elif row is EventGroup:
			(row as EventGroup).group_uid = row_path.sha256_text().substr(0, 6)
			_publish_assign_uids_in_list((row as EventGroup).events, row_path)
		index += 1


## Where the byte gate re-emits what it is asking about, and it is never the file the source came
## from: naming a real path would save a question's answer over somebody's work. Named rather than
## inlined so that a caller wanting the re-emission ITSELF (to say WHICH line would change) can
## reproduce this exact answer instead of a similar one - the emitted path is part of what a sheet
## emits, so a probe under a different name is a different question.
const ROUND_TRIP_PROBE_PATH: String = "user://__eventsheets_api_roundtrip.gd"


## The byte gate as a service: true when importing `source` and recompiling reproduces
## it byte-identically - the same covenant every built-in lift must satisfy. Use it to
## verify a custom block kind or an emission tweak can never corrupt user files.
static func round_trips(source: String) -> bool:
	var sheet: EventSheetResource = open_gd_as_sheet(source)
	if sheet == null:
		return false
	sheet.external_source_path = ROUND_TRIP_PROBE_PATH
	return str(compile(sheet, sheet.external_source_path).get("output", "")) == source


# ── Data tables (a spreadsheet read exactly the way the Table From File verb reads it) ─
#
# The Table From File / Table From Text verbs parse a .csv whose first line is the column
# names into an Array of Dictionaries, and their parse policy is a genuinely fiddly frozen
# artifact: quoted cells may contain the separator, a doubled "" is one literal quote, CRLF
# and lone-CR endings normalise, blank lines drop, a short row fills with "", a repeated
# column name keeps the first, and an unbalanced quote splits plainly instead of eating the
# rest of the line. A pack builder, an editor tool or a Doctor check that wants the SAME
# records had no way to get them but to write that parse a second time - and a second
# implementation of a frozen artifact is a drift waiting to happen.
#
# These run the verb's own template, so they cannot drift by construction: the template is
# compiled into a throwaway script and called. Editor/tool-side only (nothing is emitted, so
# the parity covenant is untouched); the compiled parser is cached per separator.

## The compiled parser for one separator. The template is frozen, so one compile serves the
## whole session.
static var _table_parsers: Dictionary = {}


## Reads a .csv (first line = column names) as an Array of Dictionaries, one record per row,
## every field reachable by column name: rows[0]["price"]. Identical to what the Table From
## File verb compiles to. A missing or unreadable file reads as no rows, never an error.
static func table_from_file(path: String, separator: String = ",") -> Array:
	# Existence is checked first only to keep a missing data file from spamming the console:
	# the verb's own template reads a missing file as "" and so as no rows, same as this.
	if not FileAccess.file_exists(path):
		return []
	return table_from_text(FileAccess.get_file_as_string(path), separator)


## The same column-names-first parse over text you already hold (a pasted blob, a downloaded
## body, a file read earlier) - the Table From Text verb as a service. Returns [] when the
## text is empty or the parser could not be built.
static func table_from_text(text: String, separator: String = ",") -> Array:
	var parser: GDScript = _table_parser(separator)
	if parser == null:
		return []
	var rows: Variant = parser.parse(text)
	return rows if rows is Array else []


static func _table_parser(separator: String) -> GDScript:
	if _table_parsers.has(separator):
		return _table_parsers[separator]
	# By path, so naming the table module here never joins the editor's boot compile.
	var module: GDScript = load("res://addons/eventforge/registration/modules/table_aces.gd")
	var script: GDScript = GDScript.new()
	script.source_code = "extends RefCounted\n\n\nstatic func parse(__text: String) -> Array:\n\treturn %s\n" \
		% module.table_expression("__text", "\"%s\"" % separator.c_escape())
	if script.reload() != OK:
		push_warning("[EventSheets] could not build the table parser for separator %s." % separator)
		return null
	_table_parsers[separator] = script
	return script


# ── Save support (build the save_state seam into any script or tool) ───────────────────
#
# A node persists across a save by exposing two plain methods - `save_state() ->
# Dictionary` and `load_state(state: Dictionary)`. The Save System duck-types the pair
# (no base class, no registration), so these services let an extension GENERATE that
# seam, detect it, and preview how a snapshot lands on disk - the same primitives the
# built-in Save Studio is built on. Dock-free; they work in tests and headless tools.

## Object-typed declared types that are references, not data, and never belong in a
## snapshot. Used to pre-tick the safe fields in persistable_fields().
const _NON_DATA_TYPES: PackedStringArray = ["Node", "Node2D", "Node3D", "Control", "Tween", "Timer", "Resource", "Texture2D", "PackedScene", "RandomNumberGenerator", "FastNoiseLite", "Mutex", "Thread", "Camera2D", "Camera3D", "SubViewport", "Sprite2D", "Line2D", "AudioStreamPlayer", "Callable", "Signal"]
const _SAVE_SYSTEM_SCRIPT: String = "res://eventsheet_addons/save_system/save_system_addon.gd"


## Generates the save_state()/load_state() pair from a list of fields, in the repo-wide
## convention: snapshot keys drop a leading underscore, collections deep-copy, and loads
## coerce by type and tolerate a missing key (returning the field's current value). Each
## field is {"name": "_wallet", "type": "Dictionary"}; the type drives the coercion
## (int/float/bool/String/Dictionary/Array, anything else passes through). Returns the
## two methods as one pastable block, or "" when fields is empty.
static func save_state_code(fields: Array) -> String:
	var save_lines: PackedStringArray = PackedStringArray()
	var load_lines: PackedStringArray = PackedStringArray()
	for field: Variant in fields:
		if not field is Dictionary:
			continue
		var var_name: String = str((field as Dictionary).get("name", ""))
		var var_type: String = str((field as Dictionary).get("type", "Variant"))
		var key: String = var_name.trim_prefix("_")
		match var_type:
			"Dictionary":
				save_lines.append("\t\t\"%s\": %s.duplicate(true)," % [key, var_name])
				load_lines.append("\t%s = (state.get(\"%s\", {}) as Dictionary).duplicate(true)" % [var_name, key])
			"Array":
				save_lines.append("\t\t\"%s\": %s.duplicate(true)," % [key, var_name])
				load_lines.append("\t%s = (state.get(\"%s\", []) as Array).duplicate(true)" % [var_name, key])
			"int":
				save_lines.append("\t\t\"%s\": %s," % [key, var_name])
				load_lines.append("\t%s = int(state.get(\"%s\", %s))" % [var_name, key, var_name])
			"float":
				save_lines.append("\t\t\"%s\": %s," % [key, var_name])
				load_lines.append("\t%s = float(state.get(\"%s\", %s))" % [var_name, key, var_name])
			"bool":
				save_lines.append("\t\t\"%s\": %s," % [key, var_name])
				load_lines.append("\t%s = bool(state.get(\"%s\", %s))" % [var_name, key, var_name])
			"String":
				save_lines.append("\t\t\"%s\": %s," % [key, var_name])
				load_lines.append("\t%s = str(state.get(\"%s\", %s))" % [var_name, key, var_name])
			_:
				save_lines.append("\t\t\"%s\": %s," % [key, var_name])
				load_lines.append("\t%s = state.get(\"%s\", %s)" % [var_name, key, var_name])
	if save_lines.is_empty():
		return ""
	save_lines[save_lines.size() - 1] = str(save_lines[save_lines.size() - 1]).trim_suffix(",")
	var lines: PackedStringArray = PackedStringArray([
		"# Save-state seam: the Save System walks any node in its persist group (or targeted",
		"# by Save/Load Node State) and duck-types these two methods. Plain data only.",
		"func save_state() -> Dictionary:",
		"\treturn {"
	])
	lines.append_array(save_lines)
	lines.append("\t}")
	lines.append("")
	lines.append("")
	lines.append("func load_state(state: Dictionary) -> void:")
	lines.append("\tif state.is_empty():")
	lines.append("\t\treturn")
	lines.append_array(load_lines)
	return "\n".join(lines)


## Lists a script's top-level variables as [{"name", "type", "recommended"}], where
## `recommended` is true for plain-data fields (numbers, text, dictionaries, arrays,
## Vector2/Color...) and false for object references (a Node, a Resource, an RNG) that
## are pointers, not state. Feed the recommended ones to save_state_code(). Returns []
## when the file is missing or has no top-level vars.
static func persistable_fields(script_path: String) -> Array[Dictionary]:
	var fields: Array[Dictionary] = []
	if not FileAccess.file_exists(script_path):
		return fields
	var pattern: RegEx = RegEx.new()
	pattern.compile("^(?:@export[^\\n]*?\\s+)?var\\s+([a-zA-Z_]\\w*)\\s*(?::\\s*([\\w\\[\\], ]+?))?\\s*(?::?=.*)?$")
	for line: String in FileAccess.get_file_as_string(script_path).split("\n"):
		if line.begins_with("\t") or line.begins_with(" "):
			continue
		var hit: RegExMatch = pattern.search(line.strip_edges())
		if hit == null:
			continue
		var var_name: String = hit.get_string(1)
		var var_type: String = hit.get_string(2).strip_edges()
		fields.append({
			"name": var_name,
			"type": var_type if not var_type.is_empty() else "Variant",
			"recommended": _is_plain_data(var_name, var_type)
		})
	return fields


static func _is_plain_data(var_name: String, var_type: String) -> bool:
	if var_name == "host" or var_type.begins_with("Array[Node"):
		return false
	return not _NON_DATA_TYPES.has(var_type)


## True when `target` participates in the save convention - it exposes BOTH save_state
## and load_state. `target` may be a live Node, a Script/GDScript, or a script path.
static func has_save_support(target: Variant) -> bool:
	if target is Node:
		return (target as Node).has_method("save_state") and (target as Node).has_method("load_state")
	var script: Script = null
	if target is Script:
		script = target
	elif target is String and FileAccess.file_exists(target):
		var loaded: Variant = load(target)
		if loaded is Script:
			script = loaded
	if script == null:
		return false
	var names: Dictionary = {}
	for method: Dictionary in script.get_script_method_list():
		names[str(method.get("name", ""))] = true
	return names.has("save_state") and names.has("load_state")


## One call to add save support to a script: scans its recommended (plain-data) fields
## and returns the save_state/load_state pair to paste in. Skips object references. Use
## persistable_fields() + save_state_code() directly when you want to choose the fields.
static func add_save_support(script_path: String) -> String:
	var recommended: Array[Dictionary] = []
	for field: Dictionary in persistable_fields(script_path):
		if bool(field.get("recommended", false)):
			recommended.append(field)
	return save_state_code(recommended)


## The bundled pack scripts that already ship the seam (their .gd paths), so tooling can
## enumerate what persists out of the box. Empty when eventsheet_addons/ is not installed.
static func save_capable_scripts() -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	var root: String = "res://eventsheet_addons"
	if not DirAccess.dir_exists_absolute(root):
		return found
	for pack_dir: String in DirAccess.get_directories_at(root):
		for file: String in DirAccess.get_files_at("%s/%s" % [root, pack_dir]):
			if file.ends_with(".gd") and FileAccess.get_file_as_string("%s/%s/%s" % [root, pack_dir, file]).contains("func save_state() -> Dictionary:"):
				found.append("%s/%s/%s" % [root, pack_dir, file])
				break
	return found


## Renders a snapshot Dictionary to on-disk text through the REAL Save System backend in
## the given format ("config", "json", "binary", "csv", "ini", "xml"), so tooling can show exactly what
## a save will look like before committing to a format. Returns the file text (a hex head
## for binary), or an explanatory line when the Save System pack is not installed.
static func preview_save(data: Dictionary, format: String, key: String = "state") -> String:
	if not FileAccess.file_exists(_SAVE_SYSTEM_SCRIPT):
		return "The Save System pack is not installed (eventsheet_addons/save_system/)."
	var writer: Node = (load(_SAVE_SYSTEM_SCRIPT) as GDScript).new()
	writer.set("save_directory", "user://")
	writer.set("file_pattern", "__eventsheets_api_preview.tmp")
	writer.set("format", format)
	writer.call("save_value", key, data)
	var path: String = str(writer.call("_slot_path"))
	var text: String
	if format == "binary":
		var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
		text = "binary (store_var): %d bytes - compact and fast, not hand-editable.\n\nFirst bytes:\n%s" % [bytes.size(), bytes.slice(0, mini(96, bytes.size())).hex_encode()]
	else:
		text = FileAccess.get_file_as_string(path)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	writer.free()
	return text


## What one script's SOURCE says about save keys: {"saved", "slot_keys", "loaded", "remembered"},
## each a sorted PackedStringArray of the literal keys it writes, writes as a TOP-LEVEL slot key,
## reads back, and persists through Remember Between Runs. This is the Doctor's own
## save-key-symmetry rule, exposed so a save browser, a migration tool or a pack's own check reads
## the same keys the built-in check does instead of writing a second regex that disagrees with it.
##
## Deliberately conservative, in both directions: a WRITE counts loosely (any receiver, plus
## every key a save_state() snapshot returns), a READ only from a real dotted call with a
## literal key, and a computed key is reported by neither - there is nothing to compare.
## "slot_keys" leaves out the save_state() members, which live inside their own node's dictionary
## rather than in the slot's own namespace. Whole-line comments are stripped before matching.
static func save_keys_used(source: String) -> Dictionary:
	return EventSheetProjectDoctor.save_key_usage(source)


# ── Localisation (the editor UI's language - game l10n is the Translation module) ──────


## Translates an editor-UI string into the active plugin language. English is the default
## and the fallback: with no translation loaded (or English active) the text passes through
## unchanged. Route every user-facing string a FUTURE feature or extension shows through
## this (or through a Control, which auto-translates via the plugin's translation domain),
## and it localises the day someone drops in a CSV. Frozen ids (ace_id, kind_id, provider
## ids) are contracts, never translated - display strings only.
static func translate(text: String) -> String:
	return EventSheetL10n.translate(text)


## Registers an extension's own translation file (a drop-in CSV whose first column is the English
## source string and whose remaining columns are locale codes, or a ready-made Translation), merging its
## messages into the language catalogs and refreshing the active language live. Use this when
## a pack ships translations for its OWN display names/descriptions somewhere outside the
## auto-scanned folders. Returns false when the file contributed nothing.
static func register_translation_file(path: String) -> bool:
	EventSheetL10n.ensure_loaded()
	if not EventSheetL10n.load_translation_file(path):
		return false
	EventSheetL10n.set_locale(EventSheetL10n.get_locale())
	return true


## Every language currently offered: "en" plus each locale a translation file provides.
static func available_languages() -> PackedStringArray:
	return EventSheetL10n.available_locales()


## Switches the editor UI language ("en" restores the default English). Persisted per-user.
static func set_editor_language(locale: String) -> void:
	EventSheetL10n.set_locale(locale)
	if _dock_alive():
		_dock.propagate_notification(MainLoop.NOTIFICATION_TRANSLATION_CHANGED)


# ── Project health ─────────────────────────────────────────────────────────────────────


## Runs the Project Doctor audit over every sheet in the project (dock-free). Returns
## {findings: Array[{severity, check, path, message}], errors, warnings, infos}.
static func doctor() -> Dictionary:
	return EventSheetProjectDoctor.run()


## Adds a project-health check that runs everywhere the Doctor runs (dock panel, CLI,
## CI, MCP), after the built-ins. `check` receives (sheet_paths: PackedStringArray,
## findings: Array[Dictionary]) and appends findings shaped
## {"severity": "error"|"warning"|"info", "check": <check_id>, "path": ..., "message": ...}.
## Doctor covenant applies: never write inside res://. Re-register an id to replace it.
static func register_doctor_check(check_id: String, check: Callable) -> void:
	EventSheetProjectDoctor.register_check(check_id, check)


static func unregister_doctor_check(check_id: String) -> void:
	EventSheetProjectDoctor.unregister_check(check_id)


## Every GDScript in the project, excluding addons/ (the plugin's own code is not the user's
## game) - the corpus most Doctor checks actually want.
##
## A registered check receives `sheet_paths`, and that list is a TRAP for anything that looks
## at emitted code: it finds only `.tres` sheets while `.gd` is the default sheet format, so a
## check built on it silently skips most real projects while looking like it works. A generated
## sheet is deliberately indistinguishable from hand-written GDScript (the parity covenant), so
## there is no marker to filter on and no need for one - a script doing the wrong thing is doing
## the wrong thing whoever wrote it. Scan these when the failure lives in the emitted output.
static func project_scripts() -> PackedStringArray:
	return EventSheetProjectDoctor._project_scripts()


## Every row of the project that migration has something to say about, sorted and deterministic:
##
##   [{sheet: String, row: int, from_id: String, to_id: String, before: String, after: String,
##     asks: bool}]
##
## `sheet` is the file the row lives in and `row` its 1-based place among that sheet's verb-carrying
## rows in reading order (conditions before actions, sub-events after their parent, functions last) -
## an address a person can count to, not a handle. `from_id` and `to_id` are "<provider>::<ace_id>"
## spellings; `to_id` is empty when the vocabulary has no newer spelling for this verb at all.
## `before` is the line the row writes today and `after` the line it would write once rewritten.
##
## `asks` is true when a person has to decide - the verb has no successor, the newer one keeps state
## of its own and has to be picked, the rewritten row could not be read back as itself, or the file
## would not compile with it in place. `after` is non-empty EXACTLY when `asks` is false: a row
## nothing can rewrite has no line to show for a rewrite that will not happen.
##
## A row written in the spelling the vocabulary uses today is not here, which is nearly every row of
## nearly every sheet. Nothing is written, nothing is cached, and nothing carries a timestamp or a
## machine path - this answers a question, and applying the answer is an edit somebody approves in
## the sheet's own migrate dialog.
##
## This shape is FROZEN, like an `ace_id`: a reader of it may be a studio's own script.
static func migration_report() -> Array[Dictionary]:
	return EventSheetMigrationDoctor.rows(EventSheetMigrationDoctor.project_corpus())


## Every scene of the project that loads one resource FILE, in path order, leaving out `own_scene`.
##
## The question behind "shared with N other scenes": a `.tres` is one object, so a material, an
## environment or a curve written at run time is written for everything holding the same file. Any
## check or head band asking it should ask HERE rather than walking the scenes itself - the answer
## comes from one indexed scan of the project, shared by everything that asks and dropped whole when
## the editor's filesystem signal fires.
##
## The scan is time-sliced across idle frames, so this BLOCKS on the first ask if it is not finished.
## A band that must not wait asks `EventSheetProjectShareIndex.request()` for readiness first and
## says "counting…" until it answers true.
static func scenes_using_resource(resource_path: String,
		own_scene: String = "") -> PackedStringArray:
	if resource_path.strip_edges().is_empty():
		return PackedStringArray()
	EventSheetProjectShareIndex.build_scenes_now()
	return EventSheetProjectShareIndex.other_holders(resource_path, own_scene)


## Every project script that calls a function of this name, in path order, leaving out `own_script`.
##
## The question behind "called by combat.gd, boss_ai.gd" on a function's head, and the one a rename
## has to answer before it changes anything: sheets it can rewrite, hand-written code it must not.
## Matched BY NAME - a script calling `take_damage` on anything is listed - because reading the types
## instead would need the whole project's inference to be right, and being quietly wrong about who
## calls a function is worse than being plainly approximate. Say so wherever the answer is shown.
##
## Comes from the same one indexed scan of the project as `scenes_using_resource`, so this BLOCKS on
## the first ask if that scan has not finished. A band that must not wait asks
## `EventSheetProjectShareIndex.request()` for readiness first.
static func scripts_calling(function_name: String, own_script: String = "") -> PackedStringArray:
	if function_name.strip_edges().is_empty():
		return PackedStringArray()
	EventSheetProjectShareIndex.build_now()
	return EventSheetProjectShareIndex.callers_of(function_name, own_script)


# ── Extension seams (custom features plug in here) ─────────────────────────────────────

## Row context-menu items: [{label, filter: Callable(resource)->bool, action: Callable(resource)}].
static var _row_menu_items: Array[Dictionary] = []
## Lifecycle listeners: event name -> Array[Callable].
static var _lifecycle: Dictionary = {"opened": [], "saved": [], "compiled": []}
## Extension starters: [{label, build: Callable()->EventSheetResource}] - ids 1000+ in the dialog.
static var _starters: Array[Dictionary] = []
## Param editors: hint or type_name -> Callable(param_dict, initial_text) -> LineEdit.
static var _param_editors: Dictionary = {}
## Param help strip paragraphs: hint -> the sentence the strip says about a field of that kind.
static var _param_help: Dictionary = {}
## Welcome Preferences rows: Array[Callable() -> Control].
static var _preference_builders: Array[Callable] = []
## Dictionary-defined ACEs live in the registry's extras (see register_simple_ace).
static var _simple_aces: Array[ACEDefinition] = []
## Editor-preview samplers: behavior script path -> Callable(params, base, time) -> Dictionary.
static var _editor_preview_samplers: Dictionary = {}
## Editor-gizmo drawers: behavior script path -> Callable(params, host, canvas) -> void.
static var _editor_gizmo_drawers: Dictionary = {}


## Adds an entry to the right-click menu of event rows. `filter` receives the row's source
## resource (an EventRow) and returns whether the item should appear; `action` receives the same
## resource when clicked. Mutate the sheet inside your action via EventSheets.edit() so the
## change is one undo step. Re-registering a label replaces it.
static func register_row_menu_item(label: String, filter: Callable, action: Callable) -> void:
	unregister_row_menu_item(label)
	_row_menu_items.append({"label": label, "filter": filter, "action": action})


static func unregister_row_menu_item(label: String) -> void:
	for index: int in range(_row_menu_items.size() - 1, -1, -1):
		if str(_row_menu_items[index].get("label", "")) == label:
			_row_menu_items.remove_at(index)


## The registered row items applicable to `resource` (consulted by the context-menu builder).
static func row_menu_items_for(resource: Resource) -> Array[Dictionary]:
	var applicable: Array[Dictionary] = []
	for entry: Dictionary in _row_menu_items:
		var filter: Callable = entry.get("filter", Callable())
		if not filter.is_valid() or bool(filter.call(resource)):
			applicable.append(entry)
	return applicable


## Lifecycle hooks: run `callback(payload)` whenever a sheet is opened ({sheet, path}), saved
## ({sheet, path}), or compiled ({sheet, path, success}). Fired by the editor's own open/save
## funnels - linters, sync tools, and exporters subscribe instead of polling.
static func on_sheet_opened(callback: Callable) -> void:
	(_lifecycle["opened"] as Array).append(callback)


static func on_sheet_saved(callback: Callable) -> void:
	(_lifecycle["saved"] as Array).append(callback)


static func on_sheet_compiled(callback: Callable) -> void:
	(_lifecycle["compiled"] as Array).append(callback)


## Internal: the dock's IO funnels announce lifecycle events here.
static func _notify_lifecycle(event_name: String, payload: Dictionary) -> void:
	for callback: Callable in (_lifecycle.get(event_name, []) as Array):
		if callback.is_valid():
			callback.call(payload)


## Registers a starter template for the FileSystem "Create New > Event Sheet" dialog:
## {"label": "FPS Player", "build": Callable() -> EventSheetResource}. Appears after the
## built-ins; the Callable runs fresh per create.
static func register_starter(config: Dictionary) -> void:
	if str(config.get("label", "")).is_empty() or not (config.get("build") is Callable):
		push_warning("[EventSheets] register_starter needs a label and a build Callable.")
		return
	_starters.append(config)


static func registered_starters() -> Array[Dictionary]:
	return _starters


## Teaches the quick-add bar, the Ghost Row, and the picker your pack's phrases:
## {"dash forward": "dash", ...} - the key is what users type, the value is the search term
## that finds your ACE.
static func register_quick_add_synonyms(synonyms: Dictionary) -> void:
	ACEPickerDialog.register_synonyms(synonyms)


## Registers the blurb shown when a picker section header is selected (the same channel the
## built-in sections use).
static func register_section_description(section_name: String, blurb: String) -> void:
	EventSheetSectionInfo.register_description(section_name, blurb)


## Curates a provider script IN PLACE: writes `## @ace_*` annotations for the members described by
## `edits`, so a script you already own publishes the vocabulary you want instead of whatever raw
## reflection happened to infer. See EventSheetACEAnnotationWriter for the edit shape.
##
## Only `##` comment lines above a declaration are added or removed - no signature and no body is
## ever touched, which is why a method's KIND is corrected with `@ace_condition` rather than by
## bolting `-> bool` onto someone's function. The file is backed up first (Tools > Sheet Backups
## restores it), and re-applying the same edits is a no-op rather than a second copy of the block.
##
## Returns {"ok", "reason", "changed", "skipped", "backup", "source"}. Nothing is written when
## `ok` is false, or when the edits produce text identical to what is already on disk.
static func curate_provider(script_path: String, edits: Array) -> Dictionary:
	var result: Dictionary = {"ok": false, "reason": "", "changed": 0, "skipped": [], "backup": "", "source": ""}
	var clean_path: String = script_path.strip_edges()
	if not FileAccess.file_exists(clean_path):
		result["reason"] = "No such script: %s" % clean_path
		return result
	var original: String = FileAccess.get_file_as_string(clean_path)
	var written: Dictionary = EventSheetACEAnnotationWriter.apply(original, edits)
	result["skipped"] = written.get("skipped", [])
	result["changed"] = written.get("changed", 0)
	result["source"] = written.get("source", original)
	if not bool(written.get("ok", false)):
		result["reason"] = str(written.get("reason", "Could not rewrite the annotations."))
		return result
	if str(result["source"]) == original:
		# Idempotent re-apply: say so rather than churning a backup for an identical file.
		result["ok"] = true
		result["reason"] = "Already up to date."
		return result
	result["backup"] = EventSheetBackups.backup_sheet(clean_path)
	var handle: FileAccess = FileAccess.open(clean_path, FileAccess.WRITE)
	if handle == null:
		result["reason"] = "Could not open %s for writing (error %d)." % [clean_path, FileAccess.get_open_error()]
		return result
	handle.store_string(str(result["source"]))
	handle.close()
	result["ok"] = true
	return result


## The "Publish New Version" ritual for a pack script: bump `@ace_version` (patch/minor/major),
## record the one-line change note as a doc comment under it, back the file up, write. Returns
## {ok, reason, old_version, new_version, backup}. The pickers republish on the next registry
## refresh - callers editing the open sheet should reopen it so the banner chip reads the new
## version.
static func publish_pack_version(script_path: String, bump: String, note: String) -> Dictionary:
	var result: Dictionary = {"ok": false, "reason": "", "old_version": "", "new_version": "", "backup": ""}
	var clean_path: String = script_path.strip_edges()
	if not FileAccess.file_exists(clean_path):
		result["reason"] = "No such script: %s" % clean_path
		return result
	var original: String = FileAccess.get_file_as_string(clean_path)
	var bumped: Dictionary = EventSheetACEAnnotationWriter.bump_version(original, bump, note)
	result["old_version"] = str(bumped.get("old_version", ""))
	result["new_version"] = str(bumped.get("new_version", ""))
	result["backup"] = EventSheetBackups.backup_sheet(clean_path)
	var handle: FileAccess = FileAccess.open(clean_path, FileAccess.WRITE)
	if handle == null:
		result["reason"] = "Could not open %s for writing (error %d)." % [clean_path, FileAccess.get_open_error()]
		return result
	handle.store_string(str(bumped.get("source", original)))
	handle.close()
	result["ok"] = true
	return result


## Keeps a RENAMED verb working for sheets that already use it, by appending a deprecated
## forwarding shim of the old name to the script.
##
## Renaming a member changes its ace_id, which orphans every row that used it - and the failure is
## silent, because the compiler prefers the template baked onto the row over any registry lookup, so
## the sheet still emits the OLD call, compiles clean, and breaks at game runtime. An id alias could
## not fix that: every already-compiled .gd holds the old call TEXT and no id at all. Only a real
## member of the old name does, which is what this writes.
##
## Additive: nothing existing is edited - no signature, no body, no call site. The file is backed up
## first, and the shim carries `@ace_deprecated` so the old verb is hidden from the picker (it cannot
## be added to new work) while still resolving for the rows that already hold it.
static func keep_old_verb_working(script_path: String, old_member: String, new_member: String, message: String = "") -> Dictionary:
	var result: Dictionary = {"ok": false, "reason": "", "backup": "", "source": ""}
	var clean_path: String = script_path.strip_edges()
	if not FileAccess.file_exists(clean_path):
		result["reason"] = "No such script: %s" % clean_path
		return result
	var original: String = FileAccess.get_file_as_string(clean_path)
	var written: Dictionary = EventSheetACEAnnotationWriter.forwarding_shim(original, old_member, new_member, message)
	result["source"] = written.get("source", original)
	if not bool(written.get("ok", false)):
		result["reason"] = str(written.get("reason", "Could not build the shim."))
		return result
	result["backup"] = EventSheetBackups.backup_sheet(clean_path)
	var handle: FileAccess = FileAccess.open(clean_path, FileAccess.WRITE)
	if handle == null:
		result["reason"] = "Could not open %s for writing (error %d)." % [clean_path, FileAccess.get_open_error()]
		return result
	handle.store_string(str(result["source"]))
	handle.close()
	result["ok"] = true
	return result


## Builds dropdown options from `{value: label}` or a plain value list, in the shape a param's
## `options` wants: {"key": <what gets inserted>, "label": <what the author reads>}. A dropdown
## should read as English while still inserting the real token, and hand-building the pair dicts
## at every call site is how half the packs ended up shipping raw tokens as their own labels.
##
## An entry given as a Dictionary may also carry `note`: the line that reads UNDER that choice in
## the Parameters dialog ("double speed, keeps momentum"). Optional per option, display only - the
## emitted value is still the key.
static func combo_options(source: Variant) -> Array:
	var output: Array = []
	if source is Dictionary:
		for key: Variant in (source as Dictionary):
			output.append({"key": str(key), "label": str((source as Dictionary)[key])})
	elif source is Array or source is PackedStringArray:
		for entry: Variant in source:
			if entry is Dictionary:
				var pair: Dictionary = entry as Dictionary
				# `note` is the line that reads UNDER the choice in the Parameters dialog ("double
				# speed, keeps momentum"). Optional: an option without one renders as it always did.
				output.append({
					"key": str(pair.get("key", "")),
					"label": str(pair.get("label", pair.get("key", ""))),
					"note": str(pair.get("note", "")),
				})
			else:
				output.append({"key": str(entry), "label": str(entry)})
	return output


## THE comparison dropdown - the six operators, labeled in plain English. Pass `equal_token` when
## the runtime stores and later matches the operator with a single `=` instead of `==`.
static func comparison_options(equal_token: String = "==") -> Array:
	return EventForgeACEFactory.comparison_options(equal_token)


## Normalizes one parameter (or custom-block field) config into the shape the params dialog reads,
## so the three ways to author a param finally agree.
##
## A bundled module could always seed a starting value and label a dropdown; annotations gained it
## with `@ace_param(id, default: …, options: a=A|b=B, hint: comparison)`; but a config passed to
## simple_ace()/simple_block_kind() went through verbatim, so an author had to know that the key is
## `default_value` and not `default`, and had to hand-build `{"key", "label"}` pairs. Both papercuts
## produce a param that silently reads 0 or a dropdown of raw tokens.
##
## - `default` and `default_value` are accepted interchangeably.
## - `options` accepts a plain list, a `{value: label}` dictionary, or ready-made pairs.
## - `hint: "comparison"` expands to the whole operator dropdown, seeded to `==` - the same one word
##   that works in an annotation.
static func param_spec(config: Dictionary) -> Dictionary:
	var spec: Dictionary = config.duplicate(true)
	if spec.has("default") and not spec.has("default_value"):
		spec["default_value"] = spec["default"]
	if str(spec.get("hint", "")).to_lower() == "comparison":
		if not spec.has("options"):
			spec["options"] = comparison_options()
		if not spec.has("default_value"):
			spec["default_value"] = "=="
		# The hint has done its job; leaving it on would send the dialog looking for a field factory
		# registered under "comparison", which is not what a dropdown wants.
		spec.erase("hint")
	if spec.has("options"):
		spec["options"] = combo_options(spec["options"])
	return spec


## Registers a custom parameter editor. `tag` matches a param's hint (or its type_name when it
## has no hint); `factory(param_dict, initial_text)` must return a LineEdit (subclass and style
## it freely - add buttons, popups, validation - the dialog reads the final value from .text).
static func register_param_editor(tag: String, factory: Callable) -> void:
	_param_editors[tag] = factory


static func param_editor_for(tag: String) -> Callable:
	return _param_editors.get(tag, Callable())


## What the Parameters dialog's help strip says about a parameter carrying this HINT - the
## paragraph under the parameter's own description, telling the reader what THIS kind of box takes
## and how to answer it. A pack that ships a new hint (with `register_param_editor`) describes it
## here rather than leaving the strip generic on the very field that needed explaining.
##
## One paragraph per hint; last registration wins, and a registration overrides the builtin text.
## Keep it to a sentence or two: the strip is a foot, not a manual.
static func register_param_help(hint: String, paragraph: String) -> void:
	_param_help[hint] = paragraph


## The registered paragraph for a hint, or "" when nothing was registered for it (the builtin table
## answers then).
static func param_help_for(hint: String) -> String:
	return str(_param_help.get(hint, ""))


## Commit-time validation for a param HINT (the generic seam the feature-tag nudge uses):
## `validator(value: String) -> Dictionary` runs when the params dialog commits a field
## with that hint. Return {} to let the commit pass, or a prompt spec to ask the user
## first: {"title", "message", "confirm_text", "cancel_text", "on_confirm": Callable}.
## The dialog owns the tricky part ONCE - the commit is deferred and then delivered
## exactly one time whichever way the prompt closes (confirm, cancel, Esc, titlebar X),
## with on_confirm invoked only on confirm. One validator per hint; last registration wins.
static var _param_commit_validators: Dictionary = {}
static var _builtin_validators_registered: bool = false


static func register_param_commit_validator(hint: String, validator: Callable) -> void:
	_param_commit_validators[hint] = validator


static func param_commit_validator_for(hint: String) -> Callable:
	_ensure_builtin_validators()
	return _param_commit_validators.get(hint, Callable())


static func _ensure_builtin_validators() -> void:
	if _builtin_validators_registered:
		return
	_builtin_validators_registered = true
	register_param_commit_validator("feature_tag", EventSheetFeatureTags.commit_validator)


## Adds a row to the Welcome window's Preferences card: `builder()` returns the Control (built
## fresh each time the Welcome first builds). Give your extension's setting a home without
## inventing a settings dialog.
static func register_preference(builder: Callable) -> void:
	_preference_builders.append(builder)


static func preference_builders() -> Array[Callable]:
	return _preference_builders


## Defines an ACE from a plain Dictionary - no provider script file:
##   {"id": "Dash", "kind": "action",              # action | condition | expression
##    "display_name": "Dash Forward", "category": "My Pack",
##    "template": "velocity.x = {speed} * 2.0",     # the GDScript it compiles to
##    "params": [{"id": "speed", "type_name": "float", "default": "300.0"}],
##    "description": "..."}
## register_simple_ace() puts it in every sheet's picker for the session (re-register on plugin
## load); simple_ace() just builds the definition. Ids are contracts once sheets use them.
static func simple_ace(config: Dictionary) -> ACEDefinition:
	var definition: ACEDefinition = ACEDefinition.new()
	definition.id = str(config.get("id", ""))
	definition.provider_id = str(config.get("provider_id", "Extension"))
	definition.display_name = str(config.get("display_name", definition.id.capitalize()))
	definition.category = str(config.get("category", "Extensions"))
	definition.description = str(config.get("description", ""))
	match str(config.get("kind", "action")):
		"condition":
			definition.ace_type = ACEDefinition.ACEType.CONDITION
		"expression":
			definition.ace_type = ACEDefinition.ACEType.EXPRESSION
		_:
			definition.ace_type = ACEDefinition.ACEType.ACTION
	definition.metadata["codegen_template"] = str(config.get("template", ""))
	for param_config: Variant in (config.get("params", []) as Array):
		if param_config is Dictionary:
			definition.parameters.append(param_spec(param_config as Dictionary))
	return definition


static func register_simple_ace(config: Dictionary) -> ACEDefinition:
	var definition: ACEDefinition = simple_ace(config)
	if definition.id.is_empty():
		push_warning("[EventSheets] register_simple_ace needs an id.")
		return definition
	for index: int in range(_simple_aces.size() - 1, -1, -1):
		if _simple_aces[index].id == definition.id and _simple_aces[index].provider_id == definition.provider_id:
			_simple_aces.remove_at(index)
	_simple_aces.append(definition)
	if _dock_alive() and _dock.has_method("_refresh_ace_registry"):
		_dock.call("_refresh_ace_registry")
	return definition


static func simple_aces() -> Array[ACEDefinition]:
	return _simple_aces


## Runs a custom guided tour through the built-in tour engine. Steps use the same shape as the
## first-time tour: {"title", "body", "task", "check": Callable(sheet)->bool or Callable()}.
## Needs the workspace open; the check (optional) flips the step to Done live.
static func start_tour(steps: Array[Dictionary]) -> bool:
	if not _dock_alive() or not ("_tour" in _dock):
		return false
	_dock._tour.start(steps)
	return true


## Registers a named tour as a Command Palette entry ("Tour: <name>") - packs ship their own
## 2-minute walkthroughs on the engine the built-in tour uses.
static func register_tour(tour_name: String, steps: Array[Dictionary]) -> void:
	register_palette_command("Tour: %s" % tour_name, func() -> void: start_tour(steps))


## In-editor behavior preview (Tools > Preview Behaviors on Selected Node): a behavior opts in
## by shipping a pure static on its emitted script -
##   static func editor_preview_sample(params: Dictionary, base: Dictionary, time: float) -> Dictionary
## (params = the behavior node's exported values, base = the host's captured rest state, return =
## host properties to apply this frame). This call registers a sampler for scripts that CANNOT
## ship the static (third-party or generated code you don't control): `script_path` is the
## behavior script's resource path; `sampler` has the same signature and takes priority.
static func register_editor_preview(script_path: String, sampler: Callable) -> void:
	_editor_preview_samplers[script_path] = sampler


static func editor_preview_sampler_for(script_path: String) -> Callable:
	return _editor_preview_samplers.get(script_path, Callable())


## In-editor behavior gizmos (select a node, its behaviors draw their setup in the 2D viewport):
## a behavior opts in by shipping a pure static on its emitted script -
##   static func editor_gizmo_draw(params: Dictionary, host: Node2D, canvas: CanvasItem) -> void
## (params = the behavior node's live script variables, host = the parent Node2D, canvas = a
## transient child of the host to draw_* on in host-local space; for world-space shapes first
## canvas.draw_set_transform_matrix(host.get_global_transform().affine_inverse())). This call
## registers a drawer for scripts that CANNOT ship the static (third-party or generated code you
## don't control): `script_path` is the behavior script's resource path; `drawer` has the same
## signature and takes priority over the static.
static func register_editor_gizmo(script_path: String, drawer: Callable) -> void:
	_editor_gizmo_drawers[script_path] = drawer


static func editor_gizmo_drawer_for(script_path: String) -> Callable:
	return _editor_gizmo_drawers.get(script_path, Callable())


## Toggles the behavior preview on the current scene-editor selection - the same entry the
## Tools menu and Command Palette use. Returns false when the workspace is not open.
static func preview_behaviors() -> bool:
	if not _dock_alive() or not ("_behavior_preview" in _dock):
		return false
	_dock._behavior_preview.toggle()
	return true


## One-call pack verification for addon authors - the gates that actually bite, bundled:
## the emitted .gd must PARSE (the build + drift audit don't check this), and it must lift
## back and re-emit byte-identically (the lossless covenant). Returns
## {ok, parses, round_trips, errors: Array[String]}.
static func verify_pack(pack_gd_path: String) -> Dictionary:
	var report: Dictionary = {"ok": false, "parses": false, "round_trips": false, "errors": []}
	if not FileAccess.file_exists(pack_gd_path):
		(report["errors"] as Array).append("no such file: %s" % pack_gd_path)
		return report
	var script: Variant = load(pack_gd_path)
	report["parses"] = script is Script and (script as Script).can_instantiate()
	if not bool(report["parses"]):
		(report["errors"] as Array).append("the emitted GDScript does not parse/load: %s" % pack_gd_path)
	var source: String = FileAccess.get_file_as_string(pack_gd_path)
	report["round_trips"] = round_trips(source)
	if not bool(report["round_trips"]):
		(report["errors"] as Array).append("open-as-sheet does not re-emit byte-identically: %s" % pack_gd_path)
	report["ok"] = bool(report["parses"]) and bool(report["round_trips"])
	return report


# ── Asset drops (FileSystem files dragged onto the sheet canvas) ───────────────────────

## extension (lowercase, no dot) -> {"build": Callable, "description": String}
static var _asset_drop_handlers: Dictionary = {}
static var _builtin_asset_drop_handlers_registered: bool = false


## Registers a drop handler for FileSystem files dragged onto the sheet canvas.
## `build(asset_path: String, target_event: Resource) -> Resource` returns:
##   - an ACEAction: appended to the event row the file landed on, or to a fresh
##     On Ready event when it landed on empty space (the effect maps onto the ACTION
##     lane, like every effect in the event model);
##   - any other sheet row resource (a CustomBlockRow such as the preload kind, a
##     RawCodeRow, ...): inserted at the sheet's top level as a declaration;
##   - null to decline this file (the drop reports nothing was added).
## One handler per extension; last registration wins, so an extension can retarget a
## built-in type. The built-in handlers (scenes spawn, sounds play, images and
## resources/scripts preload, JSON loads into a variable) register through this same seam.
static func register_asset_drop_handler(extensions: PackedStringArray, build: Callable, description: String = "") -> void:
	# Register the built-ins FIRST so a caller retargeting a built-in extension lands AFTER
	# them (last-wins). Without this, the built-ins registered lazily on the first drop and
	# clobbered an extension's earlier registration - the exact opposite of the contract.
	# Safe from recursion: _ensure sets its guard flag before its own register calls, so the
	# nested calls short-circuit.
	_ensure_builtin_asset_drop_handlers()
	for extension: String in extensions:
		_asset_drop_handlers[extension.to_lower().trim_prefix(".")] = {"build": build, "description": description}


## The registered builder for one extension (an invalid Callable when unhandled).
static func asset_drop_builder_for(extension: String) -> Callable:
	_ensure_builtin_asset_drop_handlers()
	return ((_asset_drop_handlers.get(extension.to_lower(), {}) as Dictionary).get("build", Callable()) as Callable)


## Every extension the canvas accepts, sorted - the viewport's drop filter reads this,
## so registering a handler makes the drop cursor light up with no other wiring.
static func handled_asset_extensions() -> PackedStringArray:
	_ensure_builtin_asset_drop_handlers()
	var extensions: PackedStringArray = PackedStringArray()
	for extension: Variant in _asset_drop_handlers.keys():
		extensions.append(str(extension))
	extensions.sort()
	return extensions


## Static ace_id -> descriptor index, built once. Built-in descriptors are immutable after
## generation (a standing contract), so a single scan/build is safe to cache - without this,
## every builtin_action() call re-scanned the modules dir and rebuilt the ENTIRE vocabulary
## (hundreds of allocations) just to find one id, so a multi-file drop paid it per file.
static var _builtin_descriptor_index: Dictionary = {}
## Whether the index above has been built, kept APART from its own emptiness - an emptiness test
## puts the re-scan the cache exists to kill straight back on the empty branch.
static var _builtin_descriptor_index_built: bool = false


static func _builtin_descriptor(ace_id: String) -> Variant:
	if not _builtin_descriptor_index_built:
		_builtin_descriptor_index_built = true
		# The registry's cached builtins. This index exists to stop a multi-file asset drop paying
		# for the whole vocabulary per file, and reading it out of the registry means the build is
		# not paid a second time at all.
		for descriptor in ACERegistry.get_builtin_descriptors():
			_builtin_descriptor_index[descriptor.ace_id] = descriptor
	return _builtin_descriptor_index.get(ace_id, null)


## A ready-to-insert ACEAction built from a built-in Core descriptor: identity and
## template copied, {uid} baked fresh so stateful templates stay per-instance - exactly
## what a picker apply produces. The building block asset-drop handlers (and any other
## extension that inserts actions) use instead of re-implementing the apply path.
static func builtin_action(ace_id: String, params: Dictionary) -> ACEAction:
	var descriptor: Variant = _builtin_descriptor(ace_id)
	if descriptor == null:
		return null
	var action: ACEAction = ACEAction.new()
	action.provider_id = descriptor.provider_id
	action.ace_id = ace_id
	action.params = params.duplicate(true)
	action.codegen_template = str(descriptor.codegen_template)
	if action.codegen_template.contains("{uid}"):
		action.codegen_template = action.codegen_template.replace("{uid}", EventSheetDock._fresh_uid_token())
	return action


## A preload Custom Block row (`const Name := preload("res://...")`) for a resource
## path - runs on the Custom Block API's preload kind. The constant name derives from
## the filename (PascalCase, illegal characters stripped, letter-prefixed).
static func preload_block_for(asset_path: String) -> CustomBlockRow:
	var block: CustomBlockRow = CustomBlockRow.new()
	block.kind_id = "preload"
	block.fields = {"name": _preload_constant_name(asset_path), "path": asset_path}
	return block


## Emits a docs/Addons-style guide SKELETON for a pack script: the factual tables (verbs,
## knobs, signals, the Self section) pre-filled from the script itself, the human parts (the 15
## use cases, the tips) left as prompts. "" when the script cannot be read. Loaded by path so
## naming the scaffolder here never joins the editor's boot compile.
static func addon_guide_skeleton(script_path: String) -> String:
	var scaffold: GDScript = load("res://addons/eventsheet/editor/addon_guide_scaffold.gd")
	return scaffold.generate(script_path)


static func _preload_constant_name(asset_path: String) -> String:
	var base: String = asset_path.get_file().get_basename().to_pascal_case()
	var sanitizer: RegEx = RegEx.new()
	sanitizer.compile("[^A-Za-z0-9_]")
	base = sanitizer.sub(base, "", true)
	if base.is_empty() or base[0].is_valid_int():
		base = "Res" + base
	return base


static func _ensure_builtin_asset_drop_handlers() -> void:
	if _builtin_asset_drop_handlers_registered:
		return
	_builtin_asset_drop_handlers_registered = true
	register_asset_drop_handler(PackedStringArray(["tscn", "scn"]), _drop_build_spawn_scene, "Spawn the scene at a position")
	register_asset_drop_handler(PackedStringArray(["ogg", "wav", "mp3"]), _drop_build_play_sound, "Play the sound")
	register_asset_drop_handler(PackedStringArray(["json"]), _drop_build_load_json, "Load the JSON file into a variable")
	# Images are Texture2D resources: a preload const compiles on ANY host and is referenceable,
	# unlike a `self.texture = …` action that fails on a host with no texture member (Node, Node2D,
	# CharacterBody2D, Control...) - which broke the whole sheet's compile.
	register_asset_drop_handler(PackedStringArray(["png", "jpg", "jpeg", "webp", "svg", "bmp", "tga", "ktx", "exr"]), _drop_build_preload, "Preload the image as a constant")
	register_asset_drop_handler(PackedStringArray(["tres", "res", "gd"]), _drop_build_preload, "Preload as a constant")


static func _drop_build_spawn_scene(asset_path: String, _target_event: Resource) -> Resource:
	return builtin_action("SpawnSceneAt", {"path": ACEParamsDialog.format_quoted_literal(asset_path), "position": "Vector2(0, 0)"})


static func _drop_build_play_sound(asset_path: String, _target_event: Resource) -> Resource:
	return builtin_action("PlaySound", {"path": ACEParamsDialog.format_quoted_literal(asset_path)})


static func _drop_build_load_json(asset_path: String, _target_event: Resource) -> Resource:
	return builtin_action("JsonLoadFile", {"var_name": "data", "path": ACEParamsDialog.format_quoted_literal(asset_path)})


static func _drop_build_preload(asset_path: String, _target_event: Resource) -> Resource:
	return preload_block_for(asset_path)


# ── Collection declarations (a function-local `var x := {...}` held as structure) ──────


## Builds a structured in-body collection declaration - the row an opened `.gd`'s canonical
## multi-line dictionary or array lifts into, offered here so extensions and asset-drop
## handlers can CREATE one too instead of assembling raw code text. `entries` is an Array of
## [key, value] pairs for a dictionary ("calm" keys carry their own quotes: `"calm"`), or of
## plain value strings for an array. Returns null when the name is not an identifier or any
## entry is refused (blank value, keyless dictionary entry). Append the result to an
## EventRow's actions like any other action; it emits as the literal, brackets and all, and
## its entries stay individually editable rows on the canvas.
## Builds a Timeline block from [[at_seconds, gdscript_line], ...] pairs - the schedule-as-rows
## companion to collection_decl. Steps sort by time; a malformed pair returns null.
static func timeline(steps: Array = []) -> TimelineRow:
	var row: TimelineRow = TimelineRow.new()
	for entry: Variant in steps:
		if not (entry is Array) or (entry as Array).size() != 2:
			return null
		var code_line: String = str((entry as Array)[1]).strip_edges()
		if code_line.is_empty():
			return null
		var action: RawCodeRow = RawCodeRow.new()
		action.code = code_line
		row.add_step(maxf(float((entry as Array)[0]), 0.0), action)
	return row


static func collection_decl(variable_name: String, entries: Array, dictionary: bool = true) -> CollectionDeclRow:
	var name: String = variable_name.strip_edges()
	var name_regex: RegEx = RegEx.create_from_string("^[A-Za-z_][A-Za-z0-9_]*$")
	if name_regex.search(name) == null:
		return null
	var decl: CollectionDeclRow = CollectionDeclRow.new()
	decl.head = "var %s := %s" % [name, "{" if dictionary else "["]
	decl.close = "}" if dictionary else "]"
	for entry: Variant in entries:
		var accepted: bool = false
		if dictionary and entry is Array and (entry as Array).size() == 2:
			accepted = decl.set_entry(-1, str((entry as Array)[0]), str((entry as Array)[1]))
		elif not dictionary:
			accepted = decl.set_entry(-1, "", str(entry))
		if not accepted:
			return null
	return decl


# ── Manual links (the guides live in the repo, not in the plugin zip) ──────────
#
# The release zip ships `addons/` only, so `res://docs/...` does not exist in an installed
# project - a button that opens a local guide path opens nothing. Every doc link therefore
# resolves to the repo, PINNED TO THE RELEASED TAG, so the page a reader lands on describes
# the exact build they installed rather than whatever `main` looks like today.


## The repository the released plugin is published from. Doc links are built against it.
const DOCS_REPO_URL: String = "https://github.com/SalmanShhh/Godot-EventSheet-Visual-Scripting"

## Where a pack's guide lives, relative to the repo root.
const ADDON_GUIDE_DIR: String = "docs/Addons"

## Pack directories whose guide file is NOT the Title-Case-Words spelling of the directory:
## a plural ("priced_table" is documented as Priced-Tables), a different product name
## ("utility_ai" ships as UtilityBrain), or a companion resource/loader pack documented
## inside its partner's guide ("quest_resource" belongs to Quest). This is an OVERRIDE list,
## not a mapping table: any pack the derivation already reaches stays out of it, and
## the suite sweeps every pack directory against the shipped guides, so a renamed guide fails
## a test instead of shipping a dead link.
const ADDON_GUIDE_OVERRIDES := {
	"abilities": "Simple-Abilities",
	"ability_set_resource": "Simple-Abilities",
	"background_runner": "Run-In-Background",
	"big_number": "Big-Numbers",
	"canvas_surface": "Drawing-Canvas",
	"combo_box": "ComboBox",
	"drag_drop": "Drag-And-Drop",
	"drawing_prefab_resource": "Drawing-Canvas",
	"drawing_prefab_stamp": "Drawing-Canvas",
	"color_palette_resource": "Game-Settings",
	"encounter_resource": "Encounter-Timeline",
	"home_leash": "Home-And-Leash",
	"loot_loader": "Loot-Table",
	"loot_table_resource": "Loot-Table",
	"object_pool": "ObjectPool",
	"platformer_movement": "Platformer",
	"price_table_resource": "Priced-Tables",
	"priced_table": "Priced-Tables",
	"proc_room": "ProcRoom",
	"quality_preset_resource": "Game-Settings",
	"quest_resource": "Quest",
	"random_table_resource": "Advanced-Random",
	"skill_tree_resource": "Upgrades",
	"skin_catalog_loader": "SkinVault",
	"skin_catalog_resource": "SkinVault",
	"skin_vault": "SkinVault",
	"slide_move": "Slide-Movement",
	"stat_forge": "StatForge",
	"touch_shape_library_resource": "Touch-Gestures",
	"stat_sheet_resource": "StatForge",
	"storylet_resource": "Storylet-Weaver",
	"uhtn_plan_resource": "UHTN-Planning",
	"utility_ai": "UtilityBrain",
}

## Where a built-in vocabulary module's guide lives, relative to the repo root. The sibling of
## ADDON_GUIDE_DIR: packs are documented per pack, the built-in verbs per module.
const MODULE_GUIDE_DIR: String = "docs/Modules"

## Where the built-in vocabulary modules live, so the sweep has one place to enumerate them.
const MODULE_DIR: String = "res://addons/eventforge/registration/modules"

## Vocabulary UNITS whose guide file is NOT the Title-Case-Words spelling of the unit. A unit is
## either a module file (`system_aces.gd` -> `system`) or a picker CATEGORY ("Math & Random" ->
## `math_random`), because the two ask the same question from different ends: the docs reader
## arrives holding a module name, the Explain panel arrives holding the category the selected
## verb sits in.
##
## Nearly every module is here, and that is not a mapping table by the back door: the guides are
## written for the READER's question ("how do I move something in 2D?") rather than for the
## file that happens to author the verbs, and several modules were merged into one guide
## (audio + audio_server, physics + physics_server + collision) while two big modules - core and
## system - spread across several. The derivation still runs for anything absent, so a module
## added tomorrow resolves to `docs/Modules/<Title-Case>.md` and the suite's sweep fails on the
## missing file instead of shipping a dead link.
const MODULE_GUIDE_OVERRIDES := {
	# ── module files ──
	"ajax": "Making-Web-Requests",
	"animation_player": "Animation-And-Sprites",
	"array_functional": "Working-With-Lists",
	"audio": "Sound-And-Music",
	"behavior_shape": "Making-Things-Move-In-2D",
	"boomer_weapons": "Working-In-3D",
	# Keys and doors are documented beside the shots and the secrets, because they are the same
	# reader's question - "how do I build a level of this shape" - asked one room later.
	"keys_doors": "Working-In-3D",
	"audio_server": "Sound-And-Music",
	"camera_fov": "Cameras-Graphics-And-Screenshots",
	"clipboard": "Copying-Sharing-And-Remembering-Values",
	"collection": "Working-With-Lists",
	"game_accessibility": "Game-Options-And-The-Window",
	"collision": "Collisions-Joints-And-World-Physics",
	# The filtered touch sentences are the same reader's question as the rest of the collision
	# vocabulary, asked one row later, so they share its guide rather than opening a second one.
	"collision_edge": "Collisions-Joints-And-World-Physics",
	"collision_filter": "Collisions-Joints-And-World-Physics",
	"comparison": "Comparing-Values",
	"timed_input": "Timers-Waiting-And-Cooldowns",
	"composition": "Groups-Tags-And-Systems",
	"console": "Debugging-And-Printing",
	"controls": "Reading-Keyboard-Mouse-And-Gamepad",
	# What the ONE event a handler was handed is, which is the same reader's question as the rest of
	# the input vocabulary - "how do I read the controls" - asked from inside `_input` rather than from
	# a tick. Same page, one section further down, rather than a page nobody would look for it under.
	"input_event": "Reading-Keyboard-Mouse-And-Gamepad",
	"core": "Triggers-Signals-And-When-Rows-Run",
	# The four things the engine tells a node about through its notification callback are triggers,
	# and a reader looking for them is asking the triggers guide's question: when does this row run.
	# The category is plural and the module file is not, so both spellings key the same page.
	"notification": "Triggers-Signals-And-When-Rows-Run",
	"notifications": "Triggers-Signals-And-When-Rows-Run",
	"dev": "Debugging-And-Printing",
	"device": "Reading-Keyboard-Mouse-And-Gamepad",
	"drawing": "Particles-And-Drawing-On-Screen",
	"facing": "Mirroring-And-Flipping",
	"file": "Working-With-Files",
	"gradient_curve": "Colors-Gradients-And-Curves",
	"helper": "Calling-Your-Own-Code-From-Rows",
	"host": "Calling-Your-Own-Code-From-Rows",
	"input": "Setting-Up-And-Rebinding-Controls",
	"json": "Working-With-Files",
	# Lights are what a scene is LIT with, which is the graphics guide's subject - the same guide a
	# reader lands on from the camera and screenshot rows. The node-scoped light words are the same
	# subject said the other way round (the light in the object column rather than in a field), so
	# they land on the same page rather than splitting the reader's lighting into two.
	"lighting": "Cameras-Graphics-And-Screenshots",
	"light_node": "Cameras-Graphics-And-Screenshots",
	# The darkness a layer wears and the world's own atmosphere are the same reader's question
	# one step out from the lights, so the three modules land on the one page rather than three.
	"scene_lighting": "Cameras-Graphics-And-Screenshots",
	# And turning a shader's dials is that question one step further out - how the picture is made -
	# so it lands on the same page rather than starting a fourth one.
	"effect_dial": "Cameras-Graphics-And-Screenshots",
	"locale_asset": "Localising-Your-Game",
	"video": "Playing-Video",
	"loop": "Working-With-Lists",
	"mesh": "Working-In-3D",
	"native_3d": "Working-In-3D",
	# The 3D page's own verbs - moving in a direction, the three turns, placing and
	# the facing questions - are the same subject the 3D guide already covers, said in plainer words.
	"spatial_words": "Working-In-3D",
	"node": "Finding-And-Rearranging-Nodes",
	"node_activation": "Scenes-Pausing-And-Turning-Nodes-Off",
	"options": "Game-Options-And-The-Window",
	"particle": "Particles-And-Drawing-On-Screen",
	# Walking a drawn route is a way of moving something, so it reads under the movement guide
	# rather than under a page of its own.
	"path_follow": "Making-Things-Move-In-2D",
	"physics": "Collisions-Joints-And-World-Physics",
	"physics_server": "Collisions-Joints-And-World-Physics",
	"procedural": "Doing-Math-And-Randomness",
	# The cursor's ray IS a 3D raycast, and the canvas words that go with it are
	# read and written beside it, so both share the 3D raycasting guide rather than opening a page
	# nobody would look for them under.
	"cursor_canvas": "Raycasting-And-Overlaps-In-3D",
	"raycast": "Raycasting-And-Overlaps-In-2D",
	"regex": "Working-With-Text",
	"rendering": "Cameras-Graphics-And-Screenshots",
	"resource": "Reading-Spreadsheets-And-Data-Assets",
	"spatial": "Working-With-Vectors-And-Directions",
	# The game's own mode is the other half of pausing: what a mode DOES to the game on entering is
	# the pause flag and the mouse, so its vocabulary reads beside them rather than on a page of its
	# own that a reader looking for "how do I pause during a cutscene" would never open.
	"game_state": "Scenes-Pausing-And-Turning-Nodes-Off",
	# And ONE OBJECT's own state reads under variables, because that is exactly what it is: an
	# enum plus a variable compared in conditions and set in actions. A page of its own would
	# suggest a state is a new kind of thing, which is the one idea this vocabulary is against.
	"object_state": "Setting-And-Changing-Variables",
	"system": "Timers-Waiting-And-Cooldowns",
	"table": "Reading-Spreadsheets-And-Data-Assets",
	"testing": "Testing-Your-Game",
	"text_extract": "Working-With-Text",
	"text_fit": "Making-Text-Readable-On-Screen",
	"text_format": "Making-Text-Readable-On-Screen",
	"tilemap": "Working-With-Tilemaps",
	"tooling": "Automating-The-Editor",
	# The Editor object is a second FILE of the same vocabulary (one category, one object), so it
	# resolves to the same guide - a reader who followed a dock verb here must not land somewhere else
	# than a reader who followed a Save Scene one.
	"editor_object": "Automating-The-Editor",
	# The tool author's everyday Editor set is the same subject as the two modules beside it, so
	# it reads in the same guide rather than in a page of its own.
	"editor_author": "Automating-The-Editor",
	"translation": "Localising-Your-Game",
	"translation_quality": "Localising-Your-Game",
	"ui": "Buttons-Sliders-Labels-And-Menus",
	"vibration": "Reading-Keyboard-Mouse-And-Gamepad",
	"window": "Game-Options-And-The-Window",
	# ── picker categories ──
	# The categories a module's file name cannot answer for: core and system each author several
	# guides' worth of vocabulary, and raycast authors both casting guides, so a verb selected in
	# the picker resolves through the category it is filed under instead.
	"animation": "Animation-And-Sprites",
	"behavior": "Calling-Your-Own-Code-From-Rows",
	"camera": "Cameras-Graphics-And-Screenshots",
	"collisions": "Collisions-Joints-And-World-Physics",
	"color": "Colors-Gradients-And-Curves",
	"compare_numbers": "Comparing-Values",
	"compare_objects": "Comparing-Values",
	"compare_text": "Comparing-Values",
	"compare_types": "Comparing-Values",
	"compare_vectors": "Comparing-Values",
	"debug": "Debugging-And-Printing",
	"display": "Game-Options-And-The-Window",
	"editor_tools": "Automating-The-Editor",
	# The Editor object's picker PAGES. They are folders inside the same object, so they read in
	# the same guide the flat category always did.
	"editor_tools_panels_menus": "Automating-The-Editor",
	"editor_tools_project_preferences": "Automating-The-Editor",
	"effects": "Particles-And-Drawing-On-Screen",
	"files": "Working-With-Files",
	"files_directories": "Working-With-Files",
	"files_tables": "Reading-Spreadsheets-And-Data-Assets",
	"functions": "Calling-Your-Own-Code-From-Rows",
	"game_options": "Game-Options-And-The-Window",
	"game_window": "Game-Options-And-The-Window",
	# The three cross-cutting picker sections are not one guide's vocabulary: "General Actions"
	# alone spans sound, sprites, cameras, text, movement, physics and 3D. They resolve to the
	# module index, which is the honest answer to "where do I read about this section?" - every
	# guide, grouped by task, one hop from the verb the reader had selected.
	"general_actions": "README",
	"general_conditions": "README",
	"general_expressions": "README",
	"gamepad": "Reading-Keyboard-Mouse-And-Gamepad",
	"gradients_curves": "Colors-Gradients-And-Curves",
	"groups": "Groups-Tags-And-Systems",
	"helpers": "Calling-Your-Own-Code-From-Rows",
	"inputmap": "Setting-Up-And-Rebinding-Controls",
	"joints": "Collisions-Joints-And-World-Physics",
	"keyboard": "Reading-Keyboard-Mouse-And-Gamepad",
	"loops": "Working-With-Lists",
	"math_random": "Doing-Math-And-Randomness",
	# The value-shaping statements (keep between, move toward, rescale, wrap) read beside the
	# expressions they are the statement forms of, so one guide covers both.
	"math_words": "Doing-Math-And-Randomness",
	"metadata": "Finding-And-Rearranging-Nodes",
	"mouse": "Reading-Keyboard-Mouse-And-Gamepad",
	"movement": "Making-Things-Move-In-2D",
	# The moves that name their space and the three turns are 2D movement, whatever else they say.
	"space_words": "Making-Things-Move-In-2D",
	"spawn": "Spawning-Copies-Of-Scenes",
	# Removing is the other half of the same page: the rows that take a copy back out of the world
	# read next to the rows that put it there, and the guard belongs beside the name it protects.
	"removal": "Spawning-Copies-Of-Scenes",
	# And the plural is the third half of it: a crowd is only ever the copies a spawn row made, so
	# the cap, the count and the emptying read beside the row that put them there.
	"crowd": "Spawning-Copies-Of-Scenes",
	# The two arrival triggers read with the rest of "when does this row run", beside the aggregate
	# group conditions they are the per-member answer to - not on the spawning page, because a node
	# joining a group did not have to be spawned by anybody to get there.
	"group_arrival": "Triggers-Signals-And-When-Rows-Run",
	# Batch thirteen's two new picker sections. The world's look is the graphics guide's
	# subject (the same guide the camera and light rows land on); UI standing in the world is the 3D
	# guide's, because everything about it is a 3D node.
	"environment": "Cameras-Graphics-And-Screenshots",
	"world_space_ui": "Working-In-3D",
	"nodes": "Finding-And-Rearranging-Nodes",
	"nodes_activation": "Scenes-Pausing-And-Turning-Nodes-Off",
	"nodes_picking": "Finding-And-Rearranging-Nodes",
	"overlap_2d": "Raycasting-And-Overlaps-In-2D",
	"overlap_3d": "Raycasting-And-Overlaps-In-3D",
	"particles": "Particles-And-Drawing-On-Screen",
	"performance": "Timers-Waiting-And-Cooldowns",
	"platform": "Game-Options-And-The-Window",
	"raycast_2d": "Raycasting-And-Overlaps-In-2D",
	"raycast_3d": "Raycasting-And-Overlaps-In-3D",
	"run_context": "Debugging-And-Printing",
	"scene": "Scenes-Pausing-And-Turning-Nodes-Off",
	"signals_scene_input": "Triggers-Signals-And-When-Rows-Run",
	"systems": "Groups-Tags-And-Systems",
	"text": "Working-With-Text",
	"text_regex": "Working-With-Text",
	"time": "Timers-Waiting-And-Cooldowns",
	"touch": "Reading-Keyboard-Mouse-And-Gamepad",
	"translation_voice": "Localising-Your-Game",
	"tween": "Timers-Waiting-And-Cooldowns",
	"utility_debug": "Debugging-And-Printing",
	"utility_nodes": "Finding-And-Rearranging-Nodes",
	"utility_settings": "Game-Options-And-The-Window",
	"utility_time": "Timers-Waiting-And-Cooldowns",
	"utility_window": "Game-Options-And-The-Window",
	"variables": "Setting-And-Changing-Variables",
	"variables_array": "Working-With-Lists",
	"variables_dictionary": "Working-With-Records",
	"variables_string": "Working-With-Text",
	"variables_vector": "Working-With-Vectors-And-Directions",
}

## What counts as part of a word when a vocabulary unit is folded into a lookup key. Everything
## else - spaces, "&", ":", "/" - is a separator, so a picker category keys the same way a module
## file name does.
const _UNIT_WORD_CHARACTERS: String = "abcdefghijklmnopqrstuvwxyz0123456789"

## Words that are acronyms in a guide file name, so `fps_controller` derives FPS-Controller
## rather than Fps-Controller.
const _GUIDE_ACRONYMS := {
	"2d": "2D", "3d": "3D", "ai": "AI", "fps": "FPS", "fx": "FX", "htn": "HTN", "hud": "HUD",
	"npc": "NPC", "uhtn": "UHTN", "ui": "UI",
}

## provider id -> pack directory, built in ONE pass over the addon scripts and reused for the
## whole session. Per-provider scanning was measured at ~63 ms per newly seen provider on a
## corpus this size, and this map is read on the picker's selection-change path, so a
## per-provider scan is a visible stall every time the reader arrows onto a new pack. Builtin
## providers are not in the map at all - the miss must cost nothing, not a full corpus read.
static var _pack_dir_by_provider: Dictionary = {}
## Set ONLY by the function that fills the map completely (a flag pre-set by a partial scan is
## how a lazy cache silently loses entries).
static var _pack_dir_map_built: bool = false
## pack directory -> its `@ace_help` URL ("" when it declares none), so the doc panel's per-page
## read path also costs one directory read per pack per session rather than one per page.
static var _pack_help_by_dir: Dictionary = {}


## The version every doc link is pinned to - the same constant the release ritual bumps, so a
## shipped build always points at its own tag.
static func docs_version() -> String:
	return SheetCompiler.VERSION


## The absolute URL of a repo-relative documentation path, pinned to the released tag.
## `relative_path` is repo-relative ("docs/GUIDE-MOVING-FROM-ANOTHER-EVENT-SHEET-EDITOR.md"); `anchor` is a
## GitHub heading slug, with or without its leading "#". Returns "" for an empty path.
## An already-absolute http(s) URL is returned unchanged, so a pack that hosts its guide
## elsewhere flows through the same call.
static func doc_url(relative_path: String, anchor: String = "") -> String:
	var path: String = relative_path.strip_edges().trim_prefix("res://").trim_prefix("/")
	if path.is_empty():
		return ""
	var url: String = path
	if not (path.begins_with("http://") or path.begins_with("https://")):
		url = "%s/blob/v%s/%s" % [DOCS_REPO_URL, docs_version(), path]
	var slug: String = anchor.strip_edges().trim_prefix("#")
	if not slug.is_empty():
		url += "#" + slug
	return url


## Opens a repo guide in the reader's browser, pinned to the released tag so the page always
## matches the installed plugin. Returns false when the path is empty (nothing is opened).
static func open_online_doc(relative_path: String, anchor: String = "") -> bool:
	var url: String = doc_url(relative_path, anchor)
	if url.is_empty():
		return false
	OS.shell_open(url)
	return true


## What a pack brings with it besides its script: `{"shader": path, "scene": path}`, each "" when the
## pack ships none. Derived from the pack's own folder - the one `.gdshader` beside the script is its
## shader and the one `.tscn` beside it is the scene adding the pack drops in - so a pack author
## ships an asset by putting it in the folder, with nothing to declare.
static func pack_shipped_assets(pack_script_path: String) -> Dictionary:
	return EventSheetPackAssets.shipped_by(pack_script_path)


## Copies a pack's shipped shader into the author's project and makes sure a material wears it,
## answering `{"ok", "shader_path", "material_path", "created"}`. Nothing is ever overwritten, so
## adding the pack to a second node finds the first node's files and uses them; `created` names only
## what this call really wrote. `into_folder` defaults to `res://effects`.
##
## This is what adding an effect pack to an object does, exposed so a pack's own tooling can do it
## on its own terms - a wizard that sets a project up, a test that installs into `user://`.
static func install_pack_effect(shipped_shader: String, into_folder: String = EventSheetPackAssets.DEFAULT_FOLDER) -> Dictionary:
	return EventSheetPackAssets.install(shipped_shader, into_folder)


## The docs/Addons guide file name (no extension) for a pack directory: the override when the
## pack has one, otherwise the Title-Case-Words spelling of the directory. "" for an empty name.
static func addon_guide_name(pack_dir: String) -> String:
	var directory: String = pack_dir.strip_edges().trim_suffix("/").get_file()
	if directory.is_empty():
		return ""
	if ADDON_GUIDE_OVERRIDES.has(directory):
		return str(ADDON_GUIDE_OVERRIDES[directory])
	var words: PackedStringArray = PackedStringArray()
	for word: String in directory.split("_", false):
		if _GUIDE_ACRONYMS.has(word.to_lower()):
			words.append(str(_GUIDE_ACRONYMS[word.to_lower()]))
		else:
			words.append(word.substr(0, 1).to_upper() + word.substr(1))
	return "-".join(words)


## Where a pack's documentation lives: the pack's own `@ace_help` value when it set one (a
## third party hosting docs elsewhere always wins), otherwise the derived repo-relative guide
## path. "" when neither resolves. Pure - the caller supplies the help value - so the Phase 2
## "addon:<pack>" doc ids and the picker's "Open <Pack>'s guide" button share one resolution.
static func addon_guide_target(pack_dir: String, help_url: String = "") -> String:
	var override: String = help_url.strip_edges()
	if not override.is_empty():
		return override
	var guide: String = addon_guide_name(pack_dir)
	if guide.is_empty():
		return ""
	return "%s/%s.md" % [ADDON_GUIDE_DIR, guide]


## The docs/Modules guide file name (no extension) for a built-in vocabulary UNIT - a module file
## (`system_aces.gd`, `res://.../system_aces.gd`, or plain `system`) or a picker category
## ("Math & Random"). The override when the unit has one, otherwise the Title-Case-Words spelling.
## "" for an empty name. The mirror of addon_guide_name, and frozen with it.
static func module_guide_name(module_or_category: String) -> String:
	var unit: String = module_guide_unit(module_or_category)
	if unit.is_empty():
		return ""
	if MODULE_GUIDE_OVERRIDES.has(unit):
		return str(MODULE_GUIDE_OVERRIDES[unit])
	var words: PackedStringArray = PackedStringArray()
	for word: String in unit.split("_", false):
		if _GUIDE_ACRONYMS.has(word.to_lower()):
			words.append(str(_GUIDE_ACRONYMS[word.to_lower()]))
		else:
			words.append(word.substr(0, 1).to_upper() + word.substr(1))
	return "-".join(words)


## Where a built-in vocabulary unit's documentation lives, as a repo-relative path. "" when the
## unit resolves to nothing. Pure - it does not touch the disk - so the "module:<name>" doc ids,
## the Explain panel's "read more" link and the suite's sweep share one resolution. The mirror of
## addon_guide_target; there is no per-unit override URL because built-in vocabulary is only ever
## documented in this repo.
static func module_guide_target(module_or_category: String) -> String:
	var guide: String = module_guide_name(module_or_category)
	if guide.is_empty():
		return ""
	return "%s/%s.md" % [MODULE_GUIDE_DIR, guide]


## The lookup key for a unit: file name and path decoration dropped, the `_aces` suffix dropped,
## and everything else folded to lowercase words joined by "_" - so `res://.../text_fit_aces.gd`,
## `text_fit_aces.gd` and `Text Fit` all key the same guide, and a category's punctuation
## ("Math & Random", "Variables: Array", "Signals / Scene / Input") never reaches the dictionary.
static func module_guide_unit(module_or_category: String) -> String:
	var raw: String = module_or_category.strip_edges()
	if raw.contains("/") or raw.contains("\\") or raw.ends_with(".gd"):
		raw = raw.replace("\\", "/").get_file().get_basename()
	raw = raw.trim_suffix("_aces")
	var words: PackedStringArray = PackedStringArray()
	var current: String = ""
	for index: int in raw.length():
		var character: String = raw[index].to_lower()
		if _UNIT_WORD_CHARACTERS.contains(character):
			current += character
			continue
		if not current.is_empty():
			words.append(current)
			current = ""
	if not current.is_empty():
		words.append(current)
	return "_".join(words)


## Every built-in vocabulary module on disk, as lookup units, sorted. THE sweep list: the suite
## walks it and fails when a unit's guide is missing, which is what keeps a renamed guide or a
## newly added module from shipping as a dead "module:<name>" link.
static func module_guide_units() -> PackedStringArray:
	var units: PackedStringArray = PackedStringArray()
	for file_name: String in DirAccess.get_files_at(MODULE_DIR):
		if not file_name.ends_with(".gd"):
			continue  # skips the .gd.uid sidecars
		var unit: String = module_guide_unit(file_name)
		if not unit.is_empty() and not units.has(unit):
			units.append(unit)
	units.sort()
	return units


## The pack directory a verb's provider id belongs to ("PricedTableBehavior" -> "priced_table"),
## found by locating the script that declares that class_name under the addon directories.
## "" for a builtin or project-local provider, which has no pack guide.
static func addon_pack_directory(provider_id: String) -> String:
	var wanted: String = provider_id.strip_edges()
	if wanted.is_empty():
		return ""
	_ensure_pack_directory_map()
	return str(_pack_dir_by_provider.get(wanted, ""))


## Reads every addon script ONCE and records every class_name it finds against the directory it
## was declared in. The scan already had to open every file to answer one question, so answering
## all of them in the same pass is free - and it makes a builtin provider's "no pack" answer a
## dictionary miss instead of a full-corpus read.
static func _ensure_pack_directory_map() -> void:
	if _pack_dir_map_built:
		return
	var matcher: RegEx = RegEx.create_from_string("(?m)^class_name[ \\t]+([A-Za-z_][A-Za-z0-9_]*)")
	for script_path: String in EventSheetAddonScanner.list_addon_scripts():
		var source: String = _read_text_file(script_path)
		if source.is_empty():
			continue
		var directory: String = script_path.get_base_dir().get_file()
		for found: RegExMatch in matcher.search_all(source):
			var declared: String = found.get_string(1)
			if not _pack_dir_by_provider.has(declared):
				_pack_dir_by_provider[declared] = directory
	_pack_dir_map_built = true


## The documentation target for a PACK DIRECTORY: its own `@ace_help` URL when it declares one,
## otherwise the derived docs/Addons guide path. "" for a directory that resolves to no guide.
## This is what an "addon:<pack>" doc id resolves through.
static func addon_guide_for_pack(pack_dir: String) -> String:
	var directory: String = pack_dir.strip_edges().trim_suffix("/").get_file()
	if directory.is_empty():
		return ""
	return addon_guide_target(directory, _addon_help_annotation(directory))


## The documentation target for a verb's provider: its pack's `@ace_help` URL when the pack
## declares one, otherwise the derived docs/Addons guide path. "" when the provider is not a
## pack (builtin vocabulary, or a project-local provider script).
static func addon_guide_for_provider(provider_id: String) -> String:
	return addon_guide_for_pack(addon_pack_directory(provider_id))


## Opens a pack's guide in the browser - the pinned repo page, or the pack's own `@ace_help`
## URL. False when the provider has no guide, so a caller can hide the button.
static func open_addon_guide(provider_id: String) -> bool:
	return open_online_doc(addon_guide_for_provider(provider_id))


## Every provider id declared inside a pack directory, sorted. The inverse of
## addon_pack_directory, answered from the same one-pass map - so asking "what does this pack
## publish?" costs a dictionary walk rather than a second scan of every addon script.
static func pack_providers(pack_dir: String) -> PackedStringArray:
	var wanted: String = pack_dir.strip_edges().trim_suffix("/").get_file()
	var providers: PackedStringArray = PackedStringArray()
	if wanted.is_empty():
		return providers
	_ensure_pack_directory_map()
	for provider_id: Variant in _pack_dir_by_provider:
		if str(_pack_dir_by_provider[provider_id]) == wanted:
			providers.append(str(provider_id))
	providers.sort()
	return providers


## Every verb the LIVE registry currently offers for a provider, as immutable ACEDefinitions.
## Editor-only, like find_ace: an empty array when no dock is open, which is what lets a headless
## caller fall back to a script-level derivation instead of reporting a pack with no verbs.
##
## Treat the definitions as read-only - they are statically cached and shared across every tab.
static func provider_verbs(provider_id: String) -> Array[ACEDefinition]:
	if not _dock_alive():
		return []
	return _dock._ace_registry.get_provider_definitions(provider_id)


## Selects and scrolls to the `index`-th row of the open sheet that uses a verb, unfolding any
## group it is hidden inside. The "go to first / next" of the Manual's reference entries: reading
## about a verb and finding where you already use it is one gesture, and this is its second half.
##
## False when no sheet is open, when nothing in it uses that verb, or when the index is past the
## end - so a caller says "not used here" rather than reporting a jump that never happened.
static func reveal_verb_row(provider_id: String, ace_id: String, index: int = 0) -> bool:
	if not _dock_alive():
		return false
	var rows: Array[Resource] = EventSheetDocUsage.rows_using(current_sheet(), provider_id, ace_id)
	if index < 0 or index >= rows.size():
		return false
	var viewport: EventSheetViewport = _dock._viewport
	return viewport != null and viewport.reveal_resource(rows[index])


## Where the reader's whole PROJECT already uses a verb, as [{sheet, count, rows}] - the reverse
## door of a reference entry, which turns their own game into its example gallery.
##
## The join is made fresh every time it is asked for and stored nowhere: the sheets it walks are the
## open tabs and the files already on disk, and a cached count is a count that is wrong the moment
## somebody adds a row. Empty outside the editor, where there are no tabs to ask.
static func project_uses_of(definition: ACEDefinition) -> Array[Dictionary]:
	if definition == null:
		return []
	var open_sheets: Dictionary = {}
	if _dock_alive():
		open_sheets = EventSheetFindReferences.open_sheets_of(_dock)
	return EventSheetDocProjectUsage.gather(definition, open_sheets)


## Opens the sheet a project-wide result names and lands on the event at `line`, the same way a Find
## results row does - one door for "take me to that row in that file", so the Manual and the find
## bar can never disagree about how a cross-sheet landing works.
##
## False when there is no workspace open, so a caller reports it rather than looking like it worked.
static func reveal_project_row(sheet_path: String, line: int) -> bool:
	if not _dock_alive() or sheet_path.strip_edges().is_empty():
		return false
	return _dock._find_results.jump_to_line(sheet_path, line)


## Every verb the LIVE registry currently offers, as immutable ACEDefinitions. Editor-only like
## provider_verbs: an empty array when no dock is open, so a headless caller falls back to a
## script-level derivation rather than reporting a project with no vocabulary.
##
## This is what the Manual's reference pages are built from - one page per category, listing the
## conditions, actions and expressions that category publishes - so the reference can never
## disagree with the picker: it is the picker's own data.
##
## Treat the definitions as read-only - they are statically cached and shared across every tab.
static func all_verbs() -> Array[ACEDefinition]:
	if not _dock_alive():
		return []
	return _dock._ace_registry.get_all_definitions()


## Searches the documentation corpus - the shipped guides, plus every pack guide and project guide
## discovered on disk. Each result is a row that can be acted on directly:
##   {doc_id, page_id, title, heading, anchor, score}
## `doc_id` and `anchor` feed straight back into open_docs. Results are ranked best-first (a title
## hit outranks a heading hit outranks a body hit); an empty query lists every page.
static func search_docs(query: String, limit: int = 25) -> Array[Dictionary]:
	return EventSheetDocSearch.search(query, limit)


## Where this project keeps its own Markdown guides - the `eventsheets/project/docs_dir` setting,
## with its default. Every .md file there joins the Manual's tree under "This
## project", so a team's own notes read beside the plugin's guides.
static func user_docs_dir() -> String:
	return EventSheetDocLibrary.user_docs_dir()


## Opens the Manual on `doc_id`. THE one entry point - Tools ▸ Manual…,
## F1, the row menu's "What does this do?" and any third-party caller all come through here.
##
## The id scheme, frozen with this method:
##   ""                             the index (the shipped guide tree)
##   "ace:<provider_id>/<ace_id>"   one verb, drawn from the live registry
##   "section:<header text>"        a picker category and its blurb
##   "addon:<pack directory>"       a pack's guide
##   "guide:<page id>"              a shipped guide page ("guide:GUIDE-RECIPES")
##   "module:<module name>"         a vocabulary module's guide
##
## An id that names nothing real returns FALSE and warns - never a blank page, because a
## silently empty doc surface is exactly how a renamed guide ships unnoticed.
##
## `anchor` is a heading slug. It reaches the browser routes today (the guides live in the repo,
## so a pack guide opens at its own heading); the generated verb and section pages are single
## cards with nothing to jump to, so they ignore it.
##
## A GUIDE id is drawn natively when the plugin ships that page, and opens the version-pinned repo
## page in the reader's browser when it does not - which is how a third-party pack hosting its
## docs elsewhere, and a guide the bundle deliberately leaves out, both still answer. A caller
## never has to know which route it got: that is the point of one entry point.
static func open_docs(doc_id: String = "", anchor: String = "") -> bool:
	var route: Dictionary = EventSheetDocExplain.resolve(doc_id)
	if not bool(route.get("valid", false)):
		push_warning("EventSheets.open_docs: nothing is documented under \"%s\"." % doc_id)
		return false
	# A guide page that did not ship inside the plugin has no surface to draw it, with or without
	# an editor: the browser is the whole answer, so it runs before the dock check.
	if not EventSheetDocLibrary.has_page(str(route.get("page_id", ""))) and not str(route.get("target", "")).is_empty():
		return open_online_doc(str(route.get("target", "")), anchor)
	if not _dock_alive():
		return false
	# resolve() can only check an "ace:" id's SHAPE - a verb's existence needs the running
	# registry, which lives here. Without this, "ace:RemovedPack/Verb" (a verb whose pack was
	# renamed or deleted) reads as a valid route and the host's index fallback turns the miss
	# into a `true`, which is exactly the silently-blank-page failure this id scheme forbids.
	if str(route.get("scheme", "")) == "ace":
		if find_ace(str(route.get("provider_id", "")), str(route.get("ace_id", ""))) == null:
			push_warning("EventSheets.open_docs: nothing is documented under \"%s\"." % doc_id)
			return false
	return _dock.open_documentation(doc_id, anchor)


## The `## @ace_help("...")` value declared anywhere in a pack directory, or "". Cached per
## directory: this sits on the doc panel's per-page path, and a pack's scripts do not move
## while the editor is open.
static func _addon_help_annotation(pack_dir: String) -> String:
	if _pack_help_by_dir.has(pack_dir):
		return str(_pack_help_by_dir[pack_dir])
	var found: String = _help_annotation_in_dir("res://eventsheet_addons/".path_join(pack_dir))
	_pack_help_by_dir[pack_dir] = found
	return found


## The `## @ace_help("...")` value declared by any .gd file directly inside `directory`, or "".
## Takes an absolute directory rather than a pack name so the read path itself is testable
## against a fixture rather than only through the pure caller-supplies-the-URL route.
static func _help_annotation_in_dir(directory: String) -> String:
	var dir: DirAccess = DirAccess.open(directory)
	if dir == null:
		return ""
	var matcher: RegEx = RegEx.create_from_string("@ace_help\\(\\s*\"([^\"]+)\"\\s*\\)")
	for entry: String in dir.get_files():
		if entry.get_extension() != "gd":
			continue
		var found: RegExMatch = matcher.search(_read_text_file(directory.path_join(entry)))
		if found != null:
			return found.get_string(1).strip_edges()
	return ""


static func _read_text_file(path: String) -> String:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	return file.get_as_text()


# ── Inserting authored rows (doc figures, snippet libraries, generators) ──────────────


## Inserts snippet TEXT (see EventSheetSnippet - the same versioned form the editor's Copy
## produces) below the selection as ONE undo step, creating any sheet variables it needs.
## Returns false when no sheet is open or the text is not a snippet.
##
## This is the ONLY public insertion route, and it is deliberately a thin front on the dock's
## already-guarded paste path: that path assigns fresh event uids and creates missing sheet
## variables without ever overwriting one. `label` names the undo step, so "Insert Figure" reads
## as itself in the undo history.
##
## Never hold a row or resource reference across this call - the undo funnel commits by replacing
## resources with snapshot duplicates, so re-fetch from current_sheet() afterwards.
##
## `as_example` dashes the rows that land with the tune-me marks: the reader asked for a WORKED
## EXAMPLE, so every literal in it is the example's value rather than an answer, and the marks say so
## until they edit the row or reopen the sheet. It changes nothing about what is inserted or what it
## compiles to - a marked row and an unmarked one emit the same bytes.
static func insert_snippet(text: String, label: String = "Insert Snippet", as_example: bool = false) -> bool:
	if not _dock_alive():
		return false
	if not EventSheetSnippet.is_snippet_text(text):
		return false
	# The sheet is checked HERE rather than inherited from the paste path's answer: that path
	# returns true for "this text WAS a snippet, do not fall back to the internal clipboard",
	# which is a different question and is true even when it inserted nothing. A docs window that
	# outlived a tab close would otherwise report a successful insert into no sheet at all.
	if current_sheet() == null:
		return false
	var inserted: bool = _dock._paste_snippet_text(text, label)
	if inserted and as_example:
		_dock.mark_last_insert_as_example()
	return inserted


## How much of what a sheet says about the NETWORK arrived as rows:
## `{"read": int, "blocked": int, "total": int, "percent": int}`. `total` counts the lines that
## mention Godot's high-level multiplayer at all - the peer, the messages, the authority questions,
## the connection's own signals - and `blocked` is how many of those the canvas can only show as a
## script block. The census behind the head's "reads as" band, exposed so a pack that adds its own
## networking (a lobby service, a relay) can report the same number about the same sheet instead of
## inventing a second one. Pass null (or a sheet that says nothing about the network) and every
## count is zero with `percent` 100.
static func networking_coverage(sheet: EventSheetResource) -> Dictionary:
	return EventSheetReadingCoverage.networking(sheet)


## The same count in the words the sheet shows: "every networking line reads as a row - 9 of 9", or
## "7 of 9 networking lines read as rows" when some of it stayed code. "" when the sheet says nothing
## about the network, because "0 of 0" is a number with nothing in it. Translated through the editor
## language like every other string the canvas draws.
static func networking_coverage_text(sheet: EventSheetResource) -> String:
	return EventSheetReadingCoverage.networking_text(sheet)


## Every property of this sheet's own object that a `MultiplayerSynchronizer` in its scene keeps in
## step - the half of Godot's multiplayer that lives in the `.tscn` and in no line of the script.
## One entry per property, in the order the replication config numbers them:
##   {"name", "property_path", "mode", "synchronizer", "synchronizer_path", "scene_path",
##    "node_path", "interval", "public_visibility"}
## `name` is the bare property a variable row shows (`hp`), `property_path` the `NodePath` spelling
## the config holds (`.:hp`), and `mode` one of "always" / "on change" / "at spawn" - the three the
## Replication panel offers. `interval` is the synchronizer's `replication_interval` in seconds (0
## for every frame) and `public_visibility` says whether every peer sees it.
##
## READ-ONLY and derived on every ask: nothing about replication is stored in the sheet, so a
## `.gd` still round-trips byte-for-byte and a project with no scenes gets an empty list. Ordinary
## Dictionaries, so a pack reading them needs nothing of this plugin at runtime.
static func synced_properties(sheet: EventSheetResource) -> Array[Dictionary]:
	return _typed_dictionaries(EventSheetSceneReplication.for_script(
		str(sheet.external_source_path) if sheet != null else "").get("synced", []))


## Every `MultiplayerSpawner` this sheet is about: the ones IN its own scene (which a Spawn row can
## address) and the ones anywhere else whose spawnable list can make its scene (which is what
## "spawned by" on the head stands for). One entry each:
##   {"name", "node_path", "scene_path", "spawn_path", "spawn_limit", "spawn_function", "scenes",
##    "relation"}
## `relation` is "in_scene" or "spawns_this" - which of the two questions this entry answers - and
## `spawn_function` is read from the scene's own GDScript, because Godot never stores a Callable in a
## `.tscn`; it is "" when no line sets one. Same contract as `synced_properties`: read-only, derived,
## and empty for a sheet no scene uses.
static func spawners_of(sheet: EventSheetResource) -> Array[Dictionary]:
	return _typed_dictionaries(EventSheetSceneReplication.for_script(
		str(sheet.external_source_path) if sheet != null else "").get("spawners", []))


## Every light in the scene (or scenes) that run this sheet's script, in scene order. One entry
## each:
##   {"name", "path", "class", "kind", "shadows", "masks", "shadow_masks", "reference",
##    "scene_path", "properties"}
## `kind` is the plain word for the class - point / directional / omni / spot - and `reference` the
## spelling a row addresses the light by (`$Torch`, `$Props/Lantern`, `self`). `masks` is the raw
## text of the light's range cull mask and `shadow_masks` the same for its shadow mask, both `""`
## when the scene file never wrote one, which means the engine's default; `properties` is every
## property line the scene file holds for the node.
##
## The list the picker's "Lights in this scene" shelf and the head's `lit by` bands are built from,
## and the one a pack asks before offering a light row of its own. READ-ONLY and derived on every
## ask, exactly like `synced_properties`: nothing about the scene is stored in the sheet, so a `.gd`
## still round-trips byte for byte, and a sheet no scene uses simply has no lights. The LIST itself
## is the caller's own (the reader behind it answers from a session cache, and a pack that sorts or
## filters the answer in place would otherwise be rearranging the editor's own view of the scene).
static func scene_lights(sheet: EventSheetResource) -> Array[Dictionary]:
	return _typed_dictionaries(EventSheetSceneLights.for_script(
		str(sheet.external_source_path) if sheet != null else ""))


## An untyped Array of Dictionaries as the typed Array the API promises. The readers behind the two
## scene calls answer in plain Arrays (they are parsers, not editor code), and a caller of a public
## method should not have to cast what it was handed.
static func _typed_dictionaries(entries: Array) -> Array[Dictionary]:
	var typed: Array[Dictionary] = []
	for entry: Variant in entries:
		if entry is Dictionary:
			typed.append(entry as Dictionary)
	return typed


# ── Internal wiring (called by the plugin itself) ─────────────────────────────────────


## The dock announces itself here during setup; extensions never call this.
static func _register_dock(dock: Control) -> void:
	_dock = dock


static func _dock_alive() -> bool:
	return _dock != null and is_instance_valid(_dock)
