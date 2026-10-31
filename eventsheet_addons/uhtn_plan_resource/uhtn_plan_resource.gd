## @ace_version(1.0.0)
@icon("res://eventsheet_addons/uhtn_plan_resource/icon.svg")
class_name UHTNPlanResource
extends Resource
## A complete UHTN plan (utility-driven Hierarchical Task Network) as a data asset: the tasks, the methods that decompose them (ranked by utility scorers), their preconditions, and the scoring curves - all authored in Inspector grids. Drop the saved .tres onto a UHTNPlanner's Plan Resource slot.

## A readable name for this plan (shown in debug output).
@export_group("Identity")
@export var plan_name: String = "plan"
# @inspector_required
## The goal the planner decomposes - name a compound (usually) or primitive task from the Tasks grid.
@export var root_task: String = ""
## Preconditions per method: a world-state key, a comparison and a value.
@export_group("Task Network")
@export_custom(PROPERTY_HINT_NONE, "eventsheet:table:method=String,key=String,op=enum(==|!=|<|<=|>|>=),value=String") var conditions: Array = []
## Ways to accomplish each compound task, ranked by an optional scorer.
@export_custom(PROPERTY_HINT_NONE, "eventsheet:table:task=String,method=String,subtasks=String,scorer=String,utility=float") var methods: Array = []
## Every task: primitives your sheet runs, and compounds broken into subtasks by methods.
@export_custom(PROPERTY_HINT_NONE, "eventsheet:table:name=String,kind=enum(primitive|compound)") var tasks: Array = []
## Which world-state input feeds which scorer, through a response curve.
@export_group("Utility Scorers")
@export_custom(PROPERTY_HINT_NONE, "eventsheet:table:scorer=String,input=String,curve=enum(linear|inverse|quadratic|inverse_quadratic|logistic|threshold|bell),weight=float,center=float,slope=float") var scorer_inputs: Array = []
