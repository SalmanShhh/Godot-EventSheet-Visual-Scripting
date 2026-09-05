## @ace_category("UI")
## @ace_expose_all(node)
## @ace_version(1.0.0)
@icon("res://eventsheet_addons/hud_kit/icon.svg")
class_name HudKitBehavior
extends Node
## Drives a whole menu or HUD by node name with zero signal wiring. Attach it to your UI root and set labels, fill bars, show panels, flip screens, and pop toasts by passing the name string, while every descendant Button auto-wires into one On Button Pressed trigger.

## The node this behavior acts on (its parent). Required host: Node.
var host: Node = null

func _enter_tree() -> void:
	host = get_parent() as Node
	if host == null:
		push_warning("HudKitBehavior behavior requires a Node parent.")

## @ace_trigger
## @ace_name("On Button Pressed")
signal on_button_pressed

## On Ready, wire every descendant Button's pressed signal into On Button Pressed. Re-run with Connect Buttons after spawning UI.
@export var auto_connect_buttons: bool = true
var last_button_name: String = ""
## The colour a Set Needle needle is drawn in while the value is inside its warning mark.
@export var needle_colour: Color = Color(0.66000002622604, 0.80000001192093, 1.0, 1.0)
## The colour a Set Needle needle turns once the value has drifted past its warning mark.
@export var needle_warning_colour: Color = Color(1.0, 0.44999998807907, 0.37999999523163, 1.0)
## How long a toast stays before fading (seconds).
@export_range(0.2, 10, 0.1) var toast_seconds: float = 2.0
var ui_cache: Dictionary = {}
## The DamageTypeSet this game uses, if it has one. Pop Floating Text As takes a number's colour from it, so a fire number is orange without a colour being typed into the row. Leave it empty and those numbers are drawn white.
@export var damage_types: Resource = null
## How much bigger a number popped with the style "crit" is drawn, when no styles file names that style. The whole language of a critical hit in one number.
@export_range(1, 4, 0.1) var crit_text_scale: float = 1.6
## The FloatingTextStyles file this game uses, if it has one. Pop Floating Text As takes a number's size, colour, rise, shake and lifetime from it, so the manners a number is drawn in are one file you edit rather than five numbers repeated through the sheets. Leave it empty and the numbers are drawn the way they always were.
@export var text_styles: Resource = null

## Named-descendant lookup under the host, cached (freed nodes fall out on the next miss).
func _ui(control_name: String) -> Node:
	var cached: Variant = ui_cache.get(control_name)
	if cached is Node and is_instance_valid(cached):
		return cached
	var found: Node = host.find_child(control_name, true, false) if host != null else null
	if found != null:
		ui_cache[control_name] = found
	return found

func _ready() -> void:
	if auto_connect_buttons:
		connect_buttons()

## @ace_action
## @ace_name("Connect Buttons")
## @ace_category("UI")
## @ace_description("Wires every descendant Button's pressed signal into On Button Pressed (idempotent; re-run after spawning UI).")
## @ace_icon("res://eventsheet_addons/hud_kit/icon.svg")
## @ace_codegen_template("$HudKitBehavior.connect_buttons()")
func connect_buttons() -> void:
	if host == null:
		return
	var buttons: Array = []
	_collect_buttons(host, buttons)
	for button: BaseButton in buttons:
		var handler: Callable = _on_hud_button_pressed.bind(str(button.name))
		if not button.pressed.is_connected(handler):
			button.pressed.connect(handler)

## @ace_action
## @ace_featured
## @ace_name("Set Text")
## @ace_category("UI")
## @ace_description("Sets the text of a named Label, RichTextLabel, Button or LineEdit.")
## @ace_display_template("Set text of [b]{control_name}[/b] to [b]{text}[/b]")
## @ace_icon("res://eventsheet_addons/hud_kit/icon.svg")
## @ace_codegen_template("$HudKitBehavior.set_text({control_name}, {text})")
func set_text(control_name: String, text: String) -> void:
	var target: Node = _ui(control_name)
	if target != null:
		target.set("text", text)

## @ace_action
## @ace_featured
## @ace_name("Set Bar")
## @ace_category("UI")
## @ace_description("Sets a named ProgressBar/TextureProgressBar's value (max_value too when > 0).")
## @ace_display_template("Set bar [b]{bar_name}[/b] to [b]{value}[/b] of [b]{max_value}[/b]")
## @ace_icon("res://eventsheet_addons/hud_kit/icon.svg")
## @ace_codegen_template("$HudKitBehavior.set_bar({bar_name}, {value}, {max_value})")
func set_bar(bar_name: String, value: float, max_value: float) -> void:
	var target: Node = _ui(bar_name)
	if target is Range:
		if max_value > 0.0:
			(target as Range).max_value = max_value
		(target as Range).value = value

## @ace_action
## @ace_name("Show Panel")
## @ace_category("UI")
## @ace_description("Makes a named panel (any CanvasItem) visible.")
## @ace_icon("res://eventsheet_addons/hud_kit/icon.svg")
## @ace_codegen_template("$HudKitBehavior.show_panel({panel_name})")
func show_panel(panel_name: String) -> void:
	var target: Node = _ui(panel_name)
	if target is CanvasItem:
		(target as CanvasItem).visible = true

## @ace_action
## @ace_name("Hide Panel")
## @ace_category("UI")
## @ace_description("Hides a named panel (any CanvasItem).")
## @ace_icon("res://eventsheet_addons/hud_kit/icon.svg")
## @ace_codegen_template("$HudKitBehavior.hide_panel({panel_name})")
func hide_panel(panel_name: String) -> void:
	var target: Node = _ui(panel_name)
	if target is CanvasItem:
		(target as CanvasItem).visible = false

## @ace_action
## @ace_name("Toggle Panel")
## @ace_category("UI")
## @ace_description("Flips a named panel's visibility.")
## @ace_icon("res://eventsheet_addons/hud_kit/icon.svg")
## @ace_codegen_template("$HudKitBehavior.toggle_panel({panel_name})")
func toggle_panel(panel_name: String) -> void:
	var target: Node = _ui(panel_name)
	if target is CanvasItem:
		(target as CanvasItem).visible = not (target as CanvasItem).visible

## @ace_action
## @ace_name("Switch Screen")
## @ace_category("UI")
## @ace_description("Shows the named panel and hides its sibling panels - one call flips a whole menu screen.")
## @ace_icon("res://eventsheet_addons/hud_kit/icon.svg")
## @ace_codegen_template("$HudKitBehavior.switch_screen({panel_name})")
func switch_screen(panel_name: String) -> void:
	var target: Node = _ui(panel_name)
	if not (target is CanvasItem) or target.get_parent() == null:
		return
	for sibling: Node in target.get_parent().get_children():
		if sibling is CanvasItem:
			(sibling as CanvasItem).visible = (sibling == target)

## @ace_action
## @ace_featured
## @ace_name("Show Toast")
## @ace_category("UI")
## @ace_description("Pops a bottom-centre message that fades out after toast_seconds.")
## @ace_display_template("Show toast [b]{text}[/b]")
## @ace_icon("res://eventsheet_addons/hud_kit/icon.svg")
## @ace_codegen_template("$HudKitBehavior.show_toast({text})")
func show_toast(text: String) -> void:
	var toast: Label = Label.new()
	toast.text = text
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	toast.offset_top = -64.0
	toast.offset_bottom = -40.0
	toast.offset_left = -200.0
	toast.offset_right = 200.0
	if host != null:
		host.add_child(toast)
	else:
		add_child(toast)
	var fade: Tween = toast.create_tween()
	fade.tween_interval(maxf(0.2, toast_seconds))
	fade.tween_property(toast, "modulate:a", 0.0, 0.35)
	fade.tween_callback(toast.queue_free)

## @ace_action
## @ace_name("Pop Floating Text")
## @ace_category("UI")
## @ace_description("Pops a damage number or score popup at a position: it drifts up, fades out and frees itself. No label to place, no tween to write, no cleanup to remember.")
## @ace_display_template("Pop floating text [b]{text}[/b] at [b]{at}[/b]")
## @ace_icon("res://eventsheet_addons/hud_kit/icon.svg")
## @ace_codegen_template("$HudKitBehavior.pop_floating_text({text}, {at}, {color})")
func pop_floating_text(text: String, at: Vector2, color: Color) -> void:
	var label: Label = Label.new()
	label.text = text
	label.modulate = color
	label.position = at
	if host != null:
		host.add_child(label)
	else:
		add_child(label)
	var pop: Tween = label.create_tween()
	pop.set_parallel(true)
	pop.tween_property(label, "position:y", at.y - 24.0, 0.7)
	pop.tween_property(label, "modulate:a", 0.0, 0.7)
	pop.set_parallel(false)
	pop.tween_callback(label.queue_free)

## @ace_action
## @ace_name("Pop Floating Text As")
## @ace_category("UI")
## @ace_description("Pops a damage number in the colour its kind is drawn in - fire orange, ice blue - taken from the DamageTypeSet in this behaviour's Inspector rather than typed into the row. The style "crit" draws the number bigger, which is the whole language of a critical hit. Point Text Styles at a FloatingTextStyles file and the style also says how big, how far it rises, how hard it shakes and how long it stays. A style nothing names is drawn white and plain, so a game with neither file still gets its numbers.")
## @ace_display_template("Pop floating text [b]{text}[/b] as [b]{style}[/b] at [b]{at}[/b]")
## @ace_param_hint(style damage_type)
## @ace_icon("res://eventsheet_addons/hud_kit/icon.svg")
## @ace_codegen_template("$HudKitBehavior.pop_floating_text_as({text}, {style}, {at})")
func pop_floating_text_as(text: String, style: String, at: Vector2) -> void:
	var tint: Color = Color.WHITE
	# Duck-typed rather than cast: the DamageTypeSet class ships in a pack a game need not have
	# installed, and a HUD that refused to draw a number because of that would be worse than one
	# drawing it white.
	if damage_types != null and damage_types.has_method("colour_of"):
		tint = damage_types.call("colour_of", style)
	# The manners, out of the styles file when this game has one. A style the file does not name keeps
	# the numbers this row was always drawn with, so a half-filled file is not a broken HUD - and the
	# colour is handed IN, because a style may say it takes the colour of the damage that caused it.
	var size: float = crit_text_scale if style == "crit" else 1.0
	var rise: float = 24.0
	var shake: float = 0.0
	var life: float = 0.7
	if text_styles != null and text_styles.has_method("has_style") and text_styles.call("has_style", style):
		tint = text_styles.call("colour_of", style, tint)
		size = text_styles.call("size_of", style)
		rise = text_styles.call("rise_of", style)
		shake = text_styles.call("shake_of", style)
		life = text_styles.call("lifetime_of", style)
	var label: Label = Label.new()
	label.text = text
	label.modulate = tint
	label.position = at
	label.scale = Vector2(size, size)
	if host != null:
		host.add_child(label)
	else:
		add_child(label)
	var pop: Tween = label.create_tween()
	pop.set_parallel(true)
	pop.tween_property(label, "position:y", at.y - rise, life)
	pop.tween_property(label, "modulate:a", 0.0, life)
	# The shake is a wander in x that dies away as the number fades rather than a lean, because a
	# critical that rattles on its way up reads as a critical from across the screen.
	if shake > 0.0:
		var wander: Callable = func(phase: float) -> void:
			label.position.x = at.x + sin(phase * TAU * 5.0) * shake * (1.0 - phase)
		pop.tween_method(wander, 0.0, 1.0, life)
	pop.set_parallel(false)
	pop.tween_callback(label.queue_free)

## @ace_action
## @ace_name("Set Needle")
## @ace_category("UI")
## @ace_description("Shows a value from -1 to 1 as a needle in a named Control, with a mark at dead centre. The needle is built inside that Control the first time this runs, so the only thing the scene needs is an empty box of the right size. Past the warning mark the needle turns the warning colour, which is the whole of a balance meter's language.")
## @ace_display_template("Set needle [b]{needle_name}[/b] to [b]{value}[/b], warning past [b]{warn_at}[/b]")
## @ace_icon("res://eventsheet_addons/hud_kit/icon.svg")
## @ace_codegen_template("$HudKitBehavior.set_needle({needle_name}, {value}, {warn_at})")
func set_needle(needle_name: String, value: float, warn_at: float) -> void:
	var frame: Node = _ui(needle_name)
	if not frame is Control:
		return
	var box: Control = frame as Control
	var centre_mark: ColorRect = box.get_node_or_null("__needle_centre") as ColorRect
	if centre_mark == null:
		centre_mark = ColorRect.new()
		centre_mark.name = "__needle_centre"
		centre_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		centre_mark.color = Color(1.0, 1.0, 1.0, 0.25)
		box.add_child(centre_mark)
	var needle: ColorRect = box.get_node_or_null("__needle") as ColorRect
	if needle == null:
		needle = ColorRect.new()
		needle.name = "__needle"
		needle.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(needle)
	var width: float = maxf(box.size.x, 1.0)
	var height: float = maxf(box.size.y, 1.0)
	centre_mark.size = Vector2(2.0, height)
	centre_mark.position = Vector2(width * 0.5 - 1.0, 0.0)
	needle.size = Vector2(4.0, height)
	needle.position = Vector2((clampf(value, -1.0, 1.0) * 0.5 + 0.5) * width - 2.0, 0.0)
	needle.color = needle_warning_colour if absf(value) >= warn_at else needle_colour

## @ace_condition
## @ace_name("Button Is")
## @ace_icon("res://eventsheet_addons/hud_kit/icon.svg")
## @ace_codegen_template("$HudKitBehavior.button_is({button_name})")
func button_is(button_name: String) -> bool:
	return last_button_name == button_name

## @ace_condition
## @ace_name("Is Panel Visible")
## @ace_icon("res://eventsheet_addons/hud_kit/icon.svg")
## @ace_codegen_template("$HudKitBehavior.is_panel_visible({panel_name})")
func is_panel_visible(panel_name: String) -> bool:
	var target: Node = _ui(panel_name)
	return target is CanvasItem and (target as CanvasItem).visible

## @ace_expression
## @ace_name("Last Button Name")
## @ace_icon("res://eventsheet_addons/hud_kit/icon.svg")
## @ace_codegen_template("$HudKitBehavior.last_button_name_value()")
func last_button_name_value() -> String:
	return last_button_name

## @ace_expression
## @ace_name("Bar Value")
## @ace_icon("res://eventsheet_addons/hud_kit/icon.svg")
## @ace_codegen_template("$HudKitBehavior.bar_value({bar_name})")
func bar_value(bar_name: String) -> float:
	var target: Node = _ui(bar_name)
	return (target as Range).value if target is Range else 0.0

func _collect_buttons(node: Node, out: Array) -> void:
	if node is BaseButton:
		out.append(node)
	for child: Node in node.get_children():
		_collect_buttons(child, out)

func _on_hud_button_pressed(button_name: String) -> void:
	last_button_name = button_name
	on_button_pressed.emit()

# HUD Kit behavior: drive a menu or HUD by NODE NAME - set label text, fill bars, switch menu screens (show one panel, hide its siblings), pop auto-fading toasts - and every descendant Button reports through one On Button Pressed trigger, so a whole menu needs zero connected signals. Drop it under your UI root (CanvasLayer or Control).
