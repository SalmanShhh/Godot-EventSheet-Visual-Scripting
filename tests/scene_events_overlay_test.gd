# Godot EventSheets - the events overlay (V14): which nodes have events, and which events.
#
# Pins VALUES: the exact triggers a script's badge names, in file order and in the sheet's own
# words; that a plain function is never counted as an event; that both connect spellings are read;
# that a script with no triggers wears no badge at all; and that the overlay is off until asked for.
@tool
class_name SceneEventsOverlayTest
extends RefCounted


static func run() -> bool:
	var all_passed: bool = true
	all_passed = _test_off_by_default() and all_passed
	all_passed = _test_lifecycle_triggers() and all_passed
	all_passed = _test_connected_handlers() and all_passed
	all_passed = _test_nothing_to_mark() and all_passed
	all_passed = _test_badge_words() and all_passed
	return all_passed


static func _test_off_by_default() -> bool:
	return _check("the overlay is off until asked for",
		bool(ProjectSettings.get_setting(EventSheetSceneEvents.SETTING_SHOW_EVENTS, false)), false)


## The handlers that ARE triggers on their own, read in the sheet's own words.
static func _test_lifecycle_triggers() -> bool:
	var source: String = "extends CharacterBody2D\n\n\nfunc _ready():\n\tpass\n\n\nfunc _physics_process(delta):\n\tpass\n\n\nfunc heal(amount):\n\tpass\n"
	var ids: PackedStringArray = EventSheetSceneEvents.trigger_ids_in_source(source)
	var passed: bool = _check("the two lifecycle handlers are the two triggers",
		", ".join(ids), "OnReady, OnPhysicsProcess")
	passed = _check("a plain function is not an event", Array(ids).has("heal"), false) and passed
	return passed


## A handler something connects a signal to IS that signal's trigger - in both spellings people
## write, and through the engine's own trigger id where there is one.
static func _test_connected_handlers() -> bool:
	var member_form: String = "extends Node2D\n\n\nfunc _ready():\n\t$Hurtbox.body_entered.connect(_on_hurt)\n\t$Door.connect(\"pressed\", _on_door)\n\n\nfunc _on_hurt(body):\n\tpass\n\n\nfunc _on_door():\n\tpass\n"
	var ids: PackedStringArray = EventSheetSceneEvents.trigger_ids_in_source(member_form)
	var passed: bool = _check("the connected handlers ride their own triggers",
		", ".join(ids), "OnReady, OnBodyEntered, signal:pressed")
	return passed


## A script with no triggers at all is unmarked - that is the whole point of the overlay.
static func _test_nothing_to_mark() -> bool:
	var source: String = "extends RefCounted\n\n\nfunc total(items):\n\treturn items.size()\n"
	var badge: Dictionary = {"count": EventSheetSceneEvents.trigger_ids_in_source(source).size()}
	var passed: bool = _check("a script with no triggers has no events", int(badge.get("count", -1)), 0)
	passed = _check("and so wears no badge", EventSheetSceneEvents.badge_text(badge), "") and passed
	return passed


## What the badge and its hover actually say.
static func _test_badge_words() -> bool:
	var source: String = "extends CharacterBody2D\n\n\nfunc _ready():\n\t$Hurtbox.body_entered.connect(_on_hurt)\n\n\nfunc _process(delta):\n\tpass\n\n\nfunc _on_hurt(body):\n\tpass\n"
	var words: PackedStringArray = PackedStringArray()
	for trigger_id: String in EventSheetSceneEvents.trigger_ids_in_source(source):
		var probe: EventRow = EventRow.new()
		probe.trigger_provider_id = "Core" if not trigger_id.begins_with("signal:") else ""
		probe.trigger_id = trigger_id
		words.append(EventSheetArrangement.trigger_words(probe))
	var badge: Dictionary = {"count": words.size(), "triggers": words}
	var passed: bool = _check("the badge counts the events", EventSheetSceneEvents.badge_text(badge), "⌗ 3")
	passed = _check("and the hover names the triggers",
		EventSheetSceneEvents.badge_tooltip(badge),
		"On created · Every tick (draw) · On collision with") and passed
	return passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] scene_events_overlay_test: %s" % label)
		return true
	print("[FAIL] scene_events_overlay_test: %s - expected %s, got %s" % [label, str(expected), str(actual)])
	return false
