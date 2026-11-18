extends Node


class Radio:
	enum Band {
		AM,
		FM = 4,
	}
	signal tuned(to: float)
	var band: int = 0
	class Preset:
		var label: String = ""
		var frequency: float = 88.5
	func tune(to: float) -> void:
		band = int(to)


var radio: Radio = Radio.new()
