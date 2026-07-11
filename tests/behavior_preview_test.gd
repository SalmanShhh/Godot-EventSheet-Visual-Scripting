# Godot EventSheets - in-editor behavior preview (the C3-style "see it move in the editor").
#
# Pins the two halves of the feature:
# 1. The contract: the Sine pack's emitted static editor_preview_sample(params, base, time) is
#    pure math - exact values pinned for every movement mode, the active gate, and the clamp.
# 2. The service: EventSheetBehaviorPreview discovers the static on an attached behavior, applies
#    samples to the host each tick, and stop() restores the host EXACTLY (the editor scene must
#    end byte-identical). Plus the EventSheets.register_editor_preview override channel.
@tool
class_name BehaviorPreviewTest
extends RefCounted

const SINE_PATH := "res://eventsheet_addons/sine/sine_behavior.gd"


## Minimal dock stand-in: the service only needs add_child (for its Timer) and _set_status.
class StubDock:
	extends Control
	var last_status: String = ""

	func _set_status(message: String, _warn: bool = false) -> void:
		last_status = message


static func run() -> bool:
	var passed: bool = true
	var sine: Script = load(SINE_PATH)

	# ── 1. The sampler contract (pure math, exact values) ──────────────────────────────
	var base: Dictionary = {"position": Vector2(100.0, 200.0), "rotation": 0.0, "scale": Vector2.ONE, "modulate": Color.WHITE}
	# period 4, time 1 -> quarter cycle -> sin peak (1.0) -> full magnitude.
	var params: Dictionary = {"movement": "horizontal", "wave": "sine", "period": 4.0, "magnitude": 50.0, "phase_degrees": 0.0, "active": true}
	var sampled: Dictionary = sine.call("editor_preview_sample", params, base, 1.0)
	passed = _check("horizontal peak offsets x by magnitude", sampled.get("position"), Vector2(150.0, 200.0)) and passed
	params["movement"] = "vertical"
	sampled = sine.call("editor_preview_sample", params, base, 1.0)
	passed = _check("vertical peak offsets y by magnitude", sampled.get("position"), Vector2(100.0, 250.0)) and passed
	params["movement"] = "angle"
	sampled = sine.call("editor_preview_sample", params, base, 1.0)
	passed = _check("angle mode returns a rotation", is_equal_approx(float(sampled.get("rotation", 0.0)), 50.0 * 0.0174533), true) and passed
	params["movement"] = "size"
	sampled = sine.call("editor_preview_sample", params, base, 1.0)
	passed = _check("size mode scales by 1 + magnitude percent", sampled.get("scale"), Vector2.ONE * 1.5) and passed
	params["movement"] = "opacity"
	params["magnitude"] = 200.0
	sampled = sine.call("editor_preview_sample", params, base, 1.0)
	passed = _check("opacity clamps to 1.0 at the top", (sampled.get("modulate") as Color).a, 1.0) and passed
	sampled = sine.call("editor_preview_sample", params, base, 3.0)
	passed = _check("opacity clamps to 0.0 at the bottom", (sampled.get("modulate") as Color).a, 0.0) and passed
	params["active"] = false
	sampled = sine.call("editor_preview_sample", params, base, 1.0)
	passed = _check("inactive behavior samples nothing", sampled.is_empty(), true) and passed
	params["active"] = true
	params["movement"] = "horizontal"
	params["wave"] = "square"
	sampled = sine.call("editor_preview_sample", params, base, 1.0)
	passed = _check("square wave holds +1 in the first half cycle", sampled.get("position"), Vector2(300.0, 200.0)) and passed
	params["movement"] = "value-only"
	sampled = sine.call("editor_preview_sample", params, base, 1.0)
	passed = _check("value-only drives no host property", sampled.is_empty(), true) and passed

	# ── 2. The service: discover, drive, restore ────────────────────────────────────────
	var dock: StubDock = StubDock.new()
	var service: EventSheetBehaviorPreview = EventSheetBehaviorPreview.new()
	service.init(dock)
	var host: Node2D = Node2D.new()
	host.name = "Player"
	host.position = Vector2(100.0, 200.0)
	var behavior: Node = sine.new()
	behavior.set("movement", "horizontal")
	behavior.set("period", 4.0)
	behavior.set("magnitude", 50.0)
	host.add_child(behavior)

	passed = _check("the sampler static is discovered on the emitted pack script",
		EventSheetBehaviorPreview._has_preview_static(sine), true) and passed
	var exported: Dictionary = EventSheetBehaviorPreview._exported_values(behavior)
	passed = _check("exported values read off the scene instance", exported.get("magnitude"), 50.0) and passed
	passed = _check("non-exported script vars ride along too (harmless)", exported.has("time"), true) and passed

	service.start(host)
	passed = _check("start finds one previewable behavior", service._entries.size(), 1) and passed
	passed = _check("start reports what it is previewing", dock.last_status.contains("Previewing 1 behavior"), true) and passed
	# Drive ticks manually (headless: the Timer is not in a tree). 30 ticks at 1/30s = 1.0s = peak.
	for tick_index: int in range(30):
		service._tick()
	passed = _check("ticking moves the host to the sampled peak", host.position, Vector2(150.0, 200.0)) and passed
	service.stop()
	passed = _check("stop restores the host exactly", host.position, Vector2(100.0, 200.0)) and passed
	passed = _check("stop clears the entries", service._entries.size(), 0) and passed

	# A node with no previewable behaviors reports instead of silently doing nothing.
	var bare: Node2D = Node2D.new()
	bare.name = "Bare"
	service.start(bare)
	passed = _check("a bare node reports no previewable behaviors", dock.last_status.contains("No previewable behaviors"), true) and passed

	# ── 3. The API override channel ─────────────────────────────────────────────────────
	var sampler_calls: Array = []
	EventSheets.register_editor_preview(SINE_PATH, func(_params: Dictionary, sampler_base: Dictionary, _time: float) -> Dictionary:
		sampler_calls.append(true)
		return {"position": (sampler_base.get("position") as Vector2) + Vector2(7.0, 0.0)})
	passed = _check("registered sampler is resolvable",
		EventSheets.editor_preview_sampler_for(SINE_PATH).is_valid(), true) and passed
	service.start(host)
	service._tick()
	passed = _check("a registered sampler takes priority over the static", host.position, Vector2(107.0, 200.0)) and passed
	passed = _check("the registered sampler was actually called", sampler_calls.size(), 1) and passed
	service.stop()
	passed = _check("stop restores after the override too", host.position, Vector2(100.0, 200.0)) and passed
	EventSheets._editor_preview_samplers.clear()

	host.free()
	bare.free()
	dock.free()
	return passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] behavior_preview_test: %s" % label)
		return true
	print("[FAIL] behavior_preview_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
