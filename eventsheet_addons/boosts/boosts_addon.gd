## @ace_tags(incremental, idle, boost)
## @ace_category("Boosts")
## @ace_version(1.0.0)
@icon("res://eventsheet_addons/boosts/icon.svg")
class_name BoostAddon
extends Node
## Temporary, timed multipliers that count themselves down - the golden-cookie layer of an idle game. Start a named boost with a multiplier and a duration, fold Total Multiplier into your production, and On Boost Expired fires the instant it runs out.

## @ace_trigger
## @ace_name("On Boost Started")
## @ace_category("Boosts")
signal on_boost_started
## @ace_trigger
## @ace_name("On Boost Expired")
## @ace_category("Boosts")
signal on_boost_expired

# id -> {multiplier, remaining (seconds), tag}. Absent = inactive.
var _boosts: Dictionary = {}
# The boost that just ran out (read inside On Boost Expired).
var _last_expired_id: String = ""

func _process(delta: float) -> void:
	if _boosts.is_empty():
		return
	var expired: Array = []
	for id: String in _boosts.keys():
		var boost: Dictionary = _boosts[id]
		boost.remaining -= delta
		if boost.remaining <= 0.0:
			expired.append(id)
	for id: String in expired:
		# Re-check: an On Boost Expired handler processed earlier this frame may have restarted or
		# extended a boost still queued here - do not erase one that is live again.
		if _boosts.has(id) and _boosts[id].remaining <= 0.0:
			_boosts.erase(id)
			_last_expired_id = id
			on_boost_expired.emit()

## @ace_action
## @ace_featured
## @ace_name("Start Boost")
## @ace_category("Boosts")
## @ace_description("Starts (or restarts) a timed multiplier by id for `duration` seconds and fires On Boost Started.")
## @ace_icon("res://eventsheet_addons/boosts/icon.svg")
## @ace_codegen_template("Boost.start_boost({id}, {multiplier}, {duration})")
func start_boost(id: String, multiplier: float, duration: float) -> void:
	_boosts[id] = {"multiplier": multiplier, "remaining": maxf(duration, 0.0), "tag": ""}
	on_boost_started.emit()

## @ace_action
## @ace_name("Start Tagged Boost")
## @ace_category("Boosts")
## @ace_description("Like Start Boost, but with a tag so Multiplier For Tag can group it (e.g. "production", "click").")
## @ace_icon("res://eventsheet_addons/boosts/icon.svg")
## @ace_codegen_template("Boost.start_tagged_boost({id}, {multiplier}, {duration}, {tag})")
func start_tagged_boost(id: String, multiplier: float, duration: float, tag: String) -> void:
	_boosts[id] = {"multiplier": multiplier, "remaining": maxf(duration, 0.0), "tag": tag}
	on_boost_started.emit()

## @ace_action
## @ace_name("Extend Boost")
## @ace_category("Boosts")
## @ace_description("Adds seconds to an active boost's timer (does nothing if it is not active).")
## @ace_icon("res://eventsheet_addons/boosts/icon.svg")
## @ace_codegen_template("Boost.extend_boost({id}, {seconds})")
func extend_boost(id: String, seconds: float) -> void:
	if _boosts.has(id):
		_boosts[id].remaining += seconds

## @ace_action
## @ace_name("Stop Boost")
## @ace_category("Boosts")
## @ace_description("Ends a boost immediately (no On Boost Expired - that is for timers running out).")
## @ace_icon("res://eventsheet_addons/boosts/icon.svg")
## @ace_codegen_template("Boost.stop_boost({id})")
func stop_boost(id: String) -> void:
	if _boosts.has(id):
		_boosts.erase(id)

## @ace_action
## @ace_name("Clear Boosts")
## @ace_category("Boosts")
## @ace_description("Ends every active boost at once.")
## @ace_icon("res://eventsheet_addons/boosts/icon.svg")
## @ace_codegen_template("Boost.clear_boosts()")
func clear_boosts() -> void:
	_boosts.clear()

## @ace_condition
## @ace_name("Is Active")
## @ace_category("Boosts")
## @ace_description("Whether a boost with this id is currently running.")
## @ace_icon("res://eventsheet_addons/boosts/icon.svg")
## @ace_codegen_template("Boost.is_active({id})")
func is_active(id: String) -> bool:
	return _boosts.has(id)

## @ace_condition
## @ace_name("Any Active")
## @ace_category("Boosts")
## @ace_description("Whether any boost is currently running.")
## @ace_icon("res://eventsheet_addons/boosts/icon.svg")
## @ace_codegen_template("Boost.any_active()")
func any_active() -> bool:
	return not _boosts.is_empty()

## @ace_expression
## @ace_featured
## @ace_name("Total Multiplier")
## @ace_category("Boosts")
## @ace_description("The product of every active boost's multiplier (1.0 if none) - fold it into production.")
## @ace_icon("res://eventsheet_addons/boosts/icon.svg")
## @ace_codegen_template("Boost.total_multiplier()")
func total_multiplier() -> float:
	var product: float = 1.0
	for id: String in _boosts:
		product *= float(_boosts[id].multiplier)
	return product

## @ace_expression
## @ace_name("Multiplier For Tag")
## @ace_category("Boosts")
## @ace_description("The product of active boosts that share this tag (1.0 if none).")
## @ace_icon("res://eventsheet_addons/boosts/icon.svg")
## @ace_codegen_template("Boost.multiplier_for_tag({tag})")
func multiplier_for_tag(tag: String) -> float:
	var product: float = 1.0
	for id: String in _boosts:
		if str(_boosts[id].tag) == tag:
			product *= float(_boosts[id].multiplier)
	return product

## @ace_expression
## @ace_name("Multiplier Of")
## @ace_category("Boosts")
## @ace_description("One boost's multiplier (1.0 if it is not active).")
## @ace_icon("res://eventsheet_addons/boosts/icon.svg")
## @ace_codegen_template("Boost.multiplier_of({id})")
func multiplier_of(id: String) -> float:
	return float(_boosts[id].multiplier) if _boosts.has(id) else 1.0

## @ace_expression
## @ace_name("Time Left")
## @ace_category("Boosts")
## @ace_description("Seconds remaining on a boost (0 if not active) - for a countdown label.")
## @ace_icon("res://eventsheet_addons/boosts/icon.svg")
## @ace_codegen_template("Boost.time_left({id})")
func time_left(id: String) -> float:
	return maxf(float(_boosts[id].remaining), 0.0) if _boosts.has(id) else 0.0

## @ace_expression
## @ace_name("Active Count")
## @ace_category("Boosts")
## @ace_description("How many boosts are currently running.")
## @ace_icon("res://eventsheet_addons/boosts/icon.svg")
## @ace_codegen_template("Boost.active_count()")
func active_count() -> int:
	return _boosts.size()

## @ace_expression
## @ace_name("Last Expired")
## @ace_category("Boosts")
## @ace_description("The id of the boost that just ran out (read inside On Boost Expired).")
## @ace_icon("res://eventsheet_addons/boosts/icon.svg")
## @ace_codegen_template("Boost.last_expired()")
func last_expired() -> String:
	return _last_expired_id

## @ace_hidden
func save_state() -> Dictionary:
	# Save-state seam: the Save System walks any node in its persist group (or targeted
	# by Save/Load Node State) and duck-types these two methods. Plain data only.
	# Each entry carries its own `remaining` seconds, so restored boosts resume mid-countdown.
	return {
		"boosts": _boosts.duplicate(true)
	}

## @ace_hidden
func load_state(state: Dictionary) -> void:
	if state.is_empty():
		return
	_boosts = (state.get("boosts", {}) as Dictionary).duplicate(true)

# Boosts: register as the Boost autoload. Start Boost(id, multiplier, duration) begins a timed multiplier that counts itself down and fires On Boost Expired when it ends. Total Multiplier multiplies every active boost together; Multiplier For Tag narrows it to a group. Fold Total Multiplier into your production alongside prestige and upgrade multipliers. This pack is an event sheet - extend it by editing it.
