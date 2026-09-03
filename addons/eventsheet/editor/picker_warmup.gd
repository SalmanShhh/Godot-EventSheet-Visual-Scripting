# EventSheet - what the Add picker would otherwise pay for on the first click of a session.
#
# Opening the picker asks a handful of questions whose FIRST answer costs real time and whose
# second costs nothing: which classes this project publishes, what each installed pack adds to the
# editor, and the reflected members of a Godot class. None of them depend on anything the reader
# does, so none of them has any business being on the click.
#
# So they are asked during idle, a slice at a time, once the dock is up. The budget is a few
# milliseconds per frame: a warm that stalls the editor for a third of a second has moved the
# freeze rather than removed it, and the reader would feel it in the middle of typing somewhere
# else entirely.
#
# ONLY IN THE EDITOR. A headless run - a test, the Doctor's command line, a build - has no frames
# to spread work over and no picker to warm, so `request()` schedules nothing there and every
# question is answered the first time it is genuinely asked. A warm that ran during a suite would
# make a test pass or fail on whether an idle frame happened to arrive.
@tool
class_name EventSheetPickerWarmup
extends RefCounted

## The most one slice may spend. Four milliseconds leaves the rest of a 16 ms frame to the editor.
const SLICE_BUDGET_MSEC: int = 4

## The questions, in the order the picker asks them. Empty until request() fills it.
static var _steps: Array[Callable] = []
static var _next: int = 0
static var _started: bool = false
static var _pumping: bool = false


## Starts the warm if it has not started. Cheap to call, and a second call while one is running is
## ignored rather than starting a second pass.
static func request() -> void:
	if _started:
		return
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or not Engine.is_editor_hint():
		return
	_started = true
	_next = 0
	_steps = _build_steps()
	_arm()


## True once every question has been asked. What a test reads; nothing in the editor waits on it.
static func is_warm() -> bool:
	return _started and _next >= _steps.size()


## Asks questions until the budget is spent, and answers whether that finished the warm. One step
## is always taken, however long it turns out to be - a budget that can decline to start makes no
## progress at all on a machine slow enough to blow it on the frame's own work.
static func advance(budget_msec: int = SLICE_BUDGET_MSEC) -> bool:
	var deadline: int = Time.get_ticks_msec() + maxi(budget_msec, 1)
	while _next < _steps.size():
		var step: Callable = _steps[_next]
		_next += 1
		if step.is_valid():
			step.call()
		if Time.get_ticks_msec() >= deadline:
			break
	return _next >= _steps.size()


## The whole warm, now. Nothing in the shipped editor calls this - it is here so a test can ask the
## same questions in the same order without depending on frames arriving.
static func warm_now() -> void:
	if not _started:
		_started = true
		_next = 0
		_steps = _build_steps()
	while _next < _steps.size():
		advance(1000000)


## Asks the questions again, because the answers were dropped. The editor's filesystem ping drops
## the pack censuses and the row icons the warm filled, and without this the "first open pays
## nothing" property would last only until the reader's first save - the warm being a once-a-session
## static, the second first-open would pay for all of it again on the click.
static func rearm() -> void:
	if not _started:
		return
	_next = 0
	_steps = _build_steps()
	_arm()


## Tests only: forget that a warm ran, so the next request() starts a fresh one.
static func reset_for_tests() -> void:
	_steps = []
	_next = 0
	_started = false
	_pumping = false


## One callable per question. Per PACK rather than per pack folder in one go, because reading a
## folder of scripts is the expensive half and a hundred and fifteen of them in one frame is a
## stall wherever it happens.
static func _build_steps() -> Array[Callable]:
	var steps: Array[Callable] = []
	# Which classes this project publishes - the object cards' "Your Project" section, and the
	# reflection behind any of them a reader picks.
	steps.append(func() -> void: EventSheetProjectScanner.list_project_classes())
	# What each installed pack adds to the EDITOR, which is the line on its object card. One read of
	# that pack's scripts, remembered until the filesystem changes.
	for pack_directory: String in EventSheetEditorToolCensus.pack_directories():
		steps.append(func() -> void: EventSheetEditorToolCensus.from_pack(pack_directory))
	# The reflected members of a Godot class, which also builds the shadow filter's needle set that
	# every later class shares. Node because every sheet's host derives from it.
	steps.append(func() -> void: EventSheetClassDBSource.definitions_for_class("Node"))
	# And the row icons, in slices. A pack's icon is a texture on disk and the first row that wants
	# it loads it; doing every one of them in a single step would be the stall this warm exists to
	# avoid, so the vocabulary is divided into a fixed number of slices and each is its own step.
	for slice_index in ICON_SLICES:
		steps.append(func() -> void: _warm_icons(slice_index))
	return steps


## How many steps the icon warm is spread over. Chosen so a slice is a few milliseconds on a
## vocabulary the size of this repository's, and smaller still on a project with fewer packs.
const ICON_SLICES: int = 32


## The icons of one slice of the vocabulary, resolved into the picker's own path cache. Reads the
## live vocabulary at RUN time rather than at build time: the warm is armed before the registry is
## refreshed, and an empty answer here simply warms nothing.
static func _warm_icons(slice_index: int) -> void:
	var verbs: Array[ACEDefinition] = EventSheets.all_verbs()
	if verbs.is_empty():
		return
	var per_slice: int = int(ceil(float(verbs.size()) / float(ICON_SLICES)))
	var from_index: int = slice_index * per_slice
	var to_index: int = mini(from_index + per_slice, verbs.size())
	for index in range(from_index, to_index):
		ACEPickerDialog.resolve_definition_icon(verbs[index])


static func _arm() -> void:
	if _pumping:
		return
	_pumping = _schedule_slice()


## Puts the next slice on the NEXT FRAME, and answers whether it got there.
##
## The frame signal rather than a deferred call, for the reason the share index gives: a deferred
## call is flushed at the end of the frame that posted it and that flush is re-entrant, so a slice
## that re-armed with one would run inside the same flush and the whole warm would land in a single
## frame - which is the stall the budget exists to prevent. A connection made while a signal is
## being emitted is not part of that emission, so this is one slice per frame and no more.
static func _schedule_slice() -> bool:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or not Engine.is_editor_hint():
		return false
	tree.process_frame.connect(Callable(EventSheetPickerWarmup, "_pump"), CONNECT_ONE_SHOT)
	return true


static func _pump() -> void:
	_pumping = false
	if not advance():
		_arm()
