## @ace_tags(cosmetics, gacha)
## @ace_category("SkinVault")
## @ace_version(1.0.0)
@icon("res://eventsheet_addons/skin_vault/icon.svg")
class_name SkinVaultAddon
extends Node
## Cosmetic-ownership manager for gacha, loot-box, and unlockable-skin systems, registered as the SkinVault autoload singleton. It owns what the player has, the weighted roll, and the pity streak - you build the shop and popups, it tells you what was won and when.

## @ace_trigger
## @ace_name("On Skin Rolled")
## @ace_category("SkinVault")
signal on_skin_rolled
## @ace_trigger
## @ace_name("On Skin Unlocked")
## @ace_category("SkinVault")
signal on_skin_unlocked
## @ace_trigger
## @ace_name("On Purchase Requested")
## @ace_category("SkinVault")
signal on_purchase_requested
## @ace_trigger
## @ace_name("On Purchase Cancelled")
## @ace_category("SkinVault")
signal on_purchase_cancelled
## @ace_trigger
## @ace_name("On Skin Revoked")
## @ace_category("SkinVault")
signal on_skin_revoked
## @ace_trigger
## @ace_name("On Pool Empty")
## @ace_category("SkinVault")
signal on_pool_empty

## Guarantee a high-rarity roll after a streak of misses.
@export_group("Pity")
@export var enable_pity: bool = true
## The rarity (by name) that pity guarantees at or above.
@export_group("Pity")
@export var pity_rarity: String = "epic"
## Misses in a row before the next roll is guaranteed pity-rarity-or-better.
@export_group("Pity")
@export_range(1, 200, 1) var pity_threshold: int = 10

# name -> {weight, tier}. Tier is an explicit rank so pity never depends on registration order.
var _rarities: Dictionary = {}
# id -> {name, rarity, cost, tags:PackedStringArray}.
var _skins: Dictionary = {}
# id -> true (the owned set).
var _owned: Dictionary = {}
var _pity: int = 0
# Last-event context (read via getter expressions inside the matching trigger).
var _rolled_id: String = ""
var _unlocked_id: String = ""
var _unlock_method: String = ""
var _req_id: String = ""
var _revoked_id: String = ""
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _use_shared: bool = false

func _ready() -> void:
	_rng.randomize()

## @ace_action
## @ace_name("Register Rarity")
## @ace_category("SkinVault")
## @ace_description("Registers a rarity: a roll weight (higher = commoner) and a tier rank (higher = rarer; pity guarantees a tier at or above the pity rarity).")
## @ace_icon("res://eventsheet_addons/skin_vault/icon.svg")
## @ace_codegen_template("SkinVault.register_rarity({name}, {weight}, {tier})")
func register_rarity(name: String, weight: float, tier: int) -> void:
	_rarities[name] = {"weight": maxf(weight, 0.0), "tier": tier}

## @ace_action
## @ace_name("Use Advanced Random")
## @ace_category("SkinVault")
## @ace_description("When on, rolls draw from the shared AdvancedRandom autoload instead of this pack's own generator, so one seed drives your whole game's randomness. When off (the default) it uses its own generator. Needs the Advanced Random pack installed (it safely falls back to the local generator if not).")
## @ace_icon("res://eventsheet_addons/skin_vault/icon.svg")
## @ace_codegen_template("SkinVault.use_advanced_random({enabled})")
func use_advanced_random(enabled: bool) -> void:
	_use_shared = enabled

## @ace_action
## @ace_featured
## @ace_name("Register Skin")
## @ace_category("SkinVault")
## @ace_description("Registers a skin: a unique id, a display name, its rarity (must be registered), a cost (0 = not purchasable), and comma-separated tags.")
## @ace_icon("res://eventsheet_addons/skin_vault/icon.svg")
## @ace_codegen_template("SkinVault.register_skin({id}, {display_name}, {rarity}, {cost}, {tags})")
func register_skin(id: String, display_name: String, rarity: String, cost: float, tags: String) -> void:
	var tag_list: PackedStringArray = PackedStringArray()
	for raw: String in tags.split(",", false):
		var trimmed: String = raw.strip_edges()
		if not trimmed.is_empty():
			tag_list.append(trimmed)
	_skins[id] = {"name": display_name, "rarity": rarity, "cost": cost, "tags": tag_list}

## @ace_action
## @ace_name("Load Catalog")
## @ace_category("SkinVault")
## @ace_description("Registers a whole catalog (rarities + skins) from a Skin Catalog resource (a .tres you filled in the Inspector) in one step. The data-driven alternative to a string of Register Rarity + Register Skin actions.")
## @ace_icon("res://eventsheet_addons/skin_vault/icon.svg")
## @ace_codegen_template("SkinVault.load_catalog({catalog})")
func load_catalog(catalog: Resource) -> void:
	if catalog == null:
		push_warning("SkinVault: Load Catalog was given no resource.")
		return
	var rarity_rows: Variant = catalog.get("rarities")
	if rarity_rows is Array:
		for row: Variant in (rarity_rows as Array):
			if row is Dictionary and not str((row as Dictionary).get("name", "")).is_empty():
				register_rarity(str((row as Dictionary).get("name", "")), float((row as Dictionary).get("weight", 1.0)), int((row as Dictionary).get("tier", 0)))
	var skin_rows: Variant = catalog.get("skins")
	if skin_rows is Array:
		for row: Variant in (skin_rows as Array):
			if row is Dictionary and not str((row as Dictionary).get("id", "")).is_empty():
				register_skin(str((row as Dictionary).get("id", "")), str((row as Dictionary).get("name", "")), str((row as Dictionary).get("rarity", "")), float((row as Dictionary).get("cost", 0.0)), str((row as Dictionary).get("tags", "")))

## @ace_action
## @ace_featured
## @ace_name("Roll")
## @ace_category("SkinVault")
## @ace_description("Rolls a weighted-random UNOWNED skin (optional tag filter; "" = any) and grants it. Applies pity, then fires On Skin Rolled and On Skin Unlocked. Fires On Pool Empty if nothing is left.")
## @ace_icon("res://eventsheet_addons/skin_vault/icon.svg")
## @ace_codegen_template("SkinVault.roll({tag})")
func roll(tag: String) -> void:
	var pool: Array = _pool(tag)
	if pool.is_empty():
		on_pool_empty.emit()
		return
	if enable_pity and _pity >= pity_threshold:
		var min_tier: int = _tier(pity_rarity)
		var boosted: Array = []
		for id: String in pool:
			if _tier(_skins[id].rarity) >= min_tier:
				boosted.append(id)
		if not boosted.is_empty():
			pool = boosted
	var total: float = 0.0
	for id: String in pool:
		total += maxf(_weight(_skins[id].rarity), 0.0001)
	var r: float = _rand_float() * total
	var picked: String = str(pool[pool.size() - 1])
	for id: String in pool:
		r -= maxf(_weight(_skins[id].rarity), 0.0001)
		if r <= 0.0:
			picked = id
			break
	if _tier(_skins[picked].rarity) >= _tier(pity_rarity):
		_pity = 0
	else:
		_pity += 1
	_rolled_id = picked
	on_skin_rolled.emit()
	_grant(picked, "roll")

## @ace_action
## @ace_name("Grant")
## @ace_category("SkinVault")
## @ace_description("Unlocks a skin for free (fires On Skin Unlocked). Does nothing if already owned.")
## @ace_icon("res://eventsheet_addons/skin_vault/icon.svg")
## @ace_codegen_template("SkinVault.grant({skin_id})")
func grant(skin_id: String) -> void:
	_grant(skin_id, "grant")

## @ace_action
## @ace_name("Revoke")
## @ace_category("SkinVault")
## @ace_description("Removes a skin from the owned set (fires On Skin Revoked).")
## @ace_icon("res://eventsheet_addons/skin_vault/icon.svg")
## @ace_codegen_template("SkinVault.revoke({skin_id})")
func revoke(skin_id: String) -> void:
	if _owned.has(skin_id):
		_owned.erase(skin_id)
		_revoked_id = skin_id
		on_skin_revoked.emit()

## @ace_action
## @ace_featured
## @ace_name("Purchase")
## @ace_category("SkinVault")
## @ace_description("Starts a purchase: fires On Purchase Requested carrying the skin id + cost. Check your wallet there, then call Confirm or Cancel Purchase. (SkinVault never touches currency itself.)")
## @ace_icon("res://eventsheet_addons/skin_vault/icon.svg")
## @ace_codegen_template("SkinVault.purchase({skin_id})")
func purchase(skin_id: String) -> void:
	if _owned.has(skin_id) or not _skins.has(skin_id):
		return
	_req_id = skin_id
	on_purchase_requested.emit()

## @ace_action
## @ace_name("Confirm Purchase")
## @ace_category("SkinVault")
## @ace_description("Completes a purchase and grants the skin (fires On Skin Unlocked with method "purchase").")
## @ace_icon("res://eventsheet_addons/skin_vault/icon.svg")
## @ace_codegen_template("SkinVault.confirm_purchase({skin_id})")
func confirm_purchase(skin_id: String) -> void:
	_grant(skin_id, "purchase")

## @ace_action
## @ace_name("Cancel Purchase")
## @ace_category("SkinVault")
## @ace_description("Cancels a pending purchase (fires On Purchase Cancelled).")
## @ace_icon("res://eventsheet_addons/skin_vault/icon.svg")
## @ace_codegen_template("SkinVault.cancel_purchase({skin_id})")
func cancel_purchase(skin_id: String) -> void:
	_req_id = skin_id
	on_purchase_cancelled.emit()

## @ace_action
## @ace_name("Reset Pity")
## @ace_category("SkinVault")
## @ace_description("Sets the pity counter back to 0.")
## @ace_icon("res://eventsheet_addons/skin_vault/icon.svg")
## @ace_codegen_template("SkinVault.reset_pity()")
func reset_pity() -> void:
	_pity = 0

## @ace_action
## @ace_name("Load Owned")
## @ace_category("SkinVault")
## @ace_description("Restores the owned set from a comma-separated id list (pair with the Owned Ids expression to save).")
## @ace_icon("res://eventsheet_addons/skin_vault/icon.svg")
## @ace_codegen_template("SkinVault.load_owned({owned_csv})")
func load_owned(owned_csv: String) -> void:
	_owned.clear()
	for raw: String in owned_csv.split(",", false):
		var id: String = raw.strip_edges()
		if not id.is_empty():
			_owned[id] = true

## @ace_action
## @ace_name("Set Pity Count")
## @ace_category("SkinVault")
## @ace_description("Restores the pity counter (for save/load).")
## @ace_icon("res://eventsheet_addons/skin_vault/icon.svg")
## @ace_codegen_template("SkinVault.set_pity_count({count})")
func set_pity_count(count: int) -> void:
	_pity = maxi(count, 0)

## @ace_condition
## @ace_name("Is Owned")
## @ace_category("SkinVault")
## @ace_description("Whether the player owns a skin.")
## @ace_icon("res://eventsheet_addons/skin_vault/icon.svg")
## @ace_codegen_template("SkinVault.is_owned({skin_id})")
func is_owned(skin_id: String) -> bool:
	return _owned.has(skin_id)

## @ace_condition
## @ace_name("Is Registered")
## @ace_category("SkinVault")
## @ace_description("Whether a skin exists in the catalog.")
## @ace_icon("res://eventsheet_addons/skin_vault/icon.svg")
## @ace_codegen_template("SkinVault.is_registered({skin_id})")
func is_registered(skin_id: String) -> bool:
	return _skins.has(skin_id)

## @ace_condition
## @ace_name("Is Unlockable")
## @ace_category("SkinVault")
## @ace_description("Whether a skin is registered but not yet owned (drives lock icons).")
## @ace_icon("res://eventsheet_addons/skin_vault/icon.svg")
## @ace_codegen_template("SkinVault.is_unlockable({skin_id})")
func is_unlockable(skin_id: String) -> bool:
	return _skins.has(skin_id) and not _owned.has(skin_id)

## @ace_condition
## @ace_name("Is Pool Empty")
## @ace_category("SkinVault")
## @ace_description("Whether there are no unowned skins left to roll (optional tag filter).")
## @ace_icon("res://eventsheet_addons/skin_vault/icon.svg")
## @ace_codegen_template("SkinVault.is_pool_empty({tag})")
func is_pool_empty(tag: String) -> bool:
	return _pool(tag).is_empty()

## @ace_expression
## @ace_name("Total Skins")
## @ace_category("SkinVault")
## @ace_description("How many skins are registered.")
## @ace_icon("res://eventsheet_addons/skin_vault/icon.svg")
## @ace_codegen_template("SkinVault.total_skins()")
func total_skins() -> int:
	return _skins.size()

## @ace_expression
## @ace_name("Owned Count")
## @ace_category("SkinVault")
## @ace_description("How many skins the player owns.")
## @ace_icon("res://eventsheet_addons/skin_vault/icon.svg")
## @ace_codegen_template("SkinVault.owned_count()")
func owned_count() -> int:
	return _owned.size()

## @ace_expression
## @ace_name("Pool Count")
## @ace_category("SkinVault")
## @ace_description("How many unowned skins remain (optional tag filter).")
## @ace_icon("res://eventsheet_addons/skin_vault/icon.svg")
## @ace_codegen_template("SkinVault.pool_count({tag})")
func pool_count(tag: String) -> int:
	return _pool(tag).size()

## @ace_expression
## @ace_name("Skin Name")
## @ace_category("SkinVault")
## @ace_description("A skin's display name.")
## @ace_icon("res://eventsheet_addons/skin_vault/icon.svg")
## @ace_codegen_template("SkinVault.skin_name({skin_id})")
func skin_name(skin_id: String) -> String:
	return str(_skins[skin_id].name) if _skins.has(skin_id) else ""

## @ace_expression
## @ace_name("Skin Rarity")
## @ace_category("SkinVault")
## @ace_description("A skin's rarity name.")
## @ace_icon("res://eventsheet_addons/skin_vault/icon.svg")
## @ace_codegen_template("SkinVault.skin_rarity({skin_id})")
func skin_rarity(skin_id: String) -> String:
	return str(_skins[skin_id].rarity) if _skins.has(skin_id) else ""

## @ace_expression
## @ace_name("Skin Cost")
## @ace_category("SkinVault")
## @ace_description("A skin's cost (0 if not purchasable / unknown).")
## @ace_icon("res://eventsheet_addons/skin_vault/icon.svg")
## @ace_codegen_template("SkinVault.skin_cost({skin_id})")
func skin_cost(skin_id: String) -> float:
	return float(_skins[skin_id].cost) if _skins.has(skin_id) else 0.0

## @ace_expression
## @ace_name("Pity Counter")
## @ace_category("SkinVault")
## @ace_description("The current miss streak toward pity.")
## @ace_icon("res://eventsheet_addons/skin_vault/icon.svg")
## @ace_codegen_template("SkinVault.pity_counter()")
func pity_counter() -> int:
	return _pity

## @ace_expression
## @ace_name("Pity Progress")
## @ace_category("SkinVault")
## @ace_description("Progress toward pity as 0.0 - 1.0 (for a bar).")
## @ace_icon("res://eventsheet_addons/skin_vault/icon.svg")
## @ace_codegen_template("SkinVault.pity_progress()")
func pity_progress() -> float:
	return clampf(float(_pity) / float(pity_threshold), 0.0, 1.0) if pity_threshold > 0 else 0.0

## @ace_expression
## @ace_name("Owned Ids")
## @ace_category("SkinVault")
## @ace_description("The owned skin ids as a comma-separated string (pair with Load Owned to save).")
## @ace_icon("res://eventsheet_addons/skin_vault/icon.svg")
## @ace_codegen_template("SkinVault.owned_ids()")
func owned_ids() -> String:
	return ",".join(PackedStringArray(_owned.keys()))

## @ace_expression
## @ace_name("Rolled Id")
## @ace_category("SkinVault")
## @ace_description("The skin just rolled (inside On Skin Rolled).")
## @ace_icon("res://eventsheet_addons/skin_vault/icon.svg")
## @ace_codegen_template("SkinVault.rolled_id()")
func rolled_id() -> String:
	return _rolled_id

## @ace_expression
## @ace_name("Unlocked Id")
## @ace_category("SkinVault")
## @ace_description("The skin just unlocked (inside On Skin Unlocked).")
## @ace_icon("res://eventsheet_addons/skin_vault/icon.svg")
## @ace_codegen_template("SkinVault.unlocked_id()")
func unlocked_id() -> String:
	return _unlocked_id

## @ace_expression
## @ace_name("Unlock Method")
## @ace_category("SkinVault")
## @ace_description("How it was unlocked - "roll", "grant", or "purchase" (inside On Skin Unlocked).")
## @ace_icon("res://eventsheet_addons/skin_vault/icon.svg")
## @ace_codegen_template("SkinVault.unlock_method()")
func unlock_method() -> String:
	return _unlock_method

## @ace_expression
## @ace_name("Requested Id")
## @ace_category("SkinVault")
## @ace_description("The skin being purchased (inside On Purchase Requested / Cancelled).")
## @ace_icon("res://eventsheet_addons/skin_vault/icon.svg")
## @ace_codegen_template("SkinVault.requested_id()")
func requested_id() -> String:
	return _req_id

## @ace_expression
## @ace_name("Requested Cost")
## @ace_category("SkinVault")
## @ace_description("The cost of the requested purchase (inside On Purchase Requested).")
## @ace_icon("res://eventsheet_addons/skin_vault/icon.svg")
## @ace_codegen_template("SkinVault.requested_cost()")
func requested_cost() -> float:
	return float(_skins[_req_id].cost) if _skins.has(_req_id) else 0.0

## @ace_expression
## @ace_name("Revoked Id")
## @ace_category("SkinVault")
## @ace_description("The skin just revoked (inside On Skin Revoked).")
## @ace_icon("res://eventsheet_addons/skin_vault/icon.svg")
## @ace_codegen_template("SkinVault.revoked_id()")
func revoked_id() -> String:
	return _revoked_id

func _rand_float() -> float:
	# Randomness source: the shared AdvancedRandom autoload when Use Advanced Random is on and the
	# pack is installed, otherwise this pack's own generator (the default - unchanged behaviour).
	if _use_shared and is_inside_tree():
		var shared: Node = get_node_or_null("/root/AdvancedRandom")
		if shared != null:
			return shared.random_value()
	return _rng.randf()

func _tier(rarity: String) -> int:
	return int(_rarities.get(rarity, {}).get("tier", 0))

func _weight(rarity: String) -> float:
	return float(_rarities.get(rarity, {}).get("weight", 1.0))

func _pool(tag: String) -> Array:
	# The unowned skins (optionally filtered to a tag) that a roll may award.
	var out: Array = []
	for id: String in _skins:
		if _owned.has(id):
			continue
		if tag.is_empty() or tag in (_skins[id].tags as PackedStringArray):
			out.append(id)
	return out

func _grant(id: String, method: String) -> void:
	# Adds a skin to the owned set (if new) and fires On Skin Unlocked with the method.
	if _owned.has(id) or not _skins.has(id):
		return
	_owned[id] = true
	_unlocked_id = id
	_unlock_method = method
	on_skin_unlocked.emit()

## @ace_hidden
func save_state() -> Dictionary:
	# Save-state seam: the Save System walks any node in its persist group (or targeted
	# by Save/Load Node State) and duck-types these two methods. Plain data only.
	return {
		"owned": _owned.duplicate(true),
		"pity": _pity
	}

## @ace_hidden
func load_state(state: Dictionary) -> void:
	if state.is_empty():
		return
	_owned = (state.get("owned", {}) as Dictionary).duplicate(true)
	_pity = int(state.get("pity", 0))

# SkinVault: register as the SkinVault autoload. Register rarities + skins, then unlock via Roll (weighted, with pity), Purchase (your wallet confirms), or Grant. React with On Skin Unlocked. It owns ownership; you build the UI. This pack is an event sheet - extend it by editing it.
