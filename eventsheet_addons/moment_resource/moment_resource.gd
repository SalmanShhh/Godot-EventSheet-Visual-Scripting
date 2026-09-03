## @ace_version(1.0.0)
@icon("res://eventsheet_addons/behavior.svg")
class_name MomentResource
extends Resource
## One felt beat of a game as a file: the steps a hit, a kill, a win, a danger or a calm is made of, each one a word plus how much and how long. Play it with the Juice pack's Moment row, which scales every amount by one number. It is your file - rename it, retune it in the Inspector, share it.

# @inspector_header Moment #e8a33d
# @inspector_info One entry in Steps per thing that happens, in order. The words are shake, hitstop, slowmo, flash, punch, zoom, shockwave, chromatic, pulse and hold; pulse and hold also take the name of a post effect.
## What the moment answers to. The Moment row looks a name up among the moments a game has defined, and then among the files beside the Juice pack, so a file called impact.tres is played by Moment "impact" with nothing else set up.
@export var moment_name: String = ""
## One entry per step, in the order they fire. Each is {"verb": one of the step words, "amount": how much, "effect": the post-effect word for pulse and hold, "seconds": how long}.
@export var steps: Array[Dictionary] = []
