# Godot EventSheets - the "spawns" band: what this sheet puts into the world.
#
# A sheet that spawns is a sheet whose most important fact is not in its head: the scenes it makes
# copies of are buried in rows halfway down, one parameter at a time, and the cap that keeps the
# count sane is buried beside them. This band is that fact, said once at the top, in the sheet's own
# words - the same place the reader already looks for `extends` and `@tool`.
#
# WHAT IT SAYS, per scene spawned: the scene, and the two facts that decide whether the spawning is
# safe to leave running - the CAP a crowd row puts on it, and the POOL a pack row takes it from. A
# scene spawned with neither says so by saying nothing more, which is the honest reading: there is
# no cap and there is no pool.
#
# THE BAND SCALE LAW. A band lists what the sheet USES and counts the rest. A sheet spawning three
# scenes gets three bands; a sheet spawning twenty gets the first few and one band saying how many
# more there are, because a head that is longer than the sheet is not a head.
#
# WHERE THE FACTS COME FROM, and where they do NOT. The rows are read once from the sheet that is
# already in memory, and the scene side is the SAME replication index the "spawned by" band above it
# reads - `EventSheets.spawners_of`, which is cached per script path. Nothing here opens a file, and
# nothing here starts a scan: one join, once per open, over indexes somebody else already paid for.
#
# PURE + STATIC, like every other band reader: a sheet goes in and a list of readings comes out, so
# the whole band is pinned headless without a canvas.
@tool
class_name EventSheetSpawnFacts
extends RefCounted

## How many scenes the band names before it starts counting. Four is the number of lines a head can
## grow without stopping being a head; the rest are counted on one line below them.
const SHOWN_LIMIT: int = 4

## The shape of a row that MAKES a copy, read off the row's own template rather than from a list of
## ace_ids - `var {slot} = {scene}.instantiate()`. Derived on purpose: a spawn row a pack ships is on
## the band the moment its template says this, and no table has to learn its name.
const MINTING_PATTERN: String = "^var \\{(?<slot>[A-Za-z_][A-Za-z0-9_]*)\\}[ \\t]*=.*\\.instantiate\\(\\)"

## The parameters a spawn row keeps the three facts in. The scene is the thing spawned, the crowd is
## the group it joins, and the cap is the number the crowd is held to.
const SCENE_PARAM := "scene"
const CROWD_PARAM := "crowd"
const CAP_PARAM := "cap"

## The two calls a pooled spawn is written with, read off the emitted text exactly as the minting
## shape above is read off the template. A pool row does not instantiate anything - reusing a copy is
## precisely what it does instead - so the minting pattern cannot see it, and these two calls can.
##
## The declaring call comes first because it is the one that names the SCENE as well as the pool;
## a handing-out call names only the pool, which is all the band needs to say the copies are pooled.
const POOL_CREATE_CALL := "ObjectPool.create_pool("
const POOL_SPAWN_CALL := "ObjectPool.spawn("

## How a pool's own name is remembered in the seen-map, kept apart from the scene keys beside it: a
## pool called "bullets" and a scene called "bullets" are two different facts, and one band each.
const POOL_KEY_PREFIX := "pool:"

## The same shape as it appears in a FINISHED line rather than in a template - what a hand-written
## spawn inside a verbatim block looks like, with the scene it is a copy of captured.
const HAND_WRITTEN_PATTERN: String = "^var[ \\t]+[A-Za-z_][A-Za-z0-9_]*[ \\t]*=[ \\t]*(?<scene>.+)\\.instantiate\\(\\)[ \\t]*$"

## Compiled once for the life of the session: these are asked of every action of every sheet opened.
static var _minting_regex: RegEx = null
static var _hand_regex: RegEx = null


## The band's readings, in first-mention order: one entry per scene this sheet spawns, then one
## counting the scenes it spawns that the band did not name. Empty for a sheet that spawns nothing,
## which is what keeps the head of every other sheet exactly as it was.
##
## Each entry is the shape the head's scene bands read - `{"value", "echo", "reference"}` - so the
## band model needs to learn nothing about spawning to show it.
static func bands(sheet: EventSheetResource) -> Array[Dictionary]:
	var readings: Array[Dictionary] = []
	var spawned: Array[Dictionary] = spawned_scenes(sheet)
	if spawned.is_empty():
		return readings
	for index: int in range(mini(spawned.size(), SHOWN_LIMIT)):
		var entry: Dictionary = spawned[index]
		readings.append({
			"value": reading(entry),
			"echo": str(entry.get("echo", "")),
			"reference": str(entry.get("path", "")),
		})
	var counted: int = spawned.size() - SHOWN_LIMIT
	if counted > 0:
		readings.append({
			"value": EventSheetL10n.translate("and %d more scene(s) spawned") % counted,
			"echo": "", "reference": "",
		})
	return readings


## Every scene this sheet spawns, first mention first, each with what the sheet says about it:
##   {"scene", "path", "crowd", "cap", "pool", "echo"}
## `scene` is the expression the row holds (which is what the sheet reads as), `path` is the scene
## file when the expression names one outright, and the rest are "" when nothing said them.
##
## The rows come first and the scene comes second, in that order deliberately: a scene listed on a
## MultiplayerSpawner that no row ever names is still spawned - by the spawner, on the host's word -
## and a band that left it out would be reading half the file.
static func spawned_scenes(sheet: EventSheetResource) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	var seen: Dictionary = {}
	if sheet == null:
		return found
	_walk(sheet.events, found, seen)
	for entry: Variant in sheet.functions:
		var event_function: EventFunction = entry as EventFunction
		if event_function != null:
			_walk(event_function.events, found, seen)
	for entry: Dictionary in EventSheets.spawners_of(sheet):
		if str(entry.get("relation", "")) != EventSheetSceneReplication.RELATION_IN_SCENE:
			continue
		for scene_path: String in PackedStringArray(entry.get("scenes", PackedStringArray())):
			var key: String = scene_path.strip_edges()
			if key.is_empty() or seen.has(key):
				continue
			seen[key] = true
			found.append({
				"scene": key, "path": key, "crowd": "", "cap": "", "pool": "",
				"echo": "%s: %s" % [str(entry.get("name", "")).strip_edges(), key],
			})
	return found


## One scene's reading: the file, and only the facts the sheet really said about it. A scene with no
## cap and no pool reads as its own name and nothing else, because "no cap" is what the absence of a
## cap means and inventing a word for it would be inventing a fact.
static func reading(entry: Dictionary) -> String:
	var name_text: String = str(entry.get("path", "")).get_file()
	if name_text.is_empty():
		name_text = str(entry.get("scene", "")).strip_edges()
	var said: PackedStringArray = PackedStringArray()
	var cap: String = str(entry.get("cap", "")).strip_edges()
	var crowd: String = _bare(str(entry.get("crowd", "")))
	if not cap.is_empty() and not crowd.is_empty():
		said.append(EventSheetL10n.translate("at most %s in %s") % [cap, crowd])
	elif not crowd.is_empty():
		said.append(EventSheetL10n.translate("into %s") % crowd)
	var pool: String = _bare(str(entry.get("pool", "")))
	if not pool.is_empty():
		said.append(EventSheetL10n.translate("pooled as %s") % pool)
	if said.is_empty():
		return name_text
	return "%s - %s" % [name_text, ", ".join(said)]


## The scene file one spawn expression names, or "" when it builds the path at run time. Two
## spellings are read because two spellings are what sheets hold: a `load("res://x.tscn")` or
## `preload(...)` written into the field, and a path the field simply holds outright.
static func scene_path_of(scene_expression: String) -> String:
	var expression: String = scene_expression.strip_edges()
	if expression.begins_with("res://") and expression.contains("."):
		return expression
	var opening: int = expression.find("\"")
	if opening < 0:
		return ""
	var closing: int = expression.find("\"", opening + 1)
	if closing < 0:
		return ""
	var quoted: String = expression.substr(opening + 1, closing - opening - 1)
	return quoted if quoted.begins_with("res://") else ""


# -- the pieces ------------------------------------------------------------------------------


## Walks a row list once, collecting the spawns in file order. Groups and sub-events are walked into
## because a group is a bracket around rows rather than another sheet, and a spawn under a condition
## is still a spawn this sheet does.
static func _walk(items: Array, found: Array[Dictionary], seen: Dictionary) -> void:
	for item: Variant in items:
		if item is EventGroup:
			_walk(EventSheetGroupFacts.children(item as EventGroup), found, seen)
			continue
		# A verbatim block is a row of the file like any other, and a spawn written by hand inside one
		# is a spawn this sheet does. It sits at the list level in a function body and among the
		# actions of an event, so both places ask the same question of it.
		if item is RawCodeRow:
			_collect(item as Resource, found, seen)
			continue
		var event_row: EventRow = item as EventRow
		if event_row == null:
			continue
		for entry: Variant in event_row.actions:
			_collect(entry as Resource, found, seen)
		_walk(event_row.sub_events, found, seen)


## One row's contribution: the scene it makes a copy of, or the pool it takes one from.
static func _collect(ace: Resource, found: Array[Dictionary], seen: Dictionary) -> void:
	if ace == null:
		return
	var params: Dictionary = _params_of(ace)
	_collect_pool(_filled_lines(ace), found, seen)
	var scene: String = str(params.get(SCENE_PARAM, "")).strip_edges()
	if scene.is_empty() or not _mints_a_copy(ace):
		# Not a spawn ROW, but the line it writes may still be a spawn: opened code lifts the three
		# lines of a spawn into a local declaration, an Add Child and a placement rather than into the
		# spawn sentence, and the copy it makes is the same copy. Read off the finished line, which is
		# the only place that spelling says what it is a copy of.
		_collect_written_by_hand(_filled_lines(ace), found, seen)
		return
	var path: String = scene_path_of(scene)
	var key: String = path if not path.is_empty() else scene
	if seen.has(key):
		return
	seen[key] = true
	found.append({
		"scene": scene, "path": path,
		"crowd": str(params.get(CROWD_PARAM, "")).strip_edges(),
		"cap": str(params.get(CAP_PARAM, "")).strip_edges(),
		"pool": "",
		"echo": _first_line(ace),
	})


## The spawns a row writes in its own words: the same `var x = <scene>.instantiate()` shape a spawn
## row's template declares, matched against the FINISHED line rather than against a template. This is
## what puts opened hand-written spawning code on the band beside picked rows.
static func _collect_written_by_hand(code: String, found: Array[Dictionary],
		seen: Dictionary) -> void:
	if _hand_regex == null:
		_hand_regex = RegEx.new()
		_hand_regex.compile(HAND_WRITTEN_PATTERN)
	for line: String in code.split("\n"):
		var hit: RegExMatch = _hand_regex.search(line.strip_edges())
		if hit == null:
			continue
		var scene: String = hit.get_string("scene").strip_edges()
		var path: String = scene_path_of(scene)
		var key: String = path if not path.is_empty() else scene
		if key.is_empty() or seen.has(key):
			continue
		seen[key] = true
		found.append({"scene": scene, "path": path, "crowd": "", "cap": "", "pool": "",
			"echo": line.strip_edges()})


## The pooled spawns one row's filled-in text holds. A pool that declares its scene is recorded
## against that scene, so the band says "enemy.tscn - pooled as bullets" rather than naming the pool
## twice; a pool that only hands copies out is recorded against the pool's own name, which is the
## whole of what the sheet said about it.
##
## ONE POOL IS ONE BAND, whichever of its two calls the sheet says first. Declaring a pool and taking
## copies out of it are the two halves of the same spawning - a sheet doing both said one thing, not
## two - so the pool's own name is remembered beside the scene key, and the second call either fills
## the scene in on the band the first one made or is skipped as already said.
static func _collect_pool(text: String, found: Array[Dictionary], seen: Dictionary) -> void:
	for call_name: String in [POOL_CREATE_CALL, POOL_SPAWN_CALL]:
		var at: int = text.find(call_name)
		while at >= 0:
			var arguments: PackedStringArray = _quoted_arguments(text.substr(at + call_name.length()))
			var pool: String = arguments[0] if arguments.size() > 0 else ""
			var scene: String = arguments[1] if call_name == POOL_CREATE_CALL \
				and arguments.size() > 1 else ""
			var key: String = scene if not scene.is_empty() else pool
			var pool_key: String = "%s%s" % [POOL_KEY_PREFIX, pool]
			var echo: String = text.substr(at).split("\n")[0].strip_edges()
			if key.is_empty():
				at = text.find(call_name, at + 1)
				continue
			if seen.has(pool_key):
				# The other half of a pool already on the band. A declaring call arriving second is the
				# one that knows the scene, so it names the band the handing-out call opened; a
				# handing-out call arriving second has nothing to add and says nothing twice.
				if not scene.is_empty():
					var entry: Dictionary = found[int(seen[pool_key])]
					if str(entry.get("path", "")).is_empty():
						entry["scene"] = scene
						entry["path"] = scene
						entry["echo"] = echo
						seen[scene] = true
			elif not seen.has(key):
				seen[key] = true
				if not pool.is_empty():
					seen[pool_key] = found.size()
				found.append({"scene": key, "path": scene, "crowd": "", "cap": "",
					"pool": pool, "echo": echo})
			at = text.find(call_name, at + 1)


## The quoted arguments at the head of a call, in order - `"bullets", "res://bullet.tscn", 8` reads
## as the first two. Stops at the closing bracket, so a second call further down the same line is a
## second search rather than more arguments to this one.
static func _quoted_arguments(text: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	var stop: int = text.find(")")
	var head: String = text if stop < 0 else text.substr(0, stop)
	var at: int = head.find("\"")
	while at >= 0:
		var closing: int = head.find("\"", at + 1)
		if closing < 0:
			break
		found.append(head.substr(at + 1, closing - at - 1))
		at = head.find("\"", closing + 1)
	return found


## One row's emitted text with its parameters filled in - the text the file really holds, which is
## where a pooled spawn is written even when the row that holds it is about something else.
static func _filled_lines(ace: Resource) -> String:
	if ace is RawCodeRow:
		return (ace as RawCodeRow).code
	var text: String = _template_of(ace)
	var params: Dictionary = _params_of(ace)
	for key: Variant in params.keys():
		text = text.replace("{%s}" % str(key), str(params[key]))
	return text


## True when a row's own template declares a local out of a fresh instance - the shape of every
## spawn row there is, and of every hand-written spawn line that opened as one.
static func _mints_a_copy(ace: Resource) -> bool:
	if _minting_regex == null:
		_minting_regex = RegEx.new()
		_minting_regex.compile(MINTING_PATTERN)
	for line: String in _template_of(ace).split("\n"):
		if _minting_regex.search(line.strip_edges()) != null:
			return true
	return false


## The band's echo: the row's own first emitted line, with its parameters filled in, so the band
## shows the line the file holds rather than a sentence about it.
static func _first_line(ace: Resource) -> String:
	var template: String = _template_of(ace)
	if template.is_empty():
		return ""
	var line: String = template.split("\n")[0]
	for key: Variant in _params_of(ace).keys():
		line = line.replace("{%s}" % str(key), str(_params_of(ace)[key]))
	return line.replace("{target.}", "").replace("{target}", "self").strip_edges()


## A group or pool name without the quotes the field keeps it in - the band says the name, not the
## literal, because the literal is what the echo is for.
static func _bare(value: String) -> String:
	return value.strip_edges().trim_prefix("\"").trim_suffix("\"").strip_edges()


static func _template_of(ace: Resource) -> String:
	# A verbatim block has no template at all - its code IS the emitted text - and asking a resource
	# for a property it does not declare answers with a null that reads as a non-empty string.
	if ace == null or ace is RawCodeRow:
		return ""
	var baked: String = str(ace.get("codegen_template"))
	if not baked.strip_edges().is_empty():
		return baked
	var descriptor: ACEDescriptor = ACERegistry.find_descriptor(
		str(ace.get("provider_id")), str(ace.get("ace_id")))
	return "" if descriptor == null else descriptor.codegen_template


static func _params_of(ace: Resource) -> Dictionary:
	var params: Variant = ace.get("params")
	if params is Dictionary and not (params as Dictionary).is_empty():
		return params as Dictionary
	var alias: Variant = ace.get("parameters")
	return alias as Dictionary if alias is Dictionary else {}
