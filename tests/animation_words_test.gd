# The animations a scene really has, and what the sheet does with knowing.
#
# The claim held to account here is that an animation name stops being a string somebody types. The
# scene lists what exists - an AnimationPlayer's clips with their lengths, loop modes and named
# markers, an AnimatedSprite's flipbooks with their real frame counts - and everything downstream is
# derived from that list: the picker's entries, the autocomplete, the head band, the amber on a name
# nothing declares, and the note on a queue behind an animation that never ends.
#
# Values are pinned, never counts: "the reader found two sources" would pass on a reader that found
# the wrong two.
@tool
class_name AnimationWordsTest
extends RefCounted

const SCENE := "res://tests/fixtures/animation_scene_hero.tscn"
const SCRIPT := "res://tests/fixtures/animation_scene_hero.gd"
const MODULE := preload("res://addons/eventforge/registration/modules/animation_player_aces.gd")


static func run() -> bool:
	var ok: bool = true
	EventSheetSceneAnimations.clear_cache()
	EventSheetSceneLightingFacts.clear_cache()
	ok = _test_the_scene_lists_what_it_has() and ok
	ok = _test_a_keyframed_clip_has_markers_and_no_frames() and ok
	ok = _test_the_band_names_what_the_sheet_uses() and ok
	ok = _test_a_name_nothing_declares_goes_amber() and ok
	ok = _test_a_queue_behind_a_loop_is_caught() and ok
	ok = _test_the_rows_the_sheet_holds() and ok
	ok = _test_the_completions() and ok
	ok = _test_the_filmstrip_numbers_from_zero() and ok
	ok = _test_the_new_rows() and ok
	ok = _test_the_spellings_that_lift() and ok
	EventSheetSceneAnimations.clear_cache()
	EventSheetSceneLightingFacts.clear_cache()
	return ok


## Every source of the scene, and every animation on it, by value: the name, whether it loops, how
## long it runs and how many frames it has. A flipbook's length is its frames over its speed, which
## is the number a reader would work out by hand.
static func _test_the_scene_lists_what_it_has() -> bool:
	var read: Dictionary = {}
	for source: Dictionary in EventSheetSceneAnimations.for_scene(SCENE):
		var clips: Array = []
		for entry: Variant in (source["animations"] as Array):
			var animation: Dictionary = entry
			clips.append("%s %s %s %d" % [str(animation["name"]),
				"loop" if bool(animation["loop"]) else "once",
				String.num(float(animation["length"]), 2), int(animation["frames"])])
		read["%s %s" % [str(source["name"]), str(source["kind"])]] = clips
	return _check("the scene lists its animations, with their lengths and loops", read, {
		"Anim player": ["die once 0.5 -1", "idle loop 1.2 -1", "swing once 0.8 -1"],
		"Body frames": ["hurt once 0.6 3", "walk loop 1.0 8"],
	})


## What a keyframed clip has instead of frames: named moments on a timeline. A skeletal swing has no
## frame 3 to click, and the reading says so by answering -1 frames and naming the marker instead.
static func _test_a_keyframed_clip_has_markers_and_no_frames() -> bool:
	var sources: Array[Dictionary] = EventSheetSceneAnimations.for_scene(SCENE)
	var swing: Dictionary = EventSheetSceneAnimations.find(sources, "swing").get("animation", {})
	var walk: Dictionary = EventSheetSceneAnimations.find(sources, "&\"walk\"").get("animation", {})
	return _check("a keyframed clip answers with markers, a flipbook with frames", {
		"swing markers": swing.get("markers", []),
		"swing frames": swing.get("frames", 0),
		"walk markers": walk.get("markers", []),
		"walk frames": walk.get("frames", 0),
		"walk reads as": EventSheetSceneAnimations.reading(walk),
		"swing reads as": EventSheetSceneAnimations.reading(swing),
	}, {
		"swing markers": [{"name": "impact", "time": 0.35}],
		"swing frames": -1,
		"walk markers": [],
		"walk frames": 8,
		"walk reads as": "loop",
		"swing reads as": "0.8 s",
	})


## The band's own law: it names what the SHEET uses and counts the rest. A character with a hundred
## clips is still one line, because the band is about this sheet's claims on the scene.
static func _test_the_band_names_what_the_sheet_uses() -> bool:
	var bands: Array[Dictionary] = EventSheetSceneAnimations.bands(SCRIPT,
		PackedStringArray(["\"idle\"", "\"swing\""]))
	var read: Array = []
	for band: Dictionary in bands:
		read.append(str(band["value"]))
	return _check("the band spells what is used and counts the rest", {
		"bands": read,
		"echo": str(bands[0]["echo"]) if not bands.is_empty() else "",
	}, {
		"bands": ["uses idle loop · swing 0.8 s · 1 more in Anim", "2 in Body"],
		"echo": "animation_scene_hero.tscn: AnimationPlayer \"Anim\", 3 animations",
	})


## The whole reason the names are read at all: a row naming an animation the scene does not have
## plays nothing and reports nothing, so the band says so before the game runs - and the nearest
## real name is what the re-pick offers.
static func _test_a_name_nothing_declares_goes_amber() -> bool:
	var bands: Array[Dictionary] = EventSheetSceneAnimations.bands(SCRIPT,
		PackedStringArray(["\"walk\"", "\"atack\"", "\"attack_\" + weapon"]))
	var warned: Array = []
	for band: Dictionary in bands:
		if bool(band["warning"]):
			warned.append(str(band["value"]))
	return _check("a name the scene has never heard of is named, and a built one is not", {
		"warnings": warned,
		"nearest to atack": EventSheetSceneAnimations.nearest(
			EventSheetSceneAnimations.for_scene(SCENE), "atack"),
	}, {
		"warnings": ["atack is not an animation of this scene - the row plays nothing"],
		"nearest to atack": "",
	})


## `queue` waits for the current animation to FINISH, and a looping one never does. Caught from the
## scene, before the game runs, rather than as a mystery afterwards.
static func _test_a_queue_behind_a_loop_is_caught() -> bool:
	var bands: Array[Dictionary] = EventSheetSceneAnimations.bands(SCRIPT,
		PackedStringArray(["\"idle\"", "\"swing\""]), PackedStringArray(["\"idle\"", "\"swing\""]))
	var warned: Array = []
	for band: Dictionary in bands:
		if bool(band["warning"]):
			warned.append(str(band["value"]))
	return _check("a chain behind a looping animation is caught at authoring", warned,
		["idle loops - the queue never comes"])


## The walk behind the band: every value the sheet's rows hold in a field of one hint, with the row
## that holds it - one walk, so a fact about animations and a fact about groups cost the same.
static func _test_the_rows_the_sheet_holds() -> bool:
	var sheet: EventSheetResource = _sheet_playing(["\"idle\"", "\"swing\""])
	var entries: Array[Dictionary] = EventForgeSheetParamValues.of_hint(sheet, "animation_reference")
	var read: Array = []
	for entry: Dictionary in entries:
		read.append("%s.%s = %s" % [str(entry["ace_id"]), str(entry["param"]), str(entry["value"])])
	return _check("the walk finds every animation field of every row", {
		"entries": read,
		"distinct": EventForgeSheetParamValues.distinct(sheet, "animation_reference"),
	}, {
		"entries": ["PlayThenQueue.animation = \"idle\"", "PlayThenQueue.next = \"swing\""],
		"distinct": PackedStringArray(["\"idle\"", "\"swing\""]),
	})


## The same list, offered as you type. Names are inserted QUOTED, because an animation name is a
## string literal in every row that takes one.
static func _test_the_completions() -> bool:
	EventSheetCompletions.clear_cache()
	var sheet: EventSheetResource = _sheet_playing([])
	var read: Array = []
	for entry: Dictionary in EventSheetCompletions.for_field(sheet,
			EventSheetCompletions.FIELD_ANIMATION, "wa"):
		read.append("%s %s" % [str(entry["text"]), str(entry["detail"])])
	var markers: Array = []
	for entry: Dictionary in EventSheetCompletions.for_field(sheet,
			"%s:swing" % EventSheetCompletions.FIELD_MARKER, ""):
		markers.append("%s %s" % [str(entry["text"]), str(entry["detail"])])
	EventSheetCompletions.clear_cache()
	return _check("the field completes with what the scene has", {
		"animations": read,
		"markers": markers,
	}, {
		"animations": ["\"walk\" loop · Body"],
		"markers": ["\"impact\" 0.35 s into swing"],
	})


## The filmstrip's model: one cell per frame, numbered from 0 the way Godot numbers them, and
## nothing at all for a clip that has no frames - which is what keeps a frame field off a keyframed
## animation, where it would be a lie.
static func _test_the_filmstrip_numbers_from_zero() -> bool:
	var sources: Array[Dictionary] = EventSheetSceneAnimations.for_scene(SCENE)
	var hurt: Dictionary = EventSheetSceneAnimations.find(sources, "hurt").get("animation", {})
	var swing: Dictionary = EventSheetSceneAnimations.find(sources, "swing").get("animation", {})
	var labels: Array = []
	var lit: int = -1
	for cell: Dictionary in EventSheetFrameStrip.cells_for(hurt, 2):
		labels.append(str(cell["label"]))
		if bool(cell["selected"]):
			lit = int(cell["frame"])
	return _check("the strip is the frames, from 0, and a keyframed clip has none", {
		"labels": labels,
		"selected": lit,
		"keyframed": EventSheetFrameStrip.cells_for(swing, 0),
		"eight fit": EventSheetFrameStrip.scrolls(8),
		"sixty scroll": EventSheetFrameStrip.scrolls(60),
	}, {
		"labels": ["0", "1", "2"],
		"selected": 2,
		"keyframed": [] as Array[Dictionary],
		"eight fit": false,
		"sixty scroll": true,
	})


## The two rows this wave adds, by the line each one compiles to. An ace_id and a template are a
## compatibility promise the moment they ship.
static func _test_the_new_rows() -> bool:
	var templates: Dictionary = {}
	for descriptor: ACEDescriptor in MODULE.get_descriptors():
		if descriptor.ace_id == "PlayThenQueue" or descriptor.ace_id == "AnimationPastMarker":
			templates[descriptor.ace_id] = descriptor.codegen_template
	return _check("the chain row and the marker row write what they say", templates, {
		"PlayThenQueue": "play(&{animation})\nqueue(&{next})",
		"AnimationPastMarker": "{target.}current_animation == {animation} and {target.}current_animation_position >= {target.}get_animation({animation}).get_marker_time({marker})",
	})


## The spellings a project already holds. The shipped templates write one form of each call and
## everybody's habit is the other, so both open as the row they mean, with the author's own bytes
## kept (the lift-table harness proves the round trip; what is pinned here is WHICH row).
static func _test_the_spellings_that_lift() -> bool:
	var read: Dictionary = {}
	for line: String in ["$Anim.play(\"attack\")", "queue(&\"idle\")", "play(&\"attack\")"]:
		var matched: Dictionary = EventForgeAnimationLift.match_line(line)
		read[line] = "%s %s" % [str(matched.get("ace_id", "-")), str(matched.get("template", "-"))]
	return _check("the other spelling of play and queue opens as the row it means", read, {
		"$Anim.play(\"attack\")": "PlayAnimation {target.}play({anim_name})",
		"queue(&\"idle\")": "QueueAnimation {target.}queue({animation})",
		"play(&\"attack\")": "- -",
	})


## A sheet whose one row plays the given animations - the smallest thing the walk above can be
## asked about, pointed at the fixture scene so the scene readings have something to read.
static func _sheet_playing(names: Array) -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.external_source_path = SCRIPT
	if names.is_empty():
		return sheet
	var event_row: EventRow = EventRow.new()
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = "PlayThenQueue"
	action.params = {"animation": str(names[0]), "next": str(names[1])}
	event_row.actions.append(action)
	sheet.events.append(event_row)
	return sheet


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] animation_words_test: %s" % label)
		return true
	print("[FAIL] animation_words_test: %s" % label)
	print("  expected: %s" % expected)
	print("  actual:   %s" % actual)
	return false
