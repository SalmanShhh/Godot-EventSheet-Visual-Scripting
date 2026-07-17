# Pack builder - big_number (one pack per file; run via tools/build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")


## Big Numbers: the number-formatting an idle/incremental game lives on, as an AUTOLOAD sheet. Two layers:
##  - FORMATTING plain floats: short suffixes past a trillion (K M B T Qa Qi Sx Sp Oc No Dc, then
##    scientific), scientific + engineering notation, time (seconds -> "1h 3m"), ordinals, commas, percent.
##    Good to roughly 1e300 - the range of most idle games.
##  - A DECIMAL type for numbers past a float's ~1.8e308 ceiling (Antimatter-Dimensions scale). A Decimal is
##    an Array [mantissa, exponent] meaning mantissa * 10^exponent; Add / Multiply / Power / Compare / Format
##    Big operate on it. (It is an Array, not a Vector2, so the mantissa keeps full 64-bit precision.)
## Every formatter is verified plain Godot with the classic traps fixed: the floor(log/log10) off-by-one at
## exact powers of ten (a +1e-9 epsilon), the mantissa-rounding carry (999.99 -> "1.00" one tier up), and the
## past-Dc fall-through to scientific. Zero plugin dependency, honouring the parity covenant.
static func build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.autoload_mode = true
	sheet.autoload_name = "BigNumber"
	sheet.host_class = "Node"
	sheet.custom_class_name = "BigNumberAddon"
	sheet.class_description = "Number formatting for idle and incremental games: turns raw values into compact strings like 1.25M, plus durations and percents, and ships a Decimal type that keeps growing past a float ceiling. A bank of pure calculators - it never stores your numbers or draws your HUD."
	sheet.addon_category = "Big Numbers"
	sheet.addon_tags = PackedStringArray(["incremental", "idle", "format"])
	var about: CommentRow = CommentRow.new()
	about.text = "Big Numbers: register as the BigNumber autoload, then format idle-scale numbers from any sheet - Format Short turns 1250000 into \"1.25M\" and keeps going past a trillion (Qa, Qi ... Dc, then scientific). For values beyond a float's 1.8e308 ceiling, the Decimal type (Make / Add / Multiply / Power / Format Big) stores a mantissa and exponent so numbers never overflow. This pack is an event sheet - extend it by editing it."
	sheet.events.append(about)

	# Shared private helpers (un-exposed): the suffix ladder, a corrected order-of-magnitude, and the
	# Decimal normalize/compare. Kept out of the picker; the exposed ACEs below call them.
	var block: RawCodeRow = RawCodeRow.new()
	block.code = "\n".join(PackedStringArray([
		"# Short-scale suffixes: index i covers 10^(3i). Past Dc (1e33) the formatters fall to scientific.",
		"const SUFFIXES: Array = [\"\", \"K\", \"M\", \"B\", \"T\", \"Qa\", \"Qi\", \"Sx\", \"Sp\", \"Oc\", \"No\", \"Dc\"]",
		"",
		"# Order of magnitude (floor log10 of |value|). GDScript's log() is natural log and there is no",
		"# log10, so divide by log(10.0); the +1e-9 epsilon fixes the exact-power-of-ten undercount",
		"# (log(1000)/log(10) = 2.9999999996 -> would floor to 2). Epsilon-only is exact across 1e0..1e308;",
		"# a pow() round-trip correction over-corrects at the float ceiling, so it is deliberately absent.",
		"func _oom(value: float) -> int:",
		"\tvar magnitude: float = absf(value)",
		"\tif magnitude <= 0.0:",
		"\t\treturn 0",
		"\treturn int(floor(log(magnitude) / log(10.0) + 1e-9))",
		"",
		"# Normalizes a Decimal so 1 <= abs(mantissa) < 10 (or [0, 0] for zero / non-finite).",
		"func _dnorm(mantissa: float, exponent: float) -> Array:",
		"\tif mantissa == 0.0 or not is_finite(mantissa):",
		"\t\treturn [0.0, 0.0]",
		"\tvar shift: int = _oom(mantissa)",
		"\treturn [mantissa / pow(10.0, shift), exponent + float(shift)]",
		"",
		"# Three-way compare of two Decimals: -1 if a < b, 0 if equal, 1 if a > b. Sign-aware, and",
		"# compares by exponent then mantissa so it never overflows a float back to a plain number.",
		"func _dcmp(a: Array, b: Array) -> int:",
		"\tvar na: Array = _dnorm(float(a[0]), float(a[1]))",
		"\tvar nb: Array = _dnorm(float(b[0]), float(b[1]))",
		"\tvar sign_a: float = signf(na[0])",
		"\tvar sign_b: float = signf(nb[0])",
		"\tif sign_a != sign_b:",
		"\t\treturn -1 if sign_a < sign_b else 1",
		"\tif sign_a == 0.0:",
		"\t\treturn 0",
		"\t# Compare in log10 space (exponent + log10 of the mantissa). A normalized mantissa in [1, 10)",
		"\t# spans a whole order of magnitude, so exponent-first ordering is wrong once exponents are",
		"\t# fractional (Make with a float exponent, or Power with a fractional power).",
		"\tvar mag_a: float = float(na[1]) + log(absf(na[0])) / log(10.0)",
		"\tvar mag_b: float = float(nb[1]) + log(absf(nb[0])) / log(10.0)",
		"\tvar result: int = 0",
		"\tif not is_equal_approx(mag_a, mag_b):",
		"\t\tresult = -1 if mag_a < mag_b else 1",
		"\treturn result if sign_a > 0.0 else -result"
	]))
	sheet.events.append(block)

	# --- Formatting plain floats ---
	Lib.number(sheet, "fmt_short", "Format Short", "Big Numbers", "A compact string with a short-scale suffix: 1250 -> \"1.25K\", 1250000 -> \"1.25M\", on through Qa/Qi/.../Dc, then scientific past 1e36. Pass how many decimals.",
		[["value", "float"], ["decimals", "int"]], "\n".join(PackedStringArray([
			"if not is_finite(value):",
			"\treturn \"Infinity\" if value > 0.0 else \"-Infinity\"",
			"if value == 0.0:",
			"\treturn \"0\"",
			"var sign_text: String = \"-\" if value < 0.0 else \"\"",
			"var magnitude: float = absf(value)",
			"var exponent: int = _oom(magnitude)",
			"if exponent < 3:",
			"\treturn sign_text + String.num(magnitude, maxi(decimals, 0))",
			"var tier: int = exponent / 3",
			"var step: float = pow(10.0, -maxi(decimals, 0))",
			"var mantissa: float = magnitude / pow(10.0, tier * 3)",
			"if snappedf(mantissa, step) >= 1000.0:",
			"\tmantissa = mantissa / 1000.0",
			"\ttier += 1",
			"if tier >= SUFFIXES.size():",
			"\treturn sign_text + String.num(magnitude / pow(10.0, exponent), maxi(decimals, 0)) + \"e\" + str(exponent)",
			"return sign_text + String.num(mantissa, maxi(decimals, 0)) + str(SUFFIXES[tier])"
		])), TYPE_STRING)
	Lib.number(sheet, "fmt_scientific", "Format Scientific", "Big Numbers", "Scientific notation: 1250000 -> \"1.25e6\". Pass how many decimals for the mantissa.",
		[["value", "float"], ["decimals", "int"]], "\n".join(PackedStringArray([
			"if not is_finite(value):",
			"\treturn \"Infinity\" if value > 0.0 else \"-Infinity\"",
			"if value == 0.0:",
			"\treturn \"0\"",
			"var sign_text: String = \"-\" if value < 0.0 else \"\"",
			"var magnitude: float = absf(value)",
			"var exponent: int = _oom(magnitude)",
			"var step: float = pow(10.0, -maxi(decimals, 0))",
			"var mantissa: float = magnitude / pow(10.0, exponent)",
			"if snappedf(mantissa, step) >= 10.0:",
			"\tmantissa = mantissa / 10.0",
			"\texponent += 1",
			"return sign_text + String.num(mantissa, maxi(decimals, 0)) + \"e\" + str(exponent)"
		])), TYPE_STRING)
	Lib.number(sheet, "fmt_engineering", "Format Engineering", "Big Numbers", "Engineering notation - the exponent is always a multiple of 3: 1250000 -> \"1.25e6\", 12500 -> \"12.50e3\".",
		[["value", "float"], ["decimals", "int"]], "\n".join(PackedStringArray([
			"if not is_finite(value):",
			"\treturn \"Infinity\" if value > 0.0 else \"-Infinity\"",
			"if value == 0.0:",
			"\treturn \"0\"",
			"var sign_text: String = \"-\" if value < 0.0 else \"\"",
			"var magnitude: float = absf(value)",
			"var exponent: int = _oom(magnitude)",
			"var e3: int = int(floor(float(exponent) / 3.0)) * 3",
			"var step: float = pow(10.0, -maxi(decimals, 0))",
			"var mantissa: float = magnitude / pow(10.0, e3)",
			"if snappedf(mantissa, step) >= 1000.0:",
			"\te3 += 3",
			"\tmantissa = magnitude / pow(10.0, e3)",
			"return sign_text + String.num(mantissa, maxi(decimals, 0)) + \"e\" + str(e3)"
		])), TYPE_STRING)
	Lib.number(sheet, "fmt_time", "Format Time", "Big Numbers", "Seconds as a friendly duration: 3725 -> \"1h 2m 5s\". Drops leading zero units (90 -> \"1m 30s\").",
		[["seconds", "float"]], "\n".join(PackedStringArray([
			"var total: int = int(maxf(seconds, 0.0))",
			"var days: int = total / 86400",
			"total = total % 86400",
			"var hours: int = total / 3600",
			"total = total % 3600",
			"var minutes: int = total / 60",
			"var secs: int = total % 60",
			"var parts: PackedStringArray = PackedStringArray()",
			"if days > 0:",
			"\tparts.append(str(days) + \"d\")",
			"if hours > 0 or not parts.is_empty():",
			"\tparts.append(str(hours) + \"h\")",
			"if minutes > 0 or not parts.is_empty():",
			"\tparts.append(str(minutes) + \"m\")",
			"parts.append(str(secs) + \"s\")",
			"return \" \".join(parts)"
		])), TYPE_STRING)
	Lib.number(sheet, "fmt_time_short", "Format Time Short", "Big Numbers", "Seconds as a clock: 3725 -> \"1:02:05\", 90 -> \"1:30\".",
		[["seconds", "float"]], "\n".join(PackedStringArray([
			"var total: int = int(maxf(seconds, 0.0))",
			"var hours: int = total / 3600",
			"var minutes: int = (total % 3600) / 60",
			"var secs: int = total % 60",
			"if hours > 0:",
			"\treturn \"%d:%02d:%02d\" % [hours, minutes, secs]",
			"return \"%d:%02d\" % [minutes, secs]"
		])), TYPE_STRING)
	Lib.number(sheet, "fmt_ordinal", "Format Ordinal", "Big Numbers", "An ordinal string: 1 -> \"1st\", 2 -> \"2nd\", 13 -> \"13th\", 21 -> \"21st\".",
		[["number", "int"]], "\n".join(PackedStringArray([
			"var mod100: int = number % 100",
			"var suffix: String = \"th\"",
			"if mod100 < 11 or mod100 > 13:",
			"\tmatch number % 10:",
			"\t\t1:",
			"\t\t\tsuffix = \"st\"",
			"\t\t2:",
			"\t\t\tsuffix = \"nd\"",
			"\t\t3:",
			"\t\t\tsuffix = \"rd\"",
			"return str(number) + suffix"
		])), TYPE_STRING)
	Lib.number(sheet, "fmt_comma", "Format Comma", "Big Numbers", "Thousands separators on the whole-number part: 1234567 -> \"1,234,567\".",
		[["value", "float"]], "\n".join(PackedStringArray([
			"var negative: bool = value < 0.0",
			"var digits: String = str(int(absf(value)))",
			"var out: String = \"\"",
			"var count: int = 0",
			"for i: int in range(digits.length() - 1, -1, -1):",
			"\tout = digits[i] + out",
			"\tcount += 1",
			"\tif count % 3 == 0 and i > 0:",
			"\t\tout = \",\" + out",
			"return (\"-\" if negative else \"\") + out"
		])), TYPE_STRING)
	Lib.number(sheet, "fmt_percent", "Format Percent", "Big Numbers", "A fraction as a percent: 0.25 -> \"25%\". Pass how many decimals.",
		[["value", "float"], ["decimals", "int"]],
		"return String.num(value * 100.0, maxi(decimals, 0)) + \"%\"", TYPE_STRING)
	Lib.number(sheet, "fmt_multiplier", "Format Multiplier", "Big Numbers", "A multiplier label: 1.5 -> \"x1.5\", 2.0 -> \"x2.0\".",
		[["value", "float"], ["decimals", "int"]],
		"return \"x\" + String.num(value, maxi(decimals, 0))", TYPE_STRING)
	Lib.number(sheet, "suffix_for", "Suffix For", "Big Numbers", "The short-scale suffix for an order of magnitude: 6 -> \"M\", 9 -> \"B\". \"\" past Dc.",
		[["magnitude", "int"]], "\n".join(PackedStringArray([
			"if magnitude < 0:",
			"\treturn \"\"",
			"var tier: int = magnitude / 3",
			"return str(SUFFIXES[tier]) if tier < SUFFIXES.size() else \"\""
		])), TYPE_STRING)
	Lib.number(sheet, "order_of_magnitude", "Order Of Magnitude", "Big Numbers", "The power of ten of a value (floor log10): 1250 -> 3, 1000000 -> 6.",
		[["value", "float"]],
		"return _oom(value)", TYPE_INT)

	# --- The Decimal type (Array [mantissa, exponent]) for values past a float's 1.8e308 ceiling ---
	Lib.number(sheet, "dec_make", "Make", "Big Numbers", "Builds a Decimal from a mantissa and an exponent: Make(1.5, 100) is 1.5e100. Normalized automatically.",
		[["mantissa", "float"], ["exponent", "float"]],
		"return _dnorm(mantissa, exponent)", TYPE_ARRAY)
	Lib.number(sheet, "dec_from", "From Number", "Big Numbers", "Turns a plain number into a Decimal so it can grow past the float ceiling.",
		[["value", "float"]],
		"return _dnorm(value, 0.0)", TYPE_ARRAY)
	Lib.number(sheet, "dec_to", "To Number", "Big Numbers", "Turns a Decimal back into a plain number (may be Infinity if it is above 1.8e308).",
		[["decimal", "Array"]],
		"return float(decimal[0]) * pow(10.0, float(decimal[1]))", TYPE_FLOAT)
	Lib.number(sheet, "dec_add", "Add", "Big Numbers", "Adds two Decimals. When one is more than ~15 orders of magnitude larger, the smaller is negligible and dropped.",
		[["a", "Array"], ["b", "Array"]], "\n".join(PackedStringArray([
			"var am: float = float(a[0])",
			"var ae: float = float(a[1])",
			"var bm: float = float(b[0])",
			"var be: float = float(b[1])",
			"if am == 0.0:",
			"\treturn _dnorm(bm, be)",
			"if bm == 0.0:",
			"\treturn _dnorm(am, ae)",
			"if absf(ae - be) > 15.0:",
			"\treturn _dnorm(am, ae) if ae > be else _dnorm(bm, be)",
			"var hi: float = maxf(ae, be)",
			"var total: float = am * pow(10.0, ae - hi) + bm * pow(10.0, be - hi)",
			"return _dnorm(total, hi)"
		])), TYPE_ARRAY)
	Lib.number(sheet, "dec_sub", "Subtract", "Big Numbers", "Subtracts Decimal b from Decimal a.",
		[["a", "Array"], ["b", "Array"]],
		"return dec_add(a, [-float(b[0]), float(b[1])])", TYPE_ARRAY)
	Lib.number(sheet, "dec_mul", "Multiply", "Big Numbers", "Multiplies two Decimals (mantissas multiply, exponents add).",
		[["a", "Array"], ["b", "Array"]],
		"return _dnorm(float(a[0]) * float(b[0]), float(a[1]) + float(b[1]))", TYPE_ARRAY)
	Lib.number(sheet, "dec_div", "Divide", "Big Numbers", "Divides Decimal a by Decimal b (returns 0 if b is 0).",
		[["a", "Array"], ["b", "Array"]], "\n".join(PackedStringArray([
			"if float(b[0]) == 0.0:",
			"\treturn [0.0, 0.0]",
			"return _dnorm(float(a[0]) / float(b[0]), float(a[1]) - float(b[1]))"
		])), TYPE_ARRAY)
	Lib.number(sheet, "dec_pow", "Power", "Big Numbers", "Raises a Decimal to a power: Power(d, 2) squares it. Works in log space so a big power never overflows.",
		[["decimal", "Array"], ["power", "float"]], "\n".join(PackedStringArray([
			"var mantissa: float = float(decimal[0])",
			"if mantissa == 0.0:",
			"\treturn [0.0, 0.0]",
			"# (m * 10^e) ^ p = 10 ^ (p * (e + log10|m|)). Raising 10 to a fractional part keeps the",
			"# mantissa finite, so a huge power (9^400) no longer overflows the raw pow() to INF -> 0.",
			"var total_exp: float = power * (float(decimal[1]) + log(absf(mantissa)) / log(10.0))",
			"var exp_floor: float = floor(total_exp)",
			"var result_mantissa: float = pow(10.0, total_exp - exp_floor)",
			"if mantissa < 0.0 and power == floor(power) and int(power) % 2 != 0:",
			"\tresult_mantissa = -result_mantissa",
			"return _dnorm(result_mantissa, exp_floor)"
		])), TYPE_ARRAY)
	Lib.number(sheet, "dec_scale", "Scale", "Big Numbers", "Multiplies a Decimal by a plain number - the easy way to apply a multiplier.",
		[["decimal", "Array"], ["factor", "float"]],
		"return _dnorm(float(decimal[0]) * factor, float(decimal[1]))", TYPE_ARRAY)
	Lib.number(sheet, "dec_compare", "Compare", "Big Numbers", "Compares two Decimals: -1 if a < b, 0 if equal, 1 if a > b.",
		[["a", "Array"], ["b", "Array"]],
		"return _dcmp(a, b)", TYPE_INT)
	Lib.number(sheet, "dec_format", "Format Big", "Big Numbers", "Formats a Decimal with a short-scale suffix, falling through to scientific past Dc: Make(1.5, 100) -> \"1.50e100\".",
		[["decimal", "Array"], ["decimals", "int"]], "\n".join(PackedStringArray([
			"var normalized: Array = _dnorm(float(decimal[0]), float(decimal[1]))",
			"if float(normalized[0]) == 0.0:",
			"\treturn \"0\"",
			"var sign_text: String = \"-\" if float(normalized[0]) < 0.0 else \"\"",
			"var mantissa: float = absf(float(normalized[0]))",
			"var exponent: float = float(normalized[1])",
			"var exponent_floor: float = floor(exponent)",
			"mantissa = mantissa * pow(10.0, exponent - exponent_floor)",
			"if mantissa >= 10.0:",
			"\tmantissa = mantissa / 10.0",
			"\texponent_floor += 1.0",
			"var e: int = int(exponent_floor)",
			"if e < 3:",
			"\treturn sign_text + String.num(mantissa * pow(10.0, e), maxi(decimals, 0))",
			"var tier: int = e / 3",
			"var band: float = mantissa * pow(10.0, e - tier * 3)",
			"if band >= 1000.0:",
			"\tband = band / 1000.0",
			"\ttier += 1",
			"if tier >= SUFFIXES.size():",
			"\treturn sign_text + String.num(mantissa, maxi(decimals, 0)) + \"e\" + str(e)",
			"return sign_text + String.num(band, maxi(decimals, 0)) + str(SUFFIXES[tier])"
		])), TYPE_STRING)
	Lib.condition(sheet, "dec_greater", "Is Bigger", "Big Numbers", "Whether Decimal a is strictly bigger than Decimal b.",
		[["a", "Array"], ["b", "Array"]],
		"return _dcmp(a, b) > 0")
	Lib.condition(sheet, "dec_at_least", "Is At Least", "Big Numbers", "Whether Decimal a is at least as big as Decimal b.",
		[["a", "Array"], ["b", "Array"]],
		"return _dcmp(a, b) >= 0")

	# The pack's hero verbs: starred + bold at the top of their picker section.
	Lib.feature_verbs(sheet, ["fmt_short", "dec_format"])
	return Lib.save_pack(sheet, "res://eventsheet_addons/big_number/big_number_addon")
