# Godot EventSheets - T9: INHERITANCE SHOWN AS ONE THING, and the word it is shown under.
#
# A `class_name` that other scripts `extends` is a base class. Godot has no view of that: to see
# which scripts extend Enemy, what they share, and whether the "enemy" group agrees with the Enemy
# class, a project has to be grepped. An event sheet has had one word for exactly this shape since
# forever - an object set that shares instance variables and behaviors - so the sheet shows the
# hierarchy as one entry: the base on top, the scripts that extend it as its members, the base's
# own variables and functions as what they share.
#
# THE WORD IS A SETTING. It is "Family" with Familiar Words on, "Base class" with it off, and "Kind"
# or anything else the user types on the Words page. The words themselves live in the one registry
# that page reads; this file only asks it, and adds the PLURAL, which is the form the Object bar's
# section and the head bar's folder need. Every user-facing use goes through `word()` / `plural()`
# here, so the section, the folder, the object page, the Doctor and the Manual change together.
#
# Everything here READS: the project's own class list and the sheet's own lines. Nothing is written,
# nothing is cached across a project scan, and no answer here can change what a sheet emits.
@tool
class_name EventSheetFamilyFacts
extends RefCounted

## The Words page's key for this one. The words themselves - the default with Familiar Words on, the
## default with it off, and the extra choices - live in that one registry, so this file never states
## a word of its own.
const WORD_KEY := "inheritance_set"


## What an inheritance set is CALLED, in one place. `familiar_words` is the sheet's own glossary
## switch; a word the user pinned on the Words page wins over both.
##
## Never assembled from pieces at a call site: a caller that wants "FAMILIES" asks `section_title`,
## and a caller that wants "families" asks `plural`, so a user who typed "Kind" gets "KINDS" and
## "kinds" without anything having to know how their word pluralises.
static func word(familiar_words: bool) -> String:
	return EventSheetWords.word_for(WORD_KEY, familiar_words, EventSheetWords.overrides())


## The same word for more than one of them. Both shipped words have a translated plural of their own;
## a word the user typed themselves is pluralised the plain English way, which is the only rule
## available for a word nobody translated.
static func plural(familiar_words: bool) -> String:
	var one: String = word(familiar_words)
	if one == EventSheetWords.familiar_default(WORD_KEY):
		return EventSheetL10n.translate("Families")
	if one == EventSheetWords.plain_default(WORD_KEY):
		return EventSheetL10n.translate("Base classes")
	if one.ends_with("s") or one.ends_with("x") or one.ends_with("ch") or one.ends_with("sh"):
		return "%ses" % one
	if one.ends_with("y") and one.length() > 1:
		return "%sies" % one.substr(0, one.length() - 1)
	return "%ss" % one


## The Object bar's section heading, which the bar draws in capitals the way its siblings are drawn.
static func section_title(familiar_words: bool) -> String:
	return plural(familiar_words).to_upper()


## Every inheritance set the PROJECT declares, as {base class name: {members, path}}:
##
##   members  the class names that extend it, directly or through another of its members
##   path     the script the base itself lives in
##
## Read from Godot's own global class list, which already carries each class's one-step `extends`;
## the chains are closed here so a Slime that extends a Crawler that extends an Enemy is one of the
## Enemy set's members, exactly as it is at runtime. A class nothing extends is not a set and is
## absent, because a base class with no subclasses is just a class.
static func project_families() -> Dictionary:
	var bases: Dictionary = {}
	var paths: Dictionary = {}
	for entry: Variant in ProjectSettings.get_global_class_list():
		var record: Dictionary = entry
		var class_text: String = str(record.get("class", "")).strip_edges()
		if class_text.is_empty():
			continue
		paths[class_text] = str(record.get("path", ""))
		bases[class_text] = str(record.get("base", "")).strip_edges()
	var families: Dictionary = {}
	for class_text: String in bases:
		# Walk up the chain rather than one step, so every ancestor counts this class as a member.
		# The guard is the class count: a cycle cannot happen in a valid project, and a corrupt list
		# must not spin the editor.
		var walked: int = 0
		var ancestor: String = str(bases[class_text])
		while not ancestor.is_empty() and bases.has(ancestor) and walked < bases.size():
			walked += 1
			if not families.has(ancestor):
				families[ancestor] = {"members": PackedStringArray(), "path": str(paths.get(ancestor, ""))}
			var members: PackedStringArray = (families[ancestor] as Dictionary)["members"]
			if not members.has(class_text):
				members.append(class_text)
			(families[ancestor] as Dictionary)["members"] = members
			ancestor = str(bases[ancestor])
	for base: String in families:
		var sorted: PackedStringArray = (families[base] as Dictionary)["members"]
		sorted.sort()
		(families[base] as Dictionary)["members"] = sorted
	return families


## Whether a Godot GROUP of the same name agrees with an inheritance set, as
## {matches, strays} - `strays` the group members that do NOT extend the base, which is the one
## thing worth saying out loud: a node in the "enemy" group that is not an Enemy is where an
## "Invalid call" at runtime comes from.
##
## `group_members` is what the caller already knows about the group (the scenes' own node classes);
## nothing here opens a scene, because the caller that has them has already paid for that walk.
static func group_agreement(base: String, members: PackedStringArray,
		group_members: PackedStringArray) -> Dictionary:
	var strays: PackedStringArray = PackedStringArray()
	for candidate: String in group_members:
		var name_text: String = candidate.strip_edges()
		if name_text.is_empty() or name_text == base or members.has(name_text):
			continue
		strays.append(name_text)
	return {"matches": strays.is_empty(), "strays": strays}


## The one line the Doctor says when a group and its inheritance set disagree, in the project's own
## word for the set. One sentence per stray, because each one is its own fix.
static func stray_message(base: String, group: String, stray: String, familiar_words: bool) -> String:
	return "%s is in the group \"%s\" but does not extend %s (the %s the group is named after)." % [
		stray, group, base, word(familiar_words).to_lower()]
