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
		"tasks": {"type": "Array", "default": [], "exported": true,
			"attributes": {"group": "Task Network",
				"tooltip": "Every task in the network. A PRIMITIVE is a leaf your event sheet executes (walk, shoot, hide); a COMPOUND decomposes into subtasks via the Methods grid.",
				"drawer": "table", "table_columns": [
					{"name": "name", "type": "String"},
					{"name": "kind", "type": "enum(primitive|compound)"}]}},
		"methods": {"type": "Array", "default": [], "exported": true,
			"attributes": {"group": "Task Network",
				"tooltip": "The ways to accomplish each compound task. Subtasks run in order (comma-separated task names). Rank methods with a SCORER (from the Scorer Inputs grid) for live utility ranking, or leave scorer blank and use the fixed utility number. Keep method ids unique.",
				"drawer": "table", "table_columns": [
					{"name": "task", "type": "String"},
					{"name": "method", "type": "String"},
					{"name": "subtasks", "type": "String"},
					{"name": "scorer", "type": "String"},
					{"name": "utility", "type": "float"}]}},
		"conditions": {"type": "Array", "default": [], "exported": true,
			"attributes": {"group": "Task Network",
				"tooltip": "Preconditions a method needs before it can be chosen: the world-state key, a comparison, and the expected value. A method with no rows here is always applicable.",
				"drawer": "table", "table_columns": [
					{"name": "method", "type": "String"},
					{"name": "key", "type": "String"},
					{"name": "op", "type": "enum(==|!=|<|<=|>|>=)"},
					{"name": "value", "type": "String"}]}},
		"scorer_inputs": {"type": "Array", "default": [], "exported": true,
			"attributes": {"group": "Utility Scorers",
				"tooltip": "The Utility-AI half: each row feeds one world-state input through a response curve into a named scorer. A method that names that scorer is ranked by the LIVE score at plan time (weighted average across the scorer's rows). Center + slope shape the logistic / threshold / bell curves.",
				"drawer": "table", "table_columns": [
					{"name": "scorer", "type": "String"},
					{"name": "input", "type": "String"},
					{"name": "curve", "type": "enum(linear|inverse|quadratic|inverse_quadratic|logistic|threshold|bell)"},
					{"name": "weight", "type": "float"},
					{"name": "center", "type": "float"},
					{"name": "slope", "type": "float"}]}}
	}
	return Lib.save_pack(sheet, "res://eventsheet_addons/uhtn_plan_resource/uhtn_plan_resource")
