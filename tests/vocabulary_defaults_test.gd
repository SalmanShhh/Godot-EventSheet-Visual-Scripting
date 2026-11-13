@tool
class_name VocabularyDefaultsTest
extends RefCounted

# EventForge - the Godot-words-by-default contract.
#
# Everything a reader sees by default is Godot's own word; the words other event-sheet editors use
# survive in exactly two places - the picker's search, and the opt-in Familiar preset on the Words
# page. Four promises:
#   1. the default vocabulary is the Godot preset, for a reader who never chose;
#   2. every lifecycle and tick reading says Godot's callback name by default and the other
#      editors' word in the Familiar preset;
#   3. typing EITHER word finds the same row in the picker;
#   4. no default string a reader meets uses "layout" to mean a scene, or "every tick" for a frame;
#   5. the nouns and verbs (queue free, instantiate, rotation, overlaps, body entered, opacity) read
#      Godot's word by default and the other editors' word in the Familiar preset, on the rows a
#      reader meets and on the hover;
#   6. an exact alias phrase ranks its row first.

const SUPPORT := preload("res://tests/support.gd")

## Where "layout" means something other than a scene: a Control or UI layout, an audio bus layout, an
## anchors preset, text direction, and the sheet's own canvas layout. Every entry is a phrase that
## may appear inside a user-visible string.
const LAYOUT_ALLOWED: PackedStringArray = [
	"bus layout", "layout preset", "Mirror Layout", "Layout Is Mirrored", "layout is mirrored",
	"Reset Layout", "layout direction", "layout for the language", "laid out", "layout of the",
	"settings-file layout", "Control layout", "the layout the", "keyboard layout", "grid layout",
	"layout mode", "page layout", "container layout", "UI layout", "the layout of",
	"layout view", "layout to X", "Layout To X", "layout change", "layout_", "Layout Edges stay",
	"branch layouts", "console layouts", "layout by", "layout with", "layouts on", "layout and",
	"layout, ", "layout engine", "layout pass", "buses the current layout", "a layout that overflows",
	"Layout preset",
]

## Whole strings that are the engine's own Control "Layout" group heading in an Inspector.
const LAYOUT_ALLOWED_EXACT: PackedStringArray = ["Layout"]


static func run() -> bool:
	var ok: bool = true
	ok = _default_is_godot() and ok
	ok = _callbacks_read_both_ways() and ok
	ok = _search_finds_both_words() and ok
	ok = _no_default_says_layout_for_a_scene() and ok
	ok = _no_default_says_every_tick() and ok
	ok = _nouns_and_verbs_read_both_ways() and ok
	ok = _hover_names_the_other_word_and_the_godot_call() and ok
	ok = _search_finds_the_new_words_and_ranks_phrases_first() and ok
	return ok


## 1. A reader who never chose is on the Godot preset, and the Welcome answers switch nobody.
static func _default_is_godot() -> bool:
	var ok: bool = SUPPORT.check("vocabulary_defaults_test", "the default preset is Godot's",
		EventSheetWords.preset(), EventSheetWords.PRESET_GODOT)
	for choice: String in EventSheetWelcomeWindow.CAME_FROM_CHOICES:
		ok = SUPPORT.check("vocabulary_defaults_test", "the Welcome answer '%s' sets the Godot words" % choice,
			EventSheetWelcomeWindow.choice_settings(choice)["words"], EventSheetWords.PRESET_GODOT) and ok
	return ok


## 2. The lifecycle and tick readings, per preset.
static func _callbacks_read_both_ways() -> bool:
	var rows: Array = []
	for pair: Array in [
		["OnProcess", "On process", "Every tick"],
		["OnPhysicsProcess", "On physics process", "Every physics tick"],
	]:
		rows.append(["%s, Godot" % pair[0], EventSheetViewportReadingRows.tick_trigger_words(str(pair[0]), "", false), pair[1]])
		rows.append(["%s, Familiar" % pair[0], EventSheetViewportReadingRows.tick_trigger_words(str(pair[0]), "", true), pair[2]])
	for entry: Array in [
		["OnReady", true, "On ready", "On start of layout"],
		["OnReady", false, "On ready", "On ready"],
		["OnEnterTree", false, "On enter tree", "On created"],
		["OnExitTree", true, "On exit tree", "On end of layout"],
		["OnExitTree", false, "On exit tree", "On destroyed"],
	]:
		var godot: Dictionary = EventSheetViewportReadingRows.lifecycle_trigger_reading(
			str(entry[0]), "X", bool(entry[1]), "Player", false)
		var familiar: Dictionary = EventSheetViewportReadingRows.lifecycle_trigger_reading(
			str(entry[0]), "X", bool(entry[1]), "Player", true)
		rows.append(["%s scene root %s, Godot" % [entry[0], entry[1]], str(godot.get("text", "")), entry[2]])
		rows.append(["%s scene root %s, Familiar" % [entry[0], entry[1]], str(familiar.get("text", "")), entry[3]])
	var ok: bool = true
	for row: Array in rows:
		ok = SUPPORT.check("vocabulary_defaults_test", str(row[0]), row[1], row[2]) and ok
	# The Words page lists them, so it controls them.
	for key: String in ["scene_ready", "scene_exit", "node_enter", "node_exit", "every_tick", "every_physics_tick"]:
		ok = SUPPORT.check("vocabulary_defaults_test", "the Words page lists %s" % key,
			EventSheetWords.keys().has(key), true) and ok
	return ok


## 3. Either word reaches the row: the Godot word through the row's own name, the other editor's
## through the synonym table or the alias table.
static func _search_finds_both_words() -> bool:
	var registry: EventSheetACERegistry = EventSheetACERegistry.new()
	registry.refresh_from_sources([], true)
	var ok: bool = true
	for entry: Array in [
		["OnReady", ["on ready", "on start of layout", "start of scene"]],
		["OnProcess", ["on process", "every tick", "every frame"]],
		["OnPhysicsProcess", ["on physics process", "every physics tick"]],
		["OnEnterTree", ["on enter tree", "on created"]],
		["OnExitTree", ["on exit tree", "on destroyed", "on end of layout"]],
		["ChangeScene", ["change scene", "go to layout", "goto layout"]],
		["ReloadScene", ["reload scene", "restart layout"]],
		["QueueFree", ["queue free", "destroy"]],
	]:
		var definition: ACEDefinition = registry.find_definition("Core", str(entry[0]))
		if definition == null:
			ok = SUPPORT.check("vocabulary_defaults_test", "%s is registered" % entry[0], false, true) and ok
			continue
		for query: String in (entry[1] as Array):
			ok = SUPPORT.check("vocabulary_defaults_test", "typing '%s' finds %s" % [query, entry[0]],
				_finds(query, definition), true) and ok
	return ok


static func _finds(query: String, definition: ACEDefinition) -> bool:
	if ACEPickerDialog._score_match(query, definition) > 0:
		return true
	for mapped: String in ACEPickerDialog._c3_synonym_queries(query):
		if ACEPickerDialog._score_match(mapped, definition) > 0:
			return true
	return ACEPickerDialog.alias_query_keys(query).has("%s::%s" % [definition.provider_id, definition.id])


## 4. No default string says layout for a scene. Two sweeps: every shipped descriptor's wording, and
## every literal handed to translate() in the editor and the compiler's own sources.
static func _no_default_says_layout_for_a_scene() -> bool:
	var offenders: PackedStringArray = PackedStringArray()
	var pattern: RegEx = RegEx.create_from_string("(?i)\\blayouts?\\b")
	for descriptor: ACEDescriptor in ACERegistry.get_builtin_descriptors():
		var strings: PackedStringArray = [descriptor.display_name, descriptor.list_name, descriptor.description]
		for param: ACEParam in descriptor.params:
			strings.append(param.display_name)
			strings.append(param.description)
		for text: String in strings:
			if _says_layout_for_a_scene(pattern, text):
				offenders.append("%s: %s" % [descriptor.ace_id, text.left(60)])
	var call_pattern: RegEx = RegEx.create_from_string("translate\\(\"((?:[^\"\\\\]|\\\\.)*)\"")
	for root: String in ["res://addons/eventsheet", "res://addons/eventforge"]:
		for path: String in _gd_files(root):
			var source: String = FileAccess.get_file_as_string(path)
			if not source.to_lower().contains("layout"):
				continue
			for found: RegExMatch in call_pattern.search_all(source):
				if _says_layout_for_a_scene(pattern, found.get_string(1)):
					offenders.append("%s: %s" % [path.get_file(), found.get_string(1).left(60)])
	return SUPPORT.check("vocabulary_defaults_test", "no default string says layout for a scene",
		offenders, PackedStringArray())


static func _says_layout_for_a_scene(pattern: RegEx, text: String) -> bool:
	if pattern.search(text) == null:
		return false
	if LAYOUT_ALLOWED_EXACT.has(text):
		return false
	for allowed: String in LAYOUT_ALLOWED:
		if text.contains(allowed):
			return false
	return true


static func _gd_files(root: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for name: String in DirAccess.get_files_at(root):
		if name.ends_with(".gd"):
			out.append("%s/%s" % [root, name])
	for sub: String in DirAccess.get_directories_at(root):
		out.append_array(_gd_files("%s/%s" % [root, sub]))
	return out


## Strings that may say "every tick" in a default: the sentence that tells a reader what the OTHER
## editors call a callback, or a phrase that quotes a typed example.
const EVERY_TICK_ALLOWED: PackedStringArray = [
	"Every tick, Destroy, Angle", "(e.g. every tick", "every tick, heal", "After Every Physics Tick", "Run after every physics tick",
]


## 4b. No default says "every tick" for a frame. Same two sweeps as the layout one.
static func _no_default_says_every_tick() -> bool:
	var offenders: PackedStringArray = PackedStringArray()
	var pattern: RegEx = RegEx.create_from_string("(?i)\\bevery (physics )?tick\\b")
	for descriptor: ACEDescriptor in ACERegistry.get_builtin_descriptors():
		var strings: PackedStringArray = [descriptor.display_name, descriptor.list_name, descriptor.get_display_text()]
		for text: String in strings:
			if pattern.search(text) != null and not _allowed_tick(text):
				offenders.append("%s: %s" % [descriptor.ace_id, text.left(60)])
	var call_pattern: RegEx = RegEx.create_from_string("translate\\(\"((?:[^\"\\\\]|\\\\.)*)\"")
	for root: String in ["res://addons/eventsheet", "res://addons/eventforge"]:
		for path: String in _gd_files(root):
			var source: String = FileAccess.get_file_as_string(path)
			var lowered: String = source.to_lower()
			if not lowered.contains("every tick") and not lowered.contains("every physics tick"):
				continue
			for found: RegExMatch in call_pattern.search_all(source):
				var text: String = found.get_string(1)
				if pattern.search(text) != null and not _allowed_tick(text):
					offenders.append("%s: %s" % [path.get_file(), text.left(60)])
	return SUPPORT.check("vocabulary_defaults_test", "no default string says every tick for a frame",
		offenders, PackedStringArray())


static func _allowed_tick(text: String) -> bool:
	for allowed: String in EVERY_TICK_ALLOWED:
		if text.contains(allowed):
			return true
	return false


## The context an opened CharacterBody2D script called Player produces, for the readings below.
const _CONTEXT: Dictionary = {
	"self_object": "System",
	"script_object": "Player",
	"owner": "Player",
	"signals": {},
	"engine_properties": {"position": true, "visible": true, "rotation_degrees": true, "rotation": true},
	"object_classes": {"Player": "CharacterBody2D", "hurtbox": "Area2D"}
}


static func _statement(code: String) -> String:
	return _joined(EventSheetSentence.statement(code, _CONTEXT))


static func _condition(code: String) -> String:
	return _joined(EventSheetSentence.condition(code, _CONTEXT))


static func _joined(result: Dictionary) -> String:
	var text: String = ""
	for segment: Variant in (result.get("segments", []) as Array):
		text += str((segment as Dictionary).get("text", ""))
	return text


## 5. Each noun and verb the slice touched, per preset: the Words table, the shipped names, the alias
## rows, and the reading of the code a reader may have written.
static func _nouns_and_verbs_read_both_ways() -> bool:
	var ok: bool = true
	for entry: Array in [
		["destroy", "Queue free", "Destroy"],
		["instantiate", "Instantiate", "Spawn a copy of"],
		["angle", "rotation", "angle"],
		["overlaps", "Overlaps", "Is overlapping"],
		["body_entered", "On body entered", "On collision with"],
		["body_exited", "On body exited", "On stopped overlapping"],
		["opacity", "Opacity", "Opacity"],
		["group", "Group", "Family (group)"],
	]:
		ok = SUPPORT.check("vocabulary_defaults_test", "%s reads %s in Godot's preset" % [entry[0], entry[1]],
			EventSheetWords.word_for(str(entry[0]), false, {}), entry[1]) and ok
		ok = SUPPORT.check("vocabulary_defaults_test", "%s reads %s in the Familiar preset" % [entry[0], entry[2]],
			EventSheetWords.word_for(str(entry[0]), true, {}), entry[2]) and ok
	for entry: Array in [
		["SpawnNewCopy", "Instantiate"],
		["SpawnNewCopyDeferred", "Instantiate Safely"],
		["SpawnFormation", "Instantiate In A Formation"],
		["SpawnCopyOfSelf", "Instantiate Myself"],
		["SpawnInFreeSpot", "Instantiate In A Free Spot"],
		["SpawnSceneAt", "Instantiate Scene At"],
		["DestroyNow", "Queue Free Now"],
		["DestroyAfterSeconds", "Queue Free After Seconds"],
		["FadeOutAndDestroy", "Fade Out Then Queue Free"],
		["QueueFree", "Queue Free"],
		["OverlapsBody", "Overlaps Body"],
		["OverlapsArea", "Overlaps Area"],
		["IsOverlappingAtOffset", "Overlaps At Offset"],
		["OnCollisionWithGroup", "On Body Entered, In Group"],
		["OnStoppedCollidingWithGroup", "On Body Exited, In Group"],
		["OnOverlapWithGroup", "On Body Entered, In Group"],
		["OnOverlapEndedWithGroup", "On Body Exited, In Group"],
		["IsTouchingGroup", "Overlaps Group"],
		["SetRotationDeg", "Set Rotation (Degrees)"],
	]:
		var descriptor: ACEDescriptor = ACERegistry.find_descriptor("Core", str(entry[0]))
		ok = SUPPORT.check("vocabulary_defaults_test", "%s is named %s by default" % [entry[0], entry[1]],
			descriptor.display_name if descriptor != null else "(missing)", entry[1]) and ok
	for entry: Array in [
		["Core::QueueFree", "Queue free", "Destroy"],
		["Core::DestroyNow", "queue free x now", "destroy x now"],
		["Core::SpawnNewCopy", "Instantiate [b]Bullet[/b] as b", "Spawn a copy of [b]Bullet[/b] as b"],
		["Core::SpawnFormation", "Instantiate 5 copies", "Spawn 5 copies"],
		["Core::OverlapsBody", "overlaps x", "is overlapping x"],
		["Core::OnCollisionWithGroup", "On body entered, in group x", "On collision with x"],
		["Core::OnStoppedCollidingWithGroup", "On body exited, in group x", "On stopped colliding with x"],
		["Core::SetRotationDeg", "Set rotation to 5", "Set angle to 5"],
	]:
		ok = SUPPORT.check("vocabulary_defaults_test", "%s keeps the Godot sentence by default" % entry[0],
			EventSheetWords.verb_row_words_for(str(entry[0]), str(entry[1]), false), entry[1]) and ok
		ok = SUPPORT.check("vocabulary_defaults_test", "%s reads the other editors' sentence in the Familiar words" % entry[0],
			EventSheetWords.verb_row_words_for(str(entry[0]), str(entry[1]), true), entry[2]) and ok
	var codes: Array = [
		["queue_free()", "Queue free", "Destroy"],
		["call_deferred(\"queue_free\")", "Queue free (at end of frame)", "Destroy (at end of frame)"],
		["look_at(target.global_position)", "Set rotation toward target.global_position", "Set angle toward target.global_position"],
		["set_process(true)", "Set process enabled", "Set process enabled"],
	]
	var godot_rows: Array = []
	for pair: Array in codes:
		godot_rows.append(_statement(str(pair[0])))
	var godot_condition: String = _condition("hurtbox.overlaps_body(other)")
	var godot_member: String = EventSheetSentence.engine_member_name("rotation_degrees")
	EventSheetWords.apply_preset(EventSheetWords.PRESET_FAMILIAR)
	var familiar_rows: Array = []
	for pair: Array in codes:
		familiar_rows.append(_statement(str(pair[0])))
	var familiar_condition: String = _condition("hurtbox.overlaps_body(other)")
	var familiar_member: String = EventSheetSentence.engine_member_name("rotation_degrees")
	EventSheetWords.forget_session()
	for index: int in range(codes.size()):
		var pair: Array = codes[index]
		ok = SUPPORT.check("vocabulary_defaults_test", "`%s` reads in Godot's words by default" % pair[0],
			godot_rows[index], pair[1]) and ok
		ok = SUPPORT.check("vocabulary_defaults_test", "`%s` reads in the Familiar words" % pair[0],
			familiar_rows[index], pair[2]) and ok
	ok = SUPPORT.check("vocabulary_defaults_test", "an overlap test says Overlaps by default",
		godot_condition, "Overlaps other") and ok
	ok = SUPPORT.check("vocabulary_defaults_test", "and Is overlapping in the Familiar preset",
		familiar_condition, "Is overlapping other") and ok
	ok = SUPPORT.check("vocabulary_defaults_test", "the rotation property reads rotation by default",
		godot_member, "rotation") and ok
	ok = SUPPORT.check("vocabulary_defaults_test", "and angle in the Familiar preset",
		familiar_member, "angle") and ok
	var godot_preview: String = "%s %s" % [EventSheetWords.word_for("destroy", false, {}),
		EventSheetWords.word_for("instantiate", false, {})]
	ok = SUPPORT.check("vocabulary_defaults_test", "the Words page preview shows neither Destroy nor Spawn under the Godot preset",
		godot_preview.contains("Destroy") or godot_preview.contains("Spawn"), false) and ok
	return ok


## 5b. The hover names the other editors' word under the Godot preset, Godot's under the Familiar
## one, and the Godot call or property the word writes.
static func _hover_names_the_other_word_and_the_godot_call() -> bool:
	var ok: bool = true
	for row: Array in [
		["On process", false, "Other event-sheet editors call this Every tick.\nThe _process callback."],
		["Every tick", true, "Godot calls this On process.\nThe _process callback."],
		["Queue free", false, "Other event-sheet editors call this Destroy.\nGodot writes this as queue_free()."],
		["Destroy", true, "Godot calls this Queue free.\nGodot writes this as queue_free()."],
		["Opacity", false, "Godot writes this as modulate.a."],
		["rotation", false, "Other event-sheet editors call this angle.\nGodot writes this as rotation_degrees."],
	]:
		ok = SUPPORT.check("vocabulary_defaults_test", "the hover on '%s' (familiar %s)" % [row[0], row[1]],
			EventSheetWords.glossary_hover_for(str(row[0]), bool(row[1]), {}), row[2]) and ok
	return ok


## 6. Either word finds the row, and a whole alias phrase ranks its row FIRST: the picker puts the
## rows a whole phrase names at the front of the list, whatever else shares a word with the query.
static func _search_finds_the_new_words_and_ranks_phrases_first() -> bool:
	var registry: EventSheetACERegistry = EventSheetACERegistry.new()
	registry.refresh_from_sources([], true)
	var ok: bool = true
	for entry: Array in [
		["SpawnNewCopy", ["instantiate", "spawn", "create object"]],
		["CloneInto", ["clone object"]],
		["DuplicateNode", ["clone object"]],
		["SetRotationDeg", ["set rotation", "set angle", "angle"]],
		["OverlapsBody", ["overlaps", "is overlapping"]],
		["OnCollisionWithGroup", ["on body entered", "on collision with", "on collision"]],
		["DestroyNow", ["queue free now", "destroy now"]],
		["ForEachChildOf", ["for each", "pick"]],
	]:
		var definition: ACEDefinition = registry.find_definition("Core", str(entry[0]))
		if definition == null:
			ok = SUPPORT.check("vocabulary_defaults_test", "%s is registered" % entry[0], false, true) and ok
			continue
		for query: String in (entry[1] as Array):
			ok = SUPPORT.check("vocabulary_defaults_test", "typing '%s' finds %s" % [query, entry[0]],
				_finds(query, definition), true) and ok
	var every_row: Array[ACEDefinition] = registry.get_all_definitions()
	for phrase: String in ACEPickerDialog.PHRASE_FIRST:
		var wanted: String = str(ACEPickerDialog.PHRASE_FIRST[phrase])
		var ranked: Array[ACEDefinition] = ACEPickerDialog.with_phrase_hits_first(every_row, phrase)
		var top: String = "" if ranked.is_empty() else "%s::%s" % [ranked[0].provider_id, ranked[0].id]
		ok = SUPPORT.check("vocabulary_defaults_test", "'%s' ranks %s first" % [phrase, wanted], top, wanted) and ok
	return ok
