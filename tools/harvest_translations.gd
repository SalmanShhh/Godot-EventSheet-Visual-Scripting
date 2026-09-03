# Godot EventSheets - THE TRANSLATION HARVEST (dev tool, headless-safe).
#
# Nine CSVs under addons/eventsheet/translations/ - TEMPLATE.csv and the eight bundled locales -
# were hand-maintained in lockstep, and a wave that added a word had to remember all nine. Three
# suite gates already NAME the key a wave forgot; none of them could add it. This tool is the other
# half: it derives the keys that are OWED, appends the missing ones, and leaves every byte it did
# not have to add exactly where it was.
#
# RUN IT
#   "$GODOT" --headless --path . --script tools/harvest_translations.gd
#   "$GODOT" --headless --path . --script tools/harvest_translations.gd -- --dry-run
#
# THE THREE SOURCES, AND WHY ONLY TWO OF THEM APPEND. A source is OWED when a gate already fails on
# a key it holds that no CSV carries - appending such a key changes nothing a maintainer was not
# going to be forced to write anyway. A source is ADVISORY when it sees more than the plugin owes:
# it is reported, never appended, because an appended key arrives with an empty cell in eight locale
# files and an empty cell is a suite failure.
#
#   EDITOR LITERALS  (owed)      every literal argument of a translate() call under addons/. The
#                                editor coverage gate fails on any of these that has no row.
#   VOCABULARY       (owed)      the descriptor wording - name, description, shelf, reads-as
#                                sentence, parameter label, parameter description, dropdown option
#                                label - of the modules and verbs the l10n obligation below names.
#   CONTROL WALK     (advisory)  the live dock's own Controls, its canvas-drawn tables, the theme
#                                editor and the rebuilt context menus. It sees strings the ENGINE
#                                put there (a file dialog's own filter names), theme-token help, and
#                                text not routed through translate() yet, so what it alone knows is
#                                a list for a person to read rather than rows to write.
#
# WHY THE WHOLE VOCABULARY IS NOT A SOURCE. Sweeping every shipped descriptor derives about 7,800
# strings, of which some 5,200 have no row. Appending those would blank-cell eight locale files by
# the thousand and turn a green suite red at a stroke - translating the vocabulary is a ratcheted,
# deliberately partial job, and this tool harvests what is owed, not what is possible.
#
# NEVER DELETES. A row this tool cannot derive is a row it keeps. About three in ten template keys
# are in that state - canvas text, data-table wording and vocabulary beyond the ratchet - and one of
# them dropping out because a source stopped seeing it would be a silent regression in eight
# languages. It only appends, only to the end, only when there is something to add.
#
# NO class_name, matching tools/registry_wording.gd beside it: a tool nothing ships is preloaded by
# path, and a class_name would put it in the editor's class cache for no caller's benefit.
@tool
extends SceneTree

const TRANSLATIONS_DIR := "res://addons/eventsheet/translations"
const TEMPLATE_FILE := "TEMPLATE.csv"

## The bundled languages. English is the source, so it is not a file.
const LOCALES: PackedStringArray = ["de", "es", "fr", "it", "ja", "ko", "ru", "zh_CN"]

## Where the vocabulary modules live.
const MODULES_DIR := "res://addons/eventforge/registration/modules"

## Both halves of the plugin. A user-visible string does not care which one it lives in.
const SCRIPT_ROOTS: PackedStringArray = ["res://addons/eventsheet", "res://addons/eventforge"]

## Every spelling of the call, matched by its tail. `EventSheetL10n.translate` reads the catalog;
## `EventSheetSentence.translate` and `EventSheets.translate` are one-line aliases of it, and a gate
## keyed to the first class name alone walked straight past them - ten of the row grammar's own
## words among them ("angle", "the file's text"). Nothing else in the plugin ends a call this way,
## so the tail covers an alias nobody has written yet for free.
const CALL := ".translate("


## What a source's keys oblige the CSVs to carry.
enum Binding {
	## Every key is owed a row. The harvest appends the ones that are missing.
	OWED,
	## The source sees more than the plugin owes. Keys it alone knows are reported, never written.
	ADVISORY,
}


## One source of keys, named so a report can say where a key came from.
class Source extends RefCounted:
	var title: String
	var binding: Binding
	var keys: PackedStringArray

	func _init(source_title: String, source_binding: Binding, source_keys: PackedStringArray) -> void:
		title = source_title
		binding = source_binding
		keys = source_keys


## What one harvest would do, computed before anything is written so a gate can assert it is empty.
class Plan extends RefCounted:
	## Owed keys no CSV carries yet, in the order the harvest would append them.
	var append: PackedStringArray = PackedStringArray()
	## Keys only an advisory source knows. A list for a person, never a row.
	var advisory: PackedStringArray = PackedStringArray()
	## Template rows no source derives. Kept, always - see the header.
	var kept_by_hand: PackedStringArray = PackedStringArray()

	func is_empty() -> bool:
		return append.is_empty()


# ── The l10n obligation ──


## Modules whose WHOLE descriptor set is owed a translated word: every descriptor in the file.
const OWED_WHOLE_MODULES: Array[String] = [
	"res://addons/eventforge/registration/modules/clipboard_aces.gd",
	"res://addons/eventforge/registration/modules/resource_aces.gd",
	"res://addons/eventforge/registration/modules/table_aces.gd",
	"res://addons/eventforge/registration/modules/text_extract_aces.gd",
	"res://addons/eventforge/registration/modules/text_format_aces.gd",
	"res://addons/eventforge/registration/modules/spatial_aces.gd",
	# The reading waves that followed: the game shapes every project writes by hand, the words for
	# authoring an editor plugin, the 3D move/turn/face/place vocabulary, and the cursor-and-canvas
	# words. Each of these modules is WHOLLY new, so the whole module is owed and swept.
	"res://addons/eventforge/registration/modules/game_mechanics_aces.gd",
	"res://addons/eventforge/registration/modules/cursor_canvas_aces.gd",
	# Playing together, and lighting a game: three modules that shipped whole, so the whole of each
	# is owed. The node-scoped lighting rows now live in lighting_aces.gd beside the frozen ones they
	# were authored next to, and that whole file is keyed, so the file is what is listed.
	"res://addons/eventforge/registration/modules/multiplayer_aces.gd",
	"res://addons/eventforge/registration/modules/lighting_aces.gd",
	"res://addons/eventforge/registration/modules/scene_lighting_aces.gd",
	# The game's own mode, and the value-shaping and movement words. Three modules that shipped
	# whole, so the whole of each is owed.
	"res://addons/eventforge/registration/modules/game_state_aces.gd",
	"res://addons/eventforge/registration/modules/math_words_aces.gd",
	"res://addons/eventforge/registration/modules/space_words_aces.gd",
	# The spawn sentence: the row that names a new copy, the deferred spelling beside it, and the
	# four expressions that answer "where". One module, shipped whole, so the whole of it is owed.
	"res://addons/eventforge/registration/modules/spawn_aces.gd",
	# The other half of the same sentence: the three destroy verbs and the question beside them. One
	# module, shipped whole, so the whole of it is owed.
	"res://addons/eventforge/registration/modules/removal_aces.gd",
	# The copies said in the plural: joining a group on the way in, the cap with its policy on the
	# row, the count, and the trigger that answers a crowd emptying. One module, shipped whole.
	"res://addons/eventforge/registration/modules/crowd_aces.gd",
	# The questions a handler asks the ONE event it was handed, filed apart from the polled Input
	# rows on purpose. One module, shipped whole, so the whole of it is owed.
	"res://addons/eventforge/registration/modules/input_event_aces.gd",
	# The four things the engine tells a node through its notification callback. One module,
	# shipped whole, so the whole of it is owed.
	"res://addons/eventforge/registration/modules/notification_aces.gd",
	# One object's own state, which is the game-mode module one level down: the same six roles owed
	# for the same reason. One module, shipped whole, so the whole of it is owed.
	"res://addons/eventforge/registration/modules/object_state_aces.gd",
	# The tree announcing a node joining or leaving a group: two triggers and the group they watch.
	# One module, shipped whole, so the whole of it is owed.
	"res://addons/eventforge/registration/modules/group_arrival_aces.gd",
	# What a surface looks like, said in words: the nine material words, the surface slots beside
	# them and the two a sprite has. One module, shipped whole, so the whole of it is owed.
	"res://addons/eventforge/registration/modules/material_aces.gd",
]

## The two doors content from outside the project comes in through. Added to the shipped Files
## module rather than to a module of their own, so they are swept by id here rather than wholesale.
const USER_CONTENT_DOOR_IDS: Array[String] = [
	"OnFilesDropped", "AskForAFileToOpen", "AskWhereToSave", "OnFileChosen", "OnAskCancelled",
	"LoadImageFile", "LoadSoundFile",
	# The two archive verbs and the three events an unpack raises, added to the same shipped module.
	"PackFolderIntoZip", "UnpackZipIntoFolder", "OnUnpackProgress", "OnUnpackRefused",
	"OnUnpackFinished",
	# The name a player typed made safe, the path that is still free, and the door back to their
	# own file browser. Added to the same shipped module.
	"SafeFileName", "FreeFilePath", "ShowInFileManager",
	# The guarded read, the write that makes its folder, and the door onto the player's own folder.
	"ReadTextFileOr", "WriteTextFileInFolder", "OpenUserDataFolder",
	# What the player built, written down, and the question asked before one is read back in. Added
	# to the same shipped module as the doors above, so they are swept by id here for the same
	# reason: the module predates the wave and only what the wave added is owed.
	"SaveBranchAsSceneFile", "SceneFileIsDataOnly",
]

## Modules that already shipped and GAINED verbs later: only the NAMED ids are owed, so the
## obligation says what each wave took on rather than retro-claiming vocabulary that predates it.
## Module path -> the ace_ids owed inside it.
const OWED_VERBS_IN_MODULE: Dictionary = {
	"res://addons/eventforge/registration/modules/comparison_aces.gd": [
		"TextIsANumber", "TextIsAWholeNumber", "ContainsAnyOf", "ContainsAllOf", "ContainsNoneOf",
		"NumberFromText", "WholeNumberFromText", "IsNothing", "HasSomething",
	],
	"res://addons/eventforge/registration/modules/collection_aces.gd": [
		"NumberOr", "TextOr", "ListOr", "RecordOr", "ValueOr", "PartOf", "SetPartOf",
		# The flow wave: waits that can end two ways, retries, and the race.
		"WaitUntil", "WaitForAllOf", "WaitForAnyOf", "WaitSucceeded", "WaitTimedOut",
		"FirstToFinish", "RetryUpTo", "RetryAttemptNumber", "StopRetrying", "RetriesExhausted",
		"WaitBeforeNextTry",
		# A layout put OVER the running game rather than instead of it: the add, the removal, and
		# the question between them.
		"AddLayoutOnTop", "RemoveLayoutOnTop", "LayoutIsOnTop",
	],
	# The flow/diagnostics wave: trails, measurements and the frame-budget conditions.
	"res://addons/eventforge/registration/modules/dev_aces.gd": [
		"RememberInTrail", "TrailValues", "TrailLowest", "TrailHighest", "TrailAverage",
		"TrailNewest", "TrailLength", "LogTrail", "SaveTrailCsv", "ClearTrail",
		"FrameOverBudget", "FpsBelowFor", "StartMeasuring", "StopMeasuring", "MeasuredLast",
		"MeasuredAverage", "MeasuredPeak", "LogMeasurements", "ClearMeasurements",
		# The two edges of the budget: the frame it went long on, and the frame it came right on.
		"FrameRunningLong", "FrameRecovered",
		# The write half of the scene owner, beside the read-only row that predates it.
		"SetSceneOwner",
	],
	# The wire's own words need no entry of their own: multiplayer_aces.gd is listed above as a
	# WHOLLY new module, so every descriptor it grows is already swept.
	# Drawing order as a sentence, and the on-screen question.
	"res://addons/eventforge/registration/modules/rendering_aces.gd": [
		"RenderingDrawInFrontOf", "RenderingShowOnlyTo", "RenderingIsOnScreen",
	],
	# The flow wave: the service registry, the capability loop and the deferral verbs.
	"res://addons/eventforge/registration/modules/node_aces.gd": [
		"RegisterAsService", "ServiceNamed", "HasService", "ForEachNodeThatCan",
		"DoAfterFrame", "CallLater", "SetPropertyDeferred", "OnceThisFrame",
		# The hierarchy wave: parenting, the two follow-flag escape hatches, and the child picks.
		"RemoveChild", "HierarchyAddChild", "HierarchyRemoveFromParent", "SetIgnoreParentMovement",
		"CopyPlaceTo", "StopCopyingPlace", "ForEachChildOf", "MoveChild", "QueueFreeNode",
		# The copy with its three questions asked out loud, beside the frozen engine-default one.
		"DuplicateNodeChoosing",
	],
	# The hierarchy wave's two triggers, the element-input trigger that shipped beside them, and the
	# error trigger a shipped build fires.
	"res://addons/eventforge/registration/modules/core_aces.gd": [
		"OnControlInput", "OnChildEnteredTree", "OnChildExitingTree", "OnSomethingWentWrong",
		# The reparent that says which of the two things should happen to where the node is.
		"ReparentToChoosing",
	],
	# The data wave: watched data files and the data-folder validation verbs.
	"res://addons/eventforge/registration/modules/resource_aces.gd": [
		"WatchDataFile", "ReloadDataAsset", "signal:data_file_changed",
		"DataFolderProblems", "DataFolderIsValid", "ValidateDataFolder",
	],
	# The flow wave: named spawns, the success/failure report seam and the once-per-thing guards.
	"res://addons/eventforge/registration/modules/system_aces.gd": [
		"SpawnSceneAs", "TheSpawned", "SpawnIsAlive", "signal:scene_spawned",
		"signal:verb_failed", "signal:verb_succeeded", "ReportFailure", "ReportSuccess",
		"AtMostEvery", "Poke", "ClearPoke", "HasBeenQuiet", "OnlyOncePerNode",
		"OnlyOncePerName", "OnlyOnceThisSceneLoad", "ForgetOnceFor",
	],
	# The drop door, the ask door and the two loaders - see USER_CONTENT_DOOR_IDS above.
	"res://addons/eventforge/registration/modules/file_aces.gd": USER_CONTENT_DOOR_IDS,
	# The two rows that build a menu and answer the item that was chosen out of it.
	"res://addons/eventforge/registration/modules/editor_object_aces.gd": [
		"MenuAddItem", "OnMenuItemChosen",
		# The words for authoring an editor plugin. They arrived as a module of their own and were
		# owed wholesale; the module joined this one, so the same rows are owed here by name.
		"EditorIcon", "EditorPreference", "ProjectSetting", "EditorMainScreen", "SetProjectSetting",
		"SaveProjectSettings", "SwitchToWorkspace", "ShowInProjectBar", "OpenScriptAtLine",
		"AddEditorWindow", "AddCommandPaletteCommand", "AddBottomPanel", "RemoveBottomPanel",
		"OnProjectFilesChanged", "OnPreferencesChanged",
	],
	# The three edits a tool makes as steps the editor can take back.
	"res://addons/eventforge/registration/modules/tooling_aces.gd": [
		"SetPropertyUndoable", "AddNodeUndoable", "RemoveNodeUndoable",
	],
	# The combo wave: the slice of a clip a move may be cancelled in, the per-object
	# freeze, and the two ways an animation tells the game when something happens.
	"res://addons/eventforge/registration/modules/animation_player_aces.gd": [
		"AnimationIsBetween", "PauseAnimationFor",
		"OnAnimationFrame", "SpriteAnimationFrameIs", "OnAnimationEvent",
		# The names picked off the scene: the two rows that wave added, and the three whose fields
		# stopped being free text.
		"PlayThenQueue", "AnimationPastMarker", "QueueAnimation", "SetAnimationTime", "HasAnimation",
	],
	# The layers said in the project's own words: the two mask verbs, the two layer verbs and the
	# question beside them, each in both dimensions.
	"res://addons/eventforge/registration/modules/collision_aces.gd": [
		"CollideWithLayer", "StopCollidingWithLayer", "BeOnLayer", "LeaveLayer",
		"IsSetToCollideWithLayer",
		"CollideWithLayer3D", "StopCollidingWithLayer3D", "BeOnLayer3D", "LeaveLayer3D",
		"IsSetToCollideWithLayer3D",
		# The step a standing state changed: the two floor edges, the two overlap edges and the
		# four gates that go under them. They arrived as a module of their own and were owed
		# wholesale; the module joined this one, so the same rows are owed here by name.
		"OnLanded", "OnLanded3D", "OnLeftTheGround", "OnLeftTheGround3D",
		"JustLanded", "JustLanded3D", "JustLeftTheGround", "JustLeftTheGround3D",
		"OnFirstOverlap", "OnFirstOverlap3D", "OnLastOverlapEnded", "OnLastOverlapEnded3D",
		"IsTheFirstOneIn", "IsTheFirstOneIn3D", "WasTheLastOneOut", "WasTheLastOneOut3D",
		# The touch said with a group on it: the four filtered triggers and the standing question
		# beside them, owed here for the same reason.
		"OnCollisionWithGroup", "OnCollisionWithGroup3D",
		"OnStoppedCollidingWithGroup", "OnStoppedCollidingWithGroup3D",
		"OnOverlapWithGroup", "OnOverlapWithGroup3D",
		"OnOverlapEndedWithGroup", "OnOverlapEndedWithGroup3D",
		"IsTouchingGroup", "IsTouchingGroup3D",
	],
	# The press remembered for a moment so an input made slightly too early still lands,
	# in seconds and in the frame-counted spelling beside it.
	"res://addons/eventforge/registration/modules/timed_input_aces.gd": [
		"BufferInput", "IsInputBuffered", "ConsumeBufferedInput",
		"BufferInputFrames", "IsInputBufferedFrames", "ConsumeBufferedInputFrames",
	],
}


# ── The sources ──


## Every literal the editor asks to translate. OWED: the coverage gate fails on one with no row.
static func editor_literals() -> Source:
	var seen: Dictionary = {}
	var keys: PackedStringArray = PackedStringArray()
	for root: String in SCRIPT_ROOTS:
		for path: String in scripts_under(root):
			for key: String in translated_keys(FileAccess.get_file_as_string(path)):
				_add_verbatim(key, seen, keys)
	return Source.new("editor literals", Binding.OWED, keys)


## The wording of the verbs the l10n obligation names. OWED: the vocabulary gate fails on one with
## no row.
static func owed_vocabulary() -> Source:
	var seen: Dictionary = {}
	var keys: PackedStringArray = PackedStringArray()
	for path: String in OWED_WHOLE_MODULES:
		_collect_module(path, PackedStringArray(), seen, keys)
	var module_paths: Array = OWED_VERBS_IN_MODULE.keys()
	module_paths.sort()
	for path: Variant in module_paths:
		_collect_module(str(path), PackedStringArray(OWED_VERBS_IN_MODULE[path]), seen, keys)
	return Source.new("vocabulary", Binding.OWED, keys)


## What the live editor puts on screen. ADVISORY - see the header for why it never appends.
## `tree` is the SceneTree the probe dock is built under; there is none inside the suite, which is
## why the dry-run gate reads the two owed sources only.
static func walked_controls(tree: SceneTree) -> Source:
	var seen: Dictionary = {}
	var dock: Control = EventSheetEditor.new()
	tree.root.add_child(dock)
	dock.setup(EventSheetResource.new())
	_walk(dock, seen)
	_walk_drawn_tables(seen)
	_walk_theme_editor(dock, seen)
	_walk_context_menus(dock, seen)
	var keys: PackedStringArray = PackedStringArray()
	for key: Variant in seen:
		keys.append(str(key))
	keys.sort()
	dock.free()
	return Source.new("control walk", Binding.ADVISORY, keys)


# ── The plan ──


## What the given sources would have the harvest do to the CSVs as they stand.
static func plan(sources: Array) -> Plan:
	var carried: Dictionary = {}
	for key: String in template_keys():
		carried[key] = true
	var result: Plan = Plan.new()
	var derived: Dictionary = {}
	var queued: Dictionary = {}
	for source: Source in sources:
		for key: String in source.keys:
			derived[key] = true
			if carried.has(key) or queued.has(key):
				continue
			queued[key] = true
			if source.binding == Binding.OWED:
				result.append.append(key)
			else:
				result.advisory.append(key)
	for key: Variant in carried:
		if not derived.has(key):
			result.kept_by_hand.append(str(key))
	result.kept_by_hand.sort()
	result.advisory.sort()
	return result


## Writes the plan: the appended key into TEMPLATE.csv, and the same key with an EMPTY cell into
## each locale file, so lockstep holds and the blank-cell gate names the language still owing a
## word. Returns the files it touched - empty when there was nothing to add, which is the state a
## tree with no forgotten key is in.
static func apply(harvest: Plan) -> PackedStringArray:
	if harvest.is_empty():
		return PackedStringArray()
	var written: PackedStringArray = PackedStringArray()
	var file_names: PackedStringArray = PackedStringArray([TEMPLATE_FILE])
	for locale: String in LOCALES:
		file_names.append("%s.csv" % locale)
	# Lockstep is all nine files or none of them. Every file is read BEFORE the first write, so a
	# locale that is missing or unreadable refuses the whole apply instead of leaving eight files one
	# row longer than the ninth under a green exit.
	var texts: Dictionary = {}
	for file_name: String in file_names:
		var path: String = "%s/%s" % [TRANSLATIONS_DIR, file_name]
		var text: String = FileAccess.get_file_as_string(path)
		if text.is_empty():
			push_error("harvest: %s is missing or empty - nothing written, lockstep needs all nine" % path)
			return PackedStringArray()
		texts[file_name] = text if text.ends_with("
") else text + "
"
	for file_name: String in file_names:
		var path: String = "%s/%s" % [TRANSLATIONS_DIR, file_name]
		var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
		if file == null:
			push_error("harvest: cannot write %s - the nine files are no longer in lockstep, restore them from git" % path)
			return written
		file.store_string(texts[file_name])
		for key: String in harvest.append:
			file.store_csv_line(PackedStringArray([key, ""]))
		file.close()
		written.append(file_name)
	if written.size() != file_names.size():
		push_error("harvest: wrote %d of %d files - lockstep is broken, restore them from git" % [written.size(), file_names.size()])
	return written


# ── Reading the CSVs ──


## The keys TEMPLATE.csv carries, in its own append order.
static func template_keys() -> PackedStringArray:
	var keys: PackedStringArray = PackedStringArray()
	var file: FileAccess = FileAccess.open("%s/%s" % [TRANSLATIONS_DIR, TEMPLATE_FILE], FileAccess.READ)
	if file == null:
		return keys
	var header: bool = true
	while not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line()
		if row.size() == 1 and row[0].is_empty():
			continue
		if header:
			header = false
			continue
		keys.append(row[0])
	file.close()
	return keys


# ── Descriptor wording ──


## `only_ids` empty means every descriptor in the module qualifies.
static func _collect_module(path: String, only_ids: PackedStringArray, seen: Dictionary, keys: PackedStringArray) -> void:
	var script: GDScript = load(path)
	if script == null:
		return
	for descriptor: ACEDescriptor in script.get_descriptors():
		if not only_ids.is_empty() and not only_ids.has(descriptor.ace_id):
			continue
		collect_descriptor(descriptor, seen, keys)


## The seven roles ONE verb routes through the translation layer: display name, description,
## category, the reads-as sentence, and each parameter's label, description and dropdown option
## labels. Ids, templates and hints never translate and are not collected.
static func collect_descriptor(descriptor: ACEDescriptor, seen: Dictionary, keys: PackedStringArray) -> void:
	_add(descriptor.display_name, seen, keys)
	_add(descriptor.description, seen, keys)
	_add(descriptor.category, seen, keys)
	_add(descriptor.get_display_text(), seen, keys)
	for parameter: ACEParam in descriptor.params:
		if parameter == null:
			continue
		_add(parameter.get_param_name(), seen, keys)
		_add(parameter.get_param_description(), seen, keys)
		for option: Variant in parameter.options:
			if option is Dictionary:
				_add(str((option as Dictionary).get("label", "")), seen, keys)


## A translate() literal is its own key TO THE CHARACTER. Four shipped rows begin with a space -
## the sentence they tail onto supplies the one before them - and trimming a key here would have the
## harvest append a second, spaceless spelling of a row that is already translated in eight
## languages. Only the wording sources below trim, because a descriptor's field is authored text
## rather than a lookup key.
static func _add_verbatim(text: String, seen: Dictionary, keys: PackedStringArray) -> void:
	if text.is_empty() or seen.has(text):
		return
	seen[text] = true
	keys.append(text)


## A wording field, trimmed - the shape the vocabulary gate has always swept it in.
static func _add(text: String, seen: Dictionary, keys: PackedStringArray) -> void:
	var trimmed: String = text.strip_edges()
	if trimmed.is_empty() or seen.has(trimmed):
		return
	seen[trimmed] = true
	keys.append(trimmed)


## Every .gd under a folder, sorted, so two machines walk the tree in the same order.
static func scripts_under(dir_path: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	var files: PackedStringArray = DirAccess.get_files_at(dir_path)
	files.sort()
	for file_name: String in files:
		if file_name.ends_with(".gd"):
			found.append("%s/%s" % [dir_path, file_name])
	var dirs: PackedStringArray = DirAccess.get_directories_at(dir_path)
	dirs.sort()
	for sub_dir: String in dirs:
		found.append_array(scripts_under("%s/%s" % [dir_path, sub_dir]))
	return found


# ── Reading a translate() call ──


## The keys one script asks to translate: the literal argument of every translate() call, plus both
## halves of a `translate("A" if x else "B")`. Computed arguments answer nothing, on purpose.
static func translated_keys(text: String) -> PackedStringArray:
	var keys: PackedStringArray = PackedStringArray()
	var at: int = text.find(CALL)
	while at >= 0:
		keys.append_array(_keys_in(_argument_region(text, at + CALL.length() - 1)))
		at = text.find(CALL, at + CALL.length())
	return keys


## The text between a call's parentheses, walked by bracket depth and skipping quoted text so a
## parenthesis inside a string cannot end the argument early.
static func _argument_region(text: String, open_at: int) -> String:
	var depth: int = 0
	var quote: String = ""
	var index: int = open_at
	while index < text.length():
		var glyph: String = text[index]
		if not quote.is_empty():
			if glyph == "\\":
				index += 1
			elif glyph == quote:
				quote = ""
		elif glyph == "\"" or glyph == "'":
			quote = glyph
		elif glyph == "(":
			depth += 1
		elif glyph == ")":
			depth -= 1
			if depth == 0:
				return text.substr(open_at + 1, index - open_at - 1)
		index += 1
	return ""


## The literals a translate() argument stands for, "" when the argument is computed rather than
## written out. A region that does not START with a quote is computed; so is one that joins or
## formats (`+` / `%`), because the key that reaches the catalog is then not in the file at all.
static func _keys_in(region: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	var trimmed: String = region.strip_edges()
	if not trimmed.begins_with("\""):
		return found
	var index: int = 0
	var take: bool = true
	while index < trimmed.length():
		var glyph: String = trimmed[index]
		if glyph == "\"":
			index += 1
			var literal: String = ""
			while index < trimmed.length() and trimmed[index] != "\"":
				if trimmed[index] == "\\" and index + 1 < trimmed.length():
					literal += _unescaped(trimmed[index + 1])
					index += 2
					continue
				literal += trimmed[index]
				index += 1
			if take:
				found.append(literal)
				take = false
			index += 1
			continue
		if glyph == "+" or glyph == "%":
			return PackedStringArray()
		# The other arm of a ternary is a key of its own - both spellings reach the catalog.
		if trimmed.substr(index, 5) == "else ":
			take = true
			index += 5
			continue
		index += 1
	return found


static func _unescaped(marker: String) -> String:
	match marker:
		"n":
			return "\n"
		"t":
			return "\t"
		"\"":
			return "\""
		"\\":
			return "\\"
	return "\\" + marker




# ── The live editor's own strings (advisory) ──


static func _remember(seen: Dictionary, text: String) -> void:
	var trimmed: String = text.strip_edges()
	# Skip empties, bare glyphs, and obviously dynamic strings (paths, format leftovers).
	if trimmed.length() < 2 or trimmed.begins_with("res://") or trimmed.begins_with("user://"):
		return
	seen[trimmed] = true


static func _walk(node: Node, seen: Dictionary) -> void:
	if node is Window:
		_remember(seen, (node as Window).title)
	if node is Control:
		_remember(seen, (node as Control).tooltip_text)
	if node is Button:
		_remember(seen, (node as Button).text)
	elif node is Label:
		_remember(seen, (node as Label).text)
	elif node is LineEdit:
		_remember(seen, (node as LineEdit).placeholder_text)
	elif node is TextEdit:
		_remember(seen, (node as TextEdit).placeholder_text)
	if node is MenuButton or node is OptionButton:
		var popup: PopupMenu = (node as MenuButton).get_popup() if node is MenuButton else (node as OptionButton).get_popup()
		for index: int in range(popup.item_count):
			_remember(seen, popup.get_item_text(index))
			_remember(seen, popup.get_item_tooltip(index))
	if node is PopupMenu:
		for index: int in range((node as PopupMenu).item_count):
			_remember(seen, (node as PopupMenu).get_item_text(index))
	for child: Node in node.get_children(true):
		_walk(child, seen)


## The ROW context menu (and its Insert/More submenus) is rebuilt per right-click, so at harvest time
## those PopupMenus are empty - build it here for a representative EVENT row, in BOTH Simple and
## Expert modes and both live-state relabels (Clear Else / Enable Row ...), so every context-menu
## label surfaces.
static func _walk_context_menus(dock: Control, seen: Dictionary) -> void:
	var event_row: EventRow = EventRow.new()
	var probe: EventRowData = EventRowData.new()
	probe.row_type = EventRowData.RowType.EVENT
	probe.source_resource = event_row
	dock._context_row = probe
	for simple: bool in [true, false]:
		dock._simple_mode = simple
		for mode: int in [EventRow.ElseMode.NONE, EventRow.ElseMode.ELSE, EventRow.ElseMode.ELIF]:
			event_row.else_mode = mode
			dock._build_row_context_menu(probe)
			dock._configure_context_menu(dock._row_context_menu)
			for menu: PopupMenu in [dock._row_context_menu, dock._row_insert_submenu, dock._row_more_submenu]:
				if menu == null:
					continue
				for index: int in range(menu.item_count):
					_remember(seen, menu.get_item_text(index))
	# The GROUP and COMMENT row variants carry their own type-specific leading items.
	for row_type: int in [EventRowData.RowType.GROUP, EventRowData.RowType.COMMENT]:
		var typed_probe: EventRowData = EventRowData.new()
		typed_probe.row_type = row_type
		dock._context_row = typed_probe
		dock._build_row_context_menu(typed_probe)
		for index: int in range(dock._row_context_menu.item_count):
			_remember(seen, dock._row_context_menu.get_item_text(index))


## The Theme Editor is a lazy dialog (built only when opened), so it is not in the dock's tree at
## harvest time - build it here and walk its Controls plus its token-description table.
static func _walk_theme_editor(dock: Control, seen: Dictionary) -> void:
	var editor: EventSheetThemeEditor = EventSheetThemeEditor.new()
	var style: EventSheetEditorStyle = EventSheetEditorStyle.new()
	style.ensure_defaults()
	editor.open(dock, style)
	# open() builds the dialog and adds it under the dock; walk it, then the plain-language help.
	_walk(dock, seen)
	for description: Variant in EventSheetThemeEditor._TOKEN_DESCRIPTIONS.values():
		_remember(seen, str(description))


## The strings drawn straight to canvas (they never live on a Control) - collected from their data
## tables so a translator sees them without hunting through code.
static func _walk_drawn_tables(seen: Dictionary) -> void:
	var probe_sheets: Array = [null, EventSheetResource.new()]
	var behavior_sheet: EventSheetResource = EventSheetResource.new()
	behavior_sheet.behavior_mode = true
	var autoload_sheet: EventSheetResource = EventSheetResource.new()
	autoload_sheet.autoload_mode = true
	probe_sheets.append(behavior_sheet)
	probe_sheets.append(autoload_sheet)
	for sheet: Variant in probe_sheets:
		var advice: Dictionary = EventSheetScriptIntent.empty_sheet_advice(sheet)
		for value: Variant in advice.values():
			_remember(seen, str(value))
		for spec: Dictionary in ViewportEmptyStateHelper.cta_specs(sheet):
			_remember(seen, str(spec.get("label", "")))
	for affordance: String in ["+ Add action", "+ Add condition", "+ Add event…", "Every Tick", "Else", "Else If"]:
		_remember(seen, affordance)
	for template: String in [
		"%s - Behavior · acts on host: %s",
		"%s - Autoload · one instance, project-wide",
		"%s - Editor Tool · runs in the editor (File > Run)",
		"%s - Custom Resource · every .tres of it is a data asset",
		"Event Sheet · a script for the %s it's attached to",
		"%s - Custom Node · extends %s",
	]:
		_remember(seen, template)


# ── The command line ──


func _init() -> void:
	var dry_run: bool = OS.get_cmdline_user_args().has("--dry-run")
	var sources: Array = [editor_literals(), owed_vocabulary()]
	# THE ENGINE ERRORS THE NEXT LINES PRINT ARE EXPECTED, and saying so is the difference between
	# a command that looks like it failed and one that did what it says. The advisory walk builds
	# the real dock and its real dialogs with NO Godot editor around them, so a dialog that asks to
	# be shown is a window the engine cannot open and complains about. That is the price of reading
	# the live UI rather than a list of it: nothing below is derived from those lines, the two
	# BINDING sources are already read, and neither the verdict nor the exit code is made of them.
	print("walking the live editor - the engine errors printed until the census below are expected:")
	print("  the advisory walk opens real dialogs with no editor around them, and derives nothing.")
	sources.append(walked_controls(self))
	print("live editor walked; everything from here is the harvest.")
	var harvest: Plan = plan(sources)
	for source: Source in sources:
		print("%-16s %5d key(s)%s" % [source.title, source.keys.size(),
			"  (advisory)" if source.binding == Binding.ADVISORY else ""])
	print("kept by hand:  %5d row(s) no source derives - kept, never deleted" % harvest.kept_by_hand.size())
	print("advisory only: %5d string(s) the live editor shows that no CSV carries" % harvest.advisory.size())
	for key: String in harvest.advisory:
		print("   sees: %s" % key)
	if harvest.is_empty():
		print("harvest: nothing owed - the nine files are already complete.")
		quit(0)
		return
	print("harvest: %d owed key(s) missing" % harvest.append.size())
	for key: String in harvest.append:
		print("   owed: %s" % key)
	if dry_run:
		print("harvest: dry run, nothing written.")
		quit(1)
		return
	print("harvest: appended to %s" % ", ".join(apply(harvest)))
	quit(0)
