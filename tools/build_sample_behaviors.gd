# Regenerates every bundled pack (eventsheet_addons/) from its per-pack builder in
# tools/pack_builders/. Builders are AUTO-DISCOVERED: every *.gd in that folder that is not a
# shared helper (a leading underscore, e.g. _lib.gd) is loaded and its `static func build()` is
# called - drop a new <name>.gd with a build() and it registers itself, no list to edit (the same
# zero-config discovery the helper ACE modules use). Files are built in sorted order so a rebuild
# is deterministic. Run:
#   godot --headless --path . --script tools/build_sample_behaviors.gd
# Faithfulness gate: tools/audit_addons.gd must report drifted=0 afterwards.
#
# The committed `.uid` sidecars are KEPT: a build never writes, rewrites or removes one (a
# regenerated pack keeps its identity), and one that changed anyway is put back and fails the build.
# A brand-new pack's script has no sidecar until the next import writes it - the build names it.
@tool
extends SceneTree

const BUILDERS_DIR := "res://tools/pack_builders/"

const UID_SIDECARS := preload("res://tools/uid_sidecars.gd")

## The trees a build writes into, whose sidecars it must leave exactly as it found them.
const BUILT_TREES: PackedStringArray = ["res://eventsheet_addons", "res://tools/pack_builders"]


func _init() -> void:
	var ok: bool = true
	var built: int = 0
	var sidecars: Dictionary = UID_SIDECARS.snapshot(BUILT_TREES)
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
	for path: String in UID_SIDECARS.changed_since(sidecars):
		push_error("[build_sample_behaviors] the build changed %s - put back as it was" % path)
		ok = false
	for path: String in UID_SIDECARS.missing("res://eventsheet_addons"):
		print("[build_sample_behaviors] %s has no .uid yet: %s" % [path, UID_SIDECARS.FIX])
	if not ok:
		# EXIT 1, because a build that pushed an error and then exited 0 is a build a script
		# believed. A pack that failed here is one whose body the assembler could not make -
		# nothing downstream (the drift gate included) reports that for a pack not yet committed.
		push_error("[build_sample_behaviors] one or more packs failed - see errors above.")
		quit(1)
		return
	quit(0)


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
