# Godot EventSheets - third-wave pack verbs: Health invincibility frames and the HUD Kit
# floating-text popup.
#
# Health grew a timed i-frame window (Grant Invincibility / Is Invincible) plus the gate that
# makes it mean something: Take Damage returns early while the window is open, BEFORE any HP
# is spent and before On Damaged fires. HUD Kit grew Pop Floating Text, the damage-number verb
# that spawns its own Label, tweens it and frees it.
#
# The health half runs for real (treeless: Time.get_ticks_msec needs no scene tree); the HUD Kit
# half is source-pinned only, since a spawned Label needs a tree to tween in - except the one part
# of it that is a decision rather than a drawing: Pop Floating Text As takes a number's colour from
# a DamageTypeSet, and that set is a real file, so what it answers is run.
@tool
class_name ThirdWavePacksTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const HEALTH_PACK := "res://eventsheet_addons/health/health_behavior.gd"
const HUD_KIT_PACK := "res://eventsheet_addons/hud_kit/hud_kit_behavior.gd"
const TYPE_SET_STARTER := "res://eventsheet_addons/damage_type_set_resource/damage_types.tres"


static func run() -> bool:
	var all_passed: bool = true
	all_passed = _emitted_source() and all_passed
	all_passed = _invincibility_runtime() and all_passed
	all_passed = _the_coloured_popup() and all_passed
	return all_passed


## The verbs and the gate survive into the shipped packs.
static func _emitted_source() -> bool:
	var all_passed: bool = true
	var health_source: String = FileAccess.get_file_as_string(HEALTH_PACK)
	all_passed = _check("health pack emits Grant Invincibility", health_source.contains("func grant_invincibility(seconds: float) -> void:"), true) and all_passed
	all_passed = _check("health pack stamps the clock", health_source.contains("_invincible_until = Time.get_ticks_msec() + int(maxf(seconds, 0.0) * 1000.0)"), true) and all_passed
	all_passed = _check("health pack emits Is Invincible", health_source.contains("func is_invincible() -> bool:"), true) and all_passed
	all_passed = _check("Is Invincible publishes as a condition", health_source.contains("## @ace_condition\n## @ace_name(\"Is Invincible\")"), true) and all_passed
	# THE gate: invincible damage never reaches the pools, the HP maths or on_damaged.emit().
	all_passed = _check("Take Damage gates on invincibility", health_source.contains("if amount <= 0.0 or invulnerable or is_dead_flag or is_invincible():"), true) and all_passed

	var hud_source: String = FileAccess.get_file_as_string(HUD_KIT_PACK)
	all_passed = _check("hud_kit pack emits Pop Floating Text", hud_source.contains("func pop_floating_text(text: String, at: Vector2, color: Color) -> void:"), true) and all_passed
	all_passed = _check("the popup drifts up", hud_source.contains("pop.tween_property(label, \"position:y\", at.y - 24.0, 0.7)"), true) and all_passed
	all_passed = _check("the popup fades out", hud_source.contains("pop.tween_property(label, \"modulate:a\", 0.0, 0.7)"), true) and all_passed
	all_passed = _check("the popup frees itself", hud_source.contains("pop.tween_callback(label.queue_free)"), true) and all_passed
	return all_passed


## POP FLOATING TEXT AS: the half that can be run, and the half that cannot.
##
## The colour is DECIDED by the DamageTypeSet and only ASKED FOR by the row, so the deciding is run
## against the shipped starter file, and the asking is pinned in the emitted text - a spawned Label
## needs a tree to tween in, so the row itself cannot be driven here.
##
## "crit" is a STYLE rather than a kind, which is why the set does not name it and the number is
## marked by its SIZE instead: a set that did name it would colour it too, and both would be true at
## once. The white fallback is the same promise the other way round - a game with no set at all
## still gets its numbers.
static func _the_coloured_popup() -> bool:
	var all_passed: bool = true
	var hud_source: String = FileAccess.get_file_as_string(HUD_KIT_PACK)
	all_passed = _check("hud_kit pack emits Pop Floating Text As", hud_source.contains("func pop_floating_text_as(text: String, style: String, at: Vector2) -> void:"), true) and all_passed
	all_passed = _check("the colour comes from the set, not from the row", hud_source.contains("tint = damage_types.call(\"colour_of\", style)"), true) and all_passed
	all_passed = _check("and is asked for rather than cast for", hud_source.contains("if damage_types != null and damage_types.has_method(\"colour_of\"):"), true) and all_passed
	all_passed = _check("a game with no set still gets its numbers", hud_source.contains("var tint: Color = Color.WHITE"), true) and all_passed
	all_passed = _check("a crit is marked by its size", hud_source.contains("label.scale = Vector2(crit_text_scale, crit_text_scale)"), true) and all_passed
	var starter: Resource = load(TYPE_SET_STARTER)
	if starter == null:
		return _check("the starter damage type set loads", false, true) and all_passed
	return SUPPORT.pins("third_wave_packs_test", [
		["fire is drawn in the colour the starter names",
			starter.call("colour_of", "fire"), Color(1.0, 0.45, 0.1, 1.0)],
		["and a style the set does not name is drawn white",
			starter.call("colour_of", "crit"), Color.WHITE]
	]) and all_passed


## The i-frame window really opens and really closes (no tree needed: it is one clock read).
static func _invincibility_runtime() -> bool:
	var all_passed: bool = true
	var script: GDScript = load(HEALTH_PACK)
	all_passed = _check("health pack loads + parses", script != null, true) and all_passed
	if script == null:
		return all_passed

	var health: Node = script.new()
	all_passed = _check("a fresh behavior is not invincible", health.is_invincible(), false) and all_passed
	health.grant_invincibility(10.0)
	all_passed = _check("Grant Invincibility opens the window", health.is_invincible(), true) and all_passed
	health.take_damage(25.0)
	all_passed = _check("invincible damage costs no HP", health.current_health, 100.0) and all_passed
	health._invincible_until = 0
	all_passed = _check("the window closes on its own clock", health.is_invincible(), false) and all_passed
	health.take_damage(25.0)
	all_passed = _check("damage lands again once it closes", health.current_health, 75.0) and all_passed

	health.free()
	return all_passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check("third_wave_packs_test", label, actual, expected)
