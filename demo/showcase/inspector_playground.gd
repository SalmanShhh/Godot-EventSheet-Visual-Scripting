class_name InspectorPlayground
extends Node2D

## Drift direction + speed — drag the dial.
@export_group("Aim")
@export_custom(PROPERTY_HINT_NONE, "eventsheet:vector_dial:120") var aim_dir: Vector2 = Vector2(70.0, -35.0)
## Emblem texture — drop one in.
@export_group("Body")
@export_custom(PROPERTY_HINT_NONE, "eventsheet:texture_preview") var body_icon: Texture2D = null
## Hull colour — click a swatch.
@export_group("Body")
@export_custom(PROPERTY_HINT_NONE, "eventsheet:swatch_row") var body_tint: Color = Color(0.22745098173618, 0.65098041296005, 0.87843137979507, 1.0)
## Pulse shape over time.
@export_group("Stats")
@export_subgroup("Tuning")
@export_custom(PROPERTY_HINT_NONE, "eventsheet:curve_editor") var stat_curve: Curve = null
## Health — drag the bar.
@export_group("Stats")
@export_subgroup("Tuning")
@export_custom(PROPERTY_HINT_NONE, "eventsheet:progress_bar:0:100") var stat_health: int = 80
## Drift amplitude — drag the bar.
@export_group("Stats")
@export_subgroup("Tuning")
@export_custom(PROPERTY_HINT_NONE, "eventsheet:progress_bar:0:200") var stat_speed: float = 90.0

func _ready() -> void:
	if body_icon != null:
		$Emblem.texture = body_icon

func _process(delta: float) -> void:
	var t: float = Time.get_ticks_msec() / 1000.0
	var phase: float = sin(t * 2.0) * 0.5 + 0.5
	if stat_curve != null and stat_curve.point_count > 0:
		phase = stat_curve.sample(phase)
	$Body.position = aim_dir.normalized() * (phase - 0.5) * stat_speed
	$Body.rotation = aim_dir.angle()
	$Body.color = body_tint
	$Body.scale = Vector2.ONE * (0.6 + stat_health / 100.0)

# [b]Inspector Playground[/b] — select this node and open the Inspector: every exported variable uses a [b]custom drawer[/b] (a direction dial, a colour swatch row, a texture preview, a curve, progress bars) sorted into [b]@export_group[/b] sections. Tweak them and press Play — the ship drifts along the dial, scales with health, and wears your colour. All from designer-tweakable variables, zero code.
