## @ace_tags(movement, skateboard, momentum, grind)
## @ace_category("Skateboard")
## @ace_expose_all(node)
## @ace_version(1.0.0)
@icon("res://eventsheet_addons/skateboard/icon.svg")
class_name SkateboardMovement
extends Node
## Momentum movement for a CharacterBody2D on a board: one Push nudges you toward the top speed and you keep it, Roll With The Slope projects gravity along the floor so halfpipes and ramps work, Ollie leaves the ground, Spin and Flip turn in the air, and touching down either lands clean or bails depending on how square the board is with the floor. Grinds snap to any Path2D rail and ride it, and a trick chain multiplies everything you land without touching down.

## The node this behavior acts on (its parent). Required host: CharacterBody2D.
var host: CharacterBody2D = null

func _enter_tree() -> void:
	host = get_parent() as CharacterBody2D
	if host == null:
		push_warning("SkateboardMovement behavior requires a CharacterBody2D parent.")

## @ace_trigger
## @ace_name("On Ollie")
## @ace_category("Skateboard")
signal ollied
## @ace_trigger
## @ace_name("On Landed Clean")
## @ace_category("Skateboard")
signal landed_clean
## @ace_trigger
## @ace_name("On Bailed")
## @ace_category("Skateboard")
signal bailed
## @ace_trigger
## @ace_name("On Trick Done")
## @ace_category("Skateboard")
signal trick_done(trick: String, points: float)

## How much speed one push adds toward the top speed (px/s). A board keeps it - there is no per-tick acceleration here.
@export var push_speed: float = 40.0
## The fastest a push will take you (px/s). A slope can still carry you past it.
@export var max_speed: float = 600.0
## Upward speed an ollie gives you (px/s).
@export var ollie_speed: float = 420.0
## Downward acceleration (px/s²). Roll With The Slope projects this along the floor.
@export var gravity: float = 980.0
## Terminal velocity - gravity never pulls you down faster than this.
@export var max_fall_speed: float = 1200.0
## Rolling friction on the ground (px/s²). Low, because a board coasts.
@export var friction: float = 60.0
## How much of gravity the slope hands you. 1 is a real ramp, above 1 exaggerates it, 0 makes hills flat.
@export_range(0, 3, 0.05) var slope_grip: float = 1.0
## How quickly the board settles flat onto the slope it is rolling on, in radians per second. It only does this when no trick is turning, so a spin is never fought.
@export var align_speed: float = 12.0
## Default turns per second a Spin or Flip trick turns at.
@export var trick_spin_rate: float = 1.0
## How far off square with the floor the board may be and still land clean. Wider is friendlier.
@export_range(1, 90, 1) var landing_tolerance_degrees: float = 25.0
## Default speed along a rail (px/s) when a grind is not keeping your momentum.
@export var grind_speed: float = 320.0
## How close to the rail's line the board has to be for Is Near Rail to say yes (px).
@export var rail_snap_distance: float = 12.0
## Upward speed a hop off a rail gives you (px/s).
@export var hop_off_speed: float = 260.0
## How fast balance slides toward the edge per second while you are balancing. 0 is a free ride.
@export var balance_drift: float = 0.8
## How hard one full steer pushes balance back toward the middle, per second.
@export var balance_steer: float = 1.6
## How far out balance has to be before Is Losing Balance says yes. 1 is the bail.
@export_range(0, 1, 0.05) var balance_warn: float = 0.6
var _manual: bool = false
var _grinding: bool = false
var _zipline: bool = false
var _zip_speed: float = 0.0
var _rail_offset: float = 0.0
var _grind_direction: float = 1.0
var _balancing: bool = false
var _balance: float = 0.0
var _chain_score: float = 0.0
var _chain_multiplier: int = 1
var _banked_score: float = 0.0
var _spin_turns: float = 0.0
var _was_on_floor: bool = false

# The rail this board is riding. Start Grinding remembers it so the riding rows do not
# have to name it again, and Hop Off / a bail forget it.
var _rail: Node2D = null
# The rail's curve, or null when the remembered rail is gone, is not a Path2D, or carries
# a curve too short to sample. Every grind row goes through this, so a rail deleted mid-ride
# stops the grind instead of faulting.
## @ace_hidden
func _rail_curve() -> Curve2D:
	if _rail == null or not is_instance_valid(_rail) or not _rail is Path2D:
		return null
	var curve: Curve2D = (_rail as Path2D).curve
	if curve == null or curve.point_count < 2:
		return null
	return curve

func _physics_process(delta: float) -> void:
	if host == null:
		return
	if _grinding:
		# A grind owns the position outright, so gravity, friction and the touchdown edge all
		# stand down until Hop Off or a bail hands the board back.
		_was_on_floor = false
	else:
		var on_floor: bool = host.is_on_floor()
		if on_floor:
			host.velocity.x = move_toward(host.velocity.x, 0.0, friction * delta)
		else:
			host.velocity.y = minf(host.velocity.y + gravity * delta, max_fall_speed)
		if on_floor and not _was_on_floor:
			_judge_landing()
		if on_floor and is_zero_approx(_spin_turns):
			# Rolling settles the board flat onto whatever it is on, which is what makes leaving a
			# ramp leave it at the ramp's angle. Never while a trick is turning - the trick owns the
			# rotation until it is landed.
			host.rotation = rotate_toward(host.rotation, _floor_angle(), align_speed * delta)
		_was_on_floor = on_floor
	if _balancing:
		# Balance never sits still: it leans further the way it is already going, which is what
		# makes a long manual a held breath rather than a free ride.
		var lean: float = 1.0 if _balance >= 0.0 else -1.0
		_balance = clampf(_balance + lean * balance_drift * delta, -1.5, 1.5)
		if absf(_balance) >= 1.0:
			bail()
	if not _grinding:
		host.move_and_slide()

## @ace_action
## @ace_featured
## @ace_name("Push")
## @ace_category("Skateboard")
## @ace_description("One kick: nudges the board toward its top speed in the direction it is already going, and the board keeps it. Unlike a platformer's acceleration this is a one-shot gain, so pushing twice is faster than pushing once and holding nothing is still fast.")
## @ace_display_template("Push toward [b]max speed[/b] by [b]{amount}[/b]")
## @ace_icon("res://eventsheet_addons/skateboard/icon.svg")
## @ace_codegen_template("$SkateboardMovement.push({amount})")
func push(amount: float) -> void:
	if host == null:
		return
	var facing: float = signf(host.velocity.x)
	if is_zero_approx(facing):
		facing = 1.0
	host.velocity.x = move_toward(host.velocity.x, max_speed * facing, amount)

## @ace_action
## @ace_featured
## @ace_name("Roll With The Slope")
## @ace_category("Skateboard")
## @ace_description("Projects gravity along the floor the board is standing on, so a downhill gains speed and an uphill loses it. This one row is what makes ramps, bowls and halfpipes work - call it every physics tick while on the floor.")
## @ace_display_template("Roll with the slope [i]gravity along the floor[/i]")
## @ace_icon("res://eventsheet_addons/skateboard/icon.svg")
## @ace_codegen_template("$SkateboardMovement.roll_with_slope()")
func roll_with_slope() -> void:
	if host == null or not host.is_on_floor():
		return
	host.velocity.x += host.get_floor_normal().x * gravity * slope_grip * get_physics_process_delta_time()

## @ace_action
## @ace_featured
## @ace_name("Ollie")
## @ace_category("Skateboard")
## @ace_description("Pops the board off the ground at the given speed and starts a fresh spin count, then fires On Ollie. Whatever horizontal speed the board had, it keeps.")
## @ace_display_template("[b]Ollie[/b] at [b]{strength}[/b]")
## @ace_icon("res://eventsheet_addons/skateboard/icon.svg")
## @ace_codegen_template("$SkateboardMovement.ollie({strength})")
func ollie(strength: float) -> void:
	if host == null:
		return
	host.velocity.y = -strength
	_spin_turns = 0.0
	_manual = false
	ollied.emit()

## @ace_action
## @ace_name("Manual")
## @ace_category("Skateboard")
## @ace_description("Tips the board onto its back wheels and starts the balance meter drifting. Hold it with Steer The Balance; let it reach an edge and the board bails.")
## @ace_display_template("Ride a [b]manual[/b]")
## @ace_icon("res://eventsheet_addons/skateboard/icon.svg")
## @ace_codegen_template("$SkateboardMovement.manual()")
func manual() -> void:
	_manual = true
	start_balancing(balance_drift)

## @ace_action
## @ace_name("Stop The Manual")
## @ace_category("Skateboard")
## @ace_description("Sets the board back down on all four wheels and stops the balance meter. Nothing is scored and nothing is lost - use Bank The Chain first if the manual was worth points.")
## @ace_display_template("[b]Stop[/b] the manual")
## @ace_icon("res://eventsheet_addons/skateboard/icon.svg")
## @ace_codegen_template("$SkateboardMovement.stop_manual()")
func stop_manual() -> void:
	_manual = false
	_balancing = false
	_balance = 0.0

## @ace_action
## @ace_name("Brake")
## @ace_category("Skateboard")
## @ace_description("Drags speed off the board toward a standstill, by the given amount this call. Foot down.")
## @ace_display_template("[b]Brake[/b] by [b]{amount}[/b]")
## @ace_icon("res://eventsheet_addons/skateboard/icon.svg")
## @ace_codegen_template("$SkateboardMovement.brake({amount})")
func brake(amount: float) -> void:
	if host == null:
		return
	host.velocity.x = move_toward(host.velocity.x, 0.0, amount)

## @ace_action
## @ace_name("Reverse")
## @ace_category("Skateboard")
## @ace_description("Turns the board around and rolls the way it came, keeping the speed it had. A fakie out of a bowl is this row.")
## @ace_display_template("[b]Reverse[/b] the roll")
## @ace_icon("res://eventsheet_addons/skateboard/icon.svg")
## @ace_codegen_template("$SkateboardMovement.reverse()")
func reverse() -> void:
	if host == null:
		return
	host.velocity.x = -host.velocity.x

## @ace_action
## @ace_name("Spin Trick")
## @ace_category("Skateboard")
## @ace_description("Turns the board through the air at the given turns per second and counts the turns as it goes. Nothing happens on the ground - a spin is an air row.")
## @ace_display_template("[b]Spin[/b] [b]{turns}[/b] turn per second")
## @ace_icon("res://eventsheet_addons/skateboard/icon.svg")
## @ace_codegen_template("$SkateboardMovement.spin_trick({turns})")
func spin_trick(turns: float) -> void:
	if host == null or host.is_on_floor() or _grinding:
		return
	var step: float = turns * TAU * get_physics_process_delta_time()
	host.rotation += step
	_spin_turns += absf(step) / TAU

## @ace_action
## @ace_name("Flip Trick")
## @ace_category("Skateboard")
## @ace_description("The same turn the other way, so a sheet can tell a spin and a flip apart on the canvas and in the chain. Nothing happens on the ground.")
## @ace_display_template("[b]Flip[/b] [b]{turns}[/b] turn per second")
## @ace_icon("res://eventsheet_addons/skateboard/icon.svg")
## @ace_codegen_template("$SkateboardMovement.flip_trick({turns})")
func flip_trick(turns: float) -> void:
	if host == null or host.is_on_floor() or _grinding:
		return
	var step: float = turns * TAU * get_physics_process_delta_time()
	host.rotation -= step
	_spin_turns += absf(step) / TAU

## @ace_action
## @ace_name("Land The Trick")
## @ace_category("Skateboard")
## @ace_description("Judges the landing now instead of waiting for the board to touch down: square enough with the floor and it snaps flat and fires On Landed Clean, crookeder than the tolerance and it bails. The tick calls this for you on every touchdown, so you only need it to end a grind or a scripted landing.")
## @ace_display_template("[b]Land[/b] the trick")
## @ace_icon("res://eventsheet_addons/skateboard/icon.svg")
## @ace_codegen_template("$SkateboardMovement.land_trick()")
func land_trick() -> void:
	_judge_landing()

## @ace_action
## @ace_name("Bail")
## @ace_category("Skateboard")
## @ace_description("Wipes out: the manual, the grind and the balance meter all stop, the trick chain is dropped, and On Bailed fires. This is where a ragdoll, a stumble animation, or a checkpoint respawn hangs.")
## @ace_display_template("[b]Bail[/b]")
## @ace_icon("res://eventsheet_addons/skateboard/icon.svg")
## @ace_codegen_template("$SkateboardMovement.bail()")
func bail() -> void:
	_manual = false
	_grinding = false
	_zipline = false
	_rail = null
	_balancing = false
	_balance = 0.0
	_spin_turns = 0.0
	drop_chain()
	bailed.emit()

## @ace_action
## @ace_name("Add To Chain")
## @ace_category("Skateboard")
## @ace_description("Scores a trick into the chain running right now: the points are multiplied by the current multiplier, then the multiplier climbs by one. Fires On Trick Done with the name and what it actually scored. Nothing is safe until the chain is banked.")
## @ace_display_template("Add trick [b]{trick}[/b] to the chain for [b]{points}[/b]")
## @ace_icon("res://eventsheet_addons/skateboard/icon.svg")
## @ace_codegen_template("$SkateboardMovement.add_to_chain({trick}, {points})")
func add_to_chain(trick: String, points: float) -> void:
	var scored: float = points * float(_chain_multiplier)
	_chain_score += scored
	_chain_multiplier += 1
	trick_done.emit(trick, scored)

## @ace_action
## @ace_name("Bank Chain")
## @ace_category("Skateboard")
## @ace_description("Cashes the chain in: everything it is worth moves into the banked total and the multiplier goes back to one. This is the clean landing's reward.")
## @ace_display_template("[b]Bank[/b] the chain")
## @ace_icon("res://eventsheet_addons/skateboard/icon.svg")
## @ace_codegen_template("$SkateboardMovement.bank_chain()")
func bank_chain() -> void:
	_banked_score += _chain_score
	_chain_score = 0.0
	_chain_multiplier = 1

## @ace_action
## @ace_name("Drop Chain")
## @ace_category("Skateboard")
## @ace_description("Throws the running chain away and puts the multiplier back to one. The banked total is untouched - this is what a bail costs you.")
## @ace_display_template("[b]Drop[/b] the chain")
## @ace_icon("res://eventsheet_addons/skateboard/icon.svg")
## @ace_codegen_template("$SkateboardMovement.drop_chain()")
func drop_chain() -> void:
	_chain_score = 0.0
	_chain_multiplier = 1

## @ace_action
## @ace_name("Start Balancing")
## @ace_category("Skateboard")
## @ace_description("Puts the balance meter at dead centre and starts it drifting at the given speed per second. Steer it back with Steer The Balance; let it reach either edge and the board bails.")
## @ace_display_template("[b]Start balancing[/b], drifting at [b]{drift}[/b]")
## @ace_icon("res://eventsheet_addons/skateboard/icon.svg")
## @ace_codegen_template("$SkateboardMovement.start_balancing({drift})")
func start_balancing(drift: float) -> void:
	balance_drift = drift
	_balance = 0.0
	_balancing = true

## @ace_action
## @ace_name("Steer The Balance")
## @ace_category("Skateboard")
## @ace_description("Pushes balance back toward the middle by the steer strength times this amount. Feed it the left/right axis: -1 leans one way, 1 the other, 0 lets the drift have it.")
## @ace_display_template("[b]Steer[/b] the balance by [b]{amount}[/b]")
## @ace_icon("res://eventsheet_addons/skateboard/icon.svg")
## @ace_codegen_template("$SkateboardMovement.steer_balance({amount})")
func steer_balance(amount: float) -> void:
	if not _balancing:
		return
	_balance = clampf(_balance - amount * balance_steer * get_physics_process_delta_time(), -1.5, 1.5)

## @ace_condition
## @ace_name("Is Near Rail")
## @ace_category("Grind")
## @ace_description("True when the board is within the given distance of the nearest point on the rail's curve. This is the whole of what "near a rail" means - the closest offset on the curve, and how far off it you are.")
## @ace_display_template("Is near rail [i]{rail}[/i] within [b]{distance}[/b] px")
## @ace_icon("res://eventsheet_addons/skateboard/icon.svg")
## @ace_codegen_template("$SkateboardMovement.is_near_rail({rail}, {distance})")
func is_near_rail(rail: Node2D, distance: float) -> bool:
	var found: Dictionary = _closest_on_rail(rail)
	if found.is_empty():
		return false
	return host.global_position.distance_to(found["point"]) < distance

## @ace_action
## @ace_name("Start Grinding")
## @ace_category("Grind")
## @ace_description("Locks the board onto the rail at the nearest point on its curve and starts riding, in whichever direction the board was already travelling. The balance meter starts with it, so a long rail is a held breath.")
## @ace_display_template("[b]Start grinding[/b] [i]{rail}[/i]")
## @ace_icon("res://eventsheet_addons/skateboard/icon.svg")
## @ace_codegen_template("$SkateboardMovement.start_grinding({rail})")
func start_grinding(rail: Node2D) -> void:
	var found: Dictionary = _closest_on_rail(rail)
	if found.is_empty():
		return
	_rail = rail
	_rail_offset = float(found["offset"])
	_grind_direction = 1.0 if host.velocity.x >= 0.0 else -1.0
	_grinding = true
	_zipline = false
	host.global_position = found["point"]
	start_balancing(balance_drift)

## @ace_action
## @ace_name("Grind Along Rail")
## @ace_category("Grind")
## @ace_description("Rides one tick further along the rail and puts the board on the curve, facing the way the rail runs. Keep Momentum rides at whatever speed the board arrived with instead of the given speed - a fast approach is a fast grind.")
## @ace_display_template("[b]Grind[/b] along the rail at [b]{speed}[/b]")
## @ace_icon("res://eventsheet_addons/skateboard/icon.svg")
## @ace_codegen_template("$SkateboardMovement.grind_along_rail({speed}, {keep_momentum})")
func grind_along_rail(speed: float, keep_momentum: bool) -> void:
	if host == null or not _grinding:
		return
	var curve: Curve2D = _rail_curve()
	if curve == null:
		hop_off(0.0)
		return
	var travel: float = speed
	if keep_momentum:
		travel = maxf(host.velocity.length(), 1.0)
	if _zipline:
		travel = _zip_speed
	var length: float = curve.get_baked_length()
	_rail_offset = clampf(_rail_offset + travel * _grind_direction * get_physics_process_delta_time(), 0.0, length)
	var here: Vector2 = _rail.to_global(curve.sample_baked(_rail_offset))
	var ahead: Vector2 = _rail.to_global(curve.sample_baked(clampf(_rail_offset + 4.0 * _grind_direction, 0.0, length)))
	var along: Vector2 = ahead - here
	if not along.is_zero_approx():
		host.velocity = along.normalized() * travel
		host.rotation = along.angle()
	if _zipline:
		# A zipline is a rail you do not push along: the line's own slope feeds it, so the
		# steeper the run the faster you go.
		_zip_speed = minf(_zip_speed + gravity * absf(along.normalized().y) * get_physics_process_delta_time(), max_fall_speed)
	host.global_position = here

## @ace_action
## @ace_name("Hop Off")
## @ace_category("Grind")
## @ace_description("Lets the rail go and gives the board an upward kick, keeping whatever speed the grind had built along the line. The balance meter stops with it.")
## @ace_display_template("[b]Hop off[/b] the rail at [b]{hop}[/b]")
## @ace_icon("res://eventsheet_addons/skateboard/icon.svg")
## @ace_codegen_template("$SkateboardMovement.hop_off({hop})")
func hop_off(hop: float) -> void:
	_grinding = false
	_zipline = false
	_rail = null
	_balancing = false
	_balance = 0.0
	if host == null:
		return
	host.velocity.y -= hop
	_was_on_floor = false

## @ace_action
## @ace_name("Ride Zipline")
## @ace_category("Grind")
## @ace_description("The same lock-on as a grind, but the line's slope drives the speed instead of a knob: a steep zipline accelerates, a level one coasts. Hop Off ends it exactly the same way.")
## @ace_display_template("[b]Ride[/b] the zipline [i]{rail}[/i]")
## @ace_icon("res://eventsheet_addons/skateboard/icon.svg")
## @ace_codegen_template("$SkateboardMovement.ride_zipline({rail})")
func ride_zipline(rail: Node2D) -> void:
	start_grinding(rail)
	if not _grinding:
		return
	_zipline = true
	_zip_speed = maxf(host.velocity.length(), 20.0)

## @ace_condition
## @ace_name("Is Rolling")
## @ace_category("Skateboard")
## @ace_description("True while the board is on the ground and actually moving.")
## @ace_icon("res://eventsheet_addons/skateboard/icon.svg")
## @ace_codegen_template("$SkateboardMovement.is_rolling()")
func is_rolling() -> bool:
	return host != null and host.is_on_floor() and absf(host.velocity.x) > 1.0

## @ace_condition
## @ace_name("Is Airborne")
## @ace_category("Skateboard")
## @ace_description("True while the board is off the ground and not on a rail - the window every trick lives in.")
## @ace_icon("res://eventsheet_addons/skateboard/icon.svg")
## @ace_codegen_template("$SkateboardMovement.is_airborne()")
func is_airborne() -> bool:
	return host != null and not host.is_on_floor() and not _grinding

## @ace_condition
## @ace_name("Is In A Manual")
## @ace_category("Skateboard")
## @ace_description("True while the board is riding on its back wheels.")
## @ace_icon("res://eventsheet_addons/skateboard/icon.svg")
## @ace_codegen_template("$SkateboardMovement.is_in_a_manual()")
func is_in_a_manual() -> bool:
	return _manual

## @ace_condition
## @ace_name("Is Losing Balance")
## @ace_category("Skateboard")
## @ace_description("True while balance has drifted past the warning mark and has not been steered back. This is the row a HUD needle flashes on.")
## @ace_icon("res://eventsheet_addons/skateboard/icon.svg")
## @ace_codegen_template("$SkateboardMovement.is_losing_balance()")
func is_losing_balance() -> bool:
	return _balancing and absf(_balance) >= balance_warn

## @ace_expression
## @ace_name("Balance")
## @ace_category("Skateboard")
## @ace_description("Where balance sits, from -1 (fallen one way) through 0 (dead centre) to 1 (fallen the other). A needle reads this straight.")
## @ace_icon("res://eventsheet_addons/skateboard/icon.svg")
## @ace_codegen_template("$SkateboardMovement.balance()")
func balance() -> float:
	return _balance

## @ace_expression
## @ace_name("Chain Score")
## @ace_category("Skateboard")
## @ace_description("What the chain running right now is worth. Banking it moves this into the total and resets it.")
## @ace_icon("res://eventsheet_addons/skateboard/icon.svg")
## @ace_codegen_template("$SkateboardMovement.chain_score()")
func chain_score() -> float:
	return _chain_score

## @ace_expression
## @ace_name("Multiplier")
## @ace_category("Skateboard")
## @ace_description("What the next trick in the chain will be multiplied by. Starts at 1 and climbs by one per trick.")
## @ace_icon("res://eventsheet_addons/skateboard/icon.svg")
## @ace_codegen_template("$SkateboardMovement.multiplier()")
func multiplier() -> int:
	return _chain_multiplier

## @ace_expression
## @ace_name("Banked Score")
## @ace_category("Skateboard")
## @ace_description("Everything banked so far this run. A dropped chain never reaches it.")
## @ace_icon("res://eventsheet_addons/skateboard/icon.svg")
## @ace_codegen_template("$SkateboardMovement.banked_score()")
func banked_score() -> float:
	return _banked_score

## @ace_expression
## @ace_name("Spin Turns")
## @ace_category("Skateboard")
## @ace_description("How many whole turns the board has spun since it left the ground - what a 540 is counted with.")
## @ace_icon("res://eventsheet_addons/skateboard/icon.svg")
## @ace_codegen_template("$SkateboardMovement.spin_turns()")
func spin_turns() -> float:
	return _spin_turns

## @ace_condition
## @ace_name("Is Grinding")
## @ace_category("Grind")
## @ace_description("True while the board is locked to a rail and riding it.")
## @ace_icon("res://eventsheet_addons/skateboard/icon.svg")
## @ace_codegen_template("$SkateboardMovement.is_grinding()")
func is_grinding() -> bool:
	return _grinding

## @ace_condition
## @ace_name("Has Reached The End")
## @ace_category("Grind")
## @ace_description("True when the ride has run off either end of the rail's curve. Pair it with Hop Off so the board leaves under its own momentum.")
## @ace_icon("res://eventsheet_addons/skateboard/icon.svg")
## @ace_codegen_template("$SkateboardMovement.has_reached_the_end()")
func has_reached_the_end() -> bool:
	if not _grinding or _rail == null:
		return false
	var curve: Curve2D = _rail_curve()
	if curve == null:
		return true
	return _rail_offset <= 0.0 or _rail_offset >= curve.get_baked_length()

## @ace_hidden
func _closest_on_rail(path: Node2D) -> Dictionary:
	# The point on a rail nearest the host, in world space, plus the offset along the curve
	# that produced it. This closest-offset snap is the whole of what "near a rail" means.
	if host == null or path == null or not is_instance_valid(path) or not path is Path2D:
		return {}
	var curve: Curve2D = (path as Path2D).curve
	if curve == null or curve.point_count < 2:
		return {}
	var offset: float = curve.get_closest_offset(path.to_local(host.global_position))
	return {"offset": offset, "point": path.to_global(curve.sample_baked(offset))}

## @ace_hidden
func _floor_angle() -> float:
	# The angle the board sits at when it is square with the floor it is standing on.
	if host == null:
		return 0.0
	var normal: Vector2 = host.get_floor_normal()
	if normal.is_zero_approx():
		return 0.0
	return normal.angle() + PI / 2.0

## @ace_hidden
func _judge_landing() -> void:
	# Touching down: square enough with the floor and the board snaps flat and the landing
	# counts; anything crookeder is a bail. This is the ONE place a landing is judged, so the
	# tick's automatic touchdown and a hand-called Land The Trick can never disagree.
	if host == null:
		return
	var square: float = _floor_angle()
	var off_by: float = absf(rad_to_deg(angle_difference(host.rotation, square)))
	# You cannot bail a trick you never did. A board that touched down without a turn in the
	# air is simply rolling again, however steep the slope it landed on - which is what keeps a
	# beginner rolling down a bank from wiping out on arrival.
	if is_zero_approx(_spin_turns) or off_by <= landing_tolerance_degrees:
		host.rotation = square
		_spin_turns = 0.0
		landed_clean.emit()
	else:
		bail()

# Skateboard movement: attach under a CharacterBody2D. Push to gain speed and keep it, Roll With The Slope every tick so ramps and halfpipes work, Ollie to leave the ground, Spin or Flip in the air, and let the landing decide between On Landed Clean and On Bailed. Grinds snap to any Path2D.
