## @ace_tags(combat, shooter)
## @ace_category("Weapon")
## @ace_expose_all(node)
@icon("res://eventsheet_addons/weapon_kit/icon.svg")
class_name WeaponKit
extends Node

## The node this behavior acts on (its parent). Required host: Node2D.
var host: Node2D = null

func _enter_tree() -> void:
	host = get_parent() as Node2D
	if host == null:
		push_warning("WeaponKit behavior requires a Node2D parent.")

## @ace_trigger
## @ace_name("On Fire")
signal fired
## @ace_trigger
## @ace_name("On Empty")
signal emptied
## @ace_trigger
signal reload_started
## @ace_trigger
## @ace_name("On Reload Complete")
signal reload_completed

var _burst_left: int = 0
var _cooldown: float = 0.0
var _reload_timer: float = 0.0
var _reloading: bool = false
## Reload automatically when the magazine runs dry.
@export var auto_reload: bool = true
## Shots per burst when fire_mode = 2.
@export var burst_count: int = 3
## Rounds loaded right now (set to your magazine size to start full).
@export var current_ammo: int = 12
## 0 = single, 1 = auto (both cooldown-gated), 2 = burst.
@export var fire_mode: int = 0
## Shots per second (the cooldown between shots is 1 / fire_rate).
@export var fire_rate: float = 8.0
## Reloads never spend reserve ammo.
@export var infinite_reserve: bool = false
## Magazine size (rounds before a reload).
@export var max_ammo: int = 12
## Seconds a reload takes.
@export var reload_time: float = 1.2
## Spare rounds a reload draws from.
@export var reserve_ammo: int = 96

func _process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	if _reloading:
		_reload_timer = maxf(_reload_timer - delta, 0.0)
		if _reload_timer <= 0.0:
			_complete_reload()
	elif _burst_left > 0 and _cooldown <= 0.0:
		if current_ammo > 0:
			_burst_left -= 1
			_fire_one()
		else:
			_burst_left = 0

## @ace_action
## @ace_name("Fire")
## @ace_category("Weapon")
## @ace_description("Fires if ready (not reloading, off cooldown, has ammo). In burst mode it kicks off a burst; if the magazine is empty it triggers On Empty (and auto-reloads when enabled).")
## @ace_icon("res://eventsheet_addons/weapon_kit/icon.svg")
## @ace_codegen_template("$WeaponKit.fire()")
func fire() -> void:
	if _reloading or _cooldown > 0.0 or _burst_left > 0:
		return
	if current_ammo <= 0:
		emptied.emit()
		if auto_reload:
			reload()
		return
	if fire_mode == 2:
		_burst_left = maxi(burst_count, 1)
		_burst_left -= 1
	_fire_one()

## @ace_action
## @ace_name("Reload")
## @ace_category("Weapon")
## @ace_description("Starts a timed reload (if not full and reserve has rounds).")
## @ace_icon("res://eventsheet_addons/weapon_kit/icon.svg")
## @ace_codegen_template("$WeaponKit.reload()")
func reload() -> void:
	if _reloading or current_ammo >= max_ammo:
		return
	if not infinite_reserve and reserve_ammo <= 0:
		return
	_reloading = true
	_reload_timer = reload_time
	_burst_left = 0
	reload_started.emit()

## @ace_action
## @ace_name("Cancel Reload")
## @ace_category("Weapon")
## @ace_description("Aborts an in-progress reload (no ammo gained).")
## @ace_icon("res://eventsheet_addons/weapon_kit/icon.svg")
## @ace_codegen_template("$WeaponKit.cancel_reload()")
func cancel_reload() -> void:
	_reloading = false
	_reload_timer = 0.0

## @ace_action
## @ace_name("Instant Reload")
## @ace_category("Weapon")
## @ace_description("Refills the magazine immediately (no reload time).")
## @ace_icon("res://eventsheet_addons/weapon_kit/icon.svg")
## @ace_codegen_template("$WeaponKit.instant_reload()")
func instant_reload() -> void:
	_reloading = false
	_complete_reload()

## @ace_action
## @ace_name("Add Ammo")
## @ace_category("Weapon")
## @ace_description("Adds rounds straight to the magazine (capped at the magazine size).")
## @ace_icon("res://eventsheet_addons/weapon_kit/icon.svg")
## @ace_codegen_template("$WeaponKit.add_ammo({amount})")
func add_ammo(amount: int) -> void:
	current_ammo = mini(current_ammo + amount, max_ammo)

## @ace_action
## @ace_name("Add Reserve Ammo")
## @ace_category("Weapon")
## @ace_description("Adds spare rounds to the reserve pool (e.g. an ammo pickup).")
## @ace_icon("res://eventsheet_addons/weapon_kit/icon.svg")
## @ace_codegen_template("$WeaponKit.add_reserve({amount})")
func add_reserve(amount: int) -> void:
	reserve_ammo += amount

## @ace_action
## @ace_name("Set Fire Rate")
## @ace_category("Weapon")
## @ace_description("Changes the shots-per-second.")
## @ace_icon("res://eventsheet_addons/weapon_kit/icon.svg")
## @ace_codegen_template("$WeaponKit.set_fire_rate({rate})")
func set_fire_rate(rate: float) -> void:
	fire_rate = rate

## @ace_action
## @ace_name("Set Fire Mode")
## @ace_category("Weapon")
## @ace_description("0 = single, 1 = auto, 2 = burst.")
## @ace_icon("res://eventsheet_addons/weapon_kit/icon.svg")
## @ace_codegen_template("$WeaponKit.set_fire_mode({mode})")
func set_fire_mode(mode: int) -> void:
	fire_mode = mode

## @ace_action
## @ace_name("Set Magazine Size")
## @ace_category("Weapon")
## @ace_description("Changes the magazine size.")
## @ace_icon("res://eventsheet_addons/weapon_kit/icon.svg")
## @ace_codegen_template("$WeaponKit.set_max_ammo({size})")
func set_max_ammo(size: int) -> void:
	max_ammo = maxi(size, 0)

func can_fire() -> bool:
	return not _reloading and _cooldown <= 0.0 and current_ammo > 0 and _burst_left <= 0

func has_ammo() -> bool:
	return current_ammo > 0

## @ace_condition
## @ace_name("Is Full")
## @ace_icon("res://eventsheet_addons/weapon_kit/icon.svg")
## @ace_codegen_template("$WeaponKit.is_full()")
func is_full() -> bool:
	return current_ammo >= max_ammo

## @ace_condition
## @ace_name("Is Reloading")
## @ace_icon("res://eventsheet_addons/weapon_kit/icon.svg")
## @ace_codegen_template("$WeaponKit.is_reloading()")
func is_reloading() -> bool:
	return _reloading

func ammo_percent() -> float:
	return (float(current_ammo) / float(maxi(max_ammo, 1))) * 100.0

func reload_progress() -> float:
	if not _reloading:
		return 1.0
	return clampf(1.0 - _reload_timer / maxf(reload_time, 0.01), 0.0, 1.0)

func cooldown_progress() -> float:
	return clampf(1.0 - _cooldown * maxf(fire_rate, 0.01), 0.0, 1.0)

func _fire_one() -> void:
	# One round leaves the barrel: spend ammo, start the cooldown, trigger On Fire, and
	# fall through to empty/auto-reload when the magazine runs dry.
	current_ammo -= 1
	_cooldown = 1.0 / maxf(fire_rate, 0.01)
	fired.emit()
	if current_ammo <= 0:
		_burst_left = 0
		emptied.emit()
		if auto_reload:
			reload()

func _complete_reload() -> void:
	# Move rounds from the reserve into the magazine (capped by reserve unless infinite).
	var needed: int = max_ammo - current_ammo
	var taken: int = needed if infinite_reserve else mini(needed, reserve_ammo)
	current_ammo += taken
	if not infinite_reserve:
		reserve_ammo -= taken
	_reloading = false
	_reload_timer = 0.0
	reload_completed.emit()

## @ace_hidden
func save_state() -> Dictionary:
	# Save-state seam: the Save System walks any node in its persist group (or targeted
	# by Save/Load Node State) and duck-types these two methods. Plain data only.
	# Transient combat state (_cooldown, _reloading, _burst_left) is deliberately skipped.
	return {
		"ammo": current_ammo,
		"reserve": reserve_ammo
	}

## @ace_hidden
func load_state(state: Dictionary) -> void:
	if state.is_empty():
		return
	current_ammo = int(state.get("ammo", 12))
	reserve_ammo = int(state.get("reserve", 96))

# Weapon Kit: ammo + reserve, fire-rate cooldown, single/auto/burst modes, and timed/instant reload. Call Fire (it manages ammo + cooldown and triggers On Fire - you spawn the bullet); call Reload. Read Ammo %, Reload Progress, etc. for HUD.
