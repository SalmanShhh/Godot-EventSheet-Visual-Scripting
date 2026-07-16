@icon("res://eventsheet_addons/skin_catalog_resource/icon.svg")
class_name SkinCatalogResource
extends Resource
## A cosmetics catalog as a data asset for the SkinVault pack. Fill the rarities and skins grids in the Inspector, save as a .tres, and load it with the SkinVault Load Catalog action or the Skin Catalog Loader behavior.

## One row per rarity: its name, a roll weight (higher = commoner), and a tier rank (higher = rarer; pity guarantees a tier at or above the pity rarity).
@export_custom(PROPERTY_HINT_NONE, "eventsheet:table:name=String,weight=float,tier=int") var rarities: Array = []
## One row per skin: a unique id, a display name, its rarity (must match a rarity above), a cost (0 = not purchasable), and comma-separated tags.
@export_custom(PROPERTY_HINT_NONE, "eventsheet:table:id=String,name=String,rarity=String,cost=float,tags=String") var skins: Array = []
