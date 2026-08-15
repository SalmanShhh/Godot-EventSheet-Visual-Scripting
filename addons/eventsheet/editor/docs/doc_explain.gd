# EventSheet - EventSheetDocExplain: "what does this row do?", assembled from the LIVE vocabulary.
#
# Zero Markdown, zero bundled corpus. Everything a reader is shown here is the same data the
# picker and the row hover already draw - the definition's own name, description, parameters and
# codegen template, its category's blurb, and its pack's guide link - so this page can never rot
# against the editor. If a verb is renamed, this page renames with it.
#
# The file is deliberately STATIC and PURE: it turns identity (a doc id, an ACEDefinition, or a
# clicked row) into a list of block dictionaries, and never touches a Control. The panel that
# draws them is a separate file, so the assembly is testable headlessly and a second host (a
# side dock, later) can draw the same blocks differently.
#
# THE DOC ID SCHEME (public, frozen with EventSheets.open_docs):
#   ""                                  the index - the online guide list
#   "ace:<provider_id>/<ace_id>"        one verb ("ace:QuestPackAddon/method:advance_objective")
#   "section:<header text>"             a picker category ("section:Physics")
#   "addon:<pack directory>"            a pack's guide ("addon:quest")
# An id that parses but names nothing real is INVALID - callers get false and a warning, never a
# blank page, because a silently empty doc surface is how a renamed guide ships unnoticed.
#
# BLOCK KINDS the panel understands. Each is a Dictionary with a "kind" key:
#   title      text, subtitle              the verb or section name, and its type + category
#   note       text                        a deprecation steer (loud, above the prose)
#   prose      text                        what it does, in the reader's language
#   ships_as   code                        the GDScript line it compiles to
#   params     items:[{name, detail}]      each parameter, its type, default and blurb
#   about      title, text                 the category blurb - "what is this whole group for"
#   figure     definition                  a live, insertable illustration (Phase 1's widget)
#   link       label, target               read more: a pack guide path or an absolute URL
@tool
class_name EventSheetDocExplain
extends RefCounted

const SCHEME_ACE := "ace:"
const SCHEME_SECTION := "section:"
const SCHEME_ADDON := "addon:"

## Where zero-config packs live. A pack directory that is not here names nothing real, which is
## what makes "addon:<pack>" fail loudly instead of opening a 404 in the reader's browser.
const PACK_ROOT := "res://eventsheet_addons"


## Parses a doc id into what it names. Always returns the same shape, so a caller reads
## `valid` first and then the fields for its scheme:
##   {valid, scheme, provider_id, ace_id, section, pack, target}
## `target` is filled for the addon scheme only - the repo-relative guide path (or the pack's own
## @ace_help URL), ready for EventSheets.open_online_doc.
##
## Validation is as strict as it can be WITHOUT a live editor: a section must be registered, a
## pack directory must exist on disk. A verb's existence needs the running registry, so an
## "ace:" id is checked for shape here and resolved against the registry by the caller.
static func resolve(doc_id: String) -> Dictionary:
	var route: Dictionary = {
		"valid": false, "scheme": "", "provider_id": "", "ace_id": "", "section": "", "pack": "", "target": "",
	}
	var id: String = doc_id.strip_edges()
	if id.is_empty():
		route["valid"] = true
		route["scheme"] = "index"
		return route
	if id.begins_with(SCHEME_ACE):
		var rest: String = id.substr(SCHEME_ACE.length())
		var separator: int = rest.find("/")
		if separator <= 0 or separator >= rest.length() - 1:
			return route
		route["scheme"] = "ace"
		route["provider_id"] = rest.substr(0, separator)
		# NOT get_slice("/", 1): a reflected ace id carries its own colon ("method:advance_objective")
		# and could carry a slash, so everything after the FIRST separator is the id.
		route["ace_id"] = rest.substr(separator + 1)
		route["valid"] = true
		return route
	if id.begins_with(SCHEME_SECTION):
		var section: String = id.substr(SCHEME_SECTION.length()).strip_edges()
		route["scheme"] = "section"
		route["section"] = section
		route["valid"] = not section.is_empty() and EventSheetSectionInfo.has(section)
		return route
	if id.begins_with(SCHEME_ADDON):
		var pack: String = id.substr(SCHEME_ADDON.length()).strip_edges()
		route["scheme"] = "addon"
		route["pack"] = pack
		if pack.is_empty() or not DirAccess.dir_exists_absolute(PACK_ROOT.path_join(pack)):
			return route
		route["target"] = EventSheets.addon_guide_for_pack(pack)
		route["valid"] = not str(route["target"]).is_empty()
		return route
	return route


## The doc id for a verb: "ace:<provider_id>/<ace_id>". "" for a null definition.
static func doc_id_for_definition(definition: ACEDefinition) -> String:
	if definition == null or definition.id.strip_edges().is_empty():
		return ""
	return "%s%s/%s" % [SCHEME_ACE, definition.provider_id, definition.id]


## The doc id for the verb a row (and optionally the exact clicked span) is about.
##
## `metadata` is the viewport's span metadata for the click - {kind, ace_index} - so a
## right-click on the third condition explains THAT condition rather than the row's trigger.
## Without metadata (the F1 path, where there is a selection but no click) the row answers with
## its most identifying verb: its trigger, else its first condition, else its first action.
## "" when the row names no verb at all (a comment, a blank group, raw code).
static func doc_id_for_row(resource: Resource, metadata: Dictionary = {}) -> String:
	if resource == null:
		return ""
	if resource is ACEAction or resource is ACECondition:
		return "%s%s/%s" % [SCHEME_ACE, str(resource.get("provider_id")), str(resource.get("ace_id"))]
	var event_row: EventRow = resource as EventRow
	if event_row == null:
		return ""
	var kind: String = str(metadata.get("kind", ""))
	var ace_index: int = int(metadata.get("ace_index", -1))
	if kind == "condition" and ace_index >= 0 and ace_index < event_row.conditions.size():
		return doc_id_for_row(event_row.conditions[ace_index] as Resource)
	if kind == "action" and ace_index >= 0 and ace_index < event_row.actions.size():
		return doc_id_for_row(event_row.actions[ace_index] as Resource)
	if kind == "trigger" and event_row.trigger != null:
		return doc_id_for_row(event_row.trigger as Resource)
	if not event_row.trigger_id.strip_edges().is_empty():
		return "%s%s/%s" % [SCHEME_ACE, event_row.trigger_provider_id, event_row.trigger_id]
	if event_row.trigger != null:
		return doc_id_for_row(event_row.trigger as Resource)
	if not event_row.conditions.is_empty():
		return doc_id_for_row(event_row.conditions[0] as Resource)
	if not event_row.actions.is_empty():
		return doc_id_for_row(event_row.actions[0] as Resource)
	return ""


## True when a row has something to explain - the filter behind the "What does this do?" row-menu
## item, so the entry never appears on a comment or an empty group.
static func can_explain(resource: Resource) -> bool:
	return not doc_id_for_row(resource).is_empty()


# ── The page ──────────────────────────────────────────────────────────────────────────────────


## Everything shown for one verb, in reading order. Pure: the same definition always produces the
## same blocks, so a test pins the strings instead of a screenshot.
static func blocks_for_definition(definition: ACEDefinition) -> Array[Dictionary]:
	var blocks: Array[Dictionary] = []
	if definition == null:
		return blocks
	blocks.append({
		"kind": "title",
		"text": EventSheetL10n.translate(definition.display_name),
		"subtitle": "%s  ·  %s" % [type_label(definition.ace_type), category_of(definition)],
	})
	var deprecation: String = deprecation_note(definition)
	if not deprecation.is_empty():
		blocks.append({"kind": "note", "text": deprecation})
	var description: String = str(definition.description).strip_edges()
	if description.is_empty():
		description = str(definition.metadata.get("display_template", definition.display_name))
	blocks.append({"kind": "prose", "text": EventSheetL10n.translate(description)})
	var template: String = ships_as(definition)
	if not template.is_empty():
		blocks.append({"kind": "ships_as", "code": template})
	var params_list: Array[Dictionary] = parameter_items(definition)
	if not params_list.is_empty():
		blocks.append({"kind": "params", "items": params_list})
	# The figure is the one thing neither the row hover nor a static page can carry: the verb
	# drawn by the real renderer, exactly as dropping it would look, with an Insert button.
	blocks.append({"kind": "figure", "definition": definition})
	var section_blurb: String = EventSheetSectionInfo.description_for(category_of(definition))
	if section_blurb.is_empty():
		section_blurb = str(definition.metadata.get("provider_description", "")).strip_edges()
	if not section_blurb.is_empty():
		blocks.append({
			"kind": "about",
			"title": "About %s" % category_of(definition),
			"text": EventSheetL10n.translate(section_blurb),
		})
	var guide: String = EventSheets.addon_guide_for_provider(definition.provider_id)
	if not guide.is_empty():
		blocks.append({"kind": "link", "label": guide_label(definition.provider_id), "target": guide})
	return blocks


## A whole category: its blurb, and nothing invented around it. The picker shows this when a
## header is selected; a reader who arrived from a row gets it as the "what is this group for"
## card under the verb.
static func blocks_for_section(section_name: String) -> Array[Dictionary]:
	var blocks: Array[Dictionary] = []
	var name: String = section_name.strip_edges()
	if name.is_empty():
		return blocks
	blocks.append({"kind": "title", "text": name, "subtitle": "Category"})
	var blurb: String = EventSheetSectionInfo.description_for(name)
	if not blurb.is_empty():
		blocks.append({"kind": "prose", "text": EventSheetL10n.translate(blurb)})
	return blocks


# ── The pieces, each usable on its own ────────────────────────────────────────────────────────


## The GDScript line a verb compiles to: its own template, or - for a reflected method with no
## authored template - the same owned-instance call the dock would bake at apply time, so
## "ships as" is never blank for a working verb.
static func ships_as(definition: ACEDefinition) -> String:
	if definition == null:
		return ""
	var template: String = str(definition.metadata.get("codegen_template", "")).strip_edges()
	if template.is_empty():
		template = definition.instance_backed_template()
	return template


## The deprecation steer for a verb ("[Deprecated] … Use X instead."), or "". Read from the
## definition's own metadata first, then from the base descriptor registry, so a deprecated verb
## still sitting in somebody's sheet explains where to go next.
static func deprecation_note(definition: ACEDefinition) -> String:
	if definition == null:
		return ""
	var note: String = str(definition.metadata.get("deprecation_note", "")).strip_edges()
	if not note.is_empty():
		return note
	var descriptor: ACEDescriptor = ACERegistry.find_descriptor(definition.provider_id, definition.id)
	if descriptor != null and descriptor.is_deprecated:
		return descriptor.deprecation_note()
	return ""


## One entry per parameter: the field's own label, and a detail line carrying its type, its
## default and its blurb. Handles both parameter shapes in the registry - authored ACEParam
## resources and the plain Dictionaries reflection produces - because a page that only reads one
## of them silently shows nothing for half the vocabulary.
static func parameter_items(definition: ACEDefinition) -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	if definition == null:
		return items
	for parameter: Variant in definition.parameters:
		var name: String = ""
		var type_name: String = ""
		var default_value: String = ""
		var blurb: String = ""
		if parameter is ACEParam:
			var param: ACEParam = parameter as ACEParam
			name = param.get_param_name()
			type_name = param.type_name
			default_value = param.gdscript_default.strip_edges()
			blurb = param.get_param_description().strip_edges()
		elif parameter is Dictionary:
			var entry: Dictionary = parameter as Dictionary
			name = str(entry.get("display_name", entry.get("id", "")))
			type_name = type_string(int(entry.get("type", TYPE_NIL)))
			default_value = str(entry.get("default_value", "")).strip_edges()
			blurb = str(entry.get("description", "")).strip_edges()
		if name.strip_edges().is_empty():
			continue
		var detail: String = type_name
		if not default_value.is_empty():
			detail += "  =  %s" % default_value
		if not blurb.is_empty():
			detail += "\n%s" % EventSheetL10n.translate(blurb)
		items.append({"name": EventSheetL10n.translate(name), "detail": detail.strip_edges()})
	return items


## The read-more button's text for a provider ("Open the Quest guide"), or "" when the provider
## is not a pack. Reads "the <Guide> guide" rather than a possessive because a pack whose guide
## is plural ("Priced Tables") makes a possessive read wrong, and the label is derived, never
## hand-written per pack.
static func guide_label(provider_id: String) -> String:
	var pack_dir: String = EventSheets.addon_pack_directory(provider_id)
	if pack_dir.is_empty():
		return ""
	var guide_name: String = EventSheets.addon_guide_name(pack_dir)
	if guide_name.is_empty():
		return ""
	return "Open the %s guide" % guide_name.replace("-", " ")


## The picker category a verb files under, with the same "General" fallback the picker uses so
## the two surfaces never disagree about which group a verb belongs to.
static func category_of(definition: ACEDefinition) -> String:
	if definition == null:
		return "General"
	var category: String = definition.category.strip_edges()
	return category if not category.is_empty() else "General"


## Trigger / Condition / Expression / Action, for the line under the title.
static func type_label(ace_type: int) -> String:
	match ace_type:
		ACEDefinition.ACEType.TRIGGER:
			return "Trigger"
		ACEDefinition.ACEType.CONDITION:
			return "Condition"
		ACEDefinition.ACEType.EXPRESSION:
			return "Expression"
		_:
			return "Action"
