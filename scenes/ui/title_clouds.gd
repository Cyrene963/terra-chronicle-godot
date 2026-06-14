extends ColorRect

@export var fade_start_time: float = 2.5
@export var fade_duration: float = 1.0

var elapsed_time: float = 0.0
var fading: bool = false
var fade_progress: float = 0.0

func _ready() -> void:
	modulate.a = 1.0

func _process(delta: float) -> void:
	elapsed_time += delta

	# Update shader time parameter
	if material and material is ShaderMaterial:
		material.set_shader_parameter("time", elapsed_time)

	# Start fading after fade_start_time
	if elapsed_time >= fade_start_time and not fading:
		fading = true
		fade_progress = 0.0

	# Handle fade out
	if fading:
		fade_progress += delta / fade_duration
		modulate.a = 1.0 - clamp(fade_progress, 0.0, 1.0)

		if fade_progress >= 1.0:
			queue_free()
