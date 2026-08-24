# Godot EventSheets - the five ways a light silently does nothing.
#
# L8. Lighting is the part of a game that fails without saying anything: the node is in the scene,
# the row runs, no error is printed, and the screen does not change. These five are the reasons, and
# every one of them is a fact somebody can already see before the game runs:
#
#   no texture to cast        - a 2D point light lights the shape of its texture, and it has none.
#   nothing blocks the shadow - shadows are on and no occluder's mask matches, so none is ever drawn.
#   dark with nothing lit     - the layer is darkened and no light reaches it: none at all, or none
#                               whose RANGE mask covers what is drawn on it.
#   a world that is not there - the sheet writes the environment and the scene has no WorldEnvironment.
#   a shared environment      - the sheet writes a `.tres` other scenes load, so the change follows
#                               the player out of the room. One click gives the scene its own copy.
#
# THE SPLIT. The first three are facts of a SCENE and are found without a sheet at all, because a
# scene whose lighting is broken is broken whether or not anybody wrote a row about it. The last two
# are about the ROWS, so they carry the event they are about and appear as notes under it, exactly as
# the variable and networking notes do.
#
# NOTHING IS STORED. Every finding is derived from the `.tscn` and the rows on every ask, so a fixed
# scene stops reporting with nothing to clean up, and a project with no lighting in it gets none.
#
# PURE + STATIC: no viewport, no dialog, no display server, so every word is pinned headless.
@tool
class_name EventSheetLightingFindings
extends RefCounted

## The five findings, by id. Frozen: the note rows, the Doctor and the tests address one by these.
const KIND_NO_TEXTURE := "light-without-a-texture"
const KIND_NO_OCCLUDER := "shadows-nothing-blocks"
const KIND_NO_LIGHT := "darkness-without-light"
const KIND_NO_ENVIRONMENT := "environment-without-a-world"
const KIND_SHARED_ENVIRONMENT := "environment-shared-with-other-scenes"

## The one-click repair a note offers. Only one of the five has a single step to take: the other four
## are a texture to draw, an occluder to place, a mask to fix and a node to add, and none of those is
## a line this can write on somebody's behalf.
const FIX_OWN_ENVIRONMENT := "own_environment"

## Where a finding hangs: under the event whose row has the problem, or nowhere in the sheet at all
## (a scene fact, which the head band and the Doctor report say instead).
const ANCHOR_EVENT := "event"
const ANCHOR_SCENE := "scene"

## The row the one-click fix writes, and the vocabulary it comes from. Naming it by id is exact
## rather than lazy: this row IS the fix, and asking whether a sheet already has one is asking
## whether somebody already took the step.
const OWN_ENVIRONMENT_ACE := "WorldOwnEnvironment"
const CORE_PROVIDER := "Core"

## What the fix's event runs on. A copy taken every frame is not a fix, and a copy taken after the
## rows that write through it is not one either: this is the one moment that is both once and first.
const READY_TRIGGER := "OnReady"

## The spelling a row uses for the node the sheet itself is on. The fix's "On node" is left BLANK for
## it, because that is what the shipped row's own default is and what a reader would have typed.
const OWN_NODE := "self"


## The findings about ONE SCENE, in reading order: lights that cast nothing, shadows nothing blocks,
## and a darkened layer no light reaches. Empty for a scene with no lighting in it at all, which is
## what keeps every other project exactly as it was.
static func scene_findings(scene_path: String) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	_lights_without_a_texture(scene_path, found)
	_shadows_nothing_blocks(scene_path, found)
	_darkness_without_light(scene_path, found)
	return found


## The findings about ONE SHEET: an environment row aimed at a scene that has no WorldEnvironment,
## and an environment written at run time through a resource file other scenes load. Both carry the
## event they are about, so the canvas can say them under the row rather than in a report elsewhere.
static func findings(sheet: EventSheetResource) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	if sheet == null:
		return found
	var rows: Array[Dictionary] = environment_rows(sheet)
	if rows.is_empty():
		return found
	var script_path: String = str(sheet.external_source_path)
	var scene_path: String = EventSheetSceneLightingFacts.attached_scene(script_path)
	if scene_path.is_empty():
		return found
	# Asked of the SCRIPT rather than of the scene, because the answer carries the spelling this
	# sheet's own rows address the node by - which is what the one-click fix has to write.
	var holders: Array[Dictionary] = EventSheetSceneLights.nodes_of_class(
		script_path, EventSheetSceneLightingFacts.ENVIRONMENT_CLASS)
	if holders.is_empty():
		_no_world_environment(rows[0], scene_path, found)
		return found
	if not writes_its_own_environment(sheet):
		_shared_environment(rows[0], holders[0], scene_path, found)
	return found


## The findings anchored at one event row - what the canvas hangs under it. Matched by IDENTITY, so
## the caller never has to name a row that has no name.
static func for_event(found: Array[Dictionary], event_row: EventRow) -> Array[Dictionary]:
	var mine: Array[Dictionary] = []
	if event_row == null:
		return mine
	for entry: Dictionary in found:
		if str(entry.get("anchor", "")) == ANCHOR_EVENT and is_same(entry.get("event"), event_row):
			mine.append(entry)
	return mine


# -- The three scene rules ----------------------------------------------------------------------


## A 2D point light lights the SHAPE OF ITS TEXTURE. Without one it is switched on, costs a draw and
## shows nothing - the quietest of the five, because everything about the node looks right.
static func _lights_without_a_texture(scene_path: String, found: Array[Dictionary]) -> void:
	for name_text: String in EventSheetSceneLightingFacts.textureless_lights(scene_path):
		found.append(_scene_finding(KIND_NO_TEXTURE, scene_path, name_text,
			EventSheetL10n.translate("%s has no texture, so it lights nothing. Give it one - a soft white circle is the whole of a torch.") % name_text))


## Shadows are drawn only where an occluder's own mask shares a layer with the light's shadow mask.
## The wording is the head band's, in one place: a reader meets the same sentence wherever they meet
## the problem.
static func _shadows_nothing_blocks(scene_path: String, found: Array[Dictionary]) -> void:
	var casting: Array[Dictionary] = EventSheetSceneLightingFacts.shadow_casting_lights(scene_path)
	if casting.is_empty():
		return
	var stranded: PackedStringArray = EventSheetSceneLightingFacts.lights_without_occluders(
		scene_path, casting)
	if stranded.is_empty():
		return
	# The band's sentence carries no full stop of its own (it is a band, not a paragraph), so the
	# finding punctuates it here rather than the band wearing punctuation it does not want.
	found.append(_scene_finding(KIND_NO_OCCLUDER, scene_path, stranded[0], "%s. %s" % [
		EventSheetSceneLightingFacts.shadows_warning(stranded),
		EventSheetL10n.translate("Add an occluder, or turn the shadows off and save the draw cost.")]))


## A darkened layer with no light reaching it is a uniformly dark scene. Both shapes of that are the
## same finding - no light at all, and lights whose RANGE mask misses what is drawn on the layer -
## so the sentence names both answers rather than assuming which one the reader has.
static func _darkness_without_light(scene_path: String, found: Array[Dictionary]) -> void:
	if not EventSheetSceneLightingFacts.lights_reaching_the_layer(scene_path).is_empty():
		return
	for darkness: Dictionary in EventSheetSceneLightingFacts.darkening_nodes(scene_path):
		found.append(_scene_finding(KIND_NO_LIGHT, scene_path, str(darkness["name"]),
			EventSheetL10n.translate("%s darkens the layer to %s and no light reaches it - the scene is uniformly dark. Add a light, or check the range masks of the ones there are.") % [
				str(darkness["name"]), str(darkness["percent"])]))


# -- The two sheet rules ------------------------------------------------------------------------


## An environment row aimed at a scene with no WorldEnvironment in it. The row compiles, runs, and
## writes a property of nothing at all.
static func _no_world_environment(row: Dictionary, scene_path: String, found: Array[Dictionary]) -> void:
	found.append({
		"kind": KIND_NO_ENVIRONMENT, "severity": "warning", "anchor": ANCHOR_EVENT,
		"event": row.get("event"), "subject": str(row.get("verb", "")), "scene_path": scene_path,
		"message": EventSheetL10n.translate("%s writes the world's environment, and %s has no WorldEnvironment node - the row does nothing when the game runs. Add one to the scene.") % [
			str(row.get("verb", "")), scene_path.get_file()],
		"fix": "", "fix_label": ""
	})


## An environment written at run time through a `.tres` other scenes load. An environment resource is
## a FILE: writing fog into it writes it for every scene holding the same file, and the change
## follows the player out of the room. The one finding of the five with a single step to take.
static func _shared_environment(row: Dictionary, holder: Dictionary, scene_path: String,
		found: Array[Dictionary]) -> void:
	var resource_path: String = EventSheetSceneLightingFacts.environment_resource(holder)
	var others: PackedStringArray = EventSheetSceneLightingFacts.scenes_sharing(resource_path, scene_path)
	if others.is_empty():
		return
	var names: PackedStringArray = PackedStringArray()
	for other: String in others:
		names.append(other.get_file())
	# The SUBJECT is the spelling the fix's row will be aimed at, not the node's bare name: a finding
	# whose repair is one click carries what that click needs, and every reader of a finding takes its
	# subject from the same key.
	found.append({
		"kind": KIND_SHARED_ENVIRONMENT, "severity": "warning", "anchor": ANCHOR_EVENT,
		"event": row.get("event"), "subject": str(holder.get("reference", "")), "scene_path": scene_path,
		"message": EventSheetL10n.translate("%s writes %s, which %s also uses - the change follows the player into those scenes. Give this scene its own copy first.") % [
			str(row.get("verb", "")), resource_path.get_file(), ", ".join(names)],
		"fix": FIX_OWN_ENVIRONMENT,
		"fix_label": EventSheetL10n.translate("Make the environment this scene's own")
	})


# -- What one row says --------------------------------------------------------------------------


## Every row of a sheet that WRITES THE WORLD'S ENVIRONMENT, in sheet order, each as
## {"event", "ace", "verb"}. Derived from the line the row compiles to rather than from a list of
## ace_ids: the frozen Core atmosphere actions reach the environment through a parameter, the
## node-scoped World rows through the member, and a pack's own atmosphere verb through whichever it
## likes - all three end up naming the same member of the same object, which is the only thing that
## makes them the rows this finding is about.
static func environment_rows(sheet: EventSheetResource) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if sheet == null:
		return rows
	_walk(sheet.events, rows)
	for entry: Variant in sheet.functions:
		var event_function: EventFunction = entry as EventFunction
		if event_function != null:
			_walk(event_function.events, rows)
	return rows


## True when the sheet already gives its scene a copy of the environment before writing it - the row
## the one-click fix inserts. A sheet that has taken the step is not warned about it again.
static func writes_its_own_environment(sheet: EventSheetResource) -> bool:
	for row: Dictionary in environment_rows(sheet):
		if str((row["ace"] as Resource).get("ace_id")) == OWN_ENVIRONMENT_ACE:
			return true
	return false


## True when the line one row compiles to reaches through the environment a WorldEnvironment holds.
## The LINE rather than the template, because the frozen Core actions name the environment in a
## PARAMETER (`$WorldEnvironment.environment`) while the node-scoped World rows name it in the
## template itself - and both end up writing the same member of the same object, which is the only
## thing that makes them the rows these two findings are about.
static func writes_the_environment(ace: Resource) -> bool:
	if ace == null or not (ace is ACEAction):
		return false
	return reaches_the_environment(compiled_line(ace))


## The line one row stands for, near enough to read: its template with its own values in it, the
## optional-prefix `{target.}` idiom included. Near enough, because what is asked of it is which
## member of which object the row reaches - not what the file will say byte for byte, which only the
## compiler answers.
static func compiled_line(ace: Resource) -> String:
	var line: String = _template_of(ace)
	var params: Dictionary = _params_of(ace)
	for key: Variant in params:
		var value: String = str(params[key]).strip_edges()
		line = line.replace("{%s.}" % str(key), "" if value.is_empty() else "%s." % value)
		line = line.replace("{%s}" % str(key), value)
	return line


## True when a line reaches THROUGH the environment: `environment.fog_density = 0.03`,
## `$World.environment.fog_density = 0.03`, or the member handed to a tween as `$World.environment`.
## Matched as a whole word with a dot (or the head of the line, or an unfilled `{target.}` prefix)
## before it, so a variable named `environment_hue` is never mistaken for the world's own.
static func reaches_the_environment(line: String) -> bool:
	var member: String = EventForgeSceneLightingACEs.ENVIRONMENT_MEMBER
	var at: int = line.find(member)
	while at >= 0:
		var before: String = line.substr(at - 1, 1) if at > 0 else ""
		if (before.is_empty() or before == "." or before == "}") \
				and not _is_word_glyph(line.substr(at + member.length(), 1)):
			return true
		at = line.find(member, at + 1)
	return false


## True for a glyph that could continue an identifier - what tells `environment.` (the member) from
## `environment_hue` (somebody's variable that happens to start the same way).
static func _is_word_glyph(glyph: String) -> bool:
	return glyph == "_" or glyph.to_lower() != glyph.to_upper() or glyph.is_valid_int()


## The row a fix inserts: "Make the environment this scene's own", aimed at the node the finding
## named. Built here rather than in the dock so the fix can be proven headless - what it writes is
## the shipped descriptor's own template, baked exactly as the picker would bake it.
static func own_environment_action(target: String) -> ACEAction:
	var action := ACEAction.new()
	action.provider_id = CORE_PROVIDER
	action.ace_id = OWN_ENVIRONMENT_ACE
	var descriptor: ACEDescriptor = ACERegistry.find_descriptor(CORE_PROVIDER, OWN_ENVIRONMENT_ACE)
	action.codegen_template = descriptor.codegen_template if descriptor != null else ""
	action.params = {"target": "" if target.strip_edges() == OWN_NODE else target.strip_edges()}
	return action


## Puts that row at the TOP of a sheet, in an event of its own, ON READY. Both halves matter: the copy
## has to exist before any row writes through it, and a row under no trigger at all is a row that runs
## every frame - which would take a fresh copy sixty times a second and still not be the first thing
## to happen. True when the sheet changed, which is what the undo funnel commits on.
static func insert_own_environment(sheet: EventSheetResource, target: String) -> bool:
	if sheet == null or writes_its_own_environment(sheet):
		return false
	var event_row := EventRow.new()
	event_row.trigger_provider_id = CORE_PROVIDER
	event_row.trigger_id = READY_TRIGGER
	event_row.actions.append(own_environment_action(target))
	sheet.events.insert(_first_running_row(sheet), event_row)
	return true


## Where the top of a sheet is, for a row that has to run before the others: before the first row
## that RUNS, and after the file's own header lines. A `.gd` opened as a sheet leads with its comment
## block, its `extends` and its variables, and a new event ahead of those would read as a file that
## starts with an event and then declares what it extends.
static func _first_running_row(sheet: EventSheetResource) -> int:
	for index: int in range(sheet.events.size()):
		var item: Variant = sheet.events[index]
		if item is EventRow or item is EventGroup:
			return index
	return sheet.events.size()


static func _walk(items: Array, into: Array[Dictionary]) -> void:
	for item: Variant in items:
		if item is EventGroup:
			_walk(EventSheetGroupFacts.children(item as EventGroup), into)
			continue
		var event_row: EventRow = item as EventRow
		if event_row == null:
			continue
		for ace: Variant in event_row.actions:
			if ace is Resource and writes_the_environment(ace as Resource):
				into.append({"event": event_row, "ace": ace as Resource,
					"verb": _display_name(ace as Resource)})
		_walk(event_row.sub_events, into)


## One scene finding, which has no row to hang under and says which node it is about instead.
static func _scene_finding(kind: String, scene_path: String, subject: String,
		message: String) -> Dictionary:
	return {
		"kind": kind, "severity": "warning", "anchor": ANCHOR_SCENE, "event": null,
		"subject": subject, "scene_path": scene_path, "message": message,
		"fix": "", "fix_label": ""
	}


static func _template_of(ace: Resource) -> String:
	var baked: String = str(ace.get("codegen_template"))
	if not baked.strip_edges().is_empty():
		return baked
	var descriptor: ACEDescriptor = ACERegistry.find_descriptor(
		str(ace.get("provider_id")), str(ace.get("ace_id")))
	return descriptor.codegen_template if descriptor != null else ""


static func _display_name(ace: Resource) -> String:
	var descriptor: ACEDescriptor = ACERegistry.find_descriptor(
		str(ace.get("provider_id")), str(ace.get("ace_id")))
	return descriptor.display_name if descriptor != null else str(ace.get("ace_id"))


static func _params_of(ace: Resource) -> Dictionary:
	var params: Variant = ace.get("params")
	return params as Dictionary if params is Dictionary else {}
