@tool
class_name PickerSearchWordsTest
extends RefCounted

# EventForge - the picker finds the measuring rows by the words a reader types when a game runs badly.
#
# A row carries search words beside it (its `tags` metadata: a builtin descriptor's `.tagged(...)`, a
# pack's `@ace_tags`), and the search ranks what it found: a row named by the typed word first, then a
# row whose search words or category start with it, then everything else. These pins hold:
#   1. the words a reader types ("slow", "lag", "fps", "profiler", ...) put the rows they want first;
#   2. the ranking rule on stand-in rows: the exact name, then a name that starts the word, then a search
#      word, then the help text or the middle of another word ("flag" never leads "lag");
#   3. the words are data: they change no id, template, sentence or category, and an untagged row keeps
#      the metadata it always had;
#   4. the words are searched the same under another interface language.

const SUPPORT := preload("res://tests/support.gd")
const PACKS: Array[String] = [
	"res://eventsheet_addons/debug_overlay/debug_overlay_addon.gd",
	"res://eventsheet_addons/time_slicer/time_slicer_behavior.gd",
	"res://eventsheet_addons/object_pool/object_pool_addon.gd",
]


static func run() -> bool:
	var ok: bool = _typed_words_find_the_measuring_rows()
	ok = _ranking_rule() and ok
	ok = _words_are_data_beside_the_row() and ok
	ok = _words_search_the_same_in_another_language() and ok
	return ok


static func _registry() -> EventSheetACERegistry:
	var registry: EventSheetACERegistry = EventSheetACERegistry.new()
	var sources: Array[Object] = []
	for path: String in PACKS:
		sources.append(load(path).new())
	registry.refresh_from_sources(sources, true)
	return registry


static func _first(registry: EventSheetACERegistry, word: String, count: int) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	for definition: ACEDefinition in EventSheetACERegistry.rank_for_query(registry.search(word), word).slice(0, count):
		found.append("%s::%s" % [definition.provider_id, definition.id])
	return found


static func _typed_words_find_the_measuring_rows() -> bool:
	var registry: EventSheetACERegistry = _registry()
	var rows: Array = []
	var table: Dictionary = {
		"lag": ["Core::BeginFrameBudget", "Core::AwaitIfOverBudget", "Core::GetPerfMonitor", "Core::GetStaticMemory"],
		"laggy": ["Core::FrameOverBudget", "Core::FpsBelowFor", "Core::FrameRunningLong", "Core::FrameRecovered"],
		"fps": ["Core::GetFps", "Core::FpsBelowFor", "Core::SetMaxFps", "Core::WindowSetMaxFps"],
		"framerate": ["Core::GetPerfMonitor", "Core::FrameOverBudget", "Core::FpsBelowFor", "Core::FrameRunningLong"],
		"profiler": ["Core::GetPerfMonitor", "Core::GetStaticMemory", "Core::FrameOverBudget", "Core::FpsBelowFor"],
		"stutter": ["Core::AwaitNextFrame", "Core::BeginFrameBudget", "Core::AwaitIfOverBudget", "Core::FrameOverBudget"],
		"hitch": ["Core::AwaitNextFrame", "Core::BeginFrameBudget", "Core::AwaitIfOverBudget", "Core::FrameOverBudget"],
		"optimize": ["Core::AwaitNextFrame", "Core::BeginFrameBudget", "Core::AwaitIfOverBudget", "Core::GetPerfMonitor"],
		"timing": ["Core::StartMeasuring", "Core::StopMeasuring", "Core::MeasuredLast", "Core::MeasuredAverage"],
		"benchmark": ["Core::GetStaticMemory", "Core::StartMeasuring", "Core::StopMeasuring", "Core::MeasuredLast"],
		"measure": ["Core::MeasuredLast", "Core::MeasuredAverage", "Core::MeasuredPeak", "Core::LogMeasurements"],
		"monitor": ["Core::GetMonitoring", "Core::GetPerfMonitor", "Core::ShowInMonitors", "Core::RemoveFromMonitors"],
		"budget": ["Core::BeginFrameBudget", "Core::AwaitIfOverBudget", "TimeSlicerBehavior::property:frame_budget_ms", "TimeSlicerBehavior::set:frame_budget_ms"],
	}
	for word: Variant in table:
		rows.append([str(word), _first(registry, str(word), 4), PackedStringArray(table[word])])
	# "slow" leads with the rows NAMED slow (the slowest particle) and then reaches the measuring rows.
	var slow: PackedStringArray = _first(registry, "slow", 12)
	rows.append(["slow reaches the frame budget rows", slow.has("Core::BeginFrameBudget"), true])
	rows.append(["slow reaches the performance monitor", slow.has("Core::GetPerfMonitor"), true])
	# The rows every reader of a slow game wants are each reachable by the plainest word for them.
	var wanted: Dictionary = {
		"Core::StartMeasuring": "profiler", "Core::StopMeasuring": "profiler", "Core::MeasuredLast": "profiler",
		"Core::MeasuredAverage": "profiler", "Core::MeasuredPeak": "profiler", "Core::ShowInMonitors": "profiler",
		"Core::RemoveFromMonitors": "profiler", "Core::IsInMonitors": "profiler", "Core::FrameOverBudget": "slow",
		"Core::FrameRunningLong": "lag", "Core::BeginFrameBudget": "slow", "Core::AwaitNextFrame": "stutter",
		"Core::GetFps": "fps", "TimeSlicerBehavior::method:set_frame_budget": "lag",
		"ObjectPoolAddon::method:create_pool": "lag", "DebugOverlayAddon::method:show_overlay": "profiler",
	}
	for key: Variant in wanted:
		var typed: String = str(wanted[key])
		rows.append(["%s is found by %s" % [key, typed], _first(registry, typed, 400).has(str(key)), true])
	return SUPPORT.pins("picker_search_words_test", rows)


static func _stand_in(display_name: String, category: String, description: String, tags: Array) -> ACEDefinition:
	var definition: ACEDefinition = ACEDefinition.new()
	definition.provider_id = "Stand"
	definition.id = display_name.replace(" ", "")
	definition.display_name = display_name
	definition.category = category
	definition.description = description
	definition.metadata = {"tags": tags}
	return definition


static func _names(definitions: Array[ACEDefinition]) -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	for definition: ACEDefinition in definitions:
		names.append(definition.display_name)
	return names


static func _ranking_rule() -> bool:
	var in_help: ACEDefinition = _stand_in("Spawn Wave", "Waves", "Spreads the work so the game does not lag.", [])
	var in_flag: ACEDefinition = _stand_in("Set Flag", "Flags", "Raises a flag.", [])
	var by_word: ACEDefinition = _stand_in("Start Stopwatch", "Debug", "Starts a stopwatch.", ["lag", "slow"])
	var by_name: ACEDefinition = _stand_in("Lag Meter", "Debug", "Shows lag.", [])
	var by_exact: ACEDefinition = _stand_in("Lag", "Debug", "One word.", [])
	var found: Array[ACEDefinition] = [in_help, in_flag, by_word, by_name, by_exact]
	var by_category: Array[ACEDefinition] = [in_help, _stand_in("Show Bars", "Performance", "Draws bars.", [])]
	var plain: Array[ACEDefinition] = [in_help, in_flag]
	var two_words: Array[ACEDefinition] = [in_flag, by_word]
	return SUPPORT.pins("picker_search_words_test", [
		["exact name, name word, search word, then help text and the middle of a word, each in its old order",
			_names(EventSheetACERegistry.rank_for_query(found, "lag")),
			PackedStringArray(["Lag", "Lag Meter", "Start Stopwatch", "Spawn Wave", "Set Flag"])],
		["a word on the category ranks above a hit in the help text",
			_names(EventSheetACERegistry.rank_for_query(by_category, "perf")), PackedStringArray(["Show Bars", "Spawn Wave"])],
		["an empty query leaves the order alone", _names(EventSheetACERegistry.rank_for_query(plain, "  ")), _names(plain)],
		["two words must both start words", _names(EventSheetACERegistry.rank_for_query(two_words, "start stop"))[0], "Start Stopwatch"],
	])


static func _words_are_data_beside_the_row() -> bool:
	var plain: ACEDescriptor = ACEDescriptor.new()
	plain.provider_id = "Demo"
	plain.ace_id = "Plain"
	var tagged: ACEDescriptor = ACEDescriptor.new()
	tagged.provider_id = "Demo"
	tagged.ace_id = "Plain"
	tagged.tagged("slow lag slow").tagged("profiler")
	var plain_definition: ACEDefinition = EventSheetACEAdapter.from_eventforge_descriptor(plain)
	var tagged_definition: ACEDefinition = EventSheetACEAdapter.from_eventforge_descriptor(tagged)
	var without_tags: Dictionary = tagged_definition.metadata.duplicate()
	without_tags.erase("tags")
	var shipped: ACEDefinition = _registry().find_definition("Core", "StartMeasuring")
	return SUPPORT.pins("picker_search_words_test", [
		["the words are listed once each", tagged.search_tags, PackedStringArray(["slow", "lag", "profiler"])],
		["the words ride the tags metadata", tagged_definition.metadata.get("tags"), ["slow", "lag", "profiler"]],
		["an untagged row has no tags key at all", plain_definition.metadata.has("tags"), false],
		["every other piece of metadata is the same", without_tags, plain_definition.metadata],
		["a shipped row keeps its id, name and category", [shipped.id, shipped.display_name, shipped.category],
			["StartMeasuring", "Start Measuring", "Debug"]],
		["a shipped row's words are in its search text", shipped.get_search_text().contains("profiler"), true],
	])


static func _words_search_the_same_in_another_language() -> bool:
	var registry: EventSheetACERegistry = _registry()
	var before: String = TranslationServer.get_locale()
	var english: PackedStringArray = _first(registry, "profiler", 6)
	TranslationServer.set_locale("es")
	var spanish: PackedStringArray = _first(registry, "profiler", 6)
	TranslationServer.set_locale(before)
	return SUPPORT.pins("picker_search_words_test", [
		["the same rows answer under Spanish", spanish, english],
		["and they are the measuring rows", english.slice(0, 2), PackedStringArray(["Core::GetPerfMonitor", "Core::GetStaticMemory"])],
	])
