# Godot EventSheets - commands live on Godot's own Command Palette. Every entry registered through
# the public seam (EventSheets.register_palette_command, which the plugin's own commands use too)
# is forwarded to the editor's palette when it is registered and taken back when it is unregistered
# or when the workspace that made it is freed. The suite stands a fake palette in for the editor's.
@tool
class_name GodotPaletteForwardingTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const DOCK_REGISTRY := preload("res://addons/eventsheet/api/dock_registry.gd")
const NAME := "godot_palette_forwarding_test"


static func run() -> bool:
	var log: Array = []
	DOCK_REGISTRY.forwarder = func(adding: bool, title: String, key: String, _action: Callable) -> void:
		log.append("%s|%s|%s" % ["add" if adding else "remove", title, key])
	EventSheets.register_palette_command("Zz Forward Probe", func() -> void: pass)
	EventSheets.register_palette_command("Reroll", func() -> void: pass, "Zz Pack")
	EventSheets.register_palette_command("Zz Forward Probe", func() -> void: pass)
	EventSheets.unregister_palette_command("Zz Forward Probe")
	EventSheets.unregister_palette_command("Zz Pack: Reroll")
	DOCK_REGISTRY.forwarder = Callable()
	var ok: bool = SUPPORT.pins(NAME, [
		["a command without a category is put under the plugin's name", log[0], "add|EventSheets: Zz Forward Probe|eventsheets/zz_forward_probe"],
		["a category is the heading in front of the title", log[1], "add|Zz Pack: Reroll|eventsheets/zz_pack_reroll"],
		["registering a title again replaces it: the old entry goes first", [log[2], log[3]],
			["remove|EventSheets: Zz Forward Probe|eventsheets/zz_forward_probe", "add|EventSheets: Zz Forward Probe|eventsheets/zz_forward_probe"]],
		["unregistering takes the entry back", log[4], "remove|EventSheets: Zz Forward Probe|eventsheets/zz_forward_probe"],
		["and so does it for a category entry", log[5], "remove|Zz Pack: Reroll|eventsheets/zz_pack_reroll"],
		["nothing else was forwarded", log.size(), 6],
		["the key is the title's words joined by underscores", DOCK_REGISTRY.godot_palette_key("Collapse Everything (regions + groups)"),
			"eventsheets/collapse_everything_regions_groups"],
	])

	# The workspace's own commands, the four that no menu has among them, are on the same seam, and they go
	# with the workspace.
	var added: Array = []
	var removed: Array = []
	DOCK_REGISTRY.forwarder = func(adding: bool, _title: String, key: String, _action: Callable) -> void:
		(added if adding else removed).append(key)
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.setup(EventSheetResource.new())
	var registered: PackedStringArray = PackedStringArray()
	for command: Dictionary in EventSheets.palette_commands():
		registered.append(str(command.get("title", "")))
	var kept_keys: Array = added.duplicate()
	dock.free()
	DOCK_REGISTRY.forwarder = Callable()
	ok = SUPPORT.pins(NAME, [
		["Split Scene Into Chunks is on the palette", registered.has("Streaming: Split Scene Into Chunks"), true],
		["Merge Chunks is on the palette", registered.has("Streaming: Merge Chunks"), true],
		["Export Mod Template is on the palette", registered.has("Mods: Export Mod Template"), true],
		["Toggle Rescue Tips is on the palette", registered.has("Toggle Rescue Tips"), true],
		["so is a command the Ctrl+P window used to list", registered.has("Save Sheet") and registered.has("Zoom In"), true],
		["every one the workspace added went to Godot's palette", kept_keys.has("eventsheets/save_sheet"), true],
		["and every one is taken back when the workspace is freed", removed.has("eventsheets/save_sheet") and removed.size() >= kept_keys.size(), true],
	]) and ok
	return ok
