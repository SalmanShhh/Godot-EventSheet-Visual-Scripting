@tool
extends SceneTree


func _initialize() -> void:
	var ok: bool = LongTailReadingTest.run()
	print("VERDICT: %s" % ("All tests passed." if ok else "Some tests failed."))
	quit(0)
