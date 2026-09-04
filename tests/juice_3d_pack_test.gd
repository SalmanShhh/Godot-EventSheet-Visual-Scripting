# Godot EventSheets - Juice 3D pack (camera shake / recoil / bob / jitter / lean / FOV).
#
# Loads the COMPILED pack and drives the effect integrators directly. Headless there is no
# viewport camera, which is exactly the path to prove SAFE: every effect's STATE still advances
# (trauma decays, recoil re-centres, the FOV kick recovers) while the camera apply no-ops. The
# additive apply/unapply itself is pinned against a real Camera3D node.
@tool
class_name Juice3DPackTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const PACK := "res://eventsheet_addons/juice_3d/juice_3d_behavior.gd"


static func run() -> bool:
	var all_passed: bool = true
	var script: GDScript = load(PACK)
	all_passed = _check("juice 3d pack loads + parses", script != null, true) and all_passed
	if script == null:
		return all_passed

	var behavior: Node = script.new()
	# Shake accrues trauma and decays back to rest with no camera present.
	behavior.shake(0.6)
	all_passed = _check("shake starts a shake", behavior.is_shaking(), true) and all_passed
	all_passed = _check("trauma reflects the shake strength", is_equal_approx(behavior.current_trauma(), 0.6), true) and all_passed
	behavior.shake(2.0)
	all_passed = _check("trauma clamps to 1.0", behavior.current_trauma() <= 1.0, true) and all_passed
	for _i in 200:
		behavior._process(0.1)
		if not behavior.is_shaking():
			break
	all_passed = _check("shake decays back to rest without a camera", behavior.is_shaking(), false) and all_passed
	behavior.shake(0.5)
	behavior.stop_shake()
	all_passed = _check("stop_shake clears the shake", behavior.is_shaking(), false) and all_passed

	# Recoil kicks accumulate and re-centre at the recovery rate.
	behavior.set("recoil_recovery", 30.0)
	behavior.recoil(1.5, 0.0)
	behavior.recoil(1.5, 0.0)
	all_passed = _check("recoil kicks stack", is_equal_approx(float(behavior.get("_recoil_pitch")), 3.0), true) and all_passed
	behavior._process(0.05)
	all_passed = _check("recoil re-centres at the recovery rate", is_equal_approx(float(behavior.get("_recoil_pitch")), 3.0 - 30.0 * 0.05), true) and all_passed
	for _j in 200:
		behavior._process(0.1)
	all_passed = _check("recoil settles fully", is_equal_approx(float(behavior.get("_recoil_pitch")), 0.0), true) and all_passed

	# FOV punch recovers on its own; bob and jitter are simple toggles.
	behavior.fov_punch(8.0)
	all_passed = _check("fov punch kicks", is_equal_approx(float(behavior.get("_fov_kick")), 8.0), true) and all_passed
	for _k in 200:
		behavior._process(0.1)
	all_passed = _check("fov punch recovers to zero", is_equal_approx(float(behavior.get("_fov_kick")), 0.0), true) and all_passed
	behavior.start_head_bob(0.06, 2.0)
	all_passed = _check("head bob starts", bool(behavior.get("_bob_active")), true) and all_passed
	behavior.stop_head_bob()
	all_passed = _check("head bob stops", bool(behavior.get("_bob_active")), false) and all_passed
	behavior.start_jitter(0.02, 0.5)
	all_passed = _check("jitter starts", bool(behavior.get("_jitter_active")), true) and all_passed
	behavior.stop_jitter()
	all_passed = _check("jitter stops", bool(behavior.get("_jitter_active")), false) and all_passed

	# Tween-driven verbs + triggers are compiled in (tweens need a live tree - verified in-editor).
	all_passed = _check("lean + zoom + use_camera actions exist", behavior.has_method("lean") and behavior.has_method("zoom_fov_to") and behavior.has_method("use_camera"), true) and all_passed
	all_passed = _check("the finish triggers exist", behavior.has_signal("shake_stopped") and behavior.has_signal("lean_finished") and behavior.has_signal("zoom_finished"), true) and all_passed

	# The additive apply/unapply against a real camera: offsets go on, then come off exactly.
	var camera: Camera3D = Camera3D.new()
	camera.position = Vector3(1.0, 2.0, 3.0)
	camera.rotation = Vector3(0.1, 0.2, 0.3)
	camera.fov = 75.0
	behavior.set("_last_camera", camera)
	behavior.set("_applied_position", Vector3(0.0, 0.05, 0.0))
	behavior.set("_applied_rotation", Vector3(0.02, 0.0, 0.0))
	behavior.set("_applied_fov", 8.0)
	camera.position += Vector3(0.0, 0.05, 0.0)
	camera.rotation += Vector3(0.02, 0.0, 0.0)
	camera.fov += 8.0
	behavior._unapply()
	all_passed = _check("unapply restores the camera position exactly", camera.position.is_equal_approx(Vector3(1.0, 2.0, 3.0)), true) and all_passed
	all_passed = _check("unapply restores the camera rotation exactly", camera.rotation.is_equal_approx(Vector3(0.1, 0.2, 0.3)), true) and all_passed
	all_passed = _check("unapply restores the camera fov exactly", is_equal_approx(camera.fov, 75.0), true) and all_passed
	all_passed = _check("unapply zeroes the applied ledger", Vector3(behavior.get("_applied_position")) == Vector3.ZERO and is_equal_approx(float(behavior.get("_applied_fov")), 0.0), true) and all_passed

	# Teardown hands the camera back clean (a scene change mid-shake must not strand offsets).
	all_passed = _check("a tree-exit teardown handler exists", behavior.has_method("_on_tree_exiting"), true) and all_passed

	# ── The composable wave: kick-from-point, blink, punches, screen FX, audio, tickers ──
	behavior.set("kick_recovery", 0.6)
	behavior.kick_away_from(Vector3(0, -1, 0), 0.12)
	all_passed = _check("kick-from-point no-ops without a camera", Vector3(behavior.get("_kick_vec")), Vector3.ZERO) and all_passed
	behavior.set("_kick_vec", Vector3(0.12, 0.0, 0.0))
	behavior._process(0.05)
	all_passed = _check("a kick re-centres at the recovery rate",
		is_equal_approx(Vector3(behavior.get("_kick_vec")).length(), 0.12 - 0.6 * 0.05), true) and all_passed
	behavior.start_blinking(10.0)
	all_passed = _check("blink starts", bool(behavior.get("_blink_active")), true) and all_passed
	behavior.stop_blinking()
	all_passed = _check("blink stops", bool(behavior.get("_blink_active")), false) and all_passed
	all_passed = _check("punches + On Punch Finished exist",
		behavior.has_method("punch_scale") and behavior.has_method("punch_position") and behavior.has_signal("punch_finished"), true) and all_passed
	behavior.pulse_vignette(0.5, Color(0.4, 0, 0), 0.3)
	behavior.chromatic_kick(0.5, 0.2)
	behavior.set_speed_lines(0.5)
	all_passed = _check("screen FX no-op safely off-tree (overlay defers to first in-tree use)", behavior.get("_fx_layer") == null, true) and all_passed
	behavior.play_sound_varied("res://nonexistent.ogg", 0.1, 2.0)
	behavior.play_sound_intensity("res://nonexistent.ogg", 0.8)
	behavior.set_ticker("score", 40.0)
	all_passed = _check("set_ticker writes the displayed value", is_equal_approx(float(behavior.ticker_value("score")), 40.0), true) and all_passed
	all_passed = _check("count_to + On Ticker Finished exist (tween needs a live tree)",
		behavior.has_method("count_to") and behavior.has_signal("ticker_finished"), true) and all_passed

	# ── Chromatic shake: the same split over the 3D overlay. Pinned by VALUE through the emitted
	# script's own tick. There is no _noise here (script.new() never runs _ready), which is the
	# off-tree path this whole file drives: the wander reads zero, so the magnitudes are exact. ──
	behavior.set_process(false)                 # so "the verb woke the tick" means what it says
	behavior.chromatic_shake(12.0, 0.4, "reducing", -1.0)
	all_passed = _check("chromatic shake starts", behavior.is_chromatic_shaking(), true) and all_passed
	all_passed = _check("a shake opens at the magnitude it was asked for", behavior.chromatic_shake_magnitude(), 12.0) and all_passed
	all_passed = _check("a running shake keeps the tick awake", behavior.is_processing(), true) and all_passed
	behavior._process(0.1)
	all_passed = _check("a reducing shake falls linearly (a quarter of 0.4 s spent)", behavior.chromatic_shake_magnitude(), 9.0) and all_passed
	behavior._process(0.1)
	all_passed = _check("a reducing shake keeps falling (half of 0.4 s spent)", behavior.chromatic_shake_magnitude(), 6.0) and all_passed
	behavior.chromatic_shake(12.0, 0.4, "reducing", -1.0)
	all_passed = _check("firing again RESTARTS the shake instead of stacking on it", behavior.chromatic_shake_magnitude(), 12.0) and all_passed
	behavior.stop_chromatic_shake()
	all_passed = _check("Stop Chromatic Shake takes it off at once", behavior.is_chromatic_shaking(), false) and all_passed
	all_passed = _check("a stopped shake reads zero magnitude", behavior.chromatic_shake_magnitude(), 0.0) and all_passed
	behavior.chromatic_shake(10.0, 0.3, "constant", -1.0)
	behavior._process(0.1)
	behavior._process(0.1)
	all_passed = _check("a constant shake holds its magnitude flat", behavior.chromatic_shake_magnitude(), 10.0) and all_passed
	behavior._process(0.15)
	all_passed = _check("a constant shake stops dead when the duration is up", behavior.is_chromatic_shaking(), false) and all_passed
	all_passed = _check("the ended shake parks the tick again", behavior.is_processing(), false) and all_passed
	behavior.chromatic_shake(12.0, 0.4, "reducing", 90.0)
	all_passed = _check("a fixed angle points the split down that line",
		Vector2(behavior._chroma_shake_direction()).is_equal_approx(Vector2(0.0, 1.0)), true) and all_passed
	behavior.stop_chromatic_shake()
	# ── The WANDERING direction, which is the one a row opens with. Everything above runs with no
	# noise at all (script.new() never runs _ready), so the default path - the only one a designer
	# meets without typing an angle - is the one path the rest of this file cannot see. A noise is
	# seeded by hand here and taken away again afterwards, and the question asked of it is the whole
	# promise of the verb: a direction one pixel long, so the magnitude the row asks for and the
	# expression answers is the width the screen is actually given. ──
	behavior._noise = FastNoiseLite.new()
	behavior._noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	behavior._noise.frequency = 1.0
	behavior._noise.seed = 20260904
	behavior.chromatic_shake(12.0, 10.0, "constant", -1.0)
	var off_the_unit: int = 0
	var angles_seen: Dictionary = {}
	for step: int in range(120):
		behavior._chroma_shake_phase = float(step) * 0.05
		var walked: Vector2 = behavior._chroma_shake_direction()
		if not is_equal_approx(walked.length(), 1.0):
			off_the_unit += 1
		angles_seen[int(roundf(walked.angle() * 8.0))] = true
	all_passed = _check("every wandering direction is one pixel long", off_the_unit, 0) and all_passed
	all_passed = _check("and the split still wanders rather than sitting still", angles_seen.size() > 8, true) and all_passed
	# Written out to three places rather than compared as a float: snapping a float and comparing it
	# to a literal is the pin that passes here and flakes on the runner by one ulp.
	all_passed = _check("so the shift handed to the shader is as wide as the expression says",
		"%.3f" % (Vector2(behavior._chroma_shake_direction()).length() * behavior.chromatic_shake_magnitude()),
		"12.000") and all_passed
	# And turning no flashing on part way through a shake SLOWS the wander from here on rather than
	# jumping it: the clock already carries the rate, so the sample the noise is read at does not
	# move under the setting. The two readings are taken in the same frame, either side of the meta.
	var wander_before: float = behavior._chroma_shake_wander()
	Engine.set_meta("no_flashing", true)
	var wander_after: float = behavior._chroma_shake_wander()
	Engine.remove_meta("no_flashing")
	all_passed = _check("the anti-strobe setting slows the wander without teleporting it",
		wander_after, wander_before) and all_passed
	behavior.stop_chromatic_shake()
	behavior._noise = null
	Engine.set_meta("no_flashing", true)
	behavior.chromatic_shake(12.0, 0.4, "reducing", -1.0)
	all_passed = _check("no flashing halves the magnitude", behavior.chromatic_shake_magnitude(), 6.0) and all_passed
	all_passed = _check("no flashing halves the wander rate", behavior._chroma_shake_rate(), float(behavior.get("shake_frequency")) * 0.5) and all_passed
	behavior.stop_chromatic_shake()
	Engine.remove_meta("no_flashing")
	all_passed = _check("the no-flashing meta is not left behind for other tests", Engine.has_meta("no_flashing"), false) and all_passed
	# The falloff is spent once, on the shift. The shader mixes the shaken taps in by chroma_intensity,
	# so writing the fade into that dial as well would square the curve and a reducing shake would be
	# a quarter of itself half way through while the expression answered half. Off the tree there is
	# no material to read the dial back from, so the pinned thing is the line the pack ships.
	var pack_source: String = FileAccess.get_file_as_string(PACK)
	all_passed = _check("the shake's mix dial is a gate rather than a second copy of the falloff",
		pack_source.contains("_fx_material.set_shader_parameter(\"chroma_intensity\", 1.0)"), true) and all_passed
	# And the shake's four extra reads of the screen per pixel are behind a gate: the overlay is on
	# screen for a vignette, a kick or speed lines too, and those frames must not pay for a shake
	# that is not running.
	all_passed = _check("the overlay pays for the shake's extra taps only while a shake runs",
		pack_source.contains("if (chroma_intensity > 0.0) {"), true) and all_passed
	# The overlay shader itself compiles headless: a shader that fails to build reports NO uniforms,
	# so the sorted uniform list is both the compile check and the shake's two new dials.
	var fx_shader: Shader = Shader.new()
	fx_shader.code = str(script.get_script_constant_map().get("_FX_SHADER", ""))
	var fx_uniforms: PackedStringArray = PackedStringArray()
	for entry: Dictionary in fx_shader.get_shader_uniform_list(true):
		fx_uniforms.append(str(entry.get("name", "")))
	fx_uniforms.sort()
	all_passed = _check("the overlay shader compiles and carries the shake's dials", ",".join(fx_uniforms),
		"chroma_intensity,chroma_shift,chroma_strength,speed_lines,vignette_color,vignette_strength") and all_passed

	camera.free()
	behavior.free()
	return all_passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check("juice_3d_pack_test", label, actual, expected)
