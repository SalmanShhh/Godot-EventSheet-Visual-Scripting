# Pack builder - prompts (one pack per file; run via tools/build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")


## Prompts: the visible half of a quick-time event, as the Prompts autoload.
##
## The Timed Input rows already do the thinking. They open a window the player has a moment to
## answer, say whether the control went down while it was open, grade how close to the end it was,
## count a mash, and grade a press against a beat. What they do not do is SHOW the player anything -
## and a quick-time event nobody can see is a quick-time event nobody can answer.
##
## So this pack is the showing: the prompt over the boss's head with the right button on it, the
## ring that shrinks while the moment lasts, the flash when it lands, the note that travels down a
## lane to arrive on the beat. It keeps the same two words those rows grade in - "perfect" and
## "good" - and adds the third every prompt needs, "miss", so a sheet that already branches on a
## window grade needs nothing rewritten to branch on a prompt.
##
## THE GLYPHS ARE YOURS. Which picture stands for a control on the thing in the player's hands is a
## GlyphSheetResource the game owns, and the pack ships one plain starter to replace. The device is
## the one the last input event came from, so a player who puts the pad down and reaches for the
## keyboard sees keyboard glyphs on the very next prompt, and Force Device is the row a menu uses to
## show a particular layout on purpose.
##
## IT SHIPS AS THE Prompts AUTOLOAD, the way Music and Scene Flow do, because one prompt at a time
## is the whole point: two prompts on screen asking for two controls is a sequence, and Sequence is
## the row for that.
##
## The two scenes it ships - the prompt and the rhythm lane - are STARTERS drawn plain. The director
## addresses them by the names of their children (Ring, Glyph, Label, HitLine, Note), so restyling
## one is replacing its art, not rewriting anything here.
static func build() -> bool:
	var src: Lib.PackSource = Lib.pack_from_source("prompts", "Node", "PromptsAddon",
		"Quick-time prompts as the Prompts autoload: a control to press with the right glyph for the device in the player's hands, a ring that shrinks while the moment lasts, holds, mashes and sequences, and notes that travel a lane to land on the beat. It grades in the same words the Timed Input rows do. The glyphs are a GlyphSheetResource you own; the prompt and the lane are starter scenes you restyle.",
		Lib.manifest().autoload("Prompts").category("Prompts").tags(["input", "qte", "rhythm", "prompt", "glyph"]))
	# Property ORDER is part of the pack: these emit in the order they are declared here.
	src.sheet.variables = {
		"prompt_scene": {"type": "String", "default": "res://eventsheet_addons/prompts/prompt.tscn", "exported": true,
			"attributes": {"tooltip": "The scene one prompt is drawn as. The shipped one is a starter drawn plain - copy it into your own project and restyle it. The director fills in the children it finds by name: Ring (anything with a value, for the time left), Glyph (a texture, for the button picture) and Label (for the Input Map's own words when no glyph was drawn)."}},
		"glyphs": {"type": "Resource", "default": null, "exported": true,
			"attributes": {"tooltip": "The GlyphSheetResource saying which picture stands for which control on which device. Leave it empty and a prompt shows the Input Map's own words instead, which is right on a keyboard and vague on a pad."}},
		"perfect_window_ms": {"type": "int", "default": 80, "exported": true,
			"attributes": {"tooltip": "How close to a note's own moment a press has to land to grade perfect, in milliseconds. Rhythm windows are discussed in milliseconds, so they are typed in milliseconds. Timed prompts do not use this - they grade on how much of their window was left.", "range": {"min": "0", "max": "1000", "step": "1"}}},
		"hit_window_ms": {"type": "int", "default": 250, "exported": true,
			"attributes": {"tooltip": "How far off a note's moment a press may be and still count at all, in milliseconds. A press further out than this is not an answer to that note, and a note this far past its moment is a miss.", "range": {"min": "0", "max": "2000", "step": "1"}}},
		"perfect_share": {"type": "float", "default": 0.5, "exported": true,
			"attributes": {"tooltip": "How much of a timed prompt's window still has to be left for the answer to grade perfect. 0.5 means the first half of the window is perfect and the second half is good. It grades reaction rather than nerve, which is what a quick-time event is asking about.", "range": {"min": "0", "max": "1", "step": "0.05"}}},
		"lead_seconds": {"type": "float", "default": 1.0, "exported": true,
			"attributes": {"tooltip": "How long a note travels its lane for when there is no Music director to ask. With one in the project the note lands on the song's next beat instead, and this is only the fallback.", "range": {"min": "0.05", "max": "10", "step": "0.05"}}},
		"flash_strength": {"type": "float", "default": 1.0, "exported": true,
			"attributes": {"tooltip": "How bright a prompt flashes as it is hit. A player who has asked for no flashing gets a slow fade instead, whatever this says - the prompt still has to show it landed.", "range": {"min": "0", "max": "1", "step": "0.05"}}},
		"flash_seconds": {"type": "float", "default": 0.15, "exported": true,
			"attributes": {"tooltip": "How long that flash takes to fade out. No flashing stretches it to at least four tenths of a second, which is what turns a flash into a fade.", "range": {"min": "0.01", "max": "2", "step": "0.01"}}},
		"debug_mode": {"type": "bool", "default": false, "exported": true,
			"attributes": {"tooltip": "Warns about a prompt scene that cannot be loaded, a lane with no Note child to copy, and a Sequence given no controls. On while you build, off for release."}},
	}
	src.note("Prompts (autoload): register as the Prompts autoload, then ask the player for a control from any sheet. Prompt opens a moment with the right glyph on it; Hold Prompt and Mash Prompt are the same moment answered a different way; Sequence is a list of them; Prompt On Beat sends a note down a lane to land on the song's next beat. The grades are the Timed Input rows' own words - perfect, good, miss. This pack is an event sheet - extend it by editing it.")
	src.block("block_1")
	src.block("block_2")
	src.on_ready()
	src.on_process()

	# ── The moment ────────────────────────────────────────────────────────────────────────
	src.verb("prompt", "Prompt",
		"Asks the player for a control, for the seconds given, drawn over a node. The glyph is the one for the device in their hands. Answering fires On Prompt Hit with a grade; the seconds running out fires On Prompt Missed.",
		[["action", "String"], ["seconds", "float"], ["at", "Node"]])
	_hint(src.sheet, "action", "input_action")
	_default(src.sheet, "seconds", "0.8")
	src.verb("hold_prompt", "Hold Prompt",
		"Asks the player to HOLD a control down for a while, within the seconds given - the winch, the door being forced, the finisher pressed and kept pressed. Letting go resets the hold, because a hold that survived being let go is not a hold.",
		[["action", "String"], ["hold", "float"], ["seconds", "float"], ["at", "Node"]])
	_hint(src.sheet, "action", "input_action")
	_default(src.sheet, "hold", "1.0")
	_default(src.sheet, "seconds", "3.0")
	src.verb("mash_prompt", "Mash Prompt",
		"Asks the player for a number of presses within the seconds given - breaking free of a grab, cranking a handle, shaking off a swarm. It is the shipped mash rows with a prompt over the top.",
		[["action", "String"], ["presses", "int"], ["seconds", "float"], ["at", "Node"]])
	_hint(src.sheet, "action", "input_action")
	_default(src.sheet, "presses", "12")
	_default(src.sheet, "seconds", "3.0")
	src.verb("sequence", "Sequence",
		"Asks for several controls one after another, as a comma-separated list, each with the same seconds to answer. On Sequence Finished fires once at the end carrying whether every one of them landed; the first miss ends it.",
		[["actions", "String"], ["seconds", "float"], ["at", "Node"]])
	_default(src.sheet, "actions", "\"ui_left, ui_right, ui_accept\"")
	_default(src.sheet, "seconds", "0.8")
	src.verb("cancel_prompt", "Cancel Prompt",
		"Takes whatever is being asked off the screen with no grade and no miss - the cutscene was skipped, the enemy died first, the player walked away. A sequence cancelled this way finishes uncompleted.",
		[])

	# ── On the beat ───────────────────────────────────────────────────────────────────────
	src.verb("prompt_on_beat", "Prompt On Beat",
		"Sends a note down a lane to land on the song's next beat, where pressing the control grades it. With a Music director in the project the moment is the song's own next beat; without one it is the Lead Seconds from now, so a lane works on its own too.",
		[["action", "String"], ["lane", "Node"]])
	_hint(src.sheet, "action", "input_action")
	src.verb("force_device", "Force Device",
		"Shows every glyph for one device from now on, whatever the player last touched - the options screen showing a layout on purpose, the tutorial card printed for a console. \"auto\" hands it back to the last input event.",
		[["device_name", "String"]])
	_options(src.sheet, "device_name", ["auto", "keyboard", "pad", "xbox", "playstation", "nintendo"])
	_default(src.sheet, "device_name", "\"auto\"")

	# ── Questions ─────────────────────────────────────────────────────────────────────────
	src.condition("prompt_is_open", "Prompt Is Open",
		"True while the player is being asked for something and has not answered or run out yet.",
		[])
	src.condition("grade_is", "Grade Is",
		"True when the last prompt to end ended this way - \"perfect\", \"good\" or \"miss\". The same three words a note is graded in, so one branch serves both.",
		[["grade", "String"]])
	_options(src.sheet, "grade", ["perfect", "good", "miss"])
	_default(src.sheet, "grade", "\"perfect\"")
	src.expression("last_grade", "Last Grade",
		"How the last prompt ended, as a word: \"perfect\", \"good\" or \"miss\". Empty until the first one ends.",
		[], TYPE_STRING)
	src.expression("prompt_time_left", "Prompt Time Left",
		"Seconds left before the open prompt runs out, and 0 when nothing is open - the fill of a bar drawn somewhere other than on the prompt itself.",
		[], TYPE_FLOAT)
	src.expression("sequence_progress", "Sequence Progress",
		"How far through a sequence the player is, from 0 to 1 - the number a progress bar over a cutscene reads.",
		[], TYPE_FLOAT)
	src.object_expression("glyph_for", "Glyph For",
		"The picture that stands for a control on the device in the player's hands, straight from your glyph sheet. Put it in a texture anywhere - a HUD hint, a tutorial card, a rebinding screen - and the whole game follows the pad the player picked up.",
		[["action", "String"]], "Texture2D")
	_hint(src.sheet, "action", "input_action")
	src.expression("device", "Device",
		"Which device the glyphs are being drawn for right now: \"keyboard\", \"pad\", or one of the three console layouts. It follows the last input event unless Force Device has fixed it.",
		[], TYPE_STRING)

	Lib.verb_sentences(src.sheet, {
		"prompt": "Prompt [b]{action}[/b] for [b]{seconds}[/b] s at [i]{at}[/i]",
		"hold_prompt": "Hold [b]{action}[/b] for [b]{hold}[/b] s within [b]{seconds}[/b] s",
		"mash_prompt": "Mash [b]{action}[/b] x[b]{presses}[/b] in [b]{seconds}[/b] s",
		"sequence": "Sequence [b]{actions}[/b], [b]{seconds}[/b] s each",
		"prompt_on_beat": "Prompt [b]{action}[/b] on the beat in [i]{lane}[/i]",
		"force_device": "Force device [b]{device_name}[/b]",
		"grade_is": "Grade is [b]{grade}[/b]",
	})
	# The three a new user should meet first: ask for a control, ask for one on the beat, and put the
	# right button picture wherever else the game says "press this".
	Lib.feature_verbs(src.sheet, ["prompt", "prompt_on_beat", "glyph_for"])
	if not Lib.publish(src, "res://eventsheet_addons/prompts/prompts_addon"):
		return false
	# The two starter scenes and the plain glyph sheet ship beside the script: a director whose
	# prompt scene is not there draws nothing, so a pack folder without them is a pack that silently
	# does nothing.
	return Lib.ship_files("prompts", "res://eventsheet_addons/prompts/prompts_addon",
		PackedStringArray(["tscn", "tres"]))


## Pre-fills the last-declared verb's parameter default, so a dropped row opens with a usable value
## instead of an empty field (authoring-time metadata only - defaults never appear in the compiled
## .gd of a game that uses the row).
static func _default(sheet: EventSheetResource, param_id: String, value: String) -> void:
	var fn: EventFunction = sheet.functions[sheet.functions.size() - 1]
	for parameter: ACEParam in fn.params:
		if parameter.id == param_id:
			parameter.default_value = value


## Sets the parameter HINT on the last-declared verb's parameter - the key the params dialog reads
## to decide which little editor a field gets. "input_action" is the one that reads the project's
## live Input Map, so a control is picked from the list the game really has rather than typed.
static func _hint(sheet: EventSheetResource, param_id: String, hint: String) -> void:
	var fn: EventFunction = sheet.functions[sheet.functions.size() - 1]
	for parameter: ACEParam in fn.params:
		if parameter.id == param_id:
			parameter.hint = hint


## Sets the dropdown options[] on the last-declared verb's parameter, so the row offers the words it
## actually accepts instead of a free-text field somebody has to spell right.
static func _options(sheet: EventSheetResource, param_id: String, choices: Array) -> void:
	var typed: Array[String] = []
	for choice: Variant in choices:
		typed.append(str(choice))
	var fn: EventFunction = sheet.functions[sheet.functions.size() - 1]
	for parameter: ACEParam in fn.params:
		if parameter.id == param_id:
			parameter.options = typed
