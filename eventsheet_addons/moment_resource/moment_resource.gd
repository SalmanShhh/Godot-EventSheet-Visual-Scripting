## @ace_version(1.0.0)
@icon("res://eventsheet_addons/moment_resource/icon.svg")
class_name MomentResource
extends Resource
## One felt beat of a game as a file: the steps a hit, a kill, a win, a danger or a calm is made of, each one a word plus how much and how long. Play it with the Juice pack's Moment row, which scales every amount by one number. It is your file - rename it, retune it in the Inspector, share it.

# @inspector_header Moment #e8a33d
# @inspector_info One entry in Steps per thing that happens, in order. The words are shake, hitstop, slowmo, flash, punch, zoom, shockwave, chromatic, pulse and hold; pulse and hold also take the name of a post effect.
## Name this moment is played by.
@export var moment_name: String = ""
## Steps in order: each has a step word, amount, effect and seconds.
@export var steps: Array[Dictionary] = []
