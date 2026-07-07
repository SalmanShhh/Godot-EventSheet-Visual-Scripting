# Regenerates every bundled pack (eventsheet_addons/) from its per-pack builder in
# tools/pack_builders/. Builders are AUTO-DISCOVERED: every *.gd in that folder that is not a
# shared helper (a leading underscore, e.g. _lib.gd) is loaded and its `static func build()` is
# called - drop a new <name>.gd with a build() and it registers itself, no list to edit (the same
# zero-config discovery the helper ACE modules use). Files are built in sorted order so a rebuild
# is deterministic. Run:
#   godot --headless --path . --script tools/build_sample_behaviors.gd
# Faithfulness gate: tools/audit_addons.gd must report drifted=0 afterwards.
@tool
extends SceneTree

const BUILDERS_DIR := "res://tools/pack_builders/"


func _init() -> void:
	var ok: bool = true
	var built: int = 0
	for builder_name: String in _discover_builders():
		var builder: GDScript = load(BUILDERS_DIR + builder_name + ".gd")
		if builder == null:
			push_error("[build_sample_behaviors] could not load %s" % builder_name)
			ok = false
			continue
		if not builder.has_method("build"):
			# A non-helper file that is not a pack builder - skip it rather than crash the build.
			print("[build_sample_behaviors] %s has no build() - skipped" % builder_name)
			continue
		ok = bool(builder.call("build")) and ok
		built += 1
	print("[build_sample_behaviors] built %d packs" % built)
	if not ok:
		push_error("[build_sample_behaviors] one or more packs failed - see errors above.")
	quit()


## Every pack builder in tools/pack_builders/, sorted for a deterministic build. A leading
## underscore marks a shared helper (_lib.gd), not a pack, so those are skipped.
static func _discover_builders() -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	var dir: DirAccess = DirAccess.open(BUILDERS_DIR)
	if dir == null:
		push_error("[build_sample_behaviors] cannot open %s" % BUILDERS_DIR)
		return names
	for file_name: String in dir.get_files():
		if not file_name.ends_with(".gd") or file_name.begins_with("_"):
			continue
		names.append(file_name.get_basename())
	names.sort()
	return names
