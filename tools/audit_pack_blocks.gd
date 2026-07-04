# Behaviour-pack GDScript-block census (dev/audit tool, not shipped logic). Run headless:
#   godot --headless --path . --script tools/audit_pack_blocks.gd
# For every eventsheet_addons/**/*.gd it opens the file two ways and counts the surviving RawCodeRows:
#   Lens A (user-open): import_external → attempt_lift only (what you see opening the .gd today).
#   Lens B (full chain): same, then the pack-build lift passes byte-gated (function-decls, then
#     function-bodies, event-bodies, signals). Delta A-B measures whether "run the full chain on open"
#     would erase blocks - it is 0 today (the residue is genuine vocabulary/grammar gaps, not lift reach).
# Each remaining block is tagged with a heuristic reason (blank / scaffold / host-binding / exposed
# getter/action / helper-func-body / match / numeric / other) so the audit categorises without guessing.
# NOTE: _classify is a pure-TEXT heuristic and knowingly impure - treat the
# per-category counts as an audit lens, not gospel. Writes a JSON dump to user:// (never committed).
@tool
extends SceneTree


func _init() -> void:
	var files: Array[String] = []
	_gather_gd("res://eventsheet_addons", files)
	files.sort()
	var report: Array = []
	var reason_totals: Dictionary = {}
	var total_a: int = 0
	var total_b: int = 0
	var drift: Array = []
	for path: String in files:
		var source: String = FileAccess.get_file_as_string(path)
		if source.strip_edges().is_empty():
			continue
		# Lens A
		var sheet_a: EventSheetResource = GDScriptImporter.new().import_external(path)
		var raws_a: Array = []
		_collect_raw(sheet_a.events, "events", raws_a)
		for fn_v: Variant in sheet_a.functions:
			if fn_v is EventFunction:
				_collect_raw(_fn_body(fn_v), "func %s" % (fn_v as EventFunction).function_name, raws_a)
		# Lens B - same import, then the full pack-build lift chain (byte-gated so nothing risks the file).
		var sheet_b: EventSheetResource = GDScriptImporter.new().import_external(path)
		EventSheetACELifter.lift_function_declarations(sheet_b, true)
		EventSheetACELifter.lift_function_bodies(sheet_b)
		EventSheetACELifter.lift_event_bodies(sheet_b)
		EventSheetACELifter.lift_signal_declarations(sheet_b, true)
		var raws_b: Array = []
		_collect_raw(sheet_b.events, "events", raws_b)
		for fn_v2: Variant in sheet_b.functions:
			if fn_v2 is EventFunction:
				_collect_raw(_fn_body(fn_v2), "func %s" % (fn_v2 as EventFunction).function_name, raws_b)
		# Byte-verify Lens B still round-trips (the full chain must never corrupt).
		var out_b: String = str(SheetCompiler.compile(sheet_b, "user://_audit_b.gd").get("output", ""))
		var exact_b: bool = out_b == source
		if not exact_b:
			drift.append(path)
		# Categorise the Lens-B remainder.
		var tagged: Array = []
		for blk: Variant in raws_b:
			var d: Dictionary = blk as Dictionary
			d["reason"] = _classify(d, sheet_b)
			reason_totals[d["reason"]] = int(reason_totals.get(d["reason"], 0)) + 1
			tagged.append(d)
		total_a += raws_a.size()
		total_b += raws_b.size()
		report.append({
			"pack": path.get_file(),
			"lens_a_raw": raws_a.size(),
			"lens_b_raw": raws_b.size(),
			"full_chain_exact": exact_b,
			"raws": tagged
		})
		print("[audit] %-42s A=%-3d B=%-3d exact=%s" % [path.get_file(), raws_a.size(), raws_b.size(), str(exact_b)])
	print("[audit] ===== packs=%d  Lens-A total=%d  Lens-B total=%d  (full-chain-on-open would erase %d)  drift=%d =====" % [
		report.size(), total_a, total_b, total_a - total_b, drift.size()])
	print("[audit] Lens-B reason breakdown:")
	var reasons: Array = reason_totals.keys()
	reasons.sort()
	for r: String in reasons:
		print("   %-22s %d" % [r, int(reason_totals[r])])
	if not drift.is_empty():
		print("[audit] FULL-CHAIN DRIFT in: ", drift)
	var out_path := "user://pack_blocks_audit.json"
	var f: FileAccess = FileAccess.open(out_path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(report, "\t"))
		f.close()
		print("[audit] wrote ", ProjectSettings.globalize_path(out_path))
	quit(0)


func _fn_body(fn_v: Variant) -> Array:
	var fn: EventFunction = fn_v as EventFunction
	return fn.events if not fn.events.is_empty() else fn.rows


## Heuristic reason a block stayed GDScript, from its own text (why nothing lifted it into rows).
func _classify(d: Dictionary, _sheet: EventSheetResource) -> String:
	var code: String = str(d.get("code", ""))
	var stripped: String = code.strip_edges()
	if stripped.is_empty():
		return "blank_separator"
	var first: String = str(d.get("first_line", ""))
	if first.begins_with("@") or first.begins_with("class_name") or first.begins_with("extends"):
		return "class_scaffold"
	if code.contains("func _enter_tree") or code.contains("host = get_parent"):
		return "host_binding"
	if code.contains("## @ace_condition") or code.contains("## @ace_expression"):
		return "exposed_getter_rawcode"
	if code.contains("## @ace_action"):
		return "exposed_action_rawcode"
	if code.contains("match ") and code.contains(":"):
		return "match_control_flow"
	if first.begins_with("func ") or first.begins_with("static func "):
		return "helper_func_body"
	if code.contains(" and ") or code.contains(" or ") or code.contains(" if ") or code.contains("velocity") or code.contains("lerp") or code.contains("move_toward"):
		return "numeric_or_expr_kernel"
	return "other_statements"


func _gather_gd(dir_path: String, into: Array[String]) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name: String = dir.get_next()
	while name != "":
		var full: String = "%s/%s" % [dir_path, name]
		if dir.current_is_dir():
			if not name.begins_with("."):
				_gather_gd(full, into)
		elif name.ends_with(".gd"):
			into.append(full)
		name = dir.get_next()
	dir.list_dir_end()


func _collect_raw(rows: Array, location: String, out: Array) -> void:
	for row: Variant in rows:
		if row is RawCodeRow:
			var code: String = (row as RawCodeRow).code
			var lines: PackedStringArray = code.split("\n")
			out.append({
				"pack_where": location,
				"first_line": lines[0] if lines.size() > 0 else "",
				"line_count": lines.size(),
				"lift_note": (row as RawCodeRow).lift_note,
				"code": code
			})
		elif row is EventRow:
			var er: EventRow = row as EventRow
			_collect_raw(er.actions, location + " › event", out)
			_collect_raw(er.sub_events, location + " › sub", out)
		elif row is EventGroup:
			var g: EventGroup = row as EventGroup
			_collect_raw(g.events if not g.events.is_empty() else g.rows, location + " › group", out)
