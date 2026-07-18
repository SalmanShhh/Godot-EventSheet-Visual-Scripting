## @ace_version(1.0.0)
@icon("res://eventsheet_addons/uhtn_plan_resource/icon.svg")
class_name UHTNPlanResource
extends Resource
## A complete UHTN plan (utility-driven Hierarchical Task Network) as a data asset: the tasks, the methods that decompose them (ranked by utility scorers), their preconditions, and the scoring curves - all authored in Inspector grids. Drop the saved .tres onto a UHTNPlanner's Plan Resource slot.

## Preconditions a method needs before it can be chosen: the world-state key, a comparison, and the expected value. A method with no rows here is always applicable.
@export_group("Task Network")
@export_custom(PROPERTY_HINT_NONE, "eventsheet:table:method=String,key=String,op=String,value=String") var conditions: Array = []
## The ways to accomplish each compound task. Subtasks run in order (comma-separated task names). Rank methods with a SCORER (from the Scorer Inputs grid) for live utility ranking, or leave scorer blank and use the fixed utility number. Keep method ids unique.
@export_group("Task Network")
@export_custom(PROPERTY_HINT_NONE, "eventsheet:table:task=String,method=String,subtasks=String,scorer=String,utility=float") var methods: Array = []
## A readable name for this plan (shown in debug output).
@export_group("Identity")
@export var plan_name: String = "plan"
# @inspector_required
## The goal the planner decomposes - name a compound (usually) or primitive task from the Tasks grid.
@export_group("Identity")
@export var root_task: String = ""
## The Utility-AI half: each row feeds one world-state input through a response curve into a named scorer. A method that names that scorer is ranked by the LIVE score at plan time (weighted average across the scorer's rows). Center + slope shape the logistic / threshold / bell curves.
@export_group("Utility Scorers")
@export_custom(PROPERTY_HINT_NONE, "eventsheet:table:scorer=String,input=String,curve=String,weight=float,center=float,slope=float") var scorer_inputs: Array = []
## Every task in the network. A PRIMITIVE is a leaf your event sheet executes (walk, shoot, hide); a COMPOUND decomposes into subtasks via the Methods grid.
@export_group("Task Network")
@export_custom(PROPERTY_HINT_NONE, "eventsheet:table:name=String,kind=String") var tasks: Array = []
