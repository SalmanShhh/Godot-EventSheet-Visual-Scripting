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
			schema.append(field)
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
	return EventSheetClassDBSource.definitions_for_class(target_class)


# ── Editor ─────────────────────────────────────────────────────────────────────────────


## The sheet open in the active editor tab, or null (no dock / no sheet).
static func current_sheet() -> EventSheetResource:
	if not _dock_alive():
		return null
	return _dock.get_current_sheet()


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


## Writes to the editor's status line (is_error tints it as a problem).
static func set_status(text: String, is_error: bool = false) -> void:
	if _dock_alive():
		_dock._set_status(text, is_error)


## Rebuilds the editor's rows from the current sheet (after out-of-funnel changes;
## prefer edit(), which refreshes for you).
static func refresh() -> void:
	if _dock_alive():
		_dock._refresh_after_edit()


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


# ── Codegen ────────────────────────────────────────────────────────────────────────────


## Builds a ready-to-fill EventSheetResource from a plain Dictionary, so you can author a sheet,
## behavior, autoload, or tool script from code (there is no other public "create sheet" entry).
## All keys optional:
##   {"class_name": "Enemy", "host_class": "CharacterBody2D", "behavior_mode": false,
##    "autoload_mode": false, "autoload_name": "", "tool_mode": false,
##    "category": "My Pack", "tags": ["ai"], "description": "..."}
## For a tool script pass {"tool_mode": true, "host_class": "EditorScript"}. Append events and
## functions to the returned sheet, then compile() it or open_sheet() its saved path.
static func new_sheet(config: Dictionary = {}) -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = str(config.get("host_class", "Node"))
	sheet.custom_class_name = str(config.get("class_name", ""))
	sheet.behavior_mode = bool(config.get("behavior_mode", false))
	sheet.autoload_mode = bool(config.get("autoload_mode", false))
	sheet.autoload_name = str(config.get("autoload_name", ""))
	sheet.tool_mode = bool(config.get("tool_mode", false))
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


## The exact GDScript a variable compiles to - its "Ships as:" truth, decor comments, tooltip,
## grouping, and the @export annotation included. Deterministic: same variable, same bytes.
static func variable_code(variable: LocalVariable) -> String:
	return SheetCompiler._emit_tree_variable_line(variable)


## Opens GDScript source as an editable sheet (the lossless external path: everything
## liftable lifts, everything else stays verbatim - never corrupted).
static func open_gd_as_sheet(source: String) -> EventSheetResource:
	return GDScriptImporter.new().import_external_source(source)


## The byte gate as a service: true when importing `source` and recompiling reproduces
## it byte-identically - the same covenant every built-in lift must satisfy. Use it to
## verify a custom block kind or an emission tweak can never corrupt user files.
static func round_trips(source: String) -> bool:
	var sheet: EventSheetResource = open_gd_as_sheet(source)
	if sheet == null:
		return false
	sheet.external_source_path = "user://__eventsheets_api_roundtrip.gd"
	return str(compile(sheet, sheet.external_source_path).get("output", "")) == source


# ── Localisation (the editor UI's language - game l10n is the Translation module) ──────


## Translates an editor-UI string into the active plugin language. English is the default
## and the fallback: with no translation loaded (or English active) the text passes through
## unchanged. Route every user-facing string a FUTURE feature or extension shows through
## this (or through a Control, which auto-translates via the plugin's translation domain),
## and it localises the day someone drops in a CSV. Frozen ids (ace_id, kind_id, provider
## ids) are contracts, never translated - display strings only.
static func translate(text: String) -> String:
	return EventSheetL10n.translate(text)


## Registers an extension's own translation file (the drop-in CSV shape - see
## docs/GUIDE-TRANSLATING-THE-EDITOR.md - or a ready-made Translation resource), merging its
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


# ── Extension seams (custom features plug in here) ─────────────────────────────────────

## Row context-menu items: [{label, filter: Callable(resource)->bool, action: Callable(resource)}].
static var _row_menu_items: Array[Dictionary] = []
## Lifecycle listeners: event name -> Array[Callable].
static var _lifecycle: Dictionary = {"opened": [], "saved": [], "compiled": []}
## Extension starters: [{label, build: Callable()->EventSheetResource}] - ids 1000+ in the dialog.
static var _starters: Array[Dictionary] = []
## Param editors: hint or type_name -> Callable(param_dict, initial_text) -> LineEdit.
static var _param_editors: Dictionary = {}
## Welcome Preferences rows: Array[Callable() -> Control].
static var _preference_builders: Array[Callable] = []
## Dictionary-defined ACEs live in the registry's extras (see register_simple_ace).
static var _simple_aces: Array[ACEDefinition] = []
## Editor-preview samplers: behavior script path -> Callable(params, base, time) -> Dictionary.
static var _editor_preview_samplers: Dictionary = {}


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


## Registers a custom parameter editor. `tag` matches a param's hint (or its type_name when it
## has no hint); `factory(param_dict, initial_text)` must return a LineEdit (subclass and style
## it freely - add buttons, popups, validation - the dialog reads the final value from .text).
static func register_param_editor(tag: String, factory: Callable) -> void:
	_param_editors[tag] = factory


static func param_editor_for(tag: String) -> Callable:
	return _param_editors.get(tag, Callable())


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
			definition.parameters.append((param_config as Dictionary).duplicate(true))
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


# ── Internal wiring (called by the plugin itself) ─────────────────────────────────────


## The dock announces itself here during setup; extensions never call this.
static func _register_dock(dock: Control) -> void:
	_dock = dock


static func _dock_alive() -> bool:
	return _dock != null and is_instance_valid(_dock)
