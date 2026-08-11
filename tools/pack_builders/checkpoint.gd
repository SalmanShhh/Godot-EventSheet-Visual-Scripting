# Pack builder - checkpoint (one pack per file; run via tools/build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")


## Checkpoint behavior: remembers one "put me back here" point for the host Node2D and returns
## the host to it on demand. The classic save-point / lava-respawn loop, with no bookkeeping in
## the sheet - Set Checkpoint Here at the flag, Respawn At Checkpoint when the player dies.
static func build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.behavior_mode = true
	sheet.host_class = "Node2D"
	sheet.custom_class_name = "CheckpointBehavior"
	sheet.class_description = "Remembers one point to send the host Node2D back to. Set Checkpoint Here marks the spot the host is standing on, Set Checkpoint At marks any point, and Respawn At Checkpoint teleports the host back and fires On Respawned. The starting position is captured on ready, so respawning works before the player ever touches a flag."
	sheet.addon_category = "Checkpoint"
	sheet.ace_expose_all_mode = "node"
	sheet.variables = {
		"capture_on_ready": {"type": "bool", "default": true, "exported": true, "description": "Remember where the host starts as its first checkpoint, so Respawn At Checkpoint works before any flag is touched."},
		"_checkpoint": {"type": "Vector2", "default": Vector2.ZERO, "exported": false},
		"_has_checkpoint": {"type": "bool", "default": false, "exported": false}
	}

	var about: CommentRow = CommentRow.new()
	about.text = "Checkpoint behavior: one remembered point per host. Set Checkpoint Here / At marks it, Respawn At Checkpoint sends the host back and fires On Respawned."
	sheet.events.append(about)

	var respawned_signal: SignalRow = SignalRow.new()
	respawned_signal.signal_name = "respawned"
	respawned_signal.trigger = true
	respawned_signal.ace_name = "On Respawned"
	respawned_signal.ace_category = "Checkpoint"
	sheet.events.append(respawned_signal)

	# The lazy capture, shared by Respawn At Checkpoint: a host that has never marked a checkpoint
	# treats wherever it stands the first time it is asked as its checkpoint, so Respawn can never
	# fling the host to the world origin. Hidden from the picker - it is plumbing, not a verb.
	var helper: RawCodeRow = RawCodeRow.new()
	helper.code = "\n".join(PackedStringArray([
		"## @ace_hidden",
		"func _ensure_checkpoint() -> void:",
		"\tif _has_checkpoint or host == null:",
		"\t\treturn",
		"\t_checkpoint = host.global_position",
		"\t_has_checkpoint = true"
	]))
	sheet.events.append(helper)

	# Capture the spawn point once, at ready, unless the user turned that off.
	var on_ready: EventRow = EventRow.new()
	on_ready.trigger_provider_id = "Core"
	on_ready.trigger_id = "OnReady"
	var on_ready_body: RawCodeRow = RawCodeRow.new()
	on_ready_body.code = "\n".join(PackedStringArray([
		"if capture_on_ready:",
		"\t_ensure_checkpoint()"
	]))
	on_ready.actions.append(on_ready_body)
	sheet.events.append(on_ready)

	Lib.append_function(sheet, "set_checkpoint_here", "Set Checkpoint Here", "Checkpoint",
		"Marks the spot the host is standing on right now as its checkpoint.",
		[], "\n".join(PackedStringArray([
		"if host == null:",
		"\treturn",
		"_checkpoint = host.global_position",
		"_has_checkpoint = true"
	])), "Set the checkpoint [b]here[/b]")

	Lib.append_function(sheet, "set_checkpoint_at", "Set Checkpoint At", "Checkpoint",
		"Marks any point in the world as the checkpoint, without moving the host.",
		[["point", "Vector2"]], "\n".join(PackedStringArray([
		"_checkpoint = point",
		"_has_checkpoint = true"
	])), "Set the checkpoint at [b]{point}[/b]")

	# Respawn: teleport home, then give the host a chance to clean itself up. The has_method("reset")
	# hook is the SAME duck-typed seam the Object Pool uses when it wakes a pooled node - a host that
	# defines reset() gets velocity / hp / timers cleared on every respawn, and this behavior never has
	# to know what any of those are. A host without reset() simply skips it.
	Lib.append_function(sheet, "respawn", "Respawn At Checkpoint", "Checkpoint",
		"Teleports the host back to its checkpoint and fires On Respawned. If the host defines a reset() method it is called too - the same duck-typed seam the Object Pool uses when it wakes a pooled node - so velocity, health, and timers clear without this behavior knowing about them.",
		[], "\n".join(PackedStringArray([
		"if host == null:",
		"\treturn",
		"_ensure_checkpoint()",
		"host.global_position = _checkpoint",
		"if host.has_method(&\"reset\"):",
		"\thost.call(&\"reset\")",
		"respawned.emit()"
	])), "[b]Respawn[/b] at the checkpoint")

	Lib.number(sheet, "checkpoint_position", "Checkpoint Position", "Checkpoint",
		"The point the host respawns at.", [], "return _checkpoint", TYPE_VECTOR2)

	Lib.feature_verbs(sheet, ["set_checkpoint_here", "respawn"])
	return Lib.save_pack(sheet, "res://eventsheet_addons/checkpoint/checkpoint_behavior")
