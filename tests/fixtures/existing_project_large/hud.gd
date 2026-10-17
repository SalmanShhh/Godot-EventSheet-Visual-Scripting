extends CanvasLayer
# The in-game HUD. Hearts, coins, a boss bar that only shows in boss rooms.

# @inspector_show_if show_boss_bar
@export_group("Boss bar")
@export var boss_name = "Boss"
@export var boss_bar_color = Color.RED
@export_group("")
@export var show_boss_bar = false:
	set(value):
		show_boss_bar = value
		notify_property_list_changed()
@export var heart_texture: Texture2D

var coins = 0
var hearts = 3

@onready var coin_label: Label = $Top/Coins
@onready var hearts_row = $Top/Hearts


func _validate_property(property: Dictionary) -> void:
	if str(property.name).begins_with("boss_") and not show_boss_bar:
		property.usage &= ~PROPERTY_USAGE_EDITOR


func _ready():
	_refresh()


func _on_score_changed(_score):
	coins = _score
	_refresh()


func _refresh():
	coin_label.text = "x %d" % coins
	for i in hearts_row.get_child_count():
		hearts_row.get_child(i).visible = i < hearts
