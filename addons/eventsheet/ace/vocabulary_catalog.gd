# EventSheet - the vocabulary override catalog (interop phase 3).
#
# Refinement for REFLECTED verbs - rename one, recategorize it, hide it, or drop a whole
# class - without touching the user's source file. One project resource holds only the
# differences from what inference produced, which gives the catalog its defining property:
#
#   DELETING IT MAY NEVER BREAK A SHEET.
#
# Ids, emitted calls and every applied row are untouched by anything in here; the catalog
# only changes how a verb PRESENTS in the picker. A sheet row bakes its own call when
# applied, so a project that loses this file falls back to inference and keeps compiling
# byte-identically. That is the whole reason overrides live here rather than in the row.
#
# Resolution order is source annotation > catalog > inference. The first step is enforced by
# only ever applying to definitions marked `reflected` in their metadata: a script that says
# what it is through `@ace_*` annotations is never overruled by this side file (the editor
# routes such an edit to the source instead, which is phase 4's bake).
#
# Immutability: definitions are shared and cached, so an override never writes into one -
# apply() returns duplicates and passes untouched definitions through by reference.
@tool
class_name EventSheetVocabularyCatalog
extends Resource

const DEFAULT_PATH: String = "res://eventsheet_vocabulary.tres"

## "Provider::ace_id" -> {display_name?: String, category?: String, hidden?: bool}
@export var overrides: Dictionary = {}
## Whole classes the user does not want offered at all.
@export var excluded_classes: PackedStringArray = PackedStringArray()

static var _cache: EventSheetVocabularyCatalog = null
static var _loaded: bool = false
static var _path_override: String = ""


## The project's catalog, or an empty one when the file does not exist (the normal state -
## the catalog is created on first override, never required).
static func load_catalog() -> EventSheetVocabularyCatalog:
	if _loaded and _cache != null:
		return _cache
	_loaded = true
	var path: String = catalog_path()
	if ResourceLoader.exists(path):
		var loaded: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
		if loaded is EventSheetVocabularyCatalog:
			_cache = loaded
			return _cache
	_cache = EventSheetVocabularyCatalog.new()
	return _cache


## Writes the catalog, or DELETES it when nothing is overridden any more - an empty file
## would be a confusing artifact in a project that has no overrides.
static func save_catalog(catalog: EventSheetVocabularyCatalog) -> bool:
	_cache = catalog
	_loaded = true
	var path: String = catalog_path()
	if catalog.overrides.is_empty() and catalog.excluded_classes.is_empty():
		if ResourceLoader.exists(path):
			DirAccess.remove_absolute(path)
		return true
	return ResourceSaver.save(catalog, path) == OK


static func catalog_path() -> String:
	return _path_override if not _path_override.is_empty() else DEFAULT_PATH


## The override key for one verb. Static + pure, and the ONLY place the key shape is built.
static func key_for(provider_id: String, ace_id: String) -> String:
	return "%s::%s" % [provider_id, ace_id]


## Records one verb's overrides ({} or a null field clears that facet) and persists.
static func set_override(provider_id: String, ace_id: String, edits: Dictionary) -> void:
	var catalog: EventSheetVocabularyCatalog = load_catalog()
	var key: String = key_for(provider_id, ace_id)
	var entry: Dictionary = (catalog.overrides.get(key, {}) as Dictionary).duplicate()
	for field: Variant in edits.keys():
		var value: Variant = edits[field]
		if value == null or (value is String and (value as String).strip_edges().is_empty()):
			entry.erase(str(field))
		else:
			entry[str(field)] = value
	if entry.is_empty():
		catalog.overrides.erase(key)
	else:
		catalog.overrides[key] = entry
	save_catalog(catalog)


## Hides or restores a whole class (its card and all its verbs).
static func set_class_excluded(class_id: String, excluded: bool) -> void:
	var catalog: EventSheetVocabularyCatalog = load_catalog()
	var names: PackedStringArray = catalog.excluded_classes.duplicate()
	var at: int = names.find(class_id)
	if excluded and at == -1:
		names.append(class_id)
	elif not excluded and at != -1:
		names.remove_at(at)
	catalog.excluded_classes = names
	save_catalog(catalog)


static func is_class_excluded(class_id: String) -> bool:
	return load_catalog().excluded_classes.has(class_id)


## The catalog's view of a reflected definition set: renamed, recategorized, hidden entries
## dropped. Definitions WITHOUT an override pass through by reference (no needless copies);
## overridden ones are duplicated first, so the shared cached definition is never mutated.
static func apply(definitions: Array) -> Array[ACEDefinition]:
	var catalog: EventSheetVocabularyCatalog = load_catalog()
	var out: Array[ACEDefinition] = []
	for definition: ACEDefinition in definitions:
		# Source annotations outrank the catalog: only raw reflection is refined here.
		if not bool(definition.metadata.get("reflected", false)):
			out.append(definition)
			continue
		if catalog.excluded_classes.has(str(definition.provider_id)):
			continue
		var entry: Dictionary = catalog.overrides.get(key_for(str(definition.provider_id), str(definition.id)), {})
		if entry.is_empty():
			out.append(definition)
			continue
		if bool(entry.get("hidden", false)):
			continue
		# copy(), never duplicate(): the fields are plain vars, so Resource.duplicate()
		# would hand back a blank definition that publishes nothing.
		var refined: ACEDefinition = definition.copy()
		if entry.has("display_name"):
			var renamed: String = str(entry["display_name"])
			refined.display_name = renamed
			# The sentence leads with the display name, so a rename must carry into it -
			# otherwise the row keeps announcing the old name beside the new picker entry.
			var template: String = str(refined.metadata.get("display_template", ""))
			if not template.is_empty():
				var slots: String = template.trim_prefix(str(definition.display_name))
				refined.metadata["display_template"] = renamed + slots
		if entry.has("category"):
			refined.category = str(entry["category"])
		refined.metadata["curated"] = true
		out.append(refined)
	return out


## Where a verb's identity came from, so the picker can SAY so rather than leaving the user
## to guess whether a name was authored or derived:
##   "curated"  - reflected, and you renamed/recategorized it here
##   "inferred" - reflected from a script, nobody has refined it
##   ""         - authored vocabulary (a builtin or an annotated provider), the baseline
##                that needs no label
## Static + pure; the empty case is deliberate - chips exist to mark DERIVED entries, and
## labelling everything would just add noise to the 900+ curated verbs.
static func provenance_of(definition: ACEDefinition) -> String:
	if definition == null or not bool(definition.metadata.get("reflected", false)):
		return ""
	return "curated" if bool(definition.metadata.get("curated", false)) else "inferred"


## The tooltip line for a derived verb: what it is, where it came from, and that the user
## can change it. "" for authored vocabulary.
static func provenance_note(definition: ACEDefinition) -> String:
	match provenance_of(definition):
		"curated":
			return "From your project's %s - renamed by you. Right-click to edit or hide." % definition.provider_id
		"inferred":
			return "From your project's %s - inferred from the script, not curated. Right-click to rename or hide." % definition.provider_id
	return ""


## The curation edits that would write this class's overrides INTO its script, as the
## annotation writer's edit shape. Static + pure - the caller does the file write, so the
## translation can be pinned without touching a file.
##
## Only the facets the catalog owns are translated: a rename becomes `@ace_name`, a category
## becomes `@ace_category`, a hidden verb becomes `@ace_hidden`. The member name and its
## declaration kind are recovered from the reflected id (`method:take_damage`), which is the
## same shape the writer anchors on.
static func bake_edits_for(class_id: String) -> Array:
	var catalog: EventSheetVocabularyCatalog = load_catalog()
	var edits: Array = []
	for key: Variant in catalog.overrides.keys():
		var parts: PackedStringArray = str(key).split("::", true, 1)
		if parts.size() != 2 or parts[0] != class_id:
			continue
		var member_info: Dictionary = member_from_ace_id(parts[1])
		if member_info.is_empty():
			continue
		var entry: Dictionary = catalog.overrides[key]
		var edit: Dictionary = {"source_kind": str(member_info["source_kind"]), "member": str(member_info["member"])}
		if entry.has("display_name"):
			edit["name"] = str(entry["display_name"])
		if entry.has("category"):
			edit["category"] = str(entry["category"])
		if bool(entry.get("hidden", false)):
			edit["hidden"] = true
		edits.append(edit)
	return edits


## The member + declaration kind behind a reflected ace id: `method:take_damage` ->
## {"source_kind": "method", "member": "take_damage"}; `property:set:health` and
## `property:get:health` both name the property. {} for anything unrecognised, so a future id
## shape degrades to "not bakeable" rather than writing an annotation onto the wrong line.
static func member_from_ace_id(ace_id: String) -> Dictionary:
	if ace_id.begins_with("method:"):
		return {"source_kind": "method", "member": ace_id.trim_prefix("method:")}
	if ace_id.begins_with("signal:"):
		return {"source_kind": "signal", "member": ace_id.trim_prefix("signal:")}
	if ace_id.begins_with("property:set:"):
		return {"source_kind": "property", "member": ace_id.trim_prefix("property:set:")}
	if ace_id.begins_with("property:get:"):
		return {"source_kind": "property", "member": ace_id.trim_prefix("property:get:")}
	return {}


## Drops every override for a class - used after a successful bake, because the source now
## owns those facts and source outranks the catalog. Leaving both would be a second truth
## that silently does nothing.
static func clear_class_overrides(class_id: String) -> void:
	var catalog: EventSheetVocabularyCatalog = load_catalog()
	for key: Variant in catalog.overrides.keys().duplicate():
		var parts: PackedStringArray = str(key).split("::", true, 1)
		if parts.size() == 2 and parts[0] == class_id:
			catalog.overrides.erase(key)
	save_catalog(catalog)


## Tests only: a clean slate pointed at a scratch path, so a run never touches the project's
## real catalog.
static func reset_for_tests(path_override: String = "") -> void:
	_cache = null
	_loaded = false
	_path_override = path_override
