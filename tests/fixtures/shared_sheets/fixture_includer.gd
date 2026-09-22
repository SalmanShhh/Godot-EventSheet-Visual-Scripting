extends FixtureDamageRules

var _fixture_pause_handling := FixturePauseHandling.new()


func _process(delta: float) -> void:
	super(delta)
	_fixture_pause_handling.on_tick(self, delta)
