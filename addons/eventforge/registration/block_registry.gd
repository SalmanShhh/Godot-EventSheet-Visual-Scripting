# EventForge - the Custom Block API registry: kind_id -> EventSheetBlockKind descriptor.
#
# Built-in kinds register here in code (P1: Preload Resource + Region marker, the proof kinds).
# P2 adds zero-config discovery of pack-defined kinds from res://eventsheet_addons/ (the same
# scan that finds ACE providers). Duplicate kind_ids warn and keep the first registration so
# resolution stays deterministic.
@tool
class_name EventSheetBlockRegistry
extends RefCounted

static var _kinds: Dictionary = {}
static var _built_ins_registered: bool = false

static func register_kind(kind: EventSheetBlockKind) -> void:
	if kind == null or kind.kind_id.strip_edges().is_empty():
		return
	if _kinds.has(kind.kind_id):
		push_warning("EventSheets: duplicate block kind_id '%s' ignored." % kind.kind_id)
		return
	_kinds[kind.kind_id] = kind

static func get_kind(kind_id: String) -> EventSheetBlockKind:
	_ensure_built_ins()
	return _kinds.get(kind_id, null)

## All registered kinds, sorted by kind_id for deterministic menus and lift-probe order.
static func all_kinds() -> Array[EventSheetBlockKind]:
	_ensure_built_ins()
	var kinds: Array[EventSheetBlockKind] = []
	var ids: Array = _kinds.keys()
	ids.sort()
	for id: Variant in ids:
		kinds.append(_kinds[id])
	return kinds

static func _ensure_built_ins() -> void:
	if _built_ins_registered:
		return
	_built_ins_registered = true
	register_kind(PreloadBlockKind.new())
	register_kind(RegionBlockKind.new())
	rescan_pack_kinds()

## Zero-config pack kinds, mirroring how ACE providers register: any script under
## res://eventsheet_addons/ whose base-class chain reaches EventSheetBlockKind is instantiated
## and registered. Detection walks the base-script chain (cheap) so ordinary provider/behaviour
## scripts are never instantiated by the scan. Re-run when the addon scan refreshes (the dock
## calls this from its ACE-source rebuild); already-registered ids are kept, so a rescan is
## additive and deterministic.
static func rescan_pack_kinds() -> void:
	_built_ins_registered = true
	for script_path: String in EventSheetAddonScanner.list_addon_scripts():
		var script: GDScript = load(script_path) as GDScript
		if script == null or not _extends_block_kind(script):
			continue
		var kind: EventSheetBlockKind = script.new() as EventSheetBlockKind
		if kind == null or kind.kind_id.strip_edges().is_empty():
			continue
		if _kinds.has(kind.kind_id):
			continue  # additive rescan: first registration (or a built-in) wins
		if not kind.kind_id.contains("."):
			push_warning("EventSheets: pack block kind '%s' (%s) should namespace its kind_id as '<pack>.<name>'." % [kind.kind_id, script_path])
		register_kind(kind)

static func _extends_block_kind(script: GDScript) -> bool:
	var base: Script = script.get_base_script()
	while base != null:
		if base.resource_path.ends_with("registration/block_kind.gd"):
			return true
		base = base.get_base_script()
	return false


# ── Built-in kind: Preload Resource (`const Sfx := preload("res://sfx/jump.ogg")`) ──
class PreloadBlockKind extends EventSheetBlockKind:
	func _init() -> void:
		kind_id = "preload"
		title = "Preload Resource"

	func fields() -> Array[Dictionary]:
		return [
			{"id": "name", "label": "Constant name", "type": TYPE_STRING, "default": "Res"},
			{"id": "path", "label": "Resource path", "type": TYPE_STRING, "default": "res://"},
		]

	func emit(block: CustomBlockRow) -> PackedStringArray:
		var const_name: String = str(block.fields.get("name", "Res")).strip_edges()
		var path: String = str(block.fields.get("path", "res://")).strip_edges()
		if const_name.is_empty() or path.is_empty():
			return PackedStringArray()
		return PackedStringArray(["const %s := preload(\"%s\")" % [const_name, path]])

	func lift(lines: PackedStringArray, i: int) -> Dictionary:
		var probe: RegEx = RegEx.new()
		if probe.compile("^const ([A-Za-z_][A-Za-z0-9_]*) := preload\\(\"([^\"]+)\"\\)$") != OK:
			return {}
		var found: RegExMatch = probe.search(lines[i])
		if found == null:
			return {}
		return verified_claim({"name": found.get_string(1), "path": found.get_string(2)}, lines, i, 1)

	func summary(block: CustomBlockRow) -> String:
		return "%s = %s" % [str(block.fields.get("name", "")), str(block.fields.get("path", ""))]


# ── Built-in kind: Region marker (`#region Combat` / `#endregion`) ──
# Fences are two independent single-line blocks (is_end true = the closing fence), so no
# nesting grammar is needed; unbalanced fences are a readability wart, never a parse error.
class RegionBlockKind extends EventSheetBlockKind:
	func _init() -> void:
		kind_id = "region"
		title = "Region"

	func fields() -> Array[Dictionary]:
		return [
			{"id": "label", "label": "Region name", "type": TYPE_STRING, "default": ""},
			{"id": "is_end", "label": "Closing fence (#endregion)", "type": TYPE_BOOL, "default": false},
		]

	func emit(block: CustomBlockRow) -> PackedStringArray:
		if bool(block.fields.get("is_end", false)):
			return PackedStringArray(["#endregion"])
		var label: String = str(block.fields.get("label", "")).strip_edges()
		return PackedStringArray(["#region %s" % label if not label.is_empty() else "#region"])

	func lift(lines: PackedStringArray, i: int) -> Dictionary:
		var line: String = lines[i]
		if line == "#endregion":
			return verified_claim({"label": "", "is_end": true}, lines, i, 1)
		if line == "#region":
			return verified_claim({"label": "", "is_end": false}, lines, i, 1)
		if line.begins_with("#region "):
			return verified_claim({"label": line.substr(8), "is_end": false}, lines, i, 1)
		return {}

	func summary(block: CustomBlockRow) -> String:
		if bool(block.fields.get("is_end", false)):
			return "end"
		var label: String = str(block.fields.get("label", "")).strip_edges()
		return label if not label.is_empty() else "(unnamed)"
