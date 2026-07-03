# Godot EventSheets — "Open as Event Sheet" availability (FileSystem + script-editor right-click).
#
# Pins the context-menu DECISION (EventSheetContextMenu.should_offer_open_as_sheet) so the entry point
# can't silently regress: right-clicking ANY .gd (or an EventSheet .tres) in the FileSystem offers it,
# non-sheet files don't, and the script editor always offers it. Static-only — never instantiates the
# editor-glue plugin (which the editor owns).
@tool
class_name OpenAsSheetMenuTest
extends RefCounted


static func run() -> bool:
	var all_passed: bool = true
	var fs_slot: int = EditorContextMenuPlugin.CONTEXT_SLOT_FILESYSTEM
	var script_slot: int = EditorContextMenuPlugin.CONTEXT_SLOT_SCRIPT_EDITOR

	all_passed = _check("FileSystem offers Open-as-Sheet for any .gd",
		EventSheetContextMenu.should_offer_open_as_sheet(fs_slot, PackedStringArray(["res://addons/eventforge/plugin.gd"])), true) and all_passed
	all_passed = _check("FileSystem offers it for an EventSheet .tres",
		EventSheetContextMenu.should_offer_open_as_sheet(fs_slot, PackedStringArray(["res://demo/sheets/player.tres"])), true) and all_passed
	all_passed = _check("FileSystem does NOT offer it for a non-sheet file",
		EventSheetContextMenu.should_offer_open_as_sheet(fs_slot, PackedStringArray(["res://icon.png"])), false) and all_passed
	all_passed = _check("FileSystem offers it when ANY selected path qualifies",
		EventSheetContextMenu.should_offer_open_as_sheet(fs_slot, PackedStringArray(["res://icon.png", "res://addons/eventforge/plugin.gd"])), true) and all_passed
	all_passed = _check("Script editor always offers Open-as-Sheet (the open buffer is a .gd)",
		EventSheetContextMenu.should_offer_open_as_sheet(script_slot, PackedStringArray()), true) and all_passed

	return all_passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] open_as_sheet_menu_test: %s" % label)
		return true
	print("[FAIL] open_as_sheet_menu_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
