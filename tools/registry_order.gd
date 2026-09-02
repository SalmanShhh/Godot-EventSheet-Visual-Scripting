# Godot EventSheets - THE VOCABULARY'S ORDER AS ONE TEXT (dev tool).
#
# The fourth of the four texts a vocabulary-touching refactor has to reproduce, and the only one that
# is NOT sorted. That is the whole point of it.
#
# THE OTHER THREE ARE STRUCTURALLY BLIND TO ORDER. Identity, wording and fields are each sorted by
# key so that two machines print the same bytes and a diff is a line diff. A refactor that splits one
# registration module into three, or moves a verb from the bottom of a list to the top, changes the
# SEQUENCE the vocabulary is registered in and moves not one byte of any of them. For most of the
# plugin that is correct - a picker files verbs by shelf, and nothing downstream cares which was
# appended first.
#
# TWO THINGS CARE, AND BOTH DECIDE WHAT A USER'S FILE READS AS.
#
#   THE DUPLICATE SHADOW. `ACERegistry` indexes builtins by `provider::ace_id` as it walks them, and
#   a later descriptor with a key an earlier one already took shadows the earlier one in the picker
#   index. Which of the two a person actually gets is decided by registration order alone.
#
#   THE REVERSE-LIFTER'S TIE-BREAK. The lifter reads a hand-written line BACK into a row by trying
#   its reverse index in order and taking the FIRST entry that matches. The index is sorted by how
#   many literal characters a template has, most first - and where two templates tie, the tie is
#   broken by `order`, which IS registration order. A dozen shipped comments in `ace_lifter.gd` turn
#   on exactly that: rows kept out of the index precisely because two verbs write one line and "the
#   row that shipped first keeps the reading". Reorder the modules and the other one starts keeping
#   it. The emitted bytes are identical; the SENTENCE a reader opens their file to is not.
#
# So the order is a fact worth a text of its own, and this is it.
#
# THE TEXT IS TWO SECTIONS, each headed by a comment line so a diff can skip the heading:
#
#   registration   <index>  <provider>::<ace_id>            every built-in descriptor, in the order
#                                                           `ACERegistry` walks and indexes them.
#   reverse        <index>  <provider>::<ace_id>  <kind>  <literal_len>
#                                                           the reverse index, in the exact order
#                                                           the lifter tries it - after the
#                                                           specificity sort, not before.
#
# `literal_len` rides along because it is what the sort is ON: a line that moved because a template
# gained a literal character reads differently in a diff from a line that moved because a module was
# reordered underneath it, and a gate that could not tell them apart would send a reader hunting.
#
# WHY THE REVERSE HALF IS THE POST-SORT ORDER. The lifter's own answer to "which row claims this
# line?" is a first-match walk over the sorted array. Dumping the pre-sort array would pin an
# intermediate nobody consults; dumping the sorted one pins the answer.
#
# WHAT IS NOT HERE. Packs. The registration half is the BUILT-IN sequence, because that is the one
# this repository's own refactors move; an installed pack's verbs arrive in whatever order the
# scanner found the files in, which is a property of somebody's project folder rather than of this
# tree. The reverse half is whatever the live registry holds, which in a headless run of this
# repository is the builtins plus the committed packs, identically on every machine.
@tool
extends RefCounted

## Bumped only when the LINE SHAPE changes, so an old text kept beside a project cannot quietly
## report every verb as reordered. Independent of the other three dumps' versions.
const FORMAT_VERSION: int = 1

## The one line that is not a record. Comment-led, like the other three dumps' headers.
const HEADER: String = "# eventsheets order dump %d" % FORMAT_VERSION

## Between fields. A tab, for the same reason the other three use one.
const SEPARATOR: String = "\t"

## The heading each section is written under, comment-led so a diff skips it the same way.
const REGISTRATION_HEADING: String = "# registration"
const REVERSE_HEADING: String = "# reverse"


## Both sections as one text. Reads the live registry and the live reverse index, so what it prints
## is what the plugin in this tree would actually do rather than what a table says it should.
static func text() -> String:
	var lines: PackedStringArray = PackedStringArray([HEADER, REGISTRATION_HEADING])
	lines.append_array(registration_lines(ACERegistry.get_builtin_descriptors()))
	lines.append(REVERSE_HEADING)
	lines.append_array(reverse_lines(EventSheetACELifter._build_reverse_entries()))
	return "\n".join(lines) + "\n"


## Every built-in descriptor as `<index>  <key>`, in the order given. Pure over its argument, so a
## test pins the format by handing it two descriptors rather than by booting a registry.
static func registration_lines(descriptors: Array) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	var index: int = 0
	for descriptor: ACEDescriptor in descriptors:
		if descriptor == null:
			continue
		var key: String = EventForgeSuccessors.key_of(descriptor.provider_id, descriptor.ace_id)
		lines.append(SEPARATOR.join(PackedStringArray([
			str(index),
			EventForgeRegistryDump.escape_field(key),
		])))
		index += 1
	return lines


## Every reverse-index entry as `<index>  <key>  <kind>  <literal_len>`, in the order given - which
## the caller has already taken from the lifter, sorted exactly as the lifter walks it.
static func reverse_lines(entries: Array) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	var index: int = 0
	for entry: Variant in entries:
		if not (entry is Dictionary):
			continue
		var record: Dictionary = entry
		var key: String = EventForgeSuccessors.key_of(str(record.get("provider", "")), str(record.get("ace_id", "")))
		lines.append(SEPARATOR.join(PackedStringArray([
			str(index),
			EventForgeRegistryDump.escape_field(key),
			EventForgeRegistryDump.escape_field(str(record.get("kind", ""))),
			str(int(record.get("literal_len", 0))),
		])))
		index += 1
	return lines


## True when a text was written by this format version - the one thing a comparison checks before it
## reports anything, because a shape change would otherwise read as "everything reordered".
static func is_current_format(dump_text: String) -> bool:
	return dump_text.begins_with(HEADER)
