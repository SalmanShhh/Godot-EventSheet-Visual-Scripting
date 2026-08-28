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
		"# Every control bound to the setting is shown the new value FIRST, so a reaction that reads the",
		"# menu back sees what the player is looking at, and so a value changed anywhere else - a quality",
		"# preset, Reset To Defaults, another menu still open - reaches the screen without a single row.",
		"func _announce(setting_name: String, value: Variant) -> void:",
		"\t_show_in_bound_controls(setting_name, value)",
		"\t_announcing.append(setting_name)",
		"\t_last_announced = setting_name",
		"\tsetting_changed.emit(setting_name, value)",
		"\t_announcing.pop_back()"
	]))
	sheet.events.append(block)

	# --- Declaring and changing ---
	var declare: EventFunction = Lib.exposed_function("declare_setting", "Declare Setting", "Settings",
		"Names a setting once: what it is called, what it defaults to, what kind of value it is, (for a Choice) its options, and which options page it belongs on. Everything else in this pack reads that declaration, so the default is written in one place instead of at five call sites - and this is the single entry point for an option of ANY kind. Difficulty, motion blur and invert Y are one Declare row each plus one On Setting Changed reaction whose rows do what the setting means; the menu control, the saved value, Reset To Defaults and the boot re-apply all follow from the declaration, with nothing to register anywhere else. Declaring the same name again replaces the declaration and keeps any value already set.",
		[["setting_name", "String"], ["default_value", "Variant"], ["kind", "String"], ["choices", "String"],
			["page", "String"], ["label", "String"]],
		"_declared[setting_name] = {\"default\": default_value, \"kind\": kind, \"choices\": choices, \"page\": page, \"label\": label}")
	_kind_options(declare, "kind")
	_optional(declare, "kind", "\"percent\"")
	_optional(declare, "choices", "\"\"")
	_optional(declare, "page", "\"\"")
	_optional(declare, "label", "\"\"")
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

	# --- Quality presets: one WORD over settings that already exist ---
	var quality: RawCodeRow = RawCodeRow.new()
	quality.code = "\n".join(PackedStringArray([
		"# Where the quality words live. Each .tres in this folder IS one choice, so adding a preset is",
		"# adding a file - nothing registers it, and the dropdown, the options page and the label all",
		"# just list the folder.",
		"const QUALITY_FOLDER: String = \"res://settings/quality\"",
		"",
		"# The word one preset file goes by: its own if it named itself, otherwise its file name",
		"# capitalised, which is what \"low.tres\" would have been called anyway.",
		"func _quality_word(preset: Resource, path: String) -> String:",
		"\tvar named: String = str(preset.get(\"preset_name\")).strip_edges()",
		"\tif not named.is_empty():",
		"\t\treturn named",
		"\tvar stem: String = path.get_file().get_basename()",
		"\treturn stem.substr(0, 1).to_upper() + stem.substr(1)",
		"",
		"# The values a preset stands for, or {} for a file that is not a preset at all. Asked by name",
		"# rather than by class so this pack never has to reference another one.",
		"func _quality_values(preset: Resource) -> Dictionary:",
		"\tvar held: Variant = preset.get(\"values\") if preset != null else null",
		"\treturn held if held is Dictionary else {}"
	]))
	sheet.events.append(quality)

	Lib.append_function(sheet, "apply_quality", "Apply Quality", "Settings",
		"Writes every value one quality preset stands for, as ordinary Set Setting changes - so each On Setting Changed row does the actual work, exactly as it would if the player had nudged those settings one at a time. Takes a preset file or a path to one. The preset is a shorthand; the settings are the truth, which is why nudging one afterwards simply changes that setting and the quality word reads Custom on its own.",
		[["preset", "Variant"]],
		"\n".join(PackedStringArray([
			"var asset: Resource = preset if preset is Resource else (load(str(preset)) if ResourceLoader.exists(str(preset)) else null)",
			"var values: Dictionary = _quality_values(asset)",
			"if values.is_empty():",
			"\tpush_warning(\"Settings: '%s' is not a quality preset - point Apply Quality at a .tres in %s.\" % [str(preset), QUALITY_FOLDER])",
			"\treturn",
			"for setting_name: String in values:",
			"\tset_setting(setting_name, values[setting_name])"
		])))
	Lib.append_function(sheet, "apply_quality_step", "Apply Quality One Step", "Settings",
		"Moves to the preset one step lighter (-1) or heavier (+1) than the one in force, and applies it. Stops at the ends rather than wrapping, so a game turning itself down on a struggling machine cannot loop back round to the heaviest preset. The order is each preset file's own Rank. From Custom it starts at the lightest.",
		[["step", "int"]],
		"\n".join(PackedStringArray([
			"var ranked: Array = quality_preset_paths()",
			"if ranked.is_empty():",
			"\treturn",
			"var here: int = ranked.find(quality_preset_path())",
			"var wanted: int = clampi((0 if here < 0 else here) + step, 0, ranked.size() - 1)",
			"apply_quality(ranked[wanted])"
		])))

	Lib.number(sheet, "quality_preset_paths", "Quality Preset Paths", "Settings",
		"Every quality preset in res://settings/quality/, lightest first by each file's Rank. This is the list an options dropdown offers and the list \"one step lower\" walks - the folder, read live, so a preset added while the game was closed is simply there.",
		[],
		"\n".join(PackedStringArray([
			"var found: Array = []",
			"var folder: DirAccess = DirAccess.open(QUALITY_FOLDER)",
			"if folder == null:",
			"\treturn found",
			"for file_name: String in folder.get_files():",
			"\tvar plain: String = file_name.trim_suffix(\".remap\")",
			"\tif plain.ends_with(\".tres\"):",
			"\t\tfound.append(\"%s/%s\" % [QUALITY_FOLDER, plain])",
			"found.sort_custom(func(left: String, right: String) -> bool:",
			"\tvar first: Resource = load(left)",
			"\tvar second: Resource = load(right)",
			"\tvar left_rank: int = int(first.get(\"rank\")) if first != null else 0",
			"\tvar right_rank: int = int(second.get(\"rank\")) if second != null else 0",
			"\tif left_rank == right_rank:",
			"\t\treturn left < right",
			"\treturn left_rank < right_rank)",
			"return found"
		])), TYPE_ARRAY)
	Lib.number(sheet, "quality_preset_names", "Quality Preset Names", "Settings",
		"The words those presets go by, in the same order - drop it straight into a dropdown. A preset that did not name itself goes by its file name.",
		[],
		"\n".join(PackedStringArray([
			"var words: Array = []",
			"for path: String in quality_preset_paths():",
			"\tvar preset: Resource = load(path)",
			"\tif preset != null:",
			"\t\twords.append(_quality_word(preset, path))",
			"return words"
		])), TYPE_ARRAY)
	Lib.number(sheet, "quality_preset_path", "Quality Preset Path", "Settings",
		"The preset file whose values are ALL in force right now, or nothing when no file matches. Worked out by comparing values, never remembered - so it cannot fall out of step with what the game is doing.",
		[],
		"\n".join(PackedStringArray([
			"for path: String in quality_preset_paths():",
			"\tvar values: Dictionary = _quality_values(load(path))",
			"\tif values.is_empty():",
			"\t\tcontinue",
			"\tvar all_match: bool = true",
			"\tfor setting_name: String in values:",
			"\t\tif setting_value(setting_name) != values[setting_name]:",
			"\t\t\tall_match = false",
			"\t\t\tbreak",
			"\tif all_match:",
			"\t\treturn path",
			"return \"\""
		])), TYPE_STRING)
	Lib.number(sheet, "quality_name", "Quality Name", "Settings",
		"The quality word to show a player: the preset whose every value is in force, or \"Custom\" when none of them is. Derived by comparison and never stored, so nudging one graphics setting flips the label on its own and no save file has to carry a word that could go stale.",
		[],
		"\n".join(PackedStringArray([
			"var path: String = quality_preset_path()",
			"if path.is_empty():",
			"\treturn \"Custom\"",
			"return _quality_word(load(path), path)"
		])), TYPE_STRING)
	Lib.condition(sheet, "quality_is", "Quality Is", "Settings",
		"Whether the quality in force right now goes by this word. \"Custom\" answers true whenever the values match no preset file.",
		[["word", "String"]],
		"return quality_name() == word")

	_append_options_menu(sheet)
	_append_rebinding(sheet)

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

	_set_hints(sheet, "apply_quality", {"preset": "quality_preset"})
	_set_hints(sheet, "listen_for_binding", {"action": "input_action"})
	_set_hints(sheet, "reset_binding", {"action": "input_action"})
	_set_hints(sheet, "action_is_unbound", {"action": "input_action"})
	_set_hints(sheet, "key_binding_of", {"action": "input_action"})
	_set_hints(sheet, "pad_binding_of", {"action": "input_action"})
	_set_options(sheet, "listen_for_binding", "device", [
		{"key": "keyboard", "label": "Keyboard or mouse"},
		{"key": "pad", "label": "Gamepad"},
	])
	Lib.verb_sentences(sheet, {
		"declare_setting": "Declare setting [b]{setting_name}[/b] default [b]{default_value}[/b] kind [b]{kind}[/b]",
		"set_setting": "Set setting [b]{setting_name}[/b] to [b]{value}[/b]",
		"setting_is": "Setting [b]{setting_name}[/b] is [b]{value}[/b]",
		"changed_setting_is": "Changed setting is [b]{setting_name}[/b]",
		"apply_quality": "Apply quality [b]{preset}[/b]",
		"apply_quality_step": "Apply quality [b]{step}[/b] step",
		"quality_is": "Quality is [b]{word}[/b]",
		"bind_control": "Bind [i]{control}[/i] to setting [b]{setting_name}[/b]",
		"build_settings_page": "Menu rows on [i]{container}[/i] from the [b]{page}[/b] declarations",
		"build_controls_page": "Controls page on [i]{container}[/i] from the Input Map",
		"keep_a_way_back": "Apply with a way back for [b]{seconds}[/b] s",
		"listen_for_binding": "Listen for a new [b]{device}[/b] binding for [b]{action}[/b]",
		"reset_binding": "Reset the binding of [b]{action}[/b]",
		"action_is_unbound": "[b]{action}[/b] has no binding",
	})
	Lib.feature_verbs(sheet, ["declare_setting", "set_setting"])
	return Lib.save_pack(sheet, "res://eventsheet_addons/game_settings/game_settings_addon",
		"res://eventsheet_addons/game_settings/icon.svg")


## The options menu, which is the same declarations shown on a screen. A control and a setting are one
## fact seen twice, so binding one is ONE row rather than two halves that drift; a page is every
## setting tagged with it, so adding an option later is one Declare row and no scene edit; and the
## focus neighbours are wired as the page is built, because a menu that needs a mouse is a bug found
## at certification rather than in the studio.
static func _append_options_menu(sheet: EventSheetResource) -> void:
	var plumbing: RawCodeRow = RawCodeRow.new()
	plumbing.code = "\n".join(PackedStringArray([
		"# Setting name -> the controls showing it. Both directions run through Set Setting, which does",
		"# nothing when the value is already there - that is what stops a control and a setting echoing",
		"# each other forever, with no flag to remember and nothing to get stuck.",
		"var _bound: Dictionary = {}",
		"",
		"# The values as they stood before a risky change, and the seconds left to keep it. Both are empty",
		"# except between Apply With A Way Back and the answer.",
		"var _way_back: Dictionary = {}",
		"var _keep_seconds: float = 0.0",
		"",
		"# The countdown behind Apply With A Way Back. It runs only while there is a way back to take,",
		"# which is why the first thing it does with an empty clock is switch itself off.",
		"func _process(delta: float) -> void:",
		"\tif _keep_seconds <= 0.0:",
		"\t\tset_process(false)",
		"\t\treturn",
		"\t_keep_seconds = maxf(_keep_seconds - delta, 0.0)",
		"\tif _keep_seconds <= 0.0:",
		"\t\tset_process(false)",
		"\t\tgo_back()",
		"",
		"# Shows one value in every control bound to that setting, dropping any that have since been",
		"# freed - a menu closed and rebuilt leaves nothing behind to write to.",
		"func _show_in_bound_controls(setting_name: String, value: Variant) -> void:",
		"\tvar alive: Array = []",
		"\tfor control: Node in (_bound.get(setting_name, []) as Array):",
		"\t\tif is_instance_valid(control):",
		"\t\t\talive.append(control)",
		"\t\t\t_fill_control(control, setting_name, value)",
		"\tif alive.is_empty():",
		"\t\t_bound.erase(setting_name)",
		"\telse:",
		"\t\t_bound[setting_name] = alive",
		"",
		"# Puts a value into whichever control this is. A dropdown with no items yet takes the declared",
		"# choices, which is what makes a hand-made empty OptionButton a working choice control.",
		"func _fill_control(control: Node, setting_name: String, value: Variant) -> void:",
		"\tif control is OptionButton:",
		"\t\tvar picker: OptionButton = control as OptionButton",
		"\t\tvar words: Array = setting_choices(setting_name)",
		"\t\tif picker.item_count == 0:",
		"\t\t\tfor word: String in words:",
		"\t\t\t\tpicker.add_item(word)",
		"\t\tpicker.select(words.find(value))",
		"\telif control is Range:",
		"\t\t(control as Range).value = float(value)",
		"\telif control is BaseButton:",
		"\t\t(control as BaseButton).button_pressed = bool(value)",
		"\telif control is LineEdit:",
		"\t\t(control as LineEdit).text = str(value)",
		"",
		"# What a control is showing, as the KIND the setting was declared with: a slider under a setting",
		"# that defaults to a whole number gives whole numbers back, so a saved file does not slowly fill",
		"# with 3.0 where the game wrote 3.",
		"func _control_value(control: Node, setting_name: String) -> Variant:",
		"\tvar fallback: Variant = (_declared.get(setting_name, {}) as Dictionary).get(\"default\", null)",
		"\tif control is OptionButton:",
		"\t\tvar words: Array = setting_choices(setting_name)",
		"\t\tvar picked: int = (control as OptionButton).selected",
		"\t\treturn words[picked] if picked >= 0 and picked < words.size() else fallback",
		"\tif control is Range:",
		"\t\tvar number: float = (control as Range).value",
		"\t\treturn int(number) if typeof(fallback) == TYPE_INT else number",
		"\tif control is BaseButton:",
		"\t\treturn (control as BaseButton).button_pressed",
		"\tif control is LineEdit:",
		"\t\treturn (control as LineEdit).text",
		"\treturn fallback",
		"",
		"# A player moved a control. One line, because everything else already knows what to do with it.",
		"func _control_wrote(control: Node, setting_name: String) -> void:",
		"\tset_setting(setting_name, _control_value(control, setting_name))",
		"",
		"# What a kind IS and what it wants to be shown by, in the words the mismatch sentence uses.",
		"func _kind_words(kind: String) -> PackedStringArray:",
		"\tmatch kind:",
		"\t\t\"percent\":",
		"\t\t\treturn PackedStringArray([\"a percent\", \"a slider\"])",
		"\t\t\"number\":",
		"\t\t\treturn PackedStringArray([\"a number\", \"a slider\"])",
		"\t\t\"toggle\":",
		"\t\t\treturn PackedStringArray([\"yes or no\", \"a checkbox\"])",
		"\t\t\"choice\":",
		"\t\t\treturn PackedStringArray([\"a choice\", \"a dropdown\"])",
		"\t\t\"text\":",
		"\t\t\treturn PackedStringArray([\"text\", \"a text box\"])",
		"\treturn PackedStringArray([\"\", \"\"])",
		"",
		"# What a control IS, in those same words. A control this list does not know is not complained",
		"# about: a custom one may show anything, and a wrong guess costs more than no guess.",
		"func _control_word(control: Node) -> String:",
		"\tif control is OptionButton:",
		"\t\treturn \"a dropdown\"",
		"\tif control is Range:",
		"\t\treturn \"a slider\"",
		"\tif control is BaseButton:",
		"\t\treturn \"a checkbox\"",
		"\tif control is LineEdit:",
		"\t\treturn \"a text box\"",
		"\treturn \"\"",
		"",
		"# The control one declared kind asks for, made and named after the setting so a hand-made control",
		"# of that name is found first and this is never built at all.",
		"func _make_control(setting_name: String) -> Control:",
		"\tvar made: Control = null",
		"\tmatch setting_kind(setting_name):",
		"\t\t\"percent\":",
		"\t\t\tvar slider: HSlider = HSlider.new()",
		"\t\t\tslider.min_value = 0.0",
		"\t\t\tslider.max_value = 100.0",
		"\t\t\tslider.step = 1.0",
		"\t\t\tmade = slider",
		"\t\t\"number\":",
		"\t\t\tvar box: SpinBox = SpinBox.new()",
		"\t\t\tbox.allow_greater = true",
		"\t\t\tbox.allow_lesser = true",
		"\t\t\tmade = box",
		"\t\t\"toggle\":",
		"\t\t\tmade = CheckBox.new()",
		"\t\t\"choice\":",
		"\t\t\tmade = OptionButton.new()",
		"\t\t_:",
		"\t\t\tmade = LineEdit.new()",
		"\tmade.name = setting_name",
		"\tmade.size_flags_horizontal = Control.SIZE_EXPAND_FILL",
		"\treturn made",
		"",
		"# A name opened out into words: what a label says when nobody wrote one.",
		"func _words_of(plain_name: String) -> String:",
		"\tvar words: String = plain_name.replace(\"_\", \" \").strip_edges()",
		"\treturn words.substr(0, 1).to_upper() + words.substr(1) if not words.is_empty() else plain_name",
		"",
		"# Every control under a node that a player could put focus on, in the order they are drawn.",
		"func _focusable_controls(container: Node) -> Array:",
		"\tvar found: Array = []",
		"\tif container == null:",
		"\t\treturn found",
		"\tfor child: Node in container.get_children():",
		"\t\tif child is OptionButton or child is Range or child is BaseButton or child is LineEdit:",
		"\t\t\tfound.append(child)",
		"\t\tfound.append_array(_focusable_controls(child))",
		"\treturn found"
	]))
	sheet.events.append(plumbing)

	Lib.append_function(sheet, "bind_control", "Bind To Setting", "Settings",
		"Ties one control to one setting, both ways and at once: the control shows the value in force the moment it is bound, moving it changes the setting, and anything else that changes the setting - a quality preset, Reset To Defaults, a second menu - moves the control back. This is the glue every options screen writes twice per option, as one row. A dropdown with no items yet takes the setting's declared choices.",
		[["control", "Node"], ["setting_name", "String"]],
		"\n".join(PackedStringArray([
			"if control == null:",
			"\tpush_warning(\"Settings: Bind To Setting was given no control to bind.\")",
			"\treturn",
			"if not _declared.has(setting_name):",
			"\tpush_warning(\"Settings: '%s' was never declared - Declare Setting it first, so this control knows its kind, default and choices.\" % setting_name)",
			"\treturn",
			"var reason: String = binding_mismatch(control, setting_name)",
			"if not reason.is_empty():",
			"\tpush_warning(\"Settings: %s\" % reason)",
			"var showing: Array = _bound.get(setting_name, [])",
			"if not showing.has(control):",
			"\tshowing.append(control)",
			"_bound[setting_name] = showing",
			"_fill_control(control, setting_name, setting_value(setting_name))",
			"# One writer for all four control signals: each of them carries exactly one argument, which",
			"# unbind drops, and the pair this row is about is bound in its place.",
			"var writer: Callable = Callable(self, \"_control_wrote\").bind(control, setting_name).unbind(1)",
			"for signal_name: String in [\"value_changed\", \"item_selected\", \"toggled\", \"text_changed\"]:",
			"\tif control.has_signal(signal_name) and not control.is_connected(signal_name, writer):",
			"\t\tcontrol.connect(signal_name, writer)"
		])))
	Lib.number(sheet, "binding_mismatch", "Binding Mismatch", "Settings",
		"Why a control and a setting do not belong together, in one sentence, or nothing at all when they do: \"music_volume is a percent and wants a slider - this is a checkbox.\" Bind To Setting says the same thing in the output log as it binds. A control this pack does not recognise is never complained about - a custom one may show anything.",
		[["control", "Node"], ["setting_name", "String"]],
		"\n".join(PackedStringArray([
			"if control == null:",
			"\treturn \"there is no control to bind.\"",
			"if not _declared.has(setting_name):",
			"\treturn \"nothing declares '%s' yet - Declare Setting it first.\" % setting_name",
			"var words: PackedStringArray = _kind_words(setting_kind(setting_name))",
			"var showing: String = _control_word(control)",
			"if words[1].is_empty() or showing.is_empty() or words[1] == showing:",
			"\treturn \"\"",
			"return \"%s is %s and wants %s - this is %s.\" % [setting_name, words[0], words[1], showing]"
		])), TYPE_STRING)

	Lib.number(sheet, "setting_page", "Setting Page", "Settings",
		"Which options page a setting was declared for, or nothing when it was declared for none. Blank for a name that was never declared.",
		[["setting_name", "String"]],
		"return str((_declared.get(setting_name, {}) as Dictionary).get(\"page\", \"\"))", TYPE_STRING)
	Lib.number(sheet, "setting_label", "Setting Label", "Settings",
		"The words a menu shows beside a setting: the label it was declared with, or its own name opened out (screen_shake reads Screen shake) when nobody wrote one.",
		[["setting_name", "String"]],
		"\n".join(PackedStringArray([
			"var written: String = str((_declared.get(setting_name, {}) as Dictionary).get(\"label\", \"\")).strip_edges()",
			"return written if not written.is_empty() else _words_of(setting_name)"
		])), TYPE_STRING)
	Lib.number(sheet, "settings_on_page", "Settings On Page", "Settings",
		"Every setting declared for one page, in the order they were declared - which is the order the menu shows them in. For Each over it to build a page by hand, or let Menu Rows From Declarations do it.",
		[["page", "String"]],
		"\n".join(PackedStringArray([
			"var found: Array = []",
			"for setting_name: String in _declared:",
			"\tif setting_page(setting_name) == page:",
			"\t\tfound.append(setting_name)",
			"return found"
		])), TYPE_ARRAY)

	Lib.append_function(sheet, "build_settings_page", "Menu Rows From Declarations", "Settings",
		"Fills a container with one labelled row per setting declared for this page, each control bound both ways, and the focus neighbours wired so a keyboard and a pad walk the page from the first frame. The rows are plain Godot controls in a plain container - restyle them, theme them, put them anywhere. A control already in the container NAMED after a setting is used instead of a generated one, so a hand-made slider simply replaces its row and nothing is generated twice. Adding an option later is one Declare Setting row and no scene edit.",
		[["container", "Node"], ["page", "String"]],
		"\n".join(PackedStringArray([
			"if container == null:",
			"\tpush_warning(\"Settings: Menu Rows From Declarations was given no container to fill.\")",
			"\treturn",
			"for setting_name: String in settings_on_page(page):",
			"\tvar made: Node = container.find_child(setting_name, true, false)",
			"\tif made == null:",
			"\t\tvar row: HBoxContainer = HBoxContainer.new()",
			"\t\trow.name = \"%s_row\" % setting_name",
			"\t\tvar label: Label = Label.new()",
			"\t\tlabel.text = setting_label(setting_name)",
			"\t\tlabel.size_flags_horizontal = Control.SIZE_EXPAND_FILL",
			"\t\trow.add_child(label)",
			"\t\tmade = _make_control(setting_name)",
			"\t\trow.add_child(made)",
			"\t\tcontainer.add_child(row)",
			"\tbind_control(made, setting_name)",
			"wire_focus_order(_focusable_controls(container))"
		])))
	Lib.append_function(sheet, "wire_focus_order", "Wire The Focus Order", "Settings",
		"Points every control in a list at the next and previous one, so a pad's up and down and the Tab key walk the page in the order it is drawn, and the last wraps round to the first. Menu Rows From Declarations does this to what it builds; call it yourself after adding controls to a hand-made page. Nothing here grabs focus - a page built off screen should not steal it.",
		[["controls", "Array"]],
		"\n".join(PackedStringArray([
			"var walking: Array = []",
			"for control: Node in controls:",
			"\tif control is Control and (control as Control).visible:",
			"\t\twalking.append(control)",
			"if walking.size() < 2:",
			"\treturn",
			"for index: int in walking.size():",
			"\tvar here: Control = walking[index]",
			"\tvar after: Control = walking[(index + 1) % walking.size()]",
			"\tvar before: Control = walking[(index - 1 + walking.size()) % walking.size()]",
			"\there.focus_mode = Control.FOCUS_ALL",
			"\there.focus_neighbor_bottom = here.get_path_to(after)",
			"\there.focus_next = here.get_path_to(after)",
			"\there.focus_neighbor_top = here.get_path_to(before)",
			"\there.focus_previous = here.get_path_to(before)"
		])))
	Lib.number(sheet, "unreachable_controls", "Unreachable Controls", "Settings",
		"The names of the controls on a page that a keyboard or a pad cannot get to: ones whose focus is switched off, and ones the wired focus chain walks past. Empty is the answer you want. Show it in a debug overlay or print it while building a menu - a page that needs a mouse is a bug found at certification rather than in the studio.",
		[["container", "Node"]],
		"\n".join(PackedStringArray([
			"var stranded: Array = []",
			"var controls: Array = _focusable_controls(container)",
			"var pointed_at: Dictionary = {}",
			"for control: Control in controls:",
			"\tfor path: NodePath in [control.focus_neighbor_top, control.focus_neighbor_bottom, control.focus_next, control.focus_previous]:",
			"\t\tvar neighbour: Node = control.get_node_or_null(path) if not path.is_empty() else null",
			"\t\tif neighbour != null:",
			"\t\t\tpointed_at[neighbour] = true",
			"for control: Control in controls:",
			"\tvar wired_past: bool = not pointed_at.is_empty() and not pointed_at.has(control)",
			"\tif control.focus_mode == Control.FOCUS_NONE or wired_past:",
			"\t\tstranded.append(str(control.name))",
			"return stranded"
		])), TYPE_ARRAY)

	# --- Applying with a way back ---
	var kept: SignalRow = SignalRow.new()
	kept.signal_name = "settings_kept"
	kept.trigger = true
	kept.ace_name = "On Settings Kept"
	kept.ace_category = "Settings"
	sheet.events.append(kept)
	var reverted: SignalRow = SignalRow.new()
	reverted.signal_name = "settings_reverted"
	reverted.trigger = true
	reverted.ace_name = "On Settings Reverted"
	reverted.ace_category = "Settings"
	sheet.events.append(reverted)

	Lib.append_function(sheet, "keep_a_way_back", "Apply With A Way Back", "Settings",
		"Remembers every setting as it stands right now and starts a countdown. Keep These Settings stops it; letting it run out puts every value back and fires On Settings Reverted. This is the answer to the wall every game builds for itself once: a screen mode the monitor cannot show, and the menu you need to undo it is the thing you cannot see. Apply first, then ask, and take silence for a no.",
		[["seconds", "float"]],
		"\n".join(PackedStringArray([
			"_way_back.clear()",
			"for setting_name: String in _declared:",
			"\t_way_back[setting_name] = setting_value(setting_name)",
			"_keep_seconds = maxf(seconds, 0.0)",
			"set_process(_keep_seconds > 0.0)"
		])))
	Lib.append_function(sheet, "keep_settings", "Keep These Settings", "Settings",
		"The player said yes: the countdown stops, the way back is forgotten and On Settings Kept fires. Nothing is changed - what is on screen is already what they chose.",
		[],
		"\n".join(PackedStringArray([
			"_way_back.clear()",
			"_keep_seconds = 0.0",
			"set_process(false)",
			"settings_kept.emit()"
		])))
	Lib.append_function(sheet, "go_back", "Go Back To The Working Settings", "Settings",
		"Puts every setting back the way it was before Apply With A Way Back, through ordinary Set Setting changes so the same reactions run and the menu follows, then fires On Settings Reverted. The countdown calls this itself when nobody answers.",
		[],
		"\n".join(PackedStringArray([
			"var remembered: Dictionary = _way_back.duplicate(true)",
			"_way_back.clear()",
			"_keep_seconds = 0.0",
			"set_process(false)",
			"for setting_name: String in remembered:",
			"\tset_setting(setting_name, remembered[setting_name])",
			"settings_reverted.emit()"
		])))
	Lib.number(sheet, "seconds_left_to_keep", "Seconds Left To Keep", "Settings",
		"How long the player has left to answer, counting down, or 0 when nothing is waiting. Put it in the label of the ask-me dialog so the countdown is visible rather than a surprise.",
		[],
		"return _keep_seconds", TYPE_FLOAT)


## Rebinding, with the conflict answered at bind time instead of discovered later. The Input Map is
## the list (actions added to the project appear on the page on their own), the events are ordinary
## InputMap calls, and the three answers to a taken key are three rows rather than a rule this pack
## picked for everybody.
static func _append_rebinding(sheet: EventSheetResource) -> void:
	var listening: RawCodeRow = RawCodeRow.new()
	listening.code = "\n".join(PackedStringArray([
		"# Where rebindings are kept: the same file as the settings, in a section of its own, so a rebind",
		"# persists with everything else and one Save covers the lot.",
		"const BINDINGS_SECTION: String = \"bindings\"",
		"",
		"# Which control is waiting for a key, which kind of device it wants, and the event a player gave",
		"# that something else already answers to. All three are empty except while a rebinding is open.",
		"var _listening_action: String = \"\"",
		"var _listening_device: String = \"\"",
		"var _pending_event: InputEvent = null",
		"",
		"# The key or button a player pressed while a row was listening. Unhandled input is the right",
		"# place for it: a button press that reached a control belongs to that control, and the key the",
		"# player means for the binding is the one nothing else wanted.",
		"func _unhandled_input(event: InputEvent) -> void:",
		"\tif _listening_action.is_empty() or _pending_event != null:",
		"\t\treturn",
		"\tif not _is_binding_event(event) or not event.is_pressed():",
		"\t\treturn",
		"\tif _device_of(event) != _listening_device:",
		"\t\treturn",
		"\tget_viewport().set_input_as_handled()",
		"\tvar taken_by: String = _action_bound_to(event, _listening_action)",
		"\tif taken_by.is_empty():",
		"\t\t_apply_binding(_listening_action, event)",
		"\t\treturn",
		"\t_pending_event = event",
		"\tbinding_conflict.emit(_listening_action, taken_by)",
		"",
		"# The events worth binding: a key, a mouse button, a pad button. A stick is deliberately not one",
		"# - an axis is not a binding a player can press once, and pretending otherwise reads as a bug.",
		"func _is_binding_event(event: InputEvent) -> bool:",
		"\treturn event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton",
		"",
		"# Which column an event belongs in. Mouse buttons ride with the keyboard, which is where a player",
		"# looking for them expects to find them.",
		"func _device_of(event: InputEvent) -> String:",
		"\treturn \"pad\" if event is InputEventJoypadButton else \"keyboard\"",
		"",
		"# The action that already answers to this event, if any other does. Asked through the Input Map",
		"# rather than by comparing events, so a key stored as a physical code and a key just pressed are",
		"# recognised as the same key.",
		"func _action_bound_to(event: InputEvent, except_action: String) -> String:",
		"\tfor action: String in project_actions():",
		"\t\tif action != except_action and InputMap.event_is_action(event, action):",
		"\t\t\treturn action",
		"\treturn \"\"",
		"",
		"# What one action answers to on one device right now, or nothing.",
		"func _binding_of(action: String, device: String) -> InputEvent:",
		"\tif not InputMap.has_action(action):",
		"\t\treturn null",
		"\tfor event: InputEvent in InputMap.action_get_events(action):",
		"\t\tif _device_of(event) == device:",
		"\t\t\treturn event",
		"\treturn null",
		"",
		"# Gives an action a binding, replacing whatever it had on that device and leaving the other",
		"# device alone - rebinding the key must not cost the pad button.",
		"func _apply_binding(action: String, event: InputEvent) -> void:",
		"\tvar device: String = _device_of(event)",
		"\tfor existing: InputEvent in InputMap.action_get_events(action):",
		"\t\tif _device_of(existing) == device:",
		"\t\t\tInputMap.action_erase_event(action, existing)",
		"\tInputMap.action_add_event(action, event)",
		"\t_listening_action = \"\"",
		"\t_listening_device = \"\"",
		"\t_pending_event = null",
		"\tbinding_changed.emit(action)",
		"",
		"# The words for one event: a key by the name on the key, everything else by the engine's own",
		"# reading of it. Nothing invents a table of pad button names the engine already keeps.",
		"func _event_words(event: InputEvent) -> String:",
		"\tif event == null:",
		"\t\treturn \"\"",
		"\tif event is InputEventKey:",
		"\t\tvar key: InputEventKey = event as InputEventKey",
		"\t\treturn OS.get_keycode_string(key.keycode if key.keycode != KEY_NONE else key.physical_keycode)",
		"\treturn event.as_text()"
	]))
	sheet.events.append(listening)

	var changed: SignalRow = SignalRow.new()
	changed.signal_name = "binding_changed"
	changed.params = PackedStringArray(["action: String"])
	changed.trigger = true
	changed.ace_name = "On Binding Changed"
	changed.ace_category = "Settings"
	sheet.events.append(changed)
	var conflict: SignalRow = SignalRow.new()
	conflict.signal_name = "binding_conflict"
	conflict.params = PackedStringArray(["action: String", "taken_by: String"])
	conflict.trigger = true
	conflict.ace_name = "On Binding Conflict"
	conflict.ace_category = "Settings"
	sheet.events.append(conflict)

	Lib.number(sheet, "project_actions", "Project Actions", "Settings",
		"Every control your project declares in its Input Map, leaving out the engine's own ui_ actions. This is the list a Controls page is built from, read live - an action added to the project last week is simply there, with no page to edit.",
		[],
		"\n".join(PackedStringArray([
			"var found: Array = []",
			"for action: StringName in InputMap.get_actions():",
			"\tif not str(action).begins_with(\"ui_\"):",
			"\t\tfound.append(str(action))",
			"return found"
		])), TYPE_ARRAY)
	Lib.number(sheet, "key_binding_of", "Keyboard Binding Of", "Settings",
		"The key or mouse button one control answers to, in the words a player reads on the key. Blank when it has none, which is what the amber \"no key\" row on a Controls page is showing.",
		[["action", "String"]],
		"return _event_words(_binding_of(action, \"keyboard\"))", TYPE_STRING)
	Lib.number(sheet, "pad_binding_of", "Pad Binding Of", "Settings",
		"The gamepad button one control answers to, in the engine's own words for it. Blank when it has none. Keyboard and pad are separate columns of the same row because a player rebinding one must not lose the other.",
		[["action", "String"]],
		"return _event_words(_binding_of(action, \"pad\"))", TYPE_STRING)
	Lib.number(sheet, "unbound_actions", "Unbound Actions", "Settings",
		"Every control with no binding left on any device - the ones a player cannot use at all. A Take It Anyway rebinding leaves the action it took the key from in this list, which is exactly what the amber mark on its row is for.",
		[],
		"\n".join(PackedStringArray([
			"var stranded: Array = []",
			"for action: String in project_actions():",
			"\tif InputMap.action_get_events(action).is_empty():",
			"\t\tstranded.append(action)",
			"return stranded"
		])), TYPE_ARRAY)
	Lib.condition(sheet, "action_is_unbound", "Control Has No Binding", "Settings",
		"Whether one control has no binding left on any device. The condition behind the amber mark on a Controls page row.",
		[["action", "String"]],
		"return InputMap.has_action(action) and InputMap.action_get_events(action).is_empty()")
	Lib.condition(sheet, "waiting_for_a_key", "Waiting For A Key", "Settings",
		"Whether a row is listening for a key or button right now - what the \"press a key...\" label on a Controls page is showing.",
		[],
		"return not _listening_action.is_empty()")
	Lib.number(sheet, "conflicting_action", "Conflicting Control", "Settings",
		"The control that already answers to the key a player just gave, or nothing when it was free. Read it in the On Binding Conflict reaction to say which control the player would be taking the key from.",
		[],
		"return _action_bound_to(_pending_event, _listening_action) if _pending_event != null else \"\"", TYPE_STRING)
	Lib.number(sheet, "pending_binding_words", "Pending Binding Words", "Settings",
		"The key or button the player just gave, in words, while a conflict is waiting to be answered. Blank when nothing is waiting.",
		[],
		"return _event_words(_pending_event)", TYPE_STRING)

	Lib.append_function(sheet, "listen_for_binding", "Listen For A New Binding", "Settings",
		"Waits for the player to press a key, a mouse button or a pad button, and gives it to this control. A free key is bound straight away and On Binding Changed fires; a key something else already answers to fires On Binding Conflict instead and waits for one of the three answers. Only presses on the device you name are taken, so listening for a pad button is not ended by someone resting on the keyboard.",
		[["action", "String"], ["device", "String"]],
		"\n".join(PackedStringArray([
			"if not InputMap.has_action(action):",
			"\tpush_warning(\"Settings: '%s' is not in the Input Map - add it in Project Settings first.\" % action)",
			"\treturn",
			"_listening_action = action",
			"_listening_device = \"pad\" if device == \"pad\" else \"keyboard\"",
			"_pending_event = null"
		])))
	Lib.append_function(sheet, "take_the_binding_anyway", "Take The Binding Anyway", "Settings",
		"The first answer to a conflict: this control takes the key, and the one that had it is left without it. Honest rather than tidy - the other control really has lost its key, which is why it turns up in Unbound Actions and its row goes amber until somebody gives it another.",
		[],
		"\n".join(PackedStringArray([
			"if _pending_event == null:",
			"\treturn",
			"var taken_by: String = _action_bound_to(_pending_event, _listening_action)",
			"if not taken_by.is_empty():",
			"\t# Only the key that was taken: an action bound to two keys keeps the other one, which is",
			"\t# the difference between losing a binding and losing a control.",
			"\tfor event: InputEvent in InputMap.action_get_events(taken_by):",
			"\t\tif event.is_match(_pending_event, false):",
			"\t\t\tInputMap.action_erase_event(taken_by, event)",
			"\tbinding_changed.emit(taken_by)",
			"_apply_binding(_listening_action, _pending_event)"
		])))
	Lib.append_function(sheet, "swap_the_binding", "Swap The Binding", "Settings",
		"The second answer to a conflict: the two controls trade. This one takes the key the player pressed, and the control that had it takes this one's old key on the same device. Nobody is left without a binding, which is why it is the answer to offer first.",
		[],
		"\n".join(PackedStringArray([
			"if _pending_event == null:",
			"\treturn",
			"var action: String = _listening_action",
			"var device: String = _device_of(_pending_event)",
			"var taken_by: String = _action_bound_to(_pending_event, action)",
			"if taken_by.is_empty():",
			"\t_apply_binding(action, _pending_event)",
			"\treturn",
			"# What this control answers to on that device now is what the other one is about to get, so",
			"# it is read before anything is erased.",
			"var handed_over: InputEvent = _binding_of(action, device)",
			"for event: InputEvent in InputMap.action_get_events(taken_by):",
			"\tif event.is_match(_pending_event, false):",
			"\t\tInputMap.action_erase_event(taken_by, event)",
			"if handed_over != null:",
			"\tInputMap.action_add_event(taken_by, handed_over)",
			"_apply_binding(action, _pending_event)",
			"binding_changed.emit(taken_by)"
		])))
	Lib.append_function(sheet, "pick_another_key", "Pick Another Key", "Settings",
		"The third answer to a conflict: forget the key that was taken and go on listening, so the player simply presses a different one. Nothing has changed yet at this point, which is what makes this the safe answer.",
		[],
		"_pending_event = null")
	Lib.append_function(sheet, "cancel_listening", "Stop Listening For A Binding", "Settings",
		"Stops waiting for a key and leaves every binding as it was. The Escape key of a rebinding row.",
		[],
		"\n".join(PackedStringArray([
			"_listening_action = \"\"",
			"_listening_device = \"\"",
			"_pending_event = null"
		])))
	Lib.append_function(sheet, "reset_binding", "Reset One Binding", "Settings",
		"Puts one control back to the bindings your project ships with, on every device, and fires On Binding Changed. The originals come from the Input Map in Project Settings, so this is a reset to what you designed rather than to what was last saved.",
		[["action", "String"]],
		"\n".join(PackedStringArray([
			"if not InputMap.has_action(action):",
			"\treturn",
			"var declared: Dictionary = ProjectSettings.get_setting(\"input/%s\" % action, {})",
			"InputMap.action_erase_events(action)",
			"for event: InputEvent in (declared.get(\"events\", []) as Array):",
			"\tInputMap.action_add_event(action, event)",
			"binding_changed.emit(action)"
		])))
	Lib.append_function(sheet, "reset_all_bindings", "Reset Every Binding", "Settings",
		"Puts every control back to the bindings your project ships with - the page-level Reset All. Save Bindings afterwards to make it stick.",
		[],
		"for action: String in project_actions():\n\treset_binding(action)")
	Lib.append_function(sheet, "save_bindings", "Save Bindings", "Settings",
		"Writes every control's current bindings into the same user://settings.cfg the settings live in, under a section of their own. Call it when the player closes the options screen, beside Save All Settings.",
		[],
		"\n".join(PackedStringArray([
			"var config: ConfigFile = ConfigFile.new()",
			"config.load(SETTINGS_FILE)",
			"for action: String in project_actions():",
			"\tconfig.set_value(BINDINGS_SECTION, action, InputMap.action_get_events(action))",
			"config.save(SETTINGS_FILE)"
		])))
	Lib.append_function(sheet, "load_bindings", "Load Bindings", "Settings",
		"Reads saved bindings back out of user://settings.cfg and puts them into the Input Map. Call it at boot beside Load All Settings. A control with nothing saved keeps the binding your project ships with, so an action added since the player last saved is bound the way you designed it.",
		[],
		"\n".join(PackedStringArray([
			"var config: ConfigFile = ConfigFile.new()",
			"if config.load(SETTINGS_FILE) != OK or not config.has_section(BINDINGS_SECTION):",
			"\treturn",
			"for action: String in config.get_section_keys(BINDINGS_SECTION):",
			"\tif not InputMap.has_action(action):",
			"\t\tcontinue",
			"\tInputMap.action_erase_events(action)",
			"\tfor event: InputEvent in (config.get_value(BINDINGS_SECTION, action, []) as Array):",
			"\t\tInputMap.action_add_event(action, event)"
		])))
	Lib.append_function(sheet, "build_controls_page", "Controls Page From The Input Map", "Settings",
		"Fills a container with one row per control your project declares: its name, its keyboard binding, its pad binding, and a reset. Pressing a binding starts listening for a new one. The rows come from the Input Map, so an action added to the project appears on its own; the buttons keep themselves current through On Binding Changed; and the focus neighbours are wired, so the page works on a pad from the first frame.",
		[["container", "Node"]],
		"\n".join(PackedStringArray([
			"if container == null:",
			"\tpush_warning(\"Settings: Controls Page From The Input Map was given no container to fill.\")",
			"\treturn",
			"for action: String in project_actions():",
			"\tif container.find_child(\"%s_row\" % action, true, false) != null:",
			"\t\tcontinue",
			"\tvar row: HBoxContainer = HBoxContainer.new()",
			"\trow.name = \"%s_row\" % action",
			"\tvar label: Label = Label.new()",
			"\tlabel.text = _words_of(action)",
			"\tlabel.size_flags_horizontal = Control.SIZE_EXPAND_FILL",
			"\trow.add_child(label)",
			"\tfor device: String in [\"keyboard\", \"pad\"]:",
			"\t\tvar button: Button = Button.new()",
			"\t\tbutton.name = \"%s_%s\" % [action, device]",
			"\t\tbutton.size_flags_horizontal = Control.SIZE_EXPAND_FILL",
			"\t\tbutton.pressed.connect(listen_for_binding.bind(action, device))",
			"\t\trow.add_child(button)",
			"\tvar reset: Button = Button.new()",
			"\treset.name = \"%s_reset\" % action",
			"\treset.text = \"Reset\"",
			"\treset.pressed.connect(reset_binding.bind(action))",
			"\trow.add_child(reset)",
			"\tcontainer.add_child(row)",
			"var refresh: Callable = Callable(self, \"_show_bindings\").bind(container).unbind(1)",
			"if not binding_changed.is_connected(refresh):",
			"\tbinding_changed.connect(refresh)",
			"_show_bindings(container)",
			"wire_focus_order(_focusable_controls(container))"
		])))

	var page_refresh: RawCodeRow = RawCodeRow.new()
	page_refresh.code = "\n".join(PackedStringArray([
		"# Writes what every binding button on a generated Controls page says. Kept private because it is",
		"# the page's own upkeep rather than a row anybody would write: the page asks for it once and then",
		"# it happens on every binding change, including the ones a swap makes to the OTHER control.",
		"func _show_bindings(container: Node) -> void:",
		"\tif not is_instance_valid(container):",
		"\t\treturn",
		"\tfor action: String in project_actions():",
		"\t\tfor device: String in [\"keyboard\", \"pad\"]:",
		"\t\t\tvar button: Button = container.find_child(\"%s_%s\" % [action, device], true, false) as Button",
		"\t\t\tif button == null:",
		"\t\t\t\tcontinue",
		"\t\t\tvar words: String = key_binding_of(action) if device == \"keyboard\" else pad_binding_of(action)",
		"\t\t\tbutton.text = words if not words.is_empty() else \"none\""
	]))
	sheet.events.append(page_refresh)


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


## Points named parameters of a published verb at the widget that fills them - the quality preset
## field lists res://settings/quality/ rather than asking anyone to type a path, and a control name
## comes from the project's own Input Map.
static func _set_hints(sheet: EventSheetResource, function_name: String, hints: Dictionary) -> void:
	for parameter: ACEParam in _params_of(sheet, function_name):
		if hints.has(parameter.id):
			parameter.hint = str(hints[parameter.id])


## Turns one parameter of a published verb into a dropdown. The stored key is what the emitted call
## carries; the label is what a reader picks from.
static func _set_options(sheet: EventSheetResource, function_name: String, param_id: String, options: Array) -> void:
	for parameter: ACEParam in _params_of(sheet, function_name):
		if parameter.id == param_id:
			parameter.options = options
			parameter.default_value = str((options[0] as Dictionary).get("key", ""))


## The parameters of one published verb, by name. Empty (and loud) for a name this sheet has no
## function for, which is the typo that would otherwise tune nothing and say nothing.
static func _params_of(sheet: EventSheetResource, function_name: String) -> Array[ACEParam]:
	for function_resource: Resource in sheet.functions:
		if function_resource is EventFunction and (function_resource as EventFunction).function_name == function_name:
			return (function_resource as EventFunction).params
	push_warning("game_settings: no function named %s on this sheet (typo?)" % function_name)
	return []
