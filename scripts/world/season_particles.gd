extends Node2D
class_name SeasonParticles

# Particle emitters for different seasons
var snow_particles: CPUParticles2D
var leaf_particles: CPUParticles2D
var current_emitter: CPUParticles2D

# Textures
var snow_texture: Texture2D
var leaf_texture: Texture2D

# Camera reference for viewport-relative spawning
var camera: Camera2D

func _ready():
	# Get camera reference
	camera = get_viewport().get_camera_2d()

	# Create textures
	_create_textures()

	# Create particle emitters
	_create_snow_particles()
	_create_leaf_particles()

	# Connect to TimeSystem season changes
	if TimeSystem:
		TimeSystem.season_changed.connect(_on_season_changed)
		# Initialize with current season
		_on_season_changed(TimeSystem.current_season)
	else:
		# Default to no particles if TimeSystem not available
		_deactivate_all_particles()

func _create_textures():
	# Create snow texture (white circle)
	var snow_img = Image.create(8, 8, false, Image.FORMAT_RGBA8)
	snow_img.fill(Color.TRANSPARENT)
	for y in range(8):
		for x in range(8):
			var dx = x - 4.0
			var dy = y - 4.0
			var dist = sqrt(dx * dx + dy * dy)
			if dist <= 4.0:
				var alpha = 1.0 - (dist / 4.0) * 0.3
				snow_img.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	snow_texture = ImageTexture.create_from_image(snow_img)

	# Create leaf texture (ellipse)
	var leaf_img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	leaf_img.fill(Color.TRANSPARENT)
	for y in range(16):
		for x in range(16):
			var dx = (x - 8.0) / 7.0
			var dy = (y - 8.0) / 4.2
			var dist = sqrt(dx * dx + dy * dy)
			if dist <= 1.0:
				var alpha = 1.0 - (dist * 0.2)
				leaf_img.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	leaf_texture = ImageTexture.create_from_image(leaf_img)

func _create_snow_particles():
	snow_particles = CPUParticles2D.new()
	add_child(snow_particles)

	# Basic setup
	snow_particles.emitting = false
	snow_particles.amount = 150
	snow_particles.lifetime = 14.0  # Average fall time ~12s
	snow_particles.preprocess = 2.0
	snow_particles.texture = snow_texture

	# Emission
	snow_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	snow_particles.emission_rect_extents = Vector2(960, 10)  # Will be updated in _process

	# Color
	snow_particles.color = Color("#f8fafc")

	# Scale
	snow_particles.scale_amount_min = 0.45
	snow_particles.scale_amount_max = 1.1

	# Direction and velocity
	snow_particles.direction = Vector2(0, 1)
	snow_particles.spread = 5.0
	snow_particles.gravity = Vector2(0, 0)
	snow_particles.initial_velocity_min = 40.0
	snow_particles.initial_velocity_max = 70.0

	# Angular velocity (spin)
	snow_particles.angular_velocity_min = -25.0
	snow_particles.angular_velocity_max = 25.0

	# Damping and acceleration for sway effect
	snow_particles.linear_accel_min = -5.0
	snow_particles.linear_accel_max = 5.0
	snow_particles.tangential_accel_min = -8.0
	snow_particles.tangential_accel_max = 8.0

	# Alpha
	var alpha_curve = Curve.new()
	alpha_curve.add_point(Vector2(0.0, 0.0))
	alpha_curve.add_point(Vector2(0.1, 0.6))
	alpha_curve.add_point(Vector2(0.9, 0.8))
	alpha_curve.add_point(Vector2(1.0, 0.0))
	snow_particles.scale_amount_curve = alpha_curve

func _create_leaf_particles():
	leaf_particles = CPUParticles2D.new()
	add_child(leaf_particles)

	# Basic setup
	leaf_particles.emitting = false
	leaf_particles.amount = 100
	leaf_particles.lifetime = 14.0  # Average fall time ~12s
	leaf_particles.preprocess = 2.0
	leaf_particles.texture = leaf_texture

	# Emission
	leaf_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	leaf_particles.emission_rect_extents = Vector2(960, 10)  # Will be updated in _process

	# Color (orange/red autumn colors)
	leaf_particles.color = Color("#c47834")
	var color_ramp = Gradient.new()
	color_ramp.add_point(0.0, Color("#d4854a"))
	color_ramp.add_point(0.5, Color("#c47834"))
	color_ramp.add_point(1.0, Color("#a85a28"))
	leaf_particles.color_ramp = color_ramp

	# Scale
	leaf_particles.scale_amount_min = 0.45
	leaf_particles.scale_amount_max = 1.1

	# Direction and velocity
	leaf_particles.direction = Vector2(-0.3, 1)
	leaf_particles.spread = 8.0
	leaf_particles.gravity = Vector2(0, 0)
	leaf_particles.initial_velocity_min = 50.0
	leaf_particles.initial_velocity_max = 85.0

	# Angular velocity (more dramatic spin for leaves)
	leaf_particles.angular_velocity_min = -115.0
	leaf_particles.angular_velocity_max = 115.0

	# Damping and acceleration for drift/sway effect
	leaf_particles.linear_accel_min = -8.0
	leaf_particles.linear_accel_max = 8.0
	leaf_particles.tangential_accel_min = -15.0
	leaf_particles.tangential_accel_max = 15.0

	# Alpha
	var alpha_curve = Curve.new()
	alpha_curve.add_point(Vector2(0.0, 0.0))
	alpha_curve.add_point(Vector2(0.1, 0.6))
	alpha_curve.add_point(Vector2(0.9, 0.8))
	alpha_curve.add_point(Vector2(1.0, 0.0))
	leaf_particles.scale_amount_curve = alpha_curve

func _process(_delta):
	if not camera:
		camera = get_viewport().get_camera_2d()
		return

	# Update emitter position to spawn above camera view
	if current_emitter:
		var viewport_size = get_viewport_rect().size
		var camera_pos = camera.get_screen_center_position()
		var spawn_y = camera_pos.y - viewport_size.y / 2.0 - 50.0  # Spawn above visible area

		current_emitter.position = Vector2(camera_pos.x, spawn_y)
		current_emitter.emission_rect_extents = Vector2(viewport_size.x / 2.0 + 100.0, 10)

func _on_season_changed(season_index: int):
	_deactivate_all_particles()

	match season_index:
		2:  # Autumn
			current_emitter = leaf_particles
			leaf_particles.emitting = true
		3:  # Winter
			current_emitter = snow_particles
			snow_particles.emitting = true
		_:  # Spring (0) and Summer (1) - no particles
			current_emitter = null

func _deactivate_all_particles():
	if snow_particles:
		snow_particles.emitting = false
	if leaf_particles:
		leaf_particles.emitting = false
	current_emitter = null

func _exit_tree():
	_deactivate_all_particles()
