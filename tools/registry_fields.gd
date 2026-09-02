# Godot EventSheets - THE VOCABULARY'S PICKER FIELDS AS ONE SORTED TEXT (dev tool).
#
# The third of the four texts a vocabulary-touching refactor has to reproduce, and the one that
# watches the half of a verb neither of the first two can see.
#
#   IDENTITY  (EventForgeRegistryDump)  what a verb EMITS - key, type, shelf, parameters with their
#                                       types and defaults, forwarding address, template.
#   WORDING   (registry_wording.gd)     what a verb SAYS - name, description, reads-as, and every
#                                       parameter's label and description.
#   FIELDS    (this file)               what a verb OFFERS - the dropdown behind a parameter, the
#                                       suggestions it filters, whether a blank is an answer, the
#                                       lens the canvas reads its value through, and the descriptor's
#                                       own picker facts: the node type it belongs to, the signal it
#                                       listens for, what it returns, and the three flags that decide
#                                       whether it is highlighted, built from the open project, or
#                                       hidden as retired.
#
# WHY IT NEEDED A TEXT OF ITS OWN. Not one field here changes an emitted byte, so putting any of them
# on the identity line would report a picker tidy-up as a frozen-contract break. Every one of them
# decides what a person is handed when they open the row. A migration that dropped `options` off a
# comparison parameter, flipped `required` to false, or forgot `.project_scoped()` on a dial verb
# left both older texts reading `same` while the editor in front of a user quietly lost a dropdown,
# stopped refusing a blank, or started asking for a shader parameter name to be typed by hand. That
# is the blind spot this closes.
#
# THE LINE
#
#     <provider>::<ace_id>  node_type  signal_name  return_type  flags  parameter fields
#
# tab separated, sorted by key, with its own format version - the same properties that make the other
# two diffable, for the same reason. `flags` is the subset of `featured`, `project_scoped` and
# `deprecated` that is true, always in that order. A parameter's fields are
# `id=hint;options;autocomplete;lens;option_labels;required`, comma separated, in the descriptor's
# own parameter order; `options` is `key=label` pairs joined by `|`, with the bare key where key and
# label are one word.
#
# A SEPARATOR IS NOT A PARSER HERE. A dropdown label containing a comma is written as it stands
# rather than escaped a second time, because this text is COMPARED and never parsed back: any byte
# that moves moves the line, whichever field it was in. The ambiguity can make a diff harder to read;
# it cannot hide a change, which is the only property the gate depends on.
#
# WHERE THE FACTS COME FROM. `EventForgeSuccessors.catalog()` - the one reduction that has already
# put the built-in descriptors and the installed packs into the same shape. No second reflection
# pass: a second pass is a second answer waiting to disagree with the first.
#
# THIS LIVES IN tools/ because the shipped plugin has no caller for it, exactly as the wording dump
# does. The identity dump ships because the pack update dialog reads it in front of a user.
@tool
extends RefCounted

## Bumped only when the LINE SHAPE changes, so an old text kept beside a project cannot quietly
## report every verb as re-fielded. Independent of the other two dumps' versions: the three texts
## change for three different reasons.
const FORMAT_VERSION: int = 1

## The one line that is not a verb. Comment-led, so a diff can skip it without a special case.
const HEADER: String = "# eventsheets fields dump %d" % FORMAT_VERSION

## Between fields. A tab, because an option label is full of everything else.
const SEPARATOR: String = "\t"

## The fields of a line, in order, named so a reader and a test spell them the same way.
const FIELDS: PackedStringArray = ["key", "node_type", "signal_name", "return_type", "flags",
	"params"]

## The descriptor flags this text carries, each as {entry key: word}. A table rather than three
## branches, so the order they print in is stated once and cannot drift between two readers.
const FLAGS: Array[Dictionary] = [
	{"key": "is_featured", "word": "featured"},
	{"key": "is_project_scoped", "word": "project_scoped"},
	{"key": "is_deprecated", "word": "deprecated"},
]


## The whole vocabulary's picker fields as one text. `catalog` is the `EventForgeSuccessors.catalog()`
## shape, so a caller that already holds one does not build a second.
static func text(catalog: Dictionary) -> String:
	var keys: PackedStringArray = PackedStringArray()
	for key: Variant in catalog.keys():
		keys.append(str(key))
	keys.sort()
	var lines: PackedStringArray = PackedStringArray([HEADER])
	for key: String in keys:
		var entry: Variant = catalog[key]
		if entry is Dictionary:
			lines.append(line_for(key, entry))
	return "\n".join(lines) + "\n"


## One verb's fields line. Pure over its arguments, so a test pins the format without a registry.
static func line_for(key: String, entry: Dictionary) -> String:
	var fields: PackedStringArray = PackedStringArray([
		EventForgeRegistryDump.escape_field(key),
		EventForgeRegistryDump.escape_field(str(entry.get("node_type", ""))),
		EventForgeRegistryDump.escape_field(str(entry.get("signal_name", ""))),
		EventForgeRegistryDump.escape_field(type_string(int(entry.get("return_type", TYPE_NIL)))),
		EventForgeRegistryDump.escape_field(flags_of(entry)),
		EventForgeRegistryDump.escape_field(params_of(entry)),
	])
	return SEPARATOR.join(fields)


## The true flags, in the order FLAGS names them, joined by `|`. Empty when a verb is an ordinary
## one - which is most of them, and reads better than three spelled-out falses.
static func flags_of(entry: Dictionary) -> String:
	var raised: PackedStringArray = PackedStringArray()
	for flag: Dictionary in FLAGS:
		if bool(entry.get(str(flag["key"]), false)):
			raised.append(str(flag["word"]))
	return "|".join(raised)


## Every parameter's fields, comma separated, in the descriptor's own parameter order. That order is
## never sorted: a reordered parameter list is a different row to fill in, and the identity dump
## already says so - this text agreeing with it is what makes the pair readable together.
static func params_of(entry: Dictionary) -> String:
	var hints: Dictionary = entry.get("declared_hints", {})
	var options: Dictionary = entry.get("declared_options", {})
	var autocomplete: Dictionary = entry.get("declared_autocomplete", {})
	var lenses: Dictionary = entry.get("declared_lenses", {})
	var option_labels: Dictionary = entry.get("declared_option_labels", {})
	var required: Dictionary = entry.get("declared_required", {})
	var spelled: PackedStringArray = PackedStringArray()
	for param: String in PackedStringArray(entry.get("params", PackedStringArray())):
		spelled.append("%s=%s;%s;%s;%s;%s;%s" % [
			param,
			str(hints.get(param, "")),
			str(options.get(param, "")),
			str(autocomplete.get(param, "")),
			str(lenses.get(param, "")),
			"labels" if bool(option_labels.get(param, false)) else "",
			"required" if bool(required.get(param, false)) else "",
		])
	return ",".join(spelled)


## The picker fields of the verbs ONE pack script publishes, so a pack version that is not installed
## can be read the same way the update dialog reads its identity.
static func for_script(script_path: String) -> String:
	return text(EventForgeRegistryDump.entries_of_script(script_path))


## True when a text was written by this format version - the one thing a comparison checks before it
## reports anything, because a shape change would otherwise read as "every verb re-fielded".
static func is_current_format(dump_text: String) -> bool:
	return dump_text.begins_with(HEADER)
