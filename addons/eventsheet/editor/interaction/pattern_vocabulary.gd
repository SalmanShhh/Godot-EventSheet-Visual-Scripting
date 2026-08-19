# Godot EventSheets - THE WORDS for the patterns the readings claim.
#
# EventSheetPatternFacts records THAT an event reads as a pattern; this says what that pattern is
# CALLED, the one line that explains it, which shipped behavior could replace a hand-written one,
# and where its page lives in the Manual. Everything user-facing about a pattern - the ⟡ chip, the
# hover line, the Adopt behavior menu item, the Doctor's notes, the Common Game Patterns page, the
# Add ▸ Pattern list - takes its words from here, so the same pattern is never called two things.
#
# The fixture folder is the other half of the contract. Each pattern that has a page owns one
# hand-written .gd file under `tests/fixtures/patterns/`; the reading tests open it, the Manual page
# is generated from it, and Add ▸ Pattern inserts it. A shape the sheet cannot read therefore cannot
# reach a reader: it would fail its own test first.
@tool
class_name EventSheetPatternVocabulary
extends RefCounted

## Where a pattern's hand-written shape lives. One file per pattern id that has a page, named
## `<pattern_id>.gd`, holding the smallest complete example of the shape - the exact text the Manual
## page prints in its HAND-WRITTEN column and Add ▸ Pattern inserts.
const FIXTURE_DIR := "res://tests/fixtures/patterns"

## pattern id -> {words, why, adoptable, rank}.
##   words     the chip's name for it, in the sheet's own vocabulary
##   why       the one line the hover and the Manual page lead with
##   adoptable the shipped behavior/module id a hand-written shape could be swapped for, "" for none
##   rank      how common it is; Add ▸ Pattern shows the ten lowest ranks first in Simple mode
##
## Keyed on EventSheetPatternFacts.PATTERN_IDS, which is frozen - so this table gains rows and never
## renames one.
const ENTRIES: Dictionary = {
	"countdown": {
		"words": "Cooldown",
		"why": "a number counted down every tick, with something that happens when it reaches zero",
		"adoptable": "core_cooldown",
		"rank": 1
	},
	"state_machine": {
		"words": "State machine",
		"why": "one value says what something is doing, and every event asks it first",
		"adoptable": "state_machine",
		"rank": 2
	},
	"object_pool": {
		"words": "Object pool",
		"why": "objects are kept and reused instead of created and destroyed",
		"adoptable": "object_pool",
		"rank": 3
	},
	"wait_sequence": {
		"words": "Wait sequence",
		"why": "steps that run one after another with a wait between them",
		"adoptable": "",
		"rank": 4
	},
	"local_storage": {
		"words": "Save / load",
		"why": "values written to a file and read back the next time the game runs",
		"adoptable": "save_system",
		"rank": 5
	},
	"movement": {
		"words": "Movement",
		"why": "gravity, acceleration, a speed limit and a move, every tick",
		"adoptable": "platformer",
		"rank": 6
	},
	"ui": {
		"words": "UI",
		"why": "something on screen follows a value, or is shown and hidden",
		"adoptable": "",
		"rank": 7
	},
	"sound": {
		"words": "Sound",
		"why": "a sound is chosen, tuned and played",
		"adoptable": "",
		"rank": 8
	},
	"juice": {
		"words": "Juice",
		"why": "a short push on position, scale, tint or time that makes a hit feel like one",
		"adoptable": "juice",
		"rank": 9
	},
	"camera": {
		"words": "Camera",
		"why": "the view follows something, inside limits, at a zoom",
		"adoptable": "camera_kit",
		"rank": 10
	},
	"existence": {
		"words": "Existence",
		"why": "something is checked for being there before it is used",
		"adoptable": "",
		"rank": 11
	},
	"background_loading": {
		"words": "Loading screen",
		"why": "a scene is loaded in the background while a bar shows how far it got",
		"adoptable": "scene_flow",
		"rank": 12
	},
	"multiplayer": {
		"words": "Multiplayer",
		"why": "messages sent to the host or to everyone, and who owns what",
		"adoptable": "",
		"rank": 13
	},
	"sprite_animation": {
		"words": "Sprite animation",
		"why": "a frame, a speed, a mirrored look and an animation that is playing",
		"adoptable": "",
		"rank": 14
	},
	"navigation": {
		"words": "Navigation",
		"why": "a destination, the next waypoint toward it, and arriving",
		"adoptable": "nav_agent",
		"rank": 15
	},
	"effects": {
		"words": "Effects",
		"why": "a shader parameter set, tweened or removed",
		"adoptable": "",
		"rank": 16
	},
	"tilemap": {
		"words": "Tilemap",
		"why": "tiles read and written by position",
		"adoptable": "",
		"rank": 17
	},
	"blank_event": {
		"words": "Every tick",
		"why": "an event with no condition of its own, so it runs every tick",
		"adoptable": "",
		"rank": 18
	}
}

## Adoptable id -> the shipped behavior's name, as the Adopt behavior item and the "could adopt"
## line say it. An id with no row here is shown by its id, which is a bug worth seeing rather than
## hiding.
const PACK_LABELS: Dictionary = {
	"core_cooldown": "Cooldown",
	"state_machine": "State Machine",
	"object_pool": "ObjectPool",
	"save_system": "Save System",
	"platformer": "Platformer",
	"juice": "Juice",
	"camera_kit": "Camera",
	"scene_flow": "Scene Flow",
	"nav_agent": "Nav Agent"
}


## The pattern's name in the reader's language, or "" when the id is not one this table knows.
static func words(pattern: String) -> String:
	if not ENTRIES.has(pattern):
		return ""
	return EventSheetL10n.translate(str((ENTRIES[pattern] as Dictionary).get("words", "")))


## The one line the ⟡ hover leads with, in the reader's language.
static func why(pattern: String) -> String:
	if not ENTRIES.has(pattern):
		return ""
	return EventSheetL10n.translate(str((ENTRIES[pattern] as Dictionary).get("why", "")))


## The shipped behavior a hand-written instance of this pattern could be swapped for, "" for none.
## This is the PATTERN's default; `adoptable_for` is what anything holding a claim should ask.
static func adoptable(pattern: String) -> String:
	if not ENTRIES.has(pattern):
		return ""
	return str((ENTRIES[pattern] as Dictionary).get("adoptable", ""))


## The behavior a CLAIM could be swapped for. The claim's own answer wins, because a reading knows
## whether the shape it actually saw is replaceable; when it did not say, the pattern's default
## stands in, so a shipped behavior is still offered while the reading that recognises the shape
## catches up to naming it. "" when neither has one.
##
## Everything that offers, counts or lists an adoption asks THIS - the row menu, the Object bar, the
## coverage chip, the Doctor's note - so the offer and the count can never disagree.
static func adoptable_for(claim: Dictionary) -> String:
	var named: String = str(claim.get("adoptable", ""))
	if not named.is_empty():
		return named
	return adoptable(str(claim.get("pattern", "")))


## What to call a behavior in a sentence about adopting it.
static func pack_label(adoptable_id: String) -> String:
	if adoptable_id.is_empty():
		return ""
	if not PACK_LABELS.has(adoptable_id):
		return adoptable_id
	return EventSheetL10n.translate(str(PACK_LABELS[adoptable_id]))


## Every pattern id this table knows, most common first - the order Add ▸ Pattern lists them in.
static func ranked_ids() -> PackedStringArray:
	var ordered: Array = ENTRIES.keys()
	ordered.sort_custom(func(a: Variant, b: Variant) -> bool:
		return int((ENTRIES[a] as Dictionary).get("rank", 99)) < int((ENTRIES[b] as Dictionary).get("rank", 99)))
	var out: PackedStringArray = PackedStringArray()
	for entry: Variant in ordered:
		out.append(str(entry))
	return out


## The hand-written shape of a pattern, as the fixture file holds it - "" when the pattern has no
## fixture yet, which is exactly the patterns the Manual page and Add ▸ Pattern must not offer.
static func fixture_source(pattern: String) -> String:
	var path: String = "%s/%s.gd" % [FIXTURE_DIR, pattern]
	if not FileAccess.file_exists(path):
		return ""
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	return file.get_as_text()


## The pattern ids that HAVE a fixture, in rank order - what the Manual page prints, what
## Add ▸ Pattern offers, and nothing beyond it.
static func documented_ids() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for pattern: String in ranked_ids():
		if not fixture_source(pattern).is_empty():
			out.append(pattern)
	return out
