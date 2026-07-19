# Godot EventSheets - juice pack (screenshake / zoom / squash & stretch) smoke + trauma equivalence.
#
# Loads the COMPILED juice pack and drives the trauma integrator directly. The headless runner has no
# live viewport, so the auto-found camera is null - which is exactly the path we want to prove is SAFE:
# Shake still accrues + decays trauma, and the camera/host effects no-op instead of crashing. The
# visual side (actual offset/zoom/scale tweens) is verified in-editor, not here.
@tool
class_name JuicePackTest
extends RefCounted

const PACK := "res://eventsheet_addons/juice/juice_behavior.gd"


static func run() -> bool:
	var all_passed: bool = true
	var script: GDScript = load(PACK)
	all_passed = _check("juice pack loads + parses", script != null, true) and all_passed
	if script == null:
		return all_passed

	var behavior: Node = script.new()
	# Shake accrues trauma and decays back to rest.
	behavior.shake(0.6)
	all_passed = _check("shake starts a shake", behavior.is_shaking(), true) and all_passed
	all_passed = _check("trauma reflects the shake strength", is_equal_approx(behavior.current_trauma(), 0.6), true) and all_passed
	behavior.shake(2.0)
	all_passed = _check("trauma clamps to 1.0", behavior.current_trauma() <= 1.0, true) and all_passed
	for _i in 200:
		behavior._process(0.1)
		if not behavior.is_shaking():
			break
	all_passed = _check("shake decays back to rest", behavior.is_shaking(), false) and all_passed

	# Stop Shake clears trauma immediately.
	behavior.shake(0.5)
	behavior.stop_shake()
	all_passed = _check("stop_shake clears the shake", behavior.is_shaking(), false) and all_passed

	# With no live camera/host, the camera + transform effects must no-op (not crash).
	behavior.squash_and_stretch(0.3, 0.2)
	behavior.spring_squash(0.3)
	behavior.clear_slowmo()
	behavior.zoom_by_percent(150.0, 0.2)
	behavior.zoom_to_position(Vector2(100, 100), 150.0, 0.2)
	behavior.zoom_toward_point(Vector2(50, 50), 150.0, 0.2)
	behavior.use_camera(NodePath("Nonexistent"))
	all_passed = _check("camera/host effects no-op safely without a camera or host", true, true) and all_passed

	# Slowmo + spring-squash compiled in (the runtime tween needs a live tree - verified in-editor).
	all_passed = _check("slowmo + clear_slowmo + spring_squash actions exist", behavior.has_method("slowmo") and behavior.has_method("clear_slowmo") and behavior.has_method("spring_squash"), true) and all_passed
	all_passed = _check("slowmo helpers + On Slowmo Finished signal exist", behavior.has_method("_set_time_scale") and behavior.has_method("_slowmo_trans") and behavior.has_method("_apply_host_scale") and behavior.has_signal("slowmo_finished"), true) and all_passed

	# Hitstop: the action + Is Hitstopped condition + On Hitstop Finished trigger are compiled in (the
	# freeze itself runs on a realtime SceneTree timer, which needs a live tree - verified in-editor).
	all_passed = _check("hitstop action + Is Hitstopped condition + On Hitstop Finished signal exist", behavior.has_method("hitstop") and behavior.has_method("is_hitstopped") and behavior.has_signal("hitstop_finished"), true) and all_passed
	behavior._hitstop_active = true
	all_passed = _check("Is Hitstopped reflects the freeze state", behavior.is_hitstopped(), true) and all_passed
	# Teardown safety: a scene change mid-FREEZE must un-freeze the whole game (time_scale back to 1.0)
	# AND clear the flag, so the still-pending realtime timer no-ops when it fires instead of restoring a
	# stale scale. Without this, quitting to a menu during a hitstop would leave the menu frozen.
	Engine.time_scale = 0.0
	behavior._on_tree_exiting()
	all_passed = _check("tree-exit teardown un-freezes a mid-hitstop game + clears the flag", is_equal_approx(Engine.time_scale, 1.0) and not behavior.is_hitstopped(), true) and all_passed

	# Teardown safety (D1): leaving the tree mid-slowmo restores the GLOBAL Engine.time_scale, so a scene
	# change during slow motion can't leave the whole game running slow.
	all_passed = _check("a tree-exit teardown handler exists", behavior.has_method("_on_tree_exiting"), true) and all_passed
	Engine.time_scale = 0.25
	behavior._on_tree_exiting()
	all_passed = _check("tree-exit teardown restores Engine.time_scale", is_equal_approx(Engine.time_scale, 1.0), true) and all_passed

	# The spring-squash integrator springs the scale back to rest (the math runs in the tick; no live host needed).
	behavior.squash_damping = 0.9
	behavior._base_scale = Vector2.ONE
	behavior._squash_value = Vector2(1.3, 0.7)
	behavior._squash_velocity = Vector2.ZERO
	behavior._squash_spring_active = true
	for _k in 3000:
		behavior._process(0.016)
		if not behavior._squash_spring_active:
			break
	all_passed = _check("spring squash settles back to rest", behavior._squash_spring_active, false) and all_passed
	all_passed = _check("spring squash returns to base scale", behavior._squash_value.is_equal_approx(Vector2.ONE), true) and all_passed

	# The camera-feel verbs (recoil / head bob / jitter / tilt): state advances camera-or-not.
	behavior.recoil_recovery = 140.0
	behavior.recoil(-90.0, 12.0)
	all_passed = _check("recoil kicks the offset in the given direction", (behavior._recoil_vec as Vector2).is_equal_approx(Vector2(0.0, -12.0)), true) and all_passed
	behavior._process(0.05)
	all_passed = _check("recoil springs back at the recovery rate", is_equal_approx((behavior._recoil_vec as Vector2).length(), 12.0 - 140.0 * 0.05), true) and all_passed
	for _r in 200:
		behavior._process(0.1)
	all_passed = _check("recoil settles fully", behavior._recoil_vec == Vector2.ZERO, true) and all_passed
	behavior.start_head_bob(6.0, 2.2)
	all_passed = _check("head bob starts", behavior._bob_active, true) and all_passed
	behavior._process(0.1)
	all_passed = _check("head bob advances its clock", behavior._bob_time > 0.0, true) and all_passed
	behavior.stop_head_bob()
	all_passed = _check("head bob stops", behavior._bob_active, false) and all_passed
	behavior.start_jitter(3.0)
	all_passed = _check("jitter starts", behavior._jitter_active, true) and all_passed
	behavior.stop_jitter()
	all_passed = _check("jitter stops", behavior._jitter_active, false) and all_passed
	all_passed = _check("tilt action + On Tilt Finished trigger exist (tween needs a live tree)", behavior.has_method("tilt_to") and behavior.has_signal("tilt_finished"), true) and all_passed

	# ── The composable wave: flash/blink, punches, kick-from-point, trail, screen FX,
	# audio, tickers (tween-driven visuals need a live tree; state + safety pin here). ──
	all_passed = _check("flash + punches + On Flash/Punch Finished exist",
		behavior.has_method("flash") and behavior.has_method("punch_scale")
		and behavior.has_method("punch_rotation") and behavior.has_method("punch_position")
		and behavior.has_signal("flash_finished") and behavior.has_signal("punch_finished"), true) and all_passed
	behavior.start_blinking(10.0, 0.2)
	all_passed = _check("blink starts with its rate", behavior._blink_active and is_equal_approx(behavior._blink_rate, 10.0), true) and all_passed
	behavior.stop_blinking()
	all_passed = _check("blink stops", behavior._blink_active, false) and all_passed
	behavior.start_ghost_trail(20.0, 0.4, Color(1, 1, 1, 0.5))
	all_passed = _check("ghost trail starts (interval from stamps/second)", behavior._trail_active and is_equal_approx(behavior._trail_interval, 0.05), true) and all_passed
	behavior._process(0.06)  # off-tree: the stamp must no-op safely, not crash
	behavior.stop_ghost_trail()
	all_passed = _check("ghost trail stops + stamping off-tree is safe", behavior._trail_active, false) and all_passed
	behavior.kick_away_from(Vector2(100, 100), 14.0)
	all_passed = _check("kick-from-point no-ops without a camera", (behavior._recoil_vec as Vector2), Vector2.ZERO) and all_passed
	behavior.pulse_vignette(0.5, Color(0.4, 0, 0), 0.3)
	behavior.chromatic_kick(0.5, 0.2)
	behavior.set_speed_lines(0.5)
	all_passed = _check("screen FX no-op safely off-tree (overlay defers to first in-tree use)", behavior._fx_layer == null, true) and all_passed
	behavior.play_sound_varied("res://nonexistent.ogg", 0.1, 2.0)
	behavior.play_sound_intensity("res://nonexistent.ogg", 0.8)
	all_passed = _check("one-shot audio with a missing file is safe", true, true) and all_passed
	behavior.set_ticker("score", 40.0)
	all_passed = _check("set_ticker writes the displayed value", is_equal_approx(behavior.ticker_value("score"), 40.0), true) and all_passed
	all_passed = _check("unknown tickers read 0", is_equal_approx(behavior.ticker_value("nope"), 0.0), true) and all_passed
	all_passed = _check("count_to + On Ticker Finished exist (tween needs a live tree)",
		behavior.has_method("count_to") and behavior.has_signal("ticker_finished"), true) and all_passed

	# Engine.time_scale must not leak to other tests.
	all_passed = _check("Engine.time_scale restored to 1.0", is_equal_approx(Engine.time_scale, 1.0), true) and all_passed

	behavior.free()
	return all_passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] juice_pack_test: %s" % label)
		return true
	print("[FAIL] juice_pack_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
