# Godot EventSheets - the five ways an effect silently does nothing.
#
# Every one of these runs without an error and shows nothing on screen, which is what makes shaders
# the part of a game people give up on. All five are facts the plugin can already read from the sheet
# plus the attached scene, before the game is run once:
#
#   a dial the shader does not have - a uniform renamed (or mistyped) and every row naming the old
#                     name goes on being a call Godot accepts, returns from, and acts on in no way.
#   a shared material - a `.tres` worn by twelve nodes is ONE object, so turning a dial on the goblin
#                     the player hit turns it on all twelve. The fix is one row.
#   no material at all - dial rows aimed at a node the scene gives no material: every one of them
#                     reaches through a null and does nothing.
#   an undeclared global - `RenderingServer.global_shader_parameter_set("wind_strength", …)` where
#                     Project Settings declares no such global: every shader reading it sees zero.
#   a screen effect left on - a full-screen rect wearing a screen-reading shader, visible with every
#                     dial still at rest, redrawing the whole screen every frame for nothing.
#
# THE SPLIT. The first four are about the ROWS and carry the event they are about, so the canvas says
# them under the row. The last is a fact of a SCENE and is found without a sheet at all, because a
# rect left on is left on whether or not anybody wrote a row about it.
#
# EVERY ONE IS AMBER, never red: all of them compile and run, and only the screen disagrees.
#
# TWO OF THEM HAVE ONE STEP TO TAKE, so they carry it: a dial the shader nearly declares offers the
# declared name as a button (the same gesture as the "Use hp" a misspelled variable offers), and a
# shared material offers the row that gives this node its own copy. The other three are a material to
# assign, a setting to write and a rect to hide - and a wrong guess in a fix button costs more than no
# guess at all.
#
# NOTHING IS STORED. Every finding is derived from the rows and the files on every ask, so a fixed
# sheet stops reporting with nothing to clean up, and a project with no shaders in it gets none.
#
# PURE + STATIC: no viewport, no dialog, no display server, so every word is pinned headless.
@tool
class_name EventSheetEffectFindings
extends RefCounted

## The five findings, by id. Frozen: the note rows, the Doctor and the tests address one by these.
const KIND_UNKNOWN_DIAL := "effect-dial-the-shader-does-not-declare"
const KIND_SHARED_MATERIAL := "effect-dials-on-a-shared-material"
const KIND_NO_MATERIAL := "effect-rows-on-a-node-wearing-none"
const KIND_UNDECLARED_GLOBAL := "shader-global-the-project-does-not-declare"
const KIND_IDLE_SCREEN_EFFECT := "screen-effect-drawing-while-idle"

## AND THE SAME FACT FROM THE OTHER DIRECTION. The five above are all about rows that turn a dial ON
## a material. This one is about a row that would REPLACE the material outright: a screen-reading
## blend mode hands the item a shader of its own, and an item already wearing somebody's shader
## cannot be given a second one. The blend refuses at run time rather than throwing that effect away,
## which is right - and is also invisible until somebody runs the game and wonders why the glow never
## appeared. So it is said here, before the game is run once.
const KIND_BLEND_OVER_SHADER := "blend-mode-on-an-item-already-wearing-a-shader"

## The two one-click repairs: rewrite the row's dial to the declared name it was nearly, and insert
## the row that gives this node its own copy of the material before anything turns a dial on it.
const FIX_PICK_DIAL := "pick_dial"
const FIX_OWN_MATERIAL := "own_material"

## The row that answers the sharing question, by id - the one a reader adds to stop a dial row moving
## every other node wearing the same material file. Naming it by id is exact rather than lazy: this
## row IS the fix, and asking whether a sheet already has one is asking whether the step was taken.
const OWN_MATERIAL_ACE := "EffectOwnMaterial"
const CORE_PROVIDER := "Core"

## What that fix's event runs on. A copy taken every frame is not a fix, and a copy taken after the
## rows that turn dials through it is not one either: this is the one moment that is both once and
## first.
const READY_TRIGGER := "OnReady"

## Where a finding hangs: under the event whose row has the problem, or nowhere in the sheet at all
## (a scene fact, which the Doctor report says instead).
const ANCHOR_EVENT := "event"
const ANCHOR_SCENE := "scene"

## The call a row reaches a GLOBAL uniform through, and where Project Settings keeps the declaration
## that makes one exist. Matched in the line rather than by ace_id, so the shipped rendering rows, a
## pack's own weather verb and a hand-written line lifted from somebody's project are all the same
## finding.
const GLOBAL_CALLS: PackedStringArray = ["global_shader_parameter_set(", "global_shader_parameter_get("]
const GLOBAL_SETTING_PREFIX := "shader_globals/"

## The call that WRITES a dial, and the half of it every dial row shares. A row that only READS one
## harms nobody else wearing the material, so the shared-material finding is about the rows that
## write - asked of the line, because that is the one thing a shipped row, a pack row and a lifted
## line always have in common.
const WRITE_CALL := "set_shader_parameter("
const DIAL_CALL := "shader_parameter("

## How a blend row is recognised, and which modes need a shader of their own. Matched IN THE LINE for
## the same reason the global calls above are: a picked row, a pack's own wrapper around it and a
## line somebody wrote by hand are all the same finding, and none of them is more real than the
## others. The five native words are the modes the renderer draws by itself - they set a field on an
## ordinary material and never replace anything, so a row naming one of them is never this finding.
const BLEND_CALL := ".blend_as("
const BLEND_NATIVE_MODES: PackedStringArray = ["normal", "add", "subtract", "multiply",
	"premultiplied"]

## Where the FROZEN free-string rows keep the dial's name
 - quoted, and typed rather than picked.
## Kept because a hand-written line naming a dial the shader does not declare lifts to one of those
## by design: there was no dial to pick, so the row that stands for it is the one that takes a name.
const FREE_STRING_PARAM := "param"


## The four findings about ONE SHEET's rows, in sheet order. Each carries the event it is under and
## the lane and slot of the row (so a fix can rewrite it without holding a resource across the undo
## funnel), and the two with a single step to take carry it.
static func findings(sheet: EventSheetResource) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	if sheet == null:
		return found
	var script_path: String = str(sheet.external_source_path)
	if script_path.strip_edges().is_empty():
		return found
	# One walk, and everything it needs to judge a row read once beside it. `attached` gates the
	# no-material finding alone: a behaviour five scenes wear has no one scene to be missing a
	# material in, and a node spawned at run time is in no scene at all.
	var judged: Dictionary = {
		"wearers": EventSheetSceneEffects.wearers_of_script(script_path),
		# Every node reference the scene really answers to. The no-material finding is only ever said
		# of one of these: a row aimed at a variable, at a node made at run time, or at a name nothing
		# in the scene has is a row nothing here can establish anything about.
		"nodes": EventSheetSceneLights.classes_for_script(script_path),
		"copied": nodes_given_their_own_copy(sheet),
		"attached": not EventSheetSceneLightingFacts.attached_scene(script_path).is_empty(),
		# One finding per NODE, not per row: twelve rows turning dials on one shared material are one
		# problem with one fix, and twelve identical notes is how a note stops being read.
		"said": PackedStringArray(),
	}
	_walk(sheet.events, judged, found)
	for entry: Variant in sheet.functions:
		var event_function: EventFunction = entry as EventFunction
		if event_function != null:
			_walk(event_function.events, judged, found)
	return found


## The finding about ONE SCENE: a screen effect left drawing while nothing is happening. Found
## without a sheet, because a rect left on is left on whether or not anybody wrote a row about it.
static func scene_findings(scene_path: String) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for rect: Dictionary in idle_screen_effects(scene_path):
		found.append({
			"kind": KIND_IDLE_SCREEN_EFFECT, "severity": "warning", "anchor": ANCHOR_SCENE,
			"event": null, "subject": str(rect["name"]), "scene_path": scene_path,
			"message": EventSheetL10n.translate("%s covers the screen with %s and every dial is still at rest - the whole screen redraws through the shader each frame for nothing. Hide it until an effect turns it on.") % [
				str(rect["name"]), str(rect["shader_path"]).get_file()],
			"fix": "", "fix_label": ""
		})
	return found


## The nodes of one scene that read the SCREEN and are drawing it back unchanged: visible, wearing a
## shader that samples `hint_screen_texture`, and with every dial still on the value the shader itself
## declares. All three matter - a rect that is hidden costs nothing, a rect whose shader does not read
## the screen is an ordinary sprite, and a rect somebody has turned an effect on IS the effect.
static func idle_screen_effects(scene_path: String) -> Array[Dictionary]:
	var idle: Array[Dictionary] = []
	for wearer: Dictionary in EventSheetSceneEffects.for_scene(scene_path):
		var shader_path: String = str(wearer.get("shader_path", ""))
		if shader_path.is_empty() or not EventForgeShaderUniforms.reads_the_screen(shader_path):
			continue
		if str((wearer.get("properties", {}) as Dictionary).get("visible", "true")) == "false":
			continue
		if not _every_dial_at_rest(wearer):
			continue
		idle.append({"name": str(wearer.get("name", "")), "path": str(wearer.get("path", "")),
			"scene_path": scene_path, "shader_path": shader_path})
	return idle


## True when nothing has been turned up on this node's material: every dial it overrides still holds
## the value the shader declares for it. An override the shader has no default for counts as turned
## up, because somebody wrote it on purpose.
static func _every_dial_at_rest(wearer: Dictionary) -> bool:
	var overrides: Dictionary = wearer.get("parameters", {})
	for dial_name: Variant in overrides:
		var declared: Dictionary = EventForgeShaderUniforms.find(
			str(wearer.get("shader_path", "")), str(dial_name))
		if str(overrides[dial_name]).strip_edges() \
				!= EventForgeShaderUniforms.gdscript_default(declared):
			return false
	return true


## The findings anchored at one event row - what the canvas hangs under it. Matched by IDENTITY, so
## the caller never has to name a row that has no name.
static func for_event(found: Array[Dictionary], event_row: EventRow) -> Array[Dictionary]:
	var mine: Array[Dictionary] = []
	if event_row == null:
		return mine
	for entry: Dictionary in found:
		if is_same(entry.get("event"), event_row):
			mine.append(entry)
	return mine


## The dial one row names, or "" for every row that names none.
##
## TWO ROWS SPELL IT, and both are read here. A picked dial row keeps the name bare in `dial`. The
## frozen free-string row keeps it QUOTED in `param` - and a hand-written line naming a dial the
## shader does not declare lifts to exactly that row, by design, because there was no dial to pick.
## So the check that finds a typo has to read the row a typo produces, or it only ever finds the
## mistakes nobody made.
static func dial_of(ace: Resource) -> String:
	var named: Dictionary = _dial_slot(ace)
	return str(named.get("dial", ""))


## Which parameter of a row holds the dial's name, and whether it is quoted there - what a one-click
## re-pick has to know before it writes the picked name back into the right slot in the right shape.
static func dial_param_of(ace: Resource) -> String:
	return str(_dial_slot(ace).get("param", ""))


static func _dial_slot(ace: Resource) -> Dictionary:
	if ace == null:
		return {}
	var params: Variant = ace.get("params")
	if not (params is Dictionary):
		return {}
	var picked: String = str((params as Dictionary).get(
		EventForgeEffectDialACEs.DIAL_PARAM, "")).strip_edges()
	if not picked.is_empty():
		return {"dial": picked, "param": EventForgeEffectDialACEs.DIAL_PARAM, "quoted": false}
	var typed: String = str((params as Dictionary).get(FREE_STRING_PARAM, "")).strip_edges()
	# Only a plain quoted literal: a row whose name is a variable or an expression names a dial only
	# the running game knows, and nothing here may claim to have checked it.
	if typed.length() < 2 or not typed.begins_with("\"") or not typed.ends_with("\""):
		return {}
	if not EventSheetLightingFindings.compiled_line(ace).contains(DIAL_CALL):
		return {}
	return {"dial": typed.substr(1, typed.length() - 2), "param": FREE_STRING_PARAM, "quoted": true}


## The node one row is aimed at, as the row spells it - "" meaning the node the sheet is on, which is
## what a blank "On node" means everywhere else too.
static func target_of(ace: Resource) -> String:
	var params: Variant = ace.get("params")
	return str((params as Dictionary).get("target", "")).strip_edges() if params is Dictionary else ""


## The nodes this sheet already gives their own copy of the material, as the reference keys its rows
## address them by. What the head band reads to say "its own copy at runtime" instead of warning, and
## what the shared-material check reads to leave a sheet that has taken the step alone.
static func nodes_given_their_own_copy(sheet: EventSheetResource) -> PackedStringArray:
	var copied: PackedStringArray = PackedStringArray()
	for row: Dictionary in own_material_rows(sheet):
		copied.append(EventSheetSceneEffects.reference_key_of(str(row["target"])))
	return copied


## Every `Make the effect this node's own` row of a sheet, in sheet order, each {"event", "target"}.
static func own_material_rows(sheet: EventSheetResource) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if sheet == null:
		return rows
	_walk_own_rows(sheet.events, rows)
	for entry: Variant in sheet.functions:
		var event_function: EventFunction = entry as EventFunction
		if event_function != null:
			_walk_own_rows(event_function.events, rows)
	return rows


## The row a fix inserts, aimed at the node the finding named. Built here rather than in the dock so
## the fix can be proven headless - what it writes is the shipped descriptor's own template, baked
## exactly as the picker would bake it.
static func own_material_action(target: String) -> ACEAction:
	var action := ACEAction.new()
	action.provider_id = CORE_PROVIDER
	action.ace_id = OWN_MATERIAL_ACE
	var descriptor: ACEDescriptor = ACERegistry.find_descriptor(CORE_PROVIDER, OWN_MATERIAL_ACE)
	action.codegen_template = descriptor.codegen_template if descriptor != null else ""
	action.params = {"target": "" if target.strip_edges() == EventSheetSceneLights.SELF_REFERENCE \
		else target.strip_edges()}
	return action


## Puts that row at the TOP of a sheet, in an event of its own, ON READY. Both halves matter: the copy
## has to exist before any row turns a dial through it, and a row under no trigger at all is a row
## that runs every frame - which would take a fresh copy sixty times a second and still not be the
## first thing to happen. True when the sheet changed, which is what the undo funnel commits on.
static func insert_own_material(sheet: EventSheetResource, target: String) -> bool:
	if sheet == null:
		return false
	if nodes_given_their_own_copy(sheet).has(EventSheetSceneEffects.reference_key_of(target)):
		return false
	var event_row := EventRow.new()
	event_row.trigger_provider_id = CORE_PROVIDER
	event_row.trigger_id = READY_TRIGGER
	event_row.actions.append(own_material_action(target))
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


static func _walk_own_rows(items: Array, into: Array[Dictionary]) -> void:
	for item: Variant in items:
		if item is EventGroup:
			_walk_own_rows(EventSheetGroupFacts.children(item as EventGroup), into)
			continue
		var event_row: EventRow = item as EventRow
		if event_row == null:
			continue
		for entry: Variant in event_row.actions:
			if entry is Resource and str((entry as Resource).get("ace_id")) == OWN_MATERIAL_ACE:
				into.append({"event": event_row, "target": target_of(entry as Resource)})
		_walk_own_rows(event_row.sub_events, into)


## One row judged: {} when there is nothing wrong with it, and the first of the four findings it
## earns otherwise. Anything this cannot ESTABLISH is not a finding - the point of every check here
## is that it is never a guess, so a chain that cannot be followed to a shader says nothing at all.
static func _finding_for(ace: Resource, judged: Dictionary, event_row: EventRow, lane: String,
		slot: int) -> Dictionary:
	var global_name: String = global_of(ace)
	if not global_name.is_empty():
		return _undeclared_global(global_name, event_row, lane, slot)
	# The blend row comes before the dial checks because it names no dial: it would otherwise fall
	# straight through them and be judged as nothing at all.
	var about_blend: Dictionary = _blend_over_shader(ace, judged, event_row, lane, slot)
	if not about_blend.is_empty():
		return about_blend
	var dial: String = dial_of(ace)
	if dial.is_empty():
		return {}
	var reference: String = EventSheetSceneEffects.reference_key_of(target_of(ace))
	var wearer: Dictionary = (judged["wearers"] as Dictionary).get(reference, {})
	if wearer.is_empty():
		return _no_material(reference, dial, judged, event_row, lane, slot)
	var shader_path: String = str(wearer.get("shader_path", ""))
	if shader_path.is_empty():
		return {}
	if not EventForgeShaderUniforms.declares(shader_path, dial):
		return _unknown_dial(shader_path, dial, dial_param_of(ace), event_row, lane, slot)
	return _shared_material(wearer, reference, ace, judged, event_row, lane, slot)


## A screen-reading blend aimed at an item the scene already gives a shader. The row is refused at run
## time - replacing somebody's effect to set a blend would be worse than doing nothing - so the look
## never appears, and this is where that is said instead of the player finding out.
##
## Only ever said of an item the attached scene really carries and really gives a shader: a row aimed
## at a variable, at a node made at run time, or at a name nothing in the scene has is a row nothing
## here can establish anything about, and a finding that is a guess is worse than no finding. No fix
## door either: blend a parent, blend a child, or take the shader off are three different answers to
## three different scenes, and a wrong guess in a button costs more than no guess at all.
static func _blend_over_shader(ace: Resource, judged: Dictionary, event_row: EventRow, lane: String,
		slot: int) -> Dictionary:
	var line: String = EventSheetLightingFindings.compiled_line(ace)
	var opened: int = line.find(BLEND_CALL)
	if opened < 0:
		return {}
	var arguments: String = line.substr(opened + BLEND_CALL.length())
	var comma: int = arguments.find(",")
	if comma < 0:
		return {}
	var mode: String = _first_quoted(arguments.substr(comma + 1))
	if mode.is_empty() or BLEND_NATIVE_MODES.has(mode):
		return {}
	var reference: String = EventSheetSceneEffects.reference_key_of(arguments.substr(0, comma))
	var wearer: Dictionary = (judged["wearers"] as Dictionary).get(reference, {})
	var shader_path: String = str(wearer.get("shader_path", ""))
	if shader_path.is_empty() or _already_said(judged, KIND_BLEND_OVER_SHADER, reference):
		return {}
	return _row_finding(KIND_BLEND_OVER_SHADER, reference, EventSheetL10n.translate(
		"%s already wears %s, and an item wears one material - so the %s blend is refused when the game runs and the look never appears. Blend a parent or a child instead, or take the shader off.") % [
			reference, shader_path.get_file(), mode], event_row, lane, slot,
		{"shader_path": shader_path})


## The first quoted word in a piece of an emitted line, or "" when there is none. What a mode word
## looks like in the code: the row writes it quoted, so a value that is anything else - a variable, a
## whole expression - is a mode only the running game knows, and nothing here may claim to have
## checked it.
static func _first_quoted(text: String) -> String:
	var opened: int = text.find("\"")
	if opened < 0:
		return ""
	var closed: int = text.find("\"", opened + 1)
	return "" if closed < 0 else text.substr(opened + 1, closed - opened - 1)


## A dial the shader does not declare, and the declared name it was nearly
 - the whole of the fix,
## because a name close enough to be a typo is close enough to offer as one click. It carries the
## parameter the name sits in, so the re-pick writes into the slot this particular row keeps it in.
static func _unknown_dial(shader_path: String, dial: String, dial_param: String, event_row: EventRow,
		lane: String, slot: int) -> Dictionary:
	var nearest: String = EventSheetVariableOwners.nearest_name(
		EventForgeShaderUniforms.for_shader(shader_path), dial)
	var message: String = EventSheetL10n.translate("%s declares no dial called %s, so this row does nothing when the game runs.") % [
		shader_path.get_file(), dial]
	if not nearest.is_empty():
		message += " " + EventSheetL10n.translate("Did you mean %s?") % nearest
	return _row_finding(KIND_UNKNOWN_DIAL, dial, message, event_row, lane, slot, {
		"shader_path": shader_path, "to": nearest, "param": dial_param,
		"fix": FIX_PICK_DIAL if not nearest.is_empty() else "",
		"fix_label": EventSheetL10n.translate("Use %s") % nearest if not nearest.is_empty() else ""})


## Dial rows on a node the scene gives no material. Only said of a sheet with ONE attached scene and
## only of a node that scene really has: a behaviour five scenes wear has no single scene to be
## missing a material in, a row aimed at a variable names a node this cannot follow, and a node made
## at run time is in no scene at all - reporting any of them would be a guess dressed as a finding.
static func _no_material(reference: String, dial: String, judged: Dictionary, event_row: EventRow,
		lane: String, slot: int) -> Dictionary:
	if not bool(judged["attached"]) or not (judged["nodes"] as Dictionary).has(reference):
		return {}
	if _already_said(judged, KIND_NO_MATERIAL, reference):
		return {}
	return _row_finding(KIND_NO_MATERIAL, reference, EventSheetL10n.translate(
		"%s wears no material in the scene, so setting %s on it reaches through nothing - every effect row aimed at it does nothing. Give it a ShaderMaterial in the Inspector.") % [
			reference, dial], event_row, lane, slot, {})


## Dials turned on a material FILE other nodes wear. The row is right and does exactly what it says -
## to all of them - so the finding names who else moves, and the fix is the row that gives this node
## its own copy first. A sheet that has already taken that step is never told again.
static func _shared_material(wearer: Dictionary, reference: String, ace: Resource,
		judged: Dictionary, event_row: EventRow, lane: String, slot: int) -> Dictionary:
	var material_path: String = str(wearer.get("material_path", ""))
	if material_path.is_empty() or not writes_a_dial(ace):
		return {}
	if (judged["copied"] as PackedStringArray).has(reference) \
			or _already_said(judged, KIND_SHARED_MATERIAL, reference):
		return {}
	# The count comes from the project index, which is the one place that question is answered. A scan
	# still running answers nothing, and a finding is not raised on an answer that is not in yet.
	if not EventSheetProjectShareIndex.scenes_ready():
		return {}
	var others: Array[Dictionary] = EventSheetProjectShareIndex.other_wearers(material_path,
		"%s|%s" % [str(wearer.get("scene_path", "")), str(wearer.get("path", ""))])
	if others.is_empty():
		return {}
	var names: PackedStringArray = PackedStringArray()
	for other: Dictionary in others:
		names.append(str(other.get("name", "")))
	return _row_finding(KIND_SHARED_MATERIAL, reference, EventSheetL10n.translate(
		"%s is worn by %s as well, and a material is one object - every dial this row turns turns for them too. Give this node its own copy first.") % [
			material_path.get_file(), ", ".join(names)],
		event_row, lane, slot, {"fix": FIX_OWN_MATERIAL,
			"fix_label": EventSheetL10n.translate("Make the effect this node's own"),
			"material_path": material_path})


## A global uniform Project Settings does not declare. Godot hands every shader reading it a zero and
## says nothing, so the row runs, the value goes nowhere and the weather never changes.
static func _undeclared_global(global_name: String, event_row: EventRow, lane: String,
		slot: int) -> Dictionary:
	if ProjectSettings.has_setting(GLOBAL_SETTING_PREFIX + global_name):
		return {}
	return _row_finding(KIND_UNDECLARED_GLOBAL, global_name, EventSheetL10n.translate(
		"Project Settings > Shader Globals declares no %s, so every shader reading it sees zero however often this row runs. Declare it there.") % global_name,
		event_row, lane, slot, {})


## The global uniform one row names, or "" for every row that names none. Read off the LINE rather
## than off a list of ace_ids: the shipped rendering rows, a pack's own weather verb and a line lifted
## out of somebody's project all reach the same call, and only a quoted name can be checked.
static func global_of(ace: Resource) -> String:
	if ace == null:
		return ""
	var line: String = EventSheetLightingFindings.compiled_line(ace)
	for call_text: String in GLOBAL_CALLS:
		var at: int = line.find(call_text)
		if at < 0:
			continue
		var quoted: String = line.substr(at + call_text.length()).strip_edges().trim_prefix("&")
		if not quoted.begins_with("\""):
			return ""
		var closing: int = quoted.find("\"", 1)
		return quoted.substr(1, closing - 1) if closing > 1 else ""
	return ""


## True when a row WRITES a dial rather than reading one. Asked of the line for the same reason the
## global name is: it is the one thing every spelling of the row has in common.
static func writes_a_dial(ace: Resource) -> bool:
	return EventSheetLightingFindings.compiled_line(ace).contains(WRITE_CALL)


## One row finding with its defaults filled in, so every reader of a finding can address every key.
static func _row_finding(kind: String, subject: String, message: String, event_row: EventRow,
		lane: String, slot: int, extra: Dictionary) -> Dictionary:
	var finding: Dictionary = {
		"kind": kind, "severity": "warning", "anchor": ANCHOR_EVENT, "event": event_row,
		"subject": subject, "message": message, "shader_path": "", "to": "", "param": "",
		"fix": "", "fix_label": "", "lane": lane, "index": slot
	}
	finding.merge(extra, true)
	return finding


## True when this kind has already been raised about this node, and marks it raised otherwise. Twelve
## rows turning dials on one shared material are one problem with one fix, and twelve identical notes
## is how a note stops being read.
static func _already_said(judged: Dictionary, kind: String, subject: String) -> bool:
	var key: String = "%s|%s" % [kind, subject]
	var said: PackedStringArray = judged["said"]
	if said.has(key):
		return true
	said.append(key)
	judged["said"] = said
	return false


static func _walk(items: Array, judged: Dictionary, into: Array[Dictionary]) -> void:
	for item: Variant in items:
		if item is EventGroup:
			_walk(EventSheetGroupFacts.children(item as EventGroup), judged, into)
			continue
		var event_row: EventRow = item as EventRow
		if event_row == null:
			continue
		for lane: String in ["condition", "action"]:
			var lane_rows: Array = event_row.conditions if lane == "condition" else event_row.actions
			for slot: int in range(lane_rows.size()):
				if not (lane_rows[slot] is Resource):
					continue
				var found: Dictionary = _finding_for(lane_rows[slot] as Resource, judged,
					event_row, lane, slot)
				if not found.is_empty():
					into.append(found)
		_walk(event_row.sub_events, judged, into)
