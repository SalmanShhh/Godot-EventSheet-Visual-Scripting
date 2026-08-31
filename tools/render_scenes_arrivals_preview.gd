# EventForge - render harness (dev tool) for the scenes pass: the 3D spawn sentence with a wave
# placed inside a box, and the minimap pair built on the two group-arrival triggers. Run NON-headless
# (a headless run cannot render):
#   godot --path . --script tools/render_scenes_arrivals_preview.gd
@tool
extends SceneTree

var _frames: int = 0
var _stage: int = 0
var _viewport: EventSheetViewport = null

## The box a wave is scattered inside, written once - the same expression the Random Place Inside Box
## row emits, so the picture shows the real line rather than a shortened one.
const INSIDE_BOX: String = "($SpawnBox as Node3D).to_global(Vector3(randf() - 0.5, randf() - 0.5," \
	+ " randf() - 0.5) * ((($SpawnBox as CollisionShape3D).shape as BoxShape3D).size" \
	+ " if $SpawnBox is CollisionShape3D else ($SpawnBox as CSGBox3D).size))"


func _init() -> void:
	root.title = "Scenes - arrivals"
	root.size = Vector2i(1100, 470)
	var modern_base := Color("#252525")
	var background: ColorRect = ColorRect.new()
	background.color = modern_base.darkened(0.25)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(background)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.position = Vector2(8, 8)
	scroll.size = Vector2(1084, 454)
	root.add_child(scroll)
	_viewport = EventSheetViewport.new()
	_viewport.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_viewport.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_viewport.set_ace_registry(EventSheetACERegistry.new())
	scroll.add_child(_viewport)
	_viewport.set_sheet(_styled(_wave_sheet()))
	process_frame.connect(_on_frame)


## Stage 1: the wave. A 3D spawn placed inside the box the level designer drew, and the ring row
## beside it for the enemy that arrives around the player instead.
func _wave_sheet() -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()

	var wave: EventRow = EventRow.new()
	wave.trigger_provider_id = "Core"
	wave.trigger_id = "OnProcess"
	wave.conditions.append(_cond("OnGroupFirstMember", {"group": "\"spawners\""}))
	wave.actions.append(_act("SpawnNewCopy3D", {
		"scene": "Enemy", "name": "new_enemy", "at": INSIDE_BOX, "parent": "$Enemies"
	}))
	sheet.events.append(wave)

	var ring: EventRow = EventRow.new()
	ring.trigger_provider_id = "Core"
	ring.trigger_id = "OnTimeout"
	ring.actions.append(_act("SpawnNewCopy3D", {
		"scene": "Enemy", "name": "flanker", "parent": "$Enemies",
		"at": "$Player.global_position + Vector3.FORWARD.rotated(Vector3.UP, randf() * TAU) * 8.0"
	}))
	sheet.events.append(ring)

	return sheet


## Stage 2: the minimap pair. A node joining the group gets a marker and is wired for its own death;
## a node leaving takes its marker back off. Two triggers, one group, no bookkeeping in the middle.
func _minimap_sheet() -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()

	var joins: EventRow = EventRow.new()
	joins.trigger_provider_id = "Core"
	joins.trigger_id = "OnNodeJoinsGroup"
	joins.trigger_params = {"group": "\"minimap\""}
	joins.conditions.append(_cond("IsInGroup", {"target": "node", "group": "\"minimap\""},
		"{target}.is_in_group({group})"))
	joins.actions.append(_act("CallMethod", {
		"target": "$UI/Minimap", "method": "add_marker", "args": "node"
	}))
	joins.actions.append(_act("ConnectSignalUnique", {
		"source": "node", "signal": "tree_exiting", "callable": "_on_marked_node_leaving"
	}))
	sheet.events.append(joins)

	var leaves: EventRow = EventRow.new()
	leaves.trigger_provider_id = "Core"
	leaves.trigger_id = "OnNodeLeavesGroup"
	leaves.trigger_params = {"group": "\"minimap\""}
	leaves.conditions.append(_cond("IsInGroup", {"target": "node", "group": "\"minimap\""},
		"{target}.is_in_group({group})"))
	leaves.actions.append(_act("CallMethod", {
		"target": "$UI/Minimap", "method": "remove_marker", "args": "node"
	}))
	sheet.events.append(leaves)

	return sheet


## The one theme both pictures are shot in, so the pair reads as one set.
func _styled(sheet: EventSheetResource) -> EventSheetResource:
	var modern_base := Color("#252525")
	var style := EventSheetEditorStyle.new()
	style.ensure_defaults()
	EventSheetGodotTheme.apply(style, modern_base, modern_base.darkened(0.15),
		modern_base.darkened(0.25), Color("#569eff"), Color("#ced0d2"))
	sheet.editor_style = style
	return sheet


static func _cond(ace_id: String, params: Dictionary, template: String = "") -> ACECondition:
	var condition: ACECondition = ACECondition.new()
	condition.provider_id = "Core"
	condition.ace_id = ace_id
	condition.params = params
	condition.codegen_template = template
	return condition


static func _act(ace_id: String, params: Dictionary) -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = ace_id
	action.params = params
	return action


func _on_frame() -> void:
	_frames += 1
	if _frames < 8:
		return
	if _stage == 0:
		root.get_texture().get_image().save_png("res://docs/images/scenes-spawn-3d.png")
		print("[preview] 3D spawn saved")
		_stage = 1
		_frames = 0
		_viewport.set_sheet(_styled(_minimap_sheet()))
		return
	root.get_texture().get_image().save_png("res://docs/images/scenes-group-arrivals.png")
	print("[preview] group arrivals saved")
	quit(0)
