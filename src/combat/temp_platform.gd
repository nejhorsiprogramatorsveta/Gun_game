class_name TempPlatform
extends Platform
## Architekt's arcade platform: a one-way plank that appears under the feet and
## disappears after `lifetime` seconds (blinking at the end).

var owner_peer_id := 0
var lifetime := 3.0
var _age := 0.0


func _process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		queue_free()
		return
	var blink := lifetime - _age < 0.6 and int(_age * 10.0) % 2 == 0
	modulate.a = 0.4 if blink else 1.0
