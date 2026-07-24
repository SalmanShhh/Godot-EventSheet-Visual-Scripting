## @ace_tags(narrative, storylet, resource)
## @ace_category("Storylets")
## @ace_version(1.0.0)
@icon("res://eventsheet_addons/storylet_resource/icon.svg")
class_name StoryletResource
extends Resource
## A whole storybook as a data asset: storylets with their requirements, choices, effects and meta, authored in Inspector grids. Load it into the Storylets autoload with Load From Resource - the data-driven alternative to a wall of Define Storylet actions.

## Rules that must pass for a choice to be OFFERED (else it is hidden). Reference the choice by its `storylet` + `choice_id`. Same comparison / value_is_key meaning as the Requirements grid.
@export_group("Choices")
@export_custom(PROPERTY_HINT_NONE, "eventsheet:table:storylet=String,choice_id=String,op=enum(gte|gt|lte|lt|eq|neq),key=String,value=String,value_is_key=bool") var choice_requirements: Array = []
## Player choices on a storylet: the `storylet` id, a `choice_id` (passed to Choose), and the button `text`.
@export_custom(PROPERTY_HINT_NONE, "eventsheet:table:storylet=String,choice_id=String,text=String") var choices: Array = []
## Quality changes applied when a CHOICE is picked. Reference the choice by `storylet` + `choice_id`; same op / key / value as the Effects grid.
@export_group("Effects")
@export_custom(PROPERTY_HINT_NONE, "eventsheet:table:storylet=String,choice_id=String,op=enum(set|inc|dec|toggle|delete),key=String,value=String") var choice_effects: Array = []
## Quality changes applied automatically when a storylet is DRAWN. `op`: set / inc / dec / toggle / delete on `key`; `value` is the operand (ignored for toggle / delete).
@export_custom(PROPERTY_HINT_NONE, "eventsheet:table:storylet=String,op=enum(set|inc|dec|toggle|delete),key=String,value=String") var effects: Array = []
## A readable name for this book (for your own reference; the engine does not use it).
@export_group("Identity")
@export var book_name: String = "storylets"
## Arbitrary key-value data attached to a storylet (a speaker, a portrait), read back with Active Meta / Storylet Meta. The engine never interprets it.
@export_group("Meta")
@export_custom(PROPERTY_HINT_NONE, "eventsheet:table:storylet=String,key=String,value=String") var meta: Array = []
## Rules a storylet needs to be eligible (all must pass). `storylet` is the id from the Storylets grid. `op` is a word token (a table dropdown cannot hold `>=`): gte (>=), gt (>), lte (<=), lt (<), eq (=), neq (!=). For a comparison, `key` is a quality and `value` is what to compare against; tick `value_is_key` to compare against ANOTHER quality's value (gold >= price). For `chance`, put a 0-100 percent in `value` (key ignored). For `recent` / `not_recent`, put a draw count N in `value` - an anti-repeat gate over the last N draws.
@export_group("Requirements")
@export_custom(PROPERTY_HINT_NONE, "eventsheet:table:storylet=String,op=enum(gte|gt|lte|lt|eq|neq|chance|recent|not_recent),key=String,value=String,value_is_key=bool") var requirements: Array = []
## One row per storylet: its id (the key every other grid references), the title + body your game shows, its weight (higher = leads the draw), cooldown seconds, and max plays (-1 = unlimited, 1 = a one-shot).
@export_group("Storylets")
@export_custom(PROPERTY_HINT_NONE, "eventsheet:table:id=String,title=String,body=String,weight=float,cooldown=float,max_plays=int") var storylets: Array = []
