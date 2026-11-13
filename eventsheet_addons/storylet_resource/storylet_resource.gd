## @ace_tags(narrative, storylet, resource)
## @ace_category("Storylets")
## @ace_version(1.0.0)
@icon("res://eventsheet_addons/storylet_resource/icon.svg")
class_name StoryletResource
extends Resource
## A whole storybook as a data asset: storylets with their requirements, choices, effects and meta, authored in Inspector grids. Load it into the Storylets autoload with Load From Resource - the data-driven alternative to a wall of Define Storylet actions.

## Rules a choice must pass to be offered, else it is hidden; same columns as Requirements.
@export_group("Choices")
@export_custom(PROPERTY_HINT_NONE, "eventsheet:table:storylet=String,choice_id=String,op=enum(gte=>= (at least)|gt=> (more than)|lte=<= (at most)|lt=< (less than)|eq== (equal to)|neq=!= (not equal to)),key=String,value=String,value_is_key=bool") var choice_requirements: Array = []
## Player choices on a storylet: the `storylet` id, a `choice_id` (passed to Choose), and the button `text`.
@export_custom(PROPERTY_HINT_NONE, "eventsheet:table:storylet=String,choice_id=String,text=String") var choices: Array = []
## Quality changes applied when a choice is picked; same columns as Effects.
@export_group("Effects")
@export_custom(PROPERTY_HINT_NONE, "eventsheet:table:storylet=String,choice_id=String,op=enum(set=Set to|inc=Increment by|dec=Decrement by|toggle=Toggle (0/1)|delete=Delete key),key=String,value=String") var choice_effects: Array = []
## Quality changes applied when a storylet is drawn: set, inc, dec, toggle or delete a key.
@export_custom(PROPERTY_HINT_NONE, "eventsheet:table:storylet=String,op=enum(set=Set to|inc=Increment by|dec=Decrement by|toggle=Toggle (0/1)|delete=Delete key),key=String,value=String") var effects: Array = []
## A readable name for this book (for your own reference; the engine does not use it).
@export_group("Identity")
@export var book_name: String = "storylets"
## Arbitrary key-value data attached to a storylet (a speaker, a portrait), read back with Active Meta / Storylet Meta. The engine never interprets it.
@export_group("Meta")
@export_custom(PROPERTY_HINT_NONE, "eventsheet:table:storylet=String,key=String,value=String") var meta: Array = []
## Rules a storylet needs to be eligible, all must pass: compare a quality, roll a chance, or gate on recent draws.
@export_group("Requirements")
@export_custom(PROPERTY_HINT_NONE, "eventsheet:table:storylet=String,op=enum(gte=>= (at least)|gt=> (more than)|lte=<= (at most)|lt=< (less than)|eq== (equal to)|neq=!= (not equal to)|chance=Chance (0-100%)|recent=Drawn in the last N|not_recent=NOT drawn in the last N),key=String,value=String,value_is_key=bool") var requirements: Array = []
## One row per storylet: id, title, body, weight, cooldown seconds and max plays; -1 is unlimited.
@export_group("Storylets")
@export_custom(PROPERTY_HINT_NONE, "eventsheet:table:id=String,title=String,body=String,weight=float,cooldown=float,max_plays=int:weight=weight") var storylets: Array = []
