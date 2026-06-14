extends Panel

@onready var fertility_value = $MarginContainer/VBoxContainer/StatsContainer/FertilityRow/HBox/ValueLabel
@onready var fertility_bar = $MarginContainer/VBoxContainer/StatsContainer/FertilityRow/BarBackground/BarFill
@onready var moisture_value = $MarginContainer/VBoxContainer/StatsContainer/MoistureRow/HBox/ValueLabel
@onready var moisture_bar = $MarginContainer/VBoxContainer/StatsContainer/MoistureRow/BarBackground/BarFill
@onready var pest_value = $MarginContainer/VBoxContainer/StatsContainer/PestRow/HBox/ValueLabel
@onready var pest_bar = $MarginContainer/VBoxContainer/StatsContainer/PestRow/BarBackground/BarFill
@onready var mana_value = $MarginContainer/VBoxContainer/StatsContainer/ManaRow/HBox/ValueLabel
@onready var mana_bar = $MarginContainer/VBoxContainer/StatsContainer/ManaRow/BarBackground/BarFill
@onready var close_button = $CloseButton

var spring_velocity = 0.0
var spring_target = 110.0  # Off-screen by default
var spring_stiffness = 0.15
var spring_damping = 0.7

var bar_width = 272.0  # Full width of bars
var animation_duration = 1.1
var rollup_duration = 0.9

func _ready():
	visible = false
	close_button.pressed.connect(_on_close_pressed)
	# Set initial bar scales to 0
	fertility_bar.scale.x = 0
	moisture_bar.scale.x = 0
	pest_bar.scale.x = 0
	mana_bar.scale.x = 0

func _process(delta):
	# Spring physics for horizontal slide
	var displacement = position.x - spring_target
	var spring_force = -spring_stiffness * displacement
	spring_velocity += spring_force
	spring_velocity *= spring_damping
	position.x += spring_velocity

	# Stop physics when close enough
	if abs(displacement) < 0.5 and abs(spring_velocity) < 0.5:
		position.x = spring_target
		spring_velocity = 0

func show_tile_details(tile_meta: Dictionary, cursor_pos: Vector2):
	"""
	Show panel with tile metadata at cursor position.
	Expected tile_meta fields: fertility, moisture, pest, mana (values 0-100)
	"""
	# Position panel near cursor
	position = cursor_pos
	spring_target = cursor_pos.x

	# Show immediately
	visible = true

	# Animate values with rollup and bars with staggered delays
	_animate_stat(fertility_value, fertility_bar, tile_meta.get("fertility", 0), 0.0)
	_animate_stat(moisture_value, moisture_bar, tile_meta.get("moisture", 0), 0.12)
	_animate_stat(pest_value, pest_bar, tile_meta.get("pest", 0), 0.24)
	_animate_stat(mana_value, mana_bar, tile_meta.get("mana", 0), 0.36)

func _animate_stat(value_label: Label, bar_fill: Panel, target_value: float, delay: float):
	"""Animate both the number rollup and progress bar with cubic easing"""
	# Reset bar
	bar_fill.scale.x = 0
	value_label.text = "0"

	# Wait for delay, then animate
	await get_tree().create_timer(delay).timeout

	# Number rollup with cubic ease-out (900ms)
	var rollup_time = 0.0
	while rollup_time < rollup_duration:
		rollup_time += get_process_delta_time()
		var t = min(rollup_time / rollup_duration, 1.0)
		# Cubic ease-out: 1 - pow(1 - t, 3)
		var eased = 1.0 - pow(1.0 - t, 3.0)
		var current_value = eased * target_value
		value_label.text = str(int(current_value))
		await get_tree().process_frame

	value_label.text = str(int(target_value))

	# Bar animation with cubic-bezier-like easing (1.1s, overlaps with rollup)
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(bar_fill, "scale:x", target_value / 100.0, animation_duration)

func hide_panel():
	"""Slide panel off-screen and hide"""
	spring_target = position.x + 110.0
	await get_tree().create_timer(0.3).timeout
	visible = false

func _on_close_pressed():
	hide_panel()

func _input(event):
	if not visible:
		return

	# Close on ESC
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		hide_panel()
		get_viewport().set_input_as_handled()

	# Close on click outside
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var local_pos = get_local_mouse_position()
		var rect = Rect2(Vector2.ZERO, size)
		if not rect.has_point(local_pos):
			hide_panel()
			get_viewport().set_input_as_handled()
