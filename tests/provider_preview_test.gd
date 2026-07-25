# EventSheet - the ACE provider preview ("what will this script publish?").
#
# Registering one of your own scripts used to be an act of faith. EventSheetProviderPreview.scan() answers
# it first, through the SAME generator call the registry makes, so the preview cannot drift from what
# actually ships. This pins the inference contract it reports (which member becomes which kind of verb),
# the warnings that stop a registration from disappointing, and that a bad path fails closed instead of
# crashing the dialog.
@tool
class_name ProviderPreviewTest
extends RefCounted

const TYPED := "res://tests/fixtures/typed_provider_fixture.gd"
const UNTYPED := "res://tests/fixtures/untyped_provider_fixture.gd"


static func run() -> bool:
	var ok: bool = true

	# ── A typed script: every member lands in its proper lane ──
	var typed: Dictionary = EventSheetProviderPreview.scan(TYPED)
	ok = _check("a typed provider scans", typed.get("ok", false), true) and ok
	ok = _check("the provider id comes from class_name", typed.get("provider_id", ""), "TypedProviderFixture") and ok
	ok = _check("a signal reads as a Trigger", _label_of(typed, "signal:wave_started"), "On Wave Started") and ok
	ok = _check("its kind is Trigger", _kind_of(typed, "signal:wave_started"), "Trigger") and ok
	ok = _check("a void method reads as an Action", _kind_of(typed, "method:start_wave"), "Action") and ok
	ok = _check("a bool method reads as a Condition", _kind_of(typed, "method:is_wave_active"), "Condition") and ok
	ok = _check("and drops its is_ prefix", _label_of(typed, "method:is_wave_active"), "Wave Active") and ok
	ok = _check("a value method reads as an Expression", _kind_of(typed, "method:current_multiplier"), "Expression") and ok
	ok = _check("an @export publishes a reader", _kind_of(typed, "property:difficulty"), "Expression") and ok
	ok = _check("and a writer", _kind_of(typed, "set:difficulty"), "Action") and ok
	ok = _check("the emitted code is shown for a property write",
		_emits_of(typed, "set:difficulty"), "__eventsheet_provider_TypedProviderFixture.difficulty = {value}") and ok
	ok = _check("a typed script raises no untyped warning", _has_warning(typed, "untyped"), false) and ok
	ok = _check("nor a class_name warning", _has_warning(typed, "no_class_name"), false) and ok
	# 8 = the trigger, the four from the float @export (read + set + add + subtract), and the three methods.
	ok = _check("the summary counts the verbs", str(EventSheetProviderPreview.summary_line(typed)).begins_with("8 verbs - "), true) and ok

	# ── The realistic case: untyped and class_name-less, so the preview must set expectations ──
	var untyped: Dictionary = EventSheetProviderPreview.scan(UNTYPED)
	ok = _check("an untyped provider still scans", untyped.get("ok", false), true) and ok
	ok = _check("an untyped bool method falls back to an Action", _kind_of(untyped, "method:is_wave_active"), "Action") and ok
	ok = _check("so the untyped warning fires", _has_warning(untyped, "untyped"), true) and ok
	ok = _check("naming both untyped methods", _warning_text(untyped, "untyped").contains("start_wave") and _warning_text(untyped, "untyped").contains("is_wave_active"), true) and ok
	ok = _check("the class_name warning fires and names the fallback id",
		_warning_text(untyped, "no_class_name").contains("UntypedProviderFixture"), true) and ok
	ok = _check("and that fallback id is a valid identifier (no space)",
		str(untyped.get("provider_id", "")).contains(" "), false) and ok

	# ── Fails closed: a bad path returns a reason, never a crash or a half-built table ──
	var missing: Dictionary = EventSheetProviderPreview.scan("res://tests/fixtures/does_not_exist.gd")
	ok = _check("a missing script fails closed", missing.get("ok", true), false) and ok
	ok = _check("with a reason", str(missing.get("reason", "")).is_empty(), false) and ok
	ok = _check("and no entries", (missing.get("entries", []) as Array).size(), 0) and ok
	ok = _check("the summary shows the reason", EventSheetProviderPreview.summary_line(missing), str(missing.get("reason", ""))) and ok
	var not_a_script: Dictionary = EventSheetProviderPreview.scan("res://project.godot")
	ok = _check("a non-script path fails closed", not_a_script.get("ok", true), false) and ok

	return ok


static func _entry(scan_result: Dictionary, ace_id: String) -> Dictionary:
	for entry: Variant in scan_result.get("entries", []):
		if str((entry as Dictionary).get("ace_id", "")) == ace_id:
			return entry
	return {}


static func _kind_of(scan_result: Dictionary, ace_id: String) -> String:
	return str(_entry(scan_result, ace_id).get("kind_label", "(absent)"))


static func _label_of(scan_result: Dictionary, ace_id: String) -> String:
	return str(_entry(scan_result, ace_id).get("label", "(absent)"))


static func _emits_of(scan_result: Dictionary, ace_id: String) -> String:
	return str(_entry(scan_result, ace_id).get("emits", "(absent)"))


static func _has_warning(scan_result: Dictionary, kind: String) -> bool:
	return not _warning_text(scan_result, kind).is_empty()


static func _warning_text(scan_result: Dictionary, kind: String) -> String:
	for warning: Variant in scan_result.get("warnings", []):
		if str((warning as Dictionary).get("kind", "")) == kind:
			return str((warning as Dictionary).get("text", ""))
	return ""


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] provider_preview_test: %s" % label)
		return true
	print("[FAIL] provider_preview_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
