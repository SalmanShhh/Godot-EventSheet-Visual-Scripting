extends CanvasLayer

var banner_text = ""
var shown = 0


func _ready():
	$RestartButton.pressed.connect(func(): restart())
	$Timer.timeout.connect(func():
		hide_banner()
		shown += 1
	)


func restart():
	get_tree().reload_current_scene()


func show_banner(text):
	banner_text = text
	$Banner.text = text


func hide_banner():
	banner_text = ""
	$Banner.text = ""
