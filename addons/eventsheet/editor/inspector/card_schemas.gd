# Godot EventSheets - the card-list drawer's schema side (editor-only, UI-free).
#
# A card list is an Array of Dictionaries where one key says WHAT each entry is (its kind) and the
# rest are that kind's own values. The drawer needs three things to draw such an array: which key
# holds the kind, which key colours the stripe, and a SCHEMA saying what each kind is called, what
# it explains, and which fields it has. This file is that schema side, kept apart from the widget so
# the whole contract is pinnable in a headless suite - nothing here builds a Control.
#
# THE SCHEMA SHAPE (frozen once shipped, exactly like an ace_id):
#   {
#     "kinds": [{
#       "kind":     "loop_back",                       the value stored under the kind key
#       "category": "loop",                            groups the Add dropdown, colours the stripe
#       "label":    "Loop Back",                       the card's title
#       "help":     "Moves the head back...",          the unfolded card's info line
#       "fields":   [{"key", "label", "drawer", "default", "show_if", "link"}],
#       "live":     [{"key", "label"}],                greyed read-only values while the game runs
#       "defaults": {"x": 0.0, ...},                   seeded into a NEWLY ADDED card, in this order
#       "badge":    Callable(card) -> String,          the right-hand badge text
#       "actions":  [{"label", "run": Callable(card)}] per-card hooks; NO button is assumed
#     }],
#     "label_key":   "",        an optional card key whose value replaces the kind's label
#     "enabled_key": "",        an optional card key holding the enable box (absent = enabled)
#     "stripes":     {}         category -> "#rrggbb", overriding the derived colour
#   }
#
# TWO RULES THE WHOLE FILE OBEYS, because a card list is somebody's saved .tres:
#   1. Loading never writes. Defaults are seeded when a card is ADDED, never when one is read, so a
#      file saved before a schema grew a field round-trips byte for byte.
#   2. An edit keeps the stored TYPE. A number written as a float stays a float, a colour written as
#      "#rrggbb" stays a String - the drawer changes the value, never the spelling.
@tool
class_name EventSheetCardSchemas
extends RefCounted

## The public API script, reached BY PATH rather than by class name: this file is loaded the first
## time a card drawer is built, and naming the API here would pull its dependency subtree along for
## a single registry lookup.
const EVENTSHEETS_API_PATH: String = "res://addons/eventsheet/api/eventsheets.gd"

## The head of a copied card list. A paste that does not begin with it is not ours and is refused,
## so a designer who copies a sentence and hits Paste All gets nothing rather than an empty list.
const CLIPBOARD_PREFIX: String = "eventsheet:cards\n"

## The stripe colour of a card whose category is blank - the one colour that is not derived, because
## "no category" is not a word to hash.
const UNCATEGORISED_STRIPE: Color = Color(0.55, 0.58, 0.64)

static var _api_script: Script = null


## The public API script, loaded on first use and cached for the session.
static func eventsheets_api() -> Script:
	if _api_script == null:
		_api_script = load(EVENTSHEETS_API_PATH)
	return _api_script


## "kind=kind,schema=feedback_steps,stripes=category" -> {kind_key, schema, stripe_key}. The keys
## fall back to "kind" and "category" so a marker that names only its schema still draws; a marker
## naming no schema resolves to an empty schema, which is a list of unlabelled cards rather than an
## error - the data is still the designer's, and it still round-trips.
static func parse_cards_spec(spec: String) -> Dictionary:
	var parsed: Dictionary = {"kind_key": "kind", "schema": "", "stripe_key": "category"}
	for token: String in spec.split(","):
		var trimmed: String = token.strip_edges()
		if trimmed.begins_with("kind="):
			parsed["kind_key"] = trimmed.substr(5).strip_edges()
		elif trimmed.begins_with("schema="):
			parsed["schema"] = trimmed.substr(7).strip_edges()
		elif trimmed.begins_with("stripes="):
			parsed["stripe_key"] = trimmed.substr(8).strip_edges()
	if str(parsed["kind_key"]).is_empty():
		parsed["kind_key"] = "kind"
	if str(parsed["stripe_key"]).is_empty():
		parsed["stripe_key"] = "category"
	return parsed


## The schema a spec asks for: the Dictionary handed in directly (what the Drawing Prefab does, since
## it owns its own vocabulary), else the one registered under the spec's name, else empty.
static func schema_for(spec: Dictionary) -> Dictionary:
	if spec.get("schema_dict") is Dictionary:
		return spec.get("schema_dict")
	var schema_name: String = str(spec.get("schema", "")).strip_edges()
	if schema_name.is_empty():
		return {}
	return eventsheets_api().card_schema(schema_name)


## The kind entries of a schema, in declared order.
static func kinds_of(schema: Dictionary) -> Array:
	return schema.get("kinds") if schema.get("kinds") is Array else []


## The entry describing one kind, or empty when the schema does not know it. An unknown kind is not
## an error: its card still draws with its stored values, so a project opened without the pack that
## defines the kind edits (and saves) the same bytes.
static func kind_entry(schema: Dictionary, kind: String) -> Dictionary:
	for entry: Variant in kinds_of(schema):
		if entry is Dictionary and str((entry as Dictionary).get("kind", "")) == kind:
			return entry
	return {}


## The Add dropdown's contents: [{category, kinds: [entry, ...]}], categories in first-seen order and
## the kinds within a category in declared order - so a pack decides how its own list reads.
static func kinds_by_category(schema: Dictionary) -> Array:
	var groups: Array = []
	var index_of: Dictionary = {}
	for entry: Variant in kinds_of(schema):
		if not (entry is Dictionary):
			continue
		var category: String = str((entry as Dictionary).get("category", ""))
		if not index_of.has(category):
			index_of[category] = groups.size()
			groups.append({"category": category, "kinds": []})
		(groups[int(index_of[category])]["kinds"] as Array).append(entry)
	return groups


## The stripe colour for a category. DERIVED from the word, not from a table of pack names: the
## category's own letters pick a hue, so a pack that invents a category gets a stable colour of its
## own with nothing to register and nothing here to maintain. A schema may still name an exact
## colour per category in its `stripes` map when it wants one.
static func stripe_color(schema: Dictionary, category: String) -> Color:
	var overrides: Dictionary = schema.get("stripes") if schema.get("stripes") is Dictionary else {}
	if overrides.has(category):
		return Color.from_string(str(overrides[category]), UNCATEGORISED_STRIPE)
	var word: String = category.strip_edges()
	if word.is_empty():
		return UNCATEGORISED_STRIPE
	# A card that carries its own colour says so in the one spelling a plain-data list can hold: the
	# "#rrggbb" text. There is nothing to hash then - the card already named the answer.
	if word.begins_with("#") and Color.html_is_valid(word):
		return Color.from_string(word, UNCATEGORISED_STRIPE)
	return Color.from_hsv(_hue_of(word), 0.5, 0.85)


## A word's hue, in 0..1. A plain rolling hash over the bytes, taken modulo 360 whole degrees so the
## answer is identical on every platform and pinnable by value.
static func _hue_of(word: String) -> float:
	var rolling: int = 0
	for byte: int in word.to_utf8_buffer():
		rolling = (rolling * 31 + byte) % 360
	return float(rolling) / 360.0


## The category a card shows under: its own value at the stripe key when it has one (which is how a
## card overrides its colour), else the kind entry's category.
static func card_category(spec: Dictionary, entry: Dictionary, card: Dictionary) -> String:
	var stripe_key: String = str(spec.get("stripe_key", "category"))
	if card.has(stripe_key) and not str(card[stripe_key]).strip_edges().is_empty():
		return str(card[stripe_key])
	return str(entry.get("category", ""))


## The card's title: its own value at the schema's label key when the schema declares one and the
## card fills it (a designer renaming a card in a long list), else the kind's label, else the kind
## itself in words.
static func card_label(schema: Dictionary, spec: Dictionary, entry: Dictionary, card: Dictionary) -> String:
	var label_key: String = str(schema.get("label_key", ""))
	if not label_key.is_empty() and not str(card.get(label_key, "")).strip_edges().is_empty():
		return str(card[label_key])
	var declared: String = str(entry.get("label", ""))
	if not declared.is_empty():
		return declared
	return str(card.get(str(spec.get("kind_key", "kind")), "")).capitalize()


## The badge text on the right of a card's header. The schema computes it (a duration, a count, a
## warning) and an entry without a badge callable simply has none - the drawer never invents one.
static func card_badge(entry: Dictionary, card: Dictionary) -> String:
	var badge: Variant = entry.get("badge")
	if not (badge is Callable) or not (badge as Callable).is_valid():
		return ""
	var answer: Variant = (badge as Callable).call(card)
	return str(answer) if answer != null else ""


## The card key holding the enable box, or "" when the schema declares none. A schema whose runtime
## cannot skip a card declares nothing, and the drawer draws no box - a checkbox that changed a file
## and nothing else would be a lie.
static func enabled_key(schema: Dictionary) -> String:
	return str(schema.get("enabled_key", ""))


## Whether a card is on. An ABSENT key reads as on, so a list saved before the key existed is not
## silently switched off.
static func card_enabled(schema: Dictionary, card: Dictionary) -> bool:
	var key: String = enabled_key(schema)
	if key.is_empty() or not card.has(key):
		return true
	return bool(card[key])


## A copy of the card, switched on or off. Switching ON ERASES the key rather than writing `true`,
## because absent already means on: a card ticked off and on again leaves the file exactly as it was.
static func set_card_enabled(schema: Dictionary, card: Dictionary, enabled: bool) -> Dictionary:
	var updated: Dictionary = card.duplicate()
	var key: String = enabled_key(schema)
	if key.is_empty():
		return updated
	if enabled:
		updated.erase(key)
	else:
		updated[key] = false
	return updated


## The fields of a kind, in display order.
static func fields_of(entry: Dictionary) -> Array:
	return entry.get("fields") if entry.get("fields") is Array else []


## The read-only values a kind shows greyed at the foot of its card.
static func live_of(entry: Dictionary) -> Array:
	return entry.get("live") if entry.get("live") is Array else []


## Whether a field shows for this card: a field with a `show_if` key appears only while that key's
## value is on. This is the show-if of the Inspector's own conditions, scoped to one card.
static func field_visible(field: Dictionary, card: Dictionary) -> bool:
	var gate: String = str(field.get("show_if", ""))
	if gate.is_empty():
		return true
	var value: Variant = card.get(gate)
	if value is String:
		return not (value as String).strip_edges().is_empty() and str(value) != "false"
	if value is bool or value is int or value is float:
		return bool(value)
	return value != null


## A brand-new card of one kind: the kind key first, then the entry's `defaults` in their declared
## order, then any field default not already seeded. The order matters - a saved list is a text file,
## and a newly added card should read like the ones beside it.
static func new_card(spec: Dictionary, entry: Dictionary) -> Dictionary:
	var card: Dictionary = {}
	card[str(spec.get("kind_key", "kind"))] = str(entry.get("kind", ""))
	var defaults: Dictionary = entry.get("defaults") if entry.get("defaults") is Dictionary else {}
	for key: Variant in defaults:
		card[str(key)] = defaults[key]
	for field: Variant in fields_of(entry):
		if not (field is Dictionary):
			continue
		var field_key: String = str((field as Dictionary).get("key", ""))
		if not field_key.is_empty() and not card.has(field_key) and (field as Dictionary).has("default"):
			card[field_key] = (field as Dictionary)["default"]
	return card


## The list with the card at `from` moved to `to` - what a finished drag writes. Out-of-range indices
## hand the list back untouched, so a drop onto nothing is a no-op rather than a lost card.
static func move_card(cards: Array, from: int, to: int) -> Array:
	var moved: Array = _copy_cards(cards)
	if from < 0 or from >= moved.size() or to < 0 or to >= moved.size() or from == to:
		return moved
	var card: Variant = moved[from]
	moved.remove_at(from)
	moved.insert(to, card)
	return moved


## The list with the card at `index` copied directly below itself.
static func duplicate_card(cards: Array, index: int) -> Array:
	var copied: Array = _copy_cards(cards)
	if index < 0 or index >= copied.size():
		return copied
	copied.insert(index + 1, (copied[index] as Dictionary).duplicate(true))
	return copied


## The list without the card at `index`.
static func remove_card(cards: Array, index: int) -> Array:
	var kept: Array = _copy_cards(cards)
	if index >= 0 and index < kept.size():
		kept.remove_at(index)
	return kept


## Cards as clipboard text: the marker line, then Godot's own variant spelling, which keeps an int an
## int and a float a float (JSON would not), so a pasted card stores exactly what the copied one did.
static func cards_to_text(cards: Array) -> String:
	return CLIPBOARD_PREFIX + var_to_str(_copy_cards(cards))


## Clipboard text back to cards. Text without the marker is not ours and yields nothing. Every value
## is sanitised on the way in - the variant spelling can describe an Object, and a paste is text from
## outside the editor, so anything that is not plain data is dropped rather than reconstructed.
static func cards_from_text(text: String) -> Array:
	if not text.begins_with(CLIPBOARD_PREFIX):
		return []
	var parsed: Variant = str_to_var(text.substr(CLIPBOARD_PREFIX.length()))
	if not (parsed is Array):
		return []
	var cards: Array = []
	for entry: Variant in parsed as Array:
		if entry is Dictionary:
			cards.append(_sanitize(entry))
	return cards


## A deep copy of a card list, keeping only its Dictionary entries.
static func _copy_cards(cards: Array) -> Array:
	var copied: Array = []
	for entry: Variant in cards:
		if entry is Dictionary:
			copied.append((entry as Dictionary).duplicate(true))
	return copied


## Plain data only: Objects, Callables, Signals and RIDs are dropped wherever they appear, so pasted
## text can carry values but never behaviour.
static func _sanitize(value: Variant) -> Variant:
	if value is Dictionary:
		var clean_dict: Dictionary = {}
		for key: Variant in value as Dictionary:
			var cleaned: Variant = _sanitize((value as Dictionary)[key])
			if cleaned != null:
				clean_dict[str(key)] = cleaned
		return clean_dict
	if value is Array:
		var clean_array: Array = []
		for item: Variant in value as Array:
			var cleaned_item: Variant = _sanitize(item)
			if cleaned_item != null:
				clean_array.append(cleaned_item)
		return clean_array
	match typeof(value):
		TYPE_OBJECT, TYPE_CALLABLE, TYPE_SIGNAL, TYPE_RID, TYPE_NIL:
			return null
	return value


## A schema DERIVED from ACE descriptors: one kind per verb, its label and help from the words the
## picker already shows, its fields from the verb's own parameters. A pack that publishes verbs gets
## a card list for them with no editor code of its own - the same reason the picker's dialog is
## derived rather than written per verb.
static func from_aces(aces: Array, fallback_category: String = "") -> Dictionary:
	var kinds: Array = []
	for ace: Variant in aces:
		if not (ace is ACEDescriptor):
			continue
		var descriptor: ACEDescriptor = ace as ACEDescriptor
		if descriptor.ace_id.strip_edges().is_empty():
			continue
		var category: String = descriptor.category.strip_edges()
		var fields: Array = []
		for param: ACEParam in descriptor.params:
			fields.append(_field_from_param(param))
		kinds.append({
			"kind": descriptor.ace_id,
			"category": category if not category.is_empty() else fallback_category,
			"label": _ace_label(descriptor),
			"help": descriptor.description,
			"fields": fields,
			"live": [],
		})
	return {"kinds": kinds}


## The words a picker reads out for a verb, in the order the picker prefers them.
static func _ace_label(descriptor: ACEDescriptor) -> String:
	for candidate: String in [descriptor.display_name, descriptor.list_name, descriptor.listName]:
		if not candidate.strip_edges().is_empty():
			return candidate.strip_edges()
	return descriptor.ace_id.capitalize()


## One parameter as one card field. The drawer is chosen from what the parameter already declares -
## its fixed choices become toggle buttons (a dropdown once there are too many to sit in a row), its
## type picks the editor - so a verb needs to say nothing extra to get a card that reads well.
static func _field_from_param(param: ACEParam) -> Dictionary:
	var key: String = param.id if not param.id.strip_edges().is_empty() else param.name
	var label: String = param.display_name if not param.display_name.strip_edges().is_empty() else key.capitalize()
	var options: PackedStringArray = PackedStringArray()
	for option: Variant in param.options:
		var cleaned: String = str(option).strip_edges()
		if not cleaned.is_empty() and not cleaned.contains(",") and not cleaned.contains(":"):
			options.append(cleaned)
	var drawer: String = ""
	if not options.is_empty():
		drawer = "%s:%s" % ["toggle_row" if options.size() <= 4 else "options", ",".join(options)]
	else:
		match param.type_name:
			"bool":
				drawer = "bool"
			"int":
				drawer = "int"
			"float":
				drawer = "num"
			"Color":
				drawer = "swatch_row"
			_:
				drawer = "text"
	return {"key": key, "label": label, "drawer": drawer, "default": _default_for_drawer(drawer, param.default_value)}


## A parameter's default read as the value a card would store. Verbs spell their defaults as GDScript
## text ("0.0", "true"), which is right for a code template and wrong for a number field, so a
## numeric or boolean drawer converts it once here rather than every time a card is drawn.
static func _default_for_drawer(drawer: String, default_value: Variant) -> Variant:
	var text: String = str(default_value).strip_edges()
	match drawer:
		"num":
			return text.to_float() if text.is_valid_float() else 0.0
		"int":
			return text.to_int() if text.is_valid_int() else 0
		"bool":
			return text == "true"
	return text
