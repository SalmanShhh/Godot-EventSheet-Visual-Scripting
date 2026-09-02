# Pack source - weapon_kit. The behaviour code this pack ships, as real GDScript: highlighted,
# checked and breakpointable here, and assembled into the pack by Lib.pack_from_source.
# Every #region, and the body of every top-level func, is one piece of the sheet; everything
# else is scaffolding the pack declares for itself at build time and never reads from here.
extends Node2D

var host: Node2D = null

var max_ammo
var current_ammo
var reserve_ammo
var fire_rate
var reload_time
var fire_mode
var burst_count
var auto_reload
var infinite_reserve
var _cooldown
var _reloading
var _reload_timer
var _burst_left

#region block_1
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

func can_fire() -> bool:
	return not _reloading and _cooldown <= 0.0 and current_ammo > 0 and _burst_left <= 0

func has_ammo() -> bool:
	return current_ammo > 0

## @ace_condition
## @ace_name("Is Full")
func is_full() -> bool:
	return current_ammo >= max_ammo

## @ace_condition
## @ace_name("Is Reloading")
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

# One round leaves the barrel: spend ammo, start the cooldown, trigger On Fire, and
# fall through to empty/auto-reload when the magazine runs dry.
func _fire_one() -> void:
	current_ammo -= 1
	_cooldown = 1.0 / maxf(fire_rate, 0.01)
	# A cooldown is a clock, so the tick comes back on to run it down.
	set_process(true)
	fired.emit()
	if current_ammo <= 0:
		_burst_left = 0
		emptied.emit()
		if auto_reload:
			reload()

# Move rounds from the reserve into the magazine (capped by reserve unless infinite).
func _complete_reload() -> void:
	var needed: int = max_ammo - current_ammo
	var taken: int = needed if infinite_reserve else mini(needed, reserve_ammo)
	current_ammo += taken
	if not infinite_reserve:
		reserve_ammo -= taken
	_reloading = false
	_reload_timer = 0.0
	reload_completed.emit()

# Whether anything is still on a clock. A holstered weapon - off cooldown, not reloading,
# no burst queued - has nothing to count down, so it should not cost a frame.
func _weapon_is_busy() -> bool:
	return _cooldown > 0.0 or _reloading or _burst_left > 0
#endregion

func _ready() -> void:
	# A weapon that has not been fired or reloaded has no cooldown, no reload and no burst
	# to advance; Fire and Reload turn the tick back on the moment there is one.
	set_process(false)

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
	# Asked LAST, so a shot or reload started by an On Fire / On Reload Complete handler this
	# very frame keeps the tick alive: once no clock is running, it switches itself off.
	set_process(_weapon_is_busy())

#region block_2
# Save-state seam: the Save System walks any node in its persist group (or targeted
# by Save/Load Node State) and duck-types these two methods. Plain data only.
# Transient combat state (_cooldown, _reloading, _burst_left) is deliberately skipped.
## @ace_hidden
func save_state() -> Dictionary:
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
#endregion

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

func reload() -> void:
	if _reloading or current_ammo >= max_ammo:
		return
	if not infinite_reserve and reserve_ammo <= 0:
		return
	_reloading = true
	_reload_timer = reload_time
	_burst_left = 0
	# A reload is a clock, so the tick comes back on to run it down.
	set_process(true)
	reload_started.emit()

func cancel_reload() -> void:
	_reloading = false
	_reload_timer = 0.0

func instant_reload() -> void:
	_reloading = false
	_complete_reload()

func add_ammo(amount: int) -> void:
	current_ammo = mini(current_ammo + amount, max_ammo)

func add_reserve(amount: int) -> void:
	reserve_ammo += amount

func set_fire_rate(rate: float) -> void:
	fire_rate = rate

func set_fire_mode(mode: int) -> void:
	fire_mode = mode

func set_max_ammo(size: int) -> void:
	max_ammo = maxi(size, 0)
