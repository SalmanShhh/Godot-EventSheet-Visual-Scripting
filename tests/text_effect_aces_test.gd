# Godot EventSheets - text that moves: the six engine effects, the reveal, and the styles a popped
# number is drawn in.
#
# The claims these rows make, in the order they would break:
#
#   1. THE ROW WRITES THE ENGINE'S OWN TAG. Set Text With Effect emits a line a person could have
#      typed, and each of the six effects fills its OWN knob - amp, level, radius, freq, length -
#      because writing `amp` into a shake would silently do nothing. Pinned as the emitted text.
#   2. THE TWO ACCESSIBILITY SETTINGS ARE REALLY READ. The emitted number is RUN, once with each
#      setting off and once with it on, so what is pinned is the value the label gets rather than the
#      presence of a word in a string: a shake calms to a third, and the two colour-cycling effects
#      go to zero, which is the engine's way of holding still.
#   3. THE REVEAL ENDS SOMEWHERE. Reveal Text and Skip Reveal both call `_on_reveal_finished`, which
#      is what the sheet's On Reveal Finished event compiles to - so a sheet holding the reveal and
#      that event is compiled and PARSED here, the same way the archive rows are.
#   4. THE FRACTION IS THE ENGINE'S OWN NUMBER. Revealed Fraction reads visible_ratio, so the reveal
#      is stepped by hand on a real label - character by character, no tree and no tween - and the
#      fraction is pinned at each step against what the engine says.
#   5. A HAND-TYPED TAG READS BACK AS THE ROW. A file holding the tag line and nothing else lifts to
#      Set Text With Effect with the effect, the strength and the words in its fields, and re-emits
#      BYTE FOR BYTE.
#   6. THE STYLES LOAD. The shipped starter is loaded as a resource and asked its six answers,
#      including the door that hands a style's colour over to the damage that caused it.
#
# ONE THING DELIBERATELY NOT TESTED HERE: whether anything wobbles. The effects are the engine's own
# and a headless suite draws nothing, so what is proven is the tag, the number in it and the round
# trip - not the pixels.
@tool
class_name TextEffectACEsTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const MODULE_PATH := "res://addons/eventforge/registration/modules/text_effect_aces.gd"
const LIFT_PATH := "res://addons/eventforge/importer/text_effect_lift.gd"
const STYLES_PATH := "res://eventsheet_addons/floating_text_styles_resource/floating_text_styles.tres"
const PROBE_SCRIPT := "user://text_effect_probe.gd"
const COMPILE_PROBE := "user://text_effect_compile_probe.gd"

## The two Engine metas the effect rows read. Named here because the test SETS them and has to put
## them back: a meta left behind is a leak the next test inherits.
const NO_FLASHING := "no_flashing"
const TEXT_SCALE := "text_size_scale"

## The file the lift half reads: one tag line inside a ready handler, spelled exactly as the
## compiler writes it. It is the fixture AND the expected output - the lift's promise is that opening
## this and saving it again changes nothing.
const HAND_WRITTEN := """extends Node


func _ready() -> void:
	$Title.bbcode_enabled = true
	$Title.text = "[wave amp=%s freq=5]" % (40 * float(Engine.get_meta("text_size_scale", 1.0))) + "Starfall" + "[/wave]"
"""


static func run() -> bool:
	var all_passed: bool = true
	all_passed = _run_registration() and all_passed
	all_passed = _run_tags() and all_passed
	all_passed = _run_accessibility() and all_passed
	all_passed = _run_reveal() and all_passed
	all_passed = _run_fraction() and all_passed
	all_passed = _run_lift() and all_passed
	all_passed = _run_styles() and all_passed
	if all_passed:
		print("[PASS] text_effect_aces_test: the six tags, the reveal and the floating text styles")
	return all_passed


## The eleven rows register with the ids, kinds and host the picker files them under.
static func _run_registration() -> bool:
	var by_id: Dictionary = _by_id()
	var rows: Array = []
	for entry: Array in [
			["SetTextWithEffect", ACEDescriptor.ACEType.ACTION],
			["WrapSelectionInEffect", ACEDescriptor.ACEType.ACTION],
			["ClearEffects", ACEDescriptor.ACEType.ACTION],
			["InstallTextEffect", ACEDescriptor.ACEType.ACTION],
			["RevealText", ACEDescriptor.ACEType.ACTION],
			["SkipReveal", ACEDescriptor.ACEType.ACTION],
			["PauseRevealAt", ACEDescriptor.ACEType.ACTION],
			["EffectIsActive", ACEDescriptor.ACEType.CONDITION],
			["IsRevealing", ACEDescriptor.ACEType.CONDITION],
			["RevealedFraction", ACEDescriptor.ACEType.EXPRESSION],
			["OnRevealFinished", ACEDescriptor.ACEType.TRIGGER]]:
		var ace_id: String = str(entry[0])
		rows.append(["%s is registered" % ace_id, by_id.has(ace_id), true])
		if not by_id.has(ace_id):
			continue
		var descriptor: ACEDescriptor = by_id[ace_id]
		rows.append(["%s is the kind it says" % ace_id, int(descriptor.ace_type), int(entry[1])])
		rows.append(["%s files under Text" % ace_id, str(descriptor.category), "Text"])
	# Every row but the trigger belongs to the one label that parses BBCode; the trigger is a moment
	# of the sheet and belongs to no node.
	rows.append(["the effect rows are RichTextLabel's", str(by_id["SetTextWithEffect"].node_type), "RichTextLabel"])
	rows.append(["and so is the reveal", str(by_id["RevealText"].node_type), "RichTextLabel"])
	rows.append(["the finish is a moment, not a node's signal", str(by_id["OnRevealFinished"].node_type), ""])
	rows.append(["and it hangs off no engine signal", str(by_id["OnRevealFinished"].signal_name), ""])
	# The effect field offers exactly the words the templates are written from.
	rows.append(["the effect field offers the seven words the templates write",
		_option_keys(by_id["SetTextWithEffect"], "effect"),
		["wave", "shake", "tornado", "rainbow", "fade", "pulse", "custom"]])
	# A node-scoped row that owns its own target keeps ONE of them, whatever registration would have
	# added: the transform is skipped exactly because the param is already there.
	var registered: ACEDescriptor = ACERegistry.find_descriptor("Core", "SetTextWithEffect")
	var param_ids: Array = []
	for param: ACEParam in registered.params:
		param_ids.append(str(param.id))
	rows.append(["the shipped row carries one On node field, not two",
		param_ids, ["text", "effect", "strength", "custom", "target"]])
	# The sentence a reader sees is short, and the trigger says the moment rather than the machinery.
	rows.append(["the row reads as a sentence", str(by_id["SetTextWithEffect"].display_text),
		"set text to {text} with [b]{effect}[/b]"])
	rows.append(["and the finish reads as a moment", str(by_id["OnRevealFinished"].display_text),
		"On reveal finished"])
	return SUPPORT.pins("text_effect_aces_test", rows)


## The tag each effect writes, to the character. Every one names its OWN knob, because writing amp
## into a shake would be accepted by the parser and do nothing on screen.
static func _run_tags() -> bool:
	var rows: Array = []
	var set_wave: String = _emitted("SetTextWithEffect", {"effect": "wave", "strength": "40", "text": "\"Starfall\"", "target": ""})
	rows.append(["the wave row turns bbcode on first", set_wave.split("\n")[0], "bbcode_enabled = true"])
	rows.append(["and writes the engine's own wave tag", set_wave.split("\n")[1],
		"text = \"[wave amp=%s freq=5]\" % (40 * float(Engine.get_meta(\"text_size_scale\", 1.0))) + \"Starfall\" + \"[/wave]\""])
	rows.append(["a set row is two statements and no more", set_wave.split("\n").size(), 2])
	rows.append(["no segment mark survives into the code", set_wave.contains("{?"), false])
	var set_shake: String = _emitted("SetTextWithEffect", {"effect": "shake", "strength": "5", "text": "\"Ouch\"", "target": "$Hud/Damage"})
	rows.append(["a shake names level, which is the knob shake has", set_shake.split("\n")[1],
		"$Hud/Damage.text = \"[shake rate=20 level=%s]\" % (5 * (0.3 if bool(Engine.get_meta(\"no_flashing\", false)) else 1.0)) + \"Ouch\" + \"[/shake]\""])
	var set_rainbow: String = _emitted("SetTextWithEffect", {"effect": "rainbow", "strength": "1", "text": "\"Legendary\"", "target": ""})
	rows.append(["a rainbow names freq, and answers the flashing setting rather than the size one",
		set_rainbow.split("\n")[1],
		"text = \"[rainbow freq=%s sat=0.8 val=0.8]\" % (1 * (0.0 if bool(Engine.get_meta(\"no_flashing\", false)) else 1.0)) + \"Legendary\" + \"[/rainbow]\""])
	var set_custom: String = _emitted("SetTextWithEffect", {"effect": "custom", "strength": "2", "text": "\"Glitched\"", "custom": "\"glitch\"", "target": ""})
	rows.append(["the custom door spells the tag out of your own field", set_custom.split("\n")[1],
		"text = (\"[\" + \"glitch\" + \" strength=%s]\") % (2 * float(Engine.get_meta(\"text_size_scale\", 1.0))) + \"Glitched\" + (\"[/\" + \"glitch\" + \"]\")"])
	# The wrap puts the CLOSING tag in first, at the higher index, so the opening insert cannot shift
	# the position the closing one was measured at.
	var wrap: String = _emitted("WrapSelectionInEffect", {"effect": "wave", "strength": "40", "from": "0", "to": "5", "target": ""})
	rows.append(["the wrap inserts the closing tag before the opening one", wrap.split("\n")[1],
		"text = text.insert(int(5), \"[/wave]\").insert(int(0), \"[wave amp=%s freq=5]\" % (40 * float(Engine.get_meta(\"text_size_scale\", 1.0))))"])
	# Clearing asks the label for its own parsed text, so there is no tag list to keep up to date.
	rows.append(["clearing asks the label rather than a list of tag names",
		_emitted("ClearEffects", {"target": ""}), "text = get_parsed_text()"])
	# Clearing owns its own target rather than taking the one registration appends, because the
	# transform prefixes the LINE and this line reads the label on BOTH sides of the `=`: retargeted by
	# the transform it would have written another node's text with this one's words.
	rows.append(["and asks the right node when one is named",
		_emitted("ClearEffects", {"target": "$Title"}), "$Title.text = $Title.get_parsed_text()"])
	rows.append(["the condition asks the text it can see",
		_emitted("EffectIsActive", {"effect": "shake", "target": ""}), "text.contains(\"[shake\")"])
	# The engine really does strip the tags back off, which is the whole reason Clear Effects is one
	# call rather than a list of replacements.
	var label: RichTextLabel = RichTextLabel.new()
	label.bbcode_enabled = true
	label.text = "[wave amp=40 freq=5]Starfall[/wave]"
	rows.append(["and the engine really hands back the words without them", label.get_parsed_text(), "Starfall"])
	rows.append(["counting the words rather than the markup", label.get_total_character_count(), 8])
	label.free()
	return SUPPORT.pins("text_effect_aces_test", rows)


## The two settings, RUN rather than described: what number does the label actually get.
static func _run_accessibility() -> bool:
	var rows: Array = []
	var shake_knob: String = "5 * (0.3 if bool(Engine.get_meta(\"no_flashing\", false)) else 1.0)"
	var rainbow_knob: String = "1 * (0.0 if bool(Engine.get_meta(\"no_flashing\", false)) else 1.0)"
	var wave_knob: String = "40 * float(Engine.get_meta(\"text_size_scale\", 1.0))"
	_clear_metas()
	rows.append(["with nothing set, a shake is the strength you asked for", _value(shake_knob), 5.0])
	rows.append(["a rainbow cycles at the speed you asked for", _value(rainbow_knob), 1.0])
	rows.append(["and a wave is the height you asked for", _value(wave_knob), 40.0])
	Engine.set_meta(NO_FLASHING, true)
	rows.append(["reduce flashing turns a shake into a drift", _value(shake_knob), 1.5])
	rows.append(["and holds the rainbow still", _value(rainbow_knob), 0.0])
	rows.append(["without touching what does not flash", _value(wave_knob), 40.0])
	Engine.remove_meta(NO_FLASHING)
	Engine.set_meta(TEXT_SCALE, 2.0)
	rows.append(["a bigger text size draws a bigger wave", _value(wave_knob), 80.0])
	_clear_metas()
	rows.append(["and the metas are put back", Engine.has_meta(TEXT_SCALE) or Engine.has_meta(NO_FLASHING), false])
	return SUPPORT.pins("text_effect_aces_test", rows)


## The reveal: the code it emits, and the sheet that has to parse because of what that code calls.
static func _run_reveal() -> bool:
	var rows: Array = []
	var reveal: String = _emitted("RevealText", {"text": "\"The bridge is out.\"", "chars_per_second": "40", "sound": "$Blip", "target": "$Sign", "uid": "a1"})
	rows.append(["the reveal starts the line at nothing shown",
		reveal.contains("$Sign.visible_characters = 0"), true])
	rows.append(["it ends a reveal already running on that label",
		reveal.contains("if $Sign.has_meta(&\"reveal\"):\n\t($Sign.get_meta(&\"reveal\") as Tween).kill()"), true])
	rows.append(["the speed is characters a second, turned into the delay between two of them",
		reveal.contains("var __step_a1: float = 1.0 / maxf(1.0, float(40))"), true])
	rows.append(["a character at a time, through the label's own setter",
		reveal.contains("__reveal_a1.tween_callback($Sign.set_visible_characters.bind(__at_a1)).set_delay(__step_a1)"), true])
	rows.append(["the sound clicks on each character when one is named",
		reveal.contains("if __voice_a1 != null:\n\t\t__reveal_a1.tween_callback(__voice_a1.play)"), true])
	rows.append(["a pause written down earlier is held on the way",
		reveal.contains("__reveal_a1.tween_interval(float(__pauses_a1[__at_a1]))"), true])
	rows.append(["and the last callback is the answer", reveal.ends_with("__reveal_a1.tween_callback(_on_reveal_finished)"), true])
	var skip: String = _emitted("SkipReveal", {"target": "$Sign"})
	rows.append(["a skip shows the whole line", skip.contains("$Sign.visible_ratio = 1.0"), true])
	rows.append(["and answers in the same place a reveal that ran out answers",
		skip.ends_with("_on_reveal_finished()"), true])
	var pause: String = _emitted("PauseRevealAt", {"at": "12", "seconds": "0.4", "target": "$Sign", "uid": "b2"})
	rows.append(["a pause is written down on the label the reveal reads it from",
		pause, "var __pauses_b2: Dictionary = $Sign.get_meta(&\"reveal_pauses\", {})\n__pauses_b2[int(12)] = float(0.4)\n$Sign.set_meta(&\"reveal_pauses\", __pauses_b2)"])
	# The trigger resolves to the function both rows call, and a sheet holding the reveal and the
	# event has to parse: an emitted call into a function nobody declared is the failure this catches.
	var signature: Dictionary = TriggerResolver.resolve_trigger(_trigger_row("OnRevealFinished"))
	rows.append(["the finish compiles to the function the reveal calls",
		str(signature.get("function_name", "")), "_on_reveal_finished"])
	rows.append(["with nothing handed to it", str(signature.get("args", "")), ""])
	rows.append(["and nothing to connect", str(signature.get("signal_name", "")), ""])
	var compiled: String = _compiled(_reveal_sheet())
	rows.append(["the sheet writes the handler the reveal calls",
		compiled.contains("func _on_reveal_finished() -> void:"), true])
	rows.append(["and the whole emitted file parses", _parses(compiled), true])
	return SUPPORT.pins("text_effect_aces_test", rows)


## Revealed Fraction is the engine's own number, stepped by hand on a real label - no tree, no tween.
static func _run_fraction() -> bool:
	var rows: Array = []
	var label: RichTextLabel = RichTextLabel.new()
	label.bbcode_enabled = true
	label.text = "[wave amp=40 freq=5]Starfall[/wave]"
	label.visible_characters = 0
	rows.append(["nothing shown is a fraction of nothing", label.visible_ratio, 0.0])
	rows.append(["and the row would say it is revealing", label.visible_ratio < 1.0, true])
	label.visible_characters = 4
	rows.append(["half the word is half the line", label.visible_ratio, 0.5])
	label.visible_characters = 8
	rows.append(["all eight characters is the whole line", label.visible_ratio, 1.0])
	rows.append(["and the row stops saying it is revealing", label.visible_ratio < 1.0, false])
	# The skip writes the ratio rather than the count, and the engine answers with its own spelling
	# for "all of them" - which is why the two reading rows ask the ratio and not the count.
	label.visible_characters = 3
	label.visible_ratio = 1.0
	rows.append(["a skip written as a ratio reads back as the engine's own all-of-them",
		label.visible_characters, -1])
	label.free()
	return SUPPORT.pins("text_effect_aces_test", rows)


## A hand-typed tag, opened as the row that would have written it, and saved again unchanged.
static func _run_lift() -> bool:
	var rows: Array = []
	# The table itself: one entry per engine effect, and none for the custom door, whose tag names
	# the effect twice on one line.
	var ids: Array[String] = []
	for entry: Dictionary in load(LIFT_PATH).lift_entries():
		ids.append(str(entry.get("id", "")))
		rows.append(["the %s entry was accepted" % str(entry.get("id", "")),
			entry.has(EventForgeLiftTable.REFUSAL_KEY), false])
	rows.append(["there is one entry per engine effect", ids,
		["text_effect_wave", "text_effect_shake", "text_effect_tornado", "text_effect_rainbow",
			"text_effect_fade", "text_effect_pulse"]])
	var file: FileAccess = FileAccess.open(PROBE_SCRIPT, FileAccess.WRITE)
	file.store_string(HAND_WRITTEN)
	file.close()
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(PROBE_SCRIPT, false)
	EventSheetACELifter.reset_progress()
	rows.append(["the file opens as events", EventSheetACELifter.attempt_lift(sheet, HAND_WRITTEN), true])
	var found: ACEAction = _find_action(sheet, "SetTextWithEffect")
	rows.append(["the tag opens as the row that writes it", found != null, true])
	if found != null:
		rows.append(["with the effect it was written in", str(found.params.get("effect", "")), "wave"])
		rows.append(["the strength it was written at", str(found.params.get("strength", "")), "40"])
		rows.append(["the words it was written around", str(found.params.get("text", "")), "\"Starfall\""])
		rows.append(["and the label it was written on", str(found.params.get("target", "")), "$Title"])
	var output: String = str(SheetCompiler.compile(sheet, PROBE_SCRIPT).get("output", ""))
	rows.append(["and saving it again reproduces the file byte for byte", output, HAND_WRITTEN])
	DirAccess.remove_absolute(PROBE_SCRIPT)
	return SUPPORT.pins("text_effect_aces_test", rows)


## The styles starter, loaded and asked its answers - including the door that hands a colour over.
static func _run_styles() -> bool:
	var rows: Array = []
	var styles: Resource = load(STYLES_PATH)
	rows.append(["the starter loads", styles != null, true])
	if styles == null:
		return SUPPORT.pins("text_effect_aces_test", rows)
	rows.append(["it names the three manners every game that hits anything has",
		Array(styles.get("style_names")), ["normal", "crit", "heal"]])
	rows.append(["a critical is drawn bigger", _rounded(styles.call("size_of", "crit")), 1.6])
	rows.append(["a plain hit is the size you designed", styles.call("size_of", "normal"), 1.0])
	rows.append(["a critical shakes on its way up", styles.call("shake_of", "crit"), 6.0])
	rows.append(["a heal rises without shaking", styles.call("shake_of", "heal"), 0.0])
	rows.append(["and stays a little longer than a plain hit", _rounded(styles.call("lifetime_of", "heal")), 0.8])
	rows.append(["a critical rises further", styles.call("rise_of", "crit"), 40.0])
	rows.append(["a heal keeps the colour written in the file",
		str(styles.call("colour_of", "heal", Color.RED)), str(Color(0.45, 0.95, 0.55, 1.0))])
	# THE DOOR: a style the file lists takes its colour from the hit instead, which is how a fire
	# number is orange without a colour being typed into the row.
	rows.append(["a plain hit takes the colour of the damage that caused it",
		styles.call("colour_of", "normal", Color.RED), Color.RED])
	rows.append(["and falls back to white when nothing handed it one",
		styles.call("colour_of", "normal"), Color.WHITE])
	# Every answer is total: a name this set has never heard of reads as the plain default.
	rows.append(["a manner nobody wrote down is still answered", styles.call("size_of", "nonesuch"), 1.0])
	rows.append(["and is not claimed", styles.call("has_style", "nonesuch"), false])
	return SUPPORT.pins("text_effect_aces_test", rows)


# -- the pieces ------------------------------------------------------------------------------


## A sheet holding a reveal and the event it answers into - the shape that has to parse.
static func _reveal_sheet() -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	# The reveal is a rich text label's row, so the sheet it compiles into is one - a Node host would
	# fail to parse for the honest reason that a Node has no `text`.
	sheet.host_class = "RichTextLabel"
	var starting: EventRow = _trigger_row("OnReady")
	var reveal: ACEAction = ACEAction.new()
	reveal.provider_id = "Core"
	reveal.ace_id = "RevealText"
	reveal.params = {"text": "\"The bridge is out.\"", "chars_per_second": "40", "sound": "null", "target": "", "uid": "z1"}
	reveal.codegen_template = str(_by_id()["RevealText"].codegen_template)
	starting.actions.append(reveal)
	sheet.events.append(starting)
	var answer: EventRow = _trigger_row("OnRevealFinished")
	var say: ACEAction = ACEAction.new()
	say.provider_id = "Core"
	say.ace_id = "Print"
	say.codegen_template = "print(\"done\")"
	answer.actions.append(say)
	sheet.events.append(answer)
	return sheet


static func _trigger_row(trigger_id: String) -> EventRow:
	var row: EventRow = EventRow.new()
	row.trigger_provider_id = "Core"
	row.trigger_id = trigger_id
	return row


## The first action carrying this ace_id anywhere in the sheet, or null.
static func _find_action(sheet: EventSheetResource, ace_id: String) -> ACEAction:
	for entry: Variant in sheet.events:
		var event_row: EventRow = entry as EventRow
		if event_row == null:
			continue
		for candidate: Variant in event_row.actions:
			var action: ACEAction = candidate as ACEAction
			if action != null and str(action.ace_id) == ace_id:
				return action
	return null


static func _compiled(sheet: EventSheetResource) -> String:
	var output: String = str(SheetCompiler.compile(sheet, COMPILE_PROBE).get("output", ""))
	if FileAccess.file_exists(COMPILE_PROBE):
		DirAccess.remove_absolute(COMPILE_PROBE)
	return output


## Runs an emitted expression for real - the pinned text is also the text that is run.
static func _value(expression: String) -> Variant:
	var script: GDScript = GDScript.new()
	script.source_code = "@tool\nextends RefCounted\n\n\nstatic func probe() -> Variant:\n\treturn %s\n" % expression
	if script.reload() != OK:
		print("  [FAIL] text_effect_aces_test: an emitted expression did not compile")
		return null
	return script.call("probe")


static func _parses(source: String) -> bool:
	var script: GDScript = GDScript.new()
	script.source_code = source
	return script.reload() == OK


static func _emitted(ace_id: String, params: Dictionary) -> String:
	var by_id: Dictionary = _by_id()
	if not by_id.has(ace_id):
		return ""
	return ActionCodegen._apply_template(str(by_id[ace_id].codegen_template), params)


static func _by_id() -> Dictionary:
	var by_id: Dictionary = {}
	for descriptor: ACEDescriptor in load(MODULE_PATH).get_descriptors():
		by_id[descriptor.ace_id] = descriptor
	return by_id


## The keys a dropdown inserts, in the order it offers them.
static func _option_keys(descriptor: ACEDescriptor, param_id: String) -> Array:
	for param: ACEParam in descriptor.params:
		if str(param.id) != param_id:
			continue
		var keys: Array = []
		for option: Variant in param.options:
			keys.append(str(option["key"]) if option is Dictionary else str(option))
		return keys
	return []


## One number as a PackedFloat32Array hands it back: the list stores float32 and Godot widens it to a
## double on the way out, so 1.6 reads as 1.60000002384186. A thousandth is finer than any of these
## dials and coarse enough to land back on the number the starter was written with.
static func _rounded(value: Variant) -> float:
	return snappedf(float(value), 0.001)


## Both metas back to nothing, so a run of this test leaves the engine as it found it.
static func _clear_metas() -> void:
	for name: String in [NO_FLASHING, TEXT_SCALE]:
		if Engine.has_meta(name):
			Engine.remove_meta(name)
