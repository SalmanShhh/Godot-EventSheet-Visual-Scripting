# Pack builder - codex_entry_resource (a data-driven Custom Resource; run via build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")


## CodexEntryResource: one page of a game's codex as a file.
##
## A bestiary entry, an item description, a lore page and a recipe card are the same three things
## every time - a name, a picture and some words - and every game keeps them somewhere different: a
## Dictionary in a script, a row in a spreadsheet, a scene per page. Written down as a resource they
## are an ordinary file a writer edits in the Inspector, a translator can be pointed at, and an
## artist can drop a picture onto without opening a single script.
##
## THE FILE'S NAME IS THE ENTRY'S NAME. There is no id field here to fall out of step with the file
## it lives in: `res://codex/enemies/slime.tres` IS the entry "slime" of the set "enemies", so the
## Codex director's rows take those two words and nothing else. The folder is the set for the same
## reason - a set with a new entry in it is a file dropped in a folder, with no list to maintain and
## no dropdown in the editor naming anybody's monsters.
##
## THE PACK SHIPS NO ENTRIES. One empty starter goes out beside the Codex director as the thing to
## duplicate, and that is the only page this plugin will ever have an opinion about.
static func build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Resource"
	sheet.custom_class_name = "CodexEntryResource"
	sheet.class_description = "One page of a codex as a file: the name it is shown under, the picture beside it, and the words under that. Its FILE name is the entry's name and its folder is the set, so the Codex director's rows need nothing else. It is your file - rename it, rewrite it in the Inspector, translate it."
	sheet.addon_category = "Codex"
	sheet.addon_tags = PackedStringArray(["codex", "collection", "resource"])
	sheet.variables = {
		"entry_name": {"type": "String", "default": "", "exported": true,
			"attributes": {"tooltip": "The title the page is shown under - \"Green Slime\", \"Rusted Key\", \"The Long Winter\". Leave the file name to say which entry this IS; this is what a reader sees.",
				"header": "Page", "header_color": "#7c9cf5",
				"info": "The file's own name is the entry id the Discover and Has Discovered rows take, and its folder is the set. Nothing here has to repeat either."}},
		"picture": {"type": "Texture2D", "default": null, "exported": true,
			"attributes": {"tooltip": "The illustration beside the words. Any texture: a portrait, an item sprite, a photograph of a map."}},
		"text": {"type": "String", "default": "", "exported": true,
			"attributes": {"tooltip": "The words of the page. Plain text, or BBCode if the label you show it in is a RichTextLabel."}}
	}
	return Lib.save_pack(sheet, "res://eventsheet_addons/codex_entry_resource/codex_entry_resource")
