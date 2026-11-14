# Godot EventSheets - Encounter Timeline keeps its saved state exactly as it was.
#
# The plan is held as small Beat records in memory and written to a save as plain dictionaries, the
# same five keys as always. The old form below was produced by the pack BEFORE the records existed:
# it must load, play on from where it was, and save again as the identical text.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const P := "encounter_timeline_saved_state_test"
const PACK := "res://eventsheet_addons/encounter_timeline/encounter_timeline_behavior.gd"
## Written by the pack before the change: three beats, the clock at 3 s, the cursor on the third.
const OLD_STATE := '{"clock":3.0,"encounter_name":"","entries":[{"at":0.0,"count":0,"group":"","note":"","scene":""},{"at":2.5,"count":3,"group":"wave","note":"opening","scene":"res://wave_a.tscn"},{"at":10.0,"count":1,"group":"","note":"late, note","scene":"res://wave_b.tscn"}],"finished":false,"next":2,"running":true,"spawned":0}'


static func run() -> bool:
	var script: GDScript = load(PACK)
	var old_state: Dictionary = JSON.parse_string(OLD_STATE)
	var restored: Node = script.new()
	restored.load_state(old_state)
	var again: String = JSON.stringify(restored.save_state(), "", true)
	var ok: bool = SUPPORT.pins(P, [
		["an old-form state loads every beat", restored.entry_count(), 3],
		["it loads the clock and the cursor", [restored.elapsed_seconds(), restored.next_entry_seconds()], [3.0, 10.0]],
		["a beat's note survives the trip", restored.entry_note_at(2), "late, note"],
		["saving it again gives the identical text", again, OLD_STATE],
	])
	# A state with a key missing or a stray element still loads, as a state read from a file may.
	var sparse: Node = script.new()
	sparse.load_state({"entries": [{"at": 1.5}, "stray", {"scene": "res://x.tscn", "count": 2}]})
	ok = SUPPORT.pins(P, [
		["a record missing keys reads the defaults and a stray element is dropped", sparse.entry_count(), 2],
		["and the defaults save out under the same five keys",
			JSON.stringify(sparse.save_state()["entries"][0], "", true),
			JSON.stringify({"at": 1.5, "count": 1, "group": "", "note": "", "scene": ""}, "", true)],
	]) and ok
	sparse.free()
	restored.free()
	return ok
