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
## How long a toast stays before fading (seconds).
@export_range(0.2, 10, 0.1) var toast_seconds: float = 2.0
var ui_cache: Dictionary = {}

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
