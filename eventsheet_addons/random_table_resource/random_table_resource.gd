@icon("res://eventsheet_addons/behavior.svg")
class_name RandomTableResource
extends Resource
## A weighted random table as a data asset. Fill the entries grid (value + weight) in the Inspector, save as a .tres, and draw from it with Advanced Random's Pick From Table.

## One row per outcome: its value (any string - an item id, a name, a scene path) and weight (higher = commoner).
@export_custom(PROPERTY_HINT_NONE, "eventsheet:table:value=String,weight=float") var entries: Array = []
