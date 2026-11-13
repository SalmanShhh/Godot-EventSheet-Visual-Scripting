# Pack builder - storylet_resource (a data-driven Custom Resource; run via build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")


## StoryletResource: a whole storybook - many storylets with their requirements, choices, effects and
## meta - as ONE .tres data asset you fill in the Inspector, grid by grid. This is the data-driven half
## of the Storylet Weaver pack: instead of a wall of Define Storylet / Add Requirement / Add Effect
## actions on a sheet, a writer edits friendly tables (dropdowns for the comparison and effect operators,
## no JSON, no code), saves the .tres, and the Storylets autoload loads it in one step with Load From
## Resource. The same asset can seed a project; variants are other .tres files, and discrete ACEs can
## still tweak the library afterwards. A plain Resource (extends Resource), so it works with Godot's own
## Inspector and file system with no plugin at runtime.
##
## Because Inspector table cells hold scalars (a cell can't nest an array), a storylet's requirements /
## choices / effects live in SEPARATE grids joined by the `storylet` id column - the same parallel-grid
## shape UHTNPlanResource uses. Enum columns use the {type:enum, options:[...]} form (the string form
## enum(a|b) silently degrades to a plain text cell).
static func build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Resource"
	sheet.custom_class_name = "StoryletResource"
	sheet.addon_version = "1.0.0"
	sheet.class_description = "A whole storybook as a data asset: storylets with their requirements, choices, effects and meta, authored in Inspector grids. Load it into the Storylets autoload with Load From Resource - the data-driven alternative to a wall of Define Storylet actions."
	sheet.addon_category = "Storylets"
	sheet.addon_tags = PackedStringArray(["narrative", "storylet", "resource"])
	sheet.variables = {
		"choice_requirements": {"type": "Array", "default": [], "exported": true,
			"attributes": {"group": "Choices",
				"tooltip": "Rules a choice must pass to be offered, else it is hidden; same columns as Requirements.",
				"drawer": "table", "table_columns": [
					{"name": "storylet", "type": "String"},
					{"name": "choice_id", "type": "String"},
					{"name": "op", "type": "enum", "options": [{"key": "gte", "label": ">= (at least)"}, {"key": "gt", "label": "> (more than)"}, {"key": "lte", "label": "<= (at most)"}, {"key": "lt", "label": "< (less than)"}, {"key": "eq", "label": "= (equal to)"}, {"key": "neq", "label": "!= (not equal to)"}]},
					{"name": "key", "type": "String"},
					{"name": "value", "type": "String"},
					{"name": "value_is_key", "type": "bool"}]}},
		"choices": {"type": "Array", "default": [], "exported": true,
			"attributes": {"group": "Choices",
				"tooltip": "Player choices on a storylet: the `storylet` id, a `choice_id` (passed to Choose), and the button `text`.",
				"drawer": "table", "table_columns": [
					{"name": "storylet", "type": "String"},
					{"name": "choice_id", "type": "String"},
					{"name": "text", "type": "String"}]}},
		"choice_effects": {"type": "Array", "default": [], "exported": true,
			"attributes": {"group": "Effects",
				"tooltip": "Quality changes applied when a choice is picked; same columns as Effects.",
				"drawer": "table", "table_columns": [
					{"name": "storylet", "type": "String"},
					{"name": "choice_id", "type": "String"},
					{"name": "op", "type": "enum", "options": [{"key": "set", "label": "Set to"}, {"key": "inc", "label": "Increment by"}, {"key": "dec", "label": "Decrement by"}, {"key": "toggle", "label": "Toggle (0/1)"}, {"key": "delete", "label": "Delete key"}]},
					{"name": "key", "type": "String"},
					{"name": "value", "type": "String"}]}},
		"effects": {"type": "Array", "default": [], "exported": true,
			"attributes": {"group": "Effects",
				"tooltip": "Quality changes applied when a storylet is drawn: set, inc, dec, toggle or delete a key.",
				"drawer": "table", "table_columns": [
					{"name": "storylet", "type": "String"},
					{"name": "op", "type": "enum", "options": [{"key": "set", "label": "Set to"}, {"key": "inc", "label": "Increment by"}, {"key": "dec", "label": "Decrement by"}, {"key": "toggle", "label": "Toggle (0/1)"}, {"key": "delete", "label": "Delete key"}]},
					{"name": "key", "type": "String"},
					{"name": "value", "type": "String"}]}},
		"book_name": {"type": "String", "default": "storylets", "exported": true,
			"attributes": {"group": "Identity", "tooltip": "A readable name for this book (for your own reference; the engine does not use it)."}},
		"meta": {"type": "Array", "default": [], "exported": true,
			"attributes": {"group": "Meta",
				"tooltip": "Arbitrary key-value data attached to a storylet (a speaker, a portrait), read back with Active Meta / Storylet Meta. The engine never interprets it.",
				"drawer": "table", "table_columns": [
					{"name": "storylet", "type": "String"},
					{"name": "key", "type": "String"},
					{"name": "value", "type": "String"}]}},
		"requirements": {"type": "Array", "default": [], "exported": true,
			"attributes": {"group": "Requirements",
				"tooltip": "Rules a storylet needs to be eligible, all must pass: compare a quality, roll a chance, or gate on recent draws.",
				"drawer": "table", "table_columns": [
					{"name": "storylet", "type": "String"},
					{"name": "op", "type": "enum", "options": [{"key": "gte", "label": ">= (at least)"}, {"key": "gt", "label": "> (more than)"}, {"key": "lte", "label": "<= (at most)"}, {"key": "lt", "label": "< (less than)"}, {"key": "eq", "label": "= (equal to)"}, {"key": "neq", "label": "!= (not equal to)"}, {"key": "chance", "label": "Chance (0-100%)"}, {"key": "recent", "label": "Drawn in the last N"}, {"key": "not_recent", "label": "NOT drawn in the last N"}]},
					{"name": "key", "type": "String"},
					{"name": "value", "type": "String"},
					{"name": "value_is_key", "type": "bool"}]}},
		"storylets": {"type": "Array", "default": [], "exported": true,
			"attributes": {"group": "Storylets",
				"tooltip": "One row per storylet: id, title, body, weight, cooldown seconds and max plays; -1 is unlimited.",
				"drawer": "table", "table_columns": [
					{"name": "id", "type": "String"},
					{"name": "title", "type": "String"},
					{"name": "body", "type": "String"},
					{"name": "weight", "type": "float"},
					{"name": "cooldown", "type": "float"},
					{"name": "max_plays", "type": "int"}], "table_weight_column": "weight"}}
	}
	return Lib.save_pack(sheet, "res://eventsheet_addons/storylet_resource/storylet_resource")
