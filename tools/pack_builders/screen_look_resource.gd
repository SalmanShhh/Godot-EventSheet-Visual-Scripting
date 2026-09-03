# Pack builder - screen_look_resource (a data-driven Custom Resource; run via build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")


## ScreenLookResource: a whole screen look as ONE file the project owns.
##
## A look is the post stack written down: which effects, in which order, how far each one goes and
## what its own dials are set to. Nothing here is a house style and nothing is shipped as a preset -
## the plugin has no list of named looks anywhere. A look is authored the way everything else in a
## game is: build it live with Screen FX rows until the screen is right, save it with Save Look, and
## the file is yours to rename, edit in the Inspector, put in version control and hand to somebody
## else. The only look Screen FX ships beside it is an empty one called Clean, which is what the
## screen looks like with nothing on it.
##
## The rows are a plain array of dictionaries rather than a second resource class per row, because a
## look is data a person reads and edits: `{"called": "vignette", "effect": "vignette",
## "strength": 0.4, "params": {"softness": 0.9}}` says the whole of one row in a form that survives
## being copied into a message.
static func build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Resource"
	sheet.custom_class_name = "ScreenLookResource"
	sheet.class_description = "One screen look as a file: which post effects, in which order, how far each goes and what its own dials are set to. Build a look live with Screen FX rows, save it with Save Look, and wear it with Use Look or Blend To Look. It is your file - rename it, edit it in the Inspector, share it."
	sheet.variables = {
		"look_name": {"type": "String", "default": "Clean", "exported": true,
			"attributes": {"tooltip": "What the look answers to. Look Is and Current Look compare this, so two files holding the same name are the same look.",
				"header": "Screen Look", "header_color": "#7bc96f",
				"info": "One entry in Rows per post effect, in the order they are drawn: the first is applied to the screen first and the last one has the last word."}},
		"rows": {"type": "Array[Dictionary]", "default": [], "exported": true,
			"attributes": {"tooltip": "One entry per effect, in draw order. Each is {\"called\": a name, \"effect\": one of the effect words, \"strength\": 0 to 1, \"params\": that effect's own dials by uniform name}."}}
	}
	return Lib.save_pack(sheet, "res://eventsheet_addons/screen_look_resource/screen_look_resource")
