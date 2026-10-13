# Godot EventSheets - Import tool seam
#
# THE SEAM behind the On File Imported trigger. When Godot finishes (re)importing assets, this hook
# finds the project's Editor Tool scripts that declared the trigger and calls their handler with the
# paths that just landed - so a sheet can rename what a designer dropped in, check an atlas for the
# wrong filter, or write a manifest of everything under res://art.
#
# It is deliberately the SAME shape as the project-export bake step, because the two answer the same
# question in the same way and a reader who has learned one has learned both: the trigger compiles to
# a plain, named function - `func _on_files_imported(paths: PackedStringArray)` - and this hook calls
# that by name. Both sides stay plain GDScript, so the generated script has zero plugin dependency and
# with the plugin uninstalled the function simply sits there unused. Crucially, a plain function also
# READS BACK: an opened tool lifts its handler straight to an On File Imported event, where a signal
# connection spelled through EditorInterface would have stranded the whole handler as a code block.
#
# Discovery reads the COMPILED SCRIPTS, not the sheet resources, for the reason the export hook does:
# `.gd` is the default sheet format, so an index built from `.tres` files would silently skip most
# real projects. The emitted script either declares the handler or it does not.
#
# The safety rules are the export hook's rules, for the same reasons: reflect before constructing (a
# text match reaches files that only mention the name in a comment), never instantiate a Node-hosted
# script (an orphan node would leak into the editor with nothing to free it), run in sorted path order
# so two tools that touch the same file behave the same on every machine, and print every run.
#
# Unlike an export, an import is NOT a moment the editor holds open for us, so a handler that awaits
# is merely late rather than truncated - it is still reported, because a tool that pauses has stopped
# being a reaction to the import that triggered it.
@tool
extends RefCounted

## The function name On File Imported compiles to. Part of the public seam: rename it and every
## already-generated tool script goes quiet, so it is frozen like an ace_id.
const HOOK_FUNCTION: String = "_on_files_imported"

## The export bake step, whose discovery and run this hook shares: it skips the same folders (the
## import cache and plugin code) and holds every script to the same safety rules.
const EXPORT_TOOLS := preload("res://addons/eventforge/editor/export_tools_plugin.gd")

var _filesystem: EditorFileSystem = null


## Connects to the editor's reimport signal. Safe to call twice - the second call is a no-op.
func attach(filesystem: EditorFileSystem) -> void:
	if filesystem == null or _filesystem != null:
		return
	_filesystem = filesystem
	if not _filesystem.resources_reimported.is_connected(_on_resources_reimported):
		_filesystem.resources_reimported.connect(_on_resources_reimported)


func detach() -> void:
	if _filesystem == null:
		return
	if _filesystem.resources_reimported.is_connected(_on_resources_reimported):
		_filesystem.resources_reimported.disconnect(_on_resources_reimported)
	_filesystem = null


func _on_resources_reimported(resources: PackedStringArray) -> void:
	var report: Dictionary = run_import_tools(resources)
	# Silence when nothing opted in: an import happens constantly, and a line per import from a
	# project with no import tools would be noise nobody asked for.
	if int(report.get("ran", 0)) == 0 and int(report.get("skipped", 0)) == 0:
		return
	print("[Godot EventSheets] import hook: %d editor tool(s) ran, %d skipped." % [
		int(report.get("ran", 0)), int(report.get("skipped", 0))])


## Runs every Editor Tool script that declared the On File Imported trigger, handing each the paths
## that were just imported. Returns {ran, skipped, unfinished, scripts} - `scripts` lists what
## actually ran, in the order it ran. Static + headless-safe so tests exercise the exact pass the
## editor takes. The pass itself is the export bake step's, by the same rules.
static func run_import_tools(paths: PackedStringArray, root: String = "res://") -> Dictionary:
	return EXPORT_TOOLS.run_hook_scripts(HOOK_FUNCTION, [paths], root, "import hook",
		"On File Imported belongs on an Import Tool sheet (Sheet Type > Import tool).",
		"so the rest of it runs after the editor has moved on from this import. Keep an import reaction synchronous.")


## Every `.gd` under `root` whose text declares the import handler, sorted so the run order is the
## same everywhere. Declaring the handler IS the opt-in, so the text test is exactly that one line.
static func find_import_tools(root: String = "res://") -> PackedStringArray:
	return EXPORT_TOOLS.find_hook_scripts(HOOK_FUNCTION, root)
