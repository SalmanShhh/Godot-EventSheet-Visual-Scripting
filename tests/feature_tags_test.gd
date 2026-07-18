# Godot EventSheets - live feature-tag awareness: the Platform Has Feature combo reads the
# ENGINE tag set + every export preset's custom_features LIVE (never baked), unknown quoted
# tags are detectable (the commit nudge), and "add it for me" appends to the presets file.
# Pins: the cfg parse (preset sections only, dedup), suggestions order (custom first,
# quoted), is_known across both sources, literal_tag's expression guard, add_custom_tag's
# append + missing-file refusal, and the dialog's feature_tag hint factory registration.
@tool
class_name FeatureTagsTest
extends RefCounted

const CFG := "user://feature_tags_test_presets.cfg"


static func run() -> bool:
	var all_passed: bool = true

	if FileAccess.file_exists(CFG):
		DirAccess.remove_absolute(CFG)
	var presets: FileAccess = FileAccess.open(CFG, FileAccess.WRITE)
	presets.store_string("""[preset.0]

name="Windows Desktop"
platform="Windows Desktop"
custom_features="demo_mode, steam"

[preset.0.options]

custom_features="decoy_should_be_ignored"

[preset.1]

name="Web"
platform="Web"
custom_features="demo_mode,itch"
""")
	presets.close()

	# ---- the parse: preset sections only, deduped, file order ----
	all_passed = _check("custom tags parse from every preset section (options ignored, deduped)",
		EventSheetFeatureTags.custom_tags(CFG), PackedStringArray(["demo_mode", "steam", "itch"])) and all_passed
	all_passed = _check("a missing file parses to no custom tags",
		EventSheetFeatureTags.custom_tags("user://does_not_exist.cfg"), PackedStringArray()) and all_passed

	# ---- suggestions: custom first, quoted, engine set follows ----
	var pool: Array[String] = EventSheetFeatureTags.suggestions(CFG)
	all_passed = _check("suggestions lead with the project's own tags, quoted", pool[0], "\"demo_mode\"") and all_passed
	all_passed = _check("the engine set follows", pool.has("\"windows\"") and pool.has("\"template_release\""), true) and all_passed

	# ---- is_known across both sources ----
	all_passed = _check("engine tags are known", EventSheetFeatureTags.is_known("mobile", CFG), true) and all_passed
	# The FULL engine set (review regression: missing genuine tags made the nudge cry wolf).
	for engine_tag: String in ["x86_64", "arm64", "wasm32", "64", "double", "bptc", "astc", "linuxbsd"]:
		all_passed = _check("genuine engine tag %s is known" % engine_tag, EventSheetFeatureTags.is_known(engine_tag, CFG), true) and all_passed
	all_passed = _check("preset tags are known", EventSheetFeatureTags.is_known("steam", CFG), true) and all_passed
	all_passed = _check("an undeclared tag is unknown", EventSheetFeatureTags.is_known("vr_build", CFG), false) and all_passed

	# ---- literal_tag: only quoted literals are checkable; expressions never flag ----
	all_passed = _check("a quoted literal yields its bare tag", EventSheetFeatureTags.literal_tag("\"vr_build\""), "vr_build") and all_passed
	all_passed = _check("an expression is never flagged", EventSheetFeatureTags.literal_tag("current_platform_tag()"), "") and all_passed

	# ---- add it for me: appends to every preset, refuses a missing file ----
	all_passed = _check("add_custom_tag updates every preset lacking the tag", EventSheetFeatureTags.add_custom_tag("vr_build", CFG), 2) and all_passed
	all_passed = _check("the added tag is now known (live re-read)", EventSheetFeatureTags.is_known("vr_build", CFG), true) and all_passed
	all_passed = _check("re-adding is a no-op", EventSheetFeatureTags.add_custom_tag("vr_build", CFG), 0) and all_passed
	all_passed = _check("existing tags survive the append",
		EventSheetFeatureTags.custom_tags(CFG).has("steam") and EventSheetFeatureTags.custom_tags(CFG).has("itch"), true) and all_passed
	all_passed = _check("a missing presets file is never created", EventSheetFeatureTags.add_custom_tag("x", "user://does_not_exist.cfg"), 0) and all_passed

	# ---- the commit-validator seam: registered per hint, feature_tag rides it ----
	all_passed = _check("the feature_tag commit validator is registered through the API",
		EventSheets.param_commit_validator_for("feature_tag").is_valid(), true) and all_passed
	all_passed = _check("a known engine tag passes the validator silently",
		EventSheetFeatureTags.commit_validator("\"x86_64\"").is_empty(), true) and all_passed
	all_passed = _check("an expression is never prompted",
		EventSheetFeatureTags.commit_validator("current_tag()").is_empty(), true) and all_passed
	var validator_prompt: Dictionary = EventSheetFeatureTags.commit_validator("\"vr_build\"")
	all_passed = _check("an unknown literal returns the prompt spec",
		str(validator_prompt.get("confirm_text", "")), "Add To Preset(s)") and all_passed
	all_passed = _check("the prompt carries its on_confirm action",
		(validator_prompt.get("on_confirm", Callable()) as Callable).is_valid(), true) and all_passed

	# ---- the dialog wires the hint to the LIVE combo ----
	var dialog: ACEParamsDialog = ACEParamsDialog.new()
	dialog._ensure_hint_factories()
	all_passed = _check("the params dialog registers the feature_tag hint factory", dialog._hint_factories.has("feature_tag"), true) and all_passed

	DirAccess.remove_absolute(CFG)
	return all_passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		return true
	print("  [FAIL] feature_tags_test: %s (got %s, expected %s)" % [label, str(actual), str(expected)])
	return false
