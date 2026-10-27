## @ace_tags(codex, collection, resource)
## @ace_category("Codex")
## @ace_version(1.0.0)
@icon("res://eventsheet_addons/codex_entry_resource/icon.svg")
class_name CodexEntryResource
extends Resource
## One page of a codex as a file: the name it is shown under, the picture beside it, and the words under that. Its FILE name is the entry's name and its folder is the set, so the Codex director's rows need nothing else. It is your file - rename it, rewrite it in the Inspector, translate it.

# @inspector_header Page #7c9cf5
# @inspector_info The file's own name is the entry id the Discover and Has Discovered rows take, and its folder is the set. Nothing here has to repeat either.
## The title the page is shown under - "Green Slime", "Rusted Key", "The Long Winter". Leave the file name to say which entry this IS; this is what a reader sees.
@export var entry_name: String = ""
## The illustration beside the words. Any texture: a portrait, an item sprite, a photograph of a map.
@export var picture: Texture2D = null
## The words of the page. Plain text, or BBCode if the label you show it in is a RichTextLabel.
@export var text: String = ""
