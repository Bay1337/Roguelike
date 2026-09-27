extends Camera2D

var shake_intensity: float = 0.0
var shake_decay: float = 5.0

func _ready() -> void:
	add_to_group("camera")

func _process(delta: float) -> void:
	if shake_intensity > 0:
		# Decay the shake over time
		shake_intensity = move_toward(shake_intensity, 0.0, shake_decay * delta)
		# Random offset mapping
		offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake_intensity
	else:
		offset = Vector2.ZERO

func apply_shake(intensity: float) -> void:
	shake_intensity = intensity
