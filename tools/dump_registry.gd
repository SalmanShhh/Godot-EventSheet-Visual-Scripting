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
# THE OTHER THREE TEXTS. `words`, `fields` and `order` each answer a question this one deliberately
# does not, and THE GATE IS ALL FOUR: a migrated module ships only when every one of them is
# byte-identical to the verbose form's.
#
# THE SECOND TEXT: `words`. The identity dump carries no wording at all - a reworded verb is the
# same verb, and a description typo fixed must not read to a user taking a pack update as a changed
# verb. That leaves a hole a gate has to close: a module rewritten in a terser form could keep every
# identity line and silently drop every description, and the plugin would compile the same code with
# every picker in it gone blank. `words` prints the wording as its own text, in the same shape, with
# its own format version.
#
# THE THIRD TEXT: `fields`. Identity and wording between them still say nothing about what a verb
# OFFERS - the dropdown behind a parameter, the suggestions it filters, whether a blank is an answer,
# the lens the canvas reads a value through, the node type a row belongs to, the signal it listens
# for, and whether it is featured, built from the open project, or retired. None of that moves an
# emitted byte, so none of it belongs on the identity line; all of it decides what a person is handed
# when they open the row. A migration that dropped a comparison parameter's options left both older
# texts reading `same` while a dropdown quietly went away.
#
# THE FOURTH TEXT: `order`. The three above are each SORTED BY KEY, which is what makes them diffable
# and also what makes them structurally blind to the one thing sorting destroys. Registration order
# decides which of two verbs sharing an id shadows the other in the picker index, and it is the
# reverse-lifter's TIE-BREAK: the lifter takes the first entry whose template matches, its index is
# sorted by literal-character count, and equal specificity is settled by registration order alone. A
# refactor that split a module in three could move which row a hand-written line reads back as -
# identical bytes, a different sentence - with all three sorted texts reporting `same`. `order` is
# the unsorted text that sees it. Being a property of the whole registry, it takes no `pack=`.
#
# USAGE
#   "$GODOT" --headless --path . --script tools/dump_registry.gd
#   "$GODOT" --headless --path . --script tools/dump_registry.gd -- words
#   "$GODOT" --headless --path . --script tools/dump_registry.gd -- fields
#   "$GODOT" --headless --path . --script tools/dump_registry.gd -- order
#   "$GODOT" --headless --path . --script tools/dump_registry.gd -- out=user://registry.txt
#   "$GODOT" --headless --path . --script tools/dump_registry.gd -- pack=platformer
#
# `out=` writes the text to a file instead of stdout (the redirect a shell would do, done here so
# the console binary's own banner lines cannot land in the file), and takes an absolute path as
# happily as a `user://` one - which is what the proof script uses, because two worktrees of this
# project share one `user://`. `pack=` narrows the dump to one folder under eventsheet_addons/,
# which is the version half of the update dialog's diff, and combines with the first three texts.
# `words`, `fields` and `order` are exclusive of one another - each names WHICH text to write, and
# asking for two at once would silently write one of them.
@tool
extends SceneTree

const WORDING := preload("res://tools/registry_wording.gd")
const PICKER_FIELDS := preload("res://tools/registry_fields.gd")
const ORDER := preload("res://tools/registry_order.gd")


func _init() -> void:
	var output_path: String = ""
	var pack_dir: String = ""
	# WHICH of the four texts, as one word rather than three booleans - the four are exclusive, and a
	# set of flags is a shape in which "words and fields at once" is expressible and meaningless.
	var which: String = "registry"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("out="):
			output_path = argument.trim_prefix("out=")
		elif argument.begins_with("pack="):
			pack_dir = argument.trim_prefix("pack=")
		elif argument in ["words", "fields", "order"]:
			which = argument
	var dump: String = ""
	if which == "order":
		# The order text is a property of the whole registry - which module registered first, and how
		# the lifter's index came out of the specificity sort. One pack's file has no such property,
		# so asking for one is a question with no answer rather than an empty text to diff.
		if not pack_dir.is_empty():
			print("order is a whole-registry text and takes no pack=")
			quit(1)
			return
		dump = ORDER.text()
	elif pack_dir.is_empty():
		var catalog: Dictionary = EventForgeSuccessors.catalog()
		dump = _whole_text(which, catalog)
	else:
		var script_path: String = EventSheetPackCatalog.main_script_for(pack_dir)
		if script_path.is_empty():
			print("no pack script under eventsheet_addons/%s" % pack_dir)
			quit(1)
			return
		dump = _pack_text(which, script_path)
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


## One of the three sorted texts over the whole vocabulary, chosen by name. The catalog is built once
## by the caller and handed to whichever formatter is asked for, so no text opens a second reflection
## pass over a vocabulary another text already read.
func _whole_text(which: String, catalog: Dictionary) -> String:
	match which:
		"words":
			return WORDING.text(catalog)
		"fields":
			return PICKER_FIELDS.text(catalog)
		_:
			return EventForgeRegistryDump.text(catalog)


## The same three, narrowed to one pack's own script - the version half of the update dialog's diff.
func _pack_text(which: String, script_path: String) -> String:
	match which:
		"words":
			return WORDING.for_script(script_path)
		"fields":
			return PICKER_FIELDS.for_script(script_path)
		_:
			return EventForgeRegistryDump.for_script(script_path)
