class_name DayClock
extends Node
## Moves GameState.hour along and announces dawn and dusk. The run opens at dusk (hour 20).

const CLOCK := {
	"real_minutes_per_day": 12.0, ## one full day-night cycle in real minutes
	"dawn_hour": 6.0,
	"dusk_hour": 20.0,
	"emit_every_hours": 0.1, ## how often time_of_day_changed fires
}

var _since_emit := 0.0
var _was_night := true


func _ready() -> void:
	name = "DayClock"
	_was_night = GameState.is_night()


func _physics_process(delta: float) -> void:
	advance(delta * 24.0 / (CLOCK.real_minutes_per_day * 60.0))


## Advance the clock by game hours (tests call this directly).
func advance(hours: float) -> void:
	var h := GameState.hour + hours
	while h >= 24.0:
		h -= 24.0
	GameState.hour = h
	_since_emit += hours
	var night := GameState.is_night()
	if night != _was_night:
		_was_night = night
		if night:
			Events.night_started.emit(GameState.day)
		else:
			GameState.day += 1
			Events.day_started.emit(GameState.day)
	if _since_emit >= CLOCK.emit_every_hours:
		_since_emit = 0.0
		Events.time_of_day_changed.emit(GameState.hour, night)
