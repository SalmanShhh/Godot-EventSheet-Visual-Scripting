# Pack builder - uhtn_plan_resource (a data-driven Custom Resource; run via build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")


## UHTNPlanResource: a whole UHTN plan - the task network AND its utility scorers - as one .tres data
## asset you fill in the Inspector, grid by grid. This is the data-driven half of the UHTN Planning pack:
## a designer authors tasks, methods, preconditions, and scoring curves in friendly tables (dropdowns for
## task kinds, comparison operators, and response curves - no JSON, no code), saves the .tres, and drops
## it onto a UHTNPlanner's Plan Resource slot. The same asset can drive a hundred enemies; variants are
## other .tres files. It is a plain Resource with exported fields, so it works with Godot's own Inspector
## and file system with no plugin at runtime.
static func build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Resource"
	sheet.custom_class_name = "UHTNPlanResource"
	sheet.class_description = "A complete UHTN plan (utility-driven Hierarchical Task Network) as a data asset: the tasks, the methods that decompose them (ranked by utility scorers), their preconditions, and the scoring curves - all authored in Inspector grids. Drop the saved .tres onto a UHTNPlanner's Plan Resource slot."
	sheet.variables = {
		"plan_name": {"type": "String", "default": "plan", "exported": true,
			"attributes": {"group": "Identity", "tooltip": "A readable name for this plan (shown in debug output)."}},
		"root_task": {"type": "String", "default": "", "exported": true,
			"attributes": {"group": "Identity", "required": true,
				"tooltip": "The goal the planner decomposes - name a compound (usually) or primitive task from the Tasks grid."}},
		"conditions": {"type": "Array", "default": [], "exported": true,
			"attributes": {"group": "Task Network",
				"tooltip": "Preconditions per method: a world-state key, a comparison and a value.",
				"drawer": "table", "table_columns": [
					{"name": "method", "type": "String"},
					{"name": "key", "type": "String"},
					{"name": "op", "type": "enum(==|!=|<|<=|>|>=)"},
					{"name": "value", "type": "String"}]}},
		"methods": {"type": "Array", "default": [], "exported": true,
			"attributes": {"group": "Task Network",
				"tooltip": "Ways to accomplish each compound task, ranked by an optional scorer.",
				"drawer": "table", "table_columns": [
					{"name": "task", "type": "String"},
					{"name": "method", "type": "String"},
					{"name": "subtasks", "type": "String"},
					{"name": "scorer", "type": "String"},
					{"name": "utility", "type": "float"}]}},
		"tasks": {"type": "Array", "default": [], "exported": true,
			"attributes": {"group": "Task Network",
				"tooltip": "Every task: primitives your sheet runs, and compounds broken into subtasks by methods.",
				"drawer": "table", "table_columns": [
					{"name": "name", "type": "String"},
					{"name": "kind", "type": "enum(primitive|compound)"}]}},
		"scorer_inputs": {"type": "Array", "default": [], "exported": true,
			"attributes": {"group": "Utility Scorers",
				"tooltip": "Which world-state input feeds which scorer, through a response curve.",
				"drawer": "table", "table_columns": [
					{"name": "scorer", "type": "String"},
					{"name": "input", "type": "String"},
					{"name": "curve", "type": "enum(linear|inverse|quadratic|inverse_quadratic|logistic|threshold|bell)"},
					{"name": "weight", "type": "float"},
					{"name": "center", "type": "float"},
					{"name": "slope", "type": "float"}]}}
	}
	return Lib.save_pack(sheet, "res://eventsheet_addons/uhtn_plan_resource/uhtn_plan_resource")
