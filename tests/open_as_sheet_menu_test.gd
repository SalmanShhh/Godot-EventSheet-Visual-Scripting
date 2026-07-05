# Godot EventSheets - "Open as Event Sheet" availability (FileSystem + script-editor right-click).
#
# Pins the context-menu DECISION (EventSheetContextMenu.should_offer_open_as_sheet) so the entry point
# can't silently regress: right-clicking ANY .gd (or an EventSheet .tres) in the FileSystem offers it,
# non-sheet files don't, and the script editor always offers it. Static-only - never instantiates the
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

	# ── "Create New > Event Sheet" availability + directory resolution ─────────────
	var create_slot: int = EditorContextMenuPlugin.CONTEXT_SLOT_FILESYSTEM_CREATE
	all_passed = _check("the FileSystem Create-New slot offers New Event Sheet (no selection needed)",
		EventSheetContextMenu.should_offer_create_sheet(create_slot), true) and all_passed
	all_passed = _check("other slots never offer Create New",
		EventSheetContextMenu.should_offer_create_sheet(fs_slot)
		or EventSheetContextMenu.should_offer_create_sheet(script_slot), false) and all_passed
	all_passed = _check("a right-clicked folder resolves to itself",
		EventSheetContextMenu.directory_from_targets(PackedStringArray(["res://scenes"])), "res://scenes") and all_passed
	all_passed = _check("a right-clicked file resolves to its folder",
		EventSheetContextMenu.directory_from_targets(PackedStringArray(["res://scenes/player.gd"])), "res://scenes") and all_passed
	all_passed = _check("an empty target falls back to res://",
		EventSheetContextMenu.directory_from_targets(PackedStringArray()), "res://") and all_passed

	return all_passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] open_as_sheet_menu_test: %s" % label)
		return true
	print("[FAIL] open_as_sheet_menu_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
