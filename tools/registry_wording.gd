# Godot EventSheets - THE VOCABULARY'S WORDS AS ONE SORTED TEXT (dev tool).
#
# The second of the two texts a vocabulary-touching refactor has to reproduce. The first,
# `EventForgeRegistryDump`, is the verb's IDENTITY - key, type, shelf, parameters with their types
# and defaults, forwarding address, emitted template - and it deliberately carries no wording at
# all, because a reworded verb is the same verb and the pack update dialog diffs that text to say
# what a version retires. Growing it would make every typo fixed in a description read to a user as
# a changed verb.
#
# So the words get a text of their own, in the same shape and with the same escaping:
#
#     <provider>::<ace_id>  name  description  reads-as  param wording
#
# tab separated, sorted by key, no counts, no timestamps, no machine paths - the same properties
# that make the identity dump diffable, for the same reason.
#
# WHY IT EXISTS. A module rewritten in a terser form is only proved unchanged when BOTH texts are
# byte-identical to the verbose form's: the identity dump alone would sign off a migration that
# silently dropped every description, and the plugin would go on compiling exactly the same code
# while every picker in it went blank. The two texts together are the descriptor-identity gate.
#
# THE PARAMETER FIELD is `id=label|description`, comma separated, in the descriptor's own parameter
# order. The id is on the line so a reordered or renamed parameter shows here as well as in the
# identity dump - one of the two texts alone can be misread, and the pair cannot.
#
# WHERE THE WORDS COME FROM. `EventForgeSuccessors.catalog()` - the one reduction that has already
# put the built-in descriptors and the installed packs into the same shape. This file opens no
# second reflection pass; a second pass is a second answer waiting to disagree with the first.
#
# THIS LIVES IN tools/ because the shipped plugin has no caller for it. The identity dump ships
# because the pack update dialog reads it in front of a user; this one is read by a command line
# and its own test.
@tool
extends RefCounted

## Bumped only when the LINE SHAPE changes, so an old text kept beside a project cannot quietly
## report every verb as reworded. Independent of the identity dump's version: the two texts change
## for different reasons.
const FORMAT_VERSION: int = 1

## The one line that is not a verb. Comment-led, so a diff can skip it without a special case.
const HEADER: String = "# eventsheets wording dump %d" % FORMAT_VERSION

## Between fields. A tab, because a description is full of commas and pipes.
const SEPARATOR: String = "\t"

## The fields of a line, in order, named so a reader and a test spell them the same way.
const FIELDS: PackedStringArray = ["key", "name", "description", "reads_as", "params"]


## The whole vocabulary's wording as one text. `catalog` is the `EventForgeSuccessors.catalog()`
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


## One verb's wording line. Pure over its arguments, so a test pins the format without a registry.
static func line_for(key: String, entry: Dictionary) -> String:
	var labels: Dictionary = entry.get("declared_labels", {})
	var descriptions: Dictionary = entry.get("declared_descriptions", {})
	var params: PackedStringArray = PackedStringArray()
	for param: String in PackedStringArray(entry.get("params", PackedStringArray())):
		params.append("%s=%s|%s" % [param, str(labels.get(param, "")), str(descriptions.get(param, ""))])
	var fields: PackedStringArray = PackedStringArray([
		EventForgeRegistryDump.escape_field(key),
		EventForgeRegistryDump.escape_field(str(entry.get("name", ""))),
		EventForgeRegistryDump.escape_field(str(entry.get("description", ""))),
		EventForgeRegistryDump.escape_field(str(entry.get("display_template", ""))),
		EventForgeRegistryDump.escape_field(",".join(params)),
	])
	return SEPARATOR.join(fields)


## The wording of the verbs ONE pack script publishes, so a pack version that is not installed can
## be read the same way the update dialog reads its identity.
static func for_script(script_path: String) -> String:
	return text(EventForgeRegistryDump.entries_of_script(script_path))


## True when a text was written by this format version - the one thing a comparison checks before it
## reports anything, because a shape change would otherwise read as "every verb reworded".
static func is_current_format(dump_text: String) -> bool:
	return dump_text.begins_with(HEADER)
