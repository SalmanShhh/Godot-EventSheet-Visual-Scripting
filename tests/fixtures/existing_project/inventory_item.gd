class_name InventoryItem
extends Resource
## One kind of thing the player can carry. Made in the Inspector as a .tres per item.

enum Rarity { COMMON, UNCOMMON, RARE, LEGENDARY }

@export var id: StringName = &""
@export var display_name := "Item"
@export_multiline var description := ""
@export var icon: Texture2D
@export var rarity: Rarity = Rarity.COMMON
@export_range(1, 99) var max_stack := 1
@export var value := 0
@export var tags: Array[String] = []


func is_stackable() -> bool:
	return max_stack > 1


func rarity_color() -> Color:
	match rarity:
		Rarity.UNCOMMON:
			return Color.LIME_GREEN
		Rarity.RARE:
			return Color.DODGER_BLUE
		Rarity.LEGENDARY:
			return Color.ORANGE
		_:
			return Color.WHITE


func sell_price(amount: int = 1) -> int:
	return int(value * amount * 0.5)


static func sort_by_value(a: InventoryItem, b: InventoryItem) -> bool:
	return a.value > b.value
