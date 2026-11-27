# Pack builder - moment_resource (a data-driven Custom Resource; run via build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")


## MomentResource: one felt beat of a game as a file.
##
## A moment is the little burst of feedback a game gives when something happens - the shake and the
## freeze and the flash of a hit, the swell of a win, the colour draining out as the health bar goes
## red. Every game writes those by hand, four or five rows at a time, and every game writes them
## slightly differently in each of the ten places a hit can land.
##
## A moment is that burst written down ONCE: a list of steps, each step one word plus how much and
## how long. The Juice pack plays one with a single row - Moment "impact" - and scales every amount
## in it by one number, so a light hit and a heavy hit are the same moment at two strengths.
##
## NOTHING HERE IS A HOUSE STYLE. The plugin ships six starter files under the Juice pack folder
## because a jam does not have time to author its first moment, and every one of them is an ordinary
## resource: rename it, retune it in the Inspector, duplicate it, delete it, or ignore them all and
## build your own with Define Moment. There is no dropdown of named moments anywhere in the editor,
## and the plugin has no idea which moments a game holds.
##
## The steps are a plain array of dictionaries rather than a resource class per step, because a
## moment is data a person reads and edits: `{"verb": "shake", "amount": 0.4, "effect": "",
## "seconds": 0.0}` says the whole of one step in a form that survives being copied into a message.
static func build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Resource"
	sheet.custom_class_name = "MomentResource"
	sheet.class_description = "One felt beat of a game as a file: the steps a hit, a kill, a win, a danger or a calm is made of, each one a word plus how much and how long. Play it with the Juice pack's Moment row, which scales every amount by one number. It is your file - rename it, retune it in the Inspector, share it."
	sheet.variables = {
		"moment_name": {"type": "String", "default": "", "exported": true,
			"attributes": {"tooltip": "Name this moment is played by.",
				"header": "Moment", "header_color": "#e8a33d",
				"info": "One entry in Steps per thing that happens, in order. The words are shake, hitstop, slowmo, flash, punch, zoom, shockwave, chromatic, pulse and hold; pulse and hold also take the name of a post effect."}},
		"steps": {"type": "Array[Dictionary]", "default": [], "exported": true,
			"attributes": {"tooltip": "Steps in order: each has a step word, amount, effect and seconds."}}
	}
	var saved: bool = Lib.save_pack(sheet, "res://eventsheet_addons/moment_resource/moment_resource")
	return build_juice_list() and saved


## JuiceList: the whole card list of a Juice Player as a file.
##
## A moment file holds the ten moment words and four keys a step is made of. A Juice list holds EVERYTHING a
## Juice Player's list can: every kind of card (sounds, tweens, timing words, loops, signals, scenes) with every
## key it has, and it is edited in the Inspector with the very same card editor the Juice Player uses.
##
## Drop one on a Juice Player's Moment File slot and that player plays the file's cards in place of its own.
## Edit the file once and every player using it changes, in the editor and in a running game, because a player
## only READS the file while it plays (what a play counts down, the loops left, is kept by the player, never in
## the file). A player that wants its own tweaks uses Godot's own Make Unique in the slot's menu.
static func build_juice_list() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Resource"
	sheet.custom_class_name = "JuiceList"
	sheet.class_description = "A list of juice cards as a file: the same cards a Juice Player holds, with every kind and every key, edited with the same card editor. Drop it on a Juice Player's Moment File slot to play it; edit it once and every player using it changes."
	sheet.variables = {
		"steps": {"type": "Array[Dictionary]", "default": [], "exported": true,
			"attributes": {"tooltip": "The juice cards this file holds, in order. Each one is a card: what it does, how much, how long, and the timing words between them.",
				"drawer": "cards", "cards_schema": "feedback_steps", "cards_kind_key": "verb",
				"cards_stripe_key": "category",
				"header": "Juice list", "header_color": "#8a6fd4",
				"info": "One juice card per effect, the same cards a Juice Player holds. Drop this file on a Juice Player's Moment File slot to play it there. Every player using the file changes when you edit it; to give one object its own tweaks, use Make Unique in the slot's menu."}}
	}
	return Lib.save_pack(sheet, "res://eventsheet_addons/moment_resource/juice_list")
