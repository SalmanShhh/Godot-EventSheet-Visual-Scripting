# Godot EventSheets - Inspector attribute drawers (Tier 3)
#
# One EditorInspectorPlugin recognizes the `eventsheet:<drawer>` marker that the compiler bakes into
# @export_custom hint strings, and swaps in a richer editor control. THE DEGRADATION CONTRACT: generated
# scripts stay plain GDScript - without this plugin (or in exported games) the property renders as a normal
# field, so the parity covenant is untouched. The actual widgets live in drawer_widgets.gd (reused by the
# Variable dialog's live preview); here we only map a marker+type to the right EditorProperty and forward edits.
#
# Drawers + marker forms:
#   progress_bar   eventsheet:progress_bar:<min>:<max>   int / float (a look that is a file: addons/eventsheet/looks/progress_bar.gd)
#   min_max        eventsheet:min_max:<min>:<max>        Vector2 (x = low end, y = high end; a look file)
#   table          eventsheet:table:<n>=<t>,<n>=<t>      Array (of Dictionary rows; t: String/int/float/bool)
#   table_row      eventsheet:table_row:<array>:<column> int (the number of a row of the table property
#                  <array>, picked from a dropdown of its rows by their <column> cell; a look file)
#   cards          eventsheet:cards:kind=<k>,schema=<n>,stripes=<k>
#                  Array (of Dictionary cards, each of a KIND, edited as a reorderable list of cards -
#                  the schema registered under <n> says what each kind is called and which fields it has)
#   toggle_row     eventsheet:toggle_row:<a>,<b>,<c>     String / int (choices as one row of toggle buttons;
#                  optional tails, in this order: ":segmented" for equal-width word buttons, ":icons=<source>"
#                  for a picture per option - a path pattern holding %s, or a registered provider's name)
#   unit           eventsheet:unit:kinds=<a>|<b>,store=<a> float (a spin box with a unit dropdown at its edge)
#   corners        eventsheet:corners                    Vector4 (one number, or four boxes clockwise from top-left; a look file)
#   vector_dial    eventsheet:vector_dial:<max>          Vector2 (a look file)
#   swatch_row     eventsheet:swatch_row                 Color (a look file)
#   texture_preview eventsheet:texture_preview           Texture2D (a look file)
#   curve_editor   eventsheet:curve_editor               Curve (a look file)
#
# A marker word that none of these handles is looked up in the catalogue of look FILES, so a project adds a
# look by adding one script to `res://eventsheet_addons/looks/`; nothing is registered.
#
# Decor that belongs to the OBJECT rather than to one property is parsed beside this file:
# `# @inspector_preview` asks for the preview card at the top, and
# `# @inspector_handle <property> <kind> [from <property>]` declares a viewport handle, and
# `# @inspector_tabs` draws every @export_group as a tab.
#
# Decor that SHAPES the field it sits above, read here:
#   # @inspector_choices <function>   a String as a dropdown of the words that function returns
#                                     (only for a @tool script that has it; else the plain field)
#   # @inspector_side_by_side         two numbers, this one and the next declared, on one line
@tool
class_name EventSheetAttributeDrawers
extends EditorInspectorPlugin

# The two decor lines that belong to the OBJECT rather than to one property - the preview card and
# the viewport handles - are parsed beside this file and loaded BY PATH here, so naming them never
# widens what an editor boot compiles (this plugin is constructed at boot; add_inspector_plugin
# takes an instance).
const OBJECT_DECOR_PATH: String = "res://addons/eventsheet/editor/inspector/object_decor.gd"
const PREVIEW_PANEL_PATH: String = "res://addons/eventsheet/editor/inspector/preview_panel.gd"
## The card-list drawer and its schema side, loaded BY PATH for the same reason: a property that
## never asks for cards must not pay for them at every editor start.
const CARD_LIST_DRAWER_PATH: String = "res://addons/eventsheet/editor/inspector/card_list_drawer.gd"
const CARD_SCHEMAS_PATH: String = "res://addons/eventsheet/editor/inspector/card_schemas.gd"
## The catalogue of looks that are files (the progress bar, and any look the project adds), loaded BY
## PATH for the same reason: it is read the first time a marker names a look it does not know by heart.
const LOOK_CATALOGUE_PATH: String = "res://addons/eventsheet/editor/inspector/look_catalogue.gd"
## The widgets themselves, loaded BY PATH for the same reason: most objects an Inspector shows carry
## no drawer and no decor, and the widgets (with their translations) are the larger half of this file's
## weight at boot. Reached through `widgets()`; the property wrappers below hold them as plain Controls.
const DRAWER_WIDGETS_PATH: String = "res://addons/eventsheet/editor/drawer_widgets.gd"
## The door the plugin hands in: opens a .tres in the sheet editor's table view (Callable(path)).
## Unset, the table look draws no "Open as a table" link.
var open_table: Callable = Callable()
## Whether the tab strip has been drawn for the object being read now.
var _tabs_drawn: bool = false


## The drawer widgets module, compiled the first time a drawer or a decor line is drawn.
static func widgets() -> GDScript:
	return load(DRAWER_WIDGETS_PATH)


func _can_handle(_object: Object) -> bool:
	return true  # cheap: the per-property marker check below does the real filtering


## Object-level decor, above every property: a script carrying `# @inspector_preview` gets the shared
## preview card at the top of its Inspector, showing the object as it is and re-drawing as it changes.
## Anything else is left alone, so an object that asked for nothing renders exactly as Godot draws it.
func _parse_begin(object: Object) -> void:
	var object_decor: GDScript = load(OBJECT_DECOR_PATH)
	if object_decor.wants_preview(object):
		add_custom_control(load(PREVIEW_PANEL_PATH).new(object))
	# `# @inspector_tabs` is drawn under the script's own heading, in _parse_category.
	_tabs_drawn = false


## The tab strip of `# @inspector_tabs`: one tab per @export_group. It sits directly under the heading
## of the object's own script (Godot names that heading by the script's class name, or by its file name
## when it has none), so it reads as part of that script's fields. Picking a tab rebuilds the
## Inspector, and the fields of the other groups are left out of it below.
func _parse_category(object: Object, category: String) -> void:
	if _tabs_drawn or object == null or object.get_script() == null:
		return
	var script: Script = object.get_script() as Script
	if script == null or (category != script.get_global_name() and category != script.resource_path.get_file()):
		return
	_draw_tabs(object)


## An object whose script heading could not be matched still gets its tabs, at the end, rather than none.
func _parse_end(object: Object) -> void:
	if not _tabs_drawn and object != null:
		_draw_tabs(object)


func _draw_tabs(object: Object) -> void:
	var object_decor: GDScript = load(OBJECT_DECOR_PATH)
	if not object_decor.wants_tabs(object):
		return
	var groups: PackedStringArray = object_decor.tab_groups(object)
	if groups.is_empty():
		return
	_tabs_drawn = true
	add_custom_control(widgets().GroupTabs.new(object, groups, object_decor.chosen_tab(object)))


func _parse_property(_object: Object, type: Variant.Type, name: String, _hint_type: PropertyHint, hint_string: String, _usage_flags: int, _wide: bool) -> bool:
	# A field in a group whose tab is not the one picked is consumed with nothing drawn.
	if _object != null and _object.get_script() != null and load(OBJECT_DECOR_PATH).hidden_by_tabs(_object, name):
		return true
	# The words about a field (a required note, a failed check, an info line, a button) sit UNDER the
	# field, in the value column, so they read as belonging to it. They are collected while the decor
	# is read and added after whatever draws the field itself - Godot's plain one or one of ours.
	var under_field: Array[Control] = []
	var handled: bool = _parse_field(_object, type, name, hint_string, under_field)
	for note: Control in under_field:
		add_property_editor(name, widgets().NoteRow.new(note), true)
	return handled


func _parse_field(_object: Object, type: Variant.Type, name: String, hint_string: String, under_field: Array[Control]) -> bool:
	var decor: Array = decor_for(_object, name)
	# A pair that shares one line also holds its link button and its sizes inside that one row.
	var pair: Dictionary = _pair_shape(_object, name, decor)
	# Decor first: a `# @inspector_header` comment above the var renders as a section label ABOVE the
	# property; the required / validate / info / action lines are collected to go under it.
	for entry: Variant in decor:
		var decor_entry: Dictionary = entry as Dictionary
		match str(decor_entry.get("kind", "")):
			"header":
				add_custom_control(widgets().build_header_label(str(decor_entry.get("text", "")), str(decor_entry.get("color", ""))))
			"required":
				under_field.append(widgets().RequiredBadge.new(_object, name))
			"validate":
				under_field.append(widgets().ValidateBadge.new(_object, str(decor_entry.get("function", ""))))
			"action":
				under_field.append(widgets().ActionButton.new(_object, str(decor_entry.get("function", "")), str(decor_entry.get("label", ""))))
			"link":
				if not bool(pair.get("linked", false)):
					add_custom_control(widgets().LinkToggle.new(_object, str(decor_entry.get("first", "")), str(decor_entry.get("second", ""))))
			"group_show_if":
				# Nothing to draw: hiding the group is the ordinary _validate_property the compiler
				# emits once per member, exactly as the per-field Show If compiles. The entry is here
				# so the Designer (and anything else reading the map) can say WHY a group hides.
				pass
			"tabs", "choices", "side_by_side", "side_by_side_second", "texture_size":
				# Drawn as the field itself (below) or at the top of the Inspector (_parse_begin).
				pass
			_:
				under_field.append(widgets().build_info_panel(str(decor_entry.get("text", ""))))
	for entry: Variant in decor:
		var shape: Dictionary = entry as Dictionary
		match str(shape.get("kind", "")):
			"choices":
				# Filled by the script's own function, so it only runs for a @tool script that has
				# it - otherwise Godot's plain text field, exactly as without the plugin.
				if (type == TYPE_STRING or type == TYPE_STRING_NAME) and widgets().ChoicesField.can_ask(_object, str(shape.get("function", ""))):
					add_property_editor(name, widgets().ChoicesProperty.new(str(shape.get("function", ""))))
					return true
			"side_by_side":
				var second: String = str(shape.get("second", ""))
				if side_by_side_fits(_object, name, second):
					add_property_editor_for_multiple_properties("", PackedStringArray([name, second]), widgets().SideBySideProperty.new(name, second,
						bool(pair.get("linked", false)), bool(pair.get("texture", false)), pair.get("sizes", PackedInt32Array())))
					return true
			"side_by_side_second":
				if side_by_side_fits(_object, str(shape.get("first", "")), name):
					return true
	var drawer: Dictionary = parse_drawer_hint(hint_string)
	var kind: String = str(drawer.get("drawer", ""))
	match kind:
		"cards":
			# A list of Dictionaries, each of a kind: the reorderable card list. Both the untyped list
			# and Array[Dictionary] reach here as TYPE_ARRAY, exactly as the table drawer does.
			if type != TYPE_ARRAY:
				return false
			var cards_args: Array = drawer.get("args", [])
			var cards_spec: Dictionary = load(CARD_SCHEMAS_PATH).call("parse_cards_spec", str(cards_args[0]) if cards_args.size() > 0 else "")
			add_property_editor(name, CardListProperty.new(cards_spec))
			return true
	# Every other word is a look that is a file: the progress bar and any look the project added. The
	# catalogue is loaded here, and only here, so an object with no marker pays nothing for it.
	if not kind.is_empty():
		return _parse_look(_object, type, name, kind, drawer.get("args", []))
	return false


## A look from a file draws the property when the file is installed and works on this type; any other
## marker word leaves the plain field, exactly as without the plugin.
func _parse_look(object: Object, type: int, name: String, word: String, args: Array) -> bool:
	var catalogue: Variant = load(LOOK_CATALOGUE_PATH)
	var look: Dictionary = catalogue.entry(word)
	if look.is_empty() or not catalogue.accepts(look, type, object, name):
		return false
	var control: Variant = catalogue.build(look, args)
	if control == null:
		return false
	# The door the plugin handed in, for a look that offers to open a table's file (the table look).
	if "open_table" in control:
		control.set("open_table", open_table)
	# A look may hand back rows above its field (a labelled one, like Godot's own rows) and rows under it.
	for row: Variant in control.call("_rows_above_field"):
		var row_label: String = str((row as Control).get_meta("row_label", ""))
		add_property_editor(name, widgets().NoteRow.new(row as Control, row_label), false, row_label)
	add_property_editor(name, control)
	for row: Variant in control.call("_rows_under_field"):
		add_property_editor(name, widgets().NoteRow.new(row as Control), true)
	return true


## "eventsheet:progress_bar:0:200" -> {drawer:"progress_bar", args:["0","200"], min:0.0, max:200.0}.
## Anything not starting with the marker prefix -> {}. Static + UI-free so the headless suite pins the contract.
static func parse_drawer_hint(hint_string: String) -> Dictionary:
	if not hint_string.begins_with("eventsheet:"):
		return {}
	var parts: PackedStringArray = hint_string.split(":")
	var parsed: Dictionary = {"drawer": parts[1] if parts.size() > 1 else "", "args": Array(parts.slice(2))}
	if parts.size() > 2:
		parsed["min"] = parts[2].to_float()
	if parts.size() > 3:
		parsed["max"] = parts[3].to_float()
	return parsed


## "kinds=px|world|screen,store=world" -> {units: PackedStringArray, store: String}. The store falls
## back to the first listed unit, so a marker missing it (or naming a unit it does not list) still
## has a definite stored unit. Static + UI-free so the headless suite pins the contract.
static func parse_unit_spec(spec: String) -> Dictionary:
	var units: PackedStringArray = PackedStringArray()
	var store: String = ""
	for token: String in spec.split(","):
		var trimmed: String = token.strip_edges()
		if trimmed.begins_with("kinds="):
			for unit: String in trimmed.substr(6).split("|"):
				if not unit.strip_edges().is_empty():
					units.append(unit.strip_edges())
		elif trimmed.begins_with("store="):
			store = trimmed.substr(6).strip_edges()
	# A spec that is just a FAMILY'S NAME ("time", "angle") means that family, in its own order, with
	# its base unit as the stored one - the short spelling a card schema's field uses. Only read when
	# no `kinds=` was given, so a marker that names its units keeps naming them.
	if units.is_empty():
		var family: String = spec.strip_edges()
		if widgets().UNIT_FAMILIES.has(family):
			for unit: Variant in (widgets().UNIT_FAMILIES[family] as Array):
				units.append(str(unit))
	if units.is_empty():
		return {"units": units, "store": ""}
	if store.is_empty() or not units.has(store):
		store = units[0]
	return {"units": units, "store": store}


## The toggle-row marker's arguments -> {options, segmented, icons}. The option list is args[0];
## after it come the optional tails in a fixed order - "segmented", then "icons=<source>". The icon
## source is rejoined with ":" because a res:// path carries colons of its own.
## Static + UI-free so the headless suite pins the contract.
static func parse_toggle_spec(args: Array) -> Dictionary:
	var spec: Dictionary = {"options": PackedStringArray(), "segmented": false, "icons": ""}
	if args.is_empty():
		return spec
	var options: PackedStringArray = PackedStringArray()
	for option: String in str(args[0]).split(","):
		if not option.strip_edges().is_empty():
			options.append(option.strip_edges())
	spec["options"] = options
	for index: int in range(1, args.size()):
		var tail: String = str(args[index])
		if tail == "segmented":
			spec["segmented"] = true
		elif tail.begins_with("icons="):
			var joined: PackedStringArray = PackedStringArray()
			for rest: int in range(index, args.size()):
				joined.append(str(args[rest]))
			spec["icons"] = ":".join(joined).substr(6)
			break
	return spec


# Decor maps parsed per script, cached by source length (cosmetic-only, so a same-length edit missing
# the cache costs nothing worse than one stale render until the next real edit).
static var _decor_cache: Dictionary = {}


## Forgets every parsed decor map, so the next draw reads each script's source again. A same-length
## edit (a colour, `0:200` to `0:300`) would otherwise draw from the old map until the length changed.
static func forget_decor() -> void:
	_decor_cache.clear()


## The decor entries for one property, parsed from the object's script source. Decor comments are plain
## `#` lines (never `##` - those merge into the hover tooltip), so they reach the editor only through
## the source text, exactly like the parity covenant wants: inert in the exported game.
static func decor_for(object: Object, property: String) -> Array:
	if object == null:
		return []
	var script: GDScript = object.get_script() as GDScript
	if script == null:
		return []
	var source: String = script.source_code
	if source.find("# @inspector_") == -1:
		return []
	var key: int = script.get_instance_id()
	var cached: Variant = _decor_cache.get(key)
	if cached is Dictionary and int((cached as Dictionary).get("len", -1)) == source.length():
		return ((cached as Dictionary).get("map") as Dictionary).get(property, [])
	var map: Dictionary = build_decor_map(source)
	_decor_cache[key] = {"len": source.length(), "map": map}
	return map.get(property, [])


## property name -> Array of decor dicts ({kind:"header", text, color} / {kind:"info", text}), from raw
## script source. Decor binds to the next `var` declaration; tooltips (`##`) and `@export_*` annotation
## lines may sit between them (the canonical emission order); anything else orphans the decor.
static func build_decor_map(source: String) -> Dictionary:
	var map: Dictionary = {}
	var pending: Array = []
	# The show-if that scopes a whole @export_group: it rides above the group line and belongs to
	# every member below it, until the next group (or category) line replaces it.
	var group_scope: Dictionary = {}
	# A `# @inspector_side_by_side` entry waiting for the field declared after its own, and its name.
	var side_first: Variant = null
	var side_first_name: String = ""
	for raw_line: String in source.split("\n"):
		var line: String = raw_line.strip_edges()
		if line.begins_with("# @inspector_header "):
			pending.append(_parse_header_decor(line.substr(20).strip_edges()))
		elif line.begins_with("# @inspector_info "):
			pending.append({"kind": "info", "text": line.substr(18).strip_edges()})
		elif line == "# @inspector_required":
			pending.append({"kind": "required"})
		elif line.begins_with("# @inspector_validate "):
			pending.append({"kind": "validate", "function": line.substr(22).strip_edges()})
		elif line.begins_with("# @inspector_action "):
			var action_spec: String = line.substr(20).strip_edges()
			var first_space: int = action_spec.find(" ")
			pending.append({
				"kind": "action",
				"function": action_spec.substr(0, first_space) if first_space > 0 else action_spec,
				"label": action_spec.substr(first_space + 1).strip_edges() if first_space > 0 else ""
			})
		elif line.begins_with("# @inspector_link "):
			var link_names: PackedStringArray = line.substr(18).strip_edges().split(" ", false)
			if link_names.size() == 2:
				pending.append({"kind": "link", "first": link_names[0], "second": link_names[1]})
		elif line == "# @inspector_texture_size" or line.begins_with("# @inspector_texture_size "):
			var size_list: PackedInt32Array = PackedInt32Array()
			for size_word: String in line.substr(25).strip_edges().split(" ", false):
				if size_word.is_valid_int() and size_word.to_int() > 0:
					size_list.append(size_word.to_int())
			pending.append({"kind": "texture_size", "sizes": size_list})
		elif line == "# @inspector_tabs":
			pending.append({"kind": "tabs"})
		elif line.begins_with("# @inspector_choices "):
			var choices_function: String = line.substr(21).strip_edges()
			if choices_function.is_valid_identifier():
				pending.append({"kind": "choices", "function": choices_function})
		elif line == "# @inspector_side_by_side":
			pending.append({"kind": "side_by_side", "second": ""})
		elif line.begins_with("# @inspector_show_if "):
			# Only meaningful directly above an @export_group line (the group-scoped form); above a
			# variable the show-if is the per-field attribute, which compiles rather than decorates.
			pending.append({"kind": "_show_if_pending", "predicate": line.substr(21).strip_edges()})
		elif line.begins_with("@export_group(") or line.begins_with("@export_category("):
			# A group line closes the previous group's scope and opens its own. A subgroup line does
			# NOT: it nests inside the group, so the group's show-if still covers its members. Only
			# the show-if is consumed here - the canonical emission puts a header / info / action
			# ABOVE the group line, and those still belong to the variable underneath it.
			group_scope = {}
			# The first field of the next group sits under another heading, never on the same line.
			side_first = null
			var carried: Array = []
			for waiting: Variant in pending:
				if str((waiting as Dictionary).get("kind", "")) != "_show_if_pending":
					carried.append(waiting)
				elif not str((waiting as Dictionary).get("predicate", "")).is_empty():
					group_scope = {"kind": "group_show_if", "predicate": str((waiting as Dictionary).get("predicate"))}
			pending = carried
		elif line.begins_with("@export_subgroup("):
			# A subgroup keeps its group's show-if, but its heading still parts a side-by-side pair.
			side_first = null
		elif line.begins_with("var ") or (line.begins_with("@") and line.contains(" var ")):
			if not pending.is_empty() or not group_scope.is_empty() or side_first != null:
				var var_name: String = _var_name_from_line(line)
				if not var_name.is_empty():
					var entries: Array = []
					if not group_scope.is_empty():
						entries.append(group_scope)
					# The field after a side-by-side one is the other half of its line.
					if side_first != null:
						side_first["second"] = var_name
						entries.append({"kind": "side_by_side_second", "first": side_first_name})
						side_first = null
					for waiting: Variant in pending:
						if str((waiting as Dictionary).get("kind", "")) != "_show_if_pending":
							entries.append(waiting)
							if str((waiting as Dictionary).get("kind", "")) == "side_by_side":
								side_first = waiting
								side_first_name = var_name
					if not entries.is_empty():
						map[var_name] = entries
				pending = []
		elif line.begins_with("#") or line.begins_with("@"):
			continue
		else:
			pending = []
			# A blank line between two members of a group is ordinary spacing, so the group's scope
			# survives it; a real statement (a function, a signal) means the export block is over.
			if not line.is_empty():
				group_scope = {}
				# A setter's indented body still belongs to the variable above it.
				if not raw_line.begins_with("\t") and not raw_line.begins_with(" "):
					side_first = null
	return map


## "Combat #e06666" -> {kind:"header", text:"Combat", color:"#e06666"}; a trailing token only counts as
## the accent when it is a full #rrggbb - anything else stays part of the title.
static func _parse_header_decor(text: String) -> Dictionary:
	var tokens: PackedStringArray = text.split(" ")
	var last: String = tokens[tokens.size() - 1] if tokens.size() > 1 else ""
	if last.length() == 7 and last.begins_with("#") and last.substr(1).is_valid_hex_number():
		return {"kind": "header", "text": text.substr(0, text.length() - last.length()).strip_edges(), "color": last}
	return {"kind": "header", "text": text, "color": ""}


## The declared name out of "var health: int = 100" or "@export(...) var health := 1".
static func _var_name_from_line(line: String) -> String:
	var after: String = line.substr(line.find("var ") + 4).strip_edges()
	for terminator: String in [":", "=", " "]:
		var at: int = after.find(terminator)
		if at != -1:
			after = after.substr(0, at)
	return after.strip_edges()


## The weight column a table marker names (its trailing `weight=<column>` part), or "" when it names
## none or one the columns do not have as an int or float.
static func table_weight_column(columns: Array, notes: Array) -> String:
	var named: String = str(widgets().sheet_compiler().peel_table_weight(notes)["weight"])
	for column: Variant in columns:
		if column is Dictionary and str((column as Dictionary).get("name", "")) == named and str((column as Dictionary).get("type", "")) in ["int", "float"]:
			return named
	return ""


## "hp=int,name=String" -> [{name:"hp", type:"int"}, {name:"name", type:"String"}]. The table
## marker's column schema; unknown types fall back to String, nameless entries are dropped. `notes`
## are the marker's parts after the columns - each column's own `default` and `about` - folded in
## when they fit. Static + UI-free so the headless suite pins the contract.
static func parse_table_columns(spec: String, notes: Array = []) -> Array:
	var columns: Array = []
	for pair: String in spec.split(","):
		var trimmed: String = pair.strip_edges()
		if trimmed.is_empty():
			continue
		var eq: int = trimmed.find("=")
		var column_name: String = (trimmed.substr(0, eq) if eq > 0 else trimmed).strip_edges()
		var column_type: String = trimmed.substr(eq + 1).strip_edges() if eq > 0 else "String"
		if column_name.is_empty() or column_name.contains("="):
			continue
		# A fixed-choice column - enum(a|b|c) - renders as a dropdown; the options ride the schema.
		# By path, not by class name: this file is constructed at editor boot (add_inspector_plugin
		# takes an instance), and naming the compiler here would compile its whole subtree into every
		# session for one schema helper. The widgets module owns the cached load.
		var enum_options: Array = widgets().sheet_compiler().table_enum_options(column_type)
		if not enum_options.is_empty():
			columns.append({"name": column_name, "type": "enum", "options": enum_options})
			continue
		# "key" rides along with the plain types: it renders as text like a String column, and marks
		# the cells as translation keys for the translator sweep. Flattening it here would make the
		# declaration unreachable from a resource's own @export hint.
		if not column_type in widgets().sheet_compiler().TABLE_CELL_TYPES:
			column_type = "String"
		columns.append({"name": column_name, "type": column_type})
	if not notes.is_empty():
		widgets().sheet_compiler().read_table_column_notes(columns, widgets().sheet_compiler().peel_table_weight(notes)["parts"])
	return columns


## What the decor of a field that opens a side-by-side pair says about the pair: {linked, texture, sizes}.
## `linked` is true when the pair is also linked (the ratio button then sits inside the row), and
## `texture` when it is a texture's width and height, with `sizes` the common sizes to offer.
static func _pair_shape(object: Object, name: String, decor: Array) -> Dictionary:
	var second: String = ""
	var linked: bool = false
	var link_second: String = ""
	var texture: bool = false
	var sizes: PackedInt32Array = PackedInt32Array()
	for entry: Variant in decor:
		var shape: Dictionary = entry as Dictionary
		match str(shape.get("kind", "")):
			"side_by_side":
				second = str(shape.get("second", ""))
			"link":
				linked = str(shape.get("first", "")) == name
				link_second = str(shape.get("second", ""))
			"texture_size":
				texture = true
				sizes = shape.get("sizes", PackedInt32Array())
	if second.is_empty() or not side_by_side_fits(object, name, second):
		return {}
	return {"linked": linked and link_second == second, "texture": texture, "sizes": sizes}


## True when `first` and `second` can share one line: both numbers the Inspector shows. Anything
## else stays two ordinary lines, as it is without the plugin. Static + UI-free so the suite pins it.
static func side_by_side_fits(object: Object, first: String, second: String) -> bool:
	if object == null or first.is_empty() or second.is_empty() or first == second:
		return false
	var shown: int = 0
	for property: Dictionary in object.get_property_list():
		var property_name: String = str(property.get("name", ""))
		if (property_name == first or property_name == second) and int(property.get("usage", 0)) & PROPERTY_USAGE_EDITOR \
				and int(property.get("type", TYPE_NIL)) in [TYPE_INT, TYPE_FLOAT]:
			shown += 1
	return shown == 2


# ── EditorProperty wrappers (each embeds a reusable widget and forwards edits) ──


## A list of Dictionaries as a list of cards: drag to reorder, fold one open for its own fields.
## The widget is loaded BY PATH (see CARD_LIST_DRAWER_PATH) and spoken to through `connect` and
## `call`, so this boot-path file never names it and the two never form a cycle.
class CardListProperty:
	extends EditorProperty
	var _list: Control = null

	func _init(spec: Dictionary) -> void:
		_list = load(EventSheetAttributeDrawers.CARD_LIST_DRAWER_PATH).new(spec)
		_list.connect("value_changed", _on_changed)
		# The list sits in a quiet panel in the value column's width, with no outline.
		var panel: PanelContainer = PanelContainer.new()
		panel.add_theme_stylebox_override("panel", load("res://addons/eventsheet/editor/inspector/look_style.gd").panel_box())
		panel.add_child(_list)
		add_child(panel)
		set_bottom_editor(panel)
		draw_background = false

	func _on_changed(cards: Array) -> void:
		emit_changed(get_edited_property(), cards)
		# A property write does not fire a resource's `changed` signal, so live previews (a prefab's
		# picture, a stamp in the viewport) would not repaint. Fire it, as the table drawer does.
		var edited: Object = get_edited_object()
		if edited is Resource:
			(edited as Resource).emit_changed()

	func _update_property() -> void:
		# Guard by VALUE: the echo of our own commit carries what the list already shows, so skipping
		# it keeps the field being edited alive. Only an outside change (undo, reselecting) rebuilds.
		var value: Variant = get_edited_object().get(get_edited_property())
		var incoming: Array = value if value is Array else []
		if incoming == _list.call("get_value"):
			return
		_list.call("set_value", incoming)
