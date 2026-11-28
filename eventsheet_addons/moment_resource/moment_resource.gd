# @ace_version(1.0.0)
@icon("res://eventsheet_addons/moment_resource/icon.svg")
class_name MomentResource
extends Resource
## One felt beat of a game as a file: the steps a hit, a kill, a win, a danger or a calm is made of, each one a word plus how much and how long. Play it with the Juice pack's Moment row, which scales every amount by one number. It is your file - rename it, retune it in the Inspector, share it.

# @inspector_header Moment #e8a33d
# @inspector_info One card per thing that happens, in order, shown under Steps. Add a card with the Add card button and open it to tune it. Change anything and this file turns into a Juice list that keeps the same path, so every scene using it plays on.
## Name this moment is played by.
@export var moment_name: String = ""
## The cards in order: what each one does, how much and how long.
@export var steps: Array[Dictionary] = []
