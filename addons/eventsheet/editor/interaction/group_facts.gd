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

## The compiler and the lifter, loaded by path the first time a row asks them anything - naming
## either class here would compile it, and all it names, the moment this file loads.
const ReadingDoors := preload("res://addons/eventsheet/editor/interaction/reading_doors.gd")

## How far in each nesting level draws its bracket, in px before display scaling. Nested groups sit
## 2px further in, so three levels read as three rules rather than one thick one.
const BRACKET_DEPTH_INSET: float = 2.0

## The bracket's own thickness, in px before display scaling.
const BRACKET_WIDTH: float = 2.0

## Where the outermost bracket starts. Rows are NEVER offset for a bracket, so this is a canvas
## inset, not an indent.
const BRACKET_LEFT: float = 3.0

## How far the slim tick at the foot of a group's bracket runs to the right, in px before display
## scaling: the mark that says where the group's body ends.
const END_TICK_LENGTH: float = 10.0

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


## The one muted word a head shows for which MODE a group runs in, or "" for a group that runs in
## every one. Same rule as the word above: the head says the exception and never the default, so a
## game with no modes reads exactly as it always did. The word is the group's own stored spelling,
## which is the word the author picked out of the declared list.
static func runs_in_word(group: EventGroup) -> String:
	return "" if group == null else group.runs_in.strip_edges()


## What turning this group into a region would lose, one translated sentence each, in the order a
## head shows them. Empty when nothing would be: a region keeps the name, the description, the
## colour and every row, so a plain group goes and comes back unchanged.
static func region_losses(group: EventGroup) -> PackedStringArray:
	var said: PackedStringArray = PackedStringArray()
	if group == null:
		return said
	var name: String = display_name(group)
	if not group.enabled:
		said.append(EventSheetL10n.translate("%s is off at start, so its events never run. As a region they run from the start.") % name)
	if group.runtime_toggleable:
		said.append(EventSheetL10n.translate("Events can switch %s off and on. A region cannot be switched, so the rows that switch it stop working.") % name)
	var locals: PackedStringArray = PackedStringArray()
	for entry: Variant in group.local_variables:
		if entry is LocalVariable:
			locals.append((entry as LocalVariable).name)
	if locals.size() == 1:
		said.append(EventSheetL10n.translate("Its local variable %s goes with it, so the rows that use it stop working.") % locals[0])
	elif locals.size() > 1:
		said.append(EventSheetL10n.translate("Its %d local variables (%s) go with it, so the rows that use them stop working.") % [
			locals.size(), ", ".join(locals)])
	match group.runs_on.strip_edges():
		EventGroup.RUNS_ON_HOST:
			said.append(EventSheetL10n.translate("%s runs only on the host. As a region its events run everywhere.") % name)
		EventGroup.RUNS_ON_OWNER:
			said.append(EventSheetL10n.translate("%s runs only on the owner of this object. As a region its events run everywhere.") % name)
	if not runs_in_word(group).is_empty():
		said.append(EventSheetL10n.translate("%s runs only in %s. As a region its events run in every mode.") % [
			name, runs_in_word(group)])
	return said


## Which modes a group can say it runs in: every one the project declares, plus the answer that
## means all of them. ONE list, read by the Edit group dropdown, the head's submenu and the tests.
static func runs_in_choices(sheet: EventSheetResource) -> Array[Dictionary]:
	var choices: Array[Dictionary] = [{"value": "", "label": EventSheetL10n.translate("Every mode"),
		"description": EventSheetL10n.translate("These events run whatever the game is doing. Right for a pause menu's own rows, and for a game with no modes in it.")}]
	for word: String in EventSheetModeFacts.project_words(sheet):
		choices.append({"value": word, "label": word,
			"description": EventSheetL10n.translate("These events run only while the game is in %s. Every row inside stops asking for itself.") % word})
	return choices


## The index of a group's answer in that list, and never -1: a mode nothing declares any more reads
## as every mode, which is safer than silently pointing a dropdown at the wrong row.
static func runs_in_index(sheet: EventSheetResource, value: String) -> int:
	var wanted: String = value.strip_edges()
	var choices: Array[Dictionary] = runs_in_choices(sheet)
	for index: int in range(choices.size()):
		if str(choices[index].get("value", "")) == wanted:
			return index
	return 0


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
	return ReadingDoors.compiler().guard_token("" if group == null else group.group_name)


## The value the two group ACEs take: the guard token as a GDScript string literal, which is what
## their templates concatenate into `"__group_" + … + "_active"`.
static func guard_value(group: EventGroup) -> String:
	return "\"%s\"" % guard_token(group)


## The groups a Set/Is Group Active dialog offers BY THE NAME THEY WERE GIVEN: this sheet's, then
## those of the sheets it includes (their groups compile into this script too, so a row here can
## reach them). Switchable ones lead, because those are the ones the row reaches today. Each entry is
## {value, name, description, toggleable, group, home}: `value` is the stored guard token, `home` the
## included file a group lives in ("" for this sheet). Two groups sharing a name share one switch, so
## the name is offered once.
static func choices(sheet: EventSheetResource) -> Array[Dictionary]:
	var toggleable: Array[Dictionary] = []
	var rest: Array[Dictionary] = []
	var seen: Dictionary = {}
	for owned: Array in _sheets_reaching(sheet):
		for group: EventGroup in collect((owned[0] as EventSheetResource).events):
			var value: String = guard_value(group)
			if seen.has(value):
				continue
			seen[value] = true
			var home: String = str(owned[1])
			var entry := {
				"value": value,
				"name": display_name(group),
				"description": choice_description(group, home),
				"toggleable": group.runtime_toggleable,
				"group": group,
				"home": home
			}
			if group.runtime_toggleable:
				toggleable.append(entry)
			else:
				rest.append(entry)
	toggleable.append_array(rest)
	return toggleable


## [sheet, home file] for the sheet itself and every sheet it includes, outermost first, each once -
## the same walk the compiler's include merge does, so the list holds exactly the groups the
## compiled script will have. Read when the dialog opens, never on boot.
static func _sheets_reaching(sheet: EventSheetResource) -> Array:
	var reached: Array = []
	if sheet == null:
		return reached
	reached.append([sheet, ""])
	var visited: Dictionary = {}
	var pending: Array = Array(sheet.includes)
	while not pending.is_empty():
		var path: String = str(pending.pop_front())
		if path.is_empty() or visited.has(path) or not ResourceLoader.exists(path):
			continue
		visited[path] = true
		var included: EventSheetResource = load(path) as EventSheetResource
		if included == null:
			continue
		reached.append([included, path.get_file()])
		pending.append_array(Array(included.includes))
	return reached


## The sentence a group's entry reads with in the picker: its own description, then what picking it
## does. A group whose saved token no longer matches its name says the token too, so a reader who
## meets `__group_old_name_active` in the code can tell which group it is.
static func choice_description(group: EventGroup, home: String = "") -> String:
	var pieces: PackedStringArray = PackedStringArray()
	var description: String = group.description.strip_edges()
	if not description.is_empty():
		pieces.append(description)
	if group.runtime_toggleable:
		pieces.append(EventSheetL10n.translate("On at start, switchable.") if group.enabled
			else EventSheetL10n.translate("Off at start, switchable."))
	elif home.is_empty():
		pieces.append(EventSheetL10n.translate("Not switchable: picking it turns on Can be switched at runtime."))
	else:
		pieces.append(EventSheetL10n.translate("Not switchable, and it lives in %s: turn on Can be switched at runtime there.") % home)
	var token: String = guard_token(group)
	if token != ReadingDoors.compiler().guard_token(display_name(group)):
		pieces.append(EventSheetL10n.translate("Its switch is written as %s.") % token)
	return " ".join(pieces)


## The group of THIS sheet a row's value names, or null for free text that matches none. A group of
## an included sheet is not returned: changing it would write a different file.
static func group_for_value(sheet: EventSheetResource, value: String) -> EventGroup:
	var wanted: String = value.strip_edges()
	if sheet == null:
		return null
	for group: EventGroup in collect(sheet.events):
		if guard_value(group) == wanted:
			return group
	return null


## Picking a group that cannot be switched yet turns its switch on - called inside the very edit that
## writes the row, so one Ctrl+Z takes back both. Returns the group it switched on, or null when the
## row names no such group of this sheet (already switchable, free text, or another file's group).
static func switch_on_picked(sheet: EventSheetResource, codegen_template: String, params: Dictionary) -> EventGroup:
	for key: Variant in params.keys():
		if not reads_sheet_groups(codegen_template, str(key)):
			continue
		var group: EventGroup = group_for_value(sheet, str(params[key]))
		if group != null and not group.runtime_toggleable:
			group.runtime_toggleable = true
			return group
	return null


## The ids of the two builtin rows that name a sheet group. A row lifted from a file or applied from
## the builtin vocabulary carries no baked template, so these frozen ids are how such a row is known;
## a pack row is known from the template it baked, the way the picker knows it.
const SWITCH_ACE_IDS: PackedStringArray = ["SetGroupActive", "IsGroupActive"]


## The parameter of a row that names a sheet group, or "" for a row that names none.
static func switch_param(ace: Resource) -> String:
	if ace == null or not (ace.get("params") is Dictionary):
		return ""
	var template: String = str(ace.get("codegen_template"))
	for key: Variant in (ace.get("params") as Dictionary).keys():
		if reads_sheet_groups(template, str(key)):
			return str(key)
	if template.is_empty() and SWITCH_ACE_IDS.has(str(ace.get("ace_id"))):
		return "group"
	return ""


## A group was renamed: every Set/Is Group Active in `sheet` naming its old token now names the new
## one. Walks events, groups, sub-events and functions (an inner class has groups of its own, so it is
## left alone). Returns how many rows were rewritten; call it inside the edit that renames the group.
static func rewrite_switch_rows(sheet: EventSheetResource, old_value: String, new_value: String) -> int:
	if sheet == null or old_value == new_value:
		return 0
	var counter: Array[int] = [0]
	_rewrite_in_rows(sheet.events, old_value, new_value, counter)
	for function_resource: Variant in sheet.functions:
		if function_resource is EventFunction:
			var function_rows: Array = (function_resource as EventFunction).events
			if function_rows.is_empty():
				function_rows = (function_resource as EventFunction).rows
			_rewrite_in_rows(function_rows, old_value, new_value, counter)
	return counter[0]


static func _rewrite_in_rows(rows: Array, old_value: String, new_value: String, counter: Array[int]) -> void:
	for row: Variant in rows:
		if row is EventGroup:
			_rewrite_in_rows(children(row as EventGroup), old_value, new_value, counter)
		elif row is EventRow:
			var event_row: EventRow = row as EventRow
			var aces: Array = [event_row.trigger]
			aces.append_array(event_row.conditions)
			aces.append_array(event_row.actions)
			for ace: Variant in aces:
				var key: String = switch_param(ace as Resource) if ace is Resource else ""
				if key.is_empty():
					continue
				var params: Dictionary = (ace as Resource).get("params")
				if str(params.get(key, "")).strip_edges() == old_value:
					params[key] = new_value
					counter[0] += 1
			_rewrite_in_rows(event_row.sub_events, old_value, new_value, counter)


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


## The slim end tick of one bracket (an entry `brackets` returned): a short rule as thick as the
## bracket, turning right from its foot, so a group's body has a visible bottom and not only a side.
static func end_tick_rect(bracket: Dictionary) -> Rect2:
	var bottom: float = float(bracket.get("bottom", 0.0))
	return Rect2(float(bracket.get("x", BRACKET_LEFT)), bottom - BRACKET_WIDTH, END_TICK_LENGTH, BRACKET_WIDTH)


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
