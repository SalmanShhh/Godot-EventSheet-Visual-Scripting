# A sheet on the WorldEnvironment itself, where an atmosphere row's "On node" is blank for the same
# reason the lamp's is: the node the sheet is on IS the world. The first line is the one the Doctor
# offers to write on a reader's behalf - a scene taking its own copy of the environment before
# anything changes it - so this file is also the proof that the fix survives being saved and reopened.
extends WorldEnvironment


func _ready() -> void:
	environment = environment.duplicate()
	environment.fog_enabled = true
	environment.fog_density = 0.03
