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
#   "guide:<page id>"                   a shipped guide page ("guide:GUIDE-RECIPES", "guide:Addons/Quest")
#   "module:<module name>"              a vocabulary module's guide ("module:collection")
# An id that parses but names nothing real is INVALID - callers get false and a warning, never a
# blank page, because a silently empty doc surface is how a renamed guide ships unnoticed.
#
# BLOCK KINDS the panel understands. Each is a Dictionary with a "kind" key:
#   title      text, subtitle, badges      the verb or section name, its type + category, and the
#                                          same two facts as metadata badges
#   note       text                        a deprecation steer (loud, above the prose)
#   prose      text                        what it does, in the reader's language
#   teaches    doc_id, anchor, line        the written section that teaches it, and where it sits
#   strip      items:[{heading, body}]     what the Parameters dialog says about each of its fields
#   project_usage definition               where the reader's own project already uses it
#   ships_as   code                        the GDScript line it compiles to
#   params     items:[{name, detail,       each parameter, one string for a form row and the same
#              type, default, description}] facts split into table columns
#   about      title, text                 the category blurb - "what is this whole group for"
#   figure     definition                  a live, insertable illustration (Phase 1's widget)
#   link       label, target               read more: a pack guide path or an absolute URL
@tool
class_name EventSheetDocExplain
extends RefCounted

const SCHEME_ACE := "ace:"
const SCHEME_REFERENCE := "reference:"
const SCHEME_SECTION := "section:"
const SCHEME_ADDON := "addon:"
const SCHEME_GUIDE := "guide:"
const SCHEME_MODULE := "module:"

## Where zero-config packs live. A pack directory that is not here names nothing real, which is
## what makes "addon:<pack>" fail loudly instead of opening a 404 in the reader's browser.
const PACK_ROOT := "res://eventsheet_addons"


## Parses a doc id into what it names. Always returns the same shape, so a caller reads
## `valid` first and then the fields for its scheme:
##   {valid, scheme, provider_id, ace_id, section, pack, target, page_id}
## `target` is the repo-relative guide path (or an absolute @ace_help URL) for the guide schemes,
## ready for EventSheets.open_online_doc. `page_id` is the SHIPPED page the same id resolves to
## when the bundle carries it - which is how "addon:quest" silently became a native page without
## a single caller changing: a host draws page_id when it is there, and falls back to target.
##
## Validation is as strict as it can be WITHOUT a live editor: a section must be registered, a
## pack directory must exist on disk, a guide page must ship. A verb's existence needs the running
## registry, so an "ace:" id is checked for shape here and resolved against the registry by the
## caller.
static func resolve(doc_id: String) -> Dictionary:
	var route: Dictionary = {
		"valid": false, "scheme": "", "provider_id": "", "ace_id": "", "section": "", "pack": "",
		"target": "", "page_id": "", "reference_kind": "", "reference_name": "",
	}
	var id: String = doc_id.strip_edges()
	if id.is_empty():
		route["valid"] = true
		route["scheme"] = "index"
		return route
	if id.begins_with(SCHEME_REFERENCE):
		# A reference page is DERIVED from the vocabulary rather than read from the bundle, so it
		# has no page_id and no online target: there is no repo file to send a reader to, and
		# inventing one would be the dead-shipped-link this scheme exists to avoid.
		var reference: Dictionary = EventSheetDocReference.parse(id)
		route["scheme"] = "reference"
		route["reference_kind"] = str(reference.get("kind", ""))
		route["reference_name"] = str(reference.get("name", ""))
		route["valid"] = EventSheetDocReference.has_page(id)
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
		route["page_id"] = EventSheetDocLibrary.id_for_repo_path(str(route["target"]))
		# A pack that ships its OWN guide.md answers with that page whenever the bundle carries no
		# page for it - which is every third-party pack, since the derived docs/Addons path names a
		# guide only this repo's packs have. Same id, same caller, a native page instead of a 404.
		if not EventSheetDocLibrary.has_page(str(route["page_id"])):
			var local: String = EventSheetDocLibrary.pack_page_id(pack)
			if not local.is_empty():
				route["page_id"] = local
		route["valid"] = not str(route["target"]).is_empty() or not str(route["page_id"]).is_empty()
		return route
	if id.begins_with(SCHEME_GUIDE):
		var page_id: String = id.substr(SCHEME_GUIDE.length()).strip_edges()
		route["scheme"] = "guide"
		route["page_id"] = page_id
		# Asked of the library rather than spelled out here: a DISCOVERED page (a pack's own
		# guide.md, one of the project's own notes) has a page id but no repo path, and inventing
		# one would send "read this online" to a file that never existed.
		route["target"] = EventSheetDocLibrary.repo_path_for_page(page_id)
		route["valid"] = EventSheetDocLibrary.has_page(page_id)
		return route
	if id.begins_with(SCHEME_MODULE):
		var module: String = id.substr(SCHEME_MODULE.length()).strip_edges()
		route["scheme"] = "module"
		if module.is_empty():
			return route
		route["target"] = module_guide_target(module)
		route["page_id"] = EventSheetDocLibrary.id_for_repo_path(str(route["target"]))
		route["valid"] = not str(route["page_id"]).is_empty() or not str(route["target"]).is_empty()
		return route
	return route


## Where a builtin vocabulary module's guide lives, asked of the API rather than derived here.
## The lookup is SOFT on purpose: the module mapping is authored beside the module guides
## themselves, and this reader must keep working whether that mapping has landed yet or not - a
## hard reference would turn "the guides are not written yet" into a parse error.
static func module_guide_target(module_name: String) -> String:
	var api: Script = EventSheets as Script
	var lookup: Callable = Callable(api, "module_guide_target")
	if not lookup.is_valid():
		return ""
	return str(lookup.call(module_name)).strip_edges()


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
		# The same two facts as METADATA, for a host that draws them as badges beside the title
		# rather than as a subtitle line. Exactly two, in this order - what the verb IS, and where
		# it comes from. A third badge would turn metadata into decoration.
		"badges": PackedStringArray([type_label(definition.ace_type), category_of(definition)]),
	})
	var deprecation: String = deprecation_note(definition)
	if not deprecation.is_empty():
		blocks.append({"kind": "note", "text": deprecation})
	var description: String = str(definition.description).strip_edges()
	if description.is_empty():
		description = str(definition.metadata.get("display_template", definition.display_name))
	blocks.append({"kind": "prose", "text": EventSheetL10n.translate(description)})
	# The second and third DEPTHS of the same answer, right under the first: the written section
	# that teaches the verb, and what the Parameters dialog says about each of its fields. Both are
	# joins - against the Manual's baked search index and against the dialog's own strip table - so
	# neither is a second copy of anything, and a verb the guides do not cover simply has no row.
	var section: Dictionary = EventSheetDocTeaches.teaching_section(definition)
	if not section.is_empty():
		blocks.append({
			"kind": "teaches",
			"doc_id": str(section.get("doc_id", "")),
			"anchor": str(section.get("anchor", "")),
			"line": EventSheetDocTeaches.section_line(section),
		})
	var strip_items: Array[Dictionary] = EventSheetDocTeaches.strip_items(definition)
	if not strip_items.is_empty():
		blocks.append({"kind": "strip", "items": strip_items})
	var template: String = ships_as(definition)
	if not template.is_empty():
		blocks.append({"kind": "ships_as", "code": template})
	var params_list: Array[Dictionary] = parameter_items(definition)
	if not params_list.is_empty():
		blocks.append({"kind": "params", "items": params_list})
	# The figure is the one thing neither the row hover nor a static page can carry: the verb
	# drawn by the real renderer, exactly as dropping it would look, with an Insert button.
	blocks.append({"kind": "figure", "definition": definition})
	# Everything below the illustration is about THIS reader's sheet rather than about the verb:
	# where they already use it, what sits beside it, and the four things they can do with it from
	# here. The counting itself is the panel's, because it needs the sheet that is open right now
	# and this assembly is pure over the definition it was handed.
	blocks.append({"kind": "usage", "provider_id": definition.provider_id, "ace_id": definition.id})
	# And the same question asked of the whole project rather than of the sheet on screen: the door
	# swinging back, so the reader's own game answers "what does this look like in practice".
	blocks.append({"kind": "project_usage", "definition": definition})
	# And which PATTERNS this verb belongs to. The list is derived from the claims in front of
	# the reader (the panel does the deriving, for the same reason it does the counting above), so a
	# verb is named by a pattern precisely because a claim on their own sheet says it is.
	blocks.append({"kind": "patterns", "provider_id": definition.provider_id, "ace_id": definition.id})
	var siblings: Array[Dictionary] = see_also_for(definition)
	if not siblings.is_empty():
		blocks.append({"kind": "see_also", "items": siblings})
	blocks.append({"kind": "entry_actions", "definition": definition})
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
		# The read-more affordance carries a DOC ID as well as a path. The id is what makes the
		# button open the pack's guide inside the editor once the bundle ships it, while the same
		# button still opens a browser tab for a pack that hosts its docs elsewhere - the caller
		# never has to know which it got.
		blocks.append({
			"kind": "link",
			"label": guide_label(definition.provider_id),
			"target": guide,
			"doc_id": doc_id_for_pack(EventSheets.addon_pack_directory(definition.provider_id)),
		})
	return blocks


## How many siblings an entry offers. Four is a line of chips; a dozen is a second reference page
## the reader did not ask for.
const MAX_SEE_ALSO := 4


## What sits beside a verb: the rest of its own category, nearest kind first, as {title, doc_id}.
## "See also" is the question a reference entry cannot answer by talking about itself - a reader
## who found Wait For Signal usually wants to know that Wait Until exists.
##
## Empty outside the editor, where there is no registry to ask, which is exactly the case where an
## entry has no neighbours to offer anyway.
static func see_also_for(definition: ACEDefinition) -> Array[Dictionary]:
	var siblings: Array[Dictionary] = []
	if definition == null:
		return siblings
	var category: String = category_of(definition)
	var same_kind: Array[Dictionary] = []
	var other_kind: Array[Dictionary] = []
	for other: ACEDefinition in EventSheets.all_verbs():
		if other == null or other.id == definition.id or category_of(other) != category:
			continue
		var entry: Dictionary = {
			"title": EventSheetL10n.translate(other.display_name),
			"doc_id": doc_id_for_definition(other),
		}
		if other.ace_type == definition.ace_type:
			same_kind.append(entry)
		else:
			other_kind.append(entry)
	same_kind.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a["title"]) < str(b["title"]))
	other_kind.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a["title"]) < str(b["title"]))
	siblings.append_array(same_kind)
	siblings.append_array(other_kind)
	if siblings.size() > MAX_SEE_ALSO:
		siblings.resize(MAX_SEE_ALSO)
	return siblings


## The doc id for a pack directory ("quest" -> "addon:quest"), or "" for no pack.
static func doc_id_for_pack(pack_dir: String) -> String:
	var directory: String = pack_dir.strip_edges()
	return "" if directory.is_empty() else "%s%s" % [SCHEME_ADDON, directory]


## A whole category: its blurb, and nothing invented around it. The picker shows this when a
## header is selected; a reader who arrived from a row gets it as the "what is this group for"
## card under the verb.
static func blocks_for_section(section_name: String) -> Array[Dictionary]:
	var blocks: Array[Dictionary] = []
	var name: String = section_name.strip_edges()
	if name.is_empty():
		return blocks
	blocks.append({
		"kind": "title", "text": name, "subtitle": "Category",
		"badges": PackedStringArray(["Category"]),
	})
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
		var description: String = "" if blurb.is_empty() else EventSheetL10n.translate(blurb)
		var detail: String = type_name
		if not default_value.is_empty():
			detail += "  =  %s" % default_value
		if not description.is_empty():
			detail += "\n%s" % description
		# `detail` is the one-string form (a form row, a tooltip); the four separate fields are the
		# TABLE form - Name | Type | Default | Description - because a host that has to split a
		# prose line back into columns is one authored blurb away from splitting it wrongly.
		items.append({
			"name": EventSheetL10n.translate(name),
			"detail": detail.strip_edges(),
			"type": type_name,
			"default": default_value,
			"description": description,
		})
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
