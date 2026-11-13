extends Node
# The autoload this project registers so the tests have a real singleton to read: the object
# column's "(global)" reading and the provenance reader's "receiver: autoload" both ask
# ProjectSettings for a registered autoload and the script it stands for.

var score: int = 0


func reset() -> void:
	score = 0


func unregister_provider(_provider_id: String) -> void:
	pass
