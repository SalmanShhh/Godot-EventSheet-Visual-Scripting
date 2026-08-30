# EventForge module - THE FOUR NOTIFICATIONS A GAME ACTUALLY REACTS TO.
#
# Godot tells a node about a great many things through one callback and one number:
#
#     func _notification(what: int) -> void:
#         match what:
#             NOTIFICATION_PAUSED:
#                 ...
#             NOTIFICATION_WM_CLOSE_REQUEST:
#                 get_tree().quit()
#
# The sheet has compiled to that shape, and read it back out of hand-written files, since the
# notification triggers shipped: every event whose trigger id is `OnNotification:<CONSTANT>` becomes
# one case of one `match`, which is exactly what the engine's one-callback design asks for. What was
# missing was the other half - a NAME. There was no descriptor behind any of those ids, so the four
# notifications a game really does react to could be read out of a file and could not be picked from
# a list, and the reading called them by the constant rather than by anything a person would say.
#
# These are the four, and only the four. A notification a game does not react to is not vocabulary,
# it is a number - and the `_notification` handler stays open to every other one through the
# reading, which humanizes any constant it meets without pretending the sheet has a row for it.
# Reaching for one of those means writing the case, which is a perfectly good thing to write.
#
# THE WORDS ARE THE READING'S WORDS. A hand-written `NOTIFICATION_PAUSED:` case has read as "On
# paused" since the notification reading shipped, and these descriptors say the same thing rather
# than a second thing: a row picked from the list and a row lifted out of a file are the same row,
# and a reader who has met one has met the other. `notification_trigger_words_test` fails the suite
# if the two ever drift apart.
#
# WHY THEY ARE FILED APART from the tree callbacks they sound like: On destroyed (a node leaving the
# tree) and On object freed are different moments - a node can leave the tree and come back, and this
# one is the last thing that ever happens to it. Same for pausing: a paused game is not a stopped
# one. The section they are in is what says so.
#
# Module contract: see ace_factory.gd - ace_ids/templates are API (compatibility
# covenant); this file only changes where the descriptors are AUTHORED.
@tool
class_name EventForgeNotificationACEs
extends RefCounted

const F := preload("res://addons/eventforge/registration/ace_factory.gd")

const CAT := "Notifications"

## The prefix a notification trigger's id carries, spelled once here rather than typed four times.
## It is TriggerResolver's own constant, read through the file that owns the id shape.
const PREFIX := "OnNotification:"

## The four, as {constant: [display name, hover description]}. Keyed by the engine's own constant
## because that constant IS half the trigger id and the whole of the emitted case - a table keyed on
## anything else would need a second table to get back to it.
const NOTIFICATIONS: Dictionary = {
	"NOTIFICATION_PAUSED": ["On paused",
		"Runs when the game is paused - `get_tree().paused` turned on - on every node that is not exempt from pausing. The moment to dim the music and put the menu up, and the one place a paused game can still act."],
	"NOTIFICATION_UNPAUSED": ["On unpaused",
		"Runs when the game comes back off pause, on the same nodes. The other half of On paused, and where the music and the menu go back the way they were."],
	"NOTIFICATION_PREDELETE": ["On object freed",
		"Runs as the very last thing that happens to this object, just before its memory goes. Different from On destroyed, which is the node leaving the tree and can happen more than once - this happens exactly once and nothing follows it, so it is where a handle held somewhere else gets given back."],
	"NOTIFICATION_WM_CLOSE_REQUEST": ["On close",
		"Runs when the player closes the window - the X, or the system asking the game to quit. The game does NOT quit by itself when this arrives if the project is set to handle it, which is what makes room for a \"save first?\" prompt."]
}

## The order the four are offered in: the two halves of pausing together, then the two endings, from
## the one node's to the whole window's. Written out rather than sorted, because alphabetical order
## would put the close request between the pause and the unpause and split the only pair here.
const ORDER: PackedStringArray = ["NOTIFICATION_PAUSED", "NOTIFICATION_UNPAUSED",
	"NOTIFICATION_PREDELETE", "NOTIFICATION_WM_CLOSE_REQUEST"]


static func get_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []
	for constant: String in ORDER:
		var entry: Array = NOTIFICATIONS[constant]
		var name: String = str(entry[0])
		descriptors.append(F.make_descriptor("Core", PREFIX + constant, name,
			ACEDescriptor.ACEType.TRIGGER, "", "", [], CAT, name)
			.described(str(entry[1])))
	return descriptors


static func section_descriptions() -> Dictionary:
	return {CAT: "The things the engine tells a node about through its one notification callback, rather than through a signal. Every event here becomes a case of the same `match what:` block, which is the shape the engine's design asks for and the shape a hand-written file already has."}
