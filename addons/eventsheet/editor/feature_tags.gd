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

## The engine's own tags (platforms, build kinds, capabilities) - always defined.
const ENGINE_TAGS: PackedStringArray = [
	"mobile", "pc", "web", "android", "ios", "windows", "linux", "macos",
	"editor", "debug", "release", "template", "template_debug", "template_release",
	"movie", "threads", "touchscreen", "etc2", "s3tc"
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
		for tag: String in str(presets.get_value(section, "custom_features", "")).split(","):
			var clean: String = tag.strip_edges()
			if not clean.is_empty() and not tags.has(clean):
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
		var existing: String = str(presets.get_value(section, "custom_features", ""))
		var tags: PackedStringArray = PackedStringArray()
		for entry: String in existing.split(","):
			if not entry.strip_edges().is_empty():
				tags.append(entry.strip_edges())
		if tags.has(clean):
			continue
		tags.append(clean)
		presets.set_value(section, "custom_features", ",".join(tags))
		updated += 1
	if updated > 0:
		presets.save(presets_path)
	return updated


## A top-level [preset.N] section (not its [preset.N.options] companion).
static func _is_preset_section(section: String) -> bool:
	if not section.begins_with("preset."):
		return false
	return section.trim_prefix("preset.").is_valid_int()
