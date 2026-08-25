# EventForge - the animations a scene really has, read from the scene.
#
# An animation name is a string, and a string is where the silent failures live: `play("atack")`
# plays nothing and says nothing. The scene knows better - an AnimationPlayer lists its clips, an
# AnimatedSprite2D lists its flipbooks - so the name is something a reader can PICK rather than
# type, a row naming one nothing declares can go amber, and a chain that queues after a looping clip
# can be caught before the game runs.
#
# TWO SOURCES, one shape. They are genuinely different things and the difference decides what a row
# may ask of them:
#
#   AnimationPlayer   keyframed and skeletal motion. Has a length, a loop mode and named MARKERS.
#                     Has no frames at all, so no row here may ever offer it a frame number.
#   SpriteFrames      the flipbook of an AnimatedSprite2D / AnimatedSprite3D. Has real, countable,
#                     0-based frames, a speed and a loop flag; its length is frames / speed.
#
# READ AS TEXT, like every other scene fact in this plugin: a `.tscn` writes its SpriteFrames and its
# AnimationLibrary as sub-resources, and both spell their names, loops, speeds and markers in plain
# text. Nothing is instanced, no texture is loaded, and a project with no animation nodes pays one
# class test per node.
#
# NOTHING IS STORED. Every answer is derived from the scene on every ask (held per file stamp for the
# session), so a `.gd` still round-trips byte for byte.
@tool
class_name EventSheetSceneAnimations
extends RefCounted

## The node classes that hold animations, and the word for what each one holds. A class not here has
## no animations to offer, which is what makes the frame field impossible to show on the wrong node.
const PLAYER_CLASS: String = "AnimationPlayer"
const FRAMES_CLASSES: PackedStringArray = ["AnimatedSprite2D", "AnimatedSprite3D"]

## The two kinds a source can be. Ids, never display strings: a test pins them and the frame field
## asks for one by name.
const KIND_PLAYER: String = "player"
const KIND_FRAMES: String = "frames"

## The properties each source keeps its animations under.
const LIBRARIES_PROPERTY: String = "libraries"
const FRAMES_PROPERTY: String = "sprite_frames"

## The keys an Animation sub-resource writes, and the loop mode that means "no loop".
const LIBRARY_DATA_PROPERTY: String = "_data"
const LENGTH_PROPERTY: String = "length"
const LOOP_MODE_PROPERTY: String = "loop_mode"
const MARKERS_PROPERTY: String = "markers"
const LOOP_MODE_NONE: String = "0"

## scene path stamp -> the sources of that scene. Held for the session because the head band, the
## picker, the autocomplete and the findings all ask the same question of the same file.
static var _cache: Dictionary = {}


## The animation sources of the ONE scene this script is attached to, in scene order. Empty when no
## single scene runs the script - a behaviour worn by five levels has no one scene to read.
static func for_script(script_path: String) -> Array[Dictionary]:
	var scene_path: String = EventSheetSceneLightingFacts.attached_scene(script_path)
	return [] as Array[Dictionary] if scene_path.is_empty() else for_scene(scene_path)


## Every animation source of one scene, each as
##   {"name", "path", "class", "kind", "scene_path", "reference", "animations"}
## where an animation is {"name", "length", "loop", "frames", "markers"} - `frames` is -1 for a
## player (it has none) and `markers` is empty for a flipbook (it has none).
static func for_scene(scene_path: String) -> Array[Dictionary]:
	var stamp: String = EventForgeFileStamp.of(scene_path)
	if _cache.has(stamp):
		return _cache[stamp]
	var sources: Array[Dictionary] = _read_scene(scene_path)
	_cache[stamp] = sources
	return sources


## Drops the read, so the next ask reads the scenes again. Called between fixtures by the tests and
## by the editor's filesystem ping, exactly as the readers beside this one are.
static func clear_cache() -> void:
	_cache.clear()


## Every animation name these sources declare, deduplicated, in scene order. What a picker lists and
## what a "does this name exist" question is asked against.
static func names_of(sources: Array[Dictionary]) -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	for source: Dictionary in sources:
		for animation: Dictionary in (source.get("animations", []) as Array):
			var animation_name: String = str(animation.get("name", ""))
			if not animation_name.is_empty() and not names.has(animation_name):
				names.append(animation_name)
	return names


## One named animation and the source that declares it, as {"source", "animation"} - {} when nothing
## declares it, which is the whole of the amber case.
static func find(sources: Array[Dictionary], animation_name: String) -> Dictionary:
	var wanted: String = unquoted(animation_name)
	for source: Dictionary in sources:
		for animation: Dictionary in (source.get("animations", []) as Array):
			if str(animation.get("name", "")) == wanted:
				return {"source": source, "animation": animation}
	return {}


## The words that describe one animation in a list or on a band: the loop word when it loops, its
## length in seconds when it does not. Both would be noise - a looping clip's length is not what
## anybody is deciding by.
static func reading(animation: Dictionary) -> String:
	if bool(animation.get("loop", false)):
		return EventSheetL10n.translate("loop")
	var length: float = float(animation.get("length", 0.0))
	return EventSheetL10n.translate("%s s") % String.num(length, 2).trim_suffix("0").trim_suffix("0").trim_suffix(".")


## The name a row wrote, without the quotes or the `&` a StringName carries - the form every question
## here is asked in, so `&"walk"`, `"walk"` and `walk` are one name.
static func unquoted(value: String) -> String:
	var text: String = value.strip_edges().trim_prefix("&")
	if text.length() >= 2 and text.begins_with("\"") and text.ends_with("\""):
		return text.substr(1, text.length() - 2)
	return text


## The nearest declared name to one that is not declared, for the re-pick offer. Empty when nothing
## is near enough to be worth offering - a wrong suggestion is worse than none.
static func nearest(sources: Array[Dictionary], animation_name: String) -> String:
	var wanted: String = unquoted(animation_name)
	var best: String = ""
	var best_score: float = 0.0
	for candidate: String in names_of(sources):
		var score: float = wanted.similarity(candidate)
		if score > best_score:
			best_score = score
			best = candidate
	return best if best_score >= 0.6 else ""


## How many names a band spells before it starts counting. A band states what the SHEET touches and
## counts the rest: a character with a hundred and thirty-one clips is still a one-line fact, and the
## whole list is one click away in the picker. A band that enumerates a hundred things is not a fact.
const BAND_NAMES_SHOWN: int = 6


## The `animations` bands: one per animation source of the attached scene, saying which of its
## animations this sheet plays and how many more there are, then a warning band for each of the two
## things the scene can say are wrong before the game runs.
##
## `used` is every animation name the sheet's rows hold and `chained` the names that rows play with
## something QUEUED BEHIND them. Both are read once by the caller and handed in, because both come
## out of the same walk of the rows.
static func bands(script_path: String, used: PackedStringArray,
		chained: PackedStringArray = PackedStringArray()) -> Array[Dictionary]:
	var built: Array[Dictionary] = []
	var sources: Array[Dictionary] = for_script(script_path)
	if sources.is_empty():
		return built
	for source: Dictionary in sources:
		built.append({
			"value": band_reading(source, used),
			"echo": band_echo(source),
			"reference": str(source.get("reference", "")),
			"warning": false,
		})
	var missing: PackedStringArray = missing_names(sources, used)
	if not missing.is_empty():
		built.append(_warning_band(missing_warning(missing), sources[0]))
	for name_text: String in looping_chains(sources, chained):
		built.append(_warning_band(queue_never_comes(name_text), sources[0]))
	return built


## The animations these rows queue something behind that never end. `queue` waits for the current
## animation to FINISH, and a looping one never does - so the queued clip is simply never reached.
static func looping_chains(sources: Array[Dictionary], chained: PackedStringArray) -> PackedStringArray:
	var looping: PackedStringArray = PackedStringArray()
	for value: String in chained:
		var found: Dictionary = find(sources, value)
		if found.is_empty() or not bool((found["animation"] as Dictionary).get("loop", false)):
			continue
		var name_text: String = str((found["animation"] as Dictionary).get("name", ""))
		if not looping.has(name_text):
			looping.append(name_text)
	return looping


## A band that reports a problem: the warning's own words, pointed at the scene's first source so
## clicking it opens the node the reader has to go and look at.
static func _warning_band(words: String, source: Dictionary) -> Dictionary:
	return {"value": words, "echo": band_echo(source),
		"reference": str(source.get("reference", "")), "warning": true}


## What one source's band says: the animations these rows play, each with its length or its loop
## word, then a count of everything else the node holds.
static func band_reading(source: Dictionary, used: PackedStringArray) -> String:
	var animations: Array = source.get("animations", [])
	var spelled: PackedStringArray = PackedStringArray()
	for entry: Variant in animations:
		var animation: Dictionary = entry
		if spelled.size() >= BAND_NAMES_SHOWN:
			break
		if _is_used(used, str(animation.get("name", ""))):
			spelled.append("%s %s" % [str(animation.get("name", "")), reading(animation)])
	var rest: int = animations.size() - spelled.size()
	var tail: String = EventSheetL10n.translate("%d more in %s") % [rest, str(source.get("name", ""))] \
		if rest > 0 else ""
	if spelled.is_empty():
		return EventSheetL10n.translate("%d in %s") % [animations.size(), str(source.get("name", ""))]
	var words: String = "%s %s" % [EventSheetL10n.translate("uses"), " · ".join(spelled)]
	return words if tail.is_empty() else "%s · %s" % [words, tail]


## The source's own line of the scene file, and how many animations it really holds.
static func band_echo(source: Dictionary) -> String:
	return "%s: %s \"%s\", %d %s" % [str(source.get("scene_path", "")).get_file(),
		str(source.get("class", "")), str(source.get("name", "")),
		(source.get("animations", []) as Array).size(), EventSheetL10n.translate("animations")]


## The animation names these rows ask for that no source of the scene declares - the silent failure
## this whole reading exists for, said before the game runs.
static func missing_names(sources: Array[Dictionary], used: PackedStringArray) -> PackedStringArray:
	var missing: PackedStringArray = PackedStringArray()
	for name_text: String in used:
		var bare: String = unquoted(name_text)
		# A name built at run time is not a name to check: `"attack_" + weapon` names nothing today
		# and everything tomorrow, and the free-string rows exist precisely for it.
		if bare.is_empty() or not _is_a_plain_name(name_text) or missing.has(bare):
			continue
		if find(sources, bare).is_empty():
			missing.append(bare)
	return missing


## THE warning, in one place: the band shows it and the Doctor check raises it, so a reader meets
## the same words wherever they meet the problem.
static func missing_warning(missing: PackedStringArray) -> String:
	return EventSheetL10n.translate("%s is not an animation of this scene - the row plays nothing") \
		% ", ".join(missing)


## The note a chain earns when what it plays first never ends. `queue` runs when the current
## animation FINISHES, and a looping one never does.
static func queue_never_comes(animation_name: String) -> String:
	return EventSheetL10n.translate("%s loops - the queue never comes") % animation_name


## True when a value is a plain quoted name rather than an expression - the only kind of value a
## list of declared names can honestly be checked against.
static func _is_a_plain_name(value: String) -> bool:
	var text: String = value.strip_edges().trim_prefix("&")
	return text.length() >= 2 and text.begins_with("\"") and text.ends_with("\"") \
		and not text.substr(1, text.length() - 2).contains("\"")


## True when one of the sheet's written values names this animation, whatever quoting it used.
static func _is_used(used: PackedStringArray, animation_name: String) -> bool:
	for value: String in used:
		if unquoted(value) == animation_name:
			return true
	return false


## The real SpriteFrames one flipbook source holds. The ONE thing in this file that LOADS rather
## than reads: a frame's picture is an image, and an image cannot be read out of text. Asked only
## when a dialog opens - never on a row rebuild, never on a sheet open - so the cost lands on a
## gesture and nowhere else. Null when the scene has no such node, or when it is not a flipbook.
static func frames_of(source: Dictionary) -> SpriteFrames:
	if str(source.get("kind", "")) != KIND_FRAMES:
		return null
	var packed: PackedScene = load(str(source.get("scene_path", ""))) as PackedScene
	if packed == null:
		return null
	var state: SceneState = packed.get_state()
	var wanted: String = str(source.get("path", ""))
	for node_index: int in state.get_node_count():
		if str(state.get_node_path(node_index)) != wanted:
			continue
		for property_index: int in state.get_node_property_count(node_index):
			if str(state.get_node_property_name(node_index, property_index)) == FRAMES_PROPERTY:
				return state.get_node_property_value(node_index, property_index) as SpriteFrames
	return null


# ── the read ────────────────────────────────────────────────────────────────────────────


## The walk itself. One pass for the sub-resources the file keeps, one for its nodes, and a source
## per node whose class holds animations.
static func _read_scene(scene_path: String) -> Array[Dictionary]:
	var sources: Array[Dictionary] = []
	var nodes: Array = EventSheetSceneConnections.nodes_of_scene(scene_path)
	if nodes.is_empty():
		return sources
	var holders: Array = []
	for entry: Variant in nodes:
		var node: Dictionary = entry
		var kind: String = _kind_of(str(node.get("type", "")))
		if not kind.is_empty():
			holders.append([node, kind])
	if holders.is_empty():
		return sources
	var subs: Dictionary = EventSheetSceneConnections.sub_resources_of_scene(scene_path)
	var externals: Dictionary = EventSheetSceneConnections.resource_paths_of_scene(scene_path)
	for holder: Array in holders:
		var node: Dictionary = holder[0]
		var kind: String = str(holder[1])
		var properties: Dictionary = node.get("properties", {})
		var animations: Array[Dictionary] = _player_animations(_libraries_written(properties), subs, externals) \
			if kind == KIND_PLAYER \
			else _flipbook_animations(str(properties.get(FRAMES_PROPERTY, "")), subs, externals)
		sources.append({
			"name": str(node.get("name", "")),
			"path": str(node.get("path", "")),
			"class": str(node.get("type", "")),
			"kind": kind,
			"scene_path": scene_path,
			"reference": "%s|%s" % [scene_path, str(node.get("path", ""))],
			"animations": animations,
		})
	return sources


## Every library an AnimationPlayer node holds, as one written value. A scene spells the default
## library `libraries/ = SubResource("…")` and a named one `libraries/moves = …`, one line each - so
## the answer is the whole set of those lines rather than one property called `libraries`.
static func _libraries_written(properties: Dictionary) -> String:
	var written: PackedStringArray = PackedStringArray()
	for key: Variant in properties.keys():
		var name_text: String = str(key)
		if name_text == LIBRARIES_PROPERTY or name_text.begins_with(LIBRARIES_PROPERTY + "/"):
			written.append(str(properties[key]))
	return " ".join(written)


## Which kind of source a node class is, "" when it holds no animations.
static func _kind_of(node_class: String) -> String:
	if node_class.is_empty() or not ClassDB.class_exists(node_class):
		return ""
	if ClassDB.is_parent_class(node_class, PLAYER_CLASS):
		return KIND_PLAYER
	for frames_class: String in FRAMES_CLASSES:
		if ClassDB.is_parent_class(node_class, frames_class):
			return KIND_FRAMES
	return ""


## The clips of an AnimationPlayer. Its `libraries` is a dictionary of library resources, each of
## which keys its own clips by name - so the names come from the library and the facts from the
## Animation each name points at.
static func _player_animations(libraries: String, subs: Dictionary, externals: Dictionary) -> Array[Dictionary]:
	var animations: Array[Dictionary] = []
	for library: Dictionary in _resources_named_in(libraries, subs, externals):
		var data: String = str((library.get("properties", {}) as Dictionary).get(LIBRARY_DATA_PROPERTY, ""))
		var library_subs: Dictionary = library.get("siblings", subs)
		for reference: String in _references_in(data):
			var clip: Dictionary = _resource_of(reference, library_subs, library.get("externals", externals))
			if clip.is_empty():
				continue
			var properties: Dictionary = clip.get("properties", {})
			animations.append({
				"name": _name_before(data, reference),
				"length": float(str(properties.get(LENGTH_PROPERTY, "0")).to_float()),
				"loop": str(properties.get(LOOP_MODE_PROPERTY, LOOP_MODE_NONE)).strip_edges() != LOOP_MODE_NONE,
				"frames": -1,
				"markers": _markers_in(str(properties.get(MARKERS_PROPERTY, ""))),
			})
	return animations


## The flipbooks of a SpriteFrames: one entry per animation in its own `animations` array, each
## carrying its frames, its loop flag and the speed the length is worked out from.
static func _flipbook_animations(frames_property: String, subs: Dictionary, externals: Dictionary) -> Array[Dictionary]:
	var animations: Array[Dictionary] = []
	for frames: Dictionary in _resources_named_in(frames_property, subs, externals):
		var written: String = str((frames.get("properties", {}) as Dictionary).get("animations", ""))
		for entry: String in _entries_in(written):
			var speed: float = maxf(_number_in(entry, "speed"), 0.001)
			var count: int = entry.count("\"texture\":")
			animations.append({
				"name": _quoted_after(entry, "\"name\":"),
				"length": float(count) / speed,
				"loop": _number_in(entry, "loop") != 0.0,
				"frames": count,
				"markers": [] as Array[Dictionary],
			})
	return animations


## The markers of one Animation, as [{"name", "time"}] in the order the file wrote them - the named
## moments an author can ask about instead of counting frames a keyframed clip does not have.
static func _markers_in(written: String) -> Array[Dictionary]:
	var markers: Array[Dictionary] = []
	for entry: String in _entries_in(written):
		var marker_name: String = _quoted_after(entry, "\"name\":")
		if not marker_name.is_empty():
			markers.append({"name": marker_name, "time": _number_in(entry, "time")})
	return markers


## The resources one property points at, whether the file keeps them inside itself or in another
## file. An external resource is read the same way this one was, so an AnimationLibrary saved as a
## `.tres` beside the scene answers exactly as one written into it.
static func _resources_named_in(written: String, subs: Dictionary, externals: Dictionary) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for reference: String in _references_in(written):
		var resource: Dictionary = _resource_of(reference, subs, externals)
		if not resource.is_empty():
			found.append(resource)
	return found


## One `SubResource("id")` / `ExtResource("id")` as the block it names: the scene's own, or the
## `[resource]` of the file it points at. A binary `.res` answers with nothing, which leaves its
## clips unlisted rather than guessed at.
static func _resource_of(reference: String, subs: Dictionary, externals: Dictionary) -> Dictionary:
	var id: String = reference.get_slice("\"", 1)
	if reference.begins_with("SubResource("):
		return subs.get(id, {})
	var path: String = str(externals.get(id, ""))
	if path.is_empty() or not (path.ends_with(".tres") or path.ends_with(".tscn")):
		return {}
	var lines: PackedStringArray = EventSheetSceneConnections.folded(
		FileAccess.get_file_as_string(path).split("\n"))
	var file_subs: Dictionary = EventSheetSceneConnections.sub_resources_in(lines)
	var resource: Dictionary = {"properties": _resource_properties(lines),
		"siblings": file_subs, "externals": EventSheetSceneConnections.resource_paths_in(lines)}
	return resource


## The `[resource]` block of a resource file - the properties the file's own resource holds.
static func _resource_properties(lines: PackedStringArray) -> Dictionary:
	var properties: Dictionary = {}
	var inside: bool = false
	for line: String in lines:
		if line.begins_with("["):
			inside = line.begins_with("[resource]")
			continue
		var assignment: int = line.find(" = ")
		if inside and assignment > 0:
			properties[line.substr(0, assignment).strip_edges()] = line.substr(assignment + 3).strip_edges()
	return properties


## Every `SubResource("…")` / `ExtResource("…")` a written value names, in order.
static func _references_in(written: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	for marker: String in ["SubResource(", "ExtResource("]:
		var cursor: int = written.find(marker)
		while cursor >= 0:
			var closing: int = written.find(")", cursor)
			if closing < 0:
				break
			found.append(written.substr(cursor, closing - cursor + 1))
			cursor = written.find(marker, closing)
	return found


## The dictionary KEY a reference is the value of: `"walk": SubResource("Animation_a")` -> `walk`.
## The library writes the clip's name there, which is the name `play()` is called with.
static func _name_before(written: String, reference: String) -> String:
	var at: int = written.find(reference)
	if at <= 0:
		return ""
	var head: String = written.substr(0, at)
	var colon: int = head.rfind(":")
	return _quoted_tail(head.substr(0, colon)) if colon > 0 else ""


## The last quoted run of a fragment - what sits immediately before the colon of a dictionary entry.
static func _quoted_tail(head: String) -> String:
	var closing: int = head.rfind("\"")
	if closing <= 0:
		return ""
	var opening: int = head.rfind("\"", closing - 1)
	return head.substr(opening + 1, closing - opening - 1) if opening >= 0 else ""


## The `{…}` entries of an array value, one string each. Depth-counted rather than split, because
## every entry holds arrays and dictionaries of its own (a flipbook's frames, a marker's colour).
static func _entries_in(written: String) -> PackedStringArray:
	var entries: PackedStringArray = PackedStringArray()
	var depth: int = 0
	var start: int = -1
	var quoted: bool = false
	for index: int in written.length():
		var character: String = written[index]
		if character == "\"" and (index == 0 or written[index - 1] != "\\"):
			quoted = not quoted
			continue
		if quoted:
			continue
		if character == "{":
			if depth == 1:
				start = index
			depth += 1
		elif character == "[":
			depth += 1
		elif character == "}" or character == "]":
			depth -= 1
			if character == "}" and depth == 1 and start >= 0:
				entries.append(written.substr(start, index - start + 1))
				start = -1
	return entries


## The quoted value written after a key inside one entry, `&` and quotes dropped.
static func _quoted_after(entry: String, key: String) -> String:
	var at: int = entry.find(key)
	if at < 0:
		return ""
	return unquoted(entry.substr(at + key.length()).get_slice(",", 0))


## The number written after a key inside one entry - 0 when the key is absent, which is the answer
## that reads as "does not loop" and as "no time".
static func _number_in(entry: String, key: String) -> float:
	var at: int = entry.find("\"%s\":" % key)
	if at < 0:
		return 0.0
	var written: String = entry.substr(at + key.length() + 3).get_slice(",", 0).get_slice("}", 0).strip_edges()
	if written == "true":
		return 1.0
	return written.to_float()
