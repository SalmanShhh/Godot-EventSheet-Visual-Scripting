@tool
extends RefCounted


static func run() -> bool:
	var passed: bool = true
	var coin: int = 10
	passed = _check("a coin is worth ten", coin, 10) and passed
	passed = _check("two coins are worth twenty", coin * 2, 20) and passed
	return passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] %s" % label)
		return true
	print("[FAIL] %s: got %s expected %s" % [label, actual, expected])
	return false
