# Godot EventSheets - moving a node by hand while its behaviour previews keeps the move.
#
# A preview writes the host down when it starts and puts it back on Stop. A drag, an Inspector edit or
# an undo made DURING the preview used to be overwritten on the next frame and put back on Stop, so the
# node ended where it was before Preview while the undo history said it had moved. The preview now
# remembers what it last left on the host (just before a frame is drawn) and, at the start of the next
# frame, takes anything else that changed as the node's new resting value and stops. It only trusts a
# remembered value that was taken since its last check: a frame the editor did not draw leaves the
# value stale, and a stale value would read the preview's own writes as a hand edit. A test run is not
# an editor, so the helpers are driven by hand on the shipped Sine pack, as the editor would call them,
# and the signal wiring is pinned as text.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const TEST_NAME := "preview_keeps_hand_edits_test"
const SINE := "res://eventsheet_addons/sine/sine_behavior.gd"
const TABLE := "_eventsheets_previews"
const PREVIEWING: PackedStringArray = [
	"fade", "flash", "follow_path", "hit_flash", "juice", "juice_3d", "light_flicker", "light_pulse",
	"move_to", "move_to_3d", "orbit", "orbit_3d", "rotate", "sine", "sine_3d", "spring", "tween", "wave",
]


static func run() -> bool:
	var ok: bool = true
	var moved: Dictionary = _drive(Vector2(300, 260), true)
	var still: Dictionary = _drive(Vector2.INF, true)
	var unseen: Dictionary = _drive(Vector2(300, 260), false)
	ok = SUPPORT.pins(TEST_NAME, [
		["a hand move is noticed", moved.get("kept"), true],
		["Stop keeps the hand move", moved.get("after_stop"), Vector2(300, 260)],
		["the preview is over", moved.get("previewing"), false],
		["with no hand move nothing is noticed", still.get("kept"), false],
		["and Stop puts the node back where it rested", still.get("after_stop"), Vector2(100, 100)],
		["a value taken before a frame nobody drew is not trusted", unseen.get("kept"), false],
		["so Stop puts the node back as it always did", unseen.get("after_stop"), Vector2(100, 100)],
	]) and ok
	ok = _older_entry() and ok
	ok = _two_on_one_host() and ok
	ok = _wiring() and ok
	return ok


## One preview of the shipped Sine: Preview, one frame, the editor's snapshot (when `drawn`), an optional hand
## move, the check, Stop. `hand` is Vector2.INF for no move.
static func _drive(hand: Vector2, drawn: bool) -> Dictionary:
	var script: GDScript = load(SINE) as GDScript
	var host: Node2D = Node2D.new()
	host.position = Vector2(100, 100)
	var sine: Node = script.new() as Node
	sine.set("host", host)
	sine.set("magnitude", 50.0)
	sine.set("period", 4.0)
	# What _preview_start does, minus its editor gate and its signals.
	var rest: Dictionary = script.call("_preview_values", host, false)
	Engine.set_meta(TABLE, {host.get_instance_id(): {"rest": rest, "users": 1, "seen": rest.duplicate()}})
	sine.set("_preview_own", script.call("_preview_values", sine, true))
	sine.set("_previewing", true)
	sine.call("_process", 1.0)
	if drawn:
		sine.call("_preview_note_seen")
	if hand != Vector2.INF:
		host.position = hand
	var kept: Variant = sine.call("_preview_keep_hand_edits")
	sine.call("_preview_stop")
	var out: Dictionary = {"kept": kept, "after_stop": host.position, "previewing": sine.get("_previewing")}
	Engine.remove_meta(TABLE)
	sine.free()
	host.free()
	return out


## An entry an older script wrote has no "seen": nothing is taken as a hand edit.
static func _older_entry() -> bool:
	var script: GDScript = load(SINE) as GDScript
	var host: Node2D = Node2D.new()
	var sine: Node = script.new() as Node
	sine.set("host", host)
	sine.set("_preview_noted", true)
	Engine.set_meta(TABLE, {host.get_instance_id(): {"rest": {"position": Vector2(1, 2)}, "users": 1}})
	host.position = Vector2(9, 9)
	var kept: Variant = sine.call("_preview_keep_hand_edits")
	Engine.remove_meta(TABLE)
	sine.free()
	host.free()
	return SUPPORT.check(TEST_NAME, "an older entry with no snapshot is never read as a hand edit", kept, false)


## Two behaviours on one node share one entry: a hand edit stops both, and a plain Stop on one stops the other
## with the node at rest.
static func _two_on_one_host() -> bool:
	var script: GDScript = load(SINE) as GDScript
	var hand_case: Dictionary = _two(script, Vector2(300, 260))
	var stop_case: Dictionary = _two(script, Vector2.INF)
	return SUPPORT.pins(TEST_NAME, [
		["two on one node: a hand edit is noticed by the first", hand_case.get("first_kept"), true],
		["two on one node: and by the second", hand_case.get("second_kept"), true],
		["two on one node: the node keeps the hand edit", hand_case.get("position"), Vector2(300, 260)],
		["two on one node: nothing is left previewing", hand_case.get("table_left"), 0],
		["two on one node: a plain Stop on the first is noticed by the second", stop_case.get("second_kept"), true],
		["two on one node: and the node ends at rest", stop_case.get("position"), Vector2(100, 100)],
		["two on one node: nothing is left previewing after a plain Stop", stop_case.get("table_left"), 0],
	])


static func _two(script: GDScript, hand: Vector2) -> Dictionary:
	var host: Node2D = Node2D.new()
	host.position = Vector2(100, 100)
	var first: Node = script.new() as Node
	var second: Node = script.new() as Node
	for each: Node in [first, second]:
		each.set("host", host)
		each.set("_preview_own", script.call("_preview_values", each, true))
		each.set("_previewing", true)
	var rest: Dictionary = script.call("_preview_values", host, false)
	Engine.set_meta(TABLE, {host.get_instance_id(): {"rest": rest, "users": 2, "seen": rest.duplicate()}})
	host.position = Vector2(150, 100)
	first.call("_preview_note_seen")
	second.call("_preview_note_seen")
	if hand != Vector2.INF:
		host.position = hand
	var first_kept: Variant = first.call("_preview_keep_hand_edits")
	first.call("_preview_stop")
	var second_kept: Variant = second.call("_preview_keep_hand_edits")
	second.call("_preview_stop")
	var out: Dictionary = {"first_kept": first_kept, "second_kept": second_kept, "position": host.position, "table_left": (Engine.get_meta(TABLE) as Dictionary).size()}
	Engine.remove_meta(TABLE)
	first.free()
	second.free()
	host.free()
	return out


static func _wiring() -> bool:
	var ok: bool = true
	var sine: String = FileAccess.get_file_as_string(SINE)
	ok = SUPPORT.pins(TEST_NAME, [
		["the snapshot word", sine.contains("const _PREVIEW_SEEN: String = \"seen\""), true],
		["the snapshot is taken just before a frame is drawn", sine.contains("RenderingServer.frame_pre_draw.connect(_preview_note_seen)"), true],
		["the check runs at the start of the physics phase", sine.contains("physics_frame.connect(_preview_watch)"), true],
		["and at the start of the process phase", sine.contains("process_frame.connect(_preview_watch)"), true],
		["a save keeps a hand edit before it puts the rest back",
			sine.contains("elif what == NOTIFICATION_EDITOR_PRE_SAVE:\n\t\t_preview_keep_hand_edits()\n\t\t_preview_put_back(host, _preview_rest_of(host))\n\t\t_preview_note_seen()\n"), true],
		["Stop keeps a hand edit first", sine.contains("func _preview_stop() -> void:\n\tif not _previewing:\n\t\treturn\n\t_preview_keep_hand_edits()\n"), true],
		["the guard lines are the ones they were", sine.contains("func _process(delta: float) -> void:\n\tif Engine.is_editor_hint() and not _previewing:\n\t\treturn\n"), true],
	]) and ok
	for folder: String in PREVIEWING:
		var found: bool = false
		for file: String in DirAccess.get_files_at("res://eventsheet_addons/%s" % folder):
			if file.ends_with("_behavior.gd"):
				found = FileAccess.get_file_as_string("res://eventsheet_addons/%s/%s" % [folder, file]).contains("func _preview_keep_hand_edits() -> bool:")
		ok = SUPPORT.pin_value(TEST_NAME, "%s keeps a hand edit" % folder, found, true) and ok
	return ok
