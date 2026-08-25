# EventForge - what the attached SCENE says about this sheet's effects, said in sentences.
#
# The sharpest shader trap in Godot is not the shader. It is that a material is a RESOURCE, and a
# resource is shared: twelve goblins pointing at one `goblin.tres` are twelve nodes and ONE material,
# so `Set effect.dissolve to 1.0` on the one the player hit dissolves all twelve. Nothing errors,
# the Inspector shows the same thing either way, and the row is exactly what anybody would have
# written. So the head says it before the game is run once.
#
# ONE BAND PER WEARING NODE of the scene this sheet is attached to, in scene order, each carrying
# three facts and nothing else:
#   the material file and the shader behind it - the chain the dial rows depend on;
#   who else wears it - the count that turns one row into twelve;
#   the draw order when the material hands on to another (`next_pass`), because two passes chained
#   the wrong way round look identical in the Inspector and only differ on screen.
#
# THE COUNT IS NEVER PAID FOR ON THE OPEN. "Who else wears this file" is a question about every scene
# in the project, so it goes through the shared project index, which builds a slice per frame; a band
# asked before that finishes says "counting…" and is right a moment later. Nothing here ever waits
# for a scan.
#
# WITH THE COPY TAKEN, the band says so instead of warning. A sheet holding `Make the effect this
# node's own` aimed at the node has already answered the question, and repeating the warning at
# somebody who has fixed it is how a head stops being read. Which nodes those are is a question about
# the ROWS rather than about the scene, so it is asked of the sheet's own reader and handed in.
#
# NOTHING IS STORED. Every sentence is derived from the scene on every ask, so a `.gd` still
# round-trips byte for byte and a project with no shaders in it grows no bands at all.
#
# PURE + STATIC: a path in, plain Dictionaries out. No dock, no canvas, no editor.
@tool
class_name EventSheetSceneEffectFacts
extends RefCounted


## The `effect` bands of one sheet, in scene order - one per node of its attached scene that wears a
## material. `copied` is the nodes the sheet already gives their own copy of the material, as the
## reference keys its rows address them by. Empty for a sheet no single scene runs, exactly as the
## lighting bands are: a behaviour worn by five levels has no one scene to say anything about.
static func effect_bands(script_path: String,
		copied: PackedStringArray = PackedStringArray()) -> Array[Dictionary]:
	var bands: Array[Dictionary] = []
	if EventSheetSceneLightingFacts.attached_scene(script_path).is_empty():
		return bands
	# Starting the scan HERE is what keeps it off the open: the answer for this frame is whatever the
	# index already has, and the slices that finish it run on the frames after.
	var counted: bool = EventSheetProjectShareIndex.request()
	for wearer: Dictionary in EventSheetSceneEffects.for_script(script_path):
		bands.append(_band(wearer, counted, copied.has(
			EventSheetSceneEffects.reference_key_of(str(wearer.get("reference", ""))))))
	return bands


## One node's band: what it wears, who else wears it, and the passes it draws in.
static func _band(wearer: Dictionary, counted: bool, owns_its_copy: bool) -> Dictionary:
	var material_path: String = str(wearer.get("material_path", ""))
	var others: Array[Dictionary] = [] as Array[Dictionary]
	if not material_path.is_empty():
		others = EventSheetProjectShareIndex.other_wearers(material_path, _reference(wearer))
	return {
		"value": reading(wearer, others, counted, owns_its_copy),
		"echo": echo(wearer, others),
		"reference": _reference(wearer),
		# Shared and not copied is the fact worth colouring: every row this sheet writes about the
		# node writes it for every other node in the count as well.
		"warning": counted and not owns_its_copy and not others.is_empty()
	}


## What the band says. The material file leads because it is the thing that is shared; the shader
## follows because it is what the dial rows are named from; the sharing is last because it is the
## sentence a reader is meant to stop on.
static func reading(wearer: Dictionary, others: Array[Dictionary], counted: bool,
		owns_its_copy: bool) -> String:
	var words: PackedStringArray = PackedStringArray([worn(wearer)])
	if str(wearer.get("material_path", "")).is_empty():
		words.append(EventSheetL10n.translate("kept inside this scene - nothing else wears it"))
	elif owns_its_copy:
		words.append(EventSheetL10n.translate("its own copy at runtime"))
	elif not counted:
		words.append(EventSheetL10n.translate("counting…"))
	elif others.is_empty():
		words.append(EventSheetL10n.translate("worn by this node only"))
	else:
		words.append(EventSheetL10n.translate("shared with %d other node") % others.size() \
			if others.size() == 1 \
			else EventSheetL10n.translate("shared with %d other nodes") % others.size())
	return " · ".join(words)


## The file this node wears and the shader at the end of it: `goblin.tres (dissolve.gdshader)`, with
## every further pass named after it in the order they are drawn. A chain the reader can check
## against the screen, which is the only place its order is otherwise visible.
static func worn(wearer: Dictionary) -> String:
	var material_path: String = str(wearer.get("material_path", ""))
	var shader_path: String = str(wearer.get("shader_path", ""))
	if material_path.is_empty():
		var kept: String = EventSheetL10n.translate("a material of its own")
		return kept if shader_path.is_empty() else "%s (%s)" % [kept, shader_path.get_file()]
	var drawn: PackedStringArray = PackedStringArray()
	for one_pass: Dictionary in EventSheetSceneEffects.pass_chain(material_path):
		var runs: String = str(one_pass["shader_path"])
		drawn.append(runs.get_file() if not runs.is_empty() \
			else str(one_pass["material_path"]).get_file())
	return "%s (%s)" % [material_path.get_file(),
		(" %s " % EventSheetL10n.translate("then")).join(drawn)]


## The node's own line of the scene file, then the dials the shader at the end of the chain declares,
## then the other wearers - the loud half of the fact, so a reader can see which names their rows may
## use and which nodes a dial row would move as well as this one.
##
## `uniform` is the shader language's own word and stays in it, like `class_name` and `@tool` in the
## echoes beside this one: an echo says what a file says.
static func echo(wearer: Dictionary, others: Array[Dictionary]) -> String:
	var written: String = "%s: %s \"%s\", %s = %s" % [
		str(wearer.get("scene_path", "")).get_file(), str(wearer.get("class", "")),
		str(wearer.get("name", "")), EventSheetSceneEffects.MATERIAL_PROPERTY,
		"SubResource" if str(wearer.get("material_path", "")).is_empty() \
			else "\"%s\"" % str(wearer.get("material_path", ""))]
	var dials: PackedStringArray = PackedStringArray()
	for dial: Variant in wearer.get("dials", []) as Array:
		dials.append(str((dial as Dictionary).get("name", "")))
	if not dials.is_empty():
		written += " · uniform %s" % ", ".join(dials)
	if others.is_empty():
		return written
	var names: PackedStringArray = PackedStringArray()
	for other: Dictionary in others:
		names.append(str(other.get("name", "")))
	return "%s · %s %s" % [written, EventSheetL10n.translate("also worn by"), ", ".join(names)]


## The scene and node a band is about, in the "scene|node" spelling the head's gestures read.
static func _reference(node: Dictionary) -> String:
	return "%s|%s" % [str(node.get("scene_path", "")), str(node.get("path", ""))]
