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
		var label: String = str(block.fields.get("label", "")).strip_edges()
		return label if not label.is_empty() else "(unnamed)"

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
