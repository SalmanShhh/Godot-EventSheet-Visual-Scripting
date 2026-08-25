## @ace_tags(narrative, storylet, resource)
## @ace_category("Storylets")
## @ace_version(1.0.0)
@icon("res://eventsheet_addons/storylet_resource/icon.svg")
class_name StoryletResource
extends Resource
## A whole storybook as a data asset: storylets with their requirements, choices, effects and meta, authored in Inspector grids. Load it into the Storylets autoload with Load From Resource - the data-driven alternative to a wall of Define Storylet actions.

## A readable name for this book (for your own reference; the engine does not use it).
@export_group("Identity")
@export var book_name: String = "storylets"
## One row per storylet: its id (the key every other grid references), the title + body your game shows, its weight (higher = leads the draw), cooldown seconds, and max plays (-1 = unlimited, 1 = a one-shot).
@export_group("Storylets")
@export_custom(PROPERTY_HINT_NONE, "eventsheet:table:id=String,title=String,body=String,weight=float,cooldown=float,max_plays=int") var storylets: Array = []
## Rules a storylet needs to be eligible (all must pass). `storylet` is the id from the Storylets grid. `op` picks the comparison from a dropdown; the cell stores a short token (gte, lt, eq...) that the runtime matches on. For a comparison, `key` is a quality and `value` is what to compare against; tick `value_is_key` to compare against ANOTHER quality's value (gold >= price). For `chance`, put a 0-100 percent in `value` (key ignored). For `recent` / `not_recent`, put a draw count N in `value` - an anti-repeat gate over the last N draws.
@export_group("Requirements")
@export_custom(PROPERTY_HINT_NONE, "eventsheet:table:storylet=String,op=enum(gte=>= (at least)|gt=> (more than)|lte=<= (at most)|lt=< (less than)|eq== (equal to)|neq=!= (not equal to)|chance=Chance (0-100%)|recent=Drawn in the last N|not_recent=NOT drawn in the last N),key=String,value=String,value_is_key=bool") var requirements: Array = []
## Player choices on a storylet: the `storylet` id, a `choice_id` (passed to Choose), and the button `text`.
@export_group("Choices")
@export_custom(PROPERTY_HINT_NONE, "eventsheet:table:storylet=String,choice_id=String,text=String") var choices: Array = []
## Rules that must pass for a choice to be OFFERED (else it is hidden). Reference the choice by its `storylet` + `choice_id`. Same comparison / value_is_key meaning as the Requirements grid.
@export_custom(PROPERTY_HINT_NONE, "eventsheet:table:storylet=String,choice_id=String,op=enum(gte=>= (at least)|gt=> (more than)|lte=<= (at most)|lt=< (less than)|eq== (equal to)|neq=!= (not equal to)),key=String,value=String,value_is_key=bool") var choice_requirements: Array = []
## Quality changes applied automatically when a storylet is DRAWN. `op`: set / inc / dec / toggle / delete on `key`; `value` is the operand (ignored for toggle / delete).
@export_group("Effects")
@export_custom(PROPERTY_HINT_NONE, "eventsheet:table:storylet=String,op=enum(set=Set to|inc=Increment by|dec=Decrement by|toggle=Toggle (0/1)|delete=Delete key),key=String,value=String") var effects: Array = []
## Quality changes applied when a CHOICE is picked. Reference the choice by `storylet` + `choice_id`; same op / key / value as the Effects grid.
@export_custom(PROPERTY_HINT_NONE, "eventsheet:table:storylet=String,choice_id=String,op=enum(set=Set to|inc=Increment by|dec=Decrement by|toggle=Toggle (0/1)|delete=Delete key),key=String,value=String") var choice_effects: Array = []
## Arbitrary key-value data attached to a storylet (a speaker, a portrait), read back with Active Meta / Storylet Meta. The engine never interprets it.
@export_group("Meta")
@export_custom(PROPERTY_HINT_NONE, "eventsheet:table:storylet=String,key=String,value=String") var meta: Array = []
