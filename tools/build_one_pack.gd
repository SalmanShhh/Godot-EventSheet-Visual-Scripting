# Rebuilds ONE pack (or a few named ones) from tools/pack_builders/<name>.gd, so a change to a
# single builder does not have to regenerate all of them. Same code path as
# tools/build_sample_behaviors.gd - it just calls fewer builders. Run:
#   godot --headless --path . --script tools/build_one_pack.gd -- screen_fx post_kit
@tool
extends SceneTree

const BUILDERS_DIR := "res://tools/pack_builders/"


func _init() -> void:
	var wanted: PackedStringArray = PackedStringArray()
	for argument: String in OS.get_cmdline_user_args():
		if not argument.strip_edges().is_empty():
			wanted.append(argument.strip_edges())
	if wanted.is_empty():
		push_error("[build_one_pack] name at least one pack builder after --")
		quit(1)
		return
	var ok: bool = true
	for builder_name: String in wanted:
		var builder: GDScript = load(BUILDERS_DIR + builder_name + ".gd")
		if builder == null or not builder.has_method("build"):
			push_error("[build_one_pack] no builder called %s" % builder_name)
			ok = false
			continue
		ok = bool(builder.call("build")) and ok
		print("[build_one_pack] built %s" % builder_name)
	if not ok:
		push_error("[build_one_pack] one or more packs failed - see errors above.")
		quit(1)
		return
	quit(0)
