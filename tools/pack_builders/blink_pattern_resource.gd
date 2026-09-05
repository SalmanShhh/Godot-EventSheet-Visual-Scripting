# Pack builder - blink_pattern_resource (a data-driven Custom Resource beside the Flash pack;
# run via tools/build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")


## BlinkPatternResource: a rhythm of appearing and disappearing, written down as a file.
##
## Every game blinks something. Invulnerability frames after a hit, a warning on a low bar, a
## failing bulb, a neon sign with a dead letter. Each one is the same little state machine written
## again with different numbers, usually inside a process row where nobody can see it.
##
## A pattern is that rhythm as data: a list of phases, and a phase is "on for this long, off for
## that long, this many times". Three fast winks and then two slow ones is two phases. The Flash
## pack's Blink row plays one on the host, and a player who has asked for no flashing gets the same
## pattern held to a floor, so a pattern is never a strobe.
##
## NOTHING HERE IS A HOUSE STYLE. One starter file ships beside the Flash pack because a jam does
## not have time to author its first blink; it is an ordinary resource - rename it, retune it,
## duplicate it, delete it. There is no dropdown of named patterns anywhere in the editor, and the
## plugin has no idea which patterns a game holds.
##
## The phases are a plain array of dictionaries rather than a resource class per phase, because a
## pattern is data a person reads and edits: `{"on": 0.08, "off": 0.08, "count": 6}` says the whole
## of one phase in a form that survives being copied into a message.
static func build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Resource"
	sheet.custom_class_name = "BlinkPatternResource"
	sheet.class_description = "A blink written down as a file: the phases something appears and disappears in, each one \"on for this long, off for that long, this many times\". Play it with the Flash pack's Blink row. It is your file - rename it, retune it in the Inspector, share it between the hurt flicker and the failing bulb."
	sheet.variables = {
		"pattern_name": {"type": "String", "default": "", "exported": true,
			"attributes": {"tooltip": "What this rhythm is called. For your own reading: the Blink row takes the file itself, so a pattern never has to be looked up by name.",
				"header": "Blink pattern", "header_color": "#e8a33d",
				"info": "One entry in Phases per stretch of the rhythm, in order. A phase is on seconds, off seconds and how many times to repeat that pair before the next phase takes over."}},
		"phases": {"type": "Array[Dictionary]", "default": [], "exported": true,
			"attributes": {"tooltip": "One entry per stretch of the rhythm, in the order they play. Each is {\"on\": seconds visible, \"off\": seconds hidden, \"count\": how many times}. Six fast winks then two slow ones is two entries."}}
	}
	return Lib.save_pack(sheet, "res://eventsheet_addons/flash/blink_pattern_resource")
