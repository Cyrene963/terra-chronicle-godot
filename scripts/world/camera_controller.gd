extends Camera2D

## Camera controller with smooth follow, zoom control, and boundary clamping
## Follows the player with spring-damped lerp and supports zoom toggle

# Smooth follow configuration
const FOLLOW_LERP_FACTOR: float = 4.2

# Zoom configuration
const ZOOM_LERP_FACTOR: float = 2.2
const DEFAULT_ZOOM: float = 0.62
const ENTRY_ZOOM: float = 1.0

# World boundaries (56x56 map in pixels, assuming 16px tiles)
const WORLD_WIDTH: int = 56 * 16  # 896 pixels
const WORLD_HEIGHT: int = 56 * 16  # 896 pixels

# Internal state
var target_zoom: float = DEFAULT_ZOOM
var current_zoom: float = DEFAULT_ZOOM
var is_zoomed_in: bool = false

# References
var player: Node2D = null
var world_container: Node = null

func _ready() -> void:
	# Initialize zoom
	current_zoom = DEFAULT_ZOOM
	target_zoom = DEFAULT_ZOOM

	# Find player reference (adjust path as needed)
	call_deferred("_find_player")

	# Find world container for zoom scaling (adjust path as needed)
	call_deferred("_find_world_container")

func _find_player() -> void:
	# Try to find player node - adjust the path based on your scene structure
	player = get_tree().get_first_node_in_group("player")
	if not player:
		# Fallback: try common paths
		if has_node("../Player"):
			player = get_node("../Player")
		elif has_node("../../Player"):
			player = get_node("../../Player")
		else:
			push_warning("Camera: Player node not found. Add player to 'player' group or adjust path.")

func _find_world_container() -> void:
	# Try to find world container - adjust based on your scene structure
	var parent = get_parent()
	if parent:
		world_container = parent
	else:
		push_warning("Camera: World container not found. Zoom scaling may not work correctly.")

func _process(delta: float) -> void:
	# Update zoom interpolation
	_update_zoom(delta)

	# Update camera position to follow player
	if player:
		_follow_player(delta)

func _unhandled_input(event: InputEvent) -> void:
	# Toggle zoom with F key
	if event.is_action_pressed("toggle_zoom"):
		toggle_zoom()
		get_viewport().set_input_as_handled()

func _follow_player(delta: float) -> void:
	if not player:
		return

	# Get player position
	var player_pos: Vector2 = player.global_position

	# Spring-damped smooth follow with lerp
	var lerp_weight: float = min(1.0, delta * FOLLOW_LERP_FACTOR)
	var target_pos: Vector2 = Vector2(
		global_position.x + (player_pos.x - global_position.x) * lerp_weight,
		global_position.y + (player_pos.y - global_position.y) * lerp_weight
	)

	# Clamp to world boundaries
	var clamped_pos: Vector2 = _clamp_to_boundaries(target_pos)

	# Apply position
	global_position = clamped_pos

func _clamp_to_boundaries(pos: Vector2) -> Vector2:
	# Get viewport size
	var viewport_size: Vector2 = get_viewport_rect().size

	# Calculate camera bounds based on zoom
	var half_view_width: float = (viewport_size.x * 0.5) / current_zoom
	var half_view_height: float = (viewport_size.y * 0.5) / current_zoom

	# Clamp position to keep camera within world boundaries
	var clamped_x: float = clampf(pos.x, half_view_width, WORLD_WIDTH - half_view_width)
	var clamped_y: float = clampf(pos.y, half_view_height, WORLD_HEIGHT - half_view_height)

	return Vector2(clamped_x, clamped_y)

func _update_zoom(delta: float) -> void:
	# Interpolate current zoom toward target zoom
	var lerp_weight: float = min(1.0, delta * ZOOM_LERP_FACTOR)
	current_zoom = current_zoom + (target_zoom - current_zoom) * lerp_weight

	# Apply zoom to camera
	zoom = Vector2(current_zoom, current_zoom)

	# If world container exists, apply scale
	if world_container and world_container.has_method("set_scale"):
		world_container.scale = Vector2(current_zoom, current_zoom)

func toggle_zoom() -> void:
	"""Toggle between default and entry zoom levels"""
	is_zoomed_in = not is_zoomed_in

	if is_zoomed_in:
		target_zoom = ENTRY_ZOOM
	else:
		target_zoom = DEFAULT_ZOOM

func set_camera_zoom(zoom_level: float) -> void:
	"""Set a specific zoom level"""
	target_zoom = clampf(zoom_level, 0.1, 2.0)  # Reasonable zoom range

func set_entry_zoom() -> void:
	"""Transition to entry zoom (used during world entry)"""
	target_zoom = ENTRY_ZOOM
	is_zoomed_in = true

func set_default_zoom() -> void:
	"""Reset to default zoom"""
	target_zoom = DEFAULT_ZOOM
	is_zoomed_in = false

func get_current_zoom() -> float:
	"""Get the current interpolated zoom value"""
	return current_zoom
