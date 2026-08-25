## @ace_tags(settings, options, accessibility, audio)
## @ace_category("Settings")
## @ace_version(1.0.0)
@icon("res://eventsheet_addons/game_settings/icon.svg")
class_name GameSettingsAddon
extends Node
## Settings that declare themselves, as the Settings autoload: Declare Setting names one once (default, kind, choices), Set Setting changes it, and On Setting Changed fires with the name and the new value so every reaction is an ordinary event. Apply All Settings replays them all at boot, so the game and the options screen take the same path.

## @ace_trigger
## @ace_name("On Setting Changed")
## @ace_category("Settings")
signal setting_changed(setting_name: String, value: Variant)
## @ace_trigger
## @ace_name("On Settings Kept")
## @ace_category("Settings")
signal settings_kept
## @ace_trigger
## @ace_name("On Settings Reverted")
## @ace_category("Settings")
signal settings_reverted
## @ace_trigger
## @ace_name("On Binding Changed")
## @ace_category("Settings")
signal binding_changed(action: String)
## @ace_trigger
## @ace_name("On Binding Conflict")
## @ace_category("Settings")
signal binding_conflict(action: String, taken_by: String)

# Where settings live on disk: the same FILE the built-in Save Setting action writes to, in a
# section named "settings". That action takes its section as a parameter (and offers "audio"),
# so point it at "settings" if you want values saved that way picked up here.
const SETTINGS_FILE: String = "user://settings.cfg"
const SETTINGS_SECTION: String = "settings"

# setting name -> {default, kind, choices} - what the game OFFERS. Declared once at startup.
var _declared: Dictionary = {}
# setting name -> the value in force right now. A name missing here falls back to its default,
# which is why a fresh install is already correct instead of empty.
var _values: Dictionary = {}
# The names being announced right now, innermost last. Changed Setting Is reads the last one,
# so a reaction that changes a second setting cannot make the outer row answer about it.
var _announcing: Array[String] = []
# The name announced most recently, kept after the stack empties. An event that WAITS resumes
# long after emit() returned and the stack was popped, and this is what lets its later rows
# still answer Changed Setting Is instead of silently going false halfway through.
var _last_announced: String = ""

# Where the quality words live. Each .tres in this folder IS one choice, so adding a preset is
# adding a file - nothing registers it, and the dropdown, the options page and the label all
# just list the folder.
const QUALITY_FOLDER: String = "res://settings/quality"

# Setting name -> the controls showing it. Both directions run through Set Setting, which does
# nothing when the value is already there - that is what stops a control and a setting echoing
# each other forever, with no flag to remember and nothing to get stuck.
var _bound: Dictionary = {}

# The values as they stood before a risky change, and the seconds left to keep it. Both are empty
# except between Apply With A Way Back and the answer.
var _way_back: Dictionary = {}
var _keep_seconds: float = 0.0
# What a kind IS and what it wants to be shown by, in the words the mismatch sentence uses.
func _kind_words(kind: String) -> PackedStringArray:
	match kind:
		"percent":
			return PackedStringArray(["a percent", "a slider"])
		"number":
			return PackedStringArray(["a number", "a slider"])
		"toggle":
			return PackedStringArray(["yes or no", "a checkbox"])
		"choice":
			return PackedStringArray(["a choice", "a dropdown"])
		"text":
			return PackedStringArray(["text", "a text box"])
	return PackedStringArray(["", ""])
# The control one declared kind asks for, made and named after the setting so a hand-made control
# of that name is found first and this is never built at all.
func _make_control(setting_name: String) -> Control:
	var made: Control = null
	match setting_kind(setting_name):
		"percent":
			var slider: HSlider = HSlider.new()
			slider.min_value = 0.0
			slider.max_value = 100.0
			slider.step = 1.0
			made = slider
		"number":
			var box: SpinBox = SpinBox.new()
			box.allow_greater = true
			box.allow_lesser = true
			made = box
		"toggle":
			made = CheckBox.new()
		"choice":
			made = OptionButton.new()
		_:
			made = LineEdit.new()
	made.name = setting_name
	made.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return made

# Where rebindings are kept: the same file as the settings, in a section of its own, so a rebind
# persists with everything else and one Save covers the lot.
const BINDINGS_SECTION: String = "bindings"

# Which control is waiting for a key, which kind of device it wants, and the event a player gave
# that something else already answers to. All three are empty except while a rebinding is open.
var _listening_action: String = ""
var _listening_device: String = ""
var _pending_event: InputEvent = null
# What one action answers to on one device right now, or nothing.
func _binding_of(action: String, device: String) -> InputEvent:
	if not InputMap.has_action(action):
		return null
	for event: InputEvent in InputMap.action_get_events(action):
		if _device_of(event) == device:
			return event
	return null

## @ace_action
## @ace_featured
## @ace_name("Declare Setting")
## @ace_category("Settings")
## @ace_description("Names a setting once: what it is called, what it defaults to, what kind of value it is, (for a Choice) its options, and which options page it belongs on. Everything else in this pack reads that declaration, so the default is written in one place instead of at five call sites - and this is the single entry point for an option of ANY kind. Difficulty, motion blur and invert Y are one Declare row each plus one On Setting Changed reaction whose rows do what the setting means; the menu control, the saved value, Reset To Defaults and the boot re-apply all follow from the declaration, with nothing to register anywhere else. Declaring the same name again replaces the declaration and keeps any value already set.")
## @ace_display_template("Declare setting [b]{setting_name}[/b] default [b]{default_value}[/b] kind [b]{kind}[/b]")
## @ace_param_options(kind percent=Percent (0-100 slider), toggle=Yes/No, choice=Choice, number=Number, text=Text)
## @ace_icon("res://eventsheet_addons/game_settings/icon.svg")
## @ace_codegen_template("Settings.declare_setting({setting_name}, {default_value}, {kind}, {choices}, {page}, {label})")
func declare_setting(setting_name: String, default_value: Variant, kind: String = "percent", choices: String = "", page: String = "", label: String = "") -> void:
	_declared[setting_name] = {"default": default_value, "kind": kind, "choices": choices, "page": page, "label": label}

## @ace_action
## @ace_featured
## @ace_name("Set Setting")
## @ace_category("Settings")
## @ace_description("Changes a declared setting and fires On Setting Changed with its name and new value. Setting it to the value it already holds does nothing at all, so a slider dragged back to where it started fires no reaction. A name that was never declared is refused with a warning rather than quietly stored.")
## @ace_display_template("Set setting [b]{setting_name}[/b] to [b]{value}[/b]")
## @ace_icon("res://eventsheet_addons/game_settings/icon.svg")
## @ace_codegen_template("Settings.set_setting({setting_name}, {value})")
func set_setting(setting_name: String, value: Variant) -> void:
	if not _declared.has(setting_name):
		push_warning("Settings: '%s' was never declared - Declare Setting it first, so it has a default and a kind." % setting_name)
		return
	if setting_value(setting_name) == value:
		return
	_values[setting_name] = value
	_announce(setting_name, value)

## @ace_action
## @ace_name("Apply All Settings")
## @ace_category("Settings")
## @ace_description("Re-fires On Setting Changed for EVERY declared setting, with the value in force now. This is the one row that makes boot and the options screen take the same path: the volume, the shake and the difficulty are applied by the same events either way, so they can never drift apart. Call it once after Load All Settings.")
## @ace_icon("res://eventsheet_addons/game_settings/icon.svg")
## @ace_codegen_template("Settings.apply_all_settings()")
func apply_all_settings() -> void:
	for setting_name: String in _declared:
		_announce(setting_name, setting_value(setting_name))

## @ace_action
## @ace_name("Reset Settings To Defaults")
## @ace_category("Settings")
## @ace_description("Forgets every value that was set or loaded, so each setting falls back to its declared default, then re-applies them all (On Setting Changed fires for each). The options screen's Reset button, for free. Save All Settings afterwards to make it stick.")
## @ace_icon("res://eventsheet_addons/game_settings/icon.svg")
## @ace_codegen_template("Settings.reset_settings_to_defaults()")
func reset_settings_to_defaults() -> void:
	_values.clear()
	apply_all_settings()

## @ace_action
## @ace_name("Load All Settings")
## @ace_category("Settings")
## @ace_description("Reads saved values out of user://settings.cfg (the settings section) for every declared setting. The built-in Save Setting action writes the same file but takes its section as a parameter, so values saved that way are picked up when that row names the settings section. A setting with nothing saved keeps its default. Nothing is applied yet: follow it with Apply All Settings.")
## @ace_icon("res://eventsheet_addons/game_settings/icon.svg")
## @ace_codegen_template("Settings.load_all_settings()")
func load_all_settings() -> void:
	var config: ConfigFile = ConfigFile.new()
	if config.load(SETTINGS_FILE) != OK:
		return
	for setting_name: String in _declared:
		if config.has_section_key(SETTINGS_SECTION, setting_name):
			_values[setting_name] = config.get_value(SETTINGS_SECTION, setting_name)

## @ace_action
## @ace_name("Save All Settings")
## @ace_category("Settings")
## @ace_description("Writes every declared setting's current value into user://settings.cfg (the settings section), keeping anything else already in the file. Call it when the player closes the options screen. Settings live outside your save slots on purpose, so starting a new run never resets the volume.")
## @ace_icon("res://eventsheet_addons/game_settings/icon.svg")
## @ace_codegen_template("Settings.save_all_settings()")
func save_all_settings() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.load(SETTINGS_FILE)
	for setting_name: String in _declared:
		config.set_value(SETTINGS_SECTION, setting_name, setting_value(setting_name))
	config.save(SETTINGS_FILE)

## @ace_condition
## @ace_name("Changed Setting Is")
## @ace_category("Settings")
## @ace_description("Whether the setting being announced right now is this one - the branch under On Setting Changed. Put one sub-event per setting under the trigger and each reaction stays a plain row. Once the announcement is over it keeps answering about the setting announced most recently, which is what makes it survive a reaction that waits; where several settings are applied in one go (Apply All Settings) and the reaction waits, branch on the trigger row's own setting_name value instead.")
## @ace_display_template("Changed setting is [b]{setting_name}[/b]")
## @ace_icon("res://eventsheet_addons/game_settings/icon.svg")
## @ace_codegen_template("Settings.changed_setting_is({setting_name})")
func changed_setting_is(setting_name: String) -> bool:
	if not _announcing.is_empty():
		return _announcing[_announcing.size() - 1] == setting_name
	return _last_announced == setting_name

## @ace_condition
## @ace_name("Setting Is")
## @ace_category("Settings")
## @ace_description("Whether a setting currently holds this value - the plain state check, usable anywhere and at any time. difficulty is hard gates a rule; screen_shake is true guards an effect. An undeclared name reads as not matching.")
## @ace_display_template("Setting [b]{setting_name}[/b] is [b]{value}[/b]")
## @ace_icon("res://eventsheet_addons/game_settings/icon.svg")
## @ace_codegen_template("Settings.setting_is({setting_name}, {value})")
func setting_is(setting_name: String, value: Variant) -> bool:
	return _declared.has(setting_name) and setting_value(setting_name) == value

## @ace_condition
## @ace_name("Setting Is Declared")
## @ace_category("Settings")
## @ace_description("Whether a setting has been declared at all. Useful when one sheet declares the settings and another might run first.")
## @ace_icon("res://eventsheet_addons/game_settings/icon.svg")
## @ace_codegen_template("Settings.setting_is_declared({setting_name})")
func setting_is_declared(setting_name: String) -> bool:
	return _declared.has(setting_name)

## @ace_expression
## @ace_name("Setting Value")
## @ace_category("Settings")
## @ace_description("The value a setting holds right now: the one that was set or loaded, or its declared default when nothing was ever saved. That fallback is the whole point of declaring - the game is correct on a fresh install, before the player has opened the options screen once. An undeclared name gives nothing.")
## @ace_icon("res://eventsheet_addons/game_settings/icon.svg")
## @ace_codegen_template("Settings.setting_value({setting_name})")
func setting_value(setting_name: String) -> Variant:
	return _values.get(setting_name, (_declared.get(setting_name, {}) as Dictionary).get("default", null))

## @ace_expression
## @ace_name("Setting Kind")
## @ace_category("Settings")
## @ace_description("What kind of value a setting is - percent, toggle, choice, number or text. This is what an options menu reads to know whether to build a slider, a checkbox or a dropdown. Blank when the name was never declared.")
## @ace_icon("res://eventsheet_addons/game_settings/icon.svg")
## @ace_codegen_template("Settings.setting_kind({setting_name})")
func setting_kind(setting_name: String) -> String:
	return str((_declared.get(setting_name, {}) as Dictionary).get("kind", ""))

## @ace_expression
## @ace_name("Setting Choices")
## @ace_category("Settings")
## @ace_description("The options of a Choice setting as a list, in the order they were declared - drop it straight into a dropdown. Empty for every other kind.")
## @ace_icon("res://eventsheet_addons/game_settings/icon.svg")
## @ace_codegen_template("Settings.setting_choices({setting_name})")
func setting_choices(setting_name: String) -> Array:
	var text: String = str((_declared.get(setting_name, {}) as Dictionary).get("choices", ""))
	if text.strip_edges().is_empty():
		return []
	return Array(text.split("|", false)).map(func(part: String) -> String: return part.strip_edges())

## @ace_expression
## @ace_name("Declared Setting Names")
## @ace_category("Settings")
## @ace_description("Every declared setting's name, in the order they were declared - For Each over it and an options menu builds itself from the declaration instead of a hand-wired control per setting.")
## @ace_icon("res://eventsheet_addons/game_settings/icon.svg")
## @ace_codegen_template("Settings.declared_setting_names()")
func declared_setting_names() -> Array:
	return _declared.keys()

## @ace_expression
## @ace_name("Settings Report")
## @ace_category("Settings")
## @ace_description("Every declared setting as one readable line - name, kind, the value in force and the default it came from. What your game actually offers, in a form you can print, show in a debug overlay, or paste into a bug report. Blank when nothing has been declared.")
## @ace_icon("res://eventsheet_addons/game_settings/icon.svg")
## @ace_codegen_template("Settings.settings_report()")
func settings_report() -> String:
	var lines: PackedStringArray = PackedStringArray()
	for setting_name: String in _declared:
		var entry: Dictionary = _declared[setting_name]
		lines.append("%s (%s): %s [default %s]" % [setting_name, str(entry.get("kind", "")), str(setting_value(setting_name)), str(entry.get("default", null))])
	return "\n".join(lines)

## @ace_action
## @ace_name("Apply Quality")
## @ace_category("Settings")
## @ace_description("Writes every value one quality preset stands for, as ordinary Set Setting changes - so each On Setting Changed row does the actual work, exactly as it would if the player had nudged those settings one at a time. Takes a preset file or a path to one. The preset is a shorthand; the settings are the truth, which is why nudging one afterwards simply changes that setting and the quality word reads Custom on its own.")
## @ace_display_template("Apply quality [b]{preset}[/b]")
## @ace_param_hint(preset quality_preset)
## @ace_icon("res://eventsheet_addons/game_settings/icon.svg")
## @ace_codegen_template("Settings.apply_quality({preset})")
func apply_quality(preset: Variant) -> void:
	var asset: Resource = preset if preset is Resource else (load(str(preset)) if ResourceLoader.exists(str(preset)) else null)
	var values: Dictionary = _quality_values(asset)
	if values.is_empty():
		push_warning("Settings: '%s' is not a quality preset - point Apply Quality at a .tres in %s." % [str(preset), QUALITY_FOLDER])
		return
	for setting_name: String in values:
		set_setting(setting_name, values[setting_name])

## @ace_action
## @ace_name("Apply Quality One Step")
## @ace_category("Settings")
## @ace_description("Moves to the preset one step lighter (-1) or heavier (+1) than the one in force, and applies it. Stops at the ends rather than wrapping, so a game turning itself down on a struggling machine cannot loop back round to the heaviest preset. The order is each preset file's own Rank. From Custom it starts at the lightest.")
## @ace_display_template("Apply quality [b]{step}[/b] step")
## @ace_icon("res://eventsheet_addons/game_settings/icon.svg")
## @ace_codegen_template("Settings.apply_quality_step({step})")
func apply_quality_step(step: int) -> void:
	var ranked: Array = quality_preset_paths()
	if ranked.is_empty():
		return
	var here: int = ranked.find(quality_preset_path())
	var wanted: int = clampi((0 if here < 0 else here) + step, 0, ranked.size() - 1)
	apply_quality(ranked[wanted])

## @ace_expression
## @ace_name("Quality Preset Paths")
## @ace_category("Settings")
## @ace_description("Every quality preset in res://settings/quality/, lightest first by each file's Rank. This is the list an options dropdown offers and the list "one step lower" walks - the folder, read live, so a preset added while the game was closed is simply there.")
## @ace_icon("res://eventsheet_addons/game_settings/icon.svg")
## @ace_codegen_template("Settings.quality_preset_paths()")
func quality_preset_paths() -> Array:
	var found: Array = []
	var folder: DirAccess = DirAccess.open(QUALITY_FOLDER)
	if folder == null:
		return found
	for file_name: String in folder.get_files():
		var plain: String = file_name.trim_suffix(".remap")
		if plain.ends_with(".tres"):
			found.append("%s/%s" % [QUALITY_FOLDER, plain])
	found.sort_custom(func(left: String, right: String) -> bool:
		var first: Resource = load(left)
		var second: Resource = load(right)
		var left_rank: int = int(first.get("rank")) if first != null else 0
		var right_rank: int = int(second.get("rank")) if second != null else 0
		if left_rank == right_rank:
			return left < right
		return left_rank < right_rank)
	return found

## @ace_expression
## @ace_name("Quality Preset Names")
## @ace_category("Settings")
## @ace_description("The words those presets go by, in the same order - drop it straight into a dropdown. A preset that did not name itself goes by its file name.")
## @ace_icon("res://eventsheet_addons/game_settings/icon.svg")
## @ace_codegen_template("Settings.quality_preset_names()")
func quality_preset_names() -> Array:
	var words: Array = []
	for path: String in quality_preset_paths():
		var preset: Resource = load(path)
		if preset != null:
			words.append(_quality_word(preset, path))
	return words

## @ace_expression
## @ace_name("Quality Preset Path")
## @ace_category("Settings")
## @ace_description("The preset file whose values are ALL in force right now, or nothing when no file matches. Worked out by comparing values, never remembered - so it cannot fall out of step with what the game is doing.")
## @ace_icon("res://eventsheet_addons/game_settings/icon.svg")
## @ace_codegen_template("Settings.quality_preset_path()")
func quality_preset_path() -> String:
	for path: String in quality_preset_paths():
		var values: Dictionary = _quality_values(load(path))
		if values.is_empty():
			continue
		var all_match: bool = true
		for setting_name: String in values:
			if setting_value(setting_name) != values[setting_name]:
				all_match = false
				break
		if all_match:
			return path
	return ""

## @ace_expression
## @ace_name("Quality Name")
## @ace_category("Settings")
## @ace_description("The quality word to show a player: the preset whose every value is in force, or "Custom" when none of them is. Derived by comparison and never stored, so nudging one graphics setting flips the label on its own and no save file has to carry a word that could go stale.")
## @ace_icon("res://eventsheet_addons/game_settings/icon.svg")
## @ace_codegen_template("Settings.quality_name()")
func quality_name() -> String:
	var path: String = quality_preset_path()
	if path.is_empty():
		return "Custom"
	return _quality_word(load(path), path)

## @ace_condition
## @ace_name("Quality Is")
## @ace_category("Settings")
## @ace_description("Whether the quality in force right now goes by this word. "Custom" answers true whenever the values match no preset file.")
## @ace_display_template("Quality is [b]{word}[/b]")
## @ace_icon("res://eventsheet_addons/game_settings/icon.svg")
## @ace_codegen_template("Settings.quality_is({word})")
func quality_is(word: String) -> bool:
	return quality_name() == word

## @ace_action
## @ace_name("Bind To Setting")
## @ace_category("Settings")
## @ace_description("Ties one control to one setting, both ways and at once: the control shows the value in force the moment it is bound, moving it changes the setting, and anything else that changes the setting - a quality preset, Reset To Defaults, a second menu - moves the control back. This is the glue every options screen writes twice per option, as one row. A dropdown with no items yet takes the setting's declared choices.")
## @ace_display_template("Bind [i]{control}[/i] to setting [b]{setting_name}[/b]")
## @ace_icon("res://eventsheet_addons/game_settings/icon.svg")
## @ace_codegen_template("Settings.bind_control({control}, {setting_name})")
func bind_control(control: Node, setting_name: String) -> void:
	if control == null:
		push_warning("Settings: Bind To Setting was given no control to bind.")
		return
	if not _declared.has(setting_name):
		push_warning("Settings: '%s' was never declared - Declare Setting it first, so this control knows its kind, default and choices." % setting_name)
		return
	var reason: String = binding_mismatch(control, setting_name)
	if not reason.is_empty():
		push_warning("Settings: %s" % reason)
	var showing: Array = _bound.get(setting_name, [])
	if not showing.has(control):
		showing.append(control)
	_bound[setting_name] = showing
	_fill_control(control, setting_name, setting_value(setting_name))
	# One writer for all four control signals: each of them carries exactly one argument, which
	# unbind drops, and the pair this row is about is bound in its place.
	var writer: Callable = Callable(self, "_control_wrote").bind(control, setting_name).unbind(1)
	for signal_name: String in ["value_changed", "item_selected", "toggled", "text_changed"]:
		if control.has_signal(signal_name) and not control.is_connected(signal_name, writer):
			control.connect(signal_name, writer)

## @ace_expression
## @ace_name("Binding Mismatch")
## @ace_category("Settings")
## @ace_description("Why a control and a setting do not belong together, in one sentence, or nothing at all when they do: "music_volume is a percent and wants a slider - this is a checkbox." Bind To Setting says the same thing in the output log as it binds. A control this pack does not recognise is never complained about - a custom one may show anything.")
## @ace_icon("res://eventsheet_addons/game_settings/icon.svg")
## @ace_codegen_template("Settings.binding_mismatch({control}, {setting_name})")
func binding_mismatch(control: Node, setting_name: String) -> String:
	if control == null:
		return "there is no control to bind."
	if not _declared.has(setting_name):
		return "nothing declares '%s' yet - Declare Setting it first." % setting_name
	var words: PackedStringArray = _kind_words(setting_kind(setting_name))
	var showing: String = _control_word(control)
	if words[1].is_empty() or showing.is_empty() or words[1] == showing:
		return ""
	return "%s is %s and wants %s - this is %s." % [setting_name, words[0], words[1], showing]

## @ace_expression
## @ace_name("Setting Page")
## @ace_category("Settings")
## @ace_description("Which options page a setting was declared for, or nothing when it was declared for none. Blank for a name that was never declared.")
## @ace_icon("res://eventsheet_addons/game_settings/icon.svg")
## @ace_codegen_template("Settings.setting_page({setting_name})")
func setting_page(setting_name: String) -> String:
	return str((_declared.get(setting_name, {}) as Dictionary).get("page", ""))

## @ace_expression
## @ace_name("Setting Label")
## @ace_category("Settings")
## @ace_description("The words a menu shows beside a setting: the label it was declared with, or its own name opened out (screen_shake reads Screen shake) when nobody wrote one.")
## @ace_icon("res://eventsheet_addons/game_settings/icon.svg")
## @ace_codegen_template("Settings.setting_label({setting_name})")
func setting_label(setting_name: String) -> String:
	var written: String = str((_declared.get(setting_name, {}) as Dictionary).get("label", "")).strip_edges()
	return written if not written.is_empty() else _words_of(setting_name)

## @ace_expression
## @ace_name("Settings On Page")
## @ace_category("Settings")
## @ace_description("Every setting declared for one page, in the order they were declared - which is the order the menu shows them in. For Each over it to build a page by hand, or let Menu Rows From Declarations do it.")
## @ace_icon("res://eventsheet_addons/game_settings/icon.svg")
## @ace_codegen_template("Settings.settings_on_page({page})")
func settings_on_page(page: String) -> Array:
	var found: Array = []
	for setting_name: String in _declared:
		if setting_page(setting_name) == page:
			found.append(setting_name)
	return found

## @ace_action
## @ace_name("Menu Rows From Declarations")
## @ace_category("Settings")
## @ace_description("Fills a container with one labelled row per setting declared for this page, each control bound both ways, and the focus neighbours wired so a keyboard and a pad walk the page from the first frame. The rows are plain Godot controls in a plain container - restyle them, theme them, put them anywhere. A control already in the container NAMED after a setting is used instead of a generated one, so a hand-made slider simply replaces its row and nothing is generated twice. Adding an option later is one Declare Setting row and no scene edit.")
## @ace_display_template("Menu rows on [i]{container}[/i] from the [b]{page}[/b] declarations")
## @ace_icon("res://eventsheet_addons/game_settings/icon.svg")
## @ace_codegen_template("Settings.build_settings_page({container}, {page})")
func build_settings_page(container: Node, page: String) -> void:
	if container == null:
		push_warning("Settings: Menu Rows From Declarations was given no container to fill.")
		return
	for setting_name: String in settings_on_page(page):
		var made: Node = container.find_child(setting_name, true, false)
		if made == null:
			var row: HBoxContainer = HBoxContainer.new()
			row.name = "%s_row" % setting_name
			var label: Label = Label.new()
			label.text = setting_label(setting_name)
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(label)
			made = _make_control(setting_name)
			row.add_child(made)
			container.add_child(row)
		bind_control(made, setting_name)
	wire_focus_order(_focusable_controls(container))

## @ace_action
## @ace_name("Wire The Focus Order")
## @ace_category("Settings")
## @ace_description("Points every control in a list at the next and previous one, so a pad's up and down and the Tab key walk the page in the order it is drawn, and the last wraps round to the first. Menu Rows From Declarations does this to what it builds; call it yourself after adding controls to a hand-made page. Nothing here grabs focus - a page built off screen should not steal it.")
## @ace_icon("res://eventsheet_addons/game_settings/icon.svg")
## @ace_codegen_template("Settings.wire_focus_order({controls})")
func wire_focus_order(controls: Array) -> void:
	var walking: Array = []
	for control: Node in controls:
		if control is Control and (control as Control).visible:
			walking.append(control)
	if walking.size() < 2:
		return
	for index: int in walking.size():
		var here: Control = walking[index]
		var after: Control = walking[(index + 1) % walking.size()]
		var before: Control = walking[(index - 1 + walking.size()) % walking.size()]
		here.focus_mode = Control.FOCUS_ALL
		here.focus_neighbor_bottom = here.get_path_to(after)
		here.focus_next = here.get_path_to(after)
		here.focus_neighbor_top = here.get_path_to(before)
		here.focus_previous = here.get_path_to(before)

## @ace_expression
## @ace_name("Unreachable Controls")
## @ace_category("Settings")
## @ace_description("The names of the controls on a page that a keyboard or a pad cannot get to: ones whose focus is switched off, and ones the wired focus chain walks past. Empty is the answer you want. Show it in a debug overlay or print it while building a menu - a page that needs a mouse is a bug found at certification rather than in the studio.")
## @ace_icon("res://eventsheet_addons/game_settings/icon.svg")
## @ace_codegen_template("Settings.unreachable_controls({container})")
func unreachable_controls(container: Node) -> Array:
	var stranded: Array = []
	var controls: Array = _focusable_controls(container)
	var pointed_at: Dictionary = {}
	for control: Control in controls:
		for path: NodePath in [control.focus_neighbor_top, control.focus_neighbor_bottom, control.focus_next, control.focus_previous]:
			var neighbour: Node = control.get_node_or_null(path) if not path.is_empty() else null
			if neighbour != null:
				pointed_at[neighbour] = true
	for control: Control in controls:
		var wired_past: bool = not pointed_at.is_empty() and not pointed_at.has(control)
		if control.focus_mode == Control.FOCUS_NONE or wired_past:
			stranded.append(str(control.name))
	return stranded

## @ace_action
## @ace_name("Apply With A Way Back")
## @ace_category("Settings")
## @ace_description("Remembers every setting as it stands right now and starts a countdown. Keep These Settings stops it; letting it run out puts every value back and fires On Settings Reverted. This is the answer to the wall every game builds for itself once: a screen mode the monitor cannot show, and the menu you need to undo it is the thing you cannot see. Apply first, then ask, and take silence for a no.")
## @ace_display_template("Apply with a way back for [b]{seconds}[/b] s")
## @ace_icon("res://eventsheet_addons/game_settings/icon.svg")
## @ace_codegen_template("Settings.keep_a_way_back({seconds})")
func keep_a_way_back(seconds: float) -> void:
	_way_back.clear()
	for setting_name: String in _declared:
		_way_back[setting_name] = setting_value(setting_name)
	_keep_seconds = maxf(seconds, 0.0)
	set_process(_keep_seconds > 0.0)

## @ace_action
## @ace_name("Keep These Settings")
## @ace_category("Settings")
## @ace_description("The player said yes: the countdown stops, the way back is forgotten and On Settings Kept fires. Nothing is changed - what is on screen is already what they chose.")
## @ace_icon("res://eventsheet_addons/game_settings/icon.svg")
## @ace_codegen_template("Settings.keep_settings()")
func keep_settings() -> void:
	_way_back.clear()
	_keep_seconds = 0.0
	set_process(false)
	settings_kept.emit()

## @ace_action
## @ace_name("Go Back To The Working Settings")
## @ace_category("Settings")
## @ace_description("Puts every setting back the way it was before Apply With A Way Back, through ordinary Set Setting changes so the same reactions run and the menu follows, then fires On Settings Reverted. The countdown calls this itself when nobody answers.")
## @ace_icon("res://eventsheet_addons/game_settings/icon.svg")
## @ace_codegen_template("Settings.go_back()")
func go_back() -> void:
	var remembered: Dictionary = _way_back.duplicate(true)
	_way_back.clear()
	_keep_seconds = 0.0
	set_process(false)
	for setting_name: String in remembered:
		set_setting(setting_name, remembered[setting_name])
	settings_reverted.emit()

## @ace_expression
## @ace_name("Seconds Left To Keep")
## @ace_category("Settings")
## @ace_description("How long the player has left to answer, counting down, or 0 when nothing is waiting. Put it in the label of the ask-me dialog so the countdown is visible rather than a surprise.")
## @ace_icon("res://eventsheet_addons/game_settings/icon.svg")
## @ace_codegen_template("Settings.seconds_left_to_keep()")
func seconds_left_to_keep() -> float:
	return _keep_seconds

## @ace_expression
## @ace_name("Project Actions")
## @ace_category("Settings")
## @ace_description("Every control your project declares in its Input Map, leaving out the engine's own ui_ actions. This is the list a Controls page is built from, read live - an action added to the project last week is simply there, with no page to edit.")
## @ace_icon("res://eventsheet_addons/game_settings/icon.svg")
## @ace_codegen_template("Settings.project_actions()")
func project_actions() -> Array:
	var found: Array = []
	for action: StringName in InputMap.get_actions():
		if not str(action).begins_with("ui_"):
			found.append(str(action))
	return found

## @ace_expression
## @ace_name("Keyboard Binding Of")
## @ace_category("Settings")
## @ace_description("The key or mouse button one control answers to, in the words a player reads on the key. Blank when it has none, which is what the amber "no key" row on a Controls page is showing.")
## @ace_param_hint(action input_action)
## @ace_icon("res://eventsheet_addons/game_settings/icon.svg")
## @ace_codegen_template("Settings.key_binding_of({action})")
func key_binding_of(action: String) -> String:
	return _event_words(_binding_of(action, "keyboard"))

## @ace_expression
## @ace_name("Pad Binding Of")
## @ace_category("Settings")
## @ace_description("The gamepad button one control answers to, in the engine's own words for it. Blank when it has none. Keyboard and pad are separate columns of the same row because a player rebinding one must not lose the other.")
## @ace_param_hint(action input_action)
## @ace_icon("res://eventsheet_addons/game_settings/icon.svg")
## @ace_codegen_template("Settings.pad_binding_of({action})")
func pad_binding_of(action: String) -> String:
	return _event_words(_binding_of(action, "pad"))

## @ace_expression
## @ace_name("Unbound Actions")
## @ace_category("Settings")
## @ace_description("Every control with no binding left on any device - the ones a player cannot use at all. A Take It Anyway rebinding leaves the action it took the key from in this list, which is exactly what the amber mark on its row is for.")
## @ace_icon("res://eventsheet_addons/game_settings/icon.svg")
## @ace_codegen_template("Settings.unbound_actions()")
func unbound_actions() -> Array:
	var stranded: Array = []
	for action: String in project_actions():
		if InputMap.action_get_events(action).is_empty():
			stranded.append(action)
	return stranded

## @ace_condition
## @ace_name("Control Has No Binding")
## @ace_category("Settings")
## @ace_description("Whether one control has no binding left on any device. The condition behind the amber mark on a Controls page row.")
## @ace_display_template("[b]{action}[/b] has no binding")
## @ace_param_hint(action input_action)
## @ace_icon("res://eventsheet_addons/game_settings/icon.svg")
## @ace_codegen_template("Settings.action_is_unbound({action})")
func action_is_unbound(action: String) -> bool:
	return InputMap.has_action(action) and InputMap.action_get_events(action).is_empty()

## @ace_condition
## @ace_name("Waiting For A Key")
## @ace_category("Settings")
## @ace_description("Whether a row is listening for a key or button right now - what the "press a key..." label on a Controls page is showing.")
## @ace_icon("res://eventsheet_addons/game_settings/icon.svg")
## @ace_codegen_template("Settings.waiting_for_a_key()")
func waiting_for_a_key() -> bool:
	return not _listening_action.is_empty()

## @ace_expression
## @ace_name("Conflicting Control")
## @ace_category("Settings")
## @ace_description("The control that already answers to the key a player just gave, or nothing when it was free. Read it in the On Binding Conflict reaction to say which control the player would be taking the key from.")
## @ace_icon("res://eventsheet_addons/game_settings/icon.svg")
## @ace_codegen_template("Settings.conflicting_action()")
func conflicting_action() -> String:
	return _action_bound_to(_pending_event, _listening_action) if _pending_event != null else ""

## @ace_expression
## @ace_name("Pending Binding Words")
## @ace_category("Settings")
## @ace_description("The key or button the player just gave, in words, while a conflict is waiting to be answered. Blank when nothing is waiting.")
## @ace_icon("res://eventsheet_addons/game_settings/icon.svg")
## @ace_codegen_template("Settings.pending_binding_words()")
func pending_binding_words() -> String:
	return _event_words(_pending_event)

## @ace_action
## @ace_name("Listen For A New Binding")
## @ace_category("Settings")
## @ace_description("Waits for the player to press a key, a mouse button or a pad button, and gives it to this control. A free key is bound straight away and On Binding Changed fires; a key something else already answers to fires On Binding Conflict instead and waits for one of the three answers. Only presses on the device you name are taken, so listening for a pad button is not ended by someone resting on the keyboard.")
## @ace_display_template("Listen for a new [b]{device}[/b] binding for [b]{action}[/b]")
## @ace_param_hint(action input_action)
## @ace_param_options(device keyboard=Keyboard or mouse, pad=Gamepad)
## @ace_icon("res://eventsheet_addons/game_settings/icon.svg")
## @ace_codegen_template("Settings.listen_for_binding({action}, {device})")
func listen_for_binding(action: String, device: String) -> void:
	if not InputMap.has_action(action):
		push_warning("Settings: '%s' is not in the Input Map - add it in Project Settings first." % action)
		return
	_listening_action = action
	_listening_device = "pad" if device == "pad" else "keyboard"
	_pending_event = null

## @ace_action
## @ace_name("Take The Binding Anyway")
## @ace_category("Settings")
## @ace_description("The first answer to a conflict: this control takes the key, and the one that had it is left without it. Honest rather than tidy - the other control really has lost its key, which is why it turns up in Unbound Actions and its row goes amber until somebody gives it another.")
## @ace_icon("res://eventsheet_addons/game_settings/icon.svg")
## @ace_codegen_template("Settings.take_the_binding_anyway()")
func take_the_binding_anyway() -> void:
	if _pending_event == null:
		return
	var taken_by: String = _action_bound_to(_pending_event, _listening_action)
	if not taken_by.is_empty():
		# Only the key that was taken: an action bound to two keys keeps the other one, which is
		# the difference between losing a binding and losing a control.
		for event: InputEvent in InputMap.action_get_events(taken_by):
			if event.is_match(_pending_event, false):
				InputMap.action_erase_event(taken_by, event)
		binding_changed.emit(taken_by)
	_apply_binding(_listening_action, _pending_event)

## @ace_action
## @ace_name("Swap The Binding")
## @ace_category("Settings")
## @ace_description("The second answer to a conflict: the two controls trade. This one takes the key the player pressed, and the control that had it takes this one's old key on the same device. Nobody is left without a binding, which is why it is the answer to offer first.")
## @ace_icon("res://eventsheet_addons/game_settings/icon.svg")
## @ace_codegen_template("Settings.swap_the_binding()")
func swap_the_binding() -> void:
	if _pending_event == null:
		return
	var action: String = _listening_action
	var device: String = _device_of(_pending_event)
	var taken_by: String = _action_bound_to(_pending_event, action)
	if taken_by.is_empty():
		_apply_binding(action, _pending_event)
		return
	# What this control answers to on that device now is what the other one is about to get, so
	# it is read before anything is erased.
	var handed_over: InputEvent = _binding_of(action, device)
	for event: InputEvent in InputMap.action_get_events(taken_by):
		if event.is_match(_pending_event, false):
			InputMap.action_erase_event(taken_by, event)
	if handed_over != null:
		InputMap.action_add_event(taken_by, handed_over)
	_apply_binding(action, _pending_event)
	binding_changed.emit(taken_by)

## @ace_action
## @ace_name("Pick Another Key")
## @ace_category("Settings")
## @ace_description("The third answer to a conflict: forget the key that was taken and go on listening, so the player simply presses a different one. Nothing has changed yet at this point, which is what makes this the safe answer.")
## @ace_icon("res://eventsheet_addons/game_settings/icon.svg")
## @ace_codegen_template("Settings.pick_another_key()")
func pick_another_key() -> void:
	_pending_event = null

## @ace_action
## @ace_name("Stop Listening For A Binding")
## @ace_category("Settings")
## @ace_description("Stops waiting for a key and leaves every binding as it was. The Escape key of a rebinding row.")
## @ace_icon("res://eventsheet_addons/game_settings/icon.svg")
## @ace_codegen_template("Settings.cancel_listening()")
func cancel_listening() -> void:
	_listening_action = ""
	_listening_device = ""
	_pending_event = null

## @ace_action
## @ace_name("Reset One Binding")
## @ace_category("Settings")
## @ace_description("Puts one control back to the bindings your project ships with, on every device, and fires On Binding Changed. The originals come from the Input Map in Project Settings, so this is a reset to what you designed rather than to what was last saved.")
## @ace_display_template("Reset the binding of [b]{action}[/b]")
## @ace_param_hint(action input_action)
## @ace_icon("res://eventsheet_addons/game_settings/icon.svg")
## @ace_codegen_template("Settings.reset_binding({action})")
func reset_binding(action: String) -> void:
	if not InputMap.has_action(action):
		return
	var declared: Dictionary = ProjectSettings.get_setting("input/%s" % action, {})
	InputMap.action_erase_events(action)
	for event: InputEvent in (declared.get("events", []) as Array):
		InputMap.action_add_event(action, event)
	binding_changed.emit(action)

## @ace_action
## @ace_name("Reset Every Binding")
## @ace_category("Settings")
## @ace_description("Puts every control back to the bindings your project ships with - the page-level Reset All. Save Bindings afterwards to make it stick.")
## @ace_icon("res://eventsheet_addons/game_settings/icon.svg")
## @ace_codegen_template("Settings.reset_all_bindings()")
func reset_all_bindings() -> void:
	for action: String in project_actions():
		reset_binding(action)

## @ace_action
## @ace_name("Save Bindings")
## @ace_category("Settings")
## @ace_description("Writes every control's current bindings into the same user://settings.cfg the settings live in, under a section of their own. Call it when the player closes the options screen, beside Save All Settings.")
## @ace_icon("res://eventsheet_addons/game_settings/icon.svg")
## @ace_codegen_template("Settings.save_bindings()")
func save_bindings() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.load(SETTINGS_FILE)
	for action: String in project_actions():
		config.set_value(BINDINGS_SECTION, action, InputMap.action_get_events(action))
	config.save(SETTINGS_FILE)

## @ace_action
## @ace_name("Load Bindings")
## @ace_category("Settings")
## @ace_description("Reads saved bindings back out of user://settings.cfg and puts them into the Input Map. Call it at boot beside Load All Settings. A control with nothing saved keeps the binding your project ships with, so an action added since the player last saved is bound the way you designed it.")
## @ace_icon("res://eventsheet_addons/game_settings/icon.svg")
## @ace_codegen_template("Settings.load_bindings()")
func load_bindings() -> void:
	var config: ConfigFile = ConfigFile.new()
	if config.load(SETTINGS_FILE) != OK or not config.has_section(BINDINGS_SECTION):
		return
	for action: String in config.get_section_keys(BINDINGS_SECTION):
		if not InputMap.has_action(action):
			continue
		InputMap.action_erase_events(action)
		for event: InputEvent in (config.get_value(BINDINGS_SECTION, action, []) as Array):
			InputMap.action_add_event(action, event)

## @ace_action
## @ace_name("Controls Page From The Input Map")
## @ace_category("Settings")
## @ace_description("Fills a container with one row per control your project declares: its name, its keyboard binding, its pad binding, and a reset. Pressing a binding starts listening for a new one. The rows come from the Input Map, so an action added to the project appears on its own; the buttons keep themselves current through On Binding Changed; and the focus neighbours are wired, so the page works on a pad from the first frame.")
## @ace_display_template("Controls page on [i]{container}[/i] from the Input Map")
## @ace_icon("res://eventsheet_addons/game_settings/icon.svg")
## @ace_codegen_template("Settings.build_controls_page({container})")
func build_controls_page(container: Node) -> void:
	if container == null:
		push_warning("Settings: Controls Page From The Input Map was given no container to fill.")
		return
	for action: String in project_actions():
		if container.find_child("%s_row" % action, true, false) != null:
			continue
		var row: HBoxContainer = HBoxContainer.new()
		row.name = "%s_row" % action
		var label: Label = Label.new()
		label.text = _words_of(action)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		for device: String in ["keyboard", "pad"]:
			var button: Button = Button.new()
			button.name = "%s_%s" % [action, device]
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.pressed.connect(listen_for_binding.bind(action, device))
			row.add_child(button)
		var reset: Button = Button.new()
		reset.name = "%s_reset" % action
		reset.text = "Reset"
		reset.pressed.connect(reset_binding.bind(action))
		row.add_child(reset)
		container.add_child(row)
	var refresh: Callable = Callable(self, "_show_bindings").bind(container).unbind(1)
	if not binding_changed.is_connected(refresh):
		binding_changed.connect(refresh)
	_show_bindings(container)
	wire_focus_order(_focusable_controls(container))

func _announce(setting_name: String, value: Variant) -> void:
	# Fires the trigger for one setting and keeps the announcing stack honest while handlers run.
	# Every control bound to the setting is shown the new value FIRST, so a reaction that reads the
	# menu back sees what the player is looking at, and so a value changed anywhere else - a quality
	# preset, Reset To Defaults, another menu still open - reaches the screen without a single row.
	_show_in_bound_controls(setting_name, value)
	_announcing.append(setting_name)
	_last_announced = setting_name
	setting_changed.emit(setting_name, value)
	_announcing.pop_back()

func _quality_word(preset: Resource, path: String) -> String:
	# The word one preset file goes by: its own if it named itself, otherwise its file name
	# capitalised, which is what "low.tres" would have been called anyway.
	var named: String = str(preset.get("preset_name")).strip_edges()
	if not named.is_empty():
		return named
	var stem: String = path.get_file().get_basename()
	return stem.substr(0, 1).to_upper() + stem.substr(1)

func _quality_values(preset: Resource) -> Dictionary:
	# The values a preset stands for, or {} for a file that is not a preset at all. Asked by name
	# rather than by class so this pack never has to reference another one.
	var held: Variant = preset.get("values") if preset != null else null
	return held if held is Dictionary else {}

func _process(delta: float) -> void:
	# The countdown behind Apply With A Way Back. It runs only while there is a way back to take,
	# which is why the first thing it does with an empty clock is switch itself off.
	if _keep_seconds <= 0.0:
		set_process(false)
		return
	_keep_seconds = maxf(_keep_seconds - delta, 0.0)
	if _keep_seconds <= 0.0:
		set_process(false)
		go_back()

func _show_in_bound_controls(setting_name: String, value: Variant) -> void:
	# Shows one value in every control bound to that setting, dropping any that have since been
	# freed - a menu closed and rebuilt leaves nothing behind to write to.
	var alive: Array = []
	for control: Node in (_bound.get(setting_name, []) as Array):
		if is_instance_valid(control):
			alive.append(control)
			_fill_control(control, setting_name, value)
	if alive.is_empty():
		_bound.erase(setting_name)
	else:
		_bound[setting_name] = alive

func _fill_control(control: Node, setting_name: String, value: Variant) -> void:
	# Puts a value into whichever control this is. A dropdown with no items yet takes the declared
	# choices, which is what makes a hand-made empty OptionButton a working choice control.
	if control is OptionButton:
		var picker: OptionButton = control as OptionButton
		var words: Array = setting_choices(setting_name)
		if picker.item_count == 0:
			for word: String in words:
				picker.add_item(word)
		picker.select(words.find(value))
	elif control is Range:
		(control as Range).value = float(value)
	elif control is BaseButton:
		(control as BaseButton).button_pressed = bool(value)
	elif control is LineEdit:
		(control as LineEdit).text = str(value)

func _control_value(control: Node, setting_name: String) -> Variant:
	# What a control is showing, as the KIND the setting was declared with: a slider under a setting
	# that defaults to a whole number gives whole numbers back, so a saved file does not slowly fill
	# with 3.0 where the game wrote 3.
	var fallback: Variant = (_declared.get(setting_name, {}) as Dictionary).get("default", null)
	if control is OptionButton:
		var words: Array = setting_choices(setting_name)
		var picked: int = (control as OptionButton).selected
		return words[picked] if picked >= 0 and picked < words.size() else fallback
	if control is Range:
		var number: float = (control as Range).value
		return int(number) if typeof(fallback) == TYPE_INT else number
	if control is BaseButton:
		return (control as BaseButton).button_pressed
	if control is LineEdit:
		return (control as LineEdit).text
	return fallback

func _control_wrote(control: Node, setting_name: String) -> void:
	# A player moved a control. One line, because everything else already knows what to do with it.
	set_setting(setting_name, _control_value(control, setting_name))

func _control_word(control: Node) -> String:
	# What a control IS, in those same words. A control this list does not know is not complained
	# about: a custom one may show anything, and a wrong guess costs more than no guess.
	if control is OptionButton:
		return "a dropdown"
	if control is Range:
		return "a slider"
	if control is BaseButton:
		return "a checkbox"
	if control is LineEdit:
		return "a text box"
	return ""

func _words_of(plain_name: String) -> String:
	# A name opened out into words: what a label says when nobody wrote one.
	var words: String = plain_name.replace("_", " ").strip_edges()
	return words.substr(0, 1).to_upper() + words.substr(1) if not words.is_empty() else plain_name

func _focusable_controls(container: Node) -> Array:
	# Every control under a node that a player could put focus on, in the order they are drawn.
	var found: Array = []
	if container == null:
		return found
	for child: Node in container.get_children():
		if child is OptionButton or child is Range or child is BaseButton or child is LineEdit:
			found.append(child)
		found.append_array(_focusable_controls(child))
	return found

func _unhandled_input(event: InputEvent) -> void:
	# The key or button a player pressed while a row was listening. Unhandled input is the right
	# place for it: a button press that reached a control belongs to that control, and the key the
	# player means for the binding is the one nothing else wanted.
	if _listening_action.is_empty() or _pending_event != null:
		return
	if not _is_binding_event(event) or not event.is_pressed():
		return
	if _device_of(event) != _listening_device:
		return
	get_viewport().set_input_as_handled()
	var taken_by: String = _action_bound_to(event, _listening_action)
	if taken_by.is_empty():
		_apply_binding(_listening_action, event)
		return
	_pending_event = event
	binding_conflict.emit(_listening_action, taken_by)

func _is_binding_event(event: InputEvent) -> bool:
	# The events worth binding: a key, a mouse button, a pad button. A stick is deliberately not one
	# - an axis is not a binding a player can press once, and pretending otherwise reads as a bug.
	return event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton

func _device_of(event: InputEvent) -> String:
	# Which column an event belongs in. Mouse buttons ride with the keyboard, which is where a player
	# looking for them expects to find them.
	return "pad" if event is InputEventJoypadButton else "keyboard"

func _action_bound_to(event: InputEvent, except_action: String) -> String:
	# The action that already answers to this event, if any other does. Asked through the Input Map
	# rather than by comparing events, so a key stored as a physical code and a key just pressed are
	# recognised as the same key.
	for action: String in project_actions():
		if action != except_action and InputMap.event_is_action(event, action):
			return action
	return ""

func _apply_binding(action: String, event: InputEvent) -> void:
	# Gives an action a binding, replacing whatever it had on that device and leaving the other
	# device alone - rebinding the key must not cost the pad button.
	var device: String = _device_of(event)
	for existing: InputEvent in InputMap.action_get_events(action):
		if _device_of(existing) == device:
			InputMap.action_erase_event(action, existing)
	InputMap.action_add_event(action, event)
	_listening_action = ""
	_listening_device = ""
	_pending_event = null
	binding_changed.emit(action)

func _event_words(event: InputEvent) -> String:
	# The words for one event: a key by the name on the key, everything else by the engine's own
	# reading of it. Nothing invents a table of pad button names the engine already keeps.
	if event == null:
		return ""
	if event is InputEventKey:
		var key: InputEventKey = event as InputEventKey
		return OS.get_keycode_string(key.keycode if key.keycode != KEY_NONE else key.physical_keycode)
	return event.as_text()

func _show_bindings(container: Node) -> void:
	# Writes what every binding button on a generated Controls page says. Kept private because it is
	# the page's own upkeep rather than a row anybody would write: the page asks for it once and then
	# it happens on every binding change, including the ones a swap makes to the OTHER control.
	if not is_instance_valid(container):
		return
	for action: String in project_actions():
		for device: String in ["keyboard", "pad"]:
			var button: Button = container.find_child("%s_%s" % [action, device], true, false) as Button
			if button == null:
				continue
			var words: String = key_binding_of(action) if device == "keyboard" else pad_binding_of(action)
			button.text = words if not words.is_empty() else "none"

## @ace_hidden
func save_state() -> Dictionary:
	# Save-state seam: the Save System walks any node in its persist group (or targeted
	# by Save/Load Node State) and duck-types these two methods. Plain data only.
	return {"values": _values.duplicate(true)}

## @ace_hidden
func load_state(state: Dictionary) -> void:
	if state.is_empty():
		return
	_values = (state.get("values", {}) as Dictionary).duplicate(true)

# Game Settings: register as the Settings autoload. Declare each setting once at startup, Load All Settings, then Apply All Settings - every reaction lives under On Setting Changed, branched by Changed Setting Is. Values persist in user://settings.cfg, section "settings" - the same file the built-in Save Setting writes to, so point that action at the "settings" section if you want the two to share values. This pack is an event sheet - extend it by editing it.
