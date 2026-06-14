extends CharacterBody2D

const SPEED = 235
const SQRT1_2 = 0.7071067811865476

# Navigation
@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D
var path_following := false
var current_path: Array[Vector2] = []
var path_index := 0
var stuck_timer := 0.0
var last_position := Vector2.ZERO
var pending_action: Callable

# Animation
enum AnimState { IDLE, WALK }
var anim_state := AnimState.IDLE
var facing_direction := Vector2.DOWN

# Collision
var blocked_tiles: Dictionary = {}  # Set of blocked tile coords
var collision_objects: Array[Dictionary] = []  # [{pos: Vector2, radius: float}]

# Player footprint test points (±12x, ±6y)
const FOOTPRINT_OFFSETS = [
	Vector2(-12, -6),
	Vector2(12, -6),
	Vector2(-12, 6),
	Vector2(12, 6)
]


func _ready() -> void:
	nav_agent.path_desired_distance = 4.0
	nav_agent.target_desired_distance = 8.0
	nav_agent.max_speed = SPEED

	last_position = global_position


func _physics_process(delta: float) -> void:
	var input_velocity := Vector2.ZERO

	# WASD input
	if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D):
		input_velocity.x += 1
	if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A):
		input_velocity.x -= 1
	if Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S):
		input_velocity.y += 1
	if Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W):
		input_velocity.y -= 1

	# Cancel path if WASD pressed
	if input_velocity.length_squared() > 0:
		path_following = false
		current_path.clear()
		pending_action = Callable()

	# Normalize diagonal movement
	if input_velocity.length_squared() > 1.0:
		input_velocity *= SQRT1_2

	# Handle click-to-move navigation
	if path_following and current_path.size() > 0:
		var target_velocity := _follow_path(delta)
		if target_velocity.length_squared() > 0:
			input_velocity = target_velocity
		else:
			# Path complete
			path_following = false
			if pending_action.is_valid():
				pending_action.call()
				pending_action = Callable()

	# Apply movement with collision
	if input_velocity.length_squared() > 0:
		var desired_velocity = input_velocity * SPEED
		_move_with_collision(desired_velocity, delta)
		_update_animation(AnimState.WALK, input_velocity)
	else:
		_update_animation(AnimState.IDLE, facing_direction)

	# Stuck detection
	if path_following:
		if global_position.distance_squared_to(last_position) < 1.0:
			stuck_timer += delta
			if stuck_timer > 0.5:
				path_following = false
				current_path.clear()
				stuck_timer = 0.0
		else:
			stuck_timer = 0.0
			last_position = global_position


func _move_with_collision(desired_velocity: Vector2, delta: float) -> void:
	var dx = desired_velocity.x * delta
	var dy = desired_velocity.y * delta

	# Try X movement
	var new_pos_x = global_position + Vector2(dx, 0)
	if _can_move_to(new_pos_x):
		global_position.x = new_pos_x.x

	# Try Y movement
	var new_pos_y = global_position + Vector2(0, dy)
	if _can_move_to(new_pos_y):
		global_position.y = new_pos_y.y


func _can_move_to(pos: Vector2) -> bool:
	# Check all footprint points
	for offset in FOOTPRINT_OFFSETS:
		var check_pos = pos + offset

		# Check tile collision
		var tile_x = int(floor(check_pos.x / 32))
		var tile_y = int(floor(check_pos.y / 32))
		var tile_key = Vector2i(tile_x, tile_y)
		if blocked_tiles.has(tile_key):
			return false

		# Check circular colliders (elliptical test)
		for obj in collision_objects:
			var delta_pos = check_pos - obj.pos
			var ellipse_test = delta_pos.x * delta_pos.x + (delta_pos.y * 1.6) * (delta_pos.y * 1.6)
			if ellipse_test < obj.radius * obj.radius:
				return false

	return true


func _follow_path(delta: float) -> Vector2:
	if path_index >= current_path.size():
		return Vector2.ZERO

	var target = current_path[path_index]
	var direction = (target - global_position).normalized()
	var distance = global_position.distance_to(target)

	# Reached waypoint
	if distance < 8.0:
		path_index += 1
		if path_index >= current_path.size():
			return Vector2.ZERO
		return _follow_path(delta)

	return direction


func command_to(world_x: float, world_y: float, action: Callable = Callable()) -> void:
	var target_pos = Vector2(world_x, world_y)

	# Check if target is walkable
	if not _can_move_to(target_pos):
		# Find nearest walkable neighbor
		target_pos = _find_nearest_walkable(target_pos)
		if target_pos == Vector2.ZERO:
			return  # No walkable position found

	# Request path from NavigationAgent2D
	nav_agent.target_position = target_pos
	await get_tree().process_frame  # Wait for navigation to compute

	if nav_agent.is_navigation_finished():
		return

	# Get path and smooth it
	var raw_path = nav_agent.get_current_navigation_path()
	current_path = _smooth_path(raw_path)

	if current_path.size() > 0:
		path_following = true
		path_index = 0
		pending_action = action
		stuck_timer = 0.0


func _smooth_path(raw_path: PackedVector2Array) -> Array[Vector2]:
	if raw_path.size() <= 2:
		var result: Array[Vector2] = []
		for p in raw_path:
			result.append(p)
		return result

	var smoothed: Array[Vector2] = []
	smoothed.append(raw_path[0])

	var i = 0
	while i < raw_path.size() - 1:
		var j = raw_path.size() - 1
		var found_skip = false

		# Try to find furthest visible point
		while j > i + 1:
			if _line_walk_clear(raw_path[i], raw_path[j]):
				smoothed.append(raw_path[j])
				i = j
				found_skip = true
				break
			j -= 1

		if not found_skip:
			i += 1
			if i < raw_path.size():
				smoothed.append(raw_path[i])

	return smoothed


func _line_walk_clear(from: Vector2, to: Vector2) -> bool:
	var distance = from.distance_to(to)
	var steps = int(distance / 8.0)
	if steps < 2:
		return true

	for i in range(1, steps):
		var t = float(i) / float(steps)
		var check_pos = from.lerp(to, t)
		if not _can_move_to(check_pos):
			return false

	return true


func _find_nearest_walkable(center: Vector2) -> Vector2:
	# Search in expanding radius
	for radius in range(1, 8):
		for angle_step in range(8):
			var angle = angle_step * PI / 4.0
			var offset = Vector2(cos(angle), sin(angle)) * radius * 32
			var test_pos = center + offset
			if _can_move_to(test_pos):
				return test_pos

	return Vector2.ZERO


func _update_animation(state: AnimState, direction: Vector2) -> void:
	if direction.length_squared() > 0:
		facing_direction = direction.normalized()

	if anim_state != state:
		anim_state = state
		_emit_animation_change()


func _emit_animation_change() -> void:
	# Signal for animation system
	# Example: animation_player.play("walk" if anim_state == AnimState.WALK else "idle")
	pass


# Public API for setting collision data
func set_blocked_tiles(tiles: Dictionary) -> void:
	blocked_tiles = tiles


func set_collision_objects(objects: Array[Dictionary]) -> void:
	collision_objects = objects


func add_collision_object(pos: Vector2, radius: float) -> void:
	collision_objects.append({"pos": pos, "radius": radius})


func remove_collision_object(pos: Vector2) -> void:
	for i in range(collision_objects.size() - 1, -1, -1):
		if collision_objects[i].pos.distance_squared_to(pos) < 1.0:
			collision_objects.remove_at(i)
			break
