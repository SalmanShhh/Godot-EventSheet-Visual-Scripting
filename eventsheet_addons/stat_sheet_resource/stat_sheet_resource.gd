@icon("res://eventsheet_addons/stat_sheet_resource/icon.svg")
class_name StatSheetResource
extends Resource
## A stat loadout as a data asset: base values plus buff rows, edited as Inspector grids and applied with StatForge's Load Stat Sheet action. Author classes, enemy tiers, and difficulty presets as .tres files.

## The starting value of each stat before any buffs (speed 100, hp 50...).
@export_custom(PROPERTY_HINT_NONE, "eventsheet:table:stat=String,value=float") var bases: Array = []
## One row per buff, applied top to bottom. mode: add / multiply / override (highest override wins). tags: comma-separated labels for bulk removal. source: who applied it. duration: seconds until it expires (0 = permanent).
@export_custom(PROPERTY_HINT_NONE, "eventsheet:table:buff_id=String,stat=String,value=float,mode=String,tags=String,source=String,duration=float") var buffs: Array = []
# @inspector_header Stat Sheet #7bc96f
# @inspector_info Applied by StatForge > Load Stat Sheet: bases set the starting numbers, then the buff rows are added top to bottom.
## A label for your own reference (StatForge does not read it).
@export var sheet_name: String = "loadout"
