# EventSheet - EventSheetDocBehaviorIndex: "Behaviors, by the name you know".
#
# The first thing somebody moving here from another event-sheet editor searches is a BEHAVIOR
# NAME. They do not type "CharacterBody2D" and they do not type "platformer_movement"; they type
# "8 Direction", or "Bullet", or "Pin". The glossary answers words; this page answers behaviors,
# and it answers each one twice:
#
#   here     what the thing IS here - the shipped pack that does the job, or the Godot node or
#            property that already did it and needs no pack at all
#   reading  what a HAND-WRITTEN version of it reads like on a sheet, because the second question
#            is always "and what about the code I already have?"
#
# THE NAMING RULE, same as the glossary's and not a style preference: the other editor is never
# named in code - not in an identifier, not in a string, not in a comment, not in a test label.
# The behavior NAMES below are ordinary words for ordinary movement; the product they came from
# is not written anywhere here. The repo's prose guides may name it; nothing that ships as a
# string does.
#
# Each entry is {key, name, here, pack, reading}:
#   key      the slug the page anchors it under, and the id half of "reference:behaviors/<key>"
#   name     the behavior name the reader arrives holding
#   here     the same job in this editor's words - one line
#   pack     the shipped pack directory that does it, or "" when Godot already does
#   reading  what the hand-written shape reads like on a sheet, or "" when there is nothing to say
@tool
class_name EventSheetDocBehaviorIndex
extends RefCounted

## The page's own title. What the tree row, the breadcrumb and the search result all read.
const PAGE_TITLE := "Behaviors, by the name you know"

## The lead line under the title.
const PAGE_LEAD := "The behaviors you already reach for, and what each one is here. Where a pack does the job, attaching it is the first option. Where Godot already does the job, there is nothing to attach. And in both cases, a hand-written version of the same idea reads on a sheet as the behavior it always was."

## The behaviors, in reading order - movement first, then what sits on top of it, then the
## project-level ones. Authored rather than derived: only one of the two vocabularies is in this
## repo, and a table that guessed at the other one would be wrong in the reader's own words.
const BEHAVIORS: Array[Dictionary] = [
	{
		"key": "eight-direction",
		"name": "8 Direction",
		"here": "The 8-Direction pack: arrows or a stick move the node, with acceleration and drag.",
		"pack": "eight_direction",
		"reading": "A tick that reads four keys into a direction and sets velocity from it reads as the 8-Direction rows, and offers to adopt the pack.",
	},
	{
		"key": "bullet",
		"name": "Bullet",
		"here": "The Bullet pack: a speed, an angle of motion, acceleration and gravity, moved every tick.",
		"pack": "bullet",
		"reading": "A tick that advances a position along a stored direction reads as Set speed / Set angle of motion / Move, with Distance travelled as an expression.",
	},
	{
		"key": "turret",
		"name": "Turret",
		"here": "The Weapon Kit pack: acquire the nearest target in range, rotate toward it, fire on a rate.",
		"pack": "weapon_kit",
		"reading": "A nearest-in-range search followed by a rotate-toward and a cooldown reads as Acquire nearest / Has target / Rotate toward / On shoot.",
	},
	{
		"key": "move-to",
		"name": "Move To",
		"here": "The Move To pack: send a node to a position and be told when it arrives.",
		"pack": "move_to",
		"reading": "A move_toward toward a stored destination, with an arrival test, reads as Move to position / Is moving / On arrived / Stop.",
	},
	{
		"key": "pin",
		"name": "Pin",
		"here": "No pack needed: parent the node, or copy the other node's position each tick. Pin to is one action.",
		"pack": "",
		"reading": "A tick that copies another node's position (and optionally its rotation) reads as Pin to, on one row.",
	},
	{
		"key": "wrap",
		"name": "Wrap",
		"here": "The Wrap pack: a node that leaves one edge of the scene comes back on the other.",
		"pack": "wrap",
		"reading": "A pair of edge tests that teleport the node across reads as Wrap around layout, on one row.",
	},
	{
		"key": "bound-to-layout",
		"name": "Bound to layout",
		"here": "The Bound To pack: the node is kept inside the scene's rectangle.",
		"pack": "bound_to",
		"reading": "A clamp of x and y against the scene rectangle reads as Bound to layout, on one row.",
	},
	{
		"key": "rotate",
		"name": "Rotate",
		"here": "The Rotate pack: a steady turn, in degrees per second.",
		"pack": "rotate",
		"reading": "A rotation advanced by a rate times delta reads as Rotate, on one row.",
	},
	{
		"key": "fade",
		"name": "Fade",
		"here": "The Fade pack: wait, fade out over a time, then destroy or stay.",
		"pack": "fade",
		"reading": "A tween or a per-tick alpha ramp ending in queue_free reads as Fade out then destroy, on one row.",
	},
	{
		"key": "flash",
		"name": "Flash",
		"here": "The Flash pack: blink the node on and off for a while - the hit flicker.",
		"pack": "flash",
		"reading": "A timer that toggles visible reads as Flash for, on one row.",
	},
	{
		"key": "sine",
		"name": "Sine",
		"here": "The Sine pack: a value that oscillates - position, size, angle or opacity.",
		"pack": "sine",
		"reading": "A tick that advances a phase and writes sin(phase) into a property reads as the Sine rows.",
	},
	{
		"key": "line-of-sight",
		"name": "Line of sight",
		"here": "The Line Of Sight pack (2D and 3D): can this node see that one, within a range.",
		"pack": "line_of_sight",
		"reading": "A raycast toward a target with a distance test reads as Has line of sight to, on one condition row.",
	},
	{
		"key": "drag-drop",
		"name": "Drag & Drop",
		"here": "The Drag And Drop pack: press to pick up, move with the cursor, release to drop.",
		"pack": "drag_drop",
		"reading": "A pressed / motion / released trio around a held flag reads as On drag start / Is dragging / On drop.",
	},
	{
		"key": "anchor",
		"name": "Anchor",
		"here": "No pack needed: Godot's Control anchors, or one Anchor to action that keeps a node at a share of the screen.",
		"pack": "",
		"reading": "A tick that recomputes a position from the viewport size reads as Anchor to, on one row.",
	},
	{
		"key": "solid",
		"name": "Solid",
		"here": "What a body IS here: a StaticBody2D (or a TileMap collision layer). Nothing is attached - the collision shape is the solidity.",
		"pack": "",
		"reading": "The head of the sheet says which body the node is, and the Object properties show the collision layers it stops.",
	},
	{
		"key": "jump-thru",
		"name": "Jump-thru",
		"here": "What a body IS here: a StaticBody2D whose collision shape is one-way. Two toggles in Object properties, no behavior.",
		"pack": "",
		"reading": "The head names the body; the one-way toggle and its margin read on the Object properties, not as rows.",
	},
	{
		"key": "platform",
		"name": "Platform",
		"here": "The Platformer pack: run, jump, coyote time, jump buffering, on a CharacterBody2D.",
		"pack": "platformer_movement",
		"reading": "A move_and_slide tick with gravity, a jump test and is_on_floor reads as the Platformer rows, and offers to adopt the pack.",
	},
	{
		"key": "pathfinding",
		"name": "Pathfinding",
		"here": "Two packs, by the kind of world: Nav Agent 3D over a navigation mesh, Platformer Pathfinding over a jump-and-fall graph.",
		"pack": "nav_agent_3d",
		"reading": "A path request followed by a per-tick step toward the next point reads as Find path / Move along path / On path finished.",
	},
	{
		"key": "tween",
		"name": "Tween",
		"here": "The Tween pack, over Godot's own Tween: move, scale, rotate or fade a property over a time, with an easing.",
		"pack": "tween",
		"reading": "A create_tween chain reads as ONE Tween row per property, however long the chain is.",
	},
	{
		"key": "timer",
		"name": "Timer",
		"here": "The Timer pack, over Godot's Timer node: start, stop, and On timer finished.",
		"pack": "timer",
		"reading": "A counted-down float in a tick reads as Start timer / On timer finished rather than as arithmetic.",
	},
	{
		"key": "persist",
		"name": "Persist",
		"here": "The Save System pack, whose reading is Remember Between Runs: what is remembered, and when it is written.",
		"pack": "save_system",
		"reading": "A config-file or JSON save-and-load pair reads as Remember / Restore rows addressed by name.",
	},
	{
		"key": "no-save",
		"name": "No save",
		"here": "The opt-out of Remember Between Runs: a variable marked not remembered is simply left out of the save.",
		"pack": "save_system",
		"reading": "A variable that the save writer skips reads as not remembered, on the variable's own row.",
	},
	{
		"key": "scroll-to",
		"name": "Scroll To",
		"here": "No pack needed: a Camera2D, or the Follow pack when the camera should chase a node with a lag.",
		"pack": "follow",
		"reading": "A camera position lerped toward a target each tick reads as Follow, on one row.",
	},
	{
		"key": "physics",
		"name": "Physics",
		"here": "What a body IS here: a RigidBody2D or RigidBody3D. Forces and impulses are its own actions - nothing is attached.",
		"pack": "",
		"reading": "The head names the body; apply_impulse and friends read as the body's own actions.",
	},
	{
		"key": "car",
		"name": "Car",
		"here": "Two packs, by the kind of driving: Car for the steer-and-drive feel, Physics Car for a wheeled rigid body.",
		"pack": "car",
		"reading": "A steering angle folded into a heading, then a move along it, reads as the Car rows.",
	},
	{
		"key": "orbit",
		"name": "Orbit",
		"here": "The Orbit pack (2D and 3D): circle a centre at a radius and a rate.",
		"pack": "orbit",
		"reading": "A tick that advances an angle and writes centre + polar offset reads as Orbit around.",
	},
	{
		"key": "tile-movement",
		"name": "Tile movement",
		"here": "The Tile Movement pack: step from cell to cell on a grid, one press at a time.",
		"pack": "tile_movement",
		"reading": "A snap-to-grid step with a blocked test reads as Step to cell / Is moving / On step finished.",
	},
	{
		"key": "custom-movement",
		"name": "Custom movement",
		"here": "No pack: the free movement words. Set velocity, Move by, Move toward, Look at - the actions every object already has.",
		"pack": "",
		"reading": "Movement written by hand stays exactly what it is: one action per row, in the words of the property it writes.",
	},
	{
		"key": "shadow-caster",
		"name": "Shadow caster",
		"here": "No pack needed: Godot's own 2D shadows. A LightOccluder2D casts, and the light decides what is lit.",
		"pack": "",
		"reading": "The occluder is a child node in the head, not a row.",
	},
	{
		"key": "shadow-light",
		"name": "Shadow light",
		"here": "No pack needed: a PointLight2D or DirectionalLight2D with shadows enabled.",
		"pack": "",
		"reading": "The light is a child node in the head; its colour, energy and range read as Object properties.",
	},
]


## Every behavior, in reading order. A copy, so a caller that sorts or filters cannot edit the
## table.
static func entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entry: Dictionary in BEHAVIORS:
		out.append(entry.duplicate(true))
	return out


## One behavior by its key, or an empty Dictionary. The lookup behind "reference:behaviors/<key>".
static func entry(key: String) -> Dictionary:
	var wanted: String = key.strip_edges().to_lower()
	for behavior: Dictionary in BEHAVIORS:
		if str(behavior.get("key", "")) == wanted:
			return behavior.duplicate(true)
	return {}


## The behaviors whose name or explanation mentions `query`, best first: the name itself before the
## sentence it is explained in, so typing "bullet" answers with Bullet rather than with every entry
## that happens to say "bullet".
static func find(query: String) -> Array[Dictionary]:
	var wanted: String = query.strip_edges().to_lower()
	if wanted.is_empty():
		return entries()
	var exact: Array[Dictionary] = []
	var partial: Array[Dictionary] = []
	for behavior: Dictionary in BEHAVIORS:
		var name_text: String = str(behavior.get("name", "")).to_lower()
		if name_text.begins_with(wanted):
			exact.append(behavior.duplicate(true))
			continue
		if name_text.contains(wanted) or str(behavior.get("here", "")).to_lower().contains(wanted):
			partial.append(behavior.duplicate(true))
	exact.append_array(partial)
	return exact


## The reference id of the pack page a behavior hands the reader on to, or "" when Godot already
## does the job and there is no pack to open. Built through EventSheetDocReference's own scheme so
## the two can never drift apart.
static func pack_page_for(key: String) -> String:
	var behavior: Dictionary = entry(key)
	var pack: String = str(behavior.get("pack", "")).strip_edges()
	if pack.is_empty():
		return ""
	return EventSheetDocReference.doc_id(EventSheetDocReference.KIND_PACK, pack)


## The whole index as page blocks, in the shape the page view draws: the title, the lead, then one
## chapter per behavior. Pure, so the suite pins the page's structure without a window.
static func blocks() -> Array[Dictionary]:
	var blocks: Array[Dictionary] = [
		{"kind": "heading", "level": 1, "text": PAGE_TITLE, "bbcode": PAGE_TITLE,
			"slug": EventSheetDocMarkdown.slug(PAGE_TITLE)},
		{"kind": "paragraph", "bbcode": EventSheetDocMarkdown.escape_brackets(PAGE_LEAD)},
	]
	for behavior: Dictionary in BEHAVIORS:
		var key: String = str(behavior.get("key", ""))
		var name_text: String = str(behavior.get("name", ""))
		blocks.append({"kind": "heading", "level": 2, "text": name_text, "bbcode": name_text,
			"slug": key})
		blocks.append({"kind": "paragraph",
			"bbcode": EventSheetDocMarkdown.escape_brackets(str(behavior.get("here", "")))})
		var reading: String = str(behavior.get("reading", "")).strip_edges()
		if not reading.is_empty():
			blocks.append({"kind": "quote", "bbcode": EventSheetDocMarkdown.escape_brackets(reading)})
		var page: String = pack_page_for(key)
		if not page.is_empty():
			blocks.append({"kind": "paragraph", "bbcode": "[url=%s]%s[/url]" % [page,
				EventSheetDocMarkdown.escape_brackets(
					"Open the %s reference" % EventSheetDocReference.pack_title(
						str(behavior.get("pack", ""))))]})
	return blocks
