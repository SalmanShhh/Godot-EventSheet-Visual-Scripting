# Godot EventSheets - a row that changes a card changes only its own object.
#
# THE FAULT THIS PINS: copies of one scene copy a Feedback Player's list but SHARE the card
# dictionaries inside it, so a row that changed a card on one enemy changed it on every enemy made
# from that scene, including ones spawned later. The pins here use a REAL scene file on disk and
# instance it more than once, because a player built with .new() never shares anything and would
# pass for the wrong reason.
@tool
class_name FeedbackPlayerOwnCardsTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const PLAYER := preload("res://eventsheet_addons/juice/feedback_player.gd")

const TEST_NAME: String = "feedback_player_own_cards"

## Where the scene is written. Under user://, and taken away again at the end of the run.
const SCENE_PATH: String = "user://feedback_player_own_cards_test.tscn"
const RESAVED_PATH: String = "user://feedback_player_own_cards_test_resaved.tscn"
const MOMENT_PATH: String = "user://feedback_player_own_cards_moment.tres"


static func run() -> bool:
	var ok: bool = true
	ok = _row_pins() and ok
	ok = _copy_pins() and ok
	ok = _untouched_pins() and ok
	ok = _resource_pins() and ok
	for path: String in [SCENE_PATH, RESAVED_PATH, MOMENT_PATH]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	return ok


static func _cards() -> Array[Dictionary]:
	var list: Array[Dictionary] = [
		{"verb": "shake", "label": "kick", "amount": 0.4, "seconds": 0.2, "delay": 0.1, "interval": 0.5, "loops": 2},
		{"verb": "flash", "label": "glow", "amount": 1.0, "seconds": 0.1}
	]
	return list


## Saves a scene holding one player and returns the packed scene read back from disk.
static func _scene(cards: Array[Dictionary]) -> PackedScene:
	var root: Node = PLAYER.new()
	root.name = "Enemy"
	root.steps = cards
	var packed: PackedScene = PackedScene.new()
	packed.pack(root)
	root.free()
	ResourceSaver.save(packed, SCENE_PATH)
	return ResourceLoader.load(SCENE_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene


static func _amount(player: Node, at: int) -> Variant:
	return (player.steps[at] as Dictionary).get("amount", null)


static func _rows() -> Array:
	return [
		["Set Feedback Field", func(p: Node) -> void: p.set_feedback_field("kick", "amount", 0.9), "amount", 0.9],
		["Set Feedback Timing", func(p: Node) -> void: p.set_feedback_timing("kick", 0.7, 3, 0.2, "game"), "delay", 0.7],
		["Set Feedback Chance", func(p: Node) -> void: p.set_feedback_chance("kick", 25.0), "chance", 25.0],
		["Set Feedback Label", func(p: Node) -> void: p.set_feedback_label("kick", "punch"), "label", "punch"],
		["Disable Feedback", func(p: Node) -> void: p.disable_feedback("kick"), "active", false],
		["Set Loop Count", func(p: Node) -> void: p.set_loop_count("kick", 9), "loops", 9],
		["Scale Feedback Amounts", func(p: Node) -> void: p.scale_feedback_amounts("", 0.5), "amount", 0.2],
		["Retime Feedbacks", func(p: Node) -> void: p.retime_feedbacks(0.5), "seconds", 0.1],
		["Replace Feedback", func(p: Node) -> void: p.replace_feedback("kick", {"verb": "recoil", "label": "kick"}), "verb", "recoil"],
		["Pick One Feedback Of", func(p: Node) -> void: p.pick_one_feedback_of("kick"), "active", true]
	]


## Every row that writes into a card: the edited object changes, the copy made before it and the
## copy made after it do not.
static func _row_pins() -> bool:
	var ok: bool = true
	for row: Array in _rows():
		var scene: PackedScene = _scene(_cards())
		var first: Node = scene.instantiate()
		var before: Node = scene.instantiate()
		var change: Callable = row[1]
		change.call(first)
		var after: Node = scene.instantiate()
		var key: String = row[2]
		var saved: Variant = (_cards()[0] as Dictionary).get(key, null)
		ok = SUPPORT.pins(TEST_NAME, [
			[str(row[0]) + ": the edited object has the change", (first.steps[0] as Dictionary).get(key, null), row[3]],
			[str(row[0]) + ": a copy made before is untouched", (before.steps[0] as Dictionary).get(key, null), saved],
			[str(row[0]) + ": a copy made after is untouched", (after.steps[0] as Dictionary).get(key, null), saved],
			[str(row[0]) + ": the other card of the same copy is untouched", _amount(after, 1), 1.0]
		]) and ok
		first.free()
		before.free()
		after.free()
	return ok


## Copy Feedbacks From gives a COPY: changing either list afterwards leaves the other alone. Load
## Moment File and Duplicate Feedback still do what their words say.
static func _copy_pins() -> bool:
	var scene: PackedScene = _scene(_cards())
	var source: Node = scene.instantiate()
	var taker: Node = scene.instantiate()
	taker.copy_feedbacks_from(source)
	taker.set_feedback_field("kick", "amount", 0.8)
	var third: Node = scene.instantiate()
	source.set_feedback_field("glow", "amount", 0.3)
	var ok: bool = SUPPORT.pins(TEST_NAME, [
		["changing the copy leaves the source alone", _amount(source, 0), 0.4],
		["changing the source leaves the copy alone", _amount(taker, 1), 1.0],
		["the copy carries the change made to it", _amount(taker, 0), 0.8],
		["a third copy of the scene is untouched by either", [_amount(third, 0), _amount(third, 1)], [0.4, 1.0]]
	])
	var duplicated: Node = scene.instantiate()
	duplicated.duplicate_feedback("kick", "kick2")
	duplicated.set_feedback_field("kick2", "amount", 0.11)
	var fresh: Node = scene.instantiate()
	ok = SUPPORT.pins(TEST_NAME, [
		["Duplicate Feedback puts the copy under the original", [duplicated.steps.size(), str((duplicated.steps[1] as Dictionary).get("label", ""))], [3, "kick2"]],
		["and the original keeps its amount", _amount(duplicated, 0), 0.4],
		["and the scene's next copy has two cards still", [fresh.steps.size(), _amount(fresh, 0)], [2, 0.4]]
	]) and ok
	var saver: Node = scene.instantiate()
	saver.save_moment_file(MOMENT_PATH)
	var loader: Node = scene.instantiate()
	loader.load_moment_file(MOMENT_PATH)
	loader.set_feedback_field("shake", "amount", 0.66)
	var again: Node = scene.instantiate()
	again.load_moment_file(MOMENT_PATH)
	ok = SUPPORT.pins(TEST_NAME, [
		["Load Moment File brings the beat in as this player's own list", [loader.steps.size(), _amount(loader, 0)], [2, 0.66]],
		["and retuning it does not write into the file", _amount(again, 0), 0.4]
	]) and ok
	for node: Node in [source, taker, third, duplicated, fresh, saver, loader, again]:
		node.free()
	return ok


## Nothing is copied or written on load, and a list no row changes costs no copy.
static func _untouched_pins() -> bool:
	var scene: PackedScene = _scene(_cards())
	var first: Node = scene.instantiate()
	var second: Node = scene.instantiate()
	var shared: bool = is_same(first.steps[0], second.steps[0])
	var text_before: String = _without_ids(FileAccess.get_file_as_string(SCENE_PATH))
	var reloaded: PackedScene = ResourceLoader.load(SCENE_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	var probe: Node = reloaded.instantiate()
	var repacked: PackedScene = PackedScene.new()
	repacked.pack(probe)
	ResourceSaver.save(repacked, RESAVED_PATH)
	var text_after: String = _without_ids(FileAccess.get_file_as_string(RESAVED_PATH))
	var ok: bool = SUPPORT.pins(TEST_NAME, [
		["a list no row has changed costs no copy", shared, true],
		["a scene loaded and saved again is the same text", text_after == text_before, true]
	])
	first.set_feedback_field("nobody", "amount", 0.5)
	ok = SUPPORT.check(TEST_NAME, "a row that finds no such card leaves the other object's list alone", _amount(second, 0), 0.4) and ok
	probe.free()
	first.free()
	second.free()
	return ok


## A resource on a card (a curve, a stream) stays the very same resource after the cards are copied.
static func _resource_pins() -> bool:
	var curve: Curve = Curve.new()
	var list: Array[Dictionary] = [{"verb": "shake", "label": "kick", "amount": 0.4, "ease_curve": curve}]
	var player: Node = PLAYER.new()
	player.steps = list
	var original: Dictionary = player.steps[0]
	player.set_feedback_field("kick", "amount", 0.5)
	var ok: bool = SUPPORT.pins(TEST_NAME, [
		["the card was copied", is_same(player.steps[0], original), false],
		["the resource on it was not", (player.steps[0] as Dictionary).get("ease_curve") == curve, true],
		["the original card keeps its amount", original.get("amount"), 0.4]
	])
	player.free()
	return ok


## A scene's text without the node and resource ids a fresh pack hands out, which differ on every save and say
## nothing about the card lists.
static func _without_ids(text: String) -> String:
	var ids: RegEx = RegEx.new()
	ids.compile(" unique_id=\\d+|\\d_[a-z0-9]{5}")
	return ids.sub(text, "", true)
