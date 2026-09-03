# EventForge - the lazy-cache latches
#
# ONE bug class, pinned in every place the tree holds it. A cache that uses its own EMPTINESS as
# "not derived yet" never latches when the derivation legitimately answers nothing, so the whole
# derivation runs again on every question. That is what froze the Add picker for nine and a half
# seconds on a sheet with no variables in scope: an empty catalog read as an underived one, and
# every one of the picker's rows asked again.
#
# The fix everywhere is the same - an explicit boolean the deriving function sets - and so is the
# pin: derive once, then EMPTY the cache behind the flag's back and ask again. A latch that holds
# hands back the empty cache untouched; an emptiness test rebuilds it, and the pin says so. Each
# section puts its cache back the way it found it, because these are session-wide statics that the
# rest of the suite reads.
@tool
class_name CacheLatchTest
extends RefCounted


const SUPPORT := preload("res://tests/support.gd")

const TEST_NAME := "cache_latch"


static func run() -> bool:
	var passed: bool = _pin_builtin_descriptor_cache()
	passed = _pin_builtin_definition_cache() and passed
	passed = _pin_curated_templates() and passed
	passed = _pin_lift_families() and passed
	passed = _pin_builtin_descriptor_index() and passed
	passed = _pin_category_hosts() and passed
	passed = _pin_the_picker_catalog() and passed
	return passed


## The root of the chain: every other cache below reaches the vocabulary through this one, and the
## derivation behind it loads every vocabulary module off disk.
static func _pin_builtin_descriptor_cache() -> bool:
	ACERegistry.clear_cache()
	var derived: int = ACERegistry.get_builtin_descriptors().size()
	ACERegistry._builtin_cache.clear()
	var after_emptying: int = ACERegistry.get_builtin_descriptors().size()
	ACERegistry.clear_cache()
	var rebuilt: int = ACERegistry.get_builtin_descriptors().size()
	return SUPPORT.pins(TEST_NAME, [
		["the builtin descriptors derive", derived > 0, true],
		["an empty builtin cache is not derived again behind the latch", after_emptying, 0],
		["clear_cache() drops the latch as well as the cache", rebuilt, derived],
	])


## The editor-side half: descriptors adapted into definitions, rebuilt on every tab activation.
static func _pin_builtin_definition_cache() -> bool:
	var registry: EventSheetACERegistry = EventSheetACERegistry.new()
	registry.refresh_from_sources([], true)
	var derived: int = EventSheetACERegistry._builtin_definition_cache.size()
	EventSheetACERegistry._builtin_definition_cache.clear()
	var empty_registry: EventSheetACERegistry = EventSheetACERegistry.new()
	empty_registry.refresh_from_sources([], true)
	var after_emptying: int = empty_registry.get_all_definitions().size()
	# Put it back: the rest of the suite asks this registry for a real vocabulary.
	EventSheetACERegistry._builtin_definitions_derived = false
	EventSheetACERegistry.new().refresh_from_sources([], true)
	var rebuilt: int = EventSheetACERegistry._builtin_definition_cache.size()
	return SUPPORT.pins(TEST_NAME, [
		["the builtin definitions derive", derived > 0, true],
		["an empty builtin definition cache is not adapted again behind the latch", after_emptying, 0],
		["dropping the latch derives them again", rebuilt, derived],
	])


## The shadow filter's needle set. Its fill is FILTERED - a descriptor with a blank template
## contributes nothing - so an empty answer is reachable without anything being broken.
static func _pin_curated_templates() -> bool:
	EventSheetClassDBSource._curated_templates.clear()
	EventSheetClassDBSource._curated_templates_built = false
	EventSheetClassDBSource._cache.clear()
	EventSheetClassDBSource.definitions_for_class("Node")
	var derived: int = EventSheetClassDBSource._curated_templates.size()
	EventSheetClassDBSource._curated_templates.clear()
	EventSheetClassDBSource._cache.clear()
	EventSheetClassDBSource.definitions_for_class("Node")
	var after_emptying: int = EventSheetClassDBSource._curated_templates.size()
	EventSheetClassDBSource._curated_templates_built = false
	EventSheetClassDBSource._cache.clear()
	EventSheetClassDBSource.definitions_for_class("Node")
	var rebuilt: int = EventSheetClassDBSource._curated_templates.size()
	return SUPPORT.pins(TEST_NAME, [
		["the curated templates derive", derived > 0, true],
		["an empty needle set is not walked again behind the latch", after_emptying, 0],
		["dropping the latch walks the modules again", rebuilt, derived],
	])


## The reading panel's family tables. The walk behind them answers {} whenever its folder cannot be
## opened, and the question is asked per family, per line, per refresh.
static func _pin_lift_families() -> bool:
	EventSheetLiftReading.clear_cache()
	var derived: int = EventSheetLiftReading._families().size()
	EventSheetLiftReading._family_cache.clear()
	var after_emptying: int = EventSheetLiftReading._families().size()
	# THROUGH THE REAL DOOR. clear_cache() is what the reading panel calls when a developer appends
	# a draft, and a latch that stayed up over the emptied tables would answer "no families, and
	# yes I looked" for the rest of the session - so the flag has to come down with them, and the
	# pin has to drive the door rather than reach past it.
	EventSheetLiftReading.clear_cache()
	var rebuilt: int = EventSheetLiftReading._families().size()
	return SUPPORT.pins(TEST_NAME, [
		["the lift families derive", derived > 0, true],
		["an empty family table is not re-read behind the latch", after_emptying, 0],
		["clear_cache() drops the latch as well as the tables", rebuilt, derived],
	])


## The public API's ace_id index, behind every builtin_action() an asset drop makes.
static func _pin_builtin_descriptor_index() -> bool:
	EventSheets._builtin_descriptor_index.clear()
	EventSheets._builtin_descriptor_index_built = false
	EventSheets._builtin_descriptor("wait")
	var derived: int = EventSheets._builtin_descriptor_index.size()
	EventSheets._builtin_descriptor_index.clear()
	EventSheets._builtin_descriptor("wait")
	var after_emptying: int = EventSheets._builtin_descriptor_index.size()
	EventSheets._builtin_descriptor_index_built = false
	EventSheets._builtin_descriptor("wait")
	var rebuilt: int = EventSheets._builtin_descriptor_index.size()
	return SUPPORT.pins(TEST_NAME, [
		["the descriptor index derives", derived > 0, true],
		["an empty index is not rebuilt behind the latch", after_emptying, 0],
		["dropping the latch rebuilds it", rebuilt, derived],
	])


## The picker's category-to-host map, consulted for every section header it draws. Its fill is
## filtered on having a real ClassDB host, so a host-agnostic vocabulary derives an empty map.
static func _pin_category_hosts() -> bool:
	ACEPickerDialog._category_hosts.clear()
	ACEPickerDialog._category_hosts_derived = false
	var derived: int = ACEPickerDialog._category_host_classes().size()
	ACEPickerDialog._category_hosts.clear()
	var after_emptying: int = ACEPickerDialog._category_host_classes().size()
	ACEPickerDialog._category_hosts_derived = false
	var rebuilt: int = ACEPickerDialog._category_host_classes().size()
	return SUPPORT.pins(TEST_NAME, [
		["the category hosts derive", derived > 0, true],
		["an empty host map is not walked again behind the latch", after_emptying, 0],
		["dropping the latch walks the vocabulary again", rebuilt, derived],
	])


## The one this class of bug was found in, counted rather than emptied: a provider that answers
## nothing is still asked exactly once per open.
static func _pin_the_picker_catalog() -> bool:
	var picker: ACEPickerDialog = ACEPickerDialog.new()
	var calls: Array[int] = [0]
	picker.set_variable_catalog_provider(func() -> Array:
		calls[0] += 1
		return [])
	for repeat in 50:
		picker._variables_in_scope()
	return SUPPORT.pins(TEST_NAME, [
		["fifty asks of an empty catalog derive it once", calls[0], 1],
	])
