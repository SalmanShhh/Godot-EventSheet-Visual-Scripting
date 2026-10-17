@tool
extends Resource
## One weapon's numbers. Saved as .tres files under res://data/weapons/.

enum Kind {MELEE, RANGED, MAGIC}

@export var display_name := "Sword"
@export var kind: Kind = Kind.MELEE
@export_range(0, 100) var damage = 10
@export_range(0.0, 5.0, 0.1) var cooldown = 0.5
@export var icon: Texture2D
@export var projectile: PackedScene = null
@export var stats = {}
@export var tags: Array[StringName] = []
@export var upgrades: Array[Resource] = []
@export_group("Ammo", "ammo_")
@export var ammo_max = 30
@export var ammo_per_shot = 1
@export_group("")
@export_color_no_alpha var trail = Color(1, 1, 1)

var cached_dps:
	get:
		return damage / max(cooldown, 0.01)


func dps() -> float:
	return damage / max(cooldown, 0.01)


static func by_dps(a, b) -> bool:
	return a.dps() > b.dps()
