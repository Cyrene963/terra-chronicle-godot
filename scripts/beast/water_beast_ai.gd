extends CharacterBody2D

# Water Beast AI - Autonomous crop watering behavior
# State machine: IDLE -> SEEKING -> MOVING -> WATERING -> IDLE

enum State {
	IDLE,
	SEEKING,
	MOVING,
	WATERING
}

# Configuration
@export var move_speed: float = 80.0
@export var scan_interval: float = 2.0
@export var scan_radius: float = 400.0
@export var moisture_threshold: int = 30
@export var watering_amount: int = 100
@export var watering_duration: float = 1.5
@export var idle_duration: float = 1.0

# State
var current_state: State = State.IDLE
var target_crop: Node2D = null
var state_timer: float = 0.0

# Components
@onready var navigation_agent: NavigationAgent2D = $NavigationAgent2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer if has_node("AnimationPlayer") else null
@onready var sprite: Sprite2D = $Sprite2D if has_node("Sprite2D") else null

# Scan timer
var scan_timer: float = 0.0

func _ready() -> void:
	# Configure navigation agent
	if navigation_agent:
		navigation_agent.path_desired_distance = 8.0
		navigation_agent.target_desired_distance = 16.0
		navigation_agent.avoidance_enabled = true
		navigation_agent.radius = 16.0

	# Start in IDLE state
	change_state(State.IDLE)

	# Wait for navigation map to be ready
	call_deferred("_setup_navigation")

func _setup_navigation() -> void:
	await get_tree().physics_frame
	if navigation_agent:
		navigation_agent.velocity_computed.connect(_on_velocity_computed)

func _physics_process(delta: float) -> void:
	state_timer += delta
	scan_timer += delta

	# Periodic crop scanning
	if scan_timer >= scan_interval:
		scan_timer = 0.0
		if current_state == State.IDLE or current_state == State.SEEKING:
			scan_for_thirsty_crops()

	# State machine
	match current_state:
		State.IDLE:
			process_idle_state(delta)
		State.SEEKING:
			process_seeking_state(delta)
		State.MOVING:
			process_moving_state(delta)
		State.WATERING:
			process_watering_state(delta)

	# Apply movement
	move_and_slide()

func process_idle_state(_delta: float) -> void:
	velocity = Vector2.ZERO

	# Wait for idle duration, then start seeking
	if state_timer >= idle_duration:
		change_state(State.SEEKING)

func process_seeking_state(_delta: float) -> void:
	velocity = Vector2.ZERO

	# Scan is handled by periodic timer
	# If a target was found, transition happens in scan_for_thirsty_crops()

func process_moving_state(delta: float) -> void:
	# Verify target is still valid and thirsty
	if not is_instance_valid(target_crop) or not is_crop_thirsty(target_crop):
		change_state(State.IDLE)
		return

	# Check if reached target
	if navigation_agent and navigation_agent.is_navigation_finished():
		change_state(State.WATERING)
		return

	# Navigate towards target
	if navigation_agent and not navigation_agent.is_navigation_finished():
		var next_path_position: Vector2 = navigation_agent.get_next_path_position()
		var direction: Vector2 = (next_path_position - global_position).normalized()

		# Calculate desired velocity
		var desired_velocity: Vector2 = direction * move_speed

		# Use avoidance if enabled
		if navigation_agent.avoidance_enabled:
			navigation_agent.set_velocity(desired_velocity)
		else:
			velocity = desired_velocity

		# Flip sprite based on movement direction
		if sprite and abs(direction.x) > 0.1:
			sprite.flip_h = direction.x < 0

func process_watering_state(_delta: float) -> void:
	velocity = Vector2.ZERO

	# Water the crop
	if state_timer >= watering_duration:
		if is_instance_valid(target_crop):
			water_crop(target_crop)
		change_state(State.IDLE)

func scan_for_thirsty_crops() -> void:
	var thirsty_crops: Array[Node2D] = []

	# Get all crop nodes in range
	var crops = get_tree().get_nodes_in_group("crops")

	for crop in crops:
		if not crop is Node2D:
			continue

		var distance = global_position.distance_to(crop.global_position)
		if distance <= scan_radius and is_crop_thirsty(crop):
			thirsty_crops.append(crop)

	# Find closest thirsty crop
	if thirsty_crops.size() > 0:
		var closest_crop: Node2D = null
		var closest_distance: float = INF

		for crop in thirsty_crops:
			var distance = global_position.distance_to(crop.global_position)
			if distance < closest_distance:
				closest_distance = distance
				closest_crop = crop

		if closest_crop:
			set_target_crop(closest_crop)

func is_crop_thirsty(crop: Node2D) -> bool:
	if not is_instance_valid(crop):
		return false

	# Check for moisture property
	if crop.has_method("get_moisture"):
		return crop.get_moisture() < moisture_threshold
	elif "moisture" in crop:
		return crop.moisture < moisture_threshold

	return false

func set_target_crop(crop: Node2D) -> void:
	target_crop = crop

	if navigation_agent:
		navigation_agent.target_position = crop.global_position

	change_state(State.MOVING)

func water_crop(crop: Node2D) -> void:
	if not is_instance_valid(crop):
		return

	# Set moisture to watering_amount
	if crop.has_method("set_moisture"):
		crop.set_moisture(watering_amount)
	elif "moisture" in crop:
		crop.moisture = watering_amount

	# Emit signal or visual feedback
	emit_watering_effect()

	print("Water Beast watered crop at ", crop.global_position)

func emit_watering_effect() -> void:
	# Play animation if available
	if animation_player and animation_player.has_animation("water"):
		animation_player.play("water")

	# TODO: Spawn water particle effect
	# var effect = preload("res://effects/water_splash.tscn").instantiate()
	# get_parent().add_child(effect)
	# effect.global_position = global_position

func change_state(new_state: State) -> void:
	# Exit current state
	match current_state:
		State.MOVING:
			if navigation_agent:
				navigation_agent.set_velocity(Vector2.ZERO)

	# Enter new state
	current_state = new_state
	state_timer = 0.0

	match new_state:
		State.IDLE:
			target_crop = null
		State.SEEKING:
			target_crop = null
		State.WATERING:
			pass

	# Debug logging
	if OS.is_debug_build():
		print("Water Beast state: ", State.keys()[new_state])

func _on_velocity_computed(safe_velocity: Vector2) -> void:
	# Called by NavigationAgent2D when avoidance is enabled
	velocity = safe_velocity

# Optional: Manual command interface
func command_water_crop(crop: Node2D) -> void:
	if is_instance_valid(crop):
		set_target_crop(crop)

func get_current_state_name() -> String:
	return State.keys()[current_state]
