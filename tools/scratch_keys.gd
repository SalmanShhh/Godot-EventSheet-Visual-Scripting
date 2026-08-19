extends SceneTree

const KEYS: PackedStringArray = [
	"Set mass to {value}", "Set linear damping to {value}", "Set angular damping to {value}",
	"Set gravity scale to {value}", "Set immovable", "Set movable", "Use physics material {value}",
	"Set friction to {value}", "Set elasticity to {value}", "Set world gravity to {value}",
	"Apply torque {value}", "Apply torque impulse {value}", "Apply impulse {value} at {offset}",
	"Apply force {value} at {offset}", "Create {kind} joint", "Is sleeping", "Is awake",
	"Is immovable", "Is not immovable", "Is checked", "Is not checked", "Set checked",
	"Set unchecked", "Set text to {value}", "Set placeholder to {value}",
	"Set formatted text to {value}", "Append formatted text {value}", "Switch to tab {value}",
	"Set tooltip to {value}", "Add item {value}", "Remove item {value}", "Select item {value}",
	"Clear", "Open", "Move along path at {speed}", "Has reached the end", "Go to start",
	"Set looping {state}", "Set rotate with path {state}", "Set distance along path to {value}",
	"Add path point {value}", "Set pattern {name} to {value}", "Wait {seconds} seconds",
	"Physics", "Follow a Path", "Text input", "List", "Check box", "File chooser", "Tabs",
	"blocks the game", "regular expression", "now (microseconds)", "a pattern", "the match",
	"first match of {pattern} in {text}", "all matches of {pattern} in {text}",
	"replace matches of {pattern} in {text} with {value}", "with", "revolute", "distance",
	"prismatic", "on", "off",
	"Text input ▸ On text changed", "Text input ▸ On submitted", "List ▸ On item selected",
	"File chooser ▸ On file chosen", "Tabs ▸ On tab changed"
]


func _init() -> void:
	var present: Dictionary = {}
	var handle: FileAccess = FileAccess.open("res://addons/eventsheet/translations/de.csv", FileAccess.READ)
	while not handle.eof_reached():
		var row: PackedStringArray = handle.get_csv_line()
		if row.size() >= 1 and not row[0].is_empty():
			present[row[0]] = true
	handle.close()
	for key: String in KEYS:
		if not present.has(key):
			print("MISSING: %s" % key)
	quit(0)
