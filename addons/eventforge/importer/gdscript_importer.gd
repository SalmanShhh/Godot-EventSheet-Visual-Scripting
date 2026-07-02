# EventForge — GDScript importer
# Parses generated/handwritten GDScript back into an EventSheetResource: the `extends`
# host class, top-level exported variables (with their Inspector @export_group/@export_subgroup
# grouping absorbed onto the variable), enums, signals, and functions.
#
# ACE-level lifting IS shipped: EventSheetACELifter.attempt_lift() reverse-matches generated `if`
# chains and action templates back into real events/conditions/actions, gated by a byte-identical
# verify-lift (anything that doesn't reproduce exactly stays a verbatim RawCodeRow — the lossless rule
# always wins).
@tool
extends RefCounted
class_name GDScriptImporter

func import_script(script_path: String) -> EventSheetResource:
	if not FileAccess.file_exists(script_path):
		return null
	return import_source(FileAccess.get_file_as_string(script_path))

## ── GDScript-backed sheets (open ANY .gd as a sheet, losslessly) ─────────────
## Unlike import_source (structural import into a normal sheet), external import keeps the
## .gd file as the single source of truth. THE LOSSLESS RULE: every line lands in exactly
## one ordered row — declarations are lifted to first-class rows ONLY when re-emitting them
## reproduces the original line byte-for-byte (verify-lift); everything else is preserved
## verbatim as GDScript block rows. Saving an untouched file therefore reproduces it
## exactly (guarded by golden round-trip tests).

func import_external(script_path: String) -> EventSheetResource:
	if not FileAccess.file_exists(script_path):
		return null
	var sheet: EventSheetResource = import_external_source(FileAccess.get_file_as_string(script_path))
	sheet.external_source_path = script_path
	_recover_autoload_identity(sheet, script_path)
	return sheet

## A .gd registered in the project's [autoload] section IS an autoload sheet — recover that identity
## from ProjectSettings (the single source of truth) so opening the .gd round-trips autoload_mode +
## autoload_name without needing a marker comment in the file. Unregistered .gd files open as plain
## sheets (and Project Doctor already flags an autoload sheet that isn't registered).
static func _recover_autoload_identity(sheet: EventSheetResource, script_path: String) -> void:
	if sheet == null or script_path.is_empty():
		return
	for property: Dictionary in ProjectSettings.get_property_list():
		var setting_name: String = str(property.get("name", ""))
		if not setting_name.begins_with("autoload/"):
			continue
		# Autoload values are the script path, optionally prefixed with "*" (enabled singleton).
		if _autoload_target_matches(str(ProjectSettings.get_setting(setting_name, "")).trim_prefix("*"), script_path):
			sheet.autoload_mode = true
			sheet.autoload_name = setting_name.trim_prefix("autoload/")
			return

## Whether an [autoload] target points at script_path. Handles both res:// values and uid:// values
## (Godot 4.4+ frequently stores autoloads by UID once a .uid sidecar exists) by resolving the uid.
static func _autoload_target_matches(target: String, script_path: String) -> bool:
	if target == script_path:
		return true
	if target.begins_with("uid://"):
		var uid: int = ResourceUID.text_to_id(target)
		if uid != ResourceUID.INVALID_ID and ResourceUID.has_id(uid):
			return ResourceUID.get_id_path(uid) == script_path
	return false

func import_external_source(source: String) -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = _parse_host_class(source)
	var lines: PackedStringArray = source.split("\n")
	# A trailing "\n" yields one empty trailing element; the compiler re-appends the final
	# newline, so drop exactly that element to keep round-trips byte-identical.
	if lines.size() > 0 and lines[lines.size() - 1].is_empty():
		lines.remove_at(lines.size() - 1)
	# Lines (blanks/comments/annotations/unliftable code) accumulate here and flush as one
	# verbatim block row whenever a liftable construct or a function boundary is reached.
	var pending: PackedStringArray = PackedStringArray()
	var index: int = 0
	while index < lines.size():
		var line: String = lines[index]
		# Top-level function: emitted as its OWN block row (one row per function gives the
		# sheet useful granularity and per-function provenance without lossy lifting).
		if line.begins_with("func "):
			_flush_pending(pending, sheet)
			var function_lines: PackedStringArray = PackedStringArray([line])
			index += 1
			while index < lines.size():
				var body_line: String = lines[index]
				var is_body: bool = body_line.strip_edges().is_empty() or body_line.begins_with("\t") or body_line.begins_with(" ")
				if not is_body:
					break
				function_lines.append(body_line)
				index += 1
			# Trailing blank lines belong to whatever follows, not to the function block.
			while function_lines.size() > 1 and function_lines[function_lines.size() - 1].strip_edges().is_empty():
				pending.append(function_lines[function_lines.size() - 1])
				function_lines.remove_at(function_lines.size() - 1)
			var function_block: RawCodeRow = RawCodeRow.new()
			function_block.code = "\n".join(function_lines)
			sheet.events.append(function_block)
			continue
		var lifted: LocalVariable = _try_lift_variable(line)
		if lifted != null:
			_absorb_tree_variable_group(lifted, pending, line)
			_flush_pending(pending, sheet)
			sheet.events.append(lifted)
			index += 1
			continue
		var lifted_enum: EnumRow = _try_lift_enum(line)
		if lifted_enum != null:
			_flush_pending(pending, sheet)
			sheet.events.append(lifted_enum)
			index += 1
			continue
		var lifted_signal: SignalRow = _try_lift_signal(line)
		if lifted_signal != null:
			_absorb_signal_trigger_annotations(lifted_signal, pending, line)
			_flush_pending(pending, sheet)
			sheet.events.append(lifted_signal)
			index += 1
			continue
		pending.append(line)
		index += 1
	_flush_pending(pending, sheet)
	# Recover identity fields from the source text: emission keeps the prelude verbatim
	# (so these never affect bytes), but lint, the identity banner, and the lifter's
	# annotation regeneration ($Class.fn templates for behaviors) all need them.
	if source.begins_with("@tool\n") or source.contains("\n@tool\n"):
		sheet.tool_mode = true
	var class_name_regex: RegEx = RegEx.new()
	if class_name_regex.compile("(?m)^class_name ([A-Za-z_][A-Za-z0-9_]*)") == OK:
		var class_match: RegExMatch = class_name_regex.search(source)
		if class_match != null:
			sheet.custom_class_name = class_match.get_string(1)
	# Recover the custom node icon (`@icon("res://…")`) so the sheet banner shows it and a re-save
	# regenerates it. The annotation line itself stays in the verbatim prelude block, so this is
	# metadata only — no double-emit.
	var icon_regex: RegEx = RegEx.new()
	if icon_regex.compile("(?m)^@icon\\(\"([^\"]+)\"\\)") == OK:
		var icon_match: RegExMatch = icon_regex.search(source)
		if icon_match != null:
			sheet.custom_class_icon = icon_match.get_string(1)
	# Recover addon tags (`## @ace_tags(a, b)`) so picker categorization / search round-trips. The
	# annotation line stays in the verbatim prelude block, so this is metadata only — no double-emit.
	var tags_regex: RegEx = RegEx.new()
	if tags_regex.compile("(?m)^## @ace_tags\\(([^)]*)\\)") == OK:
		var tags_match: RegExMatch = tags_regex.search(source)
		if tags_match != null:
			var recovered_tags: PackedStringArray = PackedStringArray()
			for tag: String in tags_match.get_string(1).split(","):
				var trimmed_tag: String = tag.strip_edges()
				if not trimmed_tag.is_empty():
					recovered_tags.append(trimmed_tag)
			sheet.addon_tags = recovered_tags
	# Recover the Family marker (`## @ace_family(Name)`) so a family-typed sheet re-opens as a family.
	# Metadata only (the line stays in the verbatim prelude) — exactly like @ace_tags above, so it can't
	# double-emit. The group/vars/ACEs are all derived from the class, so the bare name is enough.
	var family_regex: RegEx = RegEx.new()
	if family_regex.compile("(?m)^## @ace_family\\(") == OK:
		sheet.is_family = family_regex.search(source) != null
	# Recover the class description: the `##` doc block immediately after `extends` (no blank
	# between). The host-member doc and signal annotations are separated from `extends` by a blank
	# line, so they never match. Metadata only in external mode (the lines stay verbatim).
	var description_regex: RegEx = RegEx.new()
	if description_regex.compile("(?m)^extends .+\\n((?:##.*\\n)+)") == OK:
		var description_match: RegExMatch = description_regex.search(source)
		if description_match != null:
			var doc_lines: PackedStringArray = PackedStringArray()
			for doc_line: String in description_match.get_string(1).split("\n"):
				if doc_line == "##":
					doc_lines.append("")
				elif doc_line.begins_with("## "):
					doc_lines.append(doc_line.substr(3))
				elif doc_line.begins_with("##"):
					doc_lines.append(doc_line.substr(2))
			while not doc_lines.is_empty() and doc_lines[doc_lines.size() - 1].is_empty():
				doc_lines.remove_at(doc_lines.size() - 1)
			sheet.class_description = "\n".join(doc_lines)
	var host_regex: RegEx = RegEx.new()
	if source.contains("\nextends Node\n") and host_regex.compile("(?m)^var host: ([A-Za-z_][A-Za-z0-9_]*) = null$") == OK:
		var host_match: RegExMatch = host_regex.search(source)
		if host_match != null:
			sheet.behavior_mode = true
			sheet.host_class = host_match.get_string(1)
	# Tier 2: reverse template matching lifts trailing trigger functions, sheet functions
	# (with their @ace annotation blocks), and trailing comments into real rows — verified
	# by a byte-identical recompile and reverted otherwise (the lossless rule always wins).
	EventSheetACELifter.attempt_lift(sheet, source)
	return sheet

## Lifts a top-level variable declaration to an ordered tree-variable row, but ONLY when the
## compiler's canonical emission reproduces the source line exactly (the verify-lift rule);
## otherwise the line stays verbatim in a block row and nothing is lost.
func _try_lift_variable(line: String) -> LocalVariable:
	if not (line.begins_with("var ") or line.begins_with("@export") or line.begins_with("const ")):
		return null
	var parsed: Dictionary = VariableParser.new().parse(line)
	if parsed.size() != 1:
		return null
	var variable_name: String = str(parsed.keys()[0])
	var descriptor: Dictionary = parsed[variable_name]
	var lifted: LocalVariable = LocalVariable.new()
	lifted.name = variable_name
	lifted.type_name = str(descriptor.get("type", "Variant"))
	lifted.default_value = descriptor.get("default", null)
	lifted.exported = bool(descriptor.get("exported", false))
	lifted.options = PackedStringArray(descriptor.get("options", []))
	lifted.export_hint = str(descriptor.get("hint", ""))
	# A `const` declaration restores a first-class constant variable (green "const" pill, editable in the
	# dialog) instead of degrading to a verbatim block. Byte-gated below like every other lift.
	lifted.is_constant = bool(descriptor.get("constant", false))
	# A String default that appeared UNQUOTED in the source is a bare code expression (Vector2.ZERO,
	# Color.RED, Type.CONST), not a literal — mark it so it re-emits verbatim rather than quoted. The
	# byte-verify below still gates it: if the flagged re-emission doesn't reproduce the line, revert.
	if lifted.default_value is String and not lifted.is_constant and not lifted.onready \
			and line.contains("= %s" % str(lifted.default_value)) and not line.contains("\"%s\"" % str(lifted.default_value)):
		lifted.expression_default = true
	if SheetCompiler._emit_tree_variable_line(lifted) != line:
		return null
	_extract_drawer_from_hint(lifted, line)
	_extract_color_no_alpha(lifted, line)
	_extract_exp_easing(lifted, line)
	_extract_placeholder(lifted, line)
	return lifted

## @export_color_no_alpha round-trip: pull the bare hint into the structured `no_alpha` attribute so a
## reopened Color shows the dialog's "No alpha" tick instead of a verbatim hint. Verify-gated like the
## drawer recovery — if the structured re-emission doesn't reproduce the line exactly, revert.
func _extract_color_no_alpha(lifted: LocalVariable, line: String) -> void:
	if lifted.export_hint.strip_edges() != "@export_color_no_alpha":
		return
	var saved_hint: String = lifted.export_hint
	var saved_attrs: Dictionary = (lifted.attributes as Dictionary).duplicate() if lifted.attributes is Dictionary else {}
	var attrs: Dictionary = (lifted.attributes as Dictionary).duplicate() if lifted.attributes is Dictionary else {}
	attrs["no_alpha"] = true
	lifted.attributes = attrs
	lifted.export_hint = ""
	if SheetCompiler._emit_tree_variable_line(lifted) != line:
		lifted.export_hint = saved_hint
		lifted.attributes = saved_attrs

## @export_exp_easing round-trip: bare hint → structured `exp_easing` attribute (the float easing tick).
func _extract_exp_easing(lifted: LocalVariable, line: String) -> void:
	if lifted.export_hint.strip_edges() != "@export_exp_easing":
		return
	var saved_hint: String = lifted.export_hint
	var saved_attrs: Dictionary = (lifted.attributes as Dictionary).duplicate() if lifted.attributes is Dictionary else {}
	var attrs: Dictionary = (lifted.attributes as Dictionary).duplicate() if lifted.attributes is Dictionary else {}
	attrs["exp_easing"] = true
	lifted.attributes = attrs
	lifted.export_hint = ""
	if SheetCompiler._emit_tree_variable_line(lifted) != line:
		lifted.export_hint = saved_hint
		lifted.attributes = saved_attrs

## @export_placeholder("hint") round-trip: pull the quoted hint text into the structured `placeholder`
## attribute (the dialog's Placeholder field). Verify-gated like the others.
func _extract_placeholder(lifted: LocalVariable, line: String) -> void:
	if not lifted.export_hint.strip_edges().begins_with("@export_placeholder("):
		return
	var text: String = _extract_first_quoted(lifted.export_hint)
	var saved_hint: String = lifted.export_hint
	var saved_attrs: Dictionary = (lifted.attributes as Dictionary).duplicate() if lifted.attributes is Dictionary else {}
	var attrs: Dictionary = (lifted.attributes as Dictionary).duplicate() if lifted.attributes is Dictionary else {}
	attrs["placeholder"] = text
	lifted.attributes = attrs
	lifted.export_hint = ""
	if SheetCompiler._emit_tree_variable_line(lifted) != line:
		lifted.export_hint = saved_hint
		lifted.attributes = saved_attrs

## Tier 3 round-trip: if the lifted variable's export_hint is a custom-drawer marker
## (`@export_custom(PROPERTY_HINT_NONE, "eventsheet:<drawer>…")`), pull it into structured
## attributes.drawer (+ range bounds for progress_bar/vector_dial) and clear export_hint — so a reopened
## drawer is an editable drawer in the Variable dialog, not a verbatim @export_custom block. Verify-gated:
## if re-emission from the structured form doesn't reproduce the exact line, revert (byte-safety wins).
func _extract_drawer_from_hint(lifted: LocalVariable, line: String) -> void:
	var hint: String = lifted.export_hint.strip_edges()
	if not hint.begins_with("@export_custom(") or hint.find("\"eventsheet:") == -1:
		return
	var marker: String = _extract_first_quoted(hint)
	if not marker.begins_with("eventsheet:"):
		return
	var parts: PackedStringArray = marker.split(":")
	if parts.size() < 2 or str(parts[1]).strip_edges().is_empty():
		return
	var saved_hint: String = lifted.export_hint
	var saved_attrs: Dictionary = (lifted.attributes as Dictionary).duplicate() if lifted.attributes is Dictionary else {}
	var attrs: Dictionary = (lifted.attributes as Dictionary).duplicate() if lifted.attributes is Dictionary else {}
	attrs["drawer"] = parts[1]
	# progress_bar carries min:max, vector_dial carries a single max magnitude — recovered into the same
	# `range` dict the emitter reads, so the marker re-emits byte-for-byte.
	if parts[1] == "progress_bar" and parts.size() >= 4:
		attrs["range"] = {"min": parts[2], "max": parts[3]}
	elif parts[1] == "vector_dial" and parts.size() >= 3:
		attrs["range"] = {"max": parts[2]}
	lifted.attributes = attrs
	lifted.export_hint = ""
	if SheetCompiler._emit_tree_variable_line(lifted) != line:
		lifted.export_hint = saved_hint
		lifted.attributes = saved_attrs

## When a tree variable lifts, pull a directly-preceding @export_group / @export_subgroup off the pending
## block onto the variable's attributes — but only if the variable's canonical re-emission then reproduces
## those exact lines plus the var line (the verify-lift rule). A wrong guess is reverted, so a grouped var
## becomes a clean grouped variable instead of a stray @export_group GDScript block — without ever risking
## the byte-exact round-trip. (Order matches _emit_variables: @export_group then @export_subgroup.)
func _absorb_tree_variable_group(lifted: LocalVariable, pending: PackedStringArray, var_line: String) -> void:
	var subgroup_value: String = ""
	var group_value: String = ""
	var meta_count: int = 0
	var cursor: int = pending.size() - 1
	if cursor >= 0 and pending[cursor].begins_with("@export_subgroup(\""):
		subgroup_value = _extract_first_quoted(pending[cursor])
		meta_count += 1
		cursor -= 1
	if cursor >= 0 and pending[cursor].begins_with("@export_group(\""):
		group_value = _extract_first_quoted(pending[cursor])
		meta_count += 1
		cursor -= 1
	var tooltip_value: String = ""
	# A doc comment immediately before the var (no blank line — a blank line would sit at pending's tail
	# instead) is the variable's tooltip, per Godot's `##` doc-comment convention. Exclude `## @...`
	# annotation lines (@ace_tags / @icon / …), which are recovered elsewhere and are never tooltips.
	if cursor >= 0 and pending[cursor].begins_with("## ") and not pending[cursor].begins_with("## @"):
		tooltip_value = pending[cursor].substr(3).strip_edges()
		if not tooltip_value.is_empty():
			meta_count += 1
			cursor -= 1
	var candidate: Dictionary = {}
	if not tooltip_value.is_empty():
		candidate["tooltip"] = tooltip_value
	if not group_value.is_empty():
		candidate["group"] = group_value
	if not subgroup_value.is_empty():
		candidate["subgroup"] = subgroup_value
	if candidate.is_empty():
		return
	# MERGE, don't overwrite: a drawer (+ its range bounds) may already have been recovered onto the variable
	# by _extract_drawer_from_hint, and the grouping/tooltip rides alongside it. Overwriting here dropped the
	# drawer whenever a variable carried BOTH a custom drawer AND an @export_group (the common showcase case).
	var saved_attrs: Dictionary = (lifted.attributes as Dictionary).duplicate() if lifted.attributes is Dictionary else {}
	var merged: Dictionary = saved_attrs.duplicate()
	merged.merge(candidate, true)
	lifted.attributes = merged
	var absorbed: PackedStringArray = PackedStringArray()
	for index: int in range(pending.size() - meta_count, pending.size()):
		absorbed.append(pending[index])
	absorbed.append(var_line)
	if SheetCompiler._emit_tree_variable_line(lifted) != "\n".join(absorbed):
		lifted.attributes = saved_attrs  # reverted — keep whatever was already recovered (e.g. the drawer)
		return
	for _removed: int in range(meta_count):
		pending.remove_at(pending.size() - 1)

## The text inside the first "..." pair on a line ("" if none).
func _extract_first_quoted(line: String) -> String:
	var open_quote: int = line.find("\"")
	if open_quote < 0:
		return ""
	var close_quote: int = line.find("\"", open_quote + 1)
	if close_quote < 0:
		return ""
	return line.substr(open_quote + 1, close_quote - open_quote - 1)

## Lifts a canonical single-line enum (`enum Name { A, B = 4 }`) to an EnumRow when the
## compiler's emission reproduces the line exactly (the verify-lift rule); multi-line or
## otherwise-formatted enums stay verbatim blocks.
func _try_lift_enum(line: String) -> EnumRow:
	if not line.begins_with("enum "):
		return null
	var enum_regex: RegEx = RegEx.new()
	if enum_regex.compile("^enum ([A-Za-z_][A-Za-z0-9_]*) \\{ (.+) \\}$") != OK:
		return null
	var enum_match: RegExMatch = enum_regex.search(line)
	if enum_match == null:
		return null
	var lifted: EnumRow = EnumRow.new()
	lifted.enum_name = enum_match.get_string(1)
	lifted.members = PackedStringArray(enum_match.get_string(2).split(", "))
	if SheetCompiler._emit_enum_line(lifted) != line:
		return null
	return lifted

## Lifts a canonical signal declaration to a SignalRow when re-emission reproduces the
## line exactly (the verify-lift rule); other formats stay verbatim blocks.
func _try_lift_signal(line: String) -> SignalRow:
	if not line.begins_with("signal "):
		return null
	var signal_regex: RegEx = RegEx.new()
	if signal_regex.compile("^signal ([A-Za-z_][A-Za-z0-9_]*)(?:\\((.*)\\))?$") != OK:
		return null
	var signal_match: RegExMatch = signal_regex.search(line)
	if signal_match == null:
		return null
	var lifted: SignalRow = SignalRow.new()
	lifted.signal_name = signal_match.get_string(1)
	var params_text: String = signal_match.get_string(2)
	if not params_text.is_empty():
		lifted.params = PackedStringArray(params_text.split(", "))
	if SheetCompiler._emit_signal_line(lifted) != line:
		return null
	return lifted

## When a signal lifts, pull a directly-preceding `## @ace_trigger` (+ optional `## @ace_name` /
## `## @ace_category`) block off the pending lines onto the SignalRow — the reverse of the compiler's
## _emit_signal_annotations — so a behaviour's exposed trigger signal reads as ONE first-class "trigger"
## row instead of stranding those annotations in a separate GDScript "setup" block above a bare signal.
## Verify-gated exactly like _absorb_tree_variable_group: the SignalRow's canonical re-emission
## (annotation block + declaration) must reproduce those exact source lines, or the guess is reverted
## (byte-safety always wins). Only a `## @ace_trigger`-anchored block is absorbed; a plain signal keeps
## its bare row, and a stray `## @ace_name` with no `## @ace_trigger` above the signal is left untouched.
func _absorb_signal_trigger_annotations(lifted: SignalRow, pending: PackedStringArray, signal_line: String) -> void:
	# _emit_signal_annotations lays the block down as `## @ace_trigger`, then optional `## @ace_name`,
	# then optional `## @ace_category`. Walk up pending's tail collecting that contiguous run; it must be
	# headed by `## @ace_trigger` (anything else means this isn't a trigger-annotation block).
	var run_start: int = pending.size()
	var ace_name: String = ""
	var ace_category: String = ""
	var cursor: int = pending.size() - 1
	while cursor >= 0:
		var text: String = pending[cursor].strip_edges()
		if text == "## @ace_trigger":
			run_start = cursor
			break  # the anchor heads the block — stop (lines above belong to whatever precedes it)
		elif text.begins_with("## @ace_name(\"") and text.ends_with("\")"):
			ace_name = _extract_first_quoted(pending[cursor])
			run_start = cursor
			cursor -= 1
		elif text.begins_with("## @ace_category(\"") and text.ends_with("\")"):
			ace_category = _extract_first_quoted(pending[cursor])
			run_start = cursor
			cursor -= 1
		else:
			break
	if run_start >= pending.size() or pending[run_start].strip_edges() != "## @ace_trigger":
		return  # no `## @ace_trigger` anchor → a plain signal; leave the pending block untouched
	lifted.trigger = true
	lifted.ace_name = ace_name
	lifted.ace_category = ace_category
	var absorbed: PackedStringArray = PackedStringArray()
	for index: int in range(run_start, pending.size()):
		absorbed.append(pending[index])
	absorbed.append(signal_line)
	var expected: PackedStringArray = SheetCompiler._emit_signal_annotations(lifted)
	expected.append(SheetCompiler._emit_signal_line(lifted))
	if "\n".join(expected) != "\n".join(absorbed):
		# The block wasn't in canonical form (reordered / extra directives) — revert to a plain signal so
		# the annotations stay verbatim in their block and the round-trip is never risked.
		lifted.trigger = false
		lifted.ace_name = ""
		lifted.ace_category = ""
		return
	for _removed: int in range(pending.size() - run_start):
		pending.remove_at(pending.size() - 1)

func _flush_pending(pending: PackedStringArray, sheet: EventSheetResource) -> void:
	if pending.is_empty():
		return
	var block: RawCodeRow = RawCodeRow.new()
	block.code = "\n".join(pending)
	sheet.events.append(block)
	pending.clear()

func import_source(source: String) -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = _parse_host_class(source)
	sheet.variables = VariableParser.new().parse(source)
	for function_data: Variant in FunctionParser.new().parse(source):
		if not (function_data is Dictionary):
			continue
		sheet.functions.append(_build_function(function_data as Dictionary))
	return sheet

func _parse_host_class(source: String) -> String:
	for raw_line: String in source.split("\n"):
		var line: String = raw_line.strip_edges()
		if line.begins_with("extends "):
			return line.substr("extends ".length()).strip_edges()
	return "Node"

func _build_function(function_data: Dictionary) -> EventFunction:
	var event_function: EventFunction = EventFunction.new()
	event_function.function_name = str(function_data.get("name", ""))
	for param_data: Variant in function_data.get("params", []):
		if not (param_data is Dictionary):
			continue
		var param: ACEParam = ACEParam.new()
		param.id = str((param_data as Dictionary).get("id", ""))
		param.type_name = str((param_data as Dictionary).get("type", "Variant"))
		event_function.params.append(param)
	var body: String = str(function_data.get("body", ""))
	if not body.strip_edges().is_empty():
		var raw_row: RawCodeRow = RawCodeRow.new()
		raw_row.code = body
		event_function.events.append(raw_row)
	return event_function
