# Godot EventSheets - print the whole vocabulary as one sorted, stable text (dev tool).
#
# Every verb the project publishes - built-in descriptors and installed packs alike - one line each:
#
#     <provider>::<ace_id>  type  category  params  successor  template
#
# tab separated, sorted by key, with no counts, no timestamps and no machine paths anywhere in it.
# Two machines running this over the same tree print the same bytes, which is the whole point: the
# text is meant to be diffed.
#
# WHO REUSES THIS, AND WHY IT IS ONE TOOL. Two jobs ask the same question of the vocabulary:
#
#   * the pack update dialog derives its "what this version retires and adds" section by diffing the
#     installed pack's dump against the incoming version's - never by reading prose a pack author
#     wrote about their own release;
#   * the maintainability campaign's DESCRIPTOR-IDENTITY GATE reuses THIS EXACT TOOL AND FORMAT:
#     dump before a refactor, dump after, and any line that moved is a verb whose identity changed,
#     which is a frozen-contract break rather than a tidy-up.
#
# Neither may grow its own dumper. The format lives in EventForgeRegistryDump; this file is the
# command line over it.
#
# THE SECOND TEXT: `words`. The identity dump carries no wording at all - a reworded verb is the
# same verb, and a description typo fixed must not read to a user taking a pack update as a changed
# verb. That leaves a hole a gate has to close: a module rewritten in a terser form could keep every
# identity line and silently drop every description, and the plugin would compile the same code with
# every picker in it gone blank. `words` prints the wording as its own text, in the same shape, with
# its own format version. THE GATE IS BOTH TEXTS: a migrated module ships only when the identity dump
# AND the wording dump are byte-identical to the verbose form's.
#
# USAGE
#   "$GODOT" --headless --path . --script tools/dump_registry.gd
#   "$GODOT" --headless --path . --script tools/dump_registry.gd -- words
#   "$GODOT" --headless --path . --script tools/dump_registry.gd -- out=user://registry.txt
#   "$GODOT" --headless --path . --script tools/dump_registry.gd -- pack=platformer
#
# `out=` writes the text to a file instead of stdout (the redirect a shell would do, done here so
# the console binary's own banner lines cannot land in the file), and takes an absolute path as
# happily as a `user://` one - which is what the proof script uses, because two worktrees of this
# project share one `user://`. `pack=` narrows the dump to one folder under eventsheet_addons/,
# which is the version half of the update dialog's diff. The three combine.
@tool
extends SceneTree

const WORDING := preload("res://tools/registry_wording.gd")


func _init() -> void:
	var output_path: String = ""
	var pack_dir: String = ""
	var wording: bool = false
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("out="):
			output_path = argument.trim_prefix("out=")
		elif argument.begins_with("pack="):
			pack_dir = argument.trim_prefix("pack=")
		elif argument == "words":
			wording = true
	var dump: String = ""
	if pack_dir.is_empty():
		var catalog: Dictionary = EventForgeSuccessors.catalog()
		dump = WORDING.text(catalog) if wording else EventForgeRegistryDump.text(catalog)
	else:
		var script_path: String = EventSheetPackCatalog.main_script_for(pack_dir)
		if script_path.is_empty():
			print("no pack script under eventsheet_addons/%s" % pack_dir)
			quit(1)
			return
		dump = WORDING.for_script(script_path) if wording else EventForgeRegistryDump.for_script(script_path)
	# One verb per line, minus the header line, so a caller can gate on the count without parsing.
	var verbs: int = maxi(0, dump.strip_edges().split("\n").size() - 1)
	if output_path.is_empty():
		print(dump)
		print("verbs=%d" % verbs)
		quit(0)
		return
	var file: FileAccess = FileAccess.open(output_path, FileAccess.WRITE)
	if file == null:
		print("could not write %s" % output_path)
		quit(1)
		return
	file.store_string(dump)
	file.close()
	print("verbs=%d written=%s" % [verbs, output_path])
	quit(0)
