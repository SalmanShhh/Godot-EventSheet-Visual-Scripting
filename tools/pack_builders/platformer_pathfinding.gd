# Pack builder - platformer_pathfinding (one pack per file; run via tools/build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")

const _STRATEGIES := ["balanced", "shortest", "safest", "ground_hugging", "no_falling", "walk_only"]
const _TILE_STATES := ["solid", "clear", "jump_thru", "slope_left", "slope_right"]


## Platformer pathfinding for a CharacterBody2D - the 2D jump-graph navigator:
## scans a TileMapLayer's physics tiles (or a hand-built obstacle map, or scanned StaticBody2D
## shapes) into standable nodes, connects them with WALK links (adjacent cells, one step up/down -
## which is what makes stairs and tile slopes walkable), JUMP, DOUBLE JUMP and COYOTE JUMP arcs,
## FALL drops and FALL-THROUGH drops off one-way platforms, plus instant and gradual PORTALS and
## moving platforms, then A*-routes over the graph under a path strategy. Jump reach is DERIVED
## from the sibling PlatformerMovement's move_speed/jump_velocity/gravity/max_jumps, and
## auto-control DRIVES that sibling through its ai_move_axis seam + jump() - pathfinding never
## reimplements movement. Manual mode (Set Auto Control off) exposes the same intents as
## expressions. The code lives in tools/pack_builders/src/platformer_pathfinding/.
static func build() -> bool:
	var src: Lib.PackSource = Lib.pack_from_source("platformer_pathfinding", "CharacterBody2D", "PlatformerPathfinding",
		"Jump-aware navigation for 2D platformers: builds a jump graph from your TileMapLayer so an enemy can actually chase through the level - walking where walking works and jumping where a jump is needed. Attach as a sibling of PlatformerMovement, build the graph once, and call Find Path To; jump reach is derived from the movement pack's real physics and the agent is driven through its ai_move_axis seam.",
		Lib.manifest().behavior().category("Platformer Pathfinding").tags(["movement", "platformer", "ai", "pathfinding"]).expose_all_verbs_on_a_node())
	var sheet: EventSheetResource = src.sheet
	# Property ORDER is part of the pack: these emit in the order they are declared here.
	sheet.variables = {
		"auto_control": {"type": "bool", "default": true, "exported": true,
			"attributes": {"tooltip": "Drive the sibling PlatformerMovement automatically. Off = paths still compute; read Path Move Axis / Path Wants Jump and steer yourself."}},
		"arrive_distance": {"type": "float", "default": 10.0, "exported": true,
			"attributes": {"tooltip": "How close (px, horizontally) counts as reaching a waypoint."}},
		"max_fall_distance": {"type": "float", "default": 320.0, "exported": true,
			"attributes": {"tooltip": "The furthest safe drop (px) the graph will route through. Negative = no limit."}},
		"jump_height_override": {"type": "float", "default": 0.0, "exported": true,
			"attributes": {"tooltip": "Max jump height in px (0 = derive it from the sibling PlatformerMovement's jump_velocity/gravity)."}},
		"jump_distance_override": {"type": "float", "default": 0.0, "exported": true,
			"attributes": {"tooltip": "Max jump distance in px (0 = derive it from the sibling PlatformerMovement's speed and air time)."}},
		"debug_draw": {"type": "bool", "default": false, "exported": true,
			"attributes": {"tooltip": "Draw the active path as a line in the world."}},
		"variable_jump": {"type": "bool", "default": true, "exported": true,
			"attributes": {"tooltip": "Release the jump at the height each arc actually needs (short hops for flat gaps, full rises for tall ledges) - smoother-looking movement. Off = every jump is full height."}},
		"ledge_restriction": {"type": "bool", "default": false, "exported": true,
			"attributes": {"tooltip": "Patrol discipline: routes may only WALK - no jumps, no portals, and no drops beyond Ledge Leniency. The agent stays on its platform."}},
		"ledge_leniency": {"type": "float", "default": 0.0, "exported": true,
			"attributes": {"tooltip": "With Ledge Restriction on, drops up to this many pixels are still allowed (0 = no drops at all)."}},
		"jump_positioning": {"type": "String", "default": "relaxed", "exported": true, "options": ["relaxed", "strict"],
			"attributes": {"tooltip": "relaxed: jump as soon as a jump leg starts. strict: walk onto the exact takeoff spot first - slower but precise on tight arcs."}},
		"coyote_time": {"type": "float", "default": 0.12, "exported": true,
			"attributes": {"tooltip": "Grace window (s) for AI jumps just after running off the takeoff ledge - a frame-late jump still fires. Long enough a window (capped by the movement sibling's own) also builds COYOTE JUMP links: run off a ledge, then leap for gaps a standing jump cannot clear."}},
		"repath_interval": {"type": "float", "default": 0.5, "exported": true,
			"attributes": {"tooltip": "While following a node (Find Path To Node), how often the route may refresh. Also the cooldown between drift re-routes."}},
		"repath_threshold": {"type": "float", "default": 24.0, "exported": true,
			"attributes": {"tooltip": "The route only refreshes when the followed node has moved at least this many pixels from where the current path was aimed."}},
		"stuck_timeout": {"type": "float", "default": 1.5, "exported": true,
			"attributes": {"tooltip": "No progress toward the current waypoint for this long fires On Waypoint Stuck and re-routes from wherever the agent actually is."}},
		"fallback_move_speed": {"type": "float", "default": 200.0, "exported": true,
			"attributes": {"tooltip": "No movement sibling? The built-in fallback driver moves the CharacterBody2D itself at this speed."}},
		"fallback_jump_velocity": {"type": "float", "default": -400.0, "exported": true,
			"attributes": {"tooltip": "The fallback driver's jump velocity (negative = up). Also sizes jump arcs when nothing can be derived."}},
		"fallback_gravity": {"type": "float", "default": 980.0, "exported": true,
			"attributes": {"tooltip": "The fallback driver's gravity."}},
		"nav_enabled": {"type": "bool", "default": true, "exported": true,
			"attributes": {"tooltip": "Off = the agent freezes with its route, graph and settings kept, and route requests are ignored until it is switched back on (Set Enabled)."}},
		"path_strategy": {"type": "String", "default": "balanced", "exported": true, "options": _STRATEGIES,
			"attributes": {"tooltip": "How routes are picked. balanced: distance and difficulty weighed together. shortest: fewest pixels, long jumps welcome. safest: chains of short hops over long leaps and deep drops. ground_hugging: walks whenever any walking route exists. no_falling: never descends by jump or fall (Max Traversal Drop raises the allowance). walk_only: never leaves its platform except by portal or moving platform."}},
		"smooth_paths": {"type": "bool", "default": true, "exported": true,
			"attributes": {"tooltip": "Drop the in-between waypoints of a straight walk so the agent walks the stretch in one leg."}},
		"max_search_nodes": {"type": "int", "default": 2000, "exported": true,
			"attributes": {"tooltip": "The most nodes one route search may expand before it gives up (Path Fail Reason max_nodes_reached). Raise it for very large levels."}},
		"max_traversal_drop": {"type": "float", "default": -1.0, "exported": true,
			"attributes": {"tooltip": "Jumps and falls that land more than this many pixels lower are left out of routes (fall damage, heavy units). -1 = no limit."}},
		"drift_repath_distance": {"type": "float", "default": 0.0, "exported": true,
			"attributes": {"tooltip": "Knocked more than this many pixels off the leg it is walking, the agent re-plans from where it is (fires On Repath). 0 = off."}},
		"double_jump_links": {"type": "bool", "default": true, "exported": true,
			"attributes": {"tooltip": "When the movement sibling has max_jumps of 2 or more, build DOUBLE JUMP links to ledges a single jump cannot reach."}},
		"hazard_margin": {"type": "float", "default": 0.0, "exported": true,
			"attributes": {"tooltip": "Every hazard is surrounded by a danger buffer this many pixels wide: links through it cost more, so routes keep their distance."}},
		"danger_cost_multiplier": {"type": "float", "default": 4.0, "exported": true,
			"attributes": {"tooltip": "How much more a link through a non-deadly hazard (or a hazard's margin) costs than a clean one."}},
		"auto_build": {"type": "bool", "default": true, "exported": true,
			"attributes": {"tooltip": "A route asked for before any graph exists builds one from the first TileMapLayer with physics in the running scene."}},
		"map_tag": {"type": "String", "default": "", "exported": true,
			"attributes": {"tooltip": "Agents with the same non-empty tag SHARE one graph, obstacle edits, portals, hazards and moving platforms - built once for all of them. Give agents with different jump physics different tags. Empty = this agent keeps its own."}},
		"grid_cell_size": {"type": "float", "default": 32.0, "exported": true,
			"attributes": {"tooltip": "Cell size in pixels for a map with no TileMapLayer (Create Obstacle Map, Load Obstacle Map JSON). A tilemap's own tile size always wins."}},
		"crowd_arrivals": {"type": "bool", "default": false, "exported": true,
			"attributes": {"tooltip": "Agents routing to the same spot each claim a landing node; later arrivals take the nearest free node beside it instead of stacking."}},
		"multi_agent_avoidance": {"type": "bool", "default": false, "exported": true,
			"attributes": {"tooltip": "Routes pay extra for the cells other agents stand on or are about to walk, so agents fan out over different ways."}},
		"idle_separation": {"type": "float", "default": 0.0, "exported": true,
			"attributes": {"tooltip": "Personal space in pixels for an agent with no route: closer than this to another agent on the same map, it steps away - never off a ledge. 0 = off."}},
		"separation_cooldown": {"type": "float", "default": 5.0, "exported": true,
			"attributes": {"tooltip": "Seconds an agent rests after giving up on idle separation (a crowd too dense to spread)."}},
		"separation_give_up_time": {"type": "float", "default": 2.0, "exported": true,
			"attributes": {"tooltip": "Seconds an agent keeps trying to separate before it gives up and rests."}},
		"debug_draw_graph": {"type": "bool", "default": false, "exported": true,
			"attributes": {"tooltip": "Draw every node and link of the graph in the world, links coloured by kind (walk, jump, fall, portal...)."}},
		"debug_log": {"type": "bool", "default": false, "exported": true,
			"attributes": {"tooltip": "Print each route found (waypoints, cost) and each failure with its reason to the Output panel."}},
	}

	src.note("Platformer pathfinding: attach as a SIBLING of PlatformerMovement under a CharacterBody2D. Build Nav Graph from your TileMapLayer once, then Find Path To - the behavior derives jump reach from the movement pack and drives it through the ai_move_axis seam. Stairs and tile slopes walk (adjacent cells one step up/down are WALK links); gaps and ledges route through jump, double jump and coyote jump arcs, fall drops, fall-through drops off one-way platforms, portals and moving platforms.")
	src.block("state")
	src.block("signals")
	src.block("queries")
	src.block("grid")
	src.block("helpers")
	# Per-physics-tick drive: resolve the current waypoint into the {move_axis, want_jump}
	# intent, feed the sibling movement pack (auto) or just publish the expressions (manual).
	src.on_physics_process()

	# ── The original verbs (ids, params and templates are frozen) ──────────────────────
	src.verb("build_nav_graph", "Build Nav Graph From Tilemap",
		"Scans a TileMapLayer's physics tiles into the navigation graph: standable cells become nodes, adjacent cells (one step up or down - stairs and tile slopes) become WALK links, and jump arcs / fall drops connect the rest, sized to the sibling PlatformerMovement's real jump. One-way tiles become jump-through platforms an agent can drop through. Call once on ready; Regenerate after level edits. Fires On Nav Graph Built.",
		[["tilemap", "Node"]])
	src.verb("regenerate_nav_graph", "Regenerate Nav Graph",
		"Rebuilds the graph from the same map (after runtime tile edits, Set Tile State or Scan Collision Bodies).",
		[])
	src.verb("find_path_to", "Find Path To",
		"Routes to a world position and starts moving. Mode \"reach\" fails (On Path Failed) when the spot itself is unreachable; \"nearest\" never fails on a cut-off spot - it goes as close as it can get. Fires On Path Found / On Path Failed.",
		[["x", "float"], ["y", "float"], ["mode", "String"]])
	_default(sheet, "mode", "nearest")
	_param_options(sheet, "mode", ["nearest", "reach"])
	_quoted_argument(sheet, "find_path_to({x}, {y}, \"{mode}\")")
	src.verb("find_path_to_node", "Find Path To Node",
		"Routes to another node's position AND keeps following it: the route auto-refreshes every Repath Interval once the node has moved Repath Threshold pixels (firing On Repath) - one call chases forever. Stop Pathfinding ends the follow.",
		[["target", "Node"], ["mode", "String"]])
	_default(sheet, "mode", "nearest")
	_param_options(sheet, "mode", ["nearest", "reach"])
	_quoted_argument(sheet, "find_path_to_node({target}, \"{mode}\")")
	src.verb("stop_pathfinding", "Stop Pathfinding",
		"Clears the path (and any patrol, Jump Toward or portal in progress) and releases the movement pack back to the keyboard (ai_controlled off).",
		[])
	src.verb("set_auto_control", "Set Auto Control",
		"On (default): the behavior drives the sibling PlatformerMovement. Off: paths still compute - read Path Move Axis / Path Wants Jump / Current Waypoint X/Y and drive anything you like.",
		[["enabled", "bool"]])
	src.verb("set_ledge_restriction", "Set Ledge Restriction",
		"Patrol discipline: on, routes may only WALK - no jumps, no portals, and no drops beyond Ledge Leniency, so the agent stays on its platform. Applies from the next Find Path To.",
		[["enabled", "bool"]])
	src.verb("set_ledge_leniency", "Set Ledge Leniency",
		"With Ledge Restriction on, drops up to this many pixels are still allowed (a patroller may hop down one step but never off the tower).",
		[["pixels", "float"]])
	src.verb("set_jump_positioning", "Set Jump Positioning",
		"relaxed (default): leap the moment a jump leg starts. strict: walk onto the exact takeoff spot first - slower but precise on tight arcs.",
		[["mode", "String"]])
	_default(sheet, "mode", "relaxed")
	_param_options(sheet, "mode", ["relaxed", "strict"])
	_quoted_argument(sheet, "set_jump_positioning(\"{mode}\")")
	src.verb("set_coyote_time", "Set Coyote Time",
		"Grace window (s) for AI jumps just after running off the takeoff ledge.",
		[["seconds", "float"]])
	src.verb("set_repath_interval", "Set Repath Interval",
		"While following a node, how often the route may refresh (chase freshness vs cost).",
		[["seconds", "float"]])
	src.verb("set_repath_threshold", "Set Repath Threshold",
		"The route only refreshes when the followed node has moved at least this many pixels.",
		[["pixels", "float"]])
	src.verb("set_max_paths_per_tick", "Set Max Paths Per Tick",
		"The SHARED budget across every agent: at most this many route computations per physics tick - extras defer a tick (Is Path Pending) instead of spiking the frame. The difference between 20 chasers working and not.",
		[["count", "int"]])
	src.verb("add_portal", "Add Portal",
		"Links two world positions as an instant PORTAL: an agent whose route uses it walks to the entrance and blinks to the exit (fires On Portal Entered, then On Portal Taken). Bidirectional works both ways. Portals join the graph immediately and survive Regenerate. Add Instant Portal adds a cost and a tag; Add Gradual Portal moves the agent instead of blinking it.",
		[["from_x", "float"], ["from_y", "float"], ["to_x", "float"], ["to_y", "float"], ["bidirectional", "bool"]])
	src.verb("clear_portals", "Clear Portals",
		"Removes every registered portal and elevator stop (takes effect on the next Regenerate Nav Graph).",
		[])
	src.verb("add_hazard", "Add Hazard",
		"Marks a world-space rectangle as hazardous. Deadly: routes NEVER pass through it (spikes, lava). Not deadly: routes pay Danger Cost Multiplier to cross, so it is taken only when no clean way exists (fire patches, slow mud). Applies to routing instantly - no rebuild - and On Hazard Entered fires if the agent ends up inside one anyway. Last Hazard Id names it for Remove Hazard.",
		[["x", "float"], ["y", "float"], ["width", "float"], ["height", "float"], ["deadly", "bool"]])
	src.verb("clear_hazards", "Clear Hazards",
		"Removes every hazard of every kind (routing sees the change immediately).",
		[])
	src.verb("add_moving_platform", "Add Moving Platform",
		"Registers a moving platform (an AnimatableBody2D you animate) by its two travel endpoints: the graph gains a PLATFORM link between them, and an agent routed across it walks to the track, WAITS for the platform, boards, rides, and walks off at the far side. Survives Regenerate. The pack never moves the platform - your sheet animates it between exactly these endpoints.",
		[["platform", "Node"], ["from_x", "float"], ["from_y", "float"], ["to_x", "float"], ["to_y", "float"]])
	src.verb("clear_moving_platforms", "Clear Moving Platforms",
		"Unregisters every moving platform (takes effect on the next Regenerate Nav Graph).",
		[])
	src.verb("set_nav_debug_draw", "Set Nav Debug Draw",
		"Draws the active path as a line in the world (great while tuning a level).",
		[["enabled", "bool"]])

	# ── Routing and movement ───────────────────────────────────────────────────────────
	src.verb("set_enabled", "Set Enabled",
		"Off freezes the agent where it stands with its route, graph and settings kept, and ignores route requests; on resumes exactly where it left off.",
		[["state", "bool", "On to navigate, off to freeze."]])
	src.condition("is_enabled", "Is Enabled",
		"True while the behavior is enabled (Set Enabled, or the Nav Enabled property).",
		[])
	src.verb("set_path_strategy", "Set Path Strategy",
		"How routes are picked from now on: balanced, shortest (fewest pixels, long jumps welcome), safest (short hops over long leaps and deep drops), ground_hugging (walks whenever it can), no_falling (never descends by air) or walk_only (never leaves its platform except by portal or moving platform).",
		[["strategy", "String", "The strategy routes are priced by."]])
	_word(sheet, "strategy", _STRATEGIES, "set_path_strategy(\"{strategy}\")")
	src.verb("set_max_traversal_drop", "Set Max Traversal Drop",
		"Jumps and falls landing more than this many pixels lower are left out of this agent's routes, so it goes down by slopes, portals and short hops instead (fall damage, heavy units). -1 = no limit.",
		[["pixels", "float", "The deepest drop allowed, in pixels (-1 = no limit)."]])
	src.verb("set_drift_repath_distance", "Set Drift Repath Distance",
		"Knocked more than this many pixels off the leg it is walking, the agent re-plans from where it is (fires On Repath), at most once per Repath Interval. 0 = off.",
		[["pixels", "float", "How far off its leg the agent may be pushed before it re-plans (0 = off)."]])
	src.verb("set_movement_limit", "Set Movement Limit",
		"Overrides a movement limit the graph is built from instead of deriving it from the movement sibling: jump_height, jump_distance (pixels, 0 = derive again) or max_fall (pixels, negative = no limit). Regenerate Nav Graph afterwards.",
		[["limit", "String", "Which limit to override."], ["value", "float", "The new limit in pixels."]])
	_word(sheet, "limit", ["jump_height", "jump_distance", "max_fall"], "set_movement_limit(\"{limit}\", {value})")
	src.verb("jump_toward", "Jump Toward",
		"A full-strength jump straight at a point with no route at all - a lunge, a pounce, a boss leap. Works from the ground (or mid-air when the movement sibling has a jump left). Ends any route or patrol. Fires On Jump Toward Launched as it leaves the ground.",
		[["x", "float", "World X to leap toward."], ["y", "float", "World Y to leap toward."]])
	src.verb("teleport_to", "Teleport To",
		"Moves the agent to a world position instantly without throwing its route away (the drift re-route skips that tick).",
		[["x", "float", "World X."], ["y", "float", "World Y."]])
	src.verb("start_patrol", "Start Patrol",
		"Patrols the platform the agent stands on: walks to one end, waits Dwell seconds, turns, and repeats. The ends are found from the graph (ledges and walls, slopes and stairs included); Edge Distance keeps it that many pixels back from each end. Any route request ends the patrol.",
		[["dwell", "float", "Seconds to wait at each end (0 = turn straight around)."], ["edge_distance", "float", "Pixels to stay back from each end."]])
	src.verb("stop_patrol", "Stop Patrol",
		"Ends the patrol; the agent stands where it is.",
		[])
	src.condition("is_patrolling", "Is Patrolling",
		"True while a Start Patrol patrol is running (walking or dwelling).",
		[])
	src.expression("patrol_direction", "Patrol Direction",
		"-1 walking left, 1 walking right, 0 while dwelling at an end or not patrolling. Handy for flipping the sprite.",
		[], TYPE_INT)
	src.verb("find_path_to_nearest_ledge", "Find Path To Nearest Ledge",
		"Routes to the nearest edge of the agent's platform in a direction, stopping Distance pixels back from it. Fails (On Path Failed, reason no_ledge) when the platform has no ledge that way.",
		[["direction", "String", "Which way to look for the ledge."], ["distance", "float", "Pixels to stop short of the edge."]])
	_word(sheet, "direction", ["left", "right"], "find_path_to_nearest_ledge(\"{direction}\", {distance})")
	src.verb("find_path_to_node_side", "Find Path To Node Side",
		"Routes to a spot BESIDE a node instead of onto it, Distance pixels clear of it: left, right, or any (the nearer side, falling back to the other when it has no ground). Fires On Node Side Reached on arrival there; Reached Side says which side.",
		[["target", "Node", "The node to stand beside."], ["side", "String", "Which side of it to stand on."], ["distance", "float", "Gap in pixels between the two (one tile is always kept)."]])
	_word(sheet, "side", ["any", "left", "right"], "find_path_to_node_side({target}, \"{side}\", {distance})")
	src.expression("reached_side", "Reached Side",
		"Which side Find Path To Node Side arrived on: -1 left, 1 right, 0 none yet.",
		[], TYPE_INT)
	src.expression("jump_toward_target", "Jump Toward Target",
		"The point the running Jump Toward is aimed at (zero when none is running).",
		[], TYPE_VECTOR2)
	src.expression("coyote_timer", "Coyote Timer",
		"Seconds of coyote grace left after running off a ledge (0 on the ground or once it has run out).",
		[], TYPE_FLOAT)
	src.expression("estimated_velocity_x", "Estimated Velocity X",
		"The horizontal speed (px/s) the route is asking for right now - Path Move Axis times the run speed.",
		[], TYPE_FLOAT)

	# ── Path details ─────────────────────────────────────────────────────────────────
	src.expression("path_cost", "Path Cost",
		"The total cost of the active route under the current strategy (0 with no route).",
		[], TYPE_FLOAT)
	src.expression("path_end", "Path End",
		"Where the active route actually ends - in nearest mode this can differ from the asked-for spot.",
		[], TYPE_VECTOR2)
	src.expression("path_target", "Path Target",
		"The world position the last route was asked for.",
		[], TYPE_VECTOR2)
	src.expression("path_goal_cell", "Path Goal Cell",
		"The grid cell the last route ended on (the asked-for spot snapped to walkable ground).",
		[], TYPE_VECTOR2I)
	src.expression("path_fail_reason", "Path Fail Reason",
		"Why the last route failed: no_graph, no_start_node, no_goal_node, no_path, max_nodes_reached, no_ledge or no_target. Empty after a success.",
		[], TYPE_STRING)
	src.expression("path_queue_size", "Path Queue Size",
		"How many agents are waiting on the shared per-tick route budget right now.",
		[], TYPE_INT)
	src.expression("waypoint_position", "Waypoint Position",
		"The world position of a waypoint of the active route (zero out of range).",
		[["index", "int", "Waypoint index, from 0."]], TYPE_VECTOR2)
	src.expression("waypoint_cell", "Waypoint Cell",
		"The grid cell of a waypoint of the active route ((-1, -1) out of range).",
		[["index", "int", "Waypoint index, from 0."]], TYPE_VECTOR2I)
	src.expression("waypoint_action", "Waypoint Action",
		"How a waypoint is reached: walk, jump, double_jump, coyote_jump, fall, fall_through, portal, portal_gradual or platform (empty out of range).",
		[["index", "int", "Waypoint index, from 0."]], TYPE_STRING)
	src.expression("distance_to_waypoint", "Distance To Waypoint",
		"Pixels from the agent to its current waypoint (0 with no route).",
		[], TYPE_FLOAT)
	src.expression("angle_to_waypoint", "Angle To Waypoint",
		"Degrees from the agent to its current waypoint (0 with no route).",
		[], TYPE_FLOAT)

	# ── Crowds ───────────────────────────────────────────────────────────────────────
	src.verb("set_crowd_arrivals", "Set Crowd Arrivals",
		"On: agents routing to the same spot each claim a landing node, so later arrivals stand beside it instead of stacking on one pixel.",
		[["enabled", "bool", "On to spread arrivals."]])
	src.verb("set_multi_agent_avoidance", "Set Multi Agent Avoidance",
		"On: routes pay extra for cells other agents stand on or are about to walk, so a pack fans out over different ways.",
		[["enabled", "bool", "On to avoid other agents' routes."]])
	src.verb("set_separation_setting", "Set Separation Setting",
		"Changes an idle separation setting: distance (personal space in pixels, 0 = off), cooldown (seconds of rest after giving up) or give_up_time (seconds of trying before resting).",
		[["setting", "String", "Which setting to change."], ["value", "float", "Its new value."]])
	_word(sheet, "setting", ["distance", "cooldown", "give_up_time"], "set_separation_setting(\"{setting}\", {value})")
	src.expression("nearby_agent_count", "Nearby Agent Count",
		"How many other agents on the same map stand within a radius of this one.",
		[["radius", "float", "Radius in pixels."]], TYPE_INT)

	# ── Platforms and ledges ─────────────────────────────────────────────────────────
	src.condition("is_at_ledge", "Is At Ledge",
		"True while the agent stands on the edge node of its platform.",
		[])
	src.condition("is_at_island", "Is At Island",
		"True while the agent stands on a one-node platform.",
		[])
	src.condition("is_on_same_platform", "Is On Same Platform",
		"True when the agent could WALK to the node - no jump or fall needed (slopes and stairs count).",
		[["target", "Node", "The node to test."]])
	src.condition("is_position_on_same_platform", "Is Position On Same Platform",
		"True when the agent could WALK to a world position - no jump or fall needed.",
		[["x", "float", "World X."], ["y", "float", "World Y."]])
	src.expression("nearest_ledge", "Nearest Ledge",
		"The nearest ledge of the agent's platform in a direction (zero when there is none).",
		[["direction", "String", "Which way to look."]], TYPE_VECTOR2)
	_word(sheet, "direction", ["left", "right"], "nearest_ledge(\"{direction}\")")
	src.object_expression("node_on_platform", "Node On Platform",
		"The nearest or furthest node of a group that stands on the agent's own platform (reachable by walking alone), or null - pick a target it can walk to.",
		[["group", "String", "The group to search, in quotes."], ["which", "String", "Nearest or furthest."]], "Node")
	_code_default(sheet, "group", "\"\"")
	_word(sheet, "which", ["nearest", "furthest"], "node_on_platform({group}, \"{which}\")")

	# ── Obstacle map ─────────────────────────────────────────────────────────────────
	src.verb("create_obstacle_map", "Create Obstacle Map",
		"Starts an empty map with no TileMapLayer: Width x Height cells of Cell Size pixels from the world origin, every cell clear. Fill it with Set Tile State or Scan Collision Bodies, then Regenerate Nav Graph.",
		[["width", "int", "Width in cells."], ["height", "int", "Height in cells."], ["cell_size", "float", "Cell size in pixels (0 keeps Grid Cell Size)."]])
	src.verb("set_tile_state", "Set Tile State",
		"Overrides one cell of the map: solid, clear, jump_thru (a one-way platform), slope_left (rises to the right) or slope_right (rises to the left). Overrides survive Regenerate; call Regenerate Nav Graph after a batch of them.",
		[["gx", "int", "Grid X."], ["gy", "int", "Grid Y."], ["state", "String", "The cell's new state."]])
	_word(sheet, "state", _TILE_STATES, "set_tile_state({gx}, {gy}, \"{state}\")")
	src.verb("set_tile_state_at", "Set Tile State At",
		"Set Tile State for the cell under a world position.",
		[["x", "float", "World X."], ["y", "float", "World Y."], ["state", "String", "The cell's new state."]])
	_word(sheet, "state", _TILE_STATES, "set_tile_state_at({x}, {y}, \"{state}\")")
	src.verb("scan_collision_bodies", "Scan Collision Bodies",
		"Marks every cell covered by the StaticBody2D shapes under a node as solid (one-way shapes as jump-through) - for levels built from bodies instead of tiles. Needs a grid first (Build Nav Graph From Tilemap or Create Obstacle Map); Regenerate Nav Graph afterwards.",
		[["root", "Node", "The node whose StaticBody2D descendants are scanned."]])
	src.verb("clear_nav_graph", "Clear Nav Graph",
		"Drops the graph, the obstacle map and every tile override (portals and hazards stay registered), stops the agent and fires On Nav Graph Cleared.",
		[])
	src.verb("load_obstacle_map_json", "Load Obstacle Map JSON",
		"Rebuilds the map and graph from a string Obstacle Map JSON produced - a saved or pre-baked level, no TileMapLayer needed.",
		[["json", "String", "The JSON text, in quotes or from a variable."]])
	_code_default(sheet, "json", "\"\"")
	src.expression("obstacle_map_json", "Obstacle Map JSON",
		"The current obstacle map (tiles, scanned bodies and overrides) as a JSON string, to save or ship with a level.",
		[], TYPE_STRING)
	src.expression("obstacle_map_source", "Obstacle Map Source",
		"Where the map comes from: tilemap, custom or none.",
		[], TYPE_STRING)
	src.expression("tile_state", "Tile State",
		"A cell's state: solid, clear, jump_thru, slope_left or slope_right (empty with no map or outside a custom map).",
		[["gx", "int", "Grid X."], ["gy", "int", "Grid Y."]], TYPE_STRING)
	src.condition("tile_has_state", "Tile Has State",
		"True when a cell has the given state.",
		[["gx", "int", "Grid X."], ["gy", "int", "Grid Y."], ["state", "String", "The state to test for."]])
	_word(sheet, "state", _TILE_STATES, "tile_has_state({gx}, {gy}, \"{state}\")")
	src.condition("tile_has_state_at", "Tile Has State At",
		"True when the cell under a world position has the given state.",
		[["x", "float", "World X."], ["y", "float", "World Y."], ["state", "String", "The state to test for."]])
	_word(sheet, "state", _TILE_STATES, "tile_has_state_at({x}, {y}, \"{state}\")")
	src.expression("world_to_grid", "World To Grid",
		"The grid cell under a world position.",
		[["x", "float", "World X."], ["y", "float", "World Y."]], TYPE_VECTOR2I)
	src.expression("grid_to_world", "Grid To World",
		"The world position of a cell's centre.",
		[["gx", "int", "Grid X."], ["gy", "int", "Grid Y."]], TYPE_VECTOR2)
	src.expression("grid_size", "Grid Size",
		"The map's size in cells (a tilemap's used area, or a custom map's size).",
		[], TYPE_VECTOR2I)
	src.expression("grid_tile_size", "Grid Tile Size",
		"The map's cell size in pixels (0 with no map).",
		[], TYPE_FLOAT)

	# ── Graph inspection ─────────────────────────────────────────────────────────────
	src.verb("log_graph_stats", "Log Graph Stats",
		"Prints the graph's size to the Output panel: nodes, links by kind, portals, hazards, platforms and the jump reach.",
		[])
	src.verb("set_debug_draw_graph", "Set Debug Draw Graph",
		"Draws every node and link of the graph in the world, links coloured by kind.",
		[["enabled", "bool", "On to draw the graph."]])
	src.condition("graph_node_exists", "Graph Node Exists",
		"True when a cell is a standable node of the graph.",
		[["gx", "int", "Grid X."], ["gy", "int", "Grid Y."]])
	src.condition("graph_node_exists_at", "Graph Node Exists At",
		"True when the cell under a world position is a standable node.",
		[["x", "float", "World X."], ["y", "float", "World Y."]])
	src.condition("is_ledge_node", "Is Ledge Node",
		"True when a node is the edge of its platform (left, right or both).",
		[["gx", "int", "Grid X."], ["gy", "int", "Grid Y."]])
	src.expression("ledge_side", "Ledge Side",
		"Which side of a node is a ledge: -1 left, 1 right, 2 both (a one-node island), 0 neither.",
		[["gx", "int", "Grid X."], ["gy", "int", "Grid Y."]], TYPE_INT)
	src.expression("graph_node_count", "Graph Node Count",
		"How many standable nodes the graph has.",
		[], TYPE_INT)
	src.expression("graph_node_cell", "Graph Node Cell",
		"The grid cell of the node at an index ((-1, -1) out of range).",
		[["index", "int", "Node index, from 0."]], TYPE_VECTOR2I)
	src.expression("graph_node_position", "Graph Node Position",
		"The world position of the node at an index (zero out of range).",
		[["index", "int", "Node index, from 0."]], TYPE_VECTOR2)
	src.expression("graph_node_connection_count", "Graph Node Connection Count",
		"How many links leave a node.",
		[["gx", "int", "Grid X."], ["gy", "int", "Grid Y."]], TYPE_INT)
	src.expression("graph_node_connection_kind", "Graph Node Connection Kind",
		"The kind of one link leaving a node (walk, jump, fall, portal...).",
		[["gx", "int", "Grid X."], ["gy", "int", "Grid Y."], ["index", "int", "Link index, from 0."]], TYPE_STRING)
	src.expression("graph_node_connection_cost", "Graph Node Connection Cost",
		"The cost of one link leaving a node, under the current strategy.",
		[["gx", "int", "Grid X."], ["gy", "int", "Grid Y."], ["index", "int", "Link index, from 0."]], TYPE_FLOAT)
	src.expression("graph_node_connection_target", "Graph Node Connection Target",
		"The world position one link leaving a node lands on.",
		[["gx", "int", "Grid X."], ["gy", "int", "Grid Y."], ["index", "int", "Link index, from 0."]], TYPE_VECTOR2)
	src.expression("nearest_graph_node", "Nearest Graph Node",
		"The world position of the node nearest a point (zero with no graph).",
		[["x", "float", "World X."], ["y", "float", "World Y."]], TYPE_VECTOR2)
	src.expression("nearest_graph_node_cell", "Nearest Graph Node Cell",
		"The grid cell of the node nearest a point ((-1, -1) with no graph).",
		[["x", "float", "World X."], ["y", "float", "World Y."]], TYPE_VECTOR2I)
	src.expression("calculated_jump_distance", "Calculated Jump Distance",
		"The jump distance in pixels the graph is built with (derived or overridden).",
		[], TYPE_FLOAT)
	src.expression("calculated_jump_height", "Calculated Jump Height",
		"The jump height in pixels the graph is built with (derived or overridden).",
		[], TYPE_FLOAT)

	# ── Hazards ──────────────────────────────────────────────────────────────────────
	src.verb("add_circle_hazard", "Add Circle Hazard",
		"Marks a circle as hazardous - an explosion, a fire burst. Deadly blocks routes; not deadly makes them costly. Last Hazard Id names it.",
		[["x", "float", "Centre X."], ["y", "float", "Centre Y."], ["radius", "float", "Radius in pixels."], ["deadly", "bool", "Deadly blocks routes; off only makes them costly."]])
	src.verb("add_tracked_hazard", "Add Tracked Hazard",
		"A circular hazard that FOLLOWS a node (a patrolling saw, a burning enemy) with no per-frame events, and removes itself when the node is freed. Last Hazard Id names it.",
		[["target", "Node", "The node the hazard follows."], ["radius", "float", "Radius in pixels."], ["deadly", "bool", "Deadly blocks routes; off only makes them costly."]])
	src.verb("remove_hazard", "Remove Hazard",
		"Removes one hazard by the id Last Hazard Id gave you.",
		[["hazard_id", "int", "The hazard's id."]])
	src.verb("set_hazard_margin", "Set Hazard Margin",
		"Surrounds every hazard with a danger buffer this many pixels wide, so routes keep their distance.",
		[["pixels", "float", "Buffer width in pixels (0 = none)."]])
	src.condition("is_position_hazardous", "Is Position Hazardous",
		"True when a world position is inside any hazard.",
		[["x", "float", "World X."], ["y", "float", "World Y."]])
	src.expression("hazard_at", "Hazard At",
		"The hazard level at a world position: 0 clear, 1 danger (or a hazard's margin), 2 deadly.",
		[["x", "float", "World X."], ["y", "float", "World Y."]], TYPE_INT)
	src.expression("hazard_count", "Hazard Count",
		"How many hazards are registered (every kind).",
		[], TYPE_INT)
	src.expression("tracked_hazard_count", "Tracked Hazard Count",
		"How many node-following hazards are registered.",
		[], TYPE_INT)
	src.expression("last_hazard_id", "Last Hazard Id",
		"The id of the most recently added hazard, for Remove Hazard (0 before any).",
		[], TYPE_INT)

	# ── Portals ──────────────────────────────────────────────────────────────────────
	src.verb("add_instant_portal", "Add Instant Portal",
		"A portal that BLINKS the agent from entrance to exit (a door, a teleporter). Cost 1 is the normal price; raise it to make routes avoid the portal. Tags (comma-separated) group portals for the by-tag actions and expressions. Last Portal Id names it.",
		[["from_x", "float", "Entrance X."], ["from_y", "float", "Entrance Y."], ["to_x", "float", "Exit X."], ["to_y", "float", "Exit Y."], ["bidirectional", "bool", "Usable both ways."], ["cost", "float", "Price multiplier (1 = normal)."], ["tag", "String", "Optional tags, comma-separated, in quotes."]])
	_code_default(sheet, "tag", "\"\"")
	src.verb("add_gradual_portal", "Add Gradual Portal",
		"A portal that MOVES the agent from entrance to exit in a straight line at Speed (a ladder, a lift, a zipline), with the movement sibling paused on the way. Cost 1 prices it by its travel time. Last Portal Id names it.",
		[["from_x", "float", "Entrance X."], ["from_y", "float", "Entrance Y."], ["to_x", "float", "Exit X."], ["to_y", "float", "Exit Y."], ["bidirectional", "bool", "Usable both ways."], ["speed", "float", "Travel speed in px/s."], ["cost", "float", "Price multiplier (1 = priced by travel time)."], ["tag", "String", "Optional tags, comma-separated, in quotes."]])
	_code_default(sheet, "tag", "\"\"")
	src.verb("add_elevator_stop", "Add Elevator Stop",
		"Adds a stop to an elevator group: two-way gradual portals to every other stop of the group are created for you. One group name per elevator.",
		[["group", "String", "The elevator's name, in quotes."], ["x", "float", "Stop X."], ["y", "float", "Stop Y."], ["speed", "float", "Travel speed in px/s."], ["tag", "String", "Optional tags, comma-separated, in quotes."]])
	_code_default(sheet, "group", "\"\"")
	_code_default(sheet, "tag", "\"\"")
	src.verb("pause_at_portal", "Pause At Portal",
		"Inside On Portal Entered: holds the agent at the entrance so your events can play a door or lift animation first. Then Resume Portal (the portal moves it) or Complete Portal (your events moved it).",
		[])
	src.verb("resume_portal", "Resume Portal",
		"Runs a paused portal's own move: the blink, or the gradual travel.",
		[])
	src.verb("complete_portal", "Complete Portal",
		"Finishes a paused portal WITHOUT its own move (your events already moved the agent), or cuts a gradual portal short where the agent is.",
		[])
	src.verb("remove_portal", "Remove Portal",
		"Removes one portal by id; its links leave the graph immediately.",
		[["portal_id", "int", "The portal's id."]])
	src.verb("remove_portal_near", "Remove Portal Near",
		"Removes the portal whose entrance or exit is nearest a world position.",
		[["x", "float", "World X."], ["y", "float", "World Y."]])
	src.verb("remove_portals_by_tag", "Remove Portals By Tag",
		"Removes every portal carrying a tag (an empty tag removes them all).",
		[["tag", "String", "The tag, in quotes."]])
	_code_default(sheet, "tag", "\"\"")
	src.verb("set_portal_cost", "Set Portal Cost",
		"Changes a portal's price multiplier (higher = routes avoid it).",
		[["portal_id", "int", "The portal's id."], ["cost", "float", "Price multiplier (1 = normal)."]])
	src.verb("set_portal_speed", "Set Portal Speed",
		"Changes a gradual portal's travel speed in px/s.",
		[["portal_id", "int", "The portal's id."], ["speed", "float", "Travel speed in px/s."]])
	src.verb("set_portal_tag", "Set Portal Tag",
		"Replaces a portal's tags.",
		[["portal_id", "int", "The portal's id."], ["tag", "String", "The new tags, comma-separated, in quotes."]])
	_code_default(sheet, "tag", "\"\"")
	src.verb("set_portal_ignore_hazards", "Set Portal Ignore Hazards",
		"On: routes use the portal even when a hazard covers it.",
		[["portal_id", "int", "The portal's id."], ["ignore", "bool", "On to ignore hazards."]])
	src.verb("set_portal_position", "Set Portal Position",
		"Moves a portal's entrance and exit, keeping its id, type, cost, speed and tags - call it on a timer to follow a moving door.",
		[["portal_id", "int", "The portal's id."], ["from_x", "float", "Entrance X."], ["from_y", "float", "Entrance Y."], ["to_x", "float", "Exit X."], ["to_y", "float", "Exit Y."]])
	src.condition("is_at_portal", "Is At Portal",
		"True while the agent is held at a portal entrance by Pause At Portal.",
		[])
	src.condition("is_traversing_portal", "Is Traversing Portal",
		"True while a gradual portal is moving the agent.",
		[])
	src.expression("current_portal_id", "Current Portal Id",
		"The portal being (or last) taken - read it inside On Portal Entered / On Portal Taken (-1 before any).",
		[], TYPE_INT)
	src.expression("last_portal_id", "Last Portal Id",
		"The id of the most recently added portal (-1 before any).",
		[], TYPE_INT)
	src.expression("portal_count", "Portal Count",
		"How many portals are registered.",
		[], TYPE_INT)
	src.expression("nearest_portal_id", "Nearest Portal Id",
		"The portal whose entrance is nearest a point, optionally only those carrying a tag (-1 when none).",
		[["x", "float", "World X."], ["y", "float", "World Y."], ["tag", "String", "Only portals with this tag (empty = any), in quotes."]], TYPE_INT)
	_code_default(sheet, "tag", "\"\"")
	src.expression("furthest_portal_id", "Furthest Portal Id",
		"The portal whose entrance is furthest from a point, optionally only those carrying a tag (-1 when none).",
		[["x", "float", "World X."], ["y", "float", "World Y."], ["tag", "String", "Only portals with this tag (empty = any), in quotes."]], TYPE_INT)
	_code_default(sheet, "tag", "\"\"")
	src.expression("portal_count_by_tag", "Portal Count By Tag",
		"How many portals carry a tag.",
		[["tag", "String", "The tag, in quotes."]], TYPE_INT)
	_code_default(sheet, "tag", "\"\"")
	src.expression("portal_id_by_tag", "Portal Id By Tag",
		"The id of the index-th portal carrying a tag (-1 out of range).",
		[["tag", "String", "The tag, in quotes."], ["index", "int", "Index among those portals, from 0."]], TYPE_INT)
	_code_default(sheet, "tag", "\"\"")
	src.expression("portal_tag", "Portal Tag",
		"A portal's tags (empty when it has none or does not exist).",
		[["portal_id", "int", "The portal's id."]], TYPE_STRING)
	src.expression("portal_type", "Portal Type",
		"instant or gradual (empty when the portal does not exist).",
		[["portal_id", "int", "The portal's id."]], TYPE_STRING)
	src.expression("portal_exit", "Portal Exit",
		"Where the current portal lets the agent out.",
		[], TYPE_VECTOR2)
	src.expression("portal_progress", "Portal Progress",
		"0 to 1 along a gradual portal while it moves the agent (0 otherwise).",
		[], TYPE_FLOAT)

	# The pack's hero verbs: starred + bold at the top of their picker section.
	Lib.verb_sentences(sheet, {
		"build_nav_graph": "Build nav graph from [i]{tilemap}[/i]",
		"find_path_to": "Find path to ([b]{x}[/b], [b]{y}[/b]) mode [b]{mode}[/b]",
		"start_patrol": "Patrol the platform, waiting [b]{dwell}[/b] s at each end, [b]{edge_distance}[/b] px back from it",
		"jump_toward": "Jump toward ([b]{x}[/b], [b]{y}[/b])",
		"set_path_strategy": "Pick routes by [b]{strategy}[/b]",
		"add_gradual_portal": "Add gradual portal ([b]{from_x}[/b], [b]{from_y}[/b]) to ([b]{to_x}[/b], [b]{to_y}[/b]) at [b]{speed}[/b] px/s",
	})
	Lib.feature_verbs(sheet, ["build_nav_graph", "find_path_to"])
	return Lib.publish(src, "res://eventsheet_addons/platformer_pathfinding/platformer_pathfinding_behavior")


## Gives the last-appended ACE a call template that QUOTES its dropdown argument. A dropdown key is
## inserted into the call verbatim, so a String argument picked from a list of words has to carry its
## own quotes in the TEMPLATE - a quoted key does not survive the annotation round trip (the emitter
## wraps it again and the scanner strips one pair back off). Without this a row picking reach asked
## `find_path_to(x, y, reach)`, an undefined identifier, and the game did not parse. The call prefix
## is the pack's own class name, the same one the automatic template uses.
static func _quoted_argument(sheet: EventSheetResource, call: String) -> void:
	var fn: EventFunction = sheet.functions[sheet.functions.size() - 1]
	fn.codegen_template_override = "$%s.%s" % [sheet.custom_class_name, call]


## Pre-fills the last-appended ACE's parameter default (authoring-time metadata only).
static func _default(sheet: EventSheetResource, param_id: String, value: String) -> void:
	var fn: EventFunction = sheet.functions[sheet.functions.size() - 1]
	for parameter: ACEParam in fn.params:
		if parameter.id == param_id:
			parameter.default_value = value


## Sets the dropdown options[] on the last-appended ACE's parameter.
static func _param_options(sheet: EventSheetResource, param_id: String, choices: Array) -> void:
	var typed: Array[String] = []
	for choice: Variant in choices:
		typed.append(str(choice))
	var fn: EventFunction = sheet.functions[sheet.functions.size() - 1]
	for parameter: ACEParam in fn.params:
		if parameter.id == param_id:
			parameter.options = typed


## A word dropdown on the last-appended ACE: its options, the first option as the starting value
## (spelled as a word, because the template's own quotes receive it), and the quoting template.
static func _word(sheet: EventSheetResource, param_id: String, choices: Array, call: String) -> void:
	_param_options(sheet, param_id, choices)
	var fn: EventFunction = sheet.functions[sheet.functions.size() - 1]
	for parameter: ACEParam in fn.params:
		if parameter.id == param_id:
			parameter.default_value = str(choices[0])
			parameter.default_spelling = "word"
	_quoted_argument(sheet, call)


## A free-text parameter's starting value, spelled as GDScript (an unquoted template slot takes it
## verbatim, so an empty string is written with its quotes).
static func _code_default(sheet: EventSheetResource, param_id: String, value: String) -> void:
	var fn: EventFunction = sheet.functions[sheet.functions.size() - 1]
	for parameter: ACEParam in fn.params:
		if parameter.id == param_id:
			parameter.default_value = value
			parameter.default_spelling = "code"
