# Godot EventSheets - a noun in a comment is a door when the project can prove it exists.
#
# Everything worth pinning here is a VALUE: which words of a sentence become doors, which kind each
# one is, where it leads, and - the promise that has to hold whatever the editor draws - that the
# comment's own text and the line the compiler writes are untouched by any of it.
#
# The two halves are pinned apart, because they fail for different reasons. `doors_in` is pure: a
# line and a table go in, a list of offsets comes out, and no project is needed to ask it. The table
# itself is the join of five indexes, and it is pinned through the same seam the editor asks -
# EventSheetCompletions - with a scene injected and a sheet built by hand.
@tool
class_name CommentDoorsTest
extends RefCounted

const Pins := preload("res://tests/pin_table.gd")


static func run() -> bool:
	var ok: bool = _test_a_proven_noun_is_a_door()
	ok = _test_prose_that_proves_nothing_stays_prose() and ok
	ok = _test_a_state_spelled_as_two_words_is_one_door() and ok
	ok = _test_a_name_two_files_answer_to_is_not_a_door() and ok
	ok = _test_the_first_claim_on_a_name_wins() and ok
	ok = _test_the_table_is_held_until_an_index_is_rebuilt() and ok
	ok = _test_the_comment_and_the_line_it_writes_are_untouched() and ok
	ok = _test_a_door_is_measured_on_the_line_it_wrapped_onto() and ok
	return ok


## An object with five states, a mode, a published function, and a scene holding one plain node and
## one uniquely named one - one of everything a door can be.
##
## Two of the states are DELIBERATELY three letters and perfectly ordinary English: Run and Hit are
## as much a state name as Patrol is, and a threshold that let them through underlined the words in
## "Run the game before shipping" and "Hit points go here" as though they were references.
static func _sheet() -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.custom_class_name = "Enemy"
	sheet.host_class = "CharacterBody2D"
	var states: EnumRow = EnumRow.new()
	states.enum_name = EventSheetStateFacts.ENUM_NAME
	states.members = PackedStringArray(["PATROL", "CHASE", "GAVE_UP", "RUN", "HIT"])
	sheet.events.append(states)
	var published: EventFunction = EventFunction.new()
	published.function_name = "begin_chase"
	sheet.functions.append(published)
	return sheet


static func _scene() -> Node:
	var root := Node.new()
	root.name = "Enemy"
	var sprite := Node.new()
	sprite.name = "Sprite"
	root.add_child(sprite)
	sprite.owner = root
	var bar := Node.new()
	bar.name = "HealthBar"
	root.add_child(bar)
	bar.owner = root
	bar.unique_name_in_owner = true
	return root


## The table the editor really asks for, with the scene injected so the node index has something in
## it. Every cache both seams hold is dropped first: a cold table is the only one a pin can be sure
## it is looking at.
static func _live_table(sheet: EventSheetResource, scene_root: Node) -> Dictionary:
	EventSheetCompletions.clear_cache()
	EventSheetCommentDoors.clear_cache()
	EventSheetCompletions.scene_root_override = scene_root
	var table: Dictionary = EventSheetCommentDoors.table_for(sheet)
	return table


## Every door of one line, as "<kind>:<text>" - what it was called and what sort of thing it is, in
## the order the sentence says them.
static func _read(line: String, table: Dictionary) -> PackedStringArray:
	var said: PackedStringArray = PackedStringArray()
	for door: Dictionary in EventSheetCommentDoors.doors_in(line, table):
		said.append("%s:%s" % [str(door["kind"]), str(door["text"])])
	return said


## One sentence, read as the four things this project can prove and the several it cannot. The
## English around them is left exactly alone, which is the half that has to be true for the other
## half to be worth having.
static func _test_a_proven_noun_is_a_door() -> bool:
	var scene_root: Node = _scene()
	var table: Dictionary = _live_table(_sheet(), scene_root)
	var ok: bool = Pins.check("comment_doors", {
		"Patrol until %HealthBar drops, then begin_chase and hunt them down":
			PackedStringArray(["state:Patrol", "node:%HealthBar", "function:begin_chase"]),
		"the $Sprite flips when it turns around":
			PackedStringArray(["node:$Sprite"]),
		"PATROL is the one it opens in":
			PackedStringArray(["state:PATROL"]),
	}, func(line: String) -> Variant: return _read(line, table))
	# And the door SAYS where it leads, which is the whole difference between an underline and a
	# jump: a state's target is the enum member a declaration can be found by, never the word.
	var doors: Array[Dictionary] = EventSheetCommentDoors.doors_in("back to Patrol", table)
	ok = Pins.check_value("comment_doors", "the state door carries the member it was declared as",
		str(doors[0].get("target", "")), "PATROL") and ok
	ok = Pins.check_value("comment_doors", "and the offsets are where the word really is",
		[int(doors[0]["start"]), int(doors[0]["length"])], [8, 6]) and ok
	EventSheetCompletions.scene_root_override = null
	scene_root.free()
	return ok


## The rule in the other direction, and the one that decides whether this is worth having at all: a
## word nothing answers for is prose. No mark, no message, no guess.
static func _test_prose_that_proves_nothing_stays_prose() -> bool:
	var scene_root: Node = _scene()
	var table: Dictionary = _live_table(_sheet(), scene_root)
	var ok: bool = Pins.check("comment_doors", {
		"the enemy wanders about for a while and then gives up": PackedStringArray(),
		# A name this project does not have, spelled exactly like one it might: still prose.
		"then Retreat until it is safe": PackedStringArray(),
		# A lone sigil is arithmetic or punctuation, not a reference to anything.
		"only 50% of the time, and $ is not a node": PackedStringArray(),
		# Two letters are inside too much ordinary English to be evidence of anything.
		"go up a bit": PackedStringArray(),
		# And so are three. Run, Hit, Die, Won, Fly and End are ordinary state names AND ordinary
		# words, so a threshold at three underlined prose in every note that used one of them.
		"Run the game before shipping": PackedStringArray(),
		"Hit points go here": PackedStringArray(),
	}, func(line: String) -> Variant: return _read(line, table))
	EventSheetCompletions.scene_root_override = null
	scene_root.free()
	return ok


## A declared state reads as WORDS ("Gave Up"), and a reader writes it that way in a note. So the
## phrase is one door rather than two half-doors or none - and a phrase glued to a longer word is
## not the state at all.
static func _test_a_state_spelled_as_two_words_is_one_door() -> bool:
	var scene_root: Node = _scene()
	var table: Dictionary = _live_table(_sheet(), scene_root)
	var ok: bool = Pins.check("comment_doors", {
		"it has Gave Up written all over it": PackedStringArray(["state:Gave Up"]),
		"GAVE_UP is the member behind it": PackedStringArray(["state:GAVE_UP"]),
		"Gave Upwards is nothing at all": PackedStringArray(),
	}, func(line: String) -> Variant: return _read(line, table))
	EventSheetCompletions.scene_root_override = null
	scene_root.free()
	return ok


## An ambiguous door is a guess, and a guess is the one thing this may not be: two files called the
## same thing means the name opens neither.
static func _test_a_name_two_files_answer_to_is_not_a_door() -> bool:
	var files: Array[Dictionary] = [
		{"text": "\"res://player/hud.gd\""},
		{"text": "\"res://menu/hud.gd\""},
		{"text": "\"res://game/spine.gd\""},
		{"text": "\"res://art/logo.png\""},
	]
	var table: Dictionary = EventSheetCommentDoors.build_table([[] as Array[Dictionary],
		[] as Array[Dictionary], [] as Array[Dictionary], [] as Array[Dictionary], files])
	return Pins.check("comment_doors", {
		"the rest is in hud.gd": PackedStringArray(),
		"the rest is in spine.gd": PackedStringArray(["file:spine.gd"]),
		"see logo.png for the mark": PackedStringArray(),
	}, func(line: String) -> Variant: return _read(line, table))


## Two indexes can hold the same name. Which one a door leads to is decided once, in the order the
## table is built, rather than by whichever list happened to be walked last.
static func _test_the_first_claim_on_a_name_wins() -> bool:
	var states: Array[Dictionary] = [{"text": "CHASE"}]
	var functions: Array[Dictionary] = [{"text": "Chase"}]
	var table: Dictionary = EventSheetCommentDoors.build_table([[] as Array[Dictionary],
		states, [] as Array[Dictionary], functions, [] as Array[Dictionary]])
	return Pins.check_value("comment_doors", "the state's word beats the function of the same name",
		_read("go back to Chase", table), PackedStringArray(["state:Chase"]))


## The performance contract, which is the reason this can run on every comment row of every rebuild:
## the table is built once and handed back, and it is rebuilt the moment any index underneath it is.
static func _test_the_table_is_held_until_an_index_is_rebuilt() -> bool:
	var sheet: EventSheetResource = _sheet()
	var scene_root: Node = _scene()
	var first: Dictionary = _live_table(sheet, scene_root)
	var ok: bool = Pins.check_value("comment_doors", "the second ask is the very same table",
		is_same(EventSheetCommentDoors.table_for(sheet), first), true)
	# The completion seam hands back fresh arrays once its own caches are dropped, and that is the
	# whole invalidation: nothing else has to be told.
	EventSheetCompletions.clear_cache()
	ok = Pins.check_value("comment_doors", "a dropped index rebuilds the table",
		is_same(EventSheetCommentDoors.table_for(sheet), first), false) and ok
	EventSheetCompletions.scene_root_override = null
	scene_root.free()
	return ok


## THE CONTRACT THAT OUTRANKS THE FEATURE. A door is something a reader is shown; it is not
## something the file knows about. The comment's own text is the same string after it has been read
## for doors, and the line the compiler writes is the same line it always was.
static func _test_the_comment_and_the_line_it_writes_are_untouched() -> bool:
	var scene_root: Node = _scene()
	var sheet: EventSheetResource = _sheet()
	var note: CommentRow = CommentRow.new()
	note.text = "Patrol until %HealthBar drops, then begin_chase"
	sheet.events.append(note)
	var before: String = note.text
	var table: Dictionary = _live_table(sheet, scene_root)
	var doors: Array[Dictionary] = EventSheetCommentDoors.doors_in(note.text, table)
	var ok: bool = Pins.check_value("comment_doors", "the sentence really did hold doors",
		doors.size(), 3)
	ok = Pins.check_value("comment_doors", "and the comment's text is the string it was",
		note.text, before) and ok
	sheet.external_source_path = "user://comment_doors_rt.gd"
	var emitted: String = str(SheetCompiler.compile(sheet, "user://comment_doors_rt.gd").get("output", ""))
	ok = Pins.check_value("comment_doors", "the emitted line is the plain comment it always was",
		emitted.contains("# Patrol until %HealthBar drops, then begin_chase"), true) and ok
	EventSheetCompletions.scene_root_override = null
	scene_root.free()
	return ok


## A door on a wrapped note is underlined on the visual line the word really landed on, and at the
## distance across THAT line rather than across the whole sentence. Measured against the break
## points the draw was made with, which is why they are handed in rather than worked out twice.
static func _test_a_door_is_measured_on_the_line_it_wrapped_onto() -> bool:
	var font: Font = ThemeDB.get_default_theme().default_font
	if font == null:
		print("[FAIL] comment_doors: no default font to measure a door with")
		return false
	var text: String = "one two Patrol"
	var doors: Array = [{"start": 8, "length": 6, "text": "Patrol",
		"kind": EventSheetCommentDoors.KIND_STATE, "target": "PATROL"}]
	var boxes: Array[Dictionary] = EventSheetCommentDoors.door_boxes(
		text, doors, PackedInt32Array([0, 8]), font, 14)
	var ok: bool = Pins.check_value("comment_doors", "the door is on the second visual line",
		int(boxes[0]["line"]), 1)
	ok = Pins.check_value("comment_doors", "and it starts at that line's own left edge",
		is_zero_approx(float(boxes[0]["x"])), true) and ok
	# A word the wrap cut in half is left alone: half an underline under half a word says less than
	# none, and the word is still perfectly readable prose.
	var straddling: Array[Dictionary] = EventSheetCommentDoors.door_boxes(
		text, doors, PackedInt32Array([0, 10]), font, 14)
	return Pins.check_value("comment_doors", "a door across a wrap break is not drawn",
		straddling.size(), 0) and ok
