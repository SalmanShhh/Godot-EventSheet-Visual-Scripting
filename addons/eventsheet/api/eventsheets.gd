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
static func register_palette_command(title: String, action: Callable) -> void:
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


# ── Internal wiring (called by the plugin itself) ─────────────────────────────────────


## The dock announces itself here during setup; extensions never call this.
static func _register_dock(dock: Control) -> void:
	_dock = dock


static func _dock_alive() -> bool:
	return _dock != null and is_instance_valid(_dock)
