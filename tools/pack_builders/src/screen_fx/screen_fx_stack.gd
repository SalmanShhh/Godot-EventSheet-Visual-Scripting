# Pack source - screen_fx, the post stack. The behaviour the pack grew on top of its six frozen
# verbs, as real GDScript: highlighted, parse-checked and breakpointable here, and assembled into the
# pack by Lib.pack_from_source. The #region below is one piece of the sheet; everything outside it is
# scaffolding the pack declares for itself at build time and never reads from here.
extends CanvasLayer

#region stack
## Where the pack's own shaders live once it is installed. The pack builder copies them here beside
## the script, so an effect is a file on disk rather than a string compiled at run time.
const POST_DIRECTORY: String = "res://eventsheet_addons/screen_fx/"

## The name a shader file takes: the effect word with its spaces closed up, under one prefix. An
## effect word and its file can therefore never drift apart.
const POST_PREFIX: String = "post_"

## The twelve effects the stack ships, by the word a row uses. Each is one full-screen shader with a
## `strength` dial and a few of its own. Every one of them READS THE SCREEN BACK, which is one screen
## read per pixel of the viewport per entry that is on - so a stack of twelve is a thing to be
## deliberate about, and a stack of two costs two. Bloom is the dear one: it reads the screen nine
## times over rather than once, which is what gathering a spill from around each pixel costs.
##
## The last three arrived with the moments, because a moment is made of these words: a win swells the
## bloom and lifts the colour, and danger drains it away again.
const POST_EFFECTS: PackedStringArray = ["vignette", "film grain", "scanlines", "pixelate",
	"colour grade", "dither", "fisheye", "glitch", "letterbox", "bloom", "saturate", "desaturate"]

## And the two the colour-vision rows use. They are ordinary stack entries under reserved names, so
## Save Look records them, Clear Look takes them away, and Move Post Effect Before can put the
## correction last where it belongs - none of which needs a second mechanism.
const SEE_AS_EFFECT: String = "see as"
const CORRECT_EFFECT: String = "correct colours"

## And the two the accessibility dials do NOT touch. A colour-vision correction is not an amplitude
## that can strobe - it is the thing that makes the screen readable at all - so the effect-strength
## dial does not fade it away and the no-flashing ceiling does not hold it down. Every other entry
## obeys both.
const UNDIALLED_EFFECTS: PackedStringArray = [SEE_AS_EFFECT, CORRECT_EFFECT]

## The four kinds of colour vision, IN THE ORDER the two vision shaders number them: the position in
## this list is the number written into the shader, so nothing keeps a second table of numbers in
## step with this one.
const VISION_KINDS: PackedStringArray = ["normal", "protanopia", "deuteranopia", "tritanopia"]

## The dial every effect shader declares, and the one the rows turn. An entry holding 0 draws the
## screen back exactly as it arrived, which is the moment its rectangle is worth hiding.
const STRENGTH_DIAL: String = "strength"

## The dial the two vision shaders take their kind of vision on.
const VISION_DIAL: String = "vision"

## THE ACCESSIBILITY CEILING. A player who has asked for no flashing gets the same rows - a pulse
## still pulses, a look still lands - with the amplitude held under this and the time held over
## FLASH_FLOOR_SECONDS, so nothing the stack draws can strobe. The six verbs this pack shipped first
## are deliberately untouched by it: their bytes are a promise. The clamp lives in the new layer.
const FLASH_CEILING: float = 0.3
const FLASH_FLOOR_SECONDS: float = 0.4

## The two Engine meta this project already keeps its accessibility answers in - the same two the
## built-in Set No Flashing and Set Effect Strength rows write. A game that has those rows needs
## nothing else for the stack to obey them.
const NO_FLASHING_META: StringName = &"no_flashing"
const EFFECT_STRENGTH_META: StringName = &"effect_strength"

## The look resource's own script, loaded by path rather than named as a class, so this pack still
## runs (and says so) in a project that only installed Screen FX.
const LOOK_SCRIPT: String = "res://eventsheet_addons/screen_look_resource/screen_look_resource.gd"

## THE STACK, in the order the effects are drawn: the first entry is applied to the screen first and
## the last one has the last word. An entry is a small record rather than a node, because the order,
## the names and the strengths are what rows ask about, and a rectangle is only how one reaches the
## screen.
##
##   called    the name rows address this entry by (its effect word, when nobody said otherwise)
##   effect    which of the shipped effects it is
##   strength  how far the row ASKED it to go, 0 to 1 - the request, not what reached the screen.
##             The two accessibility dials are applied once, on the way to the shader, so a walk
##             that moves this value cannot scale it a second time and a look saved from it holds
##             what the game asked for rather than what one player's settings allowed
##   enabled   whether it draws at all
##   params    the effect's own dials, by the uniform name the shader declares
##   rect      the full-screen ColorRect wearing it, once there is one
var _stack: Array[Dictionary] = []

## The shaders loaded so far, by effect word. A project that only ever uses a vignette loads one.
var _shaders: Dictionary = {}

## The strength walks running right now, keyed by the entry they move, so a second row on the same
## entry replaces the first rather than the two of them fighting over one dial.
var _stack_walks: Dictionary = {}

## What Current Look reads back: the name of the look last worn, or "" when the stack was built row
## by row. Save Look does not change it, because saving is not wearing.
var _look_name: String = ""


## Adds one effect to the top of the post stack and turns it on. The twelve words are vignette, film
## grain, scanlines, pixelate, colour grade, dither, fisheye, glitch, letterbox, bloom, saturate and
## desaturate; leave the name empty and the entry is called after its effect, which is what one of
## each wants.
##
## Every entry reads the screen back, so each one costs one screen read per pixel of the viewport
## while it is on. Two or three is a look; twelve is a bill.
## @ace_action
## @ace_featured
## @ace_name("Add Post Effect")
## @ace_display_template("Add [b]{effect}[/b] at [b]{strength}[/b]")
## @ace_param(effect, options: vignette=Vignette|film grain=Film grain|scanlines=Scanlines|pixelate=Pixelate|colour grade=Colour grade|dither=Dither|fisheye=Fisheye|glitch=Glitch|letterbox=Letterbox|bloom=Bloom|saturate=Saturate|desaturate=Desaturate, default: vignette, desc: "Which effect. Each one reads the screen back, so each one costs a screen read per pixel it covers.")
## @ace_param(called, desc: "What later rows address it by. Empty names it after its effect, which is what one of each wants.")
## @ace_param(strength, default: 0.6, desc: "How far it goes, 0 to 1. Scaled by the effect-strength dial, and held under a ceiling while no flashing is on.")
## @ace_codegen_template("$ScreenFx.add_post_effect("{effect}", "{called}", {strength})")
func add_post_effect(effect: String = "vignette", called: String = "", strength: float = 0.6) -> void:
	var word: String = effect.strip_edges().to_lower()
	if not _is_an_effect(word):
		push_warning("Add Post Effect: no effect is called \"%s\" - the words are %s." % [
			effect, ", ".join(effect_words())])
		return
	var name_of_it: String = called.strip_edges().to_lower()
	if name_of_it.is_empty():
		name_of_it = word
	var at: int = _find(name_of_it)
	if at >= 0:
		_stack[at]["effect"] = word
		_stack[at]["enabled"] = true
		_write_strength(name_of_it, strength)
		return
	_stack.append({"called": name_of_it, "effect": word, "strength": clampf(strength, 0.0, 1.0),
		"enabled": true, "params": {}, "rect": null})
	_apply(_stack.size() - 1)
	_reorder()


## Takes one effect off the stack and frees its rectangle, so it stops costing anything at all.
## @ace_action
## @ace_name("Remove Post Effect")
## @ace_display_template("Remove post effect [b]{called}[/b]")
## @ace_param(called, default: vignette, desc: "The name the entry was added under.")
## @ace_codegen_template("$ScreenFx.remove_post_effect("{called}")")
func remove_post_effect(called: String = "vignette") -> void:
	var at: int = _find(called)
	if at < 0:
		return
	_stop_walk_on(str(_stack[at].get("called", "")))
	var rect: ColorRect = _stack[at].get("rect", null) as ColorRect
	if rect != null and is_instance_valid(rect):
		rect.queue_free()
	_stack.remove_at(at)


## Turns one entry back on at the strength it already holds - the other half of Disable, for an
## effect a look should keep but a moment should hide.
## @ace_action
## @ace_name("Enable Post Effect")
## @ace_display_template("Enable post effect [b]{called}[/b]")
## @ace_param(called, default: vignette, desc: "The name the entry was added under.")
## @ace_codegen_template("$ScreenFx.enable_post_effect("{called}")")
func enable_post_effect(called: String = "vignette") -> void:
	_set_enabled(called, true)


## Turns one entry off without forgetting it: its rectangle stops drawing, its strength is kept, and
## Enable brings it back exactly as it was.
## @ace_action
## @ace_name("Disable Post Effect")
## @ace_display_template("Disable post effect [b]{called}[/b]")
## @ace_param(called, default: vignette, desc: "The name the entry was added under.")
## @ace_codegen_template("$ScreenFx.disable_post_effect("{called}")")
func disable_post_effect(called: String = "vignette") -> void:
	_set_enabled(called, false)


## Sets how far one entry goes, at once. The effect-strength dial scales it and the no-flashing
## ceiling holds it down, so the number a row asks for is a request rather than a command.
## @ace_action
## @ace_name("Set Post Strength")
## @ace_display_template("Set [b]{called}[/b] strength to [b]{strength}[/b]")
## @ace_param(called, default: vignette, desc: "The name the entry was added under.")
## @ace_param(strength, default: 1.0, desc: "How far it goes, 0 to 1.")
## @ace_codegen_template("$ScreenFx.set_post_strength("{called}", {strength})")
func set_post_strength(called: String = "vignette", strength: float = 1.0) -> void:
	_stop_walk_on(called.strip_edges().to_lower())
	_write_strength(called, strength)


## Walks one entry's strength to a value over a time, and back again afterwards if a second time is
## given - which is the shape of a held breath: in, hold, out, all in one row.
## @ace_action
## @ace_name("Fade Post Strength")
## @ace_display_template("Fade [b]{called}[/b] to [b]{to}[/b] over [b]{seconds}[/b] s")
## @ace_param(called, default: vignette, desc: "The name the entry was added under.")
## @ace_param(to, default: 1.0, desc: "The strength to arrive at, 0 to 1.")
## @ace_param(seconds, default: 0.5, desc: "How long the walk there takes.")
## @ace_param(then_back_seconds, default: 0.0, desc: "How long to walk back to where it started afterwards. 0 stays where it landed.")
## @ace_codegen_template("$ScreenFx.fade_post_strength("{called}", {to}, {seconds}, {then_back_seconds})")
func fade_post_strength(called: String = "vignette", to: float = 1.0, seconds: float = 0.5, then_back_seconds: float = 0.0) -> void:
	var at: int = _find(called)
	if at < 0:
		return
	var started_at: float = float(_stack[at].get("strength", 0.0))
	if seconds <= 0.0 and then_back_seconds <= 0.0:
		set_post_strength(called, to)
		return
	_walk_strength(str(_stack[at].get("called", "")), clampf(to, 0.0, 1.0), _slowed(seconds),
		started_at, _slowed(then_back_seconds) if then_back_seconds > 0.0 else 0.0, false)


## THE ONE-SHOT: turns an effect all the way up and lets it fall back, in one row. If the stack does
## not hold that effect yet the pulse borrows one and takes it away again afterwards, so a hit, a
## boom or a win is one row and leaves nothing behind.
##
## A pulse with no time at all is a set that stays, because that is the only thing "pulse for zero
## seconds" can honestly mean.
## @ace_action
## @ace_featured
## @ace_name("Pulse Post Effect")
## @ace_display_template("Pulse [b]{effect}[/b] at [b]{strength}[/b] for [b]{seconds}[/b] s")
## @ace_param(effect, options: vignette=Vignette|film grain=Film grain|scanlines=Scanlines|pixelate=Pixelate|colour grade=Colour grade|dither=Dither|fisheye=Fisheye|glitch=Glitch|letterbox=Letterbox|bloom=Bloom|saturate=Saturate|desaturate=Desaturate, default: vignette, desc: "Which effect to flash up and let fall.")
## @ace_param(strength, default: 0.6, desc: "How far up it goes, 0 to 1. Held under a ceiling while no flashing is on.")
## @ace_param(seconds, default: 0.35, desc: "How long it takes to fall back to where it was.")
## @ace_codegen_template("$ScreenFx.pulse_post_effect("{effect}", {strength}, {seconds})")
func pulse_post_effect(effect: String = "vignette", strength: float = 0.6, seconds: float = 0.35) -> void:
	var word: String = effect.strip_edges().to_lower()
	if not _is_an_effect(word):
		push_warning("Pulse Post Effect: no effect is called \"%s\" - the words are %s." % [
			effect, ", ".join(effect_words())])
		return
	var borrowed: bool = _find(word) < 0
	var falls_back_to: float = 0.0
	if borrowed:
		add_post_effect(word, word, 0.0)
	else:
		falls_back_to = float(_stack[_find(word)].get("strength", 0.0))
	if _find(word) < 0:
		return
	_stop_walk_on(word)
	_write_strength(word, strength)
	if seconds <= 0.0:
		return
	_walk_strength(word, clampf(strength, 0.0, 1.0), 0.0, falls_back_to, _slowed(seconds), borrowed)


## Moves one entry so it is drawn BEFORE another - which is what decides whose look wins. A grade
## under a vignette grades the game; a grade over one grades the vignette too.
## @ace_action
## @ace_name("Move Post Effect Before")
## @ace_display_template("Draw [b]{called}[/b] before [b]{before}[/b]")
## @ace_param(called, default: vignette, desc: "The entry to move.")
## @ace_param(before, desc: "The entry it should be drawn before. Empty moves it to the very end, so it has the last word.")
## @ace_codegen_template("$ScreenFx.move_post_effect_before("{called}", "{before}")")
func move_post_effect_before(called: String = "vignette", before: String = "") -> void:
	var at: int = _find(called)
	if at < 0:
		return
	var moved: Dictionary = _stack[at]
	_stack.remove_at(at)
	var landing: int = _find(before)
	if landing < 0:
		_stack.append(moved)
	else:
		_stack.insert(landing, moved)
	_reorder()


## Draws the whole post stack UNDER this layer, so the interface on it stays sharp and unfiltered
## while the game behind it is graded, blurred or dimmed. This is the row a health-bar layer wants.
## @ace_action
## @ace_name("Draw Post Effects Below")
## @ace_display_template("Draw post effects below [i]{other}[/i]")
## @ace_param(other, hint: node_path, desc: "The CanvasLayer the effects should stay under - usually the one the interface is on.")
## @ace_codegen_template("$ScreenFx.draw_post_effects_below({other})")
func draw_post_effects_below(other: CanvasLayer) -> void:
	if other == null:
		return
	layer = other.layer - 1


## Draws the whole post stack OVER this layer, so the interface is graded and dimmed along with the
## game. That is what a cutscene letterbox or a full-screen colour change usually wants.
## @ace_action
## @ace_name("Draw Post Effects Above")
## @ace_display_template("Draw post effects above [i]{other}[/i]")
## @ace_param(other, hint: node_path, desc: "The CanvasLayer the effects should cover - usually the one the interface is on.")
## @ace_codegen_template("$ScreenFx.draw_post_effects_above({other})")
func draw_post_effects_above(other: CanvasLayer) -> void:
	if other == null:
		return
	layer = other.layer + 1


## True while that entry is on the stack, enabled and actually drawing something.
## @ace_condition
## @ace_name("Post Effect Is On")
## @ace_display_template("[b]{called}[/b] is on")
## @ace_param(called, default: vignette, desc: "The name the entry was added under.")
## @ace_codegen_template("$ScreenFx.post_effect_is_on("{called}")")
func post_effect_is_on(called: String = "vignette") -> bool:
	var at: int = _find(called)
	if at < 0:
		return false
	return bool(_stack[at].get("enabled", true)) and _dialled(_stack[at]) > 0.001


## How far one entry currently goes, 0 to 1 - after the effect-strength dial and the no-flashing
## ceiling, so it is what is on the screen rather than what a row asked for. The two colour-vision
## entries are exempt from both, so they read back at what they were set to. 0 for one that is not
## there.
## @ace_expression
## @ace_name("Post Strength")
## @ace_param(called, default: vignette, desc: "The name the entry was added under.")
## @ace_codegen_template("$ScreenFx.post_strength("{called}")")
func post_strength(called: String = "vignette") -> float:
	var at: int = _find(called)
	if at < 0:
		return 0.0
	return _dialled(_stack[at])


## How many effects the stack is drawing right now - the number a reader wants when the frame rate
## has gone, because every one of them reads the whole screen back.
## @ace_expression
## @ace_name("Post Effect Count")
## @ace_codegen_template("$ScreenFx.post_effect_count()")
func post_effect_count() -> int:
	var drawing: int = 0
	for entry: Dictionary in _stack:
		if bool(entry.get("enabled", true)) and _dialled(entry) > 0.001:
			drawing += 1
	return drawing


## SHOWS YOU what a player with one of the three common kinds of colour blindness sees. This is the
## designer's row: turn it on, walk the level, and the health bar that vanishes into the background
## is the bug you came to find. Normal takes it off again.
## @ace_action
## @ace_name("See As")
## @ace_display_template("See as [b]{vision}[/b]")
## @ace_param(vision, options: normal=Normal|protanopia=Protanopia|deuteranopia=Deuteranopia|tritanopia=Tritanopia, default: deuteranopia, desc: "Which kind of vision to simulate. Normal turns the simulation off.")
## @ace_codegen_template("$ScreenFx.see_as("{vision}")")
func see_as(vision: String = "deuteranopia") -> void:
	_wear_vision(SEE_AS_EFFECT, vision, "See As")


## CORRECTS the screen so a player with one of the three common kinds of colour blindness can tell
## apart the colours that would otherwise land on top of each other. This is the player's row, and it
## belongs behind a settings choice rather than on by default. Normal takes it off again.
## @ace_action
## @ace_name("Correct Colours For")
## @ace_display_template("Correct colours for [b]{vision}[/b]")
## @ace_param(vision, options: normal=Normal|protanopia=Protanopia|deuteranopia=Deuteranopia|tritanopia=Tritanopia, default: deuteranopia, desc: "Which kind of vision to correct for. Normal turns the correction off.")
## @ace_codegen_template("$ScreenFx.correct_colours_for("{vision}")")
func correct_colours_for(vision: String = "deuteranopia") -> void:
	_wear_vision(CORRECT_EFFECT, vision, "Correct Colours For")


## Writes the LIVE stack out as a look file: every entry, in order, with its strength and its own
## dials. That is how a look is authored - build it with rows until the screen is right, save it
## once, and every later row picks it by file.
## @ace_action
## @ace_name("Save Look")
## @ace_display_template("Save the look as [b]{path}[/b]")
## @ace_param(path, hint: file_path, default: user://looks/my_look.tres, desc: "Where to write it. user:// is the player's own folder; res:// is your project, which only works while the editor is open.")
## @ace_param(called, default: My look, desc: "The name the look answers to, which is what Look Is and Current Look compare.")
## @ace_codegen_template("$ScreenFx.save_look("{path}", "{called}")")
func save_look(path: String = "user://looks/my_look.tres", called: String = "My look") -> void:
	if not ResourceLoader.exists(LOOK_SCRIPT):
		push_warning("Save Look needs the Screen Look Resource pack, which is not installed.")
		return
	var made: Resource = (load(LOOK_SCRIPT) as GDScript).new()
	made.set("look_name", called)
	made.set("rows", _look_rows())
	var folder: String = path.get_base_dir()
	if not folder.is_empty() and not DirAccess.dir_exists_absolute(folder):
		DirAccess.make_dir_recursive_absolute(folder)
	if ResourceSaver.save(made, path) != OK:
		push_warning("Save Look could not write %s." % path)


## Wears a look at once: the stack becomes exactly what the look says, in the look's own order.
## @ace_action
## @ace_featured
## @ace_name("Use Look")
## @ace_display_template("Use the look [b]{look}[/b]")
## @ace_param(look, hint: resource_path, desc: "A look file. Build one with rows and Save Look, or make one in the Inspector from the Screen Look Resource class.")
## @ace_codegen_template("$ScreenFx.use_look({look})")
func use_look(look: Resource) -> void:
	clear_look()
	if look == null:
		return
	for row: Variant in _rows_of(look):
		var entry: Dictionary = row as Dictionary
		if entry == null:
			continue
		var word: String = str(entry.get("effect", "")).strip_edges().to_lower()
		if not _is_an_effect(word):
			continue
		var name_of_it: String = str(entry.get("called", word)).strip_edges().to_lower()
		add_post_effect(word, name_of_it, float(entry.get("strength", 0.0)))
		_write_params(name_of_it, entry.get("params", {}) as Dictionary)
	_look_name = str(look.get("look_name"))


## Walks from the look on the screen to another one over a time: the effects both looks hold fade
## from one strength to the other, the ones only the old look had fade out and go, and the ones only
## the new look has fade in from nothing. Nothing cuts.
## @ace_action
## @ace_name("Blend To Look")
## @ace_display_template("Blend to the look [b]{look}[/b] over [b]{seconds}[/b] s")
## @ace_param(look, hint: resource_path, desc: "The look to arrive at.")
## @ace_param(seconds, default: 1.0, desc: "How long the crossing takes.")
## @ace_codegen_template("await $ScreenFx.blend_to_look({look}, {seconds})")
func blend_to_look(look: Resource, seconds: float = 1.0) -> void:
	if look == null:
		clear_look()
		return
	var span: float = _slowed(maxf(seconds, 0.0))
	var wanted: Dictionary = {}
	for row: Variant in _rows_of(look):
		var entry: Dictionary = row as Dictionary
		if entry == null:
			continue
		var word: String = str(entry.get("effect", "")).strip_edges().to_lower()
		if not _is_an_effect(word):
			continue
		var name_of_it: String = str(entry.get("called", word)).strip_edges().to_lower()
		wanted[name_of_it] = entry
		if _find(name_of_it) < 0:
			add_post_effect(word, name_of_it, 0.0)
		_write_params(name_of_it, entry.get("params", {}) as Dictionary)
	var leaving: PackedStringArray = PackedStringArray()
	for entry: Dictionary in _stack:
		var name_of_it: String = str(entry.get("called", ""))
		if wanted.has(name_of_it):
			var arriving: Dictionary = wanted[name_of_it]
			_walk_strength(name_of_it, clampf(float(arriving.get("strength", 0.0)), 0.0, 1.0), span,
				0.0, 0.0, false)
		else:
			leaving.append(name_of_it)
	for name_of_it: String in leaving:
		_walk_strength(name_of_it, 0.0, span, 0.0, 0.0, true)
	_look_name = str(look.get("look_name"))
	if span > 0.0 and is_inside_tree():
		await get_tree().create_timer(span).timeout


## Takes every effect off the stack at once and puts the screen back the way the game drew it. The
## empty stack IS the Clean look, which is why the starter look file the pack ships holds no rows.
## @ace_action
## @ace_name("Clear Look")
## @ace_codegen_template("$ScreenFx.clear_look()")
func clear_look() -> void:
	for entry: Dictionary in _stack.duplicate():
		remove_post_effect(str(entry.get("called", "")))
	_look_name = ""


## True while that look is the one on the screen - compared by the look's own name, so a look
## reloaded from disk is still the same look.
## @ace_condition
## @ace_name("Look Is")
## @ace_display_template("The look is [b]{look}[/b]")
## @ace_param(look, hint: resource_path, desc: "The look to compare against what is on the screen.")
## @ace_codegen_template("$ScreenFx.look_is({look})")
func look_is(look: Resource) -> bool:
	if look == null:
		return _look_name.is_empty()
	return _look_name == str(look.get("look_name"))


## The name of the look on the screen, or "" when the stack was built row by row rather than worn
## from a file.
## @ace_expression
## @ace_name("Current Look")
## @ace_codegen_template("$ScreenFx.current_look()")
func current_look() -> String:
	return _look_name


## Every effect word the stack knows, in the order the picker offers them - what a warning prints,
## and what a settings screen can list without keeping a second copy of the list.
## @ace_expression
## @ace_name("Post Effect Words")
## @ace_codegen_template("$ScreenFx.effect_words()")
func effect_words() -> PackedStringArray:
	var words: PackedStringArray = POST_EFFECTS.duplicate()
	words.append(SEE_AS_EFFECT)
	words.append(CORRECT_EFFECT)
	return words


## Whether this word is one of the effects the pack ships - the twelve, plus the two the
## colour-vision rows wear.
func _is_an_effect(word: String) -> bool:
	return POST_EFFECTS.has(word) or word == SEE_AS_EFFECT or word == CORRECT_EFFECT


## Where an entry sits in the stack, or -1. Names are compared trimmed and lower-cased, so a row that
## says "Vignette" and one that says "vignette" mean the same entry.
func _find(called: String) -> int:
	var wanted: String = called.strip_edges().to_lower()
	if wanted.is_empty():
		return -1
	for at: int in _stack.size():
		if str(_stack[at].get("called", "")) == wanted:
			return at
	return -1


## What a row's requested strength really becomes: scaled by the effect-strength dial the whole
## project shares, then held under the ceiling while no flashing is on. ONE function, so no row can
## be the one that forgot.
func _allowed(strength: float) -> float:
	var dial: float = clampf(float(Engine.get_meta(EFFECT_STRENGTH_META, 1.0)), 0.0, 1.0)
	var wanted: float = clampf(strength, 0.0, 1.0) * dial
	if bool(Engine.get_meta(NO_FLASHING_META, false)):
		wanted = minf(wanted, FLASH_CEILING)
	return wanted


## And what a row's requested TIME really becomes: never quicker than the floor while no flashing is
## on, because a small amplitude arriving ten times a second is still a strobe.
func _slowed(seconds: float) -> float:
	if bool(Engine.get_meta(NO_FLASHING_META, false)):
		return maxf(seconds, FLASH_FLOOR_SECONDS)
	return maxf(seconds, 0.0)


## What ONE ENTRY puts on the screen: the strength its row asked for, through the dials - except for
## the two colour-vision entries, which are exempt. This is the only place a request becomes a screen
## value, which is what stops a walk over requests from being scaled a second time per step.
func _dialled(entry: Dictionary) -> float:
	var asked: float = clampf(float(entry.get("strength", 0.0)), 0.0, 1.0)
	if UNDIALLED_EFFECTS.has(str(entry.get("effect", ""))):
		return asked
	return _allowed(asked)


## Remembers what one entry's row ASKED for and pushes it at the screen. The dials have their say in
## _apply, once, on the way to the shader.
func _write_strength(called: String, strength: float) -> void:
	var at: int = _find(called)
	if at < 0:
		return
	_stack[at]["strength"] = clampf(strength, 0.0, 1.0)
	_apply(at)


## Writes an entry's own dials - the vignette's colour, the grade's table, the letterbox's depth -
## and pushes them at the screen. A dial the shader does not declare is kept anyway: a look saved by
## a newer version of the pack should not lose what this one cannot draw.
func _write_params(called: String, dials: Dictionary) -> void:
	var at: int = _find(called)
	if at < 0 or dials.is_empty():
		return
	var held: Dictionary = _stack[at].get("params", {})
	for dial: Variant in dials:
		held[str(dial)] = dials[dial]
	_stack[at]["params"] = held
	_apply(at)


## Turns one entry on or off without forgetting how far up it was.
func _set_enabled(called: String, on: bool) -> void:
	var at: int = _find(called)
	if at < 0:
		return
	_stack[at]["enabled"] = on
	_apply(at)


## One of the two colour-vision entries, wearing a kind of vision - or gone, when the kind is normal.
## Both are UNDIALLED_EFFECTS, so the correction lands whole: a player who has turned the effect
## strength down, or asked for no flashing, still gets the colours told apart.
func _wear_vision(effect: String, vision: String, row_name: String) -> void:
	var kind: String = vision.strip_edges().to_lower()
	var which: int = VISION_KINDS.find(kind)
	if which < 0:
		push_warning("%s: no vision is called \"%s\" - the words are %s." % [
			row_name, vision, ", ".join(VISION_KINDS)])
		return
	if which == 0:
		remove_post_effect(effect)
		return
	if _find(effect) < 0:
		add_post_effect(effect, effect, 1.0)
	_write_params(effect, {VISION_DIAL: which})
	_write_strength(effect, 1.0)


## The stack as look rows: what Save Look writes and what Use Look reads back, in stack order. The
## strength recorded is the one the ROWS ASKED FOR, never the one one player's accessibility dials
## allowed at the moment of saving - otherwise a look saved under a half-strength dial would come
## back at a quarter, and one saved while no flashing was on would carry that ceiling for ever.
func _look_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for entry: Dictionary in _stack:
		rows.append({
			"called": str(entry.get("called", "")),
			"effect": str(entry.get("effect", "")),
			"strength": float(entry.get("strength", 0.0)),
			"params": (entry.get("params", {}) as Dictionary).duplicate(true)
		})
	return rows


## A look's rows, whatever it was made of - the pack's own resource class, or anything else carrying
## a `rows` array of the same shape. Read through `get` so this pack never has to name that class.
func _rows_of(look: Resource) -> Array:
	if look == null:
		return []
	var rows: Variant = look.get("rows")
	if rows is Array:
		return rows as Array
	return []


## The shader one effect wears, loaded once and kept. A project that only ever uses a vignette loads
## one file.
func _shader_for(effect: String) -> Shader:
	if _shaders.has(effect):
		return _shaders[effect] as Shader
	var path: String = POST_DIRECTORY + POST_PREFIX + effect.replace(" ", "_") + ".gdshader"
	var found: Shader = null
	if ResourceLoader.exists(path):
		found = load(path) as Shader
	else:
		push_warning("Screen FX has no shader file for the \"%s\" effect at %s." % [effect, path])
	_shaders[effect] = found
	return found


## Pushes one entry at the screen: the rectangle it is drawn on, the shader it wears, its strength
## and its own dials - and then the switch, because an entry at rest should not be drawn at all.
func _apply(at: int) -> void:
	if at < 0 or at >= _stack.size():
		return
	var entry: Dictionary = _stack[at]
	var rect: ColorRect = entry.get("rect", null) as ColorRect
	if rect == null or not is_instance_valid(rect):
		rect = ColorRect.new()
		rect.name = "Post" + str(entry.get("called", "")).capitalize().replace(" ", "")
		rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rect.material = ShaderMaterial.new()
		add_child(rect)
		entry["rect"] = rect
	var worn: ShaderMaterial = rect.material as ShaderMaterial
	if worn == null:
		return
	var shader: Shader = _shader_for(str(entry.get("effect", "")))
	if worn.shader != shader:
		worn.shader = shader
	var showing: float = _dialled(entry)
	if not bool(entry.get("enabled", true)):
		showing = 0.0
	worn.set_shader_parameter(STRENGTH_DIAL, showing)
	var dials: Dictionary = entry.get("params", {})
	for dial: Variant in dials:
		worn.set_shader_parameter(str(dial), dials[dial])
	rect.visible = shader != null and showing > 0.001


## Puts the rectangles back in stack order. Each one is moved to the end in turn, so the stack's own
## order becomes the tail of this layer's children - and the pack's Screen rectangle, which the six
## older verbs draw on, keeps its place underneath them all.
func _reorder() -> void:
	for entry: Dictionary in _stack:
		var rect: ColorRect = entry.get("rect", null) as ColorRect
		if rect != null and is_instance_valid(rect) and rect.get_parent() == self:
			move_child(rect, get_child_count() - 1)


## Ends the walk on one entry, if there is one, leaving it wherever it had got to.
func _stop_walk_on(called: String) -> void:
	var walk: Tween = _stack_walks.get(called, null)
	if walk != null and walk.is_valid():
		walk.kill()
	_stack_walks.erase(called)


## Walks one entry's strength - there, and optionally back - and takes it off the stack afterwards
## when it was only borrowed for a moment.
##
## WITH NO TREE TO RUN A TWEEN IN (a headless run, a layer built but not added yet) the walk lands on
## its final value at once, which is the same answer a moment later.
func _walk_strength(called: String, to_value: float, seconds: float, back_to: float, back_seconds: float, drop_after: bool) -> void:
	var at: int = _find(called)
	if at < 0:
		return
	_stop_walk_on(called)
	var ends_at: float = back_to if back_seconds > 0.0 else to_value
	if not is_inside_tree() or (seconds <= 0.0 and back_seconds <= 0.0):
		_write_strength(called, ends_at)
		if drop_after:
			remove_post_effect(called)
		return
	var walk: Tween = create_tween()
	if seconds > 0.0:
		walk.tween_method(func(value: float) -> void: _write_strength(called, value),
			float(_stack[at].get("strength", 0.0)), to_value, seconds)
	if back_seconds > 0.0:
		walk.tween_method(func(value: float) -> void: _write_strength(called, value),
			to_value, back_to, back_seconds)
	if drop_after:
		walk.finished.connect(func() -> void: remove_post_effect(called))
	_stack_walks[called] = walk
#endregion
