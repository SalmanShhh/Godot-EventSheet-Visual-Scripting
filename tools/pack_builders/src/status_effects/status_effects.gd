# Pack source - status_effects. The behaviour code this pack ships, as real GDScript: highlighted,
# checked and breakpointable here, and assembled into the pack by Lib.pack_from_source.
# Every #region, and the body of every top-level func, is one piece of the sheet; everything
# else is scaffolding the pack declares for itself at build time and never reads from here.
extends Node

var host: Node = null

#region block_1
## Where the effect files live. An effect is a FILE in this folder, so `burn.tres` is the effect a
## row calls "burn" and adding one is dropping a file in a folder. The six starters ship here; point
## this at your own folder once you have copied and edited them.
@export_dir var effects_folder: String = "res://eventsheet_addons/status_effects"
## Effect files dropped straight onto this node, looked in BEFORE the folder - so one enemy can
## carry its own version of "burn" without the folder or any other enemy knowing about it.
@export var effects: Array = []
## Warns about a status applied under a name no file answers to, and about a tick with damage in it
## on a host that has no Health behaviour to take it. On while you build, off for release.
@export var debug_mode: bool = false

## Fires when a status lands, including the second and later times it is applied.
## @ace_trigger
## @ace_name("On Status Applied")
signal status_applied(status: String, stacks: int)

## Fires on every tick of an active status, after its damage and healing have been dealt.
## @ace_trigger
## @ace_name("On Status Ticked")
signal status_ticked(status: String, stacks: int)

## Fires when a status ends, however it ended - the clock ran out, it was removed, it was cleansed,
## or an immunity pushed it off.
## @ace_trigger
## @ace_name("On Status Expired")
signal status_expired(status: String)

## Fires when an active status changes how many stacks it is on, and not when it lands at the count
## it was already on.
## @ace_trigger
## @ace_name("On Stacks Changed")
signal stacks_changed(status: String, stacks: int)

## What is on right now: the status word -> {effect, remaining, stacks, tick_in, particles}. The
## effect is resolved ONCE, when the status lands, so a tick never touches the disk.
var _active: Dictionary = {}

## What cannot land right now: the status word -> the seconds of immunity left.
var _immune: Dictionary = {}

## The host's own colour, remembered the moment the first tint goes on and put back when the last
## one comes off - so a status can never leave a permanently coloured sprite behind.
var _base_modulate: Color = Color(1.0, 1.0, 1.0, 1.0)
var _tint_applied: bool = false

## The two Engine meta this project keeps its accessibility answers in - the same two the built-in
## Set No Flashing and Set Effect Strength rows write, and the same two the screen effects read.
const NO_FLASHING_META: StringName = &"no_flashing"
const EFFECT_STRENGTH_META: StringName = &"effect_strength"

## How far a tint may pull the host's colour while a player has asked for no flashing. A status
## tint does not blink, but several arriving and leaving in a second is a flicker all the same, so
## it is held to the same ceiling the screen effects use.
const TINT_CEILING: float = 0.3

## The tick this pack falls back to when an effect file asks for one of zero seconds, which would
## otherwise be a tick every frame - or, worse, a loop that never advances.
const MINIMUM_TICK_SECONDS: float = 0.05

## The ownership key this whole project credits kills through, written by the Claim row.
const OWNER_META: StringName = &"owner"

## The effect file a status word names: one dropped on this node first, then the folder, and null
## when nothing answers to it. A status with no file still applies - it is a name and a clock, which
## is all Has Status needs - so a plain flag costs no authoring at all.
##
## AN EFFECT ANSWERS TO WHAT IT CALLS ITSELF, whichever door it came in by. A file says its own name
## - Status Name when it has been filled in, its file name when it has not - so the folder is asked
## the same question the dropped list is, rather than being keyed by file name alone. Without that,
## a file renamed while its Status Name stayed put answered to one word through one door and another
## word through the other, and only one of the two matched what the guide promised.
##
## The ordinary case still costs one existence test: the file named after the word, when it agrees
## that the word is its name. The folder is only READ THROUGH when that misses, and sorted when it
## is, so two machines pick the same file if two of them claim the word.
## @ace_hidden
func _effect(status: String) -> Resource:
	for candidate: Variant in effects:
		if _answers_to(candidate as Resource, status):
			return candidate as Resource
	for extension: String in [".tres", ".res"]:
		var path: String = effects_folder.path_join(status + extension)
		if ResourceLoader.exists(path):
			var named: Resource = load(path)
			if _answers_to(named, status):
				return named
	var directory: DirAccess = DirAccess.open(effects_folder)
	if directory != null:
		var files: PackedStringArray = directory.get_files()
		files.sort()
		for file_name: String in files:
			if not (file_name.ends_with(".tres") or file_name.ends_with(".res")):
				continue
			var found: Resource = load(effects_folder.path_join(file_name))
			if _answers_to(found, status):
				return found
	if debug_mode:
		push_warning("Status Effects: \"%s\" was applied, but no file in %s answers to it - it is a name and a clock only." % [status, effects_folder])
	return null

## Whether one effect file is the one a word names. A file that says its own name is asked; anything
## else - a resource of somebody else's making that happens to be in the folder - answers to the
## name it is saved under, which is the only name it has.
## @ace_hidden
func _answers_to(candidate: Resource, status: String) -> bool:
	if candidate == null:
		return false
	if candidate.has_method("called"):
		return str(candidate.call("called")) == status
	return str(candidate.resource_path).get_file().get_basename() == status

## One knob off an effect file, with the value a status carrying no file behaves as. Every read of
## an effect goes through here, so the no-file case is decided once instead of at fifteen sites.
## @ace_hidden
func _knob(effect: Resource, field: StringName, fallback: Variant) -> Variant:
	if effect == null:
		return fallback
	var value: Variant = effect.get(field)
	return fallback if value == null else value

## How many stacks a second application leaves. The rule belongs to the effect file, which is where
## refresh, extend and add differ; a status with no file is one stack, refreshed.
## @ace_hidden
func _stacks_after(effect: Resource, current: int, added: int) -> int:
	if effect == null or not effect.has_method("stacks_after"):
		return 1
	return int(effect.call("stacks_after", current, added))

## And how much time it leaves. Same rule, same place.
## @ace_hidden
func _seconds_after(effect: Resource, remaining: float, added: float) -> float:
	if effect == null or not effect.has_method("seconds_after"):
		return maxf(added, 0.0)
	return float(effect.call("seconds_after", remaining, added))

## The Health behaviour a tick's damage goes to: the host itself when it has the typed pipeline, and
## otherwise the first child that does. Duck-typed on the method rather than on a class, so this
## pack never has to name another pack.
## @ace_hidden
func _health() -> Node:
	if host == null:
		return null
	if host.has_method("take_typed_damage"):
		return host
	for child: Node in host.get_children():
		if child.has_method("take_typed_damage"):
			return child
	return null

## The Boosts autoload, when the project has one and it is the pack this expects. An effect with a
## multiplier tag feeds it while the effect lasts; a project without Boosts simply gets no
## multiplier, which is the honest answer rather than an error.
##
## THE TREE IS ASKED ONLY WHEN THERE IS ONE. A status ends when a node is taken out of the tree as
## much as when its clock runs out - a pooled enemy despawning is exactly that - and `get_tree()` on
## a node with no tree is an engine error rather than a null. So being in the tree is tested first,
## and a status ending off-tree simply stops no boost, which is the same answer a project with no
## Boosts pack gets.
## @ace_hidden
func _boosts() -> Node:
	if not is_inside_tree():
		return null
	var tree: SceneTree = get_tree()
	if tree == null or tree.root == null:
		return null
	var found: Node = tree.root.get_node_or_null(^"Boost")
	if found != null and found.has_method("start_tagged_boost") and found.has_method("stop_boost"):
		return found
	return null

## The boost id one status feeds its tag through - namespaced by the host, so two poisoned enemies
## do not share one multiplier.
## @ace_hidden
func _boost_id(status: String) -> String:
	return "status:%d:%s" % [get_instance_id(), status]

## Who a tick's damage is credited to: the node this behaviour was CLAIMED for, read through the
## project's own ownership key, and nobody when nobody claimed it. Claim the Status Effects node for
## the poisoner and a kill by the poison is scored to them, exactly as a bullet's would be.
##
## The credit belongs to the NODE, not to one application: every status on this enemy is scored to
## whoever last claimed it, so a game where two players poison the same enemy and each wants their
## own kill credited claims the node again as it applies. There is no per-status source to read.
##
## An owner who has since been freed is nobody, not a dangling reference: a poison outlives the
## player who applied it often enough that the check earns its line, and the ownership rows that
## read the same key answer the same way.
##
## The key is read as it was stored and tested BEFORE it is cast, because casting a freed object to
## a Node is itself the error the check is here to avoid.
## @ace_hidden
func _source() -> Node:
	if not has_meta(OWNER_META):
		return null
	var claimed: Variant = get_meta(OWNER_META)
	return claimed as Node if is_instance_valid(claimed) else null

## How far a tint is allowed to pull the host's colour: the project's effect-strength dial, held
## under the ceiling while a player has asked for no flashing.
## @ace_hidden
func _tint_strength() -> float:
	var dial: float = clampf(float(Engine.get_meta(EFFECT_STRENGTH_META, 1.0)), 0.0, 1.0)
	if bool(Engine.get_meta(NO_FLASHING_META, false)):
		return minf(dial, TINT_CEILING)
	return dial

## Re-mixes the host's colour from everything active. Called whenever the set changes rather than
## every frame, because the answer only moves when a status lands or leaves. A host that is not a
## CanvasItem - a 3D enemy, a plain Node - is left alone, and its statuses work exactly the same.
## @ace_hidden
func _retint() -> void:
	var canvas: CanvasItem = host as CanvasItem
	if canvas == null:
		return
	var mixed: Color = Color(1.0, 1.0, 1.0, 1.0)
	for status: String in _active:
		var written: Variant = _knob((_active[status] as Dictionary)["effect"], &"tint", Color(1.0, 1.0, 1.0, 1.0))
		if written is Color:
			mixed *= written
	if mixed == Color(1.0, 1.0, 1.0, 1.0):
		if _tint_applied:
			canvas.modulate = _base_modulate
			_tint_applied = false
		return
	if not _tint_applied:
		_base_modulate = canvas.modulate
		_tint_applied = true
	canvas.modulate = _base_modulate.lerp(_base_modulate * mixed, _tint_strength())

## Ends one status: its boost stops, its particles go, the tint is re-mixed without it, and On
## Status Expired fires. Every way a status can end comes through here, so none of them can forget
## one of those four.
## @ace_hidden
func _end(status: String) -> void:
	if not _active.has(status):
		return
	var entry: Dictionary = _active[status]
	var boosts: Node = _boosts()
	if boosts != null:
		boosts.call("stop_boost", _boost_id(status))
	var particles: Node = entry.get("particles", null) as Node
	if is_instance_valid(particles):
		particles.queue_free()
	_active.erase(status)
	_retint()
	status_expired.emit(status)

## One tick of one status: its damage through the Health pack's typed pipeline so resistances,
## armour and the damage report all apply, then its healing, then the trigger a sheet listens to.
## @ace_hidden
func _tick(status: String, entry: Dictionary) -> void:
	var effect: Resource = entry["effect"]
	var stacks: int = int(entry["stacks"])
	var damage: float = float(_knob(effect, &"tick_amount", 0.0)) * stacks
	var healing: float = float(_knob(effect, &"heal_amount", 0.0)) * stacks
	if damage > 0.0 or healing > 0.0:
		var health: Node = _health()
		if health == null:
			if debug_mode:
				push_warning("Status Effects: \"%s\" ticks for %s, but neither this node's parent nor any of its children has a Health behaviour to take it." % [status, damage])
		else:
			if damage > 0.0:
				health.call("take_typed_damage", damage, str(_knob(effect, &"tick_type", "")), _source())
			if healing > 0.0 and health.has_method("heal"):
				health.call("heal", healing)
	status_ticked.emit(status, stacks)

## Ends everything the moment this node leaves the tree, however it left it - a pooled enemy stowed
## on the shelf, a room unloaded, a node freed. A status is a clock, a tint, a boost and sometimes a
## particle scene, and `_process` merely STOPS off-tree rather than tidying any of that up: without
## this, a burning enemy handed back by an object pool came out of the pool still burning, still
## orange, and still feeding its multiplier.
##
## Every ending goes through _end, so the boost stops, the particles go, the colour comes back and
## On Status Expired fires exactly as a clock running out would. The keys are a snapshot and a
## handler may end others, so each is asked whether it is still on before it is read.
##
## MOVING A NODE TO A NEW PARENT IS A LEAVE AND A RETURN, so it ends the statuses too. That is the
## same rule said once rather than two rules: what is on this node is what has happened to it since
## it arrived where it is.
## @ace_hidden
func _exit_tree() -> void:
	for status: String in _active.keys():
		if _active.has(status):
			_end(status)
	_immune.clear()
	set_process(false)
#endregion

func _ready() -> void:
	# Nothing is on at startup, so there is nothing to count down and no frame to pay for. Apply
	# Status and Immune To Status switch the tick back on the moment there is a clock to run.
	set_process(false)

func _process(delta: float) -> void:
	# Ordinary game time: a paused tree stops the ticking and a slowed one slows it, which is what
	# makes a burn on a slowed enemy burn slowly without a single row about it.
	if _active.is_empty() and _immune.is_empty():
		set_process(false)
		return
	for status: String in _immune.keys():
		var left: float = float(_immune[status]) - delta
		if left <= 0.0:
			_immune.erase(status)
		else:
			_immune[status] = left
	var ended: PackedStringArray = PackedStringArray()
	for status: String in _active.keys():
		# The keys were taken before the first tick ran, and a tick can end things: a sheet row under
		# On Status Ticked may cleanse, the damage may kill the host and a death handler may clear
		# everything. A word that has gone since the list was made is simply skipped.
		if not _active.has(status):
			continue
		var entry: Dictionary = _active[status]
		entry["remaining"] = float(entry["remaining"]) - delta
		entry["tick_in"] = float(entry["tick_in"]) - delta
		# A long frame may owe several ticks; each one is paid, and the clock keeps its remainder so
		# ten ticks a second stay ten ticks a second however uneven the frames were. A tick that
		# comes due exactly as the clock runs out is paid before the status ends, which is what makes
		# a one-second burn with a half-second tick two ticks rather than one.
		var every: float = maxf(float(_knob(entry["effect"], &"tick_seconds", 0.5)), MINIMUM_TICK_SECONDS)
		while float(entry["tick_in"]) <= 0.0 and float(entry["remaining"]) >= 0.0:
			entry["tick_in"] = float(entry["tick_in"]) + every
			_tick(status, entry)
			# A tick that killed the host, or a sheet row under On Status Ticked that cleansed this
			# very status, has already taken the entry away - there is no second tick to owe it.
			if not _active.has(status):
				break
		if _active.has(status) and float(entry["remaining"]) <= 0.0:
			ended.append(status)
	for status: String in ended:
		_end(status)
	# Asked LAST, so a status applied by an On Status Expired handler this very frame keeps the tick
	# alive: once the last clock is gone, the countdown switches itself off.
	set_process(not (_active.is_empty() and _immune.is_empty()))

func apply(status: String, seconds: float, stacks: int) -> void:
	var word: String = status.strip_edges()
	if word.is_empty():
		if debug_mode:
			push_warning("Status Effects: an Apply Status row was given no name, so nothing was applied.")
		return
	if _immune.has(word):
		return
	var entry: Dictionary = _active.get(word, {})
	var effect: Resource = entry["effect"] if entry.has("effect") else _effect(word)
	var was: int = int(entry.get("stacks", 0))
	var now: int = _stacks_after(effect, was, stacks)
	entry["effect"] = effect
	entry["stacks"] = now
	entry["remaining"] = _seconds_after(effect, float(entry.get("remaining", 0.0)), seconds)
	# A status landing for the first time waits a full interval for its first tick, so an effect
	# applied and removed inside one interval does nothing - which is what makes a one-second burn
	# with a half-second tick two ticks rather than three: one at the half, one as it goes out.
	if not entry.has("tick_in"):
		entry["tick_in"] = maxf(float(_knob(effect, &"tick_seconds", 0.5)), MINIMUM_TICK_SECONDS)
	var scene: PackedScene = _knob(effect, &"particle_scene", null) as PackedScene
	if scene != null and host != null and not is_instance_valid(entry.get("particles", null) as Node):
		var made: Node = scene.instantiate()
		host.add_child(made)
		entry["particles"] = made
	_active[word] = entry
	var tag: String = str(_knob(effect, &"multiplier_tag", "")).strip_edges()
	var factor: float = float(_knob(effect, &"multiplier", 1.0))
	if not tag.is_empty() and not is_equal_approx(factor, 1.0):
		var boosts: Node = _boosts()
		if boosts != null:
			boosts.call("start_tagged_boost", _boost_id(word), factor, float(entry["remaining"]), tag)
	_retint()
	set_process(true)
	status_applied.emit(word, now)
	if now != was:
		stacks_changed.emit(word, now)

func extend_status(status: String, seconds: float) -> void:
	if not _active.has(status):
		return
	var entry: Dictionary = _active[status]
	entry["remaining"] = float(entry["remaining"]) + maxf(seconds, 0.0)
	# THE MULTIPLIER RUNS ON THE SAME CLOCK. A shield extended by five seconds whose defence
	# multiplier still ended at the old time would leave Has Status saying shield while the shield
	# did nothing, so the boost this effect started is given the same seconds the status was.
	var boosts: Node = _boosts()
	if boosts != null and boosts.has_method("extend_boost"):
		boosts.call("extend_boost", _boost_id(status), maxf(seconds, 0.0))

func remove_status(status: String) -> void:
	_end(status)

func cleanse(status: String) -> void:
	var word: String = status.strip_edges()
	if not word.is_empty():
		# A NAMED CLEANSE IS STILL A CLEANSE. What makes a curse a curse is that the antidote does
		# not answer it, and an antidote that names the curse is still an antidote - so Cleanse asks
		# the file either way, and Remove Status is the row that takes something off regardless.
		if _active.has(word) and bool(_knob((_active[word] as Dictionary)["effect"], &"cleansable", true)):
			_end(word)
		return
	# The keys are a snapshot, and ending one fires On Status Expired - which a sheet may answer by
	# taking another off. So each is asked whether it is still on before it is read.
	for active: String in _active.keys():
		if not _active.has(active):
			continue
		if bool(_knob((_active[active] as Dictionary)["effect"], &"cleansable", true)):
			_end(active)

func make_immune(status: String, seconds: float) -> void:
	var word: String = status.strip_edges()
	if word.is_empty():
		return
	_immune[word] = maxf(seconds, 0.0)
	# Immunity that arrives while the thing it answers is already on takes it off, because an
	# immunity you have to wait out is not one.
	_end(word)
	set_process(true)

func has(status: String) -> bool:
	return _active.has(status)

func status_stacks(status: String) -> int:
	if not _active.has(status):
		return 0
	return int((_active[status] as Dictionary)["stacks"])

func status_time_left(status: String) -> float:
	if not _active.has(status):
		return 0.0
	return maxf(float((_active[status] as Dictionary)["remaining"]), 0.0)

func status_icon(status: String) -> Texture2D:
	if not _active.has(status):
		return null
	return _knob((_active[status] as Dictionary)["effect"], &"icon", null) as Texture2D

func active_statuses() -> Array:
	var words: Array = _active.keys()
	words.sort()
	return words

func speed_factor() -> float:
	var product: float = 1.0
	for status: String in _active:
		product *= float(_knob((_active[status] as Dictionary)["effect"], &"speed_factor", 1.0))
	return product
