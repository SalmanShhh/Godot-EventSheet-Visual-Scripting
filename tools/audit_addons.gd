# One-shot audit: every behaviour pack's .gd must re-import as an event sheet and recompile to EXACTLY
# itself (the .gd IS the source of truth - there is no .tres). This is the lossless round-trip gate for
# all bundled packs: open .gd -> import_external -> recompile -> byte-identical to the shipped .gd.
@tool
extends SceneTree


func _init() -> void:
	var packs_dir: DirAccess = DirAccess.open("res://eventsheet_addons")
	packs_dir.list_dir_begin()
	var entry: String = packs_dir.get_next()
	var audited: int = 0
	var drifted: int = 0
	var failed: int = 0  # parse failures + missing pack scripts
	var verify_path: String = "user://_eventforge_audit_verify.gd"
	while not entry.is_empty():
		if packs_dir.current_is_dir() and not entry.begins_with("."):
			var folder: String = "res://eventsheet_addons/%s" % entry
			var script_path: String = _find_pack_script(folder)
			if script_path.is_empty():
				print("MISSING PACK SCRIPT: %s" % entry)
				failed += 1
			else:
				audited += 1
				var verdict: Dictionary = _audit_script(entry, script_path, verify_path)
				drifted += 1 if bool(verdict.get("drift", false)) else 0
				failed += 1 if bool(verdict.get("parse_fail", false)) else 0
		elif entry.ends_with(".gd"):
			# Root-level single-file packs (demo_health_addon.gd, demo_note_block.gd) hold the
			# same covenant as folder packs - the folder-only walk silently skipped them.
			audited += 1
			var root_verdict: Dictionary = _audit_script(entry, "res://eventsheet_addons/%s" % entry, verify_path)
			drifted += 1 if bool(root_verdict.get("drift", false)) else 0
			failed += 1 if bool(root_verdict.get("parse_fail", false)) else 0
		entry = packs_dir.get_next()
	if FileAccess.file_exists(verify_path):
		DirAccess.remove_absolute(verify_path)
	print("audited=%d drifted=%d" % [audited, drifted])
	# A red gate must FAIL the invocation: anything checking only the exit code (CI, shell
	# chains) used to see success even when packs drifted or failed to parse.
	quit(1 if drifted > 0 or failed > 0 else 0)


## One pack script's round-trip + parse verdict. The .gd is both the sheet and the runtime
## script: import it as a sheet, recompile, and confirm the output matches the file on disk.
## Compiles to a throwaway user:// path so the real pack is never rewritten by the audit.
## load() of the real script is the honest parse check (re-parsing the source text directly
## would false-positive on "hides a global class" - its class_name is already registered).
func _audit_script(label: String, script_path: String, verify_path: String) -> Dictionary:
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(script_path)
	var output: String = str(SheetCompiler.compile(sheet, verify_path).get("output", ""))
	var shipped: String = FileAccess.get_file_as_string(script_path)
	var verdict: Dictionary = {"drift": output != shipped, "parse_fail": load(script_path) == null}
	if bool(verdict["drift"]):
		print("DRIFT: %s (recompile differs from shipped .gd)" % label)
	if bool(verdict["parse_fail"]):
		print("PARSE FAIL: %s" % label)
	return verdict


## The single sheet script a pack folder ships (e.g. spring_behavior.gd, save_system_addon.gd). Skips
## .gd.uid (ends with .uid, not .gd) and any non-script files.
static func _find_pack_script(folder: String) -> String:
	var dir: DirAccess = DirAccess.open(folder)
	if dir == null:
		return ""
	dir.list_dir_begin()
	var inner: String = dir.get_next()
	while not inner.is_empty():
		if inner.ends_with(".gd"):
			return "%s/%s" % [folder, inner]
		inner = dir.get_next()
	return ""
