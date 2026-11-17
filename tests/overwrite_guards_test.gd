# Godot EventSheets - the places that overwrite files ask first, keep the old file, or leave the
# reader's own files alone.
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const TEST_NAME := "overwrite_guards_test"
const ASK := "res://addons/eventsheet/editor/dock/ask_first.gd"
const GUARD := "res://addons/eventsheet/editor/dock/restore_guard.gd"


static func run() -> bool:
	# Export Addon: the files an export would replace are named, and a first export names none.
	var pack_dir: String = SUPPORT.own_folder("pack_guard")
	var first: PackedStringArray = load("res://addons/eventsheet/editor/dock/export_pack.gd").files_replaced(pack_dir, "widget")
	_write(pack_dir + "/widget.gd", "extends Node\n")
	_write(pack_dir + "/README.md", "# my own notes\n")
	var again: PackedStringArray = load("res://addons/eventsheet/editor/dock/export_pack.gd").files_replaced(pack_dir, "widget")
	var passed: bool = SUPPORT.pins(TEST_NAME, [
		["a first export replaces nothing", first.size(), 0],
		["an export over an existing pack names the script", again.has(pack_dir + "/widget.gd"), true],
		["and the README", again.has(pack_dir + "/README.md"), true],
		["and not the sheet that is not there", again.has(pack_dir + "/widget.tres"), false],
	])

	# Chunk tools: a merge replaces its target scene, a split replaces chunks of the same prefix.
	var chunk_dir: String = SUPPORT.own_folder("chunk_guard")
	_write(chunk_dir + "/chunk_0_0.tscn", "x")
	_write(chunk_dir + "/other.tscn", "x")
	var merge_target: String = SUPPORT.own_path("world.tscn")
	_write(merge_target, "x")
	var chunks: GDScript = load("res://addons/eventsheet/editor/chunk_tools_dialog.gd")
	passed = SUPPORT.pins(TEST_NAME, [
		["a split names the chunk scenes it would replace", chunks.files_replaced(true, chunk_dir, "chunk", "").size(), 1],
		["a split of another prefix replaces none", chunks.files_replaced(true, chunk_dir, "tile", "").size(), 0],
		["a merge names its target scene", chunks.files_replaced(false, chunk_dir, "chunk", merge_target), PackedStringArray([merge_target])],
		["a merge into a new scene replaces none", chunks.files_replaced(false, chunk_dir, "chunk", SUPPORT.own_path("none.tscn")).size(), 0],
	]) and passed

	# The question: yes runs what was asked, no does not.
	var host: Node = Node.new()
	var ran: Array[int] = [0]
	var asking: ConfirmationDialog = load(ASK).ask(host, "Replace?", "It is replaced. The old one is kept.", "Replace",
		func() -> void: ran[0] += 1)
	var said: String = ""
	for child: Node in asking.find_children("*", "Label", true, false):
		said += (child as Label).text
	asking.canceled.emit()
	var after_no: int = ran[0]
	var again_asking: ConfirmationDialog = load(ASK).ask(host, "Replace?", "It is replaced.", "Replace", func() -> void: ran[0] += 1)
	again_asking.confirmed.emit()
	passed = SUPPORT.pins(TEST_NAME, [
		["the question says what is replaced", said.contains("It is replaced."), true],
		["answering no runs nothing", after_no, 0],
		["answering yes runs it", ran[0], 1],
	]) and passed
	host.free()

	# Restore from Sheet Backups: the unsaved state goes into the ring first.
	var sheet_path: String = SUPPORT.own_path("restore_guard.gd")
	_write(sheet_path, "extends Node\n")
	var sheet: EventSheetResource = SUPPORT.reopen("extends Node\n\nvar unsaved_edit: int = 3\n", true, sheet_path)
	sheet.external_source_path = sheet_path
	var kept: String = load(GUARD).keep_unsaved_state(sheet, sheet_path)
	passed = SUPPORT.pins(TEST_NAME, [
		["the unsaved state was kept in the ring", kept.is_empty(), false],
		["and says what was unsaved", FileAccess.get_file_as_string(kept).contains("unsaved_edit"), true],
	]) and passed

	# The docs site export keeps a reader's own files at the folder's top level.
	var site: String = SUPPORT.own_folder("site_guard")
	_write(site + "/mine.html", "mine")
	_write(site + "/mine.css", "mine")
	_write(site + "/mine.js", "mine")
	_write(site + "/index.html", "old index")
	var ids: PackedStringArray = PackedStringArray()
	for id: String in EventSheetDocLibrary.page_ids():
		ids.append(id)
		if ids.size() >= 2:
			break
	if ids.is_empty():
		print("[doc_site] no help bundle installed - the site folder guard is not exercised")
		return passed
	EventSheetDocSiteExport.export_site(site, {"page_ids": Array(ids), "sheets": {},
		"figures_dir": SUPPORT.own_folder("site_figures")})
	passed = SUPPORT.pins(TEST_NAME, [
		["the reader's own page is kept", FileAccess.file_exists(site + "/mine.html"), true],
		["the reader's own stylesheet is kept", FileAccess.file_exists(site + "/mine.css"), true],
		["the reader's own script is kept", FileAccess.file_exists(site + "/mine.js"), true],
		["the export's own index is rewritten", FileAccess.get_file_as_string(site + "/index.html") != "old index", true],
	]) and passed
	return passed


static func _write(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var handle: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	handle.store_string(text)
	handle.close()
