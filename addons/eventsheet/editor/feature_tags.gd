# Godot EventSheets - live feature-tag awareness (the input_action live-picker pattern)
#
# The truth about which feature tags EXIST in a project lives in two places: the engine's
# built-in tags (platform / build kind / capabilities) and each export preset's
# custom_features line in export_presets.cfg. This helper reads BOTH live - at
# dialog-open, never baked - so the Platform Has Feature combo suggests the project's own
# tags, an unknown tag can be flagged before it silently returns false at runtime, and
# "add it for me" can append the tag to the presets. All statics take the cfg path as a
# parameter so tests pin them against a temp file.
@tool
class_name EventSheetFeatureTags
extends RefCounted

const PRESETS_PATH := "res://export_presets.cfg"

## The engine's own tags - platforms, build kinds, architectures, bitness, precision, and
## texture-compression formats (the Godot feature-tags reference set). A genuine tag
## missing here makes the unknown-tag nudge cry wolf, so keep this complete.
const ENGINE_TAGS: PackedStringArray = [
	"mobile", "pc", "web", "android", "ios", "windows", "linux", "macos", "bsd", "linuxbsd",
	"editor", "debug", "release", "template", "template_debug", "template_release",
	"movie", "threads", "touchscreen", "system_fonts",
	"x86_64", "x86_32", "x86", "arm64", "arm32", "arm", "rv64", "ppc64", "ppc32", "wasm32",
	"32", "64", "double", "single",
	"etc", "etc2", "s3tc", "bptc", "astc"
]


## Custom tags declared by ANY export preset's custom_features line, deduped, in file order.
static func custom_tags(presets_path: String = PRESETS_PATH) -> PackedStringArray:
	var tags: PackedStringArray = PackedStringArray()
	var presets: ConfigFile = ConfigFile.new()
	if presets.load(presets_path) != OK:
		return tags
	for section: String in presets.get_sections():
		if not _is_preset_section(section):
			continue
		for tag: String in _parse_features(str(presets.get_value(section, "custom_features", ""))):
			if not tags.has(tag):
				tags.append(tag)
	return tags


## ONE parser for a custom_features line (trim, drop empties) - custom_tags and
## add_custom_tag both read through it, so "is this tag present?" can never disagree
## between the nudge's check and the append.
static func _parse_features(raw: String) -> PackedStringArray:
	var tags: PackedStringArray = PackedStringArray()
	for tag: String in raw.split(","):
		var clean: String = tag.strip_edges()
		if not clean.is_empty():
			tags.append(clean)
	return tags


## The live suggestion pool for a feature-tag combo: the project's custom tags FIRST
## (they're what the user defined on purpose), then the engine set - quoted, ready to
## compile as OS.has_feature("tag").
static func suggestions(presets_path: String = PRESETS_PATH) -> Array[String]:
	var quoted: Array[String] = []
	for tag: String in custom_tags(presets_path):
		quoted.append("\"%s\"" % tag)
	for tag: String in ENGINE_TAGS:
		var quoted_tag: String = "\"%s\"" % tag
		if not quoted.has(quoted_tag):
			quoted.append(quoted_tag)
	return quoted


## True when the tag (unquoted) is engine-defined or declared by an export preset.
static func is_known(tag: String, presets_path: String = PRESETS_PATH) -> bool:
	return ENGINE_TAGS.has(tag) or custom_tags(presets_path).has(tag)


## The bare tag inside a quoted string literal ("" when the value is an expression, not a
## literal - expressions can't be checked, so they are never flagged as unknown).
static func literal_tag(value: String) -> String:
	var trimmed: String = value.strip_edges()
	if trimmed.length() >= 2 and trimmed.begins_with("\"") and trimmed.ends_with("\"") and not trimmed.trim_prefix("\"").trim_suffix("\"").contains("\""):
		return trimmed.trim_prefix("\"").trim_suffix("\"")
	return ""


## Appends the tag to EVERY preset's custom_features (the "add it for me" path). Returns
## the number of presets updated - 0 when the file is missing or every preset already has
## it. Never creates export_presets.cfg: presets are the Export dialog's file to create.
static func add_custom_tag(tag: String, presets_path: String = PRESETS_PATH) -> int:
	var clean: String = tag.strip_edges()
	if clean.is_empty():
		return 0
	var presets: ConfigFile = ConfigFile.new()
	if presets.load(presets_path) != OK:
		return 0
	var updated: int = 0
	for section: String in presets.get_sections():
		if not _is_preset_section(section):
			continue
		var tags: PackedStringArray = _parse_features(str(presets.get_value(section, "custom_features", "")))
		if tags.has(clean):
			continue
		tags.append(clean)
		presets.set_value(section, "custom_features", ",".join(tags))
		updated += 1
	if updated > 0 and presets.save(presets_path) != OK:
		return 0  # a failed write (read-only / locked file) must never report success
	return updated


## The commit-time validator the params dialog runs for feature_tag fields (registered
## through EventSheets.register_param_commit_validator - the generic seam). {} = fine;
## an unknown quoted literal returns the prompt spec, whose on_confirm appends the tag.
static func commit_validator(value: String) -> Dictionary:
	var tag: String = literal_tag(value)
	if tag.is_empty() or is_known(tag):
		return {}
	return {
		"title": "Unknown Feature Tag",
		"message": "\"%s\" isn't defined by Godot or any export preset, so OS.has_feature(\"%s\") will be false at runtime.\n\nAdd it to your export preset(s) now? Presets manage feature tags under Project > Export > Features." % [tag, tag],
		"confirm_text": "Add To Preset(s)",
		"cancel_text": "Keep As Is",
		"on_confirm": func() -> void:
			if add_custom_tag(tag) == 0:
				push_warning("[EventSheets] Couldn't write the tag - if export_presets.cfg doesn't exist yet (or the Export dialog holds unsaved changes), add \"%s\" under Project > Export > Features." % tag)
	}


## A top-level [preset.N] section (not its [preset.N.options] companion).
static func _is_preset_section(section: String) -> bool:
	if not section.begins_with("preset."):
		return false
	return section.trim_prefix("preset.").is_valid_int()
