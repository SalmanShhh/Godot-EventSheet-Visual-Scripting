extends Control
## The options screen: volume sliders, a fullscreen toggle and a language picker.

signal closed

@export_enum("English", "Deutsch", "Français") var language: int = 0
@export_file_path("*.cfg") var defaults_file: String = ""
@export_file("*.tres") var theme_file := ""
@export_multiline var credits = ""
@export_placeholder("Player name") var player_name = ""
@export_custom(PROPERTY_HINT_RANGE, "0,1,0.05", PROPERTY_USAGE_DEFAULT) var master_volume = 0.8
@export_custom(PROPERTY_HINT_NONE, "") var raw_value = 0
@export_custom(PROPERTY_HINT_ENUM, "Low,Medium,High") var quality: int = 1
@export_storage var opened_count = 0

@onready var music_slider = $VBox/Music
@onready var sfx_slider: HSlider = $VBox/Sfx
@onready var fullscreen_box = %Fullscreen
@onready var _locales = TranslationServer.get_loaded_locales()


func _ready():
	opened_count += 1
	music_slider.value_changed.connect(_on_music_changed)
	sfx_slider.value_changed.connect(func(value): AudioServer.set_bus_volume_db(2, linear_to_db(value)))
	fullscreen_box.toggled.connect(_on_fullscreen_toggled)
	$VBox/Back.pressed.connect(_close)


func _unhandled_input(event):
	if event.is_action_pressed("ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()


func _on_music_changed(value):
	AudioServer.set_bus_volume_db(1, linear_to_db(value * master_volume))


func _on_fullscreen_toggled(on: bool) -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED)


func _close():
	closed.emit()
	hide()
