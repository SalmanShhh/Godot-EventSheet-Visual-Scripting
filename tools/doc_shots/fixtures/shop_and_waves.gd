extends Node2D

@export var table: Resource
@export var encounter: Resource
@onready var shop: PricedTableBehavior = $Shop
@onready var waves: EncounterTimelineBehavior = $Waves


func _ready() -> void:
	waves.on_encounter_finished.connect(_on_waves_finished)


func open_shop() -> void:
	shop.load_price_table(table)


func _on_buy_pressed() -> void:
	shop.buy("sword")


func _on_start_pressed() -> void:
	waves.load_encounter(encounter)
	waves.start_encounter()


func _on_waves_finished() -> void:
	print("cleared")
