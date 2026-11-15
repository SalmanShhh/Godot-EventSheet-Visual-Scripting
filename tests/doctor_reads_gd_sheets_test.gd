# Godot EventSheets - the Project Doctor reads `.gd` sheets as well as `.tres` ones.
#
# `.gd` is the default sheet format, and the checks below used to call `load()` on a path and carry
# on only when it came back as a sheet. A `.gd` never does, so in a project of scripts those checks
# said nothing and gave no sign they had not looked. Every fixture here is a REAL file on disk (the
# analyzer and the importer both read files, not strings), written under user:// and removed again.
#
# Each case writes the smallest script a beginner would write that earns the finding, asks the one
# check by its own entry point, and pins the check id. The last block pins the four checks that do
# NOT apply to a `.gd` and the coverage note that says so.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const GdSheets := preload("res://addons/eventforge/doctor_gd_sheets.gd")
const TEST_NAME := "doctor_reads_gd_sheets_test"
static var own_folder: String = SUPPORT.own_path("doctor_gd_sheets/")


static func run() -> bool:
	DirAccess.make_dir_recursive_absolute(own_folder)
	var rows: Array = []

	# Debug residue: a script that still carries the live-values receiver or a breakpoint statement.
	var residue: String = _write("residue", "extends Node\n\nvar __live_values_timer: float = 0.0\n\n\nfunc _ready() -> void:\n\tbreakpoint\n")
	rows.append(["debug residue in a .gd is found", _checks_of("check_debug_residue", residue), ["debug-residue"]])
	var clean: String = _write("clean", "extends Node\n\n\nfunc _ready() -> void:\n\tprint(\"ready\")\n")
	rows.append(["a clean .gd has no debug residue", _checks_of("check_debug_residue", clean), []])
	rows.append(["a script that only mentions the word breakpoint in a comment is not residue",
		_checks_of("check_debug_residue", _write("mention", "extends Node\n\n# set a breakpoint here to look\nvar note: String = \"breakpoint\"\n")), []])

	# Scene attachment: a script no scene, autoload or other script names.
	rows.append(["a .gd attached to no scene is noted", _checks_of("check_scene_attachment", clean), ["scene-attachment"]])
	rows.append(["a .gd that declares a class_name is a class others can name, so it is not noted",
		_checks_of("check_scene_attachment", _write("named_class", "class_name DoctorGdProbeClass\nextends Node\n")), []])

	# Editor tool safety: an @tool script that reaches for the editor's own tree.
	var tool_path: String = _write("tool", "@tool\nextends Node\n\n\nfunc _process(delta: float) -> void:\n\tfor n in get_tree().get_nodes_in_group(\"x\"):\n\t\tn.queue_free()\n")
	rows.append(["an @tool .gd that walks get_tree() is found", _checks_of("check_editor_tool_safety", tool_path).has("editor-tool-scope"), true])
	rows.append(["a plain .gd is not judged as an editor tool", _checks_of("check_editor_tool_safety", clean), []])

	# Background threads: a function handed to a thread whose body reaches the tree.
	var thread: String = _write("thread", "extends Node\n\nvar worker: Thread = Thread.new()\n\n\nfunc _ready() -> void:\n\tworker.start(_work)\n\n\nfunc _work() -> void:\n\tget_node(\"A\").queue_free()\n")
	rows.append(["a .gd that touches the tree from a thread is found", _checks_of("check_background_thread_safety", thread), ["background-thread-touches-tree"]])

	# Unused variables: counted against the script's own text and against the other scripts.
	var dead: String = _write("dead", "extends Node\n\nvar dead_weight: int = 3\nvar used_value: int = 1\n\n\nfunc _ready() -> void:\n\tprint(used_value)\n")
	var dead_findings: Array[Dictionary] = _run_check("check_unused_variables", dead)
	rows.append(["a private variable nothing reads is found in a .gd", _checks_of_findings(dead_findings), ["unused-variable"]])
	rows.append(["and it names the variable", str(dead_findings[0].get("message", "")).contains("dead_weight") if not dead_findings.is_empty() else false, true])

	# Fan-out: one script reaching six other nodes.
	rows.append(["a .gd that drives six nodes is a god sheet", _checks_of("check_fanout_god_sheets", _write("fan",
		"extends Node\n\n\nfunc _ready() -> void:\n\t$A.hide()\n\t$B.hide()\n\t$C.hide()\n\t$D.hide()\n\t$E.hide()\n\t$F.hide()\n")), ["fanout-god-sheet"]])

	# Fragile node paths, loops under a per-frame trigger, waits under one.
	rows.append(["a .gd with a ../../ path is found", _checks_of("check_fragile_node_paths", _write("frag",
		"extends Node\n\n\nfunc _ready() -> void:\n\tprint(get_node(\"../../Player\"))\n")), ["fragile-node-path"]])
	rows.append(["a .gd looping a group every frame is found", _checks_of("check_unbounded_loops", _write("loop",
		"extends Node\n\n\nfunc _process(delta: float) -> void:\n\tfor e in get_tree().get_nodes_in_group(\"enemies\"):\n\t\te.hide()\n\t\te.show()\n\t\te.hide()\n")), ["unbounded-loop"]])
	rows.append(["a .gd that waits inside _process is found", _checks_of("check_coroutine_in_per_frame_trigger", _write("coro",
		"extends Node\n\n\nfunc _process(delta: float) -> void:\n\tawait get_tree().create_timer(1.0).timeout\n\tprint(\"x\")\n")), ["coroutine-in-per-frame"]])

	# Rows that name things: parameter kinds, variable notes, pasted engine errors, region fences.
	# A lifted script line fills its row with text (every lifted parameter is a String slot), so this
	# check reads a script and finds nothing to accuse: the pin is that it reads one without harm.
	rows.append(["a .gd is read for mistyped literals without a finding, since a lifted line holds text", _checks_of("check_param_type_mismatches", _write("param",
		"extends Node\n\n\nfunc _ready() -> void:\n\t$Timer.start(\"soon\")\n")), []])
	rows.append(["a text variable handed to Add to is found in a .gd", _checks_of("check_variable_notes", _write("varnote",
		"extends Node\n\nvar title: String = \"\"\n\n\nfunc _ready() -> void:\n\ttitle += 5\n")), ["variable-type-mismatch"]])
	rows.append(["engine error text pasted into a .gd note is found", _checks_of("check_raw_error_notes", _write("rawnote",
		"extends Node\n\n# Invalid call. Nonexistent function 'foo' in base 'Node'.\n\n\nfunc _ready() -> void:\n\tpass\n")), ["raw-error-note"]])
	rows.append(["a #region with no #endregion in a .gd is found", _checks_of("check_region_fences", _write("region",
		"extends Node\n\n#region Open\n\nfunc _ready() -> void:\n\tpass\n")), ["region-fence"]])

	# Shadowed variables: a member the engine class already has. Godot cannot load such a script.
	var shadow_findings: Array[Dictionary] = _run_check("check_shadowed_variables", _write("shadow", "extends Node2D\n\nvar position: Vector2 = Vector2.ZERO\n"))
	rows.append(["a .gd variable that shadows a Node2D member is an error", _checks_of_findings(shadow_findings), ["shadowed-variable"]])
	rows.append(["and the finding says error", str(shadow_findings[0].get("severity", "")) if not shadow_findings.is_empty() else "", "error"])
	# Godot is the judge of a script: a name the parent class has as a METHOD loads fine.
	rows.append(["a Resource script with a set_name variable loads, so it is not accused", _checks_of("check_shadowed_variables", _write("setname",
		"extends Resource

@export var set_name: String = \"\"
")), []])
	rows.append(["an unused constant in a script is a public offer, not dead", _checks_of("check_unused_variables", _write("const",
		"extends Node

const UNUSED_OFFER: int = 3
")), []])
	rows.append(["a .gd variable that shadows nothing is fine", _checks_of("check_shadowed_variables", dead), []])

	# Translation: a tr() call in a project with no catalogs.
	rows.append(["a .gd that translates text in a project with no catalogs is noted", _checks_of("check_untranslated_project", _write("tr",
		"extends Node\n\n\nfunc _ready() -> void:\n\t$Label.text = tr(\"hello\")\n")), ["l10n"]])

	# Pattern smells: a countdown that is never restarted.
	rows.append(["a .gd countdown that never restarts is found", _checks_of("check_pattern_smells", _write("pattern",
		"extends Node\n\nvar cooldown: float = 0.0\n\n\nfunc _process(delta: float) -> void:\n\tcooldown -= delta\n\tif cooldown <= 0.0:\n\t\tprint(\"ready\")\n")),
		["pattern-countdown-never-restarts"]])

	# A node sliding to a stop is not a meter. The same template lifts both, and only a plain name is
	# something a person could drain.
	rows.append(["a falling node is not a meter that never drains", _checks_of("check_pattern_smells", _write("slide",
		"extends Node


func _physics_process(delta: float) -> void:
	$Lantern.position.y = minf($Lantern.position.y + 220.0 * delta, 620.0)
")), []])
	rows.append(["a variable that only fills is", _checks_of("check_pattern_smells", _write("meter",
		"extends Node

var charge: float = 0.0


func _physics_process(delta: float) -> void:
	charge = minf(charge + 40.0 * delta, 100.0)
")), ["meter-never-drains"]])

	# Save support: a registered autoload script holding State and no save seam.
	var save_path: String = _write("save", "extends Node\n\nvar coins: int = 0\n")
	ProjectSettings.set_setting("autoload/GdProbeSave", "*" + save_path)
	rows.append(["an autoload .gd with State and no save_state is noted", _checks_of("check_missing_save_support", save_path), ["save-support"]])
	ProjectSettings.set_setting("autoload/GdProbeSave", null)

	# The two that cannot apply, pinned so a later widening cannot start crying wolf quietly.
	var twin_a: String = _write("twin_a", "extends Node\n\nvar score: int = 0\n")
	var twin_b: String = _write("twin_b", "extends Node\n\nvar score: int = 0\n")
	var twin_findings: Array[Dictionary] = []
	EventSheetProjectDoctor.check_duplicated_globals(PackedStringArray([twin_a, twin_b]), twin_findings)
	rows.append(["the same member name in two scripts is not a shared global", _checks_of_findings(twin_findings), []])
	rows.append(["a .gd is its own output, so it is never 'stale'", _checks_of("check_generated_outputs", clean), []])
	rows.append(["a .gd is an autoload only because the project registers it, so none is 'unregistered'",
		_checks_of("check_autoload_registration", clean), []])

	# Which scripts the audit now reads, and the note that says what it did not apply.
	var sheets: PackedStringArray = GdSheets.script_sheets()
	rows.append(["the audit reads the game's own scripts", sheets.has("res://demo/readme_example/player.gd"), true])
	rows.append(["it never reads this plugin's own code", _any_begins_with(sheets, "res://addons/"), false])
	rows.append(["it never reads a shipped pack", _any_begins_with(sheets, "res://eventsheet_addons/"), false])
	rows.append(["it never reads a Godot script template", _any_begins_with(sheets, "res://script_templates/"), false])
	rows.append(["it never reads a folder the project declared out of its audit", _any_begins_with(sheets, "res://tests/"), false])
	var note: Dictionary = GdSheets.coverage_finding(3, 7)
	rows.append(["the coverage note is info", str(note.get("severity", "")), "info"])
	rows.append(["it names how many .gd sheets were read", str(note.get("message", "")).contains("7"), true])
	rows.append(["it says which checks do not apply", str(note.get("message", "")).contains("duplicated globals"), true])
	rows.append(["and says why", str(note.get("message", "")).contains("its own output"), true])
	rows.append(["a project with no .gd sheets gets no note", GdSheets.coverage_finding(3, 0).is_empty(), true])

	# The residue reader on its own.
	rows.append(["live values and a breakpoint are both named",
		GdSheets.residue_in_source("var __live_values_timer: float = 0.0\nfunc f():\n\tbreakpoint\n"),
		PackedStringArray(["breakpoints", "live-values telemetry"])])
	rows.append(["the trace buffer is named",
		GdSheets.residue_in_source("var __eventsheets_fired: PackedStringArray = PackedStringArray()\n"),
		PackedStringArray(["event trace"])])
	rows.append(["the replay receiver is named",
		GdSheets.residue_in_source("## Replay recording receiver (debug sessions only).\nfunc _unhandled_input(event: InputEvent) -> void:\n\tpass\n"),
		PackedStringArray(["replay recording"])])
	rows.append(["ordinary code has none", GdSheets.residue_in_source("extends Node\n"), PackedStringArray()])

	_clean_up()
	return SUPPORT.pins(TEST_NAME, rows)


static func _write(name: String, source: String) -> String:
	var path: String = own_folder + name + ".gd"
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(source)
	file.close()
	return path


static func _run_check(check_name: String, path: String) -> Array[Dictionary]:
	var findings: Array[Dictionary] = []
	Callable(EventSheetProjectDoctor, check_name).call(PackedStringArray([path]), findings)
	return findings


static func _checks_of(check_name: String, path: String) -> Array:
	return _checks_of_findings(_run_check(check_name, path))


static func _checks_of_findings(findings: Array[Dictionary]) -> Array:
	var ids: Array = []
	for finding: Dictionary in findings:
		var id: String = str(finding.get("check", ""))
		if not ids.has(id):
			ids.append(id)
	return ids


static func _any_begins_with(paths: PackedStringArray, prefix: String) -> bool:
	for path: String in paths:
		if path.begins_with(prefix):
			return true
	return false


static func _clean_up() -> void:
	var dir: DirAccess = DirAccess.open(own_folder)
	if dir == null:
		return
	for file_name: String in dir.get_files():
		DirAccess.remove_absolute(own_folder + file_name)
	DirAccess.remove_absolute(own_folder)
