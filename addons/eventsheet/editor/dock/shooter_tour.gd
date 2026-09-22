@tool
class_name EventSheetShooterTour
extends RefCounted

# The top-down shooter tour: the first game most event-sheet users have already built once, rebuilt
# here row by row on a practice sheet, with the finished game one click away in the showcases.
#
# It rides the same tour window as the built-in tour (EventSheets.start_tour), so it floats beside
# the sheet, never gates Next on a check, and Skip closes it. Each step's check COMPILES the practice
# sheet and looks for the line the step's row writes - so it recognises the row however the reader
# made it (the picker, Quick add, the Ghost Row or typing GDScript), and a test can pin every check
# against real rows without a window.

## The finished game this tour rebuilds, opened from the last step.
const SHOWCASE_SCENE := "res://demo/showcase/top_down_shooter/top_down_shooter.tscn"


static func steps() -> Array[Dictionary]:
	return [
		{
			"title": "The player faces the mouse",
			"body": "Every tick, the Player turns toward the mouse. In the sheet that is one action under an Every tick event: set the Player's rotation to the direction from the Player to the mouse.",
			"task": "Add an event with no condition (it runs every tick) and an action: Set Property on $Player, rotation = $Player.global_position.direction_to(get_global_mouse_position()).angle().",
			"check": func(sheet: EventSheetResource) -> bool:
				return _writes(sheet, ["get_global_mouse_position()", "rotation ="]),
		},
		{
			"title": "Click fires",
			"body": "A click is an input event. The row asks \"is this the left mouse button being pressed?\" and runs once per click.",
			"task": "Add an event on On Input with the condition On Mouse Button Pressed (event), button MOUSE_BUTTON_LEFT.",
			"check": func(sheet: EventSheetResource) -> bool: return _writes(sheet, ["MOUSE_BUTTON_LEFT"]),
		},
		{
			"title": "A bullet appears at the player",
			"body": "Create object is Spawn Scene At here: a scene is the object type, and the copy lands where you say.",
			"task": "Under the click, add Spawn Scene At with the bullet scene and the position $Player.position.",
			"check": func(sheet: EventSheetResource) -> bool:
				return _writes(sheet, ["MOUSE_BUTTON_LEFT", "instantiate()"]),
		},
		{
			"title": "Monsters keep coming",
			"body": "Every X seconds is a condition with its own clock, so the event below it runs once per interval.",
			"task": "Add an event with Every X Seconds (1.2) and Spawn Scene At for the monster scene, at a random point on an edge.",
			"check": func(sheet: EventSheetResource) -> bool: return _writes(sheet, ["__every_", "instantiate()"]),
		},
		{
			"title": "Keep a score",
			"body": "A sheet variable is an instance variable of the object the sheet is on - here, the game itself.",
			"task": "Add an instance variable score, a whole number starting at 0.",
			"check": func(sheet: EventSheetResource) -> bool: return _writes(sheet, ["var score"]),
		},
		{
			"title": "A monster with no health explodes",
			"body": "In another event-sheet editor a condition on Monster picks every monster that passes it. Here a script belongs to one node, so the same words are a For each over the Monster family - and the Ghost Row writes it for you.",
			"task": "Press C, type \"ShooterMonster health <= 0\" and pick the For each line it offers.",
			"check": func(sheet: EventSheetResource) -> bool:
				return _writes(sheet, ["get_nodes_in_group(\"family_", "health <= 0"]),
		},
		{
			"title": "Boom, and a point",
			"body": "The actions under the For each run once for each monster it picked, with that monster as the one being talked about.",
			"task": "Under it add Spawn Scene At for the explosion at the monster's position, Add 1 to score, and Free Node on the monster.",
			"check": func(sheet: EventSheetResource) -> bool: return _writes(sheet, ["score += 1", "queue_free()"]),
		},
		{
			"title": "Show the score",
			"body": "The HUD is a Label; its text is set every tick from the variable.",
			"task": "Add Set Text (formatted) on $Hud with \"Score %d\" and score.",
			"check": func(sheet: EventSheetResource) -> bool: return _writes(sheet, [".text =", "score"]),
		},
		{
			"title": "Read what you wrote",
			"body": "Every row is a line of GDScript you could have typed. Nothing runs that you cannot read.",
			"task": "Open Menu ▸ View ▸ GDScript Panel and find the For each loop your picking row wrote.",
			"check": Callable(),
		},
		{
			"title": "Play the finished game",
			"body": "The finished game - with the bullet and monster sheets that go with this one - is a showcase you can open, play and change.",
			"task": "Open the Start page's Top-Down Shooter (New… ▸ Showcases) and press the play button.",
			"check": Callable(),
		},
	]


## True when the sheet's compiled GDScript holds every one of the snippets - the lines a step's
## rows write, however the reader made them.
static func _writes(sheet: EventSheetResource, snippets: Array) -> bool:
	if sheet == null:
		return false
	var output: String = str(SheetCompiler.compile(sheet, "").get("output", ""))
	for snippet: Variant in snippets:
		if not output.contains(str(snippet)):
			return false
	return true
