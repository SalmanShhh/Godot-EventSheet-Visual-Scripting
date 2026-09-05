# Pack builder - status_effects (one pack per file; run via tools/build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")


## Status Effects: burn, poison, slow, stun, freeze and shield, as one behaviour and six files.
##
## THE HALF THAT ALREADY EXISTED is the Boosts pack: timed multipliers by tag, counting themselves
## down. The other half is what a status effect actually DOES - tick damage of a kind, heal, slow,
## tint, show an icon, stack a certain way, be cleansable - and this is that half. Boosts stays the
## multiplier engine underneath: an effect with a tag simply starts a tagged boost while it lasts.
##
## THE MACHINERY SHIPS AND THE EFFECTS ARE YOURS. Every effect is a StatusEffectResource file, six
## starters ship to edit or delete, and there is no list of statuses anywhere in this plugin.
##
## IT MOVES NOTHING ITSELF. Stun and freeze do not stop the host walking: they are statuses the
## movement packs and the state machine ASK about with Has Status, which keeps this pack out of
## every controller's business and lets one status mean whatever a game wants it to mean.
##
## EVERY CLOCK IS GAME TIME. The tick runs in `_process`, so a paused tree stops it and a slowed one
## slows it; and the tint obeys the same accessibility dials the screen effects do, held under a
## ceiling while a player has asked for no flashing.
static func build() -> bool:
	var src: Lib.PackSource = Lib.pack_from_source("status_effects", "Node", "StatusEffectsBehavior",
		"Burn, poison, slow, stun, freeze and shield on any node: apply a status for a time, let it tick damage of its own kind through the Health pack, stack the way its file says, tint the host and take the tint off again when it ends. The effects are StatusEffectResource files you own - six starters ship beside the pack to edit or delete.",
		Lib.manifest().behavior().category("Status Effects").tags(["combat", "status", "buff", "debuff"]).expose_all_verbs_on_a_node())
	src.note("Status Effects: attach under anything that can be burned, poisoned, slowed or frozen. Apply Status puts a StatusEffectResource on it for a time; the file says what the effect does and how a second application stacks. Ticks go through the Health pack's typed damage, so resistances and armour apply. Stun and freeze move nothing themselves - ask about them with Has Status where the movement is decided. This pack is an event sheet - extend it by editing it.")
	src.block("block_1")
	src.on_ready()
	src.on_process()

	# The five that change what is on ────────────────────────────────────────────────────────
	src.verb("apply", "Apply Status",
		"Puts a status on this node for a time, stacking by the rule in its own file. The name is a StatusEffectResource in the effects folder, so \"burn\" is burn.tres; a name no file answers to still applies as a name and a clock, which is all a pure flag like \"stunned\" needs.",
		[["status", "String"], ["seconds", "float"], ["stacks", "int"]])
	_default(src.sheet, "status", "\"burn\"")
	_default(src.sheet, "seconds", "3.0")
	_default(src.sheet, "stacks", "1")
	src.verb("extend_status", "Extend Status",
		"Adds seconds to a status that is already on, leaving its stacks alone. Nothing happens if it is not on - extending is for a fire being fed, not for lighting one.",
		[["status", "String"], ["seconds", "float"]])
	_default(src.sheet, "status", "\"burn\"")
	_default(src.sheet, "seconds", "2.0")
	src.verb("remove_status", "Remove Status",
		"Takes one status off now, whatever its file says about being cleansable - the boss shrugs it off, the scene moved on, the shield was spent. On Status Expired still fires, so the row that cleans up after a status is the same row either way.",
		[["status", "String"]])
	_default(src.sheet, "status", "\"burn\"")
	src.verb("cleanse", "Cleanse",
		"Takes a status off, or - given no name at all - every status whose file says it may be cleansed. That is what makes an antidote one row, and what makes a curse survive it.",
		[["status", "String"]])
	_default(src.sheet, "status", "\"poison\"")
	src.verb("make_immune", "Immune To Status",
		"Stops a status from landing here for a while, and takes it off if it is already on. The i-frames of the status world: the potion that makes you proof against poison for ten seconds.",
		[["status", "String"], ["seconds", "float"]])
	_default(src.sheet, "status", "\"poison\"")
	_default(src.sheet, "seconds", "10.0")

	# The five that answer questions ─────────────────────────────────────────────────────────
	src.condition("has", "Has Status",
		"True while that status is on. This is the row a movement pack or a state machine asks before it moves anything, which is why stun and freeze need no code of their own.",
		[["status", "String"]])
	_default(src.sheet, "status", "\"stun\"")
	src.expression("status_stacks", "Status Stacks",
		"How many stacks of a status are on, and 0 when it is not. Ticks and healing are multiplied by it, so it is also how hard the effect is hitting.",
		[["status", "String"]], TYPE_INT)
	_default(src.sheet, "status", "\"burn\"")
	src.expression("status_time_left", "Status Time Left",
		"Seconds left before a status ends, and 0 when it is not on - the fill of the little bar under its icon.",
		[["status", "String"]], TYPE_FLOAT)
	_default(src.sheet, "status", "\"burn\"")
	src.object_expression("status_icon", "Status Icon",
		"The picture the effect's own file names for it, straight into a HUD texture. A status with no icon, or one that is not on, answers with nothing.",
		[["status", "String"]], "Texture2D")
	_default(src.sheet, "status", "\"burn\"")
	src.expression("active_statuses", "Active Statuses",
		"Every status on this node right now, in name order - the list a status bar walks to draw one icon per effect.",
		[], TYPE_ARRAY)
	src.expression("speed_factor", "Speed Factor",
		"The product of every active effect's speed factor: 1 when nothing is on, 0.5 under one slow, 0.25 under two. Multiply your movement speed by it and every slow, root and haste in the game already works.",
		[], TYPE_FLOAT)

	Lib.verb_sentences(src.sheet, {
		"apply": "Apply status [b]{status}[/b] for [b]{seconds}[/b] s",
		"extend_status": "Extend [b]{status}[/b] by [b]{seconds}[/b] s",
		"remove_status": "Remove status [b]{status}[/b]",
		"cleanse": "Cleanse [b]{status}[/b]",
		"make_immune": "Immune to [b]{status}[/b] for [b]{seconds}[/b] s",
		"has": "Has status [b]{status}[/b]",
		"status_stacks": "stacks of [b]{status}[/b]",
		"status_time_left": "time left on [b]{status}[/b]",
		"status_icon": "icon of [b]{status}[/b]",
		"speed_factor": "speed factor",
	})
	# The three a new user should meet first: put a status on, ask whether it is on, and multiply
	# movement by what the statuses add up to.
	Lib.feature_verbs(src.sheet, ["apply", "has", "speed_factor"])
	if not Lib.publish(src, "res://eventsheet_addons/status_effects/status_effects_behavior"):
		return false
	# The six starters go out beside the behaviour, which is also where the Effects Folder points
	# by default - so a freshly attached pack can burn something before anybody has authored a file.
	return Lib.ship_files("status_effects",
		"res://eventsheet_addons/status_effects/status_effects_behavior", PackedStringArray(["tres"]))


## Pre-fills the last-declared verb's parameter default, so a dropped row opens with a usable value
## instead of an empty field (authoring-time metadata only - defaults never appear in the compiled
## .gd of a game that uses the row).
##
## THE VALUES BELOW ARE EXPRESSIONS, because every slot in this pack's templates is bare: a bare slot
## takes whatever the field holds and splices it into the call, so a String argument has to arrive
## already carrying its quotes. That is the same reading the shipped `codegen_template`s freeze, and
## it is why a word is spelled here as "word" rather than as word.
##
## A quoted value spelled this way DOES NOT SURVIVE the annotation round trip, and it does not have
## to today: the emitter writes a `default:` segment only for a parameter that also carries help
## (`SheetCompiler._param_annotation_lines` returns early on an empty description), and no parameter
## in this file declares any, so none of these values reaches the shipped pack at all. The day one of
## them gains its help sentence the default starts shipping, both annotation readers strip one
## surrounding pair of quotes off it, and the row writes a bare word no game declares.
## `tests/pack_default_rows_compile_test.gd` compiles every shipped row with the value it opens on,
## so that day ends in a red gate rather than in a game that does not parse.
static func _default(sheet: EventSheetResource, param_id: String, value: String) -> void:
	var fn: EventFunction = sheet.functions[sheet.functions.size() - 1]
	for parameter: ACEParam in fn.params:
		if parameter.id == param_id:
			parameter.default_value = value
