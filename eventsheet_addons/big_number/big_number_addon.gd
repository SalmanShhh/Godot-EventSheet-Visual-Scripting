## @ace_tags(incremental, idle, format)
## @ace_category("Big Numbers")
@icon("res://eventsheet_addons/big_number/icon.svg")
class_name BigNumberAddon
extends Node

# Short-scale suffixes: index i covers 10^(3i). Past Dc (1e33) the formatters fall to scientific.
const SUFFIXES: Array = ["", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc"]

## @ace_expression
## @ace_name("Format Short")
## @ace_category("Big Numbers")
## @ace_description("A compact string with a short-scale suffix: 1250 -> "1.25K", 1250000 -> "1.25M", on through Qa/Qi/.../Dc, then scientific past 1e36. Pass how many decimals.")
## @ace_icon("res://eventsheet_addons/big_number/icon.svg")
## @ace_codegen_template("BigNumber.fmt_short({value}, {decimals})")
func fmt_short(value: float, decimals: int) -> String:
	if not is_finite(value):
		return "Infinity" if value > 0.0 else "-Infinity"
	if value == 0.0:
		return "0"
	var sign_text: String = "-" if value < 0.0 else ""
	var magnitude: float = absf(value)
	var exponent: int = _oom(magnitude)
	if exponent < 3:
		return sign_text + String.num(magnitude, maxi(decimals, 0))
	var tier: int = exponent / 3
	var step: float = pow(10.0, -maxi(decimals, 0))
	var mantissa: float = magnitude / pow(10.0, tier * 3)
	if snappedf(mantissa, step) >= 1000.0:
		mantissa = mantissa / 1000.0
		tier += 1
	if tier >= SUFFIXES.size():
		return sign_text + String.num(magnitude / pow(10.0, exponent), maxi(decimals, 0)) + "e" + str(exponent)
	return sign_text + String.num(mantissa, maxi(decimals, 0)) + str(SUFFIXES[tier])

## @ace_expression
## @ace_name("Format Scientific")
## @ace_category("Big Numbers")
## @ace_description("Scientific notation: 1250000 -> "1.25e6". Pass how many decimals for the mantissa.")
## @ace_icon("res://eventsheet_addons/big_number/icon.svg")
## @ace_codegen_template("BigNumber.fmt_scientific({value}, {decimals})")
func fmt_scientific(value: float, decimals: int) -> String:
	if not is_finite(value):
		return "Infinity" if value > 0.0 else "-Infinity"
	if value == 0.0:
		return "0"
	var sign_text: String = "-" if value < 0.0 else ""
	var magnitude: float = absf(value)
	var exponent: int = _oom(magnitude)
	var step: float = pow(10.0, -maxi(decimals, 0))
	var mantissa: float = magnitude / pow(10.0, exponent)
	if snappedf(mantissa, step) >= 10.0:
		mantissa = mantissa / 10.0
		exponent += 1
	return sign_text + String.num(mantissa, maxi(decimals, 0)) + "e" + str(exponent)

## @ace_expression
## @ace_name("Format Engineering")
## @ace_category("Big Numbers")
## @ace_description("Engineering notation - the exponent is always a multiple of 3: 1250000 -> "1.25e6", 12500 -> "12.50e3".")
## @ace_icon("res://eventsheet_addons/big_number/icon.svg")
## @ace_codegen_template("BigNumber.fmt_engineering({value}, {decimals})")
func fmt_engineering(value: float, decimals: int) -> String:
	if not is_finite(value):
		return "Infinity" if value > 0.0 else "-Infinity"
	if value == 0.0:
		return "0"
	var sign_text: String = "-" if value < 0.0 else ""
	var magnitude: float = absf(value)
	var exponent: int = _oom(magnitude)
	var e3: int = int(floor(float(exponent) / 3.0)) * 3
	var step: float = pow(10.0, -maxi(decimals, 0))
	var mantissa: float = magnitude / pow(10.0, e3)
	if snappedf(mantissa, step) >= 1000.0:
		e3 += 3
		mantissa = magnitude / pow(10.0, e3)
	return sign_text + String.num(mantissa, maxi(decimals, 0)) + "e" + str(e3)

## @ace_expression
## @ace_name("Format Time")
## @ace_category("Big Numbers")
## @ace_description("Seconds as a friendly duration: 3725 -> "1h 2m 5s". Drops leading zero units (90 -> "1m 30s").")
## @ace_icon("res://eventsheet_addons/big_number/icon.svg")
## @ace_codegen_template("BigNumber.fmt_time({seconds})")
func fmt_time(seconds: float) -> String:
	var total: int = int(maxf(seconds, 0.0))
	var days: int = total / 86400
	total = total % 86400
	var hours: int = total / 3600
	total = total % 3600
	var minutes: int = total / 60
	var secs: int = total % 60
	var parts: PackedStringArray = PackedStringArray()
	if days > 0:
		parts.append(str(days) + "d")
	if hours > 0 or not parts.is_empty():
		parts.append(str(hours) + "h")
	if minutes > 0 or not parts.is_empty():
		parts.append(str(minutes) + "m")
	parts.append(str(secs) + "s")
	return " ".join(parts)

## @ace_expression
## @ace_name("Format Time Short")
## @ace_category("Big Numbers")
## @ace_description("Seconds as a clock: 3725 -> "1:02:05", 90 -> "1:30".")
## @ace_icon("res://eventsheet_addons/big_number/icon.svg")
## @ace_codegen_template("BigNumber.fmt_time_short({seconds})")
func fmt_time_short(seconds: float) -> String:
	var total: int = int(maxf(seconds, 0.0))
	var hours: int = total / 3600
	var minutes: int = (total % 3600) / 60
	var secs: int = total % 60
	if hours > 0:
		return "%d:%02d:%02d" % [hours, minutes, secs]
	return "%d:%02d" % [minutes, secs]

## @ace_expression
## @ace_name("Format Ordinal")
## @ace_category("Big Numbers")
## @ace_description("An ordinal string: 1 -> "1st", 2 -> "2nd", 13 -> "13th", 21 -> "21st".")
## @ace_icon("res://eventsheet_addons/big_number/icon.svg")
## @ace_codegen_template("BigNumber.fmt_ordinal({number})")
func fmt_ordinal(number: int) -> String:
	var mod100: int = number % 100
	var suffix: String = "th"
	if mod100 < 11 or mod100 > 13:
		match number % 10:
			1:
				suffix = "st"
			2:
				suffix = "nd"
			3:
				suffix = "rd"
	return str(number) + suffix

## @ace_expression
## @ace_name("Format Comma")
## @ace_category("Big Numbers")
## @ace_description("Thousands separators on the whole-number part: 1234567 -> "1,234,567".")
## @ace_icon("res://eventsheet_addons/big_number/icon.svg")
## @ace_codegen_template("BigNumber.fmt_comma({value})")
func fmt_comma(value: float) -> String:
	var negative: bool = value < 0.0
	var digits: String = str(int(absf(value)))
	var out: String = ""
	var count: int = 0
	for i: int in range(digits.length() - 1, -1, -1):
		out = digits[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "," + out
	return ("-" if negative else "") + out

## @ace_expression
## @ace_name("Format Percent")
## @ace_category("Big Numbers")
## @ace_description("A fraction as a percent: 0.25 -> "25%". Pass how many decimals.")
## @ace_icon("res://eventsheet_addons/big_number/icon.svg")
## @ace_codegen_template("BigNumber.fmt_percent({value}, {decimals})")
func fmt_percent(value: float, decimals: int) -> String:
	return String.num(value * 100.0, maxi(decimals, 0)) + "%"

## @ace_expression
## @ace_name("Format Multiplier")
## @ace_category("Big Numbers")
## @ace_description("A multiplier label: 1.5 -> "x1.5", 2.0 -> "x2.0".")
## @ace_icon("res://eventsheet_addons/big_number/icon.svg")
## @ace_codegen_template("BigNumber.fmt_multiplier({value}, {decimals})")
func fmt_multiplier(value: float, decimals: int) -> String:
	return "x" + String.num(value, maxi(decimals, 0))

## @ace_expression
## @ace_name("Suffix For")
## @ace_category("Big Numbers")
## @ace_description("The short-scale suffix for an order of magnitude: 6 -> "M", 9 -> "B". "" past Dc.")
## @ace_icon("res://eventsheet_addons/big_number/icon.svg")
## @ace_codegen_template("BigNumber.suffix_for({magnitude})")
func suffix_for(magnitude: int) -> String:
	if magnitude < 0:
		return ""
	var tier: int = magnitude / 3
	return str(SUFFIXES[tier]) if tier < SUFFIXES.size() else ""

## @ace_expression
## @ace_name("Order Of Magnitude")
## @ace_category("Big Numbers")
## @ace_description("The power of ten of a value (floor log10): 1250 -> 3, 1000000 -> 6.")
## @ace_icon("res://eventsheet_addons/big_number/icon.svg")
## @ace_codegen_template("BigNumber.order_of_magnitude({value})")
func order_of_magnitude(value: float) -> int:
	return _oom(value)

## @ace_expression
## @ace_name("Make")
## @ace_category("Big Numbers")
## @ace_description("Builds a Decimal from a mantissa and an exponent: Make(1.5, 100) is 1.5e100. Normalized automatically.")
## @ace_icon("res://eventsheet_addons/big_number/icon.svg")
## @ace_codegen_template("BigNumber.dec_make({mantissa}, {exponent})")
func dec_make(mantissa: float, exponent: float) -> Array:
	return _dnorm(mantissa, exponent)

## @ace_expression
## @ace_name("From Number")
## @ace_category("Big Numbers")
## @ace_description("Turns a plain number into a Decimal so it can grow past the float ceiling.")
## @ace_icon("res://eventsheet_addons/big_number/icon.svg")
## @ace_codegen_template("BigNumber.dec_from({value})")
func dec_from(value: float) -> Array:
	return _dnorm(value, 0.0)

## @ace_expression
## @ace_name("To Number")
## @ace_category("Big Numbers")
## @ace_description("Turns a Decimal back into a plain number (may be Infinity if it is above 1.8e308).")
## @ace_icon("res://eventsheet_addons/big_number/icon.svg")
## @ace_codegen_template("BigNumber.dec_to({decimal})")
func dec_to(decimal: Array) -> float:
	return float(decimal[0]) * pow(10.0, float(decimal[1]))

## @ace_expression
## @ace_name("Add")
## @ace_category("Big Numbers")
## @ace_description("Adds two Decimals. When one is more than ~15 orders of magnitude larger, the smaller is negligible and dropped.")
## @ace_icon("res://eventsheet_addons/big_number/icon.svg")
## @ace_codegen_template("BigNumber.dec_add({a}, {b})")
func dec_add(a: Array, b: Array) -> Array:
	var am: float = float(a[0])
	var ae: float = float(a[1])
	var bm: float = float(b[0])
	var be: float = float(b[1])
	if am == 0.0:
		return _dnorm(bm, be)
	if bm == 0.0:
		return _dnorm(am, ae)
	if absf(ae - be) > 15.0:
		return _dnorm(am, ae) if ae > be else _dnorm(bm, be)
	var hi: float = maxf(ae, be)
	var total: float = am * pow(10.0, ae - hi) + bm * pow(10.0, be - hi)
	return _dnorm(total, hi)

## @ace_expression
## @ace_name("Subtract")
## @ace_category("Big Numbers")
## @ace_description("Subtracts Decimal b from Decimal a.")
## @ace_icon("res://eventsheet_addons/big_number/icon.svg")
## @ace_codegen_template("BigNumber.dec_sub({a}, {b})")
func dec_sub(a: Array, b: Array) -> Array:
	return dec_add(a, [-float(b[0]), float(b[1])])

## @ace_expression
## @ace_name("Multiply")
## @ace_category("Big Numbers")
## @ace_description("Multiplies two Decimals (mantissas multiply, exponents add).")
## @ace_icon("res://eventsheet_addons/big_number/icon.svg")
## @ace_codegen_template("BigNumber.dec_mul({a}, {b})")
func dec_mul(a: Array, b: Array) -> Array:
	return _dnorm(float(a[0]) * float(b[0]), float(a[1]) + float(b[1]))

## @ace_expression
## @ace_name("Divide")
## @ace_category("Big Numbers")
## @ace_description("Divides Decimal a by Decimal b (returns 0 if b is 0).")
## @ace_icon("res://eventsheet_addons/big_number/icon.svg")
## @ace_codegen_template("BigNumber.dec_div({a}, {b})")
func dec_div(a: Array, b: Array) -> Array:
	if float(b[0]) == 0.0:
		return [0.0, 0.0]
	return _dnorm(float(a[0]) / float(b[0]), float(a[1]) - float(b[1]))

## @ace_expression
## @ace_name("Power")
## @ace_category("Big Numbers")
## @ace_description("Raises a Decimal to a power: Power(d, 2) squares it. Works in log space so a big power never overflows.")
## @ace_icon("res://eventsheet_addons/big_number/icon.svg")
## @ace_codegen_template("BigNumber.dec_pow({decimal}, {power})")
func dec_pow(decimal: Array, power: float) -> Array:
	var mantissa: float = float(decimal[0])
	if mantissa == 0.0:
		return [0.0, 0.0]
	# (m * 10^e) ^ p = 10 ^ (p * (e + log10|m|)). Raising 10 to a fractional part keeps the
	# mantissa finite, so a huge power (9^400) no longer overflows the raw pow() to INF -> 0.
	var total_exp: float = power * (float(decimal[1]) + log(absf(mantissa)) / log(10.0))
	var exp_floor: float = floor(total_exp)
	var result_mantissa: float = pow(10.0, total_exp - exp_floor)
	if mantissa < 0.0 and power == floor(power) and int(power) % 2 != 0:
		result_mantissa = -result_mantissa
	return _dnorm(result_mantissa, exp_floor)

## @ace_expression
## @ace_name("Scale")
## @ace_category("Big Numbers")
## @ace_description("Multiplies a Decimal by a plain number - the easy way to apply a multiplier.")
## @ace_icon("res://eventsheet_addons/big_number/icon.svg")
## @ace_codegen_template("BigNumber.dec_scale({decimal}, {factor})")
func dec_scale(decimal: Array, factor: float) -> Array:
	return _dnorm(float(decimal[0]) * factor, float(decimal[1]))

## @ace_expression
## @ace_name("Compare")
## @ace_category("Big Numbers")
## @ace_description("Compares two Decimals: -1 if a < b, 0 if equal, 1 if a > b.")
## @ace_icon("res://eventsheet_addons/big_number/icon.svg")
## @ace_codegen_template("BigNumber.dec_compare({a}, {b})")
func dec_compare(a: Array, b: Array) -> int:
	return _dcmp(a, b)

## @ace_expression
## @ace_name("Format Big")
## @ace_category("Big Numbers")
## @ace_description("Formats a Decimal with a short-scale suffix, falling through to scientific past Dc: Make(1.5, 100) -> "1.50e100".")
## @ace_icon("res://eventsheet_addons/big_number/icon.svg")
## @ace_codegen_template("BigNumber.dec_format({decimal}, {decimals})")
func dec_format(decimal: Array, decimals: int) -> String:
	var normalized: Array = _dnorm(float(decimal[0]), float(decimal[1]))
	if float(normalized[0]) == 0.0:
		return "0"
	var sign_text: String = "-" if float(normalized[0]) < 0.0 else ""
	var mantissa: float = absf(float(normalized[0]))
	var exponent: float = float(normalized[1])
	var exponent_floor: float = floor(exponent)
	mantissa = mantissa * pow(10.0, exponent - exponent_floor)
	if mantissa >= 10.0:
		mantissa = mantissa / 10.0
		exponent_floor += 1.0
	var e: int = int(exponent_floor)
	if e < 3:
		return sign_text + String.num(mantissa * pow(10.0, e), maxi(decimals, 0))
	var tier: int = e / 3
	var band: float = mantissa * pow(10.0, e - tier * 3)
	if band >= 1000.0:
		band = band / 1000.0
		tier += 1
	if tier >= SUFFIXES.size():
		return sign_text + String.num(mantissa, maxi(decimals, 0)) + "e" + str(e)
	return sign_text + String.num(band, maxi(decimals, 0)) + str(SUFFIXES[tier])

## @ace_condition
## @ace_name("Is Bigger")
## @ace_category("Big Numbers")
## @ace_description("Whether Decimal a is strictly bigger than Decimal b.")
## @ace_icon("res://eventsheet_addons/big_number/icon.svg")
## @ace_codegen_template("BigNumber.dec_greater({a}, {b})")
func dec_greater(a: Array, b: Array) -> bool:
	return _dcmp(a, b) > 0

## @ace_condition
## @ace_name("Is At Least")
## @ace_category("Big Numbers")
## @ace_description("Whether Decimal a is at least as big as Decimal b.")
## @ace_icon("res://eventsheet_addons/big_number/icon.svg")
## @ace_codegen_template("BigNumber.dec_at_least({a}, {b})")
func dec_at_least(a: Array, b: Array) -> bool:
	return _dcmp(a, b) >= 0

func _oom(value: float) -> int:
	# Order of magnitude (floor log10 of |value|). GDScript's log() is natural log and there is no
	# log10, so divide by log(10.0); the +1e-9 epsilon fixes the exact-power-of-ten undercount
	# (log(1000)/log(10) = 2.9999999996 -> would floor to 2). Epsilon-only is exact across 1e0..1e308;
	# a pow() round-trip correction over-corrects at the float ceiling, so it is deliberately absent.
	var magnitude: float = absf(value)
	if magnitude <= 0.0:
		return 0
	return int(floor(log(magnitude) / log(10.0) + 1e-9))

func _dnorm(mantissa: float, exponent: float) -> Array:
	# Normalizes a Decimal so 1 <= abs(mantissa) < 10 (or [0, 0] for zero / non-finite).
	if mantissa == 0.0 or not is_finite(mantissa):
		return [0.0, 0.0]
	var shift: int = _oom(mantissa)
	return [mantissa / pow(10.0, shift), exponent + float(shift)]

func _dcmp(a: Array, b: Array) -> int:
	# Three-way compare of two Decimals: -1 if a < b, 0 if equal, 1 if a > b. Sign-aware, and
	# compares by exponent then mantissa so it never overflows a float back to a plain number.
	var na: Array = _dnorm(float(a[0]), float(a[1]))
	var nb: Array = _dnorm(float(b[0]), float(b[1]))
	var sign_a: float = signf(na[0])
	var sign_b: float = signf(nb[0])
	if sign_a != sign_b:
		return -1 if sign_a < sign_b else 1
	if sign_a == 0.0:
		return 0
	# Compare in log10 space (exponent + log10 of the mantissa). A normalized mantissa in [1, 10)
	# spans a whole order of magnitude, so exponent-first ordering is wrong once exponents are
	# fractional (Make with a float exponent, or Power with a fractional power).
	var mag_a: float = float(na[1]) + log(absf(na[0])) / log(10.0)
	var mag_b: float = float(nb[1]) + log(absf(nb[0])) / log(10.0)
	var result: int = 0
	if not is_equal_approx(mag_a, mag_b):
		result = -1 if mag_a < mag_b else 1
	return result if sign_a > 0.0 else -result

# Big Numbers: register as the BigNumber autoload, then format idle-scale numbers from any sheet - Format Short turns 1250000 into "1.25M" and keeps going past a trillion (Qa, Qi ... Dc, then scientific). For values beyond a float's 1.8e308 ceiling, the Decimal type (Make / Add / Multiply / Power / Format Big) stores a mantissa and exponent so numbers never overflow. This pack is an event sheet - extend it by editing it.
