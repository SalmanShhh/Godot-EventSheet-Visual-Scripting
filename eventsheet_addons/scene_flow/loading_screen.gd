extends Control


func _ready() -> void:
	$Tip.text = $SceneFlow.loading_tip()
	$SceneFlow.loading_progress_changed.connect(_on_loading_progress_changed)
	$SceneFlow.loading_finished.connect(_on_loading_finished)


## @ace_hidden
func _on_loading_progress_changed() -> void:
	$LoadBar.value = $SceneFlow.loading_progress()


## @ace_hidden
func _on_loading_finished() -> void:
	$PressAnyKey.visible = true

# [b]The starter loading screen's sheet[/b], and the whole of it: the tip is read [b]once[/b] when the screen opens, the bar follows [b]On Loading Progress[/b], and [b]On Loading Finished[/b] shows the press-any-key line - which stays hidden unless the row that started the load asked to wait for a key. Three rows, on the [b]SceneFlow[/b] node standing in this scene. Copy the scene, restyle it, and this sheet comes with it.
