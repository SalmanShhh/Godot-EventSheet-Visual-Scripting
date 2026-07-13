# Pack builder - skin_vault (one pack per file; run via tools/build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")


## SkinVault: a cosmetic-ownership manager as an AUTOLOAD sheet (SkinVault) for gacha/unlock systems.
## It owns WHAT the player has and can still get - you build the UI. Register rarities + skins, then
## unlock via three paths (Roll / Purchase / Grant), all funnelling into On Skin Unlocked. Ported from
## the Construct 3 addon, Godot-native + beginner-friendly:
##  - Discrete typed ACEs (Register Rarity / Register Skin) instead of the JSON-blob registration the
##    C3 version used.
##  - Pity uses an explicit rarity TIER integer, so "guarantee an epic-or-better after N misses" no
##    longer depends on the fragile registration ORDER the C3 addon relied on.
##  - Currency stays external: Purchase fires On Purchase Requested carrying the cost; YOUR wallet
##    (e.g. the Currency Ledger pack) decides, then calls Confirm/Cancel Purchase.
static func build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.autoload_mode = true
	sheet.autoload_name = "SkinVault"
	sheet.host_class = "Node"
	sheet.custom_class_name = "SkinVaultAddon"
	sheet.addon_category = "SkinVault"
	sheet.addon_tags = PackedStringArray(["cosmetics", "gacha"])
	sheet.variables = {
		"enable_pity": {"type": "bool", "default": true, "exported": true,
			"attributes": {"tooltip": "Guarantee a high-rarity roll after a streak of misses.", "group": "Pity"}},
		"pity_threshold": {"type": "int", "default": 10, "exported": true,
			"attributes": {"tooltip": "Misses in a row before the next roll is guaranteed pity-rarity-or-better.", "range": {"min": "1", "max": "200", "step": "1"}, "group": "Pity"}},
		"pity_rarity": {"type": "String", "default": "epic", "exported": true,
			"attributes": {"tooltip": "The rarity (by name) that pity guarantees at or above.", "group": "Pity"}}
	}
	var about: CommentRow = CommentRow.new()
	about.text = "SkinVault: register as the SkinVault autoload. Register rarities + skins, then unlock via Roll (weighted, with pity), Purchase (your wallet confirms), or Grant. React with On Skin Unlocked. It owns ownership; you build the UI. This pack is an event sheet - extend it by editing it."
	sheet.events.append(about)
	var block: RawCodeRow = RawCodeRow.new()
	block.code = "\n".join(PackedStringArray([
		"## @ace_trigger",
		"## @ace_name(\"On Skin Rolled\")",
		"## @ace_category(\"SkinVault\")",
		"signal on_skin_rolled()",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Skin Unlocked\")",
		"## @ace_category(\"SkinVault\")",
		"signal on_skin_unlocked()",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Purchase Requested\")",
		"## @ace_category(\"SkinVault\")",
		"signal on_purchase_requested()",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Purchase Cancelled\")",
		"## @ace_category(\"SkinVault\")",
		"signal on_purchase_cancelled()",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Skin Revoked\")",
		"## @ace_category(\"SkinVault\")",
		"signal on_skin_revoked()",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Pool Empty\")",
		"## @ace_category(\"SkinVault\")",
		"signal on_pool_empty()",
		"",
		"# name -> {weight, tier}. Tier is an explicit rank so pity never depends on registration order.",
		"var _rarities: Dictionary = {}",
		"# id -> {name, rarity, cost, tags:PackedStringArray}.",
		"var _skins: Dictionary = {}",
		"# id -> true (the owned set).",
		"var _owned: Dictionary = {}",
		"var _pity: int = 0",
		"# Last-event context (read via getter expressions inside the matching trigger).",
		"var _rolled_id: String = \"\"",
		"var _unlocked_id: String = \"\"",
		"var _unlock_method: String = \"\"",
		"var _req_id: String = \"\"",
		"var _revoked_id: String = \"\"",
		"var _rng: RandomNumberGenerator = RandomNumberGenerator.new()",
		"var _use_shared: bool = false",
		"",
		"# Randomness source: the shared AdvancedRandom autoload when Use Advanced Random is on and the",
		"# pack is installed, otherwise this pack's own generator (the default - unchanged behaviour).",
		"func _rand_float() -> float:",
		"\tif _use_shared and is_inside_tree():",
		"\t\tvar shared: Node = get_node_or_null(\"/root/AdvancedRandom\")",
		"\t\tif shared != null:",
		"\t\t\treturn shared.random_value()",
		"\treturn _rng.randf()",
		"",
		"func _tier(rarity: String) -> int:",
		"\treturn int(_rarities.get(rarity, {}).get(\"tier\", 0))",
		"",
		"func _weight(rarity: String) -> float:",
		"\treturn float(_rarities.get(rarity, {}).get(\"weight\", 1.0))",
		"",
		"# The unowned skins (optionally filtered to a tag) that a roll may award.",
		"func _pool(tag: String) -> Array:",
		"\tvar out: Array = []",
		"\tfor id: String in _skins:",
		"\t\tif _owned.has(id):",
		"\t\t\tcontinue",
		"\t\tif tag.is_empty() or tag in (_skins[id].tags as PackedStringArray):",
		"\t\t\tout.append(id)",
		"\treturn out",
		"",
		"# Adds a skin to the owned set (if new) and fires On Skin Unlocked with the method.",
		"func _grant(id: String, method: String) -> void:",
		"\tif _owned.has(id) or not _skins.has(id):",
		"\t\treturn",
		"\t_owned[id] = true",
		"\t_unlocked_id = id",
		"\t_unlock_method = method",
		"\ton_skin_unlocked.emit()"
	]))
	sheet.events.append(block)
	var on_ready: EventRow = EventRow.new()
	on_ready.trigger_provider_id = "Core"
	on_ready.trigger_id = "OnReady"
	var ready_body: RawCodeRow = RawCodeRow.new()
	ready_body.code = "_rng.randomize()"
	on_ready.actions.append(ready_body)
	sheet.events.append(on_ready)

	# --- Registry ---
	Lib.append_function(sheet, "register_rarity", "Register Rarity", "SkinVault", "Registers a rarity: a roll weight (higher = commoner) and a tier rank (higher = rarer; pity guarantees a tier at or above the pity rarity).",
		[["name", "String"], ["weight", "float"], ["tier", "int"]],
		"_rarities[name] = {\"weight\": maxf(weight, 0.0), \"tier\": tier}")
	Lib.append_function(sheet, "use_advanced_random", "Use Advanced Random", "SkinVault", "When on, rolls draw from the shared AdvancedRandom autoload instead of this pack's own generator, so one seed drives your whole game's randomness. When off (the default) it uses its own generator. Needs the Advanced Random pack installed (it safely falls back to the local generator if not).",
		[["enabled", "bool"]],
		"_use_shared = enabled")
	Lib.append_function(sheet, "register_skin", "Register Skin", "SkinVault", "Registers a skin: a unique id, a display name, its rarity (must be registered), a cost (0 = not purchasable), and comma-separated tags.",
		[["id", "String"], ["display_name", "String"], ["rarity", "String"], ["cost", "float"], ["tags", "String"]],
		"var tag_list: PackedStringArray = PackedStringArray()\nfor raw: String in tags.split(\",\", false):\n\tvar trimmed: String = raw.strip_edges()\n\tif not trimmed.is_empty():\n\t\ttag_list.append(trimmed)\n_skins[id] = {\"name\": display_name, \"rarity\": rarity, \"cost\": cost, \"tags\": tag_list}")

	# --- Data-driven: load a whole catalog from a Custom Resource (.tres) ---
	Lib.append_function(sheet, "load_catalog", "Load Catalog", "SkinVault", "Registers a whole catalog (rarities + skins) from a Skin Catalog resource (a .tres you filled in the Inspector) in one step. The data-driven alternative to a string of Register Rarity + Register Skin actions.",
		[["catalog", "Resource"]],
		"\n".join(PackedStringArray([
			"if catalog == null:",
			"\tpush_warning(\"SkinVault: Load Catalog was given no resource.\")",
			"\treturn",
			"var rarity_rows: Variant = catalog.get(\"rarities\")",
			"if rarity_rows is Array:",
			"\tfor row: Variant in (rarity_rows as Array):",
			"\t\tif row is Dictionary and not str((row as Dictionary).get(\"name\", \"\")).is_empty():",
			"\t\t\tregister_rarity(str((row as Dictionary).get(\"name\", \"\")), float((row as Dictionary).get(\"weight\", 1.0)), int((row as Dictionary).get(\"tier\", 0)))",
			"var skin_rows: Variant = catalog.get(\"skins\")",
			"if skin_rows is Array:",
			"\tfor row: Variant in (skin_rows as Array):",
			"\t\tif row is Dictionary and not str((row as Dictionary).get(\"id\", \"\")).is_empty():",
			"\t\t\tregister_skin(str((row as Dictionary).get(\"id\", \"\")), str((row as Dictionary).get(\"name\", \"\")), str((row as Dictionary).get(\"rarity\", \"\")), float((row as Dictionary).get(\"cost\", 0.0)), str((row as Dictionary).get(\"tags\", \"\")))"
		])))

	# --- Unlock ---
	Lib.append_function(sheet, "roll", "Roll", "SkinVault", "Rolls a weighted-random UNOWNED skin (optional tag filter; \"\" = any) and grants it. Applies pity, then fires On Skin Rolled and On Skin Unlocked. Fires On Pool Empty if nothing is left.",
		[["tag", "String"]],
		"\n".join(PackedStringArray([
			"var pool: Array = _pool(tag)",
			"if pool.is_empty():",
			"\ton_pool_empty.emit()",
			"\treturn",
			"if enable_pity and _pity >= pity_threshold:",
			"\tvar min_tier: int = _tier(pity_rarity)",
			"\tvar boosted: Array = []",
			"\tfor id: String in pool:",
			"\t\tif _tier(_skins[id].rarity) >= min_tier:",
			"\t\t\tboosted.append(id)",
			"\tif not boosted.is_empty():",
			"\t\tpool = boosted",
			"var total: float = 0.0",
			"for id: String in pool:",
			"\ttotal += maxf(_weight(_skins[id].rarity), 0.0001)",
			"var r: float = _rand_float() * total",
			"var picked: String = str(pool[pool.size() - 1])",
			"for id: String in pool:",
			"\tr -= maxf(_weight(_skins[id].rarity), 0.0001)",
			"\tif r <= 0.0:",
			"\t\tpicked = id",
			"\t\tbreak",
			"if _tier(_skins[picked].rarity) >= _tier(pity_rarity):",
			"\t_pity = 0",
			"else:",
			"\t_pity += 1",
			"_rolled_id = picked",
			"on_skin_rolled.emit()",
			"_grant(picked, \"roll\")"
		])))
	Lib.append_function(sheet, "grant", "Grant", "SkinVault", "Unlocks a skin for free (fires On Skin Unlocked). Does nothing if already owned.",
		[["skin_id", "String"]],
		"_grant(skin_id, \"grant\")")
	Lib.append_function(sheet, "revoke", "Revoke", "SkinVault", "Removes a skin from the owned set (fires On Skin Revoked).",
		[["skin_id", "String"]],
		"if _owned.has(skin_id):\n\t_owned.erase(skin_id)\n\t_revoked_id = skin_id\n\ton_skin_revoked.emit()")
	Lib.append_function(sheet, "purchase", "Purchase", "SkinVault", "Starts a purchase: fires On Purchase Requested carrying the skin id + cost. Check your wallet there, then call Confirm or Cancel Purchase. (SkinVault never touches currency itself.)",
		[["skin_id", "String"]],
		"if _owned.has(skin_id) or not _skins.has(skin_id):\n\treturn\n_req_id = skin_id\non_purchase_requested.emit()")
	Lib.append_function(sheet, "confirm_purchase", "Confirm Purchase", "SkinVault", "Completes a purchase and grants the skin (fires On Skin Unlocked with method \"purchase\").",
		[["skin_id", "String"]],
		"_grant(skin_id, \"purchase\")")
	Lib.append_function(sheet, "cancel_purchase", "Cancel Purchase", "SkinVault", "Cancels a pending purchase (fires On Purchase Cancelled).",
		[["skin_id", "String"]],
		"_req_id = skin_id\non_purchase_cancelled.emit()")
	Lib.append_function(sheet, "reset_pity", "Reset Pity", "SkinVault", "Sets the pity counter back to 0.",
		[],
		"_pity = 0")

	# --- Persistence ---
	Lib.append_function(sheet, "load_owned", "Load Owned", "SkinVault", "Restores the owned set from a comma-separated id list (pair with the Owned Ids expression to save).",
		[["owned_csv", "String"]],
		"_owned.clear()\nfor raw: String in owned_csv.split(\",\", false):\n\tvar id: String = raw.strip_edges()\n\tif not id.is_empty():\n\t\t_owned[id] = true")
	Lib.append_function(sheet, "set_pity_count", "Set Pity Count", "SkinVault", "Restores the pity counter (for save/load).",
		[["count", "int"]],
		"_pity = maxi(count, 0)")

	# --- Conditions ---
	_condition(sheet, "is_owned", "Is Owned", "SkinVault", "Whether the player owns a skin.", [["skin_id", "String"]],
		"return _owned.has(skin_id)")
	_condition(sheet, "is_registered", "Is Registered", "SkinVault", "Whether a skin exists in the catalog.", [["skin_id", "String"]],
		"return _skins.has(skin_id)")
	_condition(sheet, "is_unlockable", "Is Unlockable", "SkinVault", "Whether a skin is registered but not yet owned (drives lock icons).", [["skin_id", "String"]],
		"return _skins.has(skin_id) and not _owned.has(skin_id)")
	_condition(sheet, "is_pool_empty", "Is Pool Empty", "SkinVault", "Whether there are no unowned skins left to roll (optional tag filter).", [["tag", "String"]],
		"return _pool(tag).is_empty()")

	# --- Expressions: catalog + pity ---
	_expr(sheet, "total_skins", "Total Skins", "SkinVault", "How many skins are registered.", [],
		"return _skins.size()", TYPE_INT)
	_expr(sheet, "owned_count", "Owned Count", "SkinVault", "How many skins the player owns.", [],
		"return _owned.size()", TYPE_INT)
	_expr(sheet, "pool_count", "Pool Count", "SkinVault", "How many unowned skins remain (optional tag filter).", [["tag", "String"]],
		"return _pool(tag).size()", TYPE_INT)
	_expr(sheet, "skin_name", "Skin Name", "SkinVault", "A skin's display name.", [["skin_id", "String"]],
		"return str(_skins[skin_id].name) if _skins.has(skin_id) else \"\"", TYPE_STRING)
	_expr(sheet, "skin_rarity", "Skin Rarity", "SkinVault", "A skin's rarity name.", [["skin_id", "String"]],
		"return str(_skins[skin_id].rarity) if _skins.has(skin_id) else \"\"", TYPE_STRING)
	_expr(sheet, "skin_cost", "Skin Cost", "SkinVault", "A skin's cost (0 if not purchasable / unknown).", [["skin_id", "String"]],
		"return float(_skins[skin_id].cost) if _skins.has(skin_id) else 0.0", TYPE_FLOAT)
	_expr(sheet, "pity_counter", "Pity Counter", "SkinVault", "The current miss streak toward pity.", [],
		"return _pity", TYPE_INT)
	_expr(sheet, "pity_progress", "Pity Progress", "SkinVault", "Progress toward pity as 0.0 - 1.0 (for a bar).", [],
		"return clampf(float(_pity) / float(pity_threshold), 0.0, 1.0) if pity_threshold > 0 else 0.0", TYPE_FLOAT)
	_expr(sheet, "owned_ids", "Owned Ids", "SkinVault", "The owned skin ids as a comma-separated string (pair with Load Owned to save).", [],
		"return \",\".join(PackedStringArray(_owned.keys()))", TYPE_STRING)

	# --- Expressions: event context ---
	_expr(sheet, "rolled_id", "Rolled Id", "SkinVault", "The skin just rolled (inside On Skin Rolled).", [],
		"return _rolled_id", TYPE_STRING)
	_expr(sheet, "unlocked_id", "Unlocked Id", "SkinVault", "The skin just unlocked (inside On Skin Unlocked).", [],
		"return _unlocked_id", TYPE_STRING)
	_expr(sheet, "unlock_method", "Unlock Method", "SkinVault", "How it was unlocked - \"roll\", \"grant\", or \"purchase\" (inside On Skin Unlocked).", [],
		"return _unlock_method", TYPE_STRING)
	_expr(sheet, "requested_id", "Requested Id", "SkinVault", "The skin being purchased (inside On Purchase Requested / Cancelled).", [],
		"return _req_id", TYPE_STRING)
	_expr(sheet, "requested_cost", "Requested Cost", "SkinVault", "The cost of the requested purchase (inside On Purchase Requested).", [],
		"return float(_skins[_req_id].cost) if _skins.has(_req_id) else 0.0", TYPE_FLOAT)
	_expr(sheet, "revoked_id", "Revoked Id", "SkinVault", "The skin just revoked (inside On Skin Revoked).", [],
		"return _revoked_id", TYPE_STRING)

	var persistence: RawCodeRow = RawCodeRow.new()
	persistence.code = "\n".join(PackedStringArray([
		"# Save-state seam: the Save System walks any node in its persist group (or targeted",
		"# by Save/Load Node State) and duck-types these two methods. Plain data only.",
		"## @ace_hidden",
		"func save_state() -> Dictionary:",
		"\treturn {",
		"\t\t\"owned\": _owned.duplicate(true),",
		"\t\t\"pity\": _pity",
		"\t}",
		"",
		"## @ace_hidden",
		"func load_state(state: Dictionary) -> void:",
		"\tif state.is_empty():",
		"\t\treturn",
		"\t_owned = (state.get(\"owned\", {}) as Dictionary).duplicate(true)",
		"\t_pity = int(state.get(\"pity\", 0))"
	]))
	sheet.events.append(persistence)

	return Lib.save_pack(sheet, "res://eventsheet_addons/skin_vault/skin_vault_addon")


static func _condition(sheet: EventSheetResource, function_name: String, display_name: String, category: String, description: String, params: Array, body: String) -> void:
	var fn: EventFunction = Lib.exposed_function(function_name, display_name, category, description, params, body)
	fn.return_type = TYPE_BOOL
	sheet.functions.append(fn)


static func _expr(sheet: EventSheetResource, function_name: String, display_name: String, category: String, description: String, params: Array, body: String, ret: int) -> void:
	var fn: EventFunction = Lib.exposed_function(function_name, display_name, category, description, params, body)
	fn.return_type = ret
	sheet.functions.append(fn)
