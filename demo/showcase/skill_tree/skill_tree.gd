class_name SkillTreeShowcase
extends Control

## The Skill Tree data asset this screen draws.
@export var tree: Resource = null
var upgrades: Node = null
var buttons: Dictionary = {}
## A skill whose prerequisites are not met yet.
@export var locked_tint: Color = Color(0.44999998807907, 0.44999998807907, 0.5, 1.0)
## A skill that can be unlocked right now.
@export var affordable_tint: Color = Color(1.0, 0.86000001430511, 0.40000000596046, 1.0)
## A skill already taken.
@export var unlocked_tint: Color = Color(0.55000001192093, 0.89999997615814, 0.60000002384186, 1.0)

func _ready() -> void:
	upgrades = $Upgrades
	upgrades.load_skill_tree(tree)
	upgrades.apply_grants_to($Runner/Stats)
	$HudKit.on_button_pressed.connect(unlock_pressed)
	lay_out()

func _process(delta: float) -> void:
	refresh_states()
	$HudKit.set_text("PointsValue", "Skill points left: %d" % upgrades.skill_points_left())
	$HudKit.set_text("SpeedValue", "Speed: %0.0f" % $Runner/Stats.stat_total("speed"))

## @ace_hidden
func lay_out() -> void:
	for index: int in range(upgrades.skill_count()):
		var id: String = upgrades.skill_id_at(index)
		var button: Button = Button.new()
		button.name = id
		button.text = upgrades.skill_name_of(id)
		button.size = Vector2(150.0, 40.0)
		button.position = Vector2(40.0 + float(upgrades.skill_column_of(id)) * 190.0, 60.0 + float(upgrades.skill_row_of(id)) * 74.0)
		button.mouse_entered.connect(show_grants.bind(id))
		$TreeNodes.add_child(button)
		buttons[id] = button
	$HudKit.connect_buttons()
	refresh_states()
	queue_redraw()

## @ace_hidden
func refresh_states() -> void:
	for id: String in buttons:
		var button: Button = buttons[id]
		var takeable: bool = upgrades.can_unlock_skill(id)
		if upgrades.is_skill_unlocked(id):
			button.modulate = unlocked_tint
		elif takeable:
			button.modulate = affordable_tint
		else:
			button.modulate = locked_tint
		button.disabled = not takeable

## @ace_hidden
func unlock_pressed() -> void:
	upgrades.unlock_skill($HudKit.last_button_name_value())
	refresh_states()

## @ace_hidden
func show_grants(id: String) -> void:
	var grants: String = upgrades.skill_grants_text(id)
	$HudKit.set_text("GrantsValue", grants if not grants.is_empty() else "a perk the runner asks about")

## @ace_hidden
func _draw() -> void:
	for id: String in buttons:
		var button: Button = buttons[id]
		for part: String in upgrades.skill_requires_text(id).split(",", false):
			var earlier: Variant = buttons.get(part.strip_edges())
			if not (earlier is Button):
				continue
			var earlier_box: Rect2 = (earlier as Button).get_global_rect()
			var box: Rect2 = button.get_global_rect()
			# Edge to edge rather than centre to centre, so a line never crosses a node's own name.
			var from: Vector2 = Vector2(earlier_box.end.x, earlier_box.get_center().y) - global_position
			var to: Vector2 = Vector2(box.position.x, box.get_center().y) - global_position
			draw_line(from, to, Color(0.5, 0.62, 0.78), 2.0)

# [b]Skill Tree[/b] - a data asset, laid out. Six skills in two branches live in adventurer_tree.tres with their costs, their prerequisites and what they grant. The screen spawns one button per skill and draws a line to each one it requires; grey means a prerequisite is missing, gold means it can be taken now, green means it is taken. Clicking one is a single Unlock row, which spends a point, records the level and hands the grant to StatForge - so Swift makes the runner faster with no formula written anywhere, and Double Jump grants nothing at all because the runner asks about it directly. Arrow keys move the runner, Space jumps.
