# EventSheet - EventSheetDocTutorials: the Manual's hands-on half.
#
# Every event-sheet editor opens its manual with tutorials you DO, not ones you read, and this one
# had guides and a tour instead - neither of which puts a beginner's hands on the real controls.
# These do: each step names a control the editor really has, the control PULSES until it is used,
# and the step completes the moment the open sheet contains what the step asked for.
#
# THE STEP IS DATA, and deliberately so. A step is {text, control, check} where `check` is the NAME
# of a predicate rather than a Callable, which buys three things: the whole catalogue is a constant
# (no closures captured at load time on the boot path), a step round-trips through a config file as
# progress, and the suite pins "this fixture sheet completes step 3" without building a window.
#
# THE TOUR IS STEP 0. The tour already walks the parts of the editor; making it the first step of
# the first tutorial is what stops a beginner having to choose between two front doors.
#
# WHERE THE STEPS RUN: on a scratch sheet (EventSheetDocScratch), so a first-timer practises without
# touching a file of their project and closes the tab without being asked to save anything.
#
# THE ID SCHEME (joins the frozen set):
#   "reference:tutorials"        the list
#   "reference:tutorial/<id>"    one tutorial, at the step the reader has reached
@tool
class_name EventSheetDocTutorials
extends RefCounted

## The list page's own title, and the tree row it reads as.
const PAGE_TITLE := "Tutorials"

## The doc id of the list page. Frozen with the rest of the reference id scheme.
const LIST_DOC_ID := "reference:tutorials"

## The actions a step card offers. They are NAMES the page reports and the host acts on, the same
## way the reference stub's "Write this guide" button works - a page never runs anything itself.
const ACTION_START := "tutorial_start"
const ACTION_BACK := "tutorial_back"
const ACTION_SKIP := "tutorial_skip"
const ACTION_NEXT := "tutorial_next"

## Where a reader's progress is remembered: tutorial id -> the step they had reached. Editor
## metadata rather than a project setting, because progress belongs to the reader and not to the
## project they happen to have open.
const PROGRESS_SECTION := "eventsheets"
const PROGRESS_KEY := "tutorial_progress"

## The five tutorials, in reading order. `minutes` is the honest estimate the list prints beside
## each one; `control` is the EXACT label of the toolbar control the step asks for, so the pulse
## resolves it by that label rather than through a map somebody has to keep up to date.
const TUTORIALS: Array[Dictionary] = [
	{
		"id": "first-event",
		"title": "Your first event",
		"minutes": 5,
		"lead": "Six steps from an empty sheet to a rule that runs. Nothing here is a picture: you press the real buttons, on a scratch sheet nobody will miss.",
		"steps": [
			{
				"text": "Start with the tour: Tools ▸ Start the Tour… points at each part of the editor you are about to use. Come back here when it finishes - or press Next now and learn them as you go.",
				"control": "Tools",
				"check": "",
			},
			{
				"text": "Add an event: press E or click Add Event, and pick a trigger. Try On Ready - it fires once, when the object appears.",
				"control": "Add Event",
				"check": "sheet_has_event",
			},
			{
				"text": "Now add an action: press A or click Add Action on the event you just made. Pick anything that changes a value - Set hp, Print Message, Move.",
				"control": "Add Action",
				"check": "sheet_has_action",
			},
			{
				"text": "Give the event a condition: press C or click Add Condition. Conditions are the WHEN of the row, and all of them have to hold for the actions to run.",
				"control": "Add Condition",
				"check": "sheet_has_condition",
			},
			{
				"text": "Give the sheet some memory: Add ▸ Global Variable…, and name it something your rule cares about. A variable row reads exactly the way it will compile.",
				"control": "Add",
				"check": "sheet_has_variable",
			},
			{
				"text": "See the honest GDScript: click GDScript in the toolbar. That file is what your game ships - no runtime, no plugin dependency. You have made an event sheet.",
				"control": "GDScript",
				"check": "",
			},
		],
	},
	{
		"id": "open-your-script",
		"title": "Open your own script as a sheet",
		"minutes": 3,
		"lead": "The editor reads GDScript you already have. Nothing is rewritten: what you open, you can save back byte for byte.",
		"steps": [
			{
				"text": "Open a script of your own: Sheet ▸ Open…, and pick any .gd file in your project. Anything the reader cannot say as a row stays as a Script block, untouched.",
				"control": "Sheet",
				"check": "sheet_is_opened_script",
			},
			{
				"text": "Read one row: hover it. The exact GDScript the row came from is one hover away, and the row's own sentence is above it - that is the whole promise of opening a file here.",
				"control": "",
				"check": "",
			},
			{
				"text": "Now save it untouched: Ctrl+S. The file on disk is byte for byte what it was. That is what makes it safe to open your project's real scripts.",
				"control": "Save",
				"check": "",
			},
		],
	},
	{
		"id": "add-a-behavior",
		"title": "Add a behavior to an object",
		"minutes": 4,
		"lead": "A behavior is a pack you attach to a node; it brings its own conditions, actions and expressions with it.",
		"steps": [
			{
				"text": "Open Sheet ▸ Manage Includes… and add a behavior - Platformer, Health, Timer, anything the list offers. The sheet's Include bar says what it now carries.",
				"control": "Sheet",
				"check": "sheet_has_behavior",
			},
			{
				"text": "Add an action from it: press A and look for the behavior's own group in the picker. Everything it publishes is filed under its name.",
				"control": "Add Action",
				"check": "sheet_has_action",
			},
			{
				"text": "Read its reference: press F1 on the Include bar. Every behavior has one page in the fixed shape - Properties, Conditions, Actions, Expressions, Triggers.",
				"control": "",
				"check": "",
			},
			{
				"text": "Attach it for real: Tools ▸ Attach to Selected Node puts this sheet's script on the node you have selected in the scene, and the behavior comes with it.",
				"control": "Tools",
				"check": "",
			},
		],
	},
	{
		"id": "make-a-function",
		"title": "Make a function and call it",
		"minutes": 5,
		"lead": "A function is a named block of actions with typed parameters. It reads with its own name in the condition lane, and any row can call it.",
		"steps": [
			{
				"text": "Add ▸ Function…, name it something a person would say out loud - Take Damage, Spawn Wave - and give it one parameter.",
				"control": "Add",
				"check": "sheet_has_function",
			},
			{
				"text": "Put an action inside it: select the function's row and press A. Everything under the function's own band runs when it is called.",
				"control": "Add Action",
				"check": "sheet_has_action",
			},
			{
				"text": "Call it from an event: press A on any other event and pick Functions ▸ Call, then your function's name. The row says which function it hands over to.",
				"control": "Add Action",
				"check": "",
			},
			{
				"text": "Look at the GDScript: your function is a plain typed GDScript function, and the call is a plain call. Nothing about it is special to this editor.",
				"control": "GDScript",
				"check": "",
			},
		],
	},
	{
		"id": "coming-from-another-editor",
		"title": "Coming from another event-sheet editor",
		"minutes": 8,
		"lead": "Most of what you know comes across unchanged. This walks the handful of words that are spelled differently here, with your hands on each one.",
		"steps": [
			{
				"text": "Read the word list first: the Manual's \"Coming from another event-sheet editor\" page has every term that is spelled differently. It is two minutes and it saves the other six.",
				"control": "",
				"check": "",
			},
			{
				"text": "A layout is a scene. Add an event and give it the System ▸ On start of layout trigger - the same moment you know, under the name this editor uses.",
				"control": "Add Event",
				"check": "sheet_has_event",
			},
			{
				"text": "Picking still picks. Add a condition on an object; the actions under it run on the instances that condition kept, exactly as they did there.",
				"control": "Add Condition",
				"check": "sheet_has_condition",
			},
			{
				"text": "An instance variable is a sheet variable: Add ▸ Global Variable… for one the whole sheet shares, Add ▸ Local Variable… for one that lives inside its event.",
				"control": "Add",
				"check": "sheet_has_variable",
			},
			{
				"text": "A family is a group. Sheet ▸ Sheet Type… marks this sheet as a Family, and every member iterates the way a family did.",
				"control": "Sheet",
				"check": "",
			},
			{
				"text": "And the one real difference: where a signal exists, react to it instead of asking every frame. Press E and look at the triggers - most of what needed Every Tick plus Trigger Once is a signal here.",
				"control": "Add Event",
				"check": "",
			},
		],
	},
]


## Every tutorial, in reading order. A copy, so a caller that sorts or filters cannot edit the
## catalogue.
static func tutorials() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entry: Dictionary in TUTORIALS:
		out.append(entry.duplicate(true))
	return out


## One tutorial by its id, or an empty Dictionary for an id this build does not carry.
static func tutorial(tutorial_id: String) -> Dictionary:
	var wanted: String = tutorial_id.strip_edges()
	for entry: Dictionary in TUTORIALS:
		if str(entry.get("id", "")) == wanted:
			return entry.duplicate(true)
	return {}


## How many steps a tutorial has. 0 for one this build does not carry, which is what makes every
## caller below safe against an id from an older config file.
static func step_count(tutorial_id: String) -> int:
	return (tutorial(tutorial_id).get("steps", []) as Array).size()


## One step of one tutorial, or an empty Dictionary when either the tutorial or the index is out of
## range. Clamping is the CALLER's business - a step index that has run off the end means the
## reader finished, and that is a different thing from an id that never existed.
static func step(tutorial_id: String, index: int) -> Dictionary:
	var steps: Array = tutorial(tutorial_id).get("steps", []) as Array
	if index < 0 or index >= steps.size():
		return {}
	return (steps[index] as Dictionary).duplicate(true)


## The step index a Back / Next lands on, clamped to the tutorial. Pure, so the whole walk is
## pinned without a window: Next past the last step stays on the last step (the card says Finish
## there), and Back before the first stays on the first.
static func moved_step(tutorial_id: String, index: int, delta: int) -> int:
	var total: int = step_count(tutorial_id)
	if total <= 0:
		return 0
	return clampi(index + delta, 0, total - 1)


## True when the reader is on the last step, which is what turns Next into Finish.
static func is_last_step(tutorial_id: String, index: int) -> bool:
	var total: int = step_count(tutorial_id)
	return total > 0 and index >= total - 1


# ── Did they do it? ───────────────────────────────────────────────────────────────────────────


## Whether a step's asked-for edit is present in `sheet`. Pure over the sheet, so a fixture proves
## the completion rule rather than a screenshot of a green tick.
##
## A step with no check is never "done" - it is a step the reader reads and presses Next on, and
## reporting it complete the moment it appears would be the card lying about what happened.
static func step_done(check: String, sheet: EventSheetResource) -> bool:
	var wanted: String = check.strip_edges()
	if wanted.is_empty() or sheet == null:
		return false
	match wanted:
		"sheet_has_event":
			return _any_event(sheet, "event")
		"sheet_has_condition":
			return _any_event(sheet, "condition")
		"sheet_has_action":
			return _any_event(sheet, "action")
		"sheet_has_variable":
			return not sheet.variables.is_empty()
		"sheet_has_function":
			return not sheet.functions.is_empty()
		"sheet_has_behavior":
			return not sheet.uses_addons.is_empty() or not sheet.includes.is_empty()
		"sheet_is_opened_script":
			return sheet.external_source_path.strip_edges().to_lower().ends_with(".gd")
	return false


## True when any row of the sheet - nested ones included - answers `what`. One walk for the three
## row questions, because a beginner's first action legitimately lands inside a group.
static func _any_event(sheet: EventSheetResource, what: String) -> bool:
	return _any_in(sheet.events, what)


static func _any_in(rows: Array, what: String) -> bool:
	for entry: Variant in rows:
		var event: EventRow = entry as EventRow
		if event == null:
			continue
		match what:
			"event":
				return true
			"condition":
				if not event.conditions.is_empty():
					return true
			"action":
				if not event.actions.is_empty():
					return true
		if _any_in(event.sub_events, what):
			return true
	return false


# ── Progress ──────────────────────────────────────────────────────────────────────────────────


## Everything the reader has reached, as tutorial id -> step index. Empty outside the editor, where
## there is nothing to remember it in.
static func progress() -> Dictionary:
	if not Engine.is_editor_hint() or not Engine.has_singleton("EditorInterface"):
		return {}
	var settings: EditorSettings = EditorInterface.get_editor_settings()
	if settings == null:
		return {}
	var stored: Variant = settings.get_project_metadata(PROGRESS_SECTION, PROGRESS_KEY, {})
	return stored as Dictionary if stored is Dictionary else {}


## Where the reader had got to in one tutorial, clamped to what this build actually carries - a
## config file written by an older plugin can name a step that no longer exists.
static func step_reached(tutorial_id: String) -> int:
	var total: int = step_count(tutorial_id)
	if total <= 0:
		return 0
	return clampi(int(progress().get(tutorial_id.strip_edges(), 0)), 0, total - 1)


## Remembers where the reader is. Writes the WHOLE map back, because editor metadata is one value.
static func remember_step(tutorial_id: String, index: int) -> void:
	if not Engine.is_editor_hint() or not Engine.has_singleton("EditorInterface"):
		return
	var settings: EditorSettings = EditorInterface.get_editor_settings()
	if settings == null:
		return
	var stored: Dictionary = progress()
	stored[tutorial_id.strip_edges()] = maxi(0, index)
	settings.set_project_metadata(PROGRESS_SECTION, PROGRESS_KEY, stored)


## The line the list prints under a tutorial's name, from the progress alone. Pure, so the suite
## pins the sentence rather than a screenshot of it.
static func progress_label(tutorial_id: String, reached: int) -> String:
	var total: int = step_count(tutorial_id)
	if total <= 0:
		return ""
	if reached <= 0:
		return "%d min" % int(tutorial(tutorial_id).get("minutes", 0))
	if reached >= total - 1:
		return "%d min · last step" % int(tutorial(tutorial_id).get("minutes", 0))
	return "%d min · step %d of %d" % [int(tutorial(tutorial_id).get("minutes", 0)), reached + 1, total]


# ── The pages ─────────────────────────────────────────────────────────────────────────────────


## The list page: every tutorial, with how long it takes and where the reader left it.
static func list_blocks() -> Array[Dictionary]:
	var blocks: Array[Dictionary] = [
		{"kind": "heading", "level": 1, "text": PAGE_TITLE, "bbcode": PAGE_TITLE,
			"slug": EventSheetDocMarkdown.slug(PAGE_TITLE)},
		{"kind": "paragraph", "bbcode":
			"These are done, not read. Each step names a control this editor really has, highlights it until you use it, and completes when the sheet contains what the step asked for. They run on a scratch sheet, so nothing in your project is touched."},
	]
	for entry: Dictionary in TUTORIALS:
		var id: String = str(entry.get("id", ""))
		var title: String = str(entry.get("title", ""))
		blocks.append({"kind": "heading", "level": 2, "text": title, "bbcode": title, "slug": id})
		blocks.append({"kind": "paragraph", "bbcode": "%s\n[i]%s[/i]" % [
			EventSheetDocMarkdown.escape_brackets(str(entry.get("lead", ""))),
			progress_label(id, step_reached(id))]})
		blocks.append({"kind": "button",
			"label": "Start" if step_reached(id) <= 0 else "Carry on",
			"tooltip": "Opens a scratch sheet and walks this tutorial step by step.",
			"action": ACTION_START, "argument": id})
	return blocks


## One tutorial, at one step: the card the mockup draws. The heading is the tutorial and the
## small-caps line is where the reader is, so the page title never changes under them while they
## walk it - only the card does.
static func step_blocks(tutorial_id: String, index: int = -1) -> Array[Dictionary]:
	var entry: Dictionary = tutorial(tutorial_id)
	if entry.is_empty():
		return []
	var total: int = step_count(tutorial_id)
	var at: int = clampi(index if index >= 0 else step_reached(tutorial_id), 0, maxi(total - 1, 0))
	var current: Dictionary = step(tutorial_id, at)
	var title: String = str(entry.get("title", ""))
	var blocks: Array[Dictionary] = [
		{"kind": "heading", "level": 1, "text": title, "bbcode": title,
			"slug": EventSheetDocMarkdown.slug(title)},
		{"kind": "paragraph", "bbcode": "[i]%s[/i]" % step_caption(tutorial_id, at)},
		{"kind": "quote", "bbcode": EventSheetDocMarkdown.escape_brackets(str(current.get("text", "")))},
	]
	var control: String = str(current.get("control", "")).strip_edges()
	if not control.is_empty():
		blocks.append({"kind": "paragraph", "bbcode":
			"[i]%s stays highlighted in the toolbar until you use it.[/i]" % EventSheetDocMarkdown.escape_brackets(control)})
	if not str(current.get("check", "")).strip_edges().is_empty():
		blocks.append({"kind": "paragraph", "bbcode":
			"[i]This step completes on its own the moment the sheet contains it.[/i]"})
	blocks.append({"kind": "button", "label": "◀ Back",
		"tooltip": "The step before this one.", "action": ACTION_BACK, "argument": tutorial_id})
	blocks.append({"kind": "button", "label": "Skip",
		"tooltip": "Leaves the tutorial and goes back to the list.", "action": ACTION_SKIP,
		"argument": tutorial_id})
	blocks.append({"kind": "button",
		"label": "Finish" if is_last_step(tutorial_id, at) else "Next ▶",
		"tooltip": "The next step. Never waits for the check - a step you have already done your own way is a step you can walk past.",
		"action": ACTION_NEXT, "argument": tutorial_id})
	return blocks


## The line above the card: which tutorial, and how far in. Pure, so the suite pins the words.
static func step_caption(tutorial_id: String, index: int) -> String:
	var total: int = step_count(tutorial_id)
	if total <= 0:
		return ""
	return "%s · step %d of %d" % [str(tutorial(tutorial_id).get("title", "")).to_upper(),
		clampi(index, 0, total - 1) + 1, total]


## The doc id one tutorial's card lives at, and the id of the list.
##
## Spelled out here rather than asked of the reference router, and that is not a shortcut: the
## router reads THIS file to draw a tutorial page, and a file that read it back would be a cycle
## the parser cannot resolve. The two halves of the id are frozen either way.
static func doc_id(tutorial_id: String) -> String:
	var wanted: String = tutorial_id.strip_edges()
	return LIST_DOC_ID if wanted.is_empty() else "reference:tutorial/%s" % wanted
