extends CharacterBody2D
class_name FireBeastAI

# Fire Beast AI - Seeks forges and guards them, boosting crafting quality

enum State {
	IDLE,
	SEEKING_FORGE,
	GUARDING
}

# Configuration
const MOVE_SPEED = 80.0
const GUARD_RADIUS = 64.0
const FORGE_DETECTION_RADIUS = 300.0
const QUALITY_BOOST = 1.5
const WANDER_RADIUS = 100.0
const STATE_CHECK_INTERVAL = 1.0

# State
var current_state: State = State.IDLE
var target_forge: Node2D = null
var home_position: Vector2
var wander_target: Vector2
var state_timer: float = 0.0

# Animation & Visual
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D if has_node("AnimatedSprite2D") else null
@onready var guard_area: Area2D = $GuardArea if has_node("GuardArea") else null

func _ready() -> void:
	home_position = global_position
	wander_target = global_position

	# Setup guard area if it doesn't exist
	if not guard_area:
		guard_area = Area2D.new()
		guard_area.name = "GuardArea"
		add_child(guard_area)

		var collision = CollisionShape2D.new()
		var circle = CircleShape2D.new()
		circle.radius = GUARD_RADIUS
		collision.shape = circle
		guard_area.add_child(collision)

	# Connect to forge signals if possible
	guard_area.area_entered.connect(_on_guard_area_entered)
	guard_area.body_entered.connect(_on_guard_area_body_entered)

	change_state(State.IDLE)

func _physics_process(delta: float) -> void:
	state_timer += delta

	match current_state:
		State.IDLE:
			_process_idle(delta)
		State.SEEKING_FORGE:
			_process_seeking(delta)
		State.GUARDING:
			_process_guarding(delta)

	move_and_slide()
	_update_animation()

func _process_idle(delta: float) -> void:
	# Check for nearby forges periodically
	if state_timer >= STATE_CHECK_INTERVAL:
		state_timer = 0.0
		var forge = _find_nearest_forge()
		if forge:
			target_forge = forge
			change_state(State.SEEKING_FORGE)
			return

	# Wander behavior
	if global_position.distance_to(wander_target) < 10.0:
		_pick_new_wander_target()

	var direction = (wander_target - global_position).normalized()
	velocity = direction * MOVE_SPEED * 0.5

func _process_seeking(delta: float) -> void:
	if not is_instance_valid(target_forge):
		target_forge = null
		change_state(State.IDLE)
		return

	var distance = global_position.distance_to(target_forge.global_position)

	# Reached guard position
	if distance <= GUARD_RADIUS:
		change_state(State.GUARDING)
		return

	# Move toward forge
	var direction = (target_forge.global_position - global_position).normalized()
	velocity = direction * MOVE_SPEED

func _process_guarding(delta: float) -> void:
	if not is_instance_valid(target_forge):
		target_forge = null
		change_state(State.IDLE)
		return

	var distance = global_position.distance_to(target_forge.global_position)

	# If forge moved or we drifted too far, return to seeking
	if distance > GUARD_RADIUS * 1.5:
		change_state(State.SEEKING_FORGE)
		return

	# Apply quality boost to forge
	_apply_quality_boost()

	# Maintain position near forge (orbit slowly)
	if distance > GUARD_RADIUS * 0.8:
		var direction = (target_forge.global_position - global_position).normalized()
		velocity = direction * MOVE_SPEED * 0.3
	else:
		# Slow orbit around forge
		var to_forge = target_forge.global_position - global_position
		var perpendicular = Vector2(-to_forge.y, to_forge.x).normalized()
		velocity = perpendicular * MOVE_SPEED * 0.2

func change_state(new_state: State) -> void:
	if current_state == new_state:
		return

	# Exit current state
	match current_state:
		State.GUARDING:
			_remove_quality_boost()

	current_state = new_state
	state_timer = 0.0

	# Enter new state
	match new_state:
		State.IDLE:
			_pick_new_wander_target()
		State.SEEKING_FORGE:
			pass
		State.GUARDING:
			pass

func _find_nearest_forge() -> Node2D:
	var forges = get_tree().get_nodes_in_group("forge")
	var nearest: Node2D = null
	var nearest_distance = FORGE_DETECTION_RADIUS

	for forge in forges:
		if not is_instance_valid(forge) or not forge is Node2D:
			continue

		var distance = global_position.distance_to(forge.global_position)
		if distance < nearest_distance:
			nearest = forge
			nearest_distance = distance

	return nearest

func _pick_new_wander_target() -> void:
	var angle = randf() * TAU
	var distance = randf_range(20.0, WANDER_RADIUS)
	wander_target = home_position + Vector2(cos(angle), sin(angle)) * distance

func _apply_quality_boost() -> void:
	if not is_instance_valid(target_forge):
		return

	# Apply quality boost through metadata or direct property
	if target_forge.has_method("set_quality_multiplier"):
		target_forge.set_quality_multiplier(QUALITY_BOOST)
	elif target_forge.has_meta("quality_multiplier"):
		target_forge.set_meta("quality_multiplier", QUALITY_BOOST)
	else:
		# Set metadata for external systems to read
		target_forge.set_meta("fire_beast_boost", QUALITY_BOOST)

func _remove_quality_boost() -> void:
	if not is_instance_valid(target_forge):
		return

	if target_forge.has_method("set_quality_multiplier"):
		target_forge.set_quality_multiplier(1.0)
	elif target_forge.has_meta("quality_multiplier"):
		target_forge.set_meta("quality_multiplier", 1.0)
	else:
		target_forge.remove_meta("fire_beast_boost")

func _update_animation() -> void:
	if not sprite:
		return

	var speed = velocity.length()

	if speed < 10.0:
		if sprite.sprite_frames.has_animation("idle"):
			sprite.play("idle")
	else:
		if sprite.sprite_frames.has_animation("walk"):
			sprite.play("walk")

	# Flip sprite based on direction
	if velocity.x != 0:
		sprite.flip_h = velocity.x < 0

func _on_guard_area_entered(area: Area2D) -> void:
	# React to entities entering guard radius
	pass

func _on_guard_area_body_entered(body: Node2D) -> void:
	# React to bodies entering guard radius
	pass

# Public API for external systems
func get_guarded_forge() -> Node2D:
	if current_state == State.GUARDING:
		return target_forge
	return null

func is_guarding() -> bool:
	return current_state == State.GUARDING

func get_quality_boost() -> float:
	if current_state == State.GUARDING and is_instance_valid(target_forge):
		return QUALITY_BOOST
	return 1.0
