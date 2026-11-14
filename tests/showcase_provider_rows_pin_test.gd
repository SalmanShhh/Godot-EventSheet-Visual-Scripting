@tool
class_name ShowcaseProviderRowsPinTest
extends RefCounted

# Godot EventSheets - the behaviour rows the showcase builder places still match the pack vocabulary.
#
# tools/build_examples.gd writes a few dozen rows of shipped behaviours straight into the showcase
# scenes, each with its template spelled out. Those baked templates are what the scenes compile, so a
# change to how a script is read must never quietly make the pack's own template a different string
# from the one the showcase holds. This pins the relationship as it stands: every such row is found in
# the vocabulary of the pack it names, and the few rows whose spelled-out template is a baked form of
# the pack's template (the node path filled in) or a hand-tuned variant are listed by name, so a new
# difference is a failure and an old one cannot vanish unseen.

const SUPPORT := preload("res://tests/support.gd")
const BUILDER_PATH: String = "res://tools/build_examples.gd"

## `<provider>::<ace_id>` rows whose spelled-out template is not the pack's template string, and why:
## the node path is baked in (`$ScreenFx.` where the pack says `{target}.`), or the showcase quotes an
## argument the pack leaves bare. Each was read off the builder and the pack, and each is a placed row
## that keeps compiling the string it holds.
const KNOWN_DIFFERENT: PackedStringArray = [
	"BlendModesAddon::method:blend_as",
	"JuiceBehavior::method:chromatic_shake",
	"JuiceBehavior::method:moment",
	"ScreenFx::method:add_post_effect",
	"ScreenFx::method:pulse_post_effect",
	"ScreenFx::method:save_look",
	"ScreenFx::method:use_look",
	"SceneFlowBehavior::method:reload_scene_with",
	"UtilityBrain::method:add_consideration",
]


static func run() -> bool:
	var literals: Array = _builder_rows()
	var vocabulary: Dictionary = _pack_vocabulary()
	var missing: PackedStringArray = PackedStringArray()
	var different: Dictionary = {}
	var matched: int = 0
	for row: Dictionary in literals:
		var key: String = "%s::%s" % [row["provider"], row["ace_id"]]
		if str(row["provider"]) == "Core":
			continue
		if not vocabulary.has(key):
			if not missing.has(key):
				missing.append(key)
			continue
		var packed: String = str((vocabulary[key] as ACEDefinition).metadata.get("codegen_template", ""))
		if packed == str(row["template"]):
			matched += 1
		else:
			different[key] = true
	var different_keys: Array = different.keys()
	different_keys.sort()
	var known: Array = Array(KNOWN_DIFFERENT)
	known.sort()
	return SUPPORT.pins("showcase_provider_rows_pin_test", [
		["the builder places pack rows at all", literals.size() > 50, true],
		["every pack row the builder places is in its pack's vocabulary", missing, PackedStringArray()],
		["most rows spell the pack's own template", matched >= 30, true],
		["the rows whose spelled-out template differs are exactly the known ones", different_keys, known],
	])


## Every `_action("<provider>", "<ace id>", "<template>", ...)` the builder writes with literal text.
static func _builder_rows() -> Array:
	var rows: Array = []
	var text: String = FileAccess.get_file_as_string(BUILDER_PATH)
	var pattern: RegEx = RegEx.create_from_string(r'_action\("([A-Za-z0-9_]+)", "([^"]+)", "((?:[^"\\]|\\.)*)"')
	for found: RegExMatch in pattern.search_all(text):
		rows.append({
			"provider": found.get_string(1),
			"ace_id": found.get_string(2),
			"template": found.get_string(3).replace("\\\"", "\"").replace("\\\\", "\\"),
		})
	return rows


## `<provider id>::<ace id>` -> definition, over every scanned pack script.
static func _pack_vocabulary() -> Dictionary:
	var vocabulary: Dictionary = {}
	var generator: EventSheetACEGenerator = EventSheetACEGenerator.new()
	for path: String in EventSheetAddonScanner.list_addon_scripts():
		var script: Script = load(path) as Script
		if script == null:
			continue
		for definition: ACEDefinition in generator.reflect_script(script):
			vocabulary["%s::%s" % [definition.provider_id, definition.id]] = definition
	return vocabulary
