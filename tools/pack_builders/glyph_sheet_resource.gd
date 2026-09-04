# Pack builder - glyph_sheet_resource (a data-driven Custom Resource; run via build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")


## GlyphSheetResource: which picture stands for a control, on the thing in the player's hands.
##
## "Press E" is wrong the moment the player picks up a pad, and "Press A" is wrong on half the pads
## that exist. The shipped Prompt For Control row answers with the Input Map's own WORDS, which is
## right and readable and still not a button glyph - and a button glyph is what a prompt, a tutorial
## line and a HUD hint all actually want.
##
## The mapping is data, so it is a file: one entry per control per device, in a resource the game
## owns. The Prompts director reads it for the prompt it draws, and the Glyph For row hands the same
## texture to anything else - a label's icon, a tutorial card, a rebinding screen.
##
## FIVE DEVICES, because that is how many kinds of button art a game really ships: the keyboard, a
## generic pad for anything unrecognised, and the three console layouts, told apart by the joypad's
## own product name. A control with no picture on the layout in hand falls back to the generic pad
## and then to the keyboard, so a half-drawn sheet is a sheet with holes rather than a crash.
##
## THE PACK SHIPS ONE SHEET, drawn plain - flat coloured squares for the two controls every Godot
## project already has. It is a starter to replace, not a set to use: there is no list of glyphs
## anywhere in the editor and the plugin has no idea what a game's buttons look like.
##
## Each device is a plain Dictionary of action name to texture rather than a resource class per
## entry, because `{"ui_accept": preload("res://glyphs/key_e.png")}` says the whole of one binding
## in a form a person reads, edits and pastes into a message.
static func build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Resource"
	sheet.custom_class_name = "GlyphSheetResource"
	sheet.class_description = "Which picture stands for a control, per device: the keyboard, a generic pad, and the three console layouts. The Prompts director draws the right one automatically and the Glyph For row hands it to anything else. It is your file - draw your own buttons into it, rename it, share it."
	sheet.variables = {
		"sheet_name": {"type": "String", "default": "", "exported": true,
			"attributes": {"tooltip": "What this sheet is called, for your own sake when a project holds more than one - a plain set and a large-print set, say. Nothing looks a sheet up by this name; it is a label.",
				"header": "Sheet", "header_color": "#7c9cf5",
				"info": "Each device below is a Dictionary of control name to texture: {\"ui_accept\": the picture of that button}. A control missing from the layout in hand falls back to the generic pad, then to the keyboard."}},
		"keyboard": {"type": "Dictionary", "default": {}, "exported": true,
			"attributes": {"tooltip": "The keyboard and mouse pictures, by control name: {\"ui_accept\": the Enter key picture}. This is the last fallback, so a control drawn only here still shows something on every device.",
				"header": "Devices", "header_color": "#5fb37a"}},
		"pad": {"type": "Dictionary", "default": {}, "exported": true,
			"attributes": {"tooltip": "The generic gamepad pictures, for a pad whose product name matches none of the three layouts below - and the fallback for a control one of them has not drawn."}},
		"xbox": {"type": "Dictionary", "default": {}, "exported": true,
			"attributes": {"tooltip": "The pictures for a pad whose product name reads as this layout (A, B, X, Y). Leave it empty and such a pad uses the generic pad's pictures."}},
		"playstation": {"type": "Dictionary", "default": {}, "exported": true,
			"attributes": {"tooltip": "The pictures for a pad whose product name reads as this layout (cross, circle, square, triangle). Leave it empty and such a pad uses the generic pad's pictures."}},
		"nintendo": {"type": "Dictionary", "default": {}, "exported": true,
			"attributes": {"tooltip": "The pictures for a pad whose product name reads as this layout (B, A, Y, X - the east-west pair swapped). Leave it empty and such a pad uses the generic pad's pictures."}}
	}
	return Lib.save_pack(sheet, "res://eventsheet_addons/glyph_sheet_resource/glyph_sheet_resource")
