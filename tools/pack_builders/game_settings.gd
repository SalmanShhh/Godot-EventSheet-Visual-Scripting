# Pack builder - game_settings (one pack per file; run via tools/build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")


## Game Settings: settings that DECLARE themselves, as the Settings autoload.
##
## The shipped Save Setting writes a value to user://settings.cfg and stops there: nothing says a
## setting exists, so its default, its kind and its range get retyped at every call site and drift.
## Declare Setting names it once - default, kind, choices - and everything else follows from that
## one declaration:
##   - Setting Value answers the saved value, or the declared default when nothing was ever saved,
##     so the game sounds right on first boot instead of after the player opens the options screen.
##   - Changing one fires On Setting Changed (a real signal carrying the name and the new value),
##     so every reaction is an ordinary event branched by name, in whichever sheet owns it.
##   - Apply All Settings re-fires that trigger for EVERY declared setting, which is what makes boot
##     and the options screen take the same path and never drift apart.
##   - Reset To Defaults, a Settings Report, and a menu buildable from the declaration come free.
## Storage is the same FILE the shipped Save Setting writes to (user://settings.cfg), in a section
## named "settings". Save Setting takes its section as a parameter and offers "audio", so the two
## only share values when that row is pointed at the "settings" section - which is the one line to
## change in a project that is moving over.
static func build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.autoload_mode = true
	sheet.autoload_name = "Settings"
	sheet.host_class = "Node"
	sheet.custom_class_name = "GameSettingsAddon"
	sheet.class_description = "Settings that declare themselves, as the Settings autoload: Declare Setting names one once (default, kind, choices), Set Setting changes it, and On Setting Changed fires with the name and the new value so every reaction is an ordinary event. Apply All Settings replays them all at boot, so the game and the options screen take the same path."
	sheet.addon_category = "Settings"
	sheet.addon_tags = PackedStringArray(["settings", "options", "accessibility", "audio"])
	var about: CommentRow = CommentRow.new()
	about.text = "Game Settings: register as the Settings autoload. Declare each setting once at startup, Load All Settings, then Apply All Settings - every reaction lives under On Setting Changed, branched by Changed Setting Is. Values persist in user://settings.cfg, section \"settings\" - the same file the built-in Save Setting writes to, so point that action at the \"settings\" section if you want the two to share values. This pack is an event sheet - extend it by editing it."
	sheet.events.append(about)

	# The one trigger: a real signal whose two arguments ARE the row's payload, so a reaction reads
	# the name that changed and the new value without asking anyone what changed last.
	var changed_signal: SignalRow = SignalRow.new()
	changed_signal.signal_name = "setting_changed"
	changed_signal.params = PackedStringArray(["setting_name: String", "value: Variant"])
	changed_signal.trigger = true
	changed_signal.ace_name = "On Setting Changed"
	changed_signal.ace_category = "Settings"
	sheet.events.append(changed_signal)

	var block: RawCodeRow = RawCodeRow.new()
	block.code = "\n".join(PackedStringArray([
		"# Where settings live on disk: the same FILE the built-in Save Setting action writes to, in a",
		"# section named \"settings\". That action takes its section as a parameter (and offers \"audio\"),",
		"# so point it at \"settings\" if you want values saved that way picked up here.",
		"const SETTINGS_FILE: String = \"user://settings.cfg\"",
		"const SETTINGS_SECTION: String = \"settings\"",
		"",
		"# setting name -> {default, kind, choices} - what the game OFFERS. Declared once at startup.",
		"var _declared: Dictionary = {}",
		"# setting name -> the value in force right now. A name missing here falls back to its default,",
		"# which is why a fresh install is already correct instead of empty.",
		"var _values: Dictionary = {}",
		"# The names being announced right now, innermost last. Changed Setting Is reads the last one,",
		"# so a reaction that changes a second setting cannot make the outer row answer about it.",
		"var _announcing: Array[String] = []",
		"# The name announced most recently, kept after the stack empties. An event that WAITS resumes",
		"# long after emit() returned and the stack was popped, and this is what lets its later rows",
		"# still answer Changed Setting Is instead of silently going false halfway through.",
		"var _last_announced: String = \"\"",
		"",
		"# Fires the trigger for one setting and keeps the announcing stack honest while handlers run.",
		"func _announce(setting_name: String, value: Variant) -> void:",
		"\t_announcing.append(setting_name)",
		"\t_last_announced = setting_name",
		"\tsetting_changed.emit(setting_name, value)",
		"\t_announcing.pop_back()"
	]))
	sheet.events.append(block)

	# --- Declaring and changing ---
	var declare: EventFunction = Lib.exposed_function("declare_setting", "Declare Setting", "Settings",
		"Names a setting once: what it is called, what it defaults to, what kind of value it is, and (for a Choice) its options. Everything else in this pack reads that declaration, so the default is written in one place instead of at five call sites. Declaring the same name again replaces the declaration and keeps any value already set.",
		[["setting_name", "String"], ["default_value", "Variant"], ["kind", "String"], ["choices", "String"]],
		"_declared[setting_name] = {\"default\": default_value, \"kind\": kind, \"choices\": choices}")
	_kind_options(declare, "kind")
	_optional(declare, "kind", "\"percent\"")
	_optional(declare, "choices", "\"\"")
	sheet.functions.append(declare)

	Lib.append_function(sheet, "set_setting", "Set Setting", "Settings",
		"Changes a declared setting and fires On Setting Changed with its name and new value. Setting it to the value it already holds does nothing at all, so a slider dragged back to where it started fires no reaction. A name that was never declared is refused with a warning rather than quietly stored.",
		[["setting_name", "String"], ["value", "Variant"]],
		"\n".join(PackedStringArray([
			"if not _declared.has(setting_name):",
			"\tpush_warning(\"Settings: '%s' was never declared - Declare Setting it first, so it has a default and a kind.\" % setting_name)",
			"\treturn",
			"if setting_value(setting_name) == value:",
			"\treturn",
			"_values[setting_name] = value",
			"_announce(setting_name, value)"
		])))
	Lib.append_function(sheet, "apply_all_settings", "Apply All Settings", "Settings",
		"Re-fires On Setting Changed for EVERY declared setting, with the value in force now. This is the one row that makes boot and the options screen take the same path: the volume, the shake and the difficulty are applied by the same events either way, so they can never drift apart. Call it once after Load All Settings.",
		[],
		"for setting_name: String in _declared:\n\t_announce(setting_name, setting_value(setting_name))")
	Lib.append_function(sheet, "reset_settings_to_defaults", "Reset Settings To Defaults", "Settings",
		"Forgets every value that was set or loaded, so each setting falls back to its declared default, then re-applies them all (On Setting Changed fires for each). The options screen's Reset button, for free. Save All Settings afterwards to make it stick.",
		[],
		"_values.clear()\napply_all_settings()")

	# --- Persistence (the same user://settings.cfg the built-in Save Setting writes) ---
	Lib.append_function(sheet, "load_all_settings", "Load All Settings", "Settings",
		"Reads saved values out of user://settings.cfg (the settings section) for every declared setting. The built-in Save Setting action writes the same file but takes its section as a parameter, so values saved that way are picked up when that row names the settings section. A setting with nothing saved keeps its default. Nothing is applied yet: follow it with Apply All Settings.",
		[],
		"\n".join(PackedStringArray([
			"var config: ConfigFile = ConfigFile.new()",
			"if config.load(SETTINGS_FILE) != OK:",
			"\treturn",
			"for setting_name: String in _declared:",
			"\tif config.has_section_key(SETTINGS_SECTION, setting_name):",
			"\t\t_values[setting_name] = config.get_value(SETTINGS_SECTION, setting_name)"
		])))
	Lib.append_function(sheet, "save_all_settings", "Save All Settings", "Settings",
		"Writes every declared setting's current value into user://settings.cfg (the settings section), keeping anything else already in the file. Call it when the player closes the options screen. Settings live outside your save slots on purpose, so starting a new run never resets the volume.",
		[],
		"\n".join(PackedStringArray([
			"var config: ConfigFile = ConfigFile.new()",
			"config.load(SETTINGS_FILE)",
			"for setting_name: String in _declared:",
			"\tconfig.set_value(SETTINGS_SECTION, setting_name, setting_value(setting_name))",
			"config.save(SETTINGS_FILE)"
		])))

	# --- Conditions ---
	Lib.condition(sheet, "changed_setting_is", "Changed Setting Is", "Settings",
		"Whether the setting being announced right now is this one - the branch under On Setting Changed. Put one sub-event per setting under the trigger and each reaction stays a plain row. Once the announcement is over it keeps answering about the setting announced most recently, which is what makes it survive a reaction that waits; where several settings are applied in one go (Apply All Settings) and the reaction waits, branch on the trigger row's own setting_name value instead.",
		[["setting_name", "String"]],
		"if not _announcing.is_empty():\n\treturn _announcing[_announcing.size() - 1] == setting_name\nreturn _last_announced == setting_name")
	Lib.condition(sheet, "setting_is", "Setting Is", "Settings",
		"Whether a setting currently holds this value - the plain state check, usable anywhere and at any time. difficulty is hard gates a rule; screen_shake is true guards an effect. An undeclared name reads as not matching.",
		[["setting_name", "String"], ["value", "Variant"]],
		"return _declared.has(setting_name) and setting_value(setting_name) == value")
	Lib.condition(sheet, "setting_is_declared", "Setting Is Declared", "Settings",
		"Whether a setting has been declared at all. Useful when one sheet declares the settings and another might run first.",
		[["setting_name", "String"]],
		"return _declared.has(setting_name)")

	# --- Expressions ---
	var value_of: EventFunction = Lib.exposed_function("setting_value", "Setting Value", "Settings",
		"The value a setting holds right now: the one that was set or loaded, or its declared default when nothing was ever saved. That fallback is the whole point of declaring - the game is correct on a fresh install, before the player has opened the options screen once. An undeclared name gives nothing.",
		[["setting_name", "String"]],
		"return _values.get(setting_name, (_declared.get(setting_name, {}) as Dictionary).get(\"default\", null))")
	value_of.return_type = TYPE_MAX
	sheet.functions.append(value_of)
	Lib.number(sheet, "setting_kind", "Setting Kind", "Settings",
		"What kind of value a setting is - percent, toggle, choice, number or text. This is what an options menu reads to know whether to build a slider, a checkbox or a dropdown. Blank when the name was never declared.",
		[["setting_name", "String"]],
		"return str((_declared.get(setting_name, {}) as Dictionary).get(\"kind\", \"\"))", TYPE_STRING)
	Lib.number(sheet, "setting_choices", "Setting Choices", "Settings",
		"The options of a Choice setting as a list, in the order they were declared - drop it straight into a dropdown. Empty for every other kind.",
		[["setting_name", "String"]],
		"var text: String = str((_declared.get(setting_name, {}) as Dictionary).get(\"choices\", \"\"))\nif text.strip_edges().is_empty():\n\treturn []\nreturn Array(text.split(\"|\", false)).map(func(part: String) -> String: return part.strip_edges())", TYPE_ARRAY)
	Lib.number(sheet, "declared_setting_names", "Declared Setting Names", "Settings",
		"Every declared setting's name, in the order they were declared - For Each over it and an options menu builds itself from the declaration instead of a hand-wired control per setting.",
		[],
		"return _declared.keys()", TYPE_ARRAY)
	Lib.number(sheet, "settings_report", "Settings Report", "Settings",
		"Every declared setting as one readable line - name, kind, the value in force and the default it came from. What your game actually offers, in a form you can print, show in a debug overlay, or paste into a bug report. Blank when nothing has been declared.",
		[],
		"\n".join(PackedStringArray([
			"var lines: PackedStringArray = PackedStringArray()",
			"for setting_name: String in _declared:",
			"\tvar entry: Dictionary = _declared[setting_name]",
			"\tlines.append(\"%s (%s): %s [default %s]\" % [setting_name, str(entry.get(\"kind\", \"\")), str(setting_value(setting_name)), str(entry.get(\"default\", null))])",
			"return \"\\n\".join(lines)"
		])), TYPE_STRING)

	# Save-state seam - deliberately unpublished; the Save System provides the user-facing verbs.
	# Only the VALUES travel: the declarations belong to the game's code, not to a save file, so a
	# build that added a setting keeps its new default instead of restoring a file that never had it.
	var persistence: RawCodeRow = RawCodeRow.new()
	persistence.code = "\n".join(PackedStringArray([
		"# Save-state seam: the Save System walks any node in its persist group (or targeted",
		"# by Save/Load Node State) and duck-types these two methods. Plain data only.",
		"## @ace_hidden",
		"func save_state() -> Dictionary:",
		"\treturn {\"values\": _values.duplicate(true)}",
		"",
		"## @ace_hidden",
		"func load_state(state: Dictionary) -> void:",
		"\tif state.is_empty():",
		"\t\treturn",
		"\t_values = (state.get(\"values\", {}) as Dictionary).duplicate(true)"
	]))
	sheet.events.append(persistence)

	Lib.verb_sentences(sheet, {
		"declare_setting": "Declare setting [b]{setting_name}[/b] default [b]{default_value}[/b] kind [b]{kind}[/b]",
		"set_setting": "Set setting [b]{setting_name}[/b] to [b]{value}[/b]",
		"setting_is": "Setting [b]{setting_name}[/b] is [b]{value}[/b]",
		"changed_setting_is": "Changed setting is [b]{setting_name}[/b]",
	})
	Lib.feature_verbs(sheet, ["declare_setting", "set_setting"])
	return Lib.save_pack(sheet, "res://eventsheet_addons/game_settings/game_settings_addon",
		"res://eventsheet_addons/game_settings/icon.svg")


## The kind dropdown: the friendly label is shown, the stored token is what an options menu reads
## back through Setting Kind to know which control to build.
static func _kind_options(fn: EventFunction, param_id: String) -> void:
	for parameter: ACEParam in fn.params:
		if parameter.id == param_id:
			parameter.options = [
				{"key": "percent", "label": "Percent (0-100 slider)"},
				{"key": "toggle", "label": "Yes/No"},
				{"key": "choice", "label": "Choice"},
				{"key": "number", "label": "Number"},
				{"key": "text", "label": "Text"},
			]
			parameter.default_value = "percent"


## Gives a trailing parameter a GDScript default, so the row can leave it out entirely.
static func _optional(fn: EventFunction, param_id: String, gdscript_default: String) -> void:
	for parameter: ACEParam in fn.params:
		if parameter.id == param_id:
			parameter.gdscript_default = gdscript_default
