# EventSheet - which Inspector section each exported member of an opened script sits in, read the way
# the Inspector itself reads the file.
#
# Godot's grouping is positional: `@export_category`, `@export_group` and `@export_subgroup` each
# open a section that every later exported property joins until another line closes it. Two rules
# make that more than "carry the name forward", and both are the Inspector's own:
#
#   - A PREFIX group (`@export_group("Bullet", "bullet")`) only takes names that start with its
#     prefix. The first exported name that does not closes the group, so `health` written right under
#     `bullet_speed` sits outside it - and stays outside, as does everything after it.
#   - An EMPTY name ends the section: `@export_group("")` closes the open group (and its subgroup),
#     `@export_subgroup("")` only the subgroup. A category closes both.
#
# The section lines arrive two ways and both are read: as attributes the importer lifted onto the
# member they precede (`category`, `group`, `subgroup`), and as script lines the lift left as they
# were - a block whose every line is a section annotation. PURE and STATIC apart from the small walk
# state below: no viewport, no theme, so every rule here is testable headless.
@tool
extends RefCounted

const CATEGORY := "category"
const GROUP := "group"
const SUBGROUP := "subgroup"

## One section annotation, the whole line: its kind, its name and the optional prefix argument.
const LINE_PATTERN := "^@export_(category|group|subgroup)\\(\\s*\"((?:[^\"\\\\]|\\\\.)*)\"\\s*(?:,\\s*\"((?:[^\"\\\\]|\\\\.)*)\"\\s*)?\\)$"

static var _line_regex: RegEx = null

## The open sections, as the walk below leaves them after each member.
var category: String = ""
var group: String = ""
var group_prefix: String = ""
var subgroup: String = ""
var subgroup_prefix: String = ""


## The section a line declares, {kind, name, prefix}, or {} when the line is anything else. A
## category takes no prefix, so a second argument on one is not a line this reads.
static func parse_line(line: String) -> Dictionary:
	if _line_regex == null:
		_line_regex = RegEx.create_from_string(LINE_PATTERN)
	var found: RegExMatch = _line_regex.search(line.strip_edges())
	if found == null:
		return {}
	var prefix: String = found.get_string(3) if found.get_group_count() >= 3 else ""
	if found.get_string(1) == CATEGORY and not prefix.is_empty():
		return {}
	return {"kind": found.get_string(1), "name": found.get_string(2), "prefix": prefix}


## Every section a script block declares, in order, or [] unless EVERY non-blank line of it is one -
## a block that also holds code is code, and reads as code.
static func parse_block(code: String) -> Array[Dictionary]:
	var sections: Array[Dictionary] = []
	for line: String in code.split("\n"):
		if line.strip_edges().is_empty():
			continue
		var section: Dictionary = parse_line(line)
		if section.is_empty():
			return [] as Array[Dictionary]
		sections.append(section)
	return sections


## The sections the importer lifted onto a member, in the order the file wrote them.
static func from_attributes(attributes: Variant) -> Array[Dictionary]:
	var sections: Array[Dictionary] = []
	if not (attributes is Dictionary):
		return sections
	for kind: String in [CATEGORY, GROUP, SUBGROUP]:
		var name: String = str((attributes as Dictionary).get(kind, "")).strip_edges()
		if not name.is_empty():
			sections.append({"kind": kind, "name": name, "prefix": ""})
	return sections


## Opens (or, with an empty name, closes) the section one line declares.
func enter(section: Dictionary) -> void:
	var name: String = str(section.get("name", ""))
	var prefix: String = str(section.get("prefix", ""))
	match str(section.get("kind", "")):
		CATEGORY:
			category = name
			_close_group()
		GROUP:
			_close_group()
			group = name
			group_prefix = prefix if not name.is_empty() else ""
		SUBGROUP:
			subgroup = name if not group.is_empty() else ""
			subgroup_prefix = prefix if not subgroup.is_empty() else ""


## Places one exported member: closes whatever its name does not fit (the Inspector's prefix rule,
## subgroup first) and returns what it shut it out of - {group, prefix} - or {} when nothing did.
func place(member_name: String) -> Dictionary:
	if not subgroup.is_empty() and not _fits(member_name, subgroup_prefix):
		subgroup = ""
		subgroup_prefix = ""
	if not group.is_empty() and subgroup.is_empty() and not _fits(member_name, group_prefix):
		var shut: Dictionary = {"group": group, "prefix": group_prefix}
		_close_group()
		return shut
	return {}


## Forgets every open section - the declarations have ended.
func reset() -> void:
	category = ""
	_close_group()


func _close_group() -> void:
	group = ""
	group_prefix = ""
	subgroup = ""
	subgroup_prefix = ""


## The Inspector's own test: a name fits a prefix it starts with, and also a prefix that starts with
## the whole name (`bullet` under `bullet_`), which the Inspector keeps on purpose.
static func _fits(member_name: String, prefix: String) -> bool:
	return prefix.is_empty() or member_name.begins_with(prefix) or prefix.begins_with(member_name)


## The line that declares a section, as the file writes it - the last line of each hover.
static func code_line(kind: String, name: String, prefix: String = "") -> String:
	if prefix.is_empty():
		return "@export_%s(\"%s\")" % [kind, name]
	return "@export_%s(\"%s\", \"%s\")" % [kind, name, prefix]


## A section head's hover: what kind of section it is, what that means in the Inspector, what it
## holds and the line that declares it. Said only on the head's NAME, never across the row.
static func head_hover(kind: String, name: String, prefix: String, parent: String, holds: String) -> String:
	var lines := PackedStringArray()
	match kind:
		CATEGORY:
			lines.append(EventSheetL10n.translate("%s - a category") % name)
			lines.append(EventSheetL10n.translate("A heavy band in the Inspector that starts a new chapter of properties."))
		SUBGROUP:
			lines.append(EventSheetL10n.translate("%s - a subgroup of %s") % [name, parent])
			lines.append(EventSheetL10n.translate("A folder inside the %s folder in the Inspector.") % parent)
		_:
			if prefix.is_empty():
				lines.append(EventSheetL10n.translate("%s - an export group") % name)
				lines.append(EventSheetL10n.translate("The exported variables under it share one folder in the Inspector, until the group ends."))
			else:
				lines.append(EventSheetL10n.translate("%s - a prefix group") % name)
				lines.append(EventSheetL10n.translate("Only variables whose names start with %s join it; the Inspector shows them without that start.") % prefix)
	if not holds.is_empty():
		lines.append(holds)
	lines.append(code_line(kind, name, prefix))
	return "\n".join(lines)


## What a head holds, in words: "2 variables", "1 variable · 1 subgroup".
static func holds_text(variables: int, subgroups: int) -> String:
	var parts := PackedStringArray()
	if variables > 0:
		parts.append(EventSheetL10n.translate("1 variable") if variables == 1
			else EventSheetL10n.translate("%d variables") % variables)
	if subgroups > 0:
		parts.append(EventSheetL10n.translate("1 subgroup") if subgroups == 1
			else EventSheetL10n.translate("%d subgroups") % subgroups)
	return " · ".join(parts)


## The help strip's sentence for a member a prefix group shut out: the row itself never says it.
static func outside_note(shut: Dictionary) -> String:
	return EventSheetL10n.translate("Not in %s: that group only takes names starting %s.") % [
		str(shut.get("group", "")), str(shut.get("prefix", ""))]


## The words on an explicit end line.
static func end_text(name: String) -> String:
	return EventSheetL10n.translate("%s ends here") % name
