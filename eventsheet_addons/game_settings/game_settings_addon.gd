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

## @ace_action
## @ace_featured
## @ace_name("Declare Setting")
## @ace_category("Settings")
## @ace_description("Names a setting once: what it is called, what it defaults to, what kind of value it is, and (for a Choice) its options. Everything else in this pack reads that declaration, so the default is written in one place instead of at five call sites. Declaring the same name again replaces the declaration and keeps any value already set.")
## @ace_display_template("Declare setting [b]{setting_name}[/b] default [b]{default_value}[/b] kind [b]{kind}[/b]")
## @ace_param_options(kind percent=Percent (0-100 slider), toggle=Yes/No, choice=Choice, number=Number, text=Text)
## @ace_icon("res://eventsheet_addons/game_settings/icon.svg")
## @ace_codegen_template("Settings.declare_setting({setting_name}, {default_value}, {kind}, {choices})")
func declare_setting(setting_name: String, default_value: Variant, kind: String = "percent", choices: String = "") -> void:
	_declared[setting_name] = {"default": default_value, "kind": kind, "choices": choices}

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

func _announce(setting_name: String, value: Variant) -> void:
	# Fires the trigger for one setting and keeps the announcing stack honest while handlers run.
	_announcing.append(setting_name)
	_last_announced = setting_name
	setting_changed.emit(setting_name, value)
	_announcing.pop_back()

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
