# Godot EventSheets - saving what the player built, and the trust line that comes back with it.
#
# Two rows are under test and they are one story. A branch of the running game can be written out as
# a scene file - which is how a level editor, a base builder or a ship yard keeps what somebody made
# - and a scene file is the one format in the Files vocabulary that can carry BEHAVIOUR, because its
# resource table may name a script. So the writer ships with the question worth asking before
# anything reads one back, and with a Doctor check that notices when nobody asked.
#
# What is pinned here, in the order the failures actually happen:
#   1. THE VOCABULARY. Ids, category, hints, templates, and that every row and every parameter
#      carries real help - values, never counts. The editor-side twin is named in the writer's own
#      description, because two rows doing one job in two worlds have to say so.
#   2. THE OWNER WALK, which is the whole reason the writer is a row. The emitted lines are pinned,
#      and the write is registered as a write so the export trap and its one-click fix can see it.
#   3. THE QUESTION REALLY ANSWERS. The function the condition compiles to is run against real scene
#      files written for this test: one that is only data, one naming a script beside itself, one
#      carrying a script inside it, one naming the project's own script, and one that is not there.
#   4. THE HELPER LANDS ONCE. The compiler writes the definition into the file the first time any row
#      asks, skips it when the file already has it, and never moves a line above it.
#   5. THE LIFT, in both tails, with the boundary in the other direction: a bare pack-and-save with
#      no walk in front of it is a different program and is left as the code it is.
#   6. THE DOCTOR'S READING, pure over text: flagged unasked, quiet when asked, quiet about res://,
#      quiet about a path it cannot read.
#   7. THE QUIET AMBER STATE AND ITS DOOR. The finding hangs on the event, the door writes the
#      shipped question in front of the questions already there, and the finding then goes away.
@tool
class_name SceneTrustTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const FIXTURE_DIR: String = "res://tests/fixtures/"
const FIXTURE: String = "scene_save_branch.gd"

## Every ace_id this pass adds. Checked against the WHOLE registry, because an id is a compatibility
## promise the moment it ships and two descriptors answering to one id is a silent coin toss over
## which template a row compiles through.
const NEW_ACE_IDS: Array[String] = ["SaveBranchAsSceneFile", "SceneFileIsDataOnly"]

## Where the scene files this test writes and reads go. Under user://, which is the place a test may
## write, and cleaned up at the end of the run that made them.
const TEST_DIR: String = "user://_scene_trust_test"

## The two paths this test compiles TO, cleaned up beside the folder above for the same reason.
const COMPILE_OUTPUTS: Array[String] = [
	"user://_scene_trust_authored.gd", "user://_scene_trust_quiet.gd",
	"user://_scene_save_refusals.gd",
]


static func run() -> bool:
	var ok: bool = true
	ok = _test_descriptors() and ok
	ok = _test_the_owner_walk() and ok
	ok = _test_the_question_answers() and ok
	ok = _test_the_helper_lands_once() and ok
	ok = _test_the_lift() and ok
	ok = _test_the_doctors_reading() and ok
	ok = _test_the_row_state_and_its_door() and ok
	_clean_up()
	return ok


# ── 1. the vocabulary ───────────────────────────────────────────────────────────


static func _test_descriptors() -> bool:
	var ok: bool = true
	var counts: Dictionary = {}
	var missing_help: PackedStringArray = PackedStringArray()
	for descriptor: ACEDescriptor in ACERegistry.get_all_descriptors():
		if not NEW_ACE_IDS.has(descriptor.ace_id):
			continue
		counts[descriptor.ace_id] = int(counts.get(descriptor.ace_id, 0)) + 1
		if descriptor.description.strip_edges().is_empty():
			missing_help.append(descriptor.ace_id)
		for param: ACEParam in descriptor.params:
			if str(param.description).strip_edges().is_empty():
				missing_help.append("%s.%s" % [descriptor.ace_id, param.id])
	var absent: PackedStringArray = PackedStringArray()
	var duplicated: PackedStringArray = PackedStringArray()
	for ace_id: String in NEW_ACE_IDS:
		var seen: int = int(counts.get(ace_id, 0))
		if seen == 0:
			absent.append(ace_id)
		elif seen > 1:
			duplicated.append(ace_id)
	ok = _check("every new id is registered", absent, PackedStringArray()) and ok
	ok = _check("no new id collides with an existing one", duplicated, PackedStringArray()) and ok
	ok = _check("every new row and parameter carries real help", missing_help,
		PackedStringArray()) and ok

	var writer: ACEDescriptor = ACERegistry.find_descriptor("Core", "SaveBranchAsSceneFile")
	ok = _check("the writer is an action", writer.ace_type, ACEDescriptor.ACEType.ACTION) and ok
	ok = _check("filed on the Files page with the rest of the file vocabulary",
		writer.category, "Files") and ok
	ok = _check("and reads as a sentence", writer.get_display_text(),
		"save branch {branch} as scene file {path}") and ok
	ok = _check("its Save To field says its place under the box",
		writer.params[1].hint, EventForgeFilePlaces.PATH_HINT) and ok
	ok = _check("its branch defaults to the node the sheet is on",
		writer.params[0].default_value, "self") and ok
	ok = _check("and its file defaults to the player's own folder",
		EventForgeFilePlaces.place_of(writer.params[1].default_value),
		EventForgeFilePlaces.PLACE_USER) and ok
	# The editor-side twin, named in the writer's own words. Two rows do this one job, in two worlds,
	# and a reader who found one of them has to be told the other exists.
	ok = _check("the editor-side twin is named where the reader meets the game-side one",
		writer.description.contains("Save Node As Scene"), true) and ok
	ok = _check("and the editor-side twin is still exactly what it was",
		ACERegistry.find_descriptor("Core", "SaveNodeAsScene").codegen_template,
		"var __scene_{uid} = PackedScene.new()\n__scene_{uid}.pack({node})\nResourceSaver.save(__scene_{uid}, {path})") and ok

	var question: ACEDescriptor = ACERegistry.find_descriptor("Core", "SceneFileIsDataOnly")
	ok = _check("the question is a condition", question.ace_type,
		ACEDescriptor.ACEType.CONDITION) and ok
	ok = _check("it compiles to the one call every reader recognises the guard by",
		question.codegen_template, "%s({path})" % EventForgeSceneTrust.HELPER_NAME) and ok
	ok = _check("and reads as a sentence", question.get_display_text(),
		"scene file {path} is data-only") and ok
	ok = _check("its file field says its place under the box too",
		question.params[0].hint, EventForgeFilePlaces.PATH_HINT) and ok
	ok = _check("the row the door writes is the row that ships",
		EventForgeSceneTrust.GUARD_ACE_ID, question.ace_id) and ok
	ok = _check("and the door fills the field that row really has",
		question.params[0].id, EventForgeSceneTrust.GUARD_PARAM) and ok
	return ok


# ── 2. the owner walk ───────────────────────────────────────────────────────────


static func _test_the_owner_walk() -> bool:
	var writer: ACEDescriptor = ACERegistry.find_descriptor("Core", "SaveBranchAsSceneFile")
	var ok: bool = _check("the walk, the pack, the ownership given back and the write, in that order",
		writer.codegen_template,
		"var __branch_{uid}: Node = {branch}\n"
		+ "var __adopted_{uid}: Array[Node] = []\n"
		+ "for __part_{uid}: Node in __branch_{uid}.find_children(\"*\", \"\", true, false):\n"
		+ "\tif __part_{uid}.owner == null:\n"
		+ "\t\t__part_{uid}.owner = __branch_{uid}\n"
		+ "\t\t__adopted_{uid}.append(__part_{uid})\n"
		+ "var __scene_{uid} := PackedScene.new()\n"
		+ "var __packed_{uid} := __scene_{uid}.pack(__branch_{uid})\n"
		+ "for __lent_{uid}: Node in __adopted_{uid}:\n"
		+ "\t__lent_{uid}.owner = null\n"
		+ "if __packed_{uid} != OK:\n"
		+ "\tpush_error(\"Save Branch As Scene File: %s could not be packed (error %d).\" % [__branch_{uid}.name, __packed_{uid}])\n"
		+ "elif ResourceSaver.save(__scene_{uid}, {path}) != OK:\n"
		+ "\tpush_error(\"Save Branch As Scene File: nothing was written to %s.\" % {path})")
	# The walk asks for the children that are NOT already owned, and gives an owner only to those
	# that have none: a node belonging to an instanced scene keeps its own, which is what makes that
	# instance save as an instance instead of as a copy of its insides.
	ok = _check("the walk reaches the nodes nothing owns",
		writer.codegen_template.contains("find_children(\"*\", \"\", true, false)"), true) and ok
	ok = _check("and only gives an owner to a node that has none",
		writer.codegen_template.contains(".owner == null"), true) and ok
	# THE OWNERSHIP IS BORROWED, NOT TAKEN. Without the give-back, saving a branch and then a branch
	# ABOVE it writes the outer file truncated - the inner branch now owns the props, and pack() saves
	# only what the ROOT owns - with both engine calls answering OK and nothing reported anywhere.
	ok = _check("what the walk adopted is remembered",
		writer.codegen_template.contains("__adopted_{uid}.append(__part_{uid})"), true) and ok
	ok = _check("and handed back once the pack is done, so the row can be run twice",
		writer.codegen_template.contains("__lent_{uid}.owner = null"), true) and ok
	# A scene save IS a write, so the export trap and its one-click fix can both reach the row.
	ok = _check("the writer says which of its fields it writes to",
		EventForgeFilePlaces.write_params_of("SaveBranchAsSceneFile"),
		PackedStringArray(["path"])) and ok
	ok = _check("and a scene written to res:// is the export trap like any other write",
		EventSheetFilesDoctor.res_write_lines(
			"func _ready() -> void:\n\tResourceSaver.save(scene, \"res://built.tscn\")\n").size(),
		1) and ok
	# The question is a READ and is never reported as a write - the whole point of the write table.
	ok = _check("the question writes nothing",
		EventForgeFilePlaces.writes("SceneFileIsDataOnly"), false) and ok
	return ok


# ── 3. the question really answers ──────────────────────────────────────────────


## The scene files this test writes, each one a real `.tscn` a project could have on disk.
const DATA_ONLY_SCENE: String = "[gd_scene format=3]\n\n[node name=\"Level\" type=\"Node2D\"]\n"
## The crafted spellings. Godot's own parser TOKENISES a tag, so each of these loads the script it
## names while a reading built on `contains("type=\"Script\"")` answers true about it.
const SPACED_EQUALS_SCENE: String = "[gd_scene load_steps=2 format=3]\n\n[ext_resource type = \"Script\" path = \"user://_scene_trust_test/mod.gd\" id = \"1_a\"]\n\n[node name=\"Level\" type=\"Node2D\"]\nscript = ExtResource(\"1_a\")\n"
const TAG_OVER_TWO_LINES_SCENE: String = "[gd_scene load_steps=2 format=3]\n\n[ext_resource\ntype=\"Script\" path=\"user://_scene_trust_test/mod.gd\" id=\"1_a\"]\n\n[node name=\"Level\" type=\"Node2D\"]\nscript = ExtResource(\"1_a\")\n"
const CLIMBING_OUT_SCENE: String = "[gd_scene load_steps=2 format=3]\n\n[ext_resource type=\"Script\" path=\"res://../payload.gd\" id=\"1_a\"]\n\n[node name=\"Level\" type=\"Node2D\"]\n"
const OTHER_LANGUAGE_SCENE: String = "[gd_scene load_steps=2 format=3]\n\n[ext_resource type=\"CSharpScript\" path=\"user://_scene_trust_test/mod.cs\" id=\"1_a\"]\n\n[node name=\"Level\" type=\"Node2D\"]\n"
const NESTED_SCENE_SCENE: String = "[gd_scene load_steps=2 format=3]\n\n[ext_resource type=\"PackedScene\" path=\"user://_scene_trust_test/inner.tscn\" id=\"1_a\"]\n\n[node name=\"Level\" type=\"Node2D\"]\n"
const NESTED_RESOURCE_SCENE: String = "[gd_scene load_steps=2 format=3]\n\n[ext_resource type=\"Resource\" path=\"user://_scene_trust_test/loot.tres\" id=\"1_a\"]\n\n[node name=\"Level\" type=\"Node2D\"]\n"
const UNCLOSED_TAG_SCENE: String = "[gd_scene load_steps=2 format=3]\n\n[ext_resource type=\"Script\" path=\"res://player.gd\" id=\"1_a\"\n"
const PROJECT_SCENE_SCENE: String = "[gd_scene load_steps=2 format=3]\n\n[ext_resource type=\"PackedScene\" path=\"res://enemy.tscn\" id=\"1_a\"]\n\n[node name=\"Level\" type=\"Node2D\"]\n"
const OUTSIDE_SCRIPT_SCENE: String = "[gd_scene load_steps=2 format=3]\n\n[ext_resource type=\"Script\" path=\"user://_scene_trust_test/mod.gd\" id=\"1_a\"]\n\n[node name=\"Level\" type=\"Node2D\"]\nscript = ExtResource(\"1_a\")\n"
const PROJECT_SCRIPT_SCENE: String = "[gd_scene load_steps=2 format=3]\n\n[ext_resource type=\"Script\" uid=\"uid://abc\" path=\"res://player.gd\" id=\"1_a\"]\n\n[node name=\"Player\" type=\"Node2D\"]\nscript = ExtResource(\"1_a\")\n"
const EMBEDDED_SCRIPT_SCENE: String = "[gd_scene load_steps=2 format=3]\n\n[sub_resource type=\"GDScript\" id=\"1_a\"]\nscript/source = \"extends Node2D\"\n\n[node name=\"Level\" type=\"Node2D\"]\nscript = SubResource(\"1_a\")\n"
const NOT_A_SCENE: String = "just some text nobody wrote as a scene\n"
## THE BODY OF A NODE IS NOT A TAG, and the engine's value parser reads it all the same. Each of these
## two carries no `[ext_resource]` and no `[sub_resource]` line at all: the first hands the parser a
## path to LOAD, the second hands it an object to MAKE with source code inside it. Both were run
## before they were written down - each one built and ran its script on instantiate.
const BODY_RESOURCE_SCENE: String = "[gd_scene format=3]\n\n[node name=\"Level\" type=\"Node2D\"]\nscript = Resource(\"user://_scene_trust_test/mod.gd\")\n"
const BODY_OBJECT_SCENE: String = "[gd_scene format=3]\n\n[node name=\"Level\" type=\"Node2D\"]\nscript = Object(GDScript,\"script/source\":\"extends Node2D\")\n"
## THE ESCAPES. Godot's parser decodes what it finds in a tag; a reading that compares the letters as
## written does not. `\\u0053` is `S`, so the first names a `GDScript` that does not end in `Script`
## here; `\\u002e\\u002e` is `..`, so the second climbs out of the project while beginning with
## `res://`; and the third's escaped quote ends the tag early here and not there.
const ESCAPED_TYPE_TAIL_SCENE: String = "[gd_scene load_steps=2 format=3]\n\n[sub_resource type=\"GD\\u0053cript\" id=\"1_a\"]\nscript/source = \"extends Node2D\"\n\n[node name=\"Level\" type=\"Node2D\"]\n"
const ESCAPED_CLIMB_OUT_SCENE: String = "[gd_scene load_steps=2 format=3]\n\n[ext_resource type=\"Script\" path=\"res://\\u002e\\u002e/payload.gd\" id=\"1_a\"]\n\n[node name=\"Level\" type=\"Node2D\"]\n"
const ESCAPED_QUOTE_SCENE: String = "[gd_scene load_steps=2 format=3]\n\n[ext_resource type=\"Script\" path=\"res://ok.gd\\\"] \" id=\"1_a\"]\n\n[node name=\"Level\" type=\"Node2D\"]\n"
## THE LIMIT THE ANSWER STATES OUT LOUD. A cleared scene may still ask the GAME'S OWN code to run:
## a connection naming one of your methods with its own arguments in `binds`, or a placeholder that
## loads another scene when somebody calls `create_instance()`. Neither brings a stranger's code in,
## both are still somebody else's data, and the answer is true - which is why the row, the guide and
## the helper all say what "data-only" does not cover.
const CONNECTION_WITH_BINDS_SCENE: String = "[gd_scene format=3]\n\n[node name=\"Level\" type=\"Node2D\"]\n\n[node name=\"Button\" type=\"Button\" parent=\".\"]\n\n[connection signal=\"pressed\" from=\"Button\" to=\".\" method=\"spend\" binds= [999]]\n"


static func _test_the_question_answers() -> bool:
	var asking: Object = _the_question_as_a_running_function()
	if asking == null:
		print("[FAIL] scene_trust_test: the emitted question does not parse")
		return false
	DirAccess.make_dir_recursive_absolute(TEST_DIR)
	var ok: bool = _check("a scene that is only data answers true",
		asking.call(EventForgeSceneTrust.HELPER_NAME, _written("data_only.tscn", DATA_ONLY_SCENE)),
		true)
	ok = _check("a scene naming a script beside itself in the player's folder answers false",
		asking.call(EventForgeSceneTrust.HELPER_NAME,
			_written("outside_script.tscn", OUTSIDE_SCRIPT_SCENE)), false) and ok
	ok = _check("a scene carrying a script inside it answers false",
		asking.call(EventForgeSceneTrust.HELPER_NAME,
			_written("embedded_script.tscn", EMBEDDED_SCRIPT_SCENE)), false) and ok
	ok = _check("a scene naming this project's own script answers true",
		asking.call(EventForgeSceneTrust.HELPER_NAME,
			_written("project_script.tscn", PROJECT_SCRIPT_SCENE)), true) and ok
	ok = _check("a file that is not a scene at all answers false",
		asking.call(EventForgeSceneTrust.HELPER_NAME,
			_written("not_a_scene.tscn", NOT_A_SCENE)), false) and ok
	ok = _check("and a file that is not there answers false - unreadable is not cleared",
		asking.call(EventForgeSceneTrust.HELPER_NAME,
			"%s/nothing_here.tscn" % TEST_DIR), false) and ok

	# THE CRAFTED SPELLINGS. The threat this question exists for is a HAND-WRITTEN file, so "Godot
	# writes it the other way" is not an answer: every one of these parses as the tag it looks like
	# and loads the script it names.
	ok = _check("spaces around the equals do not get a script past it",
		asking.call(EventForgeSceneTrust.HELPER_NAME,
			_written("spaced_equals.tscn", SPACED_EQUALS_SCENE)), false) and ok
	ok = _check("nor does a tag broken over two lines",
		asking.call(EventForgeSceneTrust.HELPER_NAME,
			_written("two_line_tag.tscn", TAG_OVER_TWO_LINES_SCENE)), false) and ok
	ok = _check("a res:// path that climbs out of the project is not the project's own",
		asking.call(EventForgeSceneTrust.HELPER_NAME,
			_written("climbing_out.tscn", CLIMBING_OUT_SCENE)), false) and ok
	ok = _check("a script in the engine's other language is a script",
		asking.call(EventForgeSceneTrust.HELPER_NAME,
			_written("other_language.tscn", OTHER_LANGUAGE_SCENE)), false) and ok
	ok = _check("a scene pointing at another scene outside the game answers false",
		asking.call(EventForgeSceneTrust.HELPER_NAME,
			_written("nested_scene.tscn", NESTED_SCENE_SCENE)), false) and ok
	ok = _check("and at a resource file outside the game too",
		asking.call(EventForgeSceneTrust.HELPER_NAME,
			_written("nested_resource.tscn", NESTED_RESOURCE_SCENE)), false) and ok
	ok = _check("a tag that never closes is unfamiliar, and unfamiliar is not cleared",
		asking.call(EventForgeSceneTrust.HELPER_NAME,
			_written("unclosed_tag.tscn", UNCLOSED_TAG_SCENE)), false) and ok
	ok = _check("while a scene naming the game's OWN scenes is the game running",
		asking.call(EventForgeSceneTrust.HELPER_NAME,
			_written("project_scene.tscn", PROJECT_SCENE_SCENE)), true) and ok

	# THE BODY OF A NODE. Neither of these writes a resource tag at all, and each one ran its script
	# on instantiate before it was written down here.
	ok = _check("a path handed to the value parser to LOAD, in a node's body, answers false",
		asking.call(EventForgeSceneTrust.HELPER_NAME,
			_written("body_resource.tscn", BODY_RESOURCE_SCENE)), false) and ok
	ok = _check("and an object made in a node's body with source code inside it answers false",
		asking.call(EventForgeSceneTrust.HELPER_NAME,
			_written("body_object.tscn", BODY_OBJECT_SCENE)), false) and ok

	# THE ESCAPES. The engine decodes them and this reading does not, so the two disagree about what
	# a type is called, where a path goes and where a tag ends.
	ok = _check("a type whose tail is spelled with an escape does not slip past the script check",
		asking.call(EventForgeSceneTrust.HELPER_NAME,
			_written("escaped_type_tail.tscn", ESCAPED_TYPE_TAIL_SCENE)), false) and ok
	ok = _check("nor a path whose two dots are spelled with escapes",
		asking.call(EventForgeSceneTrust.HELPER_NAME,
			_written("escaped_climb_out.tscn", ESCAPED_CLIMB_OUT_SCENE)), false) and ok
	ok = _check("nor a quote inside a value that would end the tag early here and not there",
		asking.call(EventForgeSceneTrust.HELPER_NAME,
			_written("escaped_quote.tscn", ESCAPED_QUOTE_SCENE)), false) and ok

	# AND THE WORD BOUNDARY IS THE WHOLE REASON THE HONEST PAIR STILL PASSES. `ExtResource(` holds
	# `Resource(` with a letter in front of it; the two scenes above that answer TRUE both use it.
	ok = _check("what the answer does NOT cover: a connection with binds is still data",
		asking.call(EventForgeSceneTrust.HELPER_NAME,
			_written("connection_binds.tscn", CONNECTION_WITH_BINDS_SCENE)), true) and ok
	return ok


# ── 4. the helper lands once ────────────────────────────────────────────────────


static func _test_the_helper_lands_once() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node"
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnReady"
	event.conditions.append(_authored_condition("SceneFileIsDataOnly",
		{"path": "\"user://built_level.tscn\""}))
	event.actions.append(_authored_action("SaveBranchAsSceneFile",
		{"branch": "self", "path": "\"user://built_level.tscn\""}, "a1"))
	sheet.events.append(event)
	# A second event asking the same question, so the count below is a count of definitions rather
	# than of rows: two askers must still leave one function.
	var again: EventRow = EventRow.new()
	again.trigger_provider_id = "Core"
	again.trigger_id = "OnProcess"
	again.conditions.append(_authored_condition("SceneFileIsDataOnly",
		{"path": "\"user://built_ship.tscn\""}))
	sheet.events.append(again)
	sheet.external_source_path = COMPILE_OUTPUTS[0]
	var output: String = str(SheetCompiler.compile(sheet, sheet.external_source_path).get("output", ""))
	var ok: bool = _check("the question compiles to the call it names",
		output.contains("if %s(\"user://built_level.tscn\"):" % EventForgeSceneTrust.HELPER_NAME),
		true)
	ok = _check("the walk the row writes is really in the file",
		output.contains("for __part_a1: Node in __branch_a1.find_children(\"*\", \"\", true, false):"),
		true) and ok
	ok = _check("and it is the ownerless children it gives an owner to",
		output.contains("if __part_a1.owner == null:") and output.contains("__part_a1.owner = __branch_a1"),
		true) and ok
	ok = _check("the definition lands exactly once however many rows ask",
		_times(output, EventForgeSceneTrust.helper_head()), 1) and ok
	ok = _check("and the whole file parses inside the host it is for",
		_parses("extends Node\n%s" % output), true) and ok
	# Reopening an emitted file and saving it again must not add a second definition: the one that is
	# already there reads back as an ordinary function and is re-emitted where it sits.
	var reopened: EventSheetResource = GDScriptImporter.new().import_external_source(
		output, true, COMPILE_OUTPUTS[0])
	reopened.external_source_path = COMPILE_OUTPUTS[0]
	var again_out: String = str(SheetCompiler.compile(
		reopened, reopened.external_source_path).get("output", ""))
	ok = _check("a file that already defines it gains no second copy",
		_times(again_out, EventForgeSceneTrust.helper_head()), 1) and ok
	ok = _check("and a sheet that never asks gains no definition at all",
		_times(_compiled_without_the_question(), EventForgeSceneTrust.helper_head()), 0) and ok
	return ok


# ── 5. the lift ─────────────────────────────────────────────────────────────────


static func _test_the_lift() -> bool:
	var sheet: EventSheetResource = _open(FIXTURE)
	var ok: bool = true
	var plain: ACEAction = _function_action(sheet, "save_the_level", 0)
	ok = _check("the hand-written walk, pack and save read as one row", _row_of(plain),
		"SaveBranchAsSceneFile") and ok
	ok = _check("with the branch and the file the file wrote", _params_of(plain),
		{"branch": "$Level", "path": "\"user://built_level.tscn\""}) and ok
	ok = _check("and the author's own words for the three locals baked on", _template_of(plain),
		"var branch := {branch}\n"
		+ "for part: Node in branch.find_children(\"*\", \"\", true, false):\n"
		+ "\tif part.owner == null:\n"
		+ "\t\tpart.owner = branch\n"
		+ "var scene := PackedScene.new()\n"
		+ "scene.pack(branch)\n"
		+ "ResourceSaver.save(scene, {path})") and ok

	var borrowed: ACEAction = _function_action(sheet, "save_the_room", 0)
	ok = _check("the run the row writes today reads back as the row", _row_of(borrowed),
		"SaveBranchAsSceneFile") and ok
	ok = _check("with its own values", _params_of(borrowed),
		{"branch": "$Level/Room", "path": "\"user://built_room.tscn\""}) and ok
	ok = _check("and the list and the give-back riding back out in the template",
		_template_of(borrowed).contains("__adopted_r1.append(__part_r1)")
			and _template_of(borrowed).contains("__lent_r1.owner = null"), true) and ok

	var answered: ACEAction = _function_action(sheet, "save_the_ship", 0)
	ok = _check("the tail the row itself writes is the same row", _row_of(answered),
		"SaveBranchAsSceneFile") and ok
	ok = _check("with its own values", _params_of(answered),
		{"branch": "$Ship", "path": "\"user://built_ship.tscn\""}) and ok
	ok = _check("and both failure answers riding back out in the template",
		_template_of(answered).contains("elif ResourceSaver.save(__scene_s1, {path}) != OK:"),
		true) and ok

	# THE BOUNDARY. A pack and a save with no walk in front of them saves a scene holding one node -
	# a different program - so it keeps the reading it had.
	ok = _check("a bare pack-and-save is not claimed",
		_function_row_ids(sheet, "pack_it_only").has("SaveBranchAsSceneFile"), false) and ok

	sheet.external_source_path = "user://_scene_save_roundtrip.gd"
	var output: String = str(SheetCompiler.compile(sheet, sheet.external_source_path).get("output", ""))
	ok = _check("%s comes back byte for byte" % FIXTURE, output, _source(FIXTURE)) and ok
	ok = _test_the_lift_refuses() and ok
	return ok


## THE RUN THE FAMILY MUST NOT CLAIM, and the reason it is a section rather than a line. Two things
## about this run are READ rather than matched - the branch and the path - so a stray space or a note
## inside either used to ride in, be trimmed off, and be written back as something the author did not
## type. That is not a local wrong: the re-emission gate above this one is per FUNCTION and per FILE,
## so a single run claimed a byte too loosely threw away every row of the file, which is what the
## second half of each pin below measures - an untouched line in ANOTHER function, still opening as
## the row it is.
static func _test_the_lift_refuses() -> bool:
	const CLEAN: String = "extends Sprite2D\n\n\nfunc save_it() -> void:\n\tvar branch := $Level\n\tfor part: Node in branch.find_children(\"*\", \"\", true, false):\n\t\tif part.owner == null:\n\t\t\tpart.owner = branch\n\tvar scene := PackedScene.new()\n\tscene.pack(branch)\n\tResourceSaver.save(scene, \"user://built.tscn\")\n\n\nfunc flash() -> void:\n\tmodulate = Color.RED\n"
	# One space, at the end of the branch the run opens on. Everything else is byte for byte the run
	# above it.
	const A_SPACE: String = "extends Sprite2D\n\n\nfunc save_it() -> void:\n\tvar branch := $Level \n\tfor part: Node in branch.find_children(\"*\", \"\", true, false):\n\t\tif part.owner == null:\n\t\t\tpart.owner = branch\n\tvar scene := PackedScene.new()\n\tscene.pack(branch)\n\tResourceSaver.save(scene, \"user://built.tscn\")\n\n\nfunc flash() -> void:\n\tmodulate = Color.RED\n"
	# A note after the branch, which the row has nowhere to put: it is not part of the expression, and
	# a row carrying it in its branch field would offer somebody their own comment to edit.
	const A_NOTE: String = "extends Sprite2D\n\n\nfunc save_it() -> void:\n\tvar branch := $Level  # the branch we write out\n\tfor part: Node in branch.find_children(\"*\", \"\", true, false):\n\t\tif part.owner == null:\n\t\t\tpart.owner = branch\n\tvar scene := PackedScene.new()\n\tscene.pack(branch)\n\tResourceSaver.save(scene, \"user://built.tscn\")\n\n\nfunc flash() -> void:\n\tmodulate = Color.RED\n"
	# THE SPELLING NEGATIVE. The row's own tail, with the two failures answered in the author's own
	# words rather than in the row's. Re-emitting it through the row would change what their game
	# prints, so it is somebody's code and stays that way.
	const OWN_WORDS: String = "extends Sprite2D\n\n\nfunc save_it() -> void:\n\tvar __branch_z9: Node = $Level\n\tfor __part_z9: Node in __branch_z9.find_children(\"*\", \"\", true, false):\n\t\tif __part_z9.owner == null:\n\t\t\t__part_z9.owner = __branch_z9\n\tvar __scene_z9 := PackedScene.new()\n\tvar __packed_z9 := __scene_z9.pack(__branch_z9)\n\tif __packed_z9 != OK:\n\t\tpush_error(\"could not pack it\")\n\telif ResourceSaver.save(__scene_z9, \"user://built.tscn\") != OK:\n\t\tpush_error(\"nothing written\")\n\n\nfunc flash() -> void:\n\tmodulate = Color.RED\n"
	# A hash inside a STRING is not a note, and the run that holds one is the row it always was.
	const A_HASH_IN_A_NAME: String = "extends Sprite2D\n\n\nfunc save_it() -> void:\n\tvar branch := get_node(\"Level#1\")\n\tfor part: Node in branch.find_children(\"*\", \"\", true, false):\n\t\tif part.owner == null:\n\t\t\tpart.owner = branch\n\tvar scene := PackedScene.new()\n\tscene.pack(branch)\n\tResourceSaver.save(scene, \"user://built.tscn\")\n"

	var clean: EventSheetResource = _opened(CLEAN)
	var ok: bool = _check("the run written exactly as the row writes it is the row",
		_function_row_ids(clean, "save_it"), PackedStringArray(["SaveBranchAsSceneFile"]))
	ok = _check("with the branch the file names", _params_of(_function_action(clean, "save_it", 0)),
		{"branch": "$Level", "path": "\"user://built.tscn\""}) and ok
	ok = _check("and the line in the function beside it reads as its own row",
		_function_row_ids(clean, "flash"), PackedStringArray(["SetModulate"])) and ok

	var spaced: EventSheetResource = _opened(A_SPACE)
	ok = _check("one trailing space in the branch and the run is not claimed at all",
		_function_row_ids(spaced, "save_it").has("SaveBranchAsSceneFile"), false) and ok
	ok = _check("and the refusal costs the function beside it nothing",
		_function_row_ids(spaced, "flash"), PackedStringArray(["SetModulate"])) and ok
	ok = _check("the file with the space in it still comes back byte for byte",
		_reemitted(spaced), A_SPACE) and ok

	var noted: EventSheetResource = _opened(A_NOTE)
	ok = _check("a note after the branch is not a value of the row",
		_function_row_ids(noted, "save_it").has("SaveBranchAsSceneFile"), false) and ok
	ok = _check("and the noted file comes back byte for byte",
		_reemitted(noted), A_NOTE) and ok

	var own: EventSheetResource = _opened(OWN_WORDS)
	ok = _check("a tail that reports failure in the author's own words is their code",
		_function_row_ids(own, "save_it").has("SaveBranchAsSceneFile"), false) and ok
	ok = _check("and that file comes back byte for byte too",
		_reemitted(own), OWN_WORDS) and ok

	var hashed: EventSheetResource = _opened(A_HASH_IN_A_NAME)
	ok = _check("a hash inside a node name is not a note, and the run is still the row",
		_function_row_ids(hashed, "save_it"),
		PackedStringArray(["SaveBranchAsSceneFile"])) and ok
	ok = _check("with the whole call as its branch",
		_params_of(_function_action(hashed, "save_it", 0)),
		{"branch": "get_node(\"Level#1\")", "path": "\"user://built.tscn\""}) and ok
	return ok


# ── 6. the Doctor's reading ─────────────────────────────────────────────────────


const UNASKED: String = "extends Node\n\n\nfunc _ready() -> void:\n\tvar __layout_a1 = load(\"user://mods/level.tscn\").instantiate()\n\tget_tree().root.add_child(__layout_a1)\n"
const ASKED: String = "extends Node\n\n\nfunc _ready() -> void:\n\tif __eventsheets_scene_is_data_only(\"user://mods/level.tscn\"):\n\t\tvar __layout_a1 = load(\"user://mods/level.tscn\").instantiate()\n\t\tget_tree().root.add_child(__layout_a1)\n"
const ASKED_ABOUT_ANOTHER: String = "extends Node\n\n\nfunc _ready() -> void:\n\tif __eventsheets_scene_is_data_only(\"user://mods/other.tscn\"):\n\t\tvar __layout_a1 = load(\"user://mods/level.tscn\").instantiate()\n\t\tget_tree().root.add_child(__layout_a1)\n"
const SHIPPED_SCENE: String = "extends Node\n\n\nfunc _ready() -> void:\n\tget_tree().change_scene_to_file(\"res://levels/one.tscn\")\n"
const BUILT_PATH: String = "extends Node\n\n\nfunc _ready() -> void:\n\tadd_child(load(chosen_path).instantiate())\n"
const NOT_A_SCENE_FILE: String = "extends Node\n\n\nfunc _ready() -> void:\n\tvar table = load(\"user://mods/loot.tres\")\n"
## A question MENTIONED is not a question ANSWERED. Both of these run the build on exactly the files
## the question refused, so both are the unguarded build they look like.
const GUARD_INVERTED: String = "extends Node\n\n\nfunc _ready() -> void:\n\tif not __eventsheets_scene_is_data_only(\"user://mods/level.tscn\"):\n\t\tadd_child(load(\"user://mods/level.tscn\").instantiate())\n"
const GUARD_ORED_AWAY: String = "extends Node\n\n\nfunc _ready() -> void:\n\tif debug_mode or __eventsheets_scene_is_data_only(\"user://mods/level.tscn\"):\n\t\tadd_child(load(\"user://mods/level.tscn\").instantiate())\n"
## Travelling to a layout builds it the same way any loader does, and the tree's own method is how
## every project writes it.
const TRAVELLED_TO: String = "extends Node\n\n\nfunc _ready() -> void:\n\tget_tree().change_scene_to_file(\"user://mods/level.tscn\")\n"


static func _test_the_doctors_reading() -> bool:
	var ok: bool = _check("a scene built from the player's folder with nobody asking is reported",
		EventSheetFilesDoctor.untrusted_scene_lines(UNASKED),
		PackedStringArray(["var __layout_a1 = load(\"user://mods/level.tscn\").instantiate()"]))
	ok = _check("the same build under the question is quiet",
		EventSheetFilesDoctor.untrusted_scene_lines(ASKED).size(), 0) and ok
	ok = _check("but a question about a DIFFERENT file guards nothing",
		EventSheetFilesDoctor.untrusted_scene_lines(ASKED_ABOUT_ANOTHER).size(), 1) and ok
	ok = _check("a scene the game shipped with is nobody's business",
		EventSheetFilesDoctor.untrusted_scene_lines(SHIPPED_SCENE).size(), 0) and ok
	ok = _check("a path built out of pieces is one this check says nothing about",
		EventSheetFilesDoctor.untrusted_scene_lines(BUILT_PATH).size(), 0) and ok
	ok = _check("and a file that is not a scene is a different question",
		EventSheetFilesDoctor.untrusted_scene_lines(NOT_A_SCENE_FILE).size(), 0) and ok
	ok = _check("a question asked and then INVERTED guards nothing",
		EventSheetFilesDoctor.untrusted_scene_lines(GUARD_INVERTED).size(), 1) and ok
	ok = _check("nor does one standing beside an or",
		EventSheetFilesDoctor.untrusted_scene_lines(GUARD_ORED_AWAY).size(), 1) and ok
	ok = _check("and travelling to a layout in the player's folder is a build like any other",
		EventSheetFilesDoctor.untrusted_scene_lines(TRAVELLED_TO),
		PackedStringArray(["get_tree().change_scene_to_file(\"user://mods/level.tscn\")"])) and ok
	ok = _check("a note beside the question is not part of it",
		EventForgeSceneTrust.guarded_paths(
			"if __eventsheets_scene_is_data_only(\"user://a.tscn\"):  # or ask the player").size(),
		1) and ok
	ok = _check("a loader of somebody's own is not the engine's",
		EventForgeSceneTrust.untrusted_scene_paths(
			"var s = MyResourceLoader.load(\"user://mods/level.tscn\")").size(), 0) and ok

	var filed: Array[Dictionary] = EventSheetFilesDoctor.untrusted_scene_findings(
		{"res://mods.gd": UNASKED})
	ok = _check("it is filed under its own id", filed.size() == 1
		and str(filed[0].get("check", "")) == EventSheetFilesDoctor.CHECK_UNTRUSTED_SCENE, true) and ok
	ok = _check("as a warning rather than an error - a game whose mods are code is a decision",
		str(filed[0].get("severity", "")), "warning") and ok
	ok = _check("naming the file the door will ask about",
		str(filed[0].get("subject", "")), "\"user://mods/level.tscn\"") and ok
	ok = _check("and saying what it cannot see, so silence is never read as an all-clear",
		str(filed[0].get("message", "")).contains("built out of pieces"), true) and ok
	# The sibling check in the same section is about a different half of the same story and must not
	# have started saying this one's sentence.
	ok = _check("the outside-content check beside it stays quiet about a literal nobody dropped",
		EventForgeOutsidePaths.loading_outside_lines(UNASKED).size(), 0) and ok
	ok = ok and _test_the_other_code_files()
	return ok


## THE LINE THE TWO CHECKS EACH LEFT TO THE OTHER. A literal `.gd`, `.tres` or `.res` under the
## player's folder, handed to a loader, with no door anywhere in the file: not a scene, so the
## reading above passes it by, and not a path the outside-content trace can follow, because nothing
## in the file dropped it, chose it, watched it or unpacked it. It used to earn nothing at all.
static func _test_the_other_code_files() -> bool:
	const SCRIPT_LOADED: String = "extends Node\n\n\nfunc _ready() -> void:\n\tvar mod = load(\"user://mods/hack.gd\")\n"
	const RESOURCE_LOADED: String = "extends Node\n\n\nfunc _ready() -> void:\n\tvar weapon = load(\"user://mods/weapon.tres\")\n"
	const BINARY_LOADED: String = "extends Node\n\n\nfunc _ready() -> void:\n\tvar pack = ResourceLoader.load(\"/opt/mods/pack.res\")\n"
	const SHIPPED_RESOURCE: String = "extends Node\n\n\nfunc _ready() -> void:\n\tvar weapon = load(\"res://data/weapon.tres\")\n"
	const READ_AS_DATA: String = "extends Node\n\n\nfunc _ready() -> void:\n\tvar text = FileAccess.get_file_as_string(\"user://mods/weapon.tres\")\n"
	var ok: bool = _check("a script loaded out of the player's folder is reported",
		EventSheetFilesDoctor.untrusted_code_file_lines(SCRIPT_LOADED),
		PackedStringArray(["var mod = load(\"user://mods/hack.gd\")"]))
	ok = _check("so is a resource file, which is a table that can name a script",
		EventSheetFilesDoctor.untrusted_code_file_lines(RESOURCE_LOADED).size(), 1) and ok
	ok = _check("and the binary form of one, named on a path from one computer",
		EventSheetFilesDoctor.untrusted_code_file_lines(BINARY_LOADED).size(), 1) and ok
	ok = _check("a resource the game shipped with is nobody's business",
		EventSheetFilesDoctor.untrusted_code_file_lines(SHIPPED_RESOURCE).size(), 0) and ok
	ok = _check("and reading the same file as TEXT brings no behaviour with it",
		EventSheetFilesDoctor.untrusted_code_file_lines(READ_AS_DATA).size(), 0) and ok
	# The two readings share a corpus and must not say each other's sentence about one line.
	ok = _check("the scene reading says nothing about a .tres",
		EventSheetFilesDoctor.untrusted_scene_lines(RESOURCE_LOADED).size(), 0) and ok
	ok = _check("and this one says nothing about a .tscn",
		EventSheetFilesDoctor.untrusted_code_file_lines(UNASKED).size(), 0) and ok

	# THE res:// PREFIX IS NOT A PROMISE. A literal that climbs out of the project begins with the
	# scheme that means the game's own files and names a file beside the project - which is the very
	# shape the emitted question already refuses inside a scene table, so the reading that decides
	# whether to ask it has to refuse one too.
	const CLIMBED_OUT_SCRIPT: String = "extends Node


func _ready() -> void:
	var mod = load(\"res://../payload.gd\")
"
	const CLIMBED_OUT_SCENE: String = "extends Node


func _ready() -> void:
	add_child(load(\"res://../payload.tscn\").instantiate())
"
	# The two that are containers rather than tables, and the call that mounts one over res://.
	const NATIVE_LIBRARY: String = "extends Node


func _ready() -> void:
	var lib = load(\"user://mods/speed.gdextension\")
"
	const PACK_MOUNTED: String = "extends Node


func _ready() -> void:
	ProjectSettings.load_resource_pack(\"user://mods/extra.pck\")
"
	const SHIPPED_PACK: String = "extends Node


func _ready() -> void:
	ProjectSettings.load_resource_pack(\"res://dlc/extra.pck\")
"
	ok = _check("a script reached by climbing out of res:// is reported",
		EventSheetFilesDoctor.untrusted_code_file_lines(CLIMBED_OUT_SCRIPT).size(), 1) and ok
	ok = _check("and so is a scene reached the same way",
		EventSheetFilesDoctor.untrusted_scene_lines(CLIMBED_OUT_SCENE).size(), 1) and ok
	ok = _check("a native library out of the player's folder is reported",
		EventSheetFilesDoctor.untrusted_code_file_lines(NATIVE_LIBRARY).size(), 1) and ok
	ok = _check("and a pack mounted over the game's own files from there",
		EventSheetFilesDoctor.untrusted_code_file_lines(PACK_MOUNTED),
		PackedStringArray(["ProjectSettings.load_resource_pack(\"user://mods/extra.pck\")"])) and ok
	ok = _check("while the game's own downloadable content is nobody's business",
		EventSheetFilesDoctor.untrusted_code_file_lines(SHIPPED_PACK).size(), 0) and ok

	var filed: Array[Dictionary] = EventSheetFilesDoctor.untrusted_code_file_findings(
		{"res://mods.gd": SCRIPT_LOADED})
	ok = _check("it is filed under its own id", filed.size() == 1
		and str(filed[0].get("check", "")) == EventSheetFilesDoctor.CHECK_UNTRUSTED_CODE_FILE,
		true) and ok
	ok = _check("as a warning rather than an error, exactly as its sibling is",
		str(filed[0].get("severity", "")), "warning") and ok
	ok = _check("naming the file that is loaded", str(filed[0].get("subject", "")),
		"\"user://mods/hack.gd\"") and ok
	ok = _check("and saying there is no question to ask about this one",
		str(filed[0].get("message", "")).contains(EventSheetL10n.translate(
			"There is no question to ask first about these the way there is about a scene file, because the file being read is not a scene. Read it as DATA instead - Read Text File (or a fallback) for text, Table From File for rows and columns, JSON for a structure - or, if this game means to run code its players wrote, say so where they can read it.")),
		true) and ok
	return ok


# ── 7. the quiet amber state, and its door ──────────────────────────────────────


static func _test_the_row_state_and_its_door() -> bool:
	var sheet: EventSheetResource = _sheet_that_builds_a_mod()
	var event: EventRow = sheet.events[0]
	var found: Array[Dictionary] = EventSheetSceneTrustFindings.findings(sheet, "res://mods.gd")
	var ok: bool = _check("the sheet earns exactly one note", found.size(), 1)
	if not ok:
		return false
	ok = _check("filed under the id the Doctor files it under",
		str(found[0].get("kind", "")), EventSheetFilesDoctor.CHECK_UNTRUSTED_SCENE) and ok
	ok = _check("anchored at the event that builds it",
		EventSheetSceneTrustFindings.for_event(found, event).size(), 1) and ok
	ok = _check("naming the file, which is what the door needs",
		str(found[0].get("subject", "")), "\"user://mods/level.tscn\"") and ok
	ok = _check("and offering the question as its one door",
		str(found[0].get("fix", "")), EventSheetSceneTrustFindings.FIX_ASK_FIRST) and ok
	ok = _check("the receipt says the file and the question that would be asked about it",
		EventSheetSceneTrustFindings.receipt(sheet),
		[{"before": "\"user://mods/level.tscn\"",
			"after": "%s(\"user://mods/level.tscn\")" % EventForgeSceneTrust.HELPER_NAME}]) and ok

	var written: int = EventSheetSceneTrustFindings.guard_scene_loads(sheet)
	ok = _check("the door writes one question", written, 1) and ok
	ok = _check("as an ordinary condition row, in front of the ones already there",
		[str((event.conditions[0] as Resource).get("ace_id")),
			str((event.conditions[1] as Resource).get("ace_id"))],
		[EventForgeSceneTrust.GUARD_ACE_ID, "IsPaused"]) and ok
	ok = _check("over the very file the row builds",
		((event.conditions[0] as Resource).get("params") as Dictionary),
		{EventForgeSceneTrust.GUARD_PARAM: "\"user://mods/level.tscn\""}) and ok
	ok = _check("and the note is gone, because the sheet really did change",
		EventSheetSceneTrustFindings.findings(sheet, "res://mods.gd").size(), 0) and ok
	ok = _check("asking twice writes nothing the second time",
		EventSheetSceneTrustFindings.guard_scene_loads(sheet), 0) and ok

	# A question asked by a PARENT event stands over the rows beneath it - which is what the emitted
	# `if` inside an `if` really does, and what the Doctor's own walk out through the blocks reads.
	var nested: EventSheetResource = _sheet_that_asks_above_and_builds_below()
	ok = _check("a question on the event above guards the sub-event under it",
		EventSheetSceneTrustFindings.findings(nested, "res://mods.gd").size(), 0) and ok

	# The same sheet with the same question INVERTED: the body then runs on exactly the files the
	# question refused, so the amber state is earned again. The canvas and the Doctor read the guard
	# through one function, which is what keeps these two answers the same answer.
	var flipped: EventSheetResource = _sheet_that_asks_above_and_builds_below()
	((flipped.events[0] as EventRow).conditions[0] as ACECondition).negated = true
	ok = _check("but the same question, inverted, guards nothing",
		EventSheetSceneTrustFindings.findings(flipped, "res://mods.gd").size(), 1) and ok
	var turned_off: EventSheetResource = _sheet_that_asks_above_and_builds_below()
	((turned_off.events[0] as EventRow).conditions[0] as ACECondition).enabled = false
	ok = _check("and a question that is turned off asks nothing at all",
		EventSheetSceneTrustFindings.findings(turned_off, "res://mods.gd").size(), 1) and ok
	return ok


## A sheet with one event that builds a scene out of the player's folder, with an unrelated question
## already on it - so the door's insert is measured against a lane that is not empty.
static func _sheet_that_builds_a_mod() -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node"
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnReady"
	event.conditions.append(_authored_condition("IsPaused", {}))
	event.actions.append(_authored_action("AddLayoutOnTop",
		{"path": "\"user://mods/level.tscn\"", "layout_name": "\"Mod\""}, "a1"))
	sheet.events.append(event)
	return sheet


## The same build, one level down, under an event that already asks about that same file.
static func _sheet_that_asks_above_and_builds_below() -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node"
	var outer: EventRow = EventRow.new()
	outer.trigger_provider_id = "Core"
	outer.trigger_id = "OnReady"
	outer.conditions.append(_authored_condition("SceneFileIsDataOnly",
		{"path": "\"user://mods/level.tscn\""}))
	var inner: EventRow = EventRow.new()
	inner.actions.append(_authored_action("AddLayoutOnTop",
		{"path": "\"user://mods/level.tscn\"", "layout_name": "\"Mod\""}, "b2"))
	outer.sub_events.append(inner)
	sheet.events.append(outer)
	return sheet


# ── helpers ─────────────────────────────────────────────────────────────────────


## The question the condition compiles to, as a real function this test can call. Built from the ONE
## definition the compiler writes, so what runs here is what runs in somebody's game.
static func _the_question_as_a_running_function() -> Object:
	var lines: PackedStringArray = PackedStringArray(["extends RefCounted", "",
		EventForgeSceneTrust.helper_head()])
	for line: String in EventForgeSceneTrust.helper_body():
		lines.append(str(line))
	var script := GDScript.new()
	script.source_code = "\n".join(lines) + "\n"
	return null if script.reload() != OK else script.new()


## One scene file on disk, written for this test, and the path it landed at.
static func _written(file_name: String, text: String) -> String:
	DirAccess.make_dir_recursive_absolute(TEST_DIR)
	var path: String = "%s/%s" % [TEST_DIR, file_name]
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(text)
		file.close()
	return path


## Everything this test wrote, taken away with it. The two scripts are the OUTPUT of a compile,
## which lands where the compile was told to write it - beside the folder rather than inside it - so
## sweeping the folder alone left them on the machine that ran the suite.
static func _clean_up() -> void:
	for compiled: String in COMPILE_OUTPUTS:
		if FileAccess.file_exists(compiled):
			DirAccess.remove_absolute(compiled)
	if not DirAccess.dir_exists_absolute(TEST_DIR):
		return
	for file_name: String in DirAccess.get_files_at(TEST_DIR):
		DirAccess.remove_absolute("%s/%s" % [TEST_DIR, file_name])
	DirAccess.remove_absolute(TEST_DIR)


## A sheet that asks nothing, compiled - the proof that a project which never asks the question
## gains nothing at all.
static func _compiled_without_the_question() -> String:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node"
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnReady"
	event.actions.append(_authored_action("SaveBranchAsSceneFile",
		{"branch": "self", "path": "\"user://built_level.tscn\""}, "c3"))
	sheet.events.append(event)
	sheet.external_source_path = COMPILE_OUTPUTS[1]
	return str(SheetCompiler.compile(sheet, sheet.external_source_path).get("output", ""))


static func _times(text: String, needle: String) -> int:
	var seen: int = 0
	var at: int = text.find(needle)
	while at >= 0:
		seen += 1
		at = text.find(needle, at + needle.length())
	return seen


static func _parses(source: String) -> bool:
	var script := GDScript.new()
	script.source_code = source
	return script.reload() == OK


static func _source(file_name: String) -> String:
	return FileAccess.get_file_as_string(FIXTURE_DIR + file_name)


static func _open(file_name: String) -> EventSheetResource:
	var path: String = FIXTURE_DIR + file_name
	return GDScriptImporter.new().import_external_source(_source(file_name), true, path)


## A source string opened as a sheet. Used where the thing under test is a SPELLING rather than a
## file - a stray space survives a string literal and does not survive every editor a fixture passes
## through, so the runs that must not be claimed are written here rather than committed as files.
static func _opened(source: String) -> EventSheetResource:
	return GDScriptImporter.new().import_external_source(source, true, COMPILE_OUTPUTS[2])


## The same sheet written back out. The byte comparison is the point: a run this family refuses is
## still every byte the author typed, because a refusal leaves the statements exactly as they are.
static func _reemitted(sheet: EventSheetResource) -> String:
	sheet.external_source_path = COMPILE_OUTPUTS[2]
	return str(SheetCompiler.compile(sheet, sheet.external_source_path).get("output", ""))


## A row the SHEET authored. `uid` bakes the per-row id of a template that declares locals, which is
## what the dock does at apply time and what nothing downstream does for it.
static func _authored_action(ace_id: String, params: Dictionary, uid: String) -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = ace_id
	action.params = params
	action.codegen_template = ACERegistry.find_descriptor(
		"Core", ace_id).codegen_template.replace("{uid}", uid)
	return action


static func _authored_condition(ace_id: String, params: Dictionary) -> ACECondition:
	var condition: ACECondition = ACECondition.new()
	condition.provider_id = "Core"
	condition.ace_id = ace_id
	condition.params = params
	return condition


static func _function_of(sheet: EventSheetResource, function_name: String) -> EventFunction:
	for entry: Variant in sheet.functions:
		if entry is EventFunction and (entry as EventFunction).function_name == function_name:
			return entry as EventFunction
	return null


## The nth ACE action of a lifted function's body, counting across its rows in order.
static func _function_action(sheet: EventSheetResource, function_name: String,
		index: int) -> ACEAction:
	var found: Array[ACEAction] = []
	var event_function: EventFunction = _function_of(sheet, function_name)
	if event_function != null:
		for row: Variant in event_function.events:
			if row is EventRow:
				for action: Variant in (row as EventRow).actions:
					if action is ACEAction:
						found.append(action as ACEAction)
	return found[index] if index < found.size() else null


static func _function_row_ids(sheet: EventSheetResource,
		function_name: String) -> PackedStringArray:
	var ids: PackedStringArray = PackedStringArray()
	var index: int = 0
	while true:
		var action: ACEAction = _function_action(sheet, function_name, index)
		if action == null:
			break
		ids.append(action.ace_id)
		index += 1
	return ids


static func _row_of(action: ACEAction) -> String:
	return action.ace_id if action != null else "(no row)"


static func _params_of(action: ACEAction) -> Dictionary:
	return action.params if action != null else {}


static func _template_of(action: ACEAction) -> String:
	return action.codegen_template if action != null else "(no row)"


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check("scene_trust_test", label, actual, expected)
