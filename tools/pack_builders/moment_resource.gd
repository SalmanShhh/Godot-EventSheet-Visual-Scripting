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
	return Lib.save_pack(sheet, "res://eventsheet_addons/moment_resource/moment_resource")
