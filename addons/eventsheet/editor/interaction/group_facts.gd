# EventSheet - the ONE place that answers questions about an event GROUP.
#
# A group is sheet structure: it holds rows, it can nest, it carries local variables, and it can be
# switched on and off. Everything a reader sees on a group head - its name, the counts at the right,
# the bracket down its body, the choices the Set Group Active dialog lists - is derived here so the
# row, the dialog, the pinned head and the tests can never answer the same question two ways.
#
# PURE + STATIC on purpose: no viewport, no theme, no display server. The geometry function takes a
# flat shape array (the same {group, indent, top, height} shape the breadcrumb's enclosure map takes)
# rather than the viewport's rows, so bracket placement is unit-testable headless.
@tool
class_name EventSheetGroupFacts
extends RefCounted

## How far in each nesting level draws its bracket, in px before display scaling. Nested groups sit
## 2px further in, so three levels read as three rules rather than one thick one.
const BRACKET_DEPTH_INSET: float = 2.0

## The bracket's own thickness, in px before display scaling.
const BRACKET_WIDTH: float = 2.0

## Where the outermost bracket starts. Rows are NEVER offset for a bracket, so this is a canvas
## inset, not an indent.
const BRACKET_LEFT: float = 3.0

## How many object names a folded head lists before it trails off.
const FOLDED_OBJECT_LIMIT: int = 3


## The rows a group holds, across the `events` / `rows` alias pair. The resource answers - the
## alias pair is a fact about EventGroup, not about the canvas.
static func children(group: EventGroup) -> Array[Resource]:
	return group.child_rows() if group != null else [] as Array[Resource]


## The name a group reads with, across the `name` / `group_name` alias pair.
static func display_name(group: EventGroup) -> String:
	return group.display_name() if group != null else "Group"


## What a group holds: direct child groups, events (recursive - a reader folding the outer group
## wants to know how much is under it, not how much sits at its first level), and its own locals.
static func counts(group: EventGroup) -> Dictionary:
	var tally := {"groups": 0, "events": 0, "locals": 0}
	if group == null:
		return tally
	for local_entry: Variant in group.local_variables:
		if local_entry is LocalVariable:
			tally["locals"] = int(tally["locals"]) + 1
	for child: Variant in children(group):
		if child is EventGroup:
			tally["groups"] = int(tally["groups"]) + 1
			tally["events"] = int(tally["events"]) + int(counts(child as EventGroup).get("events", 0))
		elif child is EventRow:
			tally["events"] = int(tally["events"]) + 1
	return tally


## The muted line at the right of a group head: what it holds, and - when it is folded - the objects
## inside it, so a reader can decide whether to open it without opening it. A group that is off says
## so first, because that is the fact that changes what the sheet does.
static func counts_text(group: EventGroup, object_labels: PackedStringArray = PackedStringArray()) -> String:
	if group == null:
		return ""
	var pieces: PackedStringArray = PackedStringArray()
	if not group.enabled:
		pieces.append(EventSheetL10n.translate("off"))
	var tally: Dictionary = counts(group)
	var group_count: int = int(tally.get("groups", 0))
	var event_count: int = int(tally.get("events", 0))
	var local_count: int = int(tally.get("locals", 0))
	if group_count > 0:
		pieces.append(EventSheetL10n.translate("1 group") if group_count == 1 \
			else EventSheetL10n.translate("%d groups") % group_count)
	if event_count > 0:
		pieces.append(EventSheetL10n.translate("1 event") if event_count == 1 \
			else EventSheetL10n.translate("%d events") % event_count)
	if local_count > 0:
		pieces.append(EventSheetL10n.translate("1 local") if local_count == 1 \
			else EventSheetL10n.translate("%d locals") % local_count)
	if pieces.is_empty():
		pieces.append(EventSheetL10n.translate("empty"))
	var objects: String = object_list_text(object_labels)
	if not objects.is_empty():
		pieces.append(objects)
	return " · ".join(pieces)


## The distinct object names a folded head lists, trailing off after the first few.
static func object_list_text(object_labels: PackedStringArray) -> String:
	if object_labels.is_empty():
		return ""
	var shown: PackedStringArray = PackedStringArray()
	for label: String in object_labels:
		if shown.size() >= FOLDED_OBJECT_LIMIT:
			return "%s…" % ", ".join(shown)
		shown.append(label)
	return ", ".join(shown)


## The one muted word a head shows for who runs a group, or "" for everyone. A head says the
## EXCEPTION and never the default, so a sheet with no networking in it reads exactly as it always
## did. The two words are spelled as literals rather than looked up, so the translation gate can see
## them - the value they come from is a stored string, which it cannot.
static func runs_on_word(group: EventGroup) -> String:
	match "" if group == null else group.runs_on.strip_edges():
		EventGroup.RUNS_ON_HOST:
			return EventSheetL10n.translate("host")
		EventGroup.RUNS_ON_OWNER:
			return EventSheetL10n.translate("owner")
	return ""


## The three answers to "who runs this group", each as the word a reader picks, the line under
## it, and the value stored on the group. ONE list: the Edit group dropdown, the head's Runs on
## submenu, the help strip and the tests all read it, so a wording change lands everywhere at once.
## Everyone stores "" - it is the default, and it is the answer that emits nothing at all.
static func runs_on_choices() -> Array[Dictionary]:
	return [
		{"value": "", "label": EventSheetL10n.translate("Everyone"),
			"description": EventSheetL10n.translate("Every peer runs these events. Right for anything a player sees or hears, and for a game with no networking in it.")},
		{"value": EventGroup.RUNS_ON_HOST, "label": EventSheetL10n.translate("The host"),
			"description": EventSheetL10n.translate("Only the peer that called Host a game runs them. Right for anything that decides what is true; the others learn the result through a message or a value kept in step.")},
		{"value": EventGroup.RUNS_ON_OWNER, "label": EventSheetL10n.translate("The owner"),
			"description": EventSheetL10n.translate("Only the peer that owns this object runs them. Right for what each player controls about their own character, so nobody moves anybody else's.")}
	]


## The index of a group's answer in that list - what a dropdown selects, and never -1: a value
## nothing recognises reads as everyone, which is what it compiles to.
static func runs_on_index(value: String) -> int:
	var wanted: String = value.strip_edges()
	var choices: Array[Dictionary] = runs_on_choices()
	for index: int in range(choices.size()):
		if str(choices[index].get("value", "")) == wanted:
			return index
	return 0


## Every group in an event list, outermost first, depth-first - the order a picker lists them in.
static func collect(events: Array, into: Array[EventGroup] = []) -> Array[EventGroup]:
	for entry: Variant in events:
		if entry is EventGroup:
			var group: EventGroup = entry as EventGroup
			into.append(group)
			collect(children(group), into)
	return into


## The member Set Group Active addresses for a group, as the compiler spells it. One token, so the
## dialog can never write a name the compiler does not emit.
static func guard_token(group: EventGroup) -> String:
	# The compiler builds the guard from `group_name`, blank included (which it turns into "group"),
	# so this asks the same question of the same field rather than of the prettier display name.
	return SheetCompiler.guard_token("" if group == null else group.group_name)


## The value the two group ACEs take: the guard token as a GDScript string literal, which is what
## their templates concatenate into `"__group_" + … + "_active"`.
static func guard_value(group: EventGroup) -> String:
	return "\"%s\"" % guard_token(group)


## The groups a Set/Is Group Active dialog offers, toggleable ones first (those are the ones the
## action can actually reach), each with the sentence the picker shows beside it.
static func choices(sheet: EventSheetResource) -> Array[Dictionary]:
	var offered: Array[Dictionary] = []
	if sheet == null:
		return offered
	var toggleable: Array[Dictionary] = []
	var rest: Array[Dictionary] = []
	for group: EventGroup in collect(sheet.events):
		var entry := {
			"value": guard_value(group),
			"name": display_name(group),
			"description": group.description.strip_edges(),
			"toggleable": group.runtime_toggleable,
			"group": group
		}
		if group.runtime_toggleable:
			toggleable.append(entry)
		else:
			rest.append(entry)
	offered.append_array(toggleable)
	offered.append_array(rest)
	return offered


## True when the value a group row was given names a group of this sheet that cannot be switched at
## runtime yet - the one case where the row is well spelled and still does nothing.
static func needs_switch(offered: Array[Dictionary], value: String) -> bool:
	var wanted: String = value.strip_edges()
	for entry: Dictionary in offered:
		if str(entry.get("value", "")) == wanted:
			return not bool(entry.get("toggleable", false))
	return false


## The group of this sheet a row's value names, or null for free text that matches none.
static func group_for_value(sheet: EventSheetResource, value: String) -> EventGroup:
	var wanted: String = value.strip_edges()
	for entry: Dictionary in choices(sheet):
		if str(entry.get("value", "")) == wanted:
			return entry.get("group") as EventGroup
	return null


## True when a parameter names one of the SHEET's own groups rather than a node group. Derived from
## what the template does with the value - it builds the very `"__group_<name>_active"` member the
## compiler emits for a runtime-toggleable group - so a pack that writes the same guard gets the
## same picker without registering anything.
static func reads_sheet_groups(codegen_template: String, param_id: String) -> bool:
	if param_id.strip_edges().is_empty():
		return false
	return codegen_template.contains("\"__group_\" + {%s} + \"_active\"" % param_id)


## The brackets to draw for one screenful of rows: one entry per group whose body is visible, with
## the y-range its body covers and the depth its rule insets by.
##
## `rows` is [{group: bool, indent: int, top: float, height: float}] - the flat rows in draw order.
## A group's body runs from the row after its head while the indent stays deeper, which is the same
## walk the breadcrumb's enclosure map does, so the bracket ends exactly where the crumb does.
## Returns [{index, depth, top, bottom, x}] with `top` at the head's BOTTOM (the head wears its own
## accent bar) and `bottom` at the last child's bottom.
static func brackets(rows: Array, left: float = BRACKET_LEFT, depth_inset: float = BRACKET_DEPTH_INSET) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	var by_index: Dictionary = {}
	var open_groups: Array[int] = []
	for index: int in range(rows.size()):
		var entry: Dictionary = rows[index]
		var indent: int = int(entry.get("indent", 0))
		while not open_groups.is_empty() and int((rows[open_groups.back()] as Dictionary).get("indent", 0)) >= indent:
			open_groups.pop_back()
		var row_bottom: float = float(entry.get("top", 0.0)) + float(entry.get("height", 0.0))
		for open_index: int in open_groups:
			(by_index[open_index] as Dictionary)["bottom"] = row_bottom
		if bool(entry.get("group", false)):
			var head: Dictionary = {
				"index": index,
				"depth": open_groups.size(),
				"top": row_bottom,
				"bottom": row_bottom,
				"x": left + float(open_groups.size()) * depth_inset
			}
			found.append(head)
			by_index[index] = head
			open_groups.append(index)
	var drawable: Array[Dictionary] = []
	for candidate: Dictionary in found:
		if float(candidate.get("bottom", 0.0)) > float(candidate.get("top", 0.0)) + 0.5:
			drawable.append(candidate)
	return drawable


## The separator between two crumbs of the pinned head's parent trail.
const CRUMB_SEPARATOR: String = " ▸ "

## The elision a trail longer than two parents wears in place of the names it drops.
const CRUMB_ELLIPSIS: String = "…"


## The pinned head's parent trail, as the names it is DRAWN from: `crumbs` is [{"text", "index"}] in
## reading order, where `index` is that name's position in `titles` and -1 for the elision, which
## stands for names rather than being one. Only the last two parents are shown; the whole chain is
## kept as `full` for the hover, and the innermost name is the head itself (`title`), never a crumb -
## the pinned row IS that group.
##
## The strip draws one name at a time and arms a click zone per crumb from these, so clicking a
## parent name scrolls to that head.
static func pinned_trail(titles: PackedStringArray) -> Dictionary:
	if titles.size() <= 1:
		return {"title": titles[0] if titles.size() == 1 else "", "crumbs": [],
			"full": CRUMB_SEPARATOR.join(titles)}
	var crumbs: Array[Dictionary] = []
	var first_shown: int = maxi(0, titles.size() - 3)
	if first_shown > 0:
		crumbs.append({"text": CRUMB_ELLIPSIS, "index": -1})
	for index: int in range(first_shown, titles.size() - 1):
		crumbs.append({"text": titles[index], "index": index})
	return {
		"title": titles[titles.size() - 1],
		"crumbs": crumbs,
		"full": CRUMB_SEPARATOR.join(titles)
	}
