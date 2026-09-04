# EventForge - the Custom Block API registry: kind_id -> EventSheetBlockKind descriptor.
#
# Built-in kinds register here in code (Preload Resource + Region marker, the proof kinds).
# Adds zero-config discovery of pack-defined kinds from res://eventsheet_addons/ (the same
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


## The kind responsible for a row instance: CustomBlockRow resolves by its kind_id; the
## plugin's own row classes (EnumRow, ...) resolve through each resource kind's handles().
## Null when nothing claims it.
static func kind_for(entry: Resource) -> EventSheetBlockKind:
	_ensure_built_ins()
	if entry is CustomBlockRow:
		return get_kind((entry as CustomBlockRow).kind_id)
	for kind: EventSheetBlockKind in all_kinds():
		if kind.handles(entry):
			return kind
	return null


## All registered kinds, sorted by kind_id for deterministic menus and lift-probe order.
static func all_kinds() -> Array[EventSheetBlockKind]:
	_ensure_built_ins()
	var kinds: Array[EventSheetBlockKind] = []
	var ids: Array = _kinds.keys()
	ids.sort()
	for id: Variant in ids:
		kinds.append(_kinds[id])
	return kinds


## The kinds the generic add surfaces (Add menu, palette, schema dialog) may offer - resource
## kinds (the plugin's own row classes) are excluded; their classes have dedicated flows.
static func addable_kinds() -> Array[EventSheetBlockKind]:
	var kinds: Array[EventSheetBlockKind] = []
	for kind: EventSheetBlockKind in all_kinds():
		if kind.addable():
			kinds.append(kind)
	return kinds


## Splits a comma-joined declaration list at the TOP level only - a ", " inside (), [], {} or a
## string literal stays put, so a typed collection like `scores: Dictionary[String, int]` survives
## as ONE parameter. The naive String.split(", ") fragmented it into two garbage params that STILL
## rejoined byte-identically, so the round-trip gate never saw the corruption - only the editor's
## param fields did. Empty/whitespace input returns an empty array (a no-param list, not [""]).
static func split_params_top_level(params_text: String) -> PackedStringArray:
	if params_text.strip_edges().is_empty():
		return PackedStringArray()
	var parts: PackedStringArray = PackedStringArray()
	var depth: int = 0
	var in_string: bool = false
	var quote: String = ""
	var start: int = 0
	var i: int = 0
	var n: int = params_text.length()
	while i < n:
		var c: String = params_text[i]
		if in_string:
			if c == "\\":
				i += 2  # skip the escaped char, whatever it is
				continue
			if c == quote:
				in_string = false
			i += 1
			continue
		if c == "\"" or c == "'":
			in_string = true
			quote = c
		elif c == "(" or c == "[" or c == "{":
			depth += 1
		elif c == ")" or c == "]" or c == "}":
			depth -= 1
		elif depth == 0 and c == "," and params_text.substr(i, 2) == ", ":
			parts.append(params_text.substr(start, i - start))
			i += 2
			start = i
			continue
		i += 1
	parts.append(params_text.substr(start))
	return parts


static func _ensure_built_ins() -> void:
	if _built_ins_registered:
		return
	_built_ins_registered = true
	register_kind(PreloadBlockKind.new())
	register_kind(RegionBlockKind.new())
	register_kind(EnumBlockKind.new())
	register_kind(SignalBlockKind.new())
	register_kind(MomentBlockKind.new())
	_scan_pack_kinds()


## Zero-config pack kinds, mirroring how ACE providers register: any script under
## res://eventsheet_addons/ whose base-class chain reaches EventSheetBlockKind is instantiated
## and registered. Detection walks the base-script chain (cheap) so ordinary provider/behaviour
## scripts are never instantiated by the scan. Re-run when the addon scan refreshes (the dock
## calls this from its ACE-source rebuild); already-registered ids are kept, so a rescan is
## additive and deterministic.
static func rescan_pack_kinds() -> void:
	# Built-ins FIRST, always: setting the registered flag here (as this used to) made a
	# rescan-first call skip built-in registration for the whole session - the enum, signal,
	# preload, and region kinds silently vanished. _ensure_built_ins is a no-op when done.
	_ensure_built_ins()
	_scan_pack_kinds()


static func _scan_pack_kinds() -> void:
	for script_path: String in EventSheetAddonScanner.list_addon_scripts():
		if not _could_extend_block_kind(script_path):
			continue
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


## Cheap text pre-filter for the scan above: can this file POSSIBLY be a block kind, without
## loading (and therefore compiling) it?
##
## A block kind's base-script chain must reach block_kind.gd, so its top-level `extends` names
## another script - a global class_name, a res:// path, or nothing at all (which means the engine
## class RefCounted). A script whose `extends` names an ENGINE class has an empty base-SCRIPT chain,
## so `_extends_block_kind` can only ever answer false for it, and loading it was pure cost. Nearly
## every pack script extends Node / Resource / Node2D, so this turns ~90 GDScript compiles into ~90
## small file reads: measured on this tree, the first block-kind scan went from 807 ms to 46 ms.
## The answer is identical to the post-load check - this only skips files that provably cannot match.
static func _could_extend_block_kind(script_path: String) -> bool:
	var source: String = FileAccess.get_file_as_string(script_path)
	if source.is_empty():
		return false
	for raw_line: String in source.split("\n"):
		var line: String = raw_line.strip_edges()
		if not line.begins_with("extends "):
			continue
		if raw_line.begins_with("\t") or raw_line.begins_with(" "):
			continue  # an inner class's extends, not the file's own
		var base_name: String = line.substr("extends ".length()).strip_edges()
		# A quoted path or a preload() base is a script base - always worth loading.
		if not base_name.is_valid_identifier():
			return true
		return not ClassDB.class_exists(base_name)
	return false  # no top-level extends: the implicit base is RefCounted, an engine class


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
			{"id": "path", "label": "Resource path", "type": TYPE_STRING, "default": "res://", "hint": "resource_path"},
			# STATIC vs DYNAMIC: "preload" emits `const X := preload(...)` (resolved at parse
			# time, the classic form); "load" emits `var X := load(...)` (loaded when the node
			# is instantiated - a runtime reference the game can also reassign). Both shapes
			# lift back to this SAME row kind, byte-gated.
			{"id": "mode", "label": "When to load", "type": TYPE_STRING, "default": "preload", "options": ["preload", "load"]},
		]

	func emit(block: CustomBlockRow) -> PackedStringArray:
		var const_name: String = str(block.fields.get("name", "Res")).strip_edges()
		var path: String = str(block.fields.get("path", "res://")).strip_edges()
		if const_name.is_empty() or path.is_empty():
			return PackedStringArray()
		if str(block.fields.get("mode", "preload")) == "load":
			return PackedStringArray(["var %s := load(\"%s\")" % [const_name, path]])
		return PackedStringArray(["const %s := preload(\"%s\")" % [const_name, path]])

	func lift(lines: PackedStringArray, i: int) -> Dictionary:
		var probe: RegEx = RegEx.new()
		if probe.compile("^const ([A-Za-z_][A-Za-z0-9_]*) := preload\\(\"([^\"]+)\"\\)$") != OK:
			return {}
		var found: RegExMatch = probe.search(lines[i])
		if found != null:
			return verified_claim({"name": found.get_string(1), "path": found.get_string(2), "mode": "preload"}, lines, i, 1)
		# The dynamic form. Claiming it here does not shadow variable rows: the variable
		# lifter's byte gate rejects the `:=`-inferred load line (it re-emits typed), so
		# before this claim such lines were stranded VERBATIM blocks.
		var dynamic_probe: RegEx = RegEx.new()
		if dynamic_probe.compile("^var ([A-Za-z_][A-Za-z0-9_]*) := load\\(\"([^\"]+)\"\\)$") != OK:
			return {}
		var dynamic_found: RegExMatch = dynamic_probe.search(lines[i])
		if dynamic_found == null:
			return {}
		return verified_claim({"name": dynamic_found.get_string(1), "path": dynamic_found.get_string(2), "mode": "load"}, lines, i, 1)

	func summary(block: CustomBlockRow) -> String:
		return "%s = %s" % [str(block.fields.get("name", "")), str(block.fields.get("path", ""))]

	## First-class row in the VARIABLE row's exact shape - `name : Type [pill] = default` -
	## so a preload reads at a glance the same way a variable does: the pill sits where
	## const/@export pills sit (green "preload" for the static form, blue "load" for the
	## runtime form), the resource TYPE is inferred from the file extension, and the path
	## takes the default-value slot after "=".
	func display_spans(entry: Resource) -> Array[Dictionary]:
		var block: CustomBlockRow = entry as CustomBlockRow
		if block == null:
			return []
		var path: String = str(block.fields.get("path", "res://"))
		var is_dynamic: bool = str(block.fields.get("mode", "preload")) == "load"
		return [
			{"text": str(block.fields.get("name", "Res")), "role": "name"},
			{"text": ":", "role": "operator"},
			{"text": _resource_type_for(path), "role": "type"},
			{"text": "load" if is_dynamic else "preload", "role": "badge", "badge_style": "scope" if is_dynamic else "const"},
			{"text": "=", "role": "operator"},
			{"text": path, "role": "value"},
		]

	## The display type a resource path implies (extension-based; "Resource" when unknown).
	## Display only - emission never writes a type, so this can never affect the round-trip.
	func _resource_type_for(path: String) -> String:
		match path.get_extension().to_lower():
			"tscn", "scn":
				return "PackedScene"
			"png", "jpg", "jpeg", "webp", "svg", "bmp", "tga", "ktx", "exr":
				return "Texture2D"
			"ogg", "wav", "mp3":
				return "AudioStream"
			"gd":
				return "Script"
			"gdshader":
				return "Shader"
			"ttf", "otf", "woff", "woff2":
				return "FontFile"
			"material":
				return "Material"
			"mesh", "obj", "glb", "gltf":
				return "Mesh"
			_:
				return "Resource"


# ── Built-in RESOURCE kind: enum rows (`enum Mode { IDLE, RUN }`) ──
# The plugin's own EnumRow runs ON the Custom Block API: the compiler's enum emission, the
# importer's enum lift, and the viewport's enum summary all dispatch through this kind, so the
# registry is load-bearing for a shipped feature - not just an extension point. Instances stay
# EnumRow resources (saved .tres sheets and the enum dialog are untouched), which is why this
# kind is not addable() from the generic surfaces.
class EnumBlockKind extends EventSheetBlockKind:
	func _init() -> void:
		kind_id = "enum"
		title = "enum"

	func handles(entry: Resource) -> bool:
		return entry is EnumRow

	func addable() -> bool:
		return false

	## The enum dialog IS this kind's custom editor - the registry dispatches the edit.
	func edit(dock: Control, block: Resource) -> bool:
		dock._struct_rows.open_enum_dialog(block)
		return true

	func source_map_kind() -> String:
		return "enum"

	## Canonical forms the verify-lift depends on: single-line `enum Name { A, B }`, or with
	## multiline on, `enum Name {` / one tab-indented `MEMBER,` per line / `}` (the trailing
	## comma on the LAST member follows trailing_comma, since both styles exist in the wild).
	func emit_lines(entry: Resource) -> PackedStringArray:
		var enum_row: EnumRow = entry as EnumRow
		if enum_row == null or not enum_row.enabled or enum_row.enum_name.strip_edges().is_empty():
			return PackedStringArray()
		var members: PackedStringArray = _clean_members(enum_row)
		if members.is_empty():
			return PackedStringArray()
		if not enum_row.multiline:
			return PackedStringArray(["enum %s { %s }" % [enum_row.enum_name.strip_edges(), ", ".join(members)]])
		var out: PackedStringArray = PackedStringArray(["enum %s {" % enum_row.enum_name.strip_edges()])
		for member_index: int in members.size():
			var is_last: bool = member_index == members.size() - 1
			out.append("\t%s%s" % [members[member_index], "" if is_last and not enum_row.trailing_comma else ","])
		out.append("}")
		return out

	func lift(lines: PackedStringArray, i: int) -> Dictionary:
		var line: String = lines[i]
		if not line.begins_with("enum "):
			return {}
		# Single-line form first (the compiler's classic shape).
		var enum_regex: RegEx = RegEx.new()
		if enum_regex.compile("^enum ([A-Za-z_][A-Za-z0-9_]*) \\{ (.+) \\}$") != OK:
			return {}
		var enum_match: RegExMatch = enum_regex.search(line)
		if enum_match != null:
			var lifted: EnumRow = EnumRow.new()
			lifted.enum_name = enum_match.get_string(1)
			# Top-level split: a member value with a call (`A = max(1, 2)`) stays ONE member.
			lifted.members = EventSheetBlockRegistry.split_params_top_level(enum_match.get_string(2))
			# The resource-kind byte gate: re-emission must reproduce the line or the claim drops.
			var emitted: PackedStringArray = emit_lines(lifted)
			if emitted.size() != 1 or emitted[0] != line:
				return {}
			return {"resource": lifted, "consumed": 1}
		# Multi-line form: `enum Name {` then one tab-indented member per line until `}`. Members
		# keep their text verbatim ("HURT = 4" included); the last line's comma style is
		# remembered so the block re-emits byte-identically - an enum only stays a raw code
		# block when its shape genuinely isn't this one (or the user chose a block on purpose).
		var header_regex: RegEx = RegEx.new()
		if header_regex.compile("^enum ([A-Za-z_][A-Za-z0-9_]*) \\{$") != OK:
			return {}
		var header_match: RegExMatch = header_regex.search(line)
		if header_match == null:
			return {}
		var multiline_row: EnumRow = EnumRow.new()
		multiline_row.enum_name = header_match.get_string(1)
		multiline_row.multiline = true
		multiline_row.members = PackedStringArray()
		var scan: int = i + 1
		while scan < lines.size() and lines[scan] != "}":
			var member_line: String = lines[scan]
			if not member_line.begins_with("\t") or member_line.strip_edges().is_empty():
				return {}
			var member_text: String = member_line.substr(1)
			if member_text.ends_with(","):
				member_text = member_text.substr(0, member_text.length() - 1)
				multiline_row.trailing_comma = true
			else:
				multiline_row.trailing_comma = false
			if member_text.strip_edges().is_empty() or member_text.contains("\t"):
				return {}
			multiline_row.members.append(member_text)
			scan += 1
		if scan >= lines.size() or multiline_row.members.is_empty():
			return {}
		var consumed: int = scan - i + 1
		var emitted_block: PackedStringArray = emit_lines(multiline_row)
		if emitted_block.size() != consumed:
			return {}
		for check_index: int in consumed:
			if emitted_block[check_index] != lines[i + check_index]:
				return {}
		return {"resource": multiline_row, "consumed": consumed}

	func summary_for(entry: Resource) -> String:
		var enum_row: EnumRow = entry as EnumRow
		if enum_row == null:
			return ""
		return "%s { %s }" % [enum_row.enum_name, ", ".join(_clean_members(enum_row))]

	func _clean_members(enum_row: EnumRow) -> PackedStringArray:
		var members: PackedStringArray = PackedStringArray()
		for member: String in enum_row.members:
			if not member.strip_edges().is_empty():
				members.append(member.strip_edges())
		return members


# ── Built-in RESOURCE kind: signal declarations (`signal hit(amount: int)`) ──
# Second dogfooded built-in: SignalRow's canonical DECLARATION contract (emit + byte-gated lift
# + summary) runs through the registry. The trigger-annotation fold (`## @ace_trigger` blocks
# absorbing onto the row) stays with the importer - it is pending-block surgery across rows,
# not a per-row contract.
class SignalBlockKind extends EventSheetBlockKind:
	func _init() -> void:
		kind_id = "signal"
		title = "signal"

	func handles(entry: Resource) -> bool:
		return entry is SignalRow

	func addable() -> bool:
		return false

	## The signal dialog IS this kind's custom editor - the registry dispatches the edit.
	func edit(dock: Control, block: Resource) -> bool:
		dock._struct_rows.open_signal_dialog(block)
		return true

	func source_map_kind() -> String:
		return "signal"

	## Canonical single-line form; the importer's verify-lift depends on this exact shape.
	func emit_lines(entry: Resource) -> PackedStringArray:
		var signal_row: SignalRow = entry as SignalRow
		if signal_row == null or not signal_row.enabled or signal_row.signal_name.strip_edges().is_empty():
			return PackedStringArray()
		var params: PackedStringArray = _clean_params(signal_row)
		if params.is_empty():
			return PackedStringArray(["signal %s" % signal_row.signal_name.strip_edges()])
		return PackedStringArray(["signal %s(%s)" % [signal_row.signal_name.strip_edges(), ", ".join(params)]])

	func lift(lines: PackedStringArray, i: int) -> Dictionary:
		var line: String = lines[i]
		if not line.begins_with("signal "):
			return {}
		var signal_regex: RegEx = RegEx.new()
		if signal_regex.compile("^signal ([A-Za-z_][A-Za-z0-9_]*)(?:\\((.*)\\))?$") != OK:
			return {}
		var signal_match: RegExMatch = signal_regex.search(line)
		if signal_match == null:
			return {}
		var lifted: SignalRow = SignalRow.new()
		lifted.signal_name = signal_match.get_string(1)
		var params_text: String = signal_match.get_string(2)
		if not params_text.is_empty():
			# Top-level split only: `scores: Dictionary[String, int]` is ONE param. The naive
			# split fragmented it yet rejoined byte-identically, slipping past the gate below.
			lifted.params = EventSheetBlockRegistry.split_params_top_level(params_text)
		var emitted: PackedStringArray = emit_lines(lifted)
		if emitted.size() != 1 or emitted[0] != line:
			return {}
		return {"resource": lifted, "consumed": 1}

	func summary_for(entry: Resource) -> String:
		var signal_row: SignalRow = entry as SignalRow
		if signal_row == null:
			return ""
		var declaration: String = signal_row.signal_name
		if not signal_row.params.is_empty():
			declaration += "(%s)" % ", ".join(signal_row.params)
		return declaration

	func _clean_params(signal_row: SignalRow) -> PackedStringArray:
		var params: PackedStringArray = PackedStringArray()
		for param: String in signal_row.params:
			if not param.strip_edges().is_empty():
				params.append(param.strip_edges())
		return params


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
			{"id": "description", "label": "Description", "type": TYPE_STRING, "default": ""},
			{"id": "color", "label": "Bubble color", "type": TYPE_COLOR, "default": ""},
			{"id": "is_end", "label": "Closing fence (#endregion)", "type": TYPE_BOOL, "default": false},
		]

	# A styled opener (color and/or description set) emits an `## @ace_region(...)`
	# marker line ABOVE the fence - metadata-as-attributes, so the .gd stays plain
	# and an unstyled `#region` line stays byte-identical to what it always was.
	func emit(block: CustomBlockRow) -> PackedStringArray:
		if bool(block.fields.get("is_end", false)):
			return PackedStringArray(["#endregion"])
		var label: String = str(block.fields.get("label", "")).strip_edges()
		var fence: String = "#region %s" % label if not label.is_empty() else "#region"
		var marker: String = _style_marker(block)
		if marker.is_empty():
			return PackedStringArray([fence])
		return PackedStringArray([marker, fence])

	func lift(lines: PackedStringArray, i: int) -> Dictionary:
		var line: String = lines[i]
		if line == "#endregion":
			return verified_claim({"label": "", "is_end": true}, lines, i, 1)
		# A style marker directly above a fence lifts WITH it (two lines, one row).
		# Emission canonicalizes the marker (color first, then the quoted description),
		# so a hand-written variant that re-emits differently fails the byte gate and
		# stays raw - degrade, never corrupt.
		if line.begins_with("## @ace_region(") and i + 1 < lines.size() \
				and (lines[i + 1] == "#region" or lines[i + 1].begins_with("#region ")):
			var styled: Dictionary = _parse_style_marker(line)
			styled["label"] = lines[i + 1].substr(8) if lines[i + 1].begins_with("#region ") else ""
			styled["is_end"] = false
			return verified_claim(styled, lines, i, 2)
		if line == "#region":
			return verified_claim({"label": "", "is_end": false}, lines, i, 1)
		if line.begins_with("#region "):
			return verified_claim({"label": line.substr(8), "is_end": false}, lines, i, 1)
		return {}

	func summary(block: CustomBlockRow) -> String:
		if bool(block.fields.get("is_end", false)):
			return "end"
		# The name a region READS with is the region facts' answer - the row on the canvas, the picker
		# and the block listings say the same words about the same fence, unnamed ones included.
		return EventSheetRegionFacts.display_name(block)

	# A region is a FOLD MARK, not a group: it holds no locals, it cannot be switched off, and
	# it is two plain lines of the file rather than a resource. Asking for the region look through
	# the public hook is what stopped it borrowing the group bar's chrome.
	func row_style(_entry: Resource) -> String:
		return "region"

	static func _style_marker(block: CustomBlockRow) -> String:
		var color: String = str(block.fields.get("color", "")).strip_edges()
		var description: String = str(block.fields.get("description", "")).strip_edges()
		if color.is_empty() and description.is_empty():
			return ""
		var parts: PackedStringArray = []
		if not color.is_empty():
			parts.append(color)
		if not description.is_empty():
			# The marker must stay one parseable line; inner double quotes soften.
			parts.append("\"%s\"" % description.replace("\"", "'"))
		return "## @ace_region(%s)" % ", ".join(parts)

	## Tokens inside the parens, by shape: `#...` = color, `"..."` = description.
	static func _parse_style_marker(line: String) -> Dictionary:
		var parsed: Dictionary = {"color": "", "description": ""}
		var open_index: int = line.find("(")
		var close_index: int = line.rfind(")")
		if open_index == -1 or close_index <= open_index:
			return parsed
		var payload: String = line.substr(open_index + 1, close_index - open_index - 1)
		var in_quotes: bool = false
		var current: String = ""
		var tokens: Array[String] = []
		for char_index in range(payload.length()):
			var character: String = payload.substr(char_index, 1)
			if character == "\"":
				in_quotes = not in_quotes
			if character == "," and not in_quotes:
				tokens.append(current)
				current = ""
				continue
			current += character
		tokens.append(current)
		for token: String in tokens:
			var trimmed: String = token.strip_edges()
			if trimmed.begins_with("#"):
				parsed["color"] = trimmed
			elif trimmed.begins_with("\"") and trimmed.ends_with("\"") and trimmed.length() >= 2:
				parsed["description"] = trimmed.substr(1, trimmed.length() - 2)
		return parsed


# ── Built-in RESOURCE kind: the Moment block (`func moment_impact(strength, from) -> void:`) ──
# A moment written as rows: the block head names it, its child steps carry a timing word on the
# left and any actions on the right, and the whole thing compiles to ONE coroutine on the host.
#
# THE SHAPE IT READS BACK. A hand-written coroutine of exactly the emitted form - the fixed
# signature, waits through the Juice pack's runner, an optional `for _moment_loop` around a
# looped stretch - opens as this block. Anything else stays the plain function it always was.
# The statements inside each step come back as VERBATIM code rows: recovering a step's WHEN is
# what makes the block a block, and a statement nothing claims is an honest line of GDScript
# rather than a mangled row. The claim is dropped altogether unless re-emission reproduces the
# consumed lines byte for byte, so a moment can never be corrupted by being opened.
class MomentBlockKind extends EventSheetBlockKind:
	## The waits the emitted coroutine is made of, by name, so the reader of this file can see
	## the whole vocabulary the lift looks for in one place.
	const AT_CALL: String = ".at(self, "
	const THEN_CALL: String = ".then(self, "
	const HOLD_CALL: String = ".hold(self, "
	const RANGE_CALL: String = ".strength_at(self, strength, from, "
	const LOOP_HEAD: String = "for _moment_loop: int in "

	func _init() -> void:
		kind_id = "moment"
		title = "Moment"

	func handles(entry: Resource) -> bool:
		return entry is MomentBlockRow

	func addable() -> bool:
		return false

	func source_map_kind() -> String:
		return "moment"

	## The block as GDScript, with each step's VERBATIM statements in place. This is the lift's
	## own byte gate; the compiler emits through the same MomentBlockRow.build_lines() with a
	## provider that also knows how to render ACE action rows.
	func emit_lines(entry: Resource) -> PackedStringArray:
		var block: MomentBlockRow = entry as MomentBlockRow
		if block == null:
			return PackedStringArray()
		return block.build_lines(_verbatim_statements)

	func summary_for(entry: Resource) -> String:
		var block: MomentBlockRow = entry as MomentBlockRow
		if block == null:
			return ""
		return "%s - %d step(s)" % [block.moment_name, block.live_steps().size()]

	func lift(lines: PackedStringArray, i: int) -> Dictionary:
		var header: RegEx = RegEx.new()
		if header.compile("^func %s([A-Za-z_][A-Za-z0-9_]*)%s$" % [
				MomentBlockRow.FUNCTION_PREFIX, _escaped_signature()]) != OK:
			return {}
		var opened: RegExMatch = header.search(lines[i])
		if opened == null:
			return {}
		var body_end: int = i + 1
		while body_end < lines.size() and lines[body_end].begins_with("\t"):
			body_end += 1
		var consumed: int = body_end - i
		if consumed < 2:
			return {}
		var block: MomentBlockRow = _read_body(opened.get_string(1), lines.slice(i + 1, body_end))
		if block == null:
			return {}
		# The gate: a claim survives only when the block writes those exact lines back.
		var emitted: PackedStringArray = emit_lines(block)
		if emitted.size() != consumed:
			return {}
		for offset: int in range(consumed):
			if emitted[offset] != lines[i + offset]:
				return {}
		return {"resource": block, "consumed": consumed}

	## The signature as a regular expression, derived from the one place it is spelled so the two
	## can never drift apart.
	func _escaped_signature() -> String:
		var pattern: String = ""
		for index: int in range(MomentBlockRow.SIGNATURE.length()):
			var character: String = MomentBlockRow.SIGNATURE[index]
			pattern += ("\\" + character) if "()[]{}.*+?^$|".contains(character) else character
		return pattern

	## Reads a moment's body back into steps: the range line, the loop head, the three waits, and
	## everything else as a verbatim statement on the step it belongs to. Returns null the moment
	## the body is not a shape this kind writes, which is how a plain coroutine stays a function.
	func _read_body(word: String, body: PackedStringArray) -> MomentBlockRow:
		var block: MomentBlockRow = MomentBlockRow.new()
		block.moment_name = word
		var current: MomentStepRow = null
		var cursor: float = 0.0
		var last_start: float = 0.0
		var depth: int = 1
		var loop_count: int = 1
		var pending_loop: bool = false
		for raw_line: String in body:
			if not raw_line.begins_with("\t".repeat(depth)):
				if depth == 1:
					return null
				# The looped stretch has ended: the row that closes it is the loop back.
				block.steps.append(_loop_back_step(loop_count))
				depth = 1
				cursor = 0.0
				last_start = 0.0
				current = null
			var line: String = raw_line.substr(depth)
			if line.begins_with("\t"):
				return null  # a body indented deeper than any shape this kind writes
			if current == null and line == "pass":
				continue
			if block.steps.is_empty() and current == null and line.contains(RANGE_CALL):
				var ranged: PackedStringArray = _arguments(line, RANGE_CALL)
				if ranged.size() != 2:
					return null
				block.within = ranged[0].to_float()
				block.falloff = ranged[1].strip_edges().trim_prefix("\"").trim_suffix("\"")
				continue
			if line.begins_with(LOOP_HEAD) and line.ends_with(":"):
				if depth == 2:
					return null  # one level of looping is the whole grammar
				loop_count = maxi(line.substr(LOOP_HEAD.length()).trim_suffix(":").to_int() - 1, 1)
				pending_loop = true
				depth = 2
				cursor = 0.0
				last_start = 0.0
				current = null
				continue
			var started: MomentStepRow = _step_from_wait(line, cursor)
			if started != null:
				_carry_hold_duration(started, current, cursor, last_start)
				cursor = float(started.get_meta("__cursor", cursor))
				started.remove_meta("__cursor")
				last_start = cursor
				block.steps.append(started)
				current = started
				pending_loop = false
				continue
			if current == null:
				current = MomentStepRow.new()
				current.seconds = cursor
				last_start = cursor
				block.steps.append(current)
				pending_loop = false
			var statement: RawCodeRow = RawCodeRow.new()
			statement.code = line
			current.actions.append(statement)
		if pending_loop:
			return null  # a loop head with nothing under it is not a shape this kind writes
		if depth == 2:
			block.steps.append(_loop_back_step(loop_count))
		return block

	## The row a closing looped stretch reads as.
	func _loop_back_step(loop_count: int) -> MomentStepRow:
		var closer: MomentStepRow = MomentStepRow.new()
		closer.timing = MomentStepRow.TIMING_LOOP_BACK
		closer.loop_count = loop_count
		return closer

	## One wait line as the step it starts, or null when the line is not a wait. Where the
	## schedule stands afterwards rides on a meta the caller takes straight back off - the reader
	## needs both answers, and a step has nowhere to keep a running total.
	func _step_from_wait(line: String, cursor: float) -> MomentStepRow:
		if not line.begins_with("await %s" % MomentBlockRow.RUNNER):
			return null
		var step: MomentStepRow = MomentStepRow.new()
		if line.contains(AT_CALL):
			var at_args: PackedStringArray = _arguments(line, AT_CALL)
			if at_args.size() != 2:
				return null
			step.timing = MomentStepRow.TIMING_AT
			step.seconds = cursor + at_args[0].to_float()
			step.clock = _clock_word(at_args[1])
			step.set_meta("__cursor", step.seconds)
			return step
		if line.contains(THEN_CALL):
			var then_args: PackedStringArray = _arguments(line, THEN_CALL)
			if then_args.size() != 2:
				return null
			step.timing = MomentStepRow.TIMING_THEN
			step.seconds = then_args[0].to_float()
			step.clock = _clock_word(then_args[1])
			step.set_meta("__cursor", cursor + step.seconds)
			return step
		if line.contains(HOLD_CALL):
			var hold_args: PackedStringArray = _arguments(line, HOLD_CALL)
			if hold_args.size() != 3:
				return null
			step.timing = MomentStepRow.TIMING_HOLD
			step.seconds = hold_args[1].to_float()
			step.clock = _clock_word(hold_args[2])
			# The first number is how much of the longest step above is still to run.
			step.set_meta("__longest", hold_args[0].to_float())
			step.set_meta("__cursor", cursor + hold_args[0].to_float() + step.seconds)
			return step
		return null

	## Puts a Hold's waited-for time back on the step above it, as the duration that step declared
	## - the reverse of the fold the emitter does. Nothing to do when the wait was zero, which is
	## every moment whose steps are all instant.
	func _carry_hold_duration(step: MomentStepRow, above: MomentStepRow, cursor: float,
			above_start: float) -> void:
		if not step.has_meta("__longest"):
			return
		var longest: float = float(step.get_meta("__longest"))
		step.remove_meta("__longest")
		if longest <= 0.0 or above == null:
			return
		above.lasts = maxf(cursor + longest - above_start, 0.0)


	## The clock a wait names ("real" only when it says so).
	func _clock_word(argument: String) -> String:
		if argument.contains(MomentStepRow.CLOCK_REAL):
			return MomentStepRow.CLOCK_REAL
		return MomentStepRow.CLOCK_GAME

	## The arguments of one runner call, split at the top level, with the leading `self` dropped.
	func _arguments(line: String, call_text: String) -> PackedStringArray:
		var opened: int = line.find(call_text)
		if opened < 0:
			return PackedStringArray()
		var closed: int = line.rfind(")")
		if closed <= opened:
			return PackedStringArray()
		var start: int = opened + call_text.length()
		return EventSheetBlockRegistry.split_params_top_level(line.substr(start, closed - start))

	## Every statement a step holds, unindented, exactly as the compiler renders a verbatim row.
	static func _verbatim_statements(step: MomentStepRow) -> PackedStringArray:
		var out: PackedStringArray = PackedStringArray()
		if step == null:
			return out
		for entry: Variant in step.actions:
			if not (entry is RawCodeRow):
				continue
			var raw: RawCodeRow = entry as RawCodeRow
			if not raw.enabled or raw.code.strip_edges().is_empty():
				continue
			for code_line: String in raw.code.split("\n"):
				out.append(code_line)
		return out
