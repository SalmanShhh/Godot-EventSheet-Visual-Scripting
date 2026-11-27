# @ace_version(1.0.0)
@icon("res://eventsheet_addons/moment_resource/icon.svg")
class_name JuiceList
extends Resource
## A list of juice cards as a file: the same cards a Juice Player holds, with every kind and every key, edited with the same card editor. Drop it on a Juice Player's Moment File slot to play it; edit it once and every player using it changes.

# @inspector_header Juice list #8a6fd4
# @inspector_info One juice card per effect, the same cards a Juice Player holds. Drop this file on a Juice Player's Moment File slot to play it there. Every player using the file changes when you edit it; to give one object its own tweaks, use Make Unique in the slot's menu.
## The juice cards this file holds, in order. Each one is a card: what it does, how much, how long, and the timing words between them.
@export_custom(PROPERTY_HINT_NONE, "eventsheet:cards:kind=verb,schema=feedback_steps,stripes=category") var steps: Array[Dictionary] = []
