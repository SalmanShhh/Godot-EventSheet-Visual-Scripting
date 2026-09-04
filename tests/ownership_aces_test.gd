# Godot EventSheets - Ownership: the one key that says who made this.
#
# What this gate holds, in the order the mistakes actually happen:
#   1. ONE KEY. Every row in the family writes or reads node metadata `owner` and nothing else. A
#      second key invented by a later row would split the fact in half and nothing else would see it.
#   2. THE CHAIN, BY VALUE. Bullet to turret to player is the whole point, so the walk is RUN - the
#      shipped template compiled into a real script and asked about a real three-node chain - rather
#      than eyeballed. The nearest owner and the far end are different answers and both are pinned.
#   3. THE WALK ALWAYS ANSWERS. A chain that points at itself, an owner that has been freed, and a
#      node that is null are three things a shipped project will hit; all three must answer rather
#      than hang or crash, because a bounded fold is the only loop an expression can have.
#   4. THE GUARD. Hit Is Not My Owner is the friendly-fire row, and it is run from inside a node
#      standing in for the bullet: its own shooter is refused, the shooter's other bullet is refused,
#      and an enemy is allowed. A guard that let the shooter through would be worse than no guard.
#   5. THE CREDIT, THROUGH THE REAL PACK. The Health pack's shipped .gd is loaded and damaged, so
#      Killer Of, Assists Of and Killed By Me are answered by the code that ships, not by a copy of
#      it written here. Credit is taken BEFORE the damage lands, which is what lets a row under On
#      Death read the killer at all.
#   6. THE POOL FORGETS. A recycled node must not carry its last life's owner, or the second bullet
#      out of the pool is credited to whoever fired the first.
#   7. THE LIFT. The hand-written `set_meta(&"owner", ...)` line opens as the row it is; the
#      two-line disown DEGRADES to the general meta rows that already say it, which is the honest
#      answer rather than a corrupt one; and all three files come back byte for byte.
#
# Values are pinned, never counts.
@tool
class_name OwnershipACEsTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")

## The module, loaded BY PATH so the test does not wait on the editor class cache having been
## regenerated for a newly added file.
const MODULE_PATH: String = "res://addons/eventforge/registration/modules/ownership_aces.gd"

## The packs whose shipped bytes this gate reads back: the credit lives in one and the forgetting
## in the other, and both are COMPILER OUTPUT, so what is asserted is the emitted file.
const HEALTH_PACK_PATH: String = "res://eventsheet_addons/health/health_behavior.gd"
const POOL_PACK_PATH: String = "res://eventsheet_addons/object_pool/object_pool_addon.gd"

## The one key the whole family agrees on. Spelled here as text so a row that invented a second one
## fails this gate rather than quietly halving the fact.
const KEY: String = "&\"owner\""


static func run() -> bool:
	var passed: bool = true
	passed = _test_every_row_writes_the_one_key() and passed
	passed = _test_the_chain_answers_by_value() and passed
	passed = _test_the_walk_always_answers() and passed
	passed = _test_the_guard_refuses_its_own_shooter() and passed
	passed = _test_claim_writes_and_disown_clears() and passed
	passed = _test_the_credit_runs_through_the_health_pack() and passed
	passed = _test_the_pool_forgets_on_the_way_back() and passed
	passed = _test_the_handwritten_rows_open_as_the_rows_they_are() and passed
	return passed


# ── 1. One key ──


## Every descriptor in the family, by ace_id, with the key it touches - so a row added later that
## reaches for a different word is a failure here rather than a fact nothing else can see.
static func _test_every_row_writes_the_one_key() -> bool:
	var rows: Dictionary = _descriptors_by_id()
	var wanted: Array[String] = ["Claim", "Disown", "ClaimedBy", "RootOwnerOf", "IsOwnedBy",
		"IsMine", "HitIsNotMyOwner"]
	var found: Array[String] = []
	for ace_id: String in rows.keys():
		found.append(ace_id)
	found.sort()
	var expected: Array[String] = wanted.duplicate()
	expected.sort()
	var passed: bool = SUPPORT.check("ownership", "the family is the seven rows it says it is",
		found, expected)
	for ace_id: String in wanted:
		if not rows.has(ace_id):
			continue
		var template: String = str((rows[ace_id] as ACEDescriptor).codegen_template)
		passed = SUPPORT.check("ownership", "%s touches the one key" % ace_id,
			template.contains(KEY), true) and passed
		passed = SUPPORT.check("ownership", "%s invents no second key" % ace_id,
			template.count("&\""), template.count(KEY)) and passed
	return passed


# ── 2. The chain, by value ──


## The shot, the turret that fired it and the player who built the turret. The nearest owner and the
## far end are DIFFERENT answers, which is the whole reason both rows exist.
static func _test_the_chain_answers_by_value() -> bool:
	var player: Node = _named("Player")
	var turret: Node = _named("Turret")
	var bullet: Node = _named("Bullet")
	var loose: Node = _named("Rock")
	turret.set_meta(&"owner", player)
	bullet.set_meta(&"owner", turret)
	var nearest: Callable = _reader("ClaimedBy")
	var root: Callable = _reader("RootOwnerOf")
	var passed: bool = SUPPORT.pins("ownership", [
		["the nearest owner of the bullet is the turret", _name_of(nearest.call(bullet)), "Turret"],
		["the nearest owner of the turret is the player", _name_of(nearest.call(turret)), "Player"],
		["a node nobody claimed has no nearest owner", _name_of(nearest.call(loose)), ""],
		["the root owner of the bullet is the player", _name_of(root.call(bullet)), "Player"],
		["the root owner of the turret is the player", _name_of(root.call(turret)), "Player"],
		["the root owner of the player is the player", _name_of(root.call(player)), "Player"],
		["a node nobody claimed is its own root owner", _name_of(root.call(loose)), "Rock"]
	])
	for node: Node in [player, turret, bullet, loose]:
		node.free()
	return passed


# ── 3. The walk always answers ──


## The three shapes a real project produces that a naive walk does not survive. None of them may hang
## and none of them may crash: a bounded fold is the only loop an expression has, and this is what it
## is bounded FOR.
static func _test_the_walk_always_answers() -> bool:
	var root: Callable = _reader("RootOwnerOf")
	var first: Node = _named("First")
	var second: Node = _named("Second")
	first.set_meta(&"owner", second)
	second.set_meta(&"owner", first)
	var cycled: Variant = root.call(first)
	var carrier: Node = _named("Carrier")
	var ghost: Node = _named("Ghost")
	carrier.set_meta(&"owner", ghost)
	ghost.free()
	var after_free: Variant = root.call(carrier)
	var nearest: Callable = _reader("ClaimedBy")
	var nearest_after_free: Variant = nearest.call(carrier)
	var passed: bool = SUPPORT.pins("ownership", [
		["a chain that points at itself still answers with a node in it",
			cycled == first or cycled == second, true],
		# NOTHING, not "something that is no longer valid": a row reads a name off what this
		# answers, and reading one off a freed object is an error in the sheet.
		["an owner that has been freed answers with nothing", after_free == null, true],
		["and the nearest owner answers with nothing too", nearest_after_free == null, true],
		["nothing owns nothing", root.call(null) == null, true]
	])
	for node: Node in [first, second, carrier]:
		node.free()
	return passed


# ── 4. The guard ──


## Hit Is Not My Owner asked from INSIDE the bullet, because `self` in its template is the bullet.
## The three answers a friendly-fire guard is judged on: my own shooter, my shooter's other shot,
## and somebody else entirely.
static func _test_the_guard_refuses_its_own_shooter() -> bool:
	var player: Node = _named("Player")
	var enemy: Node = _named("Enemy")
	var sibling: Node = _named("Sibling")
	sibling.set_meta(&"owner", player)
	var bullet: Node = _probe("HitIsNotMyOwner", "hit", "\treturn %s")
	bullet.set_meta(&"owner", player)
	var passed: bool = SUPPORT.pins("ownership", [
		["a bullet does not hurt the player who fired it", bullet.call("probe", player), false],
		["a bullet does not hurt its shooter's other shot", bullet.call("probe", sibling), false],
		["a bullet does hurt somebody else", bullet.call("probe", enemy), true],
		["a bullet does not hurt itself", bullet.call("probe", bullet), false]
	])
	for node: Node in [player, enemy, sibling, bullet]:
		node.free()
	return passed


# ── 5. Claim and Disown ──


static func _test_claim_writes_and_disown_clears() -> bool:
	var rows: Dictionary = _descriptors_by_id()
	var thing: Node = _named("Thing")
	var claim: Node = _statement(str((rows["Claim"] as ACEDescriptor).codegen_template)
		.replace("{node}", "subject").replace("{owner}", "self"))
	claim.call("probe", thing)
	var claimed: bool = thing.get_meta(&"owner", null) == claim
	var disown: Node = _statement(str((rows["Disown"] as ACEDescriptor).codegen_template)
		.replace("{node}", "subject"))
	disown.call("probe", thing)
	var cleared: bool = not thing.has_meta(&"owner")
	# Disowning something that was never claimed must be quiet, not an error: a pool hands back
	# nodes that were never anybody's.
	var never: Node = _named("Never")
	disown.call("probe", never)
	never.free()
	var passed: bool = SUPPORT.pins("ownership", [
		["Claim writes the key", claimed, true],
		["Disown clears the key", cleared, true]
	])
	for node: Node in [thing, claim, disown]:
		node.free()
	return passed


# ── 6. The credit, through the real pack ──


## The Health pack's SHIPPED script, damaged three times by two different sources, then killed. What
## is pinned is what a results screen asks: who killed it, who helped, and whether the kill was mine.
static func _test_the_credit_runs_through_the_health_pack() -> bool:
	var health_script: GDScript = load(HEALTH_PACK_PATH)
	if health_script == null:
		return SUPPORT.check("ownership", "the Health pack loads", false, true)
	var health: Node = Node.new()
	health.set_script(health_script)
	health.set("max_health", 30.0)
	health.set("current_health", 30.0)
	var player: Node = _named("Player")
	var turret: Node = _named("Turret")
	var bullet: Node = _named("Bullet")
	var ally: Node = _named("Ally")
	turret.set_meta(&"owner", player)
	bullet.set_meta(&"owner", turret)
	# The ally softens it up, then the player's turret-fired bullet finishes it.
	health.call("take_damage_from", 5.0, ally)
	var after_assist: String = _name_of(health.call("last_hit_from_value"))
	var killer_while_alive: Variant = health.call("killer_of")
	health.call("take_damage_from", 25.0, bullet)
	var killer: String = _name_of(health.call("killer_of"))
	var assists: Array = health.call("assists_of") as Array
	var assist_names: Array[String] = []
	for who: Variant in assists:
		assist_names.append(_name_of(who))
	# A hit on the corpse must not steal the credit.
	health.call("take_damage_from", 100.0, ally)
	var killer_after_corpse_hit: String = _name_of(health.call("killer_of"))
	var passed: bool = SUPPORT.pins("ownership", [
		["a hit records who dealt it", after_assist, "Ally"],
		["nothing has killed it while it is alive", killer_while_alive == null, true],
		["the kill is credited to the person, not the bullet", killer, "Player"],
		["the helper is listed as an assist", assist_names, ["Ally"] as Array[String]],
		["the killer is not listed among the assists", assist_names.has("Player"), false],
		["a hit on the corpse does not steal the credit", killer_after_corpse_hit, "Player"],
		["the kill is mine when I am the one asking",
			health.call("killed_by_me", player), true],
		["the kill is mine when my turret fired it",
			health.call("killed_by_me", turret), true],
		["the kill is not the helper's", health.call("killed_by_me", ally), false]
	])
	for node: Node in [health, player, turret, bullet, ally]:
		node.free()
	return passed


# ── 7. The pool forgets ──


## Read out of the SHIPPED pool, because that file is the compiler's output and the lines are what a
## user's project runs. A recycled node that kept its owner would credit the second bullet to
## whoever fired the first.
static func _test_the_pool_forgets_on_the_way_back() -> bool:
	var pool: String = FileAccess.get_file_as_string(POOL_PACK_PATH)
	return SUPPORT.pins("ownership", [
		["parking a node clears the ownership key",
			pool.contains("if node.has_meta(&\"owner\"):\n\t\tnode.remove_meta(&\"owner\")"), true],
		["and it happens where every despawn passes", pool.contains("func _stow("), true]
	])


# ── 8. The lift ──


## The line a hand-written project already contains opens as the row it is, and saving the file
## untouched reproduces it byte for byte.
static func _test_the_handwritten_rows_open_as_the_rows_they_are() -> bool:
	var source: String = "\n".join(PackedStringArray([
		"extends Node2D",
		"",
		"",
		"func _ready() -> void:",
		"\tself.set_meta(&\"owner\", self)",
		""
	]))
	var reopened: EventSheetResource = SUPPORT.reopen(source)
	var claimed: String = ""
	for row: Resource in reopened.events:
		if row is EventRow:
			for action: Resource in (row as EventRow).actions:
				if action is ACEAction:
					claimed = str((action as ACEAction).ace_id)
	var reemitted: String = SUPPORT.reemit(source, "user://eventforge_ownership_trip.gd")
	# DISOWN DEGRADES RATHER THAN CORRUPTS, and that is pinned rather than wished for: its template
	# is a two-line `if has_meta` / `remove_meta`, which the general meta rows already say character
	# for character, so a hand-written one opens as those two rows instead of as Disown. It says the
	# same thing, and the file it came from comes back untouched - which is the contract.
	var stowed: String = "\n".join(PackedStringArray([
		"extends Node2D",
		"",
		"",
		"func _on_stow(node: Node) -> void:",
		"\tif node.has_meta(&\"owner\"):",
		"\t\tnode.remove_meta(&\"owner\")",
		""
	]))
	var reopened_stow: EventSheetResource = SUPPORT.reopen(stowed)
	var stow_rows: PackedStringArray = PackedStringArray()
	for fn: EventFunction in reopened_stow.functions:
		for row: Resource in fn.events:
			if not (row is EventRow):
				continue
			for condition: Resource in (row as EventRow).conditions:
				if condition is ACECondition:
					stow_rows.append(str((condition as ACECondition).ace_id))
			for action: Resource in (row as EventRow).actions:
				if action is ACEAction:
					stow_rows.append(str((action as ACEAction).ace_id))
	# And the fold the three comparison rows are built from is an ordinary expression wherever a
	# project already wrote one: it is kept whole, not split down the middle by the reading.
	var folded: String = "\n".join(PackedStringArray([
		"extends Node2D",
		"",
		"",
		"func _ready() -> void:",
		"\tprint(%s)" % load(MODULE_PATH).call("root_owner_expression", "self"),
		""
	]))
	return SUPPORT.pins("ownership", [
		["a hand-written claim opens as Claim", claimed, "Claim"],
		["and the file comes back byte for byte", reemitted, source],
		["a hand-written disown opens as the meta rows that already say it",
			Array(stow_rows), ["HasMeta", "RemoveMeta"]],
		["and that file comes back byte for byte too",
			SUPPORT.reemit(stowed, "user://eventforge_ownership_stow_trip.gd"), stowed],
		["a file holding the owner walk comes back byte for byte",
			SUPPORT.reemit(folded, "user://eventforge_ownership_fold_trip.gd"), folded]
	])


# ── The harness ──


## Every descriptor this module publishes, keyed by ace_id.
static func _descriptors_by_id() -> Dictionary:
	var rows: Dictionary = {}
	for descriptor: ACEDescriptor in load(MODULE_PATH).call("get_descriptors"):
		rows[str(descriptor.ace_id)] = descriptor
	return rows


## A node whose `probe(subject)` RETURNS what one reading row answers about the subject - the shipped
## template compiled into real GDScript, so what is measured is the row rather than a paraphrase.
static func _reader(ace_id: String) -> Callable:
	var template: String = str((_descriptors_by_id()[ace_id] as ACEDescriptor).codegen_template)
	var probe: Node = _probe(ace_id, "node", "\treturn %s")
	return func(subject: Variant) -> Variant:
		return probe.call("probe", subject)


## The shipped template of one row, compiled inside a Node as `probe(subject)`. `slot` is the
## parameter the subject is fed into; `shape` is the one line of the body, with %s for the template.
static func _probe(ace_id: String, slot: String, shape: String) -> Node:
	var template: String = str((_descriptors_by_id()[ace_id] as ACEDescriptor).codegen_template)
	return _body(shape % template.replace("{%s}" % slot, "subject"))


## The shipped template of one ACTION, compiled as the body of `probe(subject)`.
static func _statement(statement: String) -> Node:
	var indented: PackedStringArray = PackedStringArray()
	for line: String in statement.split("\n"):
		indented.append("\t" + line)
	return _body("\n".join(indented))


## One probe node: a script with `probe(subject)` and nothing else, so the only thing under test is
## the line the body holds.
static func _body(body: String) -> Node:
	var script: GDScript = GDScript.new()
	script.source_code = "@tool\nextends Node\n\n\nfunc probe(subject: Variant) -> Variant:\n%s\n\treturn null\n" % body
	script.reload()
	var node: Node = Node.new()
	node.set_script(script)
	return node


## A named node, because a pinned VALUE has to be readable when it fails: "Turret" says which node
## the walk stopped at, where an object id says nothing at all.
static func _named(node_name: String) -> Node:
	var node: Node = Node.new()
	node.name = node_name
	return node


## What a walk answered, as the name of the node it landed on - "" for nothing and for anything that
## is no longer valid.
static func _name_of(value: Variant) -> String:
	if not is_instance_valid(value) or not (value is Node):
		return ""
	return str((value as Node).name)
