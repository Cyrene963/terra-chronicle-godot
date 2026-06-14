extends Node2D

@onready var player_light: PointLight2D = PointLight2D.new()
@onready var time_system = get_node("/root/TimeSystem")

# Ambient colors for different seasons (spring, summer, autumn, winter)
const AMBIENT_COLORS = [
	Color(0.314, 0.337, 0.518),  # Spring
	Color(0.259, 0.282, 0.455),  # Summer
	Color(0.376, 0.341, 0.443),  # Autumn
	Color(0.424, 0.431, 0.498)   # Winter
]

# Target night colors (RGB: 70, 86, 132)
const NIGHT_COLOR = Color(0.275, 0.337, 0.518)

# Dawn/Dusk color (#e89646)
const DUSK_COLOR = Color(0.910, 0.588, 0.275)

func _ready():
	# Configure the point light
	player_light.enabled = true
	player_light.texture = preload("res://assets/lighting/light_texture.png") if ResourceLoader.exists("res://assets/lighting/light_texture.png") else null
	player_light.texture_scale = 3.0
	player_light.energy = 1.0
	player_light.shadow_enabled = false
	player_light.blend_mode = Light2D.BLEND_MODE_ADD

	add_child(player_light)

	# Connect to time system signals
	if time_system:
		time_system.time_of_day_changed.connect(_on_time_of_day_changed)
		# Initial update
		_update_lighting(time_system.time_of_day)

func _process(_delta):
	# Update light position to follow player
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player_light.global_position = player.global_position

func _on_time_of_day_changed(time_of_day: float):
	_update_lighting(time_of_day)

func _update_lighting(time_of_day: float):
	# Get current season for ambient color
	var season = time_system.season if time_system else 0
	var ambient = AMBIENT_COLORS[season]

	var light_color: Color
	var light_energy: float

	# Time phases:
	# 0.0-0.25: Dawn
	# 0.25-0.5: Noon
	# 0.5-0.75: Dusk
	# 0.75-1.0: Night

	if time_of_day < 0.25:
		# Dawn phase (symmetric with dusk)
		var dawn_progress = time_of_day / 0.25
		# Fade from night to dusk color
		var night_factor = 1.0 - dawn_progress
		var dusk_factor = dawn_progress

		var night_ambient = Color(
			lerp(ambient.r, NIGHT_COLOR.r, night_factor),
			lerp(ambient.g, NIGHT_COLOR.g, night_factor),
			lerp(ambient.b, NIGHT_COLOR.b, night_factor)
		)

		light_color = night_ambient.lerp(DUSK_COLOR, dusk_factor)
		light_energy = lerp(0.3, 0.7, dawn_progress)

	elif time_of_day < 0.5:
		# Noon phase (morning to midday)
		var noon_progress = (time_of_day - 0.25) / 0.25
		# Fade from dusk color to bright noon
		var night = 1.0 - noon_progress

		light_color = Color(
			lerp(ambient.r, 0.275, night * 0.78),
			lerp(ambient.g, 0.337, night * 0.74),
			lerp(ambient.b, 0.518, night * 0.6)
		)

		light_energy = lerp(0.7, 1.0, noon_progress)

	elif time_of_day < 0.75:
		# Dusk phase (afternoon to evening)
		var dusk_progress = (time_of_day - 0.5) / 0.25
		# Fade from noon to dusk color
		var night = dusk_progress

		var noon_color = Color(
			lerp(ambient.r, 0.275, 0.0),
			lerp(ambient.g, 0.337, 0.0),
			lerp(ambient.b, 0.518, 0.0)
		)

		light_color = noon_color.lerp(DUSK_COLOR, dusk_progress)
		light_energy = lerp(1.0, 0.7, dusk_progress)

	else:
		# Night phase
		var night_progress = (time_of_day - 0.75) / 0.25
		var night_factor = night_progress

		# Fade from dusk color to night ambient
		var night_ambient = Color(
			lerp(ambient.r, NIGHT_COLOR.r, night_factor),
			lerp(ambient.g, NIGHT_COLOR.g, night_factor),
			lerp(ambient.b, NIGHT_COLOR.b, night_factor)
		)

		light_color = DUSK_COLOR.lerp(night_ambient, night_progress)
		light_energy = lerp(0.7, 0.3, night_progress)

	# Apply the calculated values
	player_light.color = light_color
	player_light.energy = light_energy
