extends CanvasLayer

## Terra Chronicle — Dungeon Map UI
## Dark fantasy Slay-the-Spire style node-based dungeon map
## Matches dungeon.js from web version

signal node_selected(node_data)
signal map_closed()

const NODE_TYPES = {
	"combat": {"icon": "⚔️", "label": "战斗"},
	"elite": {"icon": "👹", "label": "精英"},
	"treasure": {"icon": "💎", "label": "宝箱"},
	"rest": {"icon": "🔥", "label": "休息"},
	"boss": {"icon": "💀", "label": "BOSS"},
}

var map_data = []  # Array of floors, each floor is array of nodes
var progress = {"floor": 0, "path": []}  # Current floor and visited nodes
var node_buttons = {}  # Dictionary mapping node_id to button reference

func _ready():
	hide()
	if has_node("CloseButton"):
		$CloseButton.pressed.connect(_on_close_button_pressed)

func open_map():
	"""Open the dungeon map, generate if needed"""
	if map_data.is_empty():
		generate_map()
		progress = {"floor": 0, "path": []}
	render_map()
	show()
	# Play fade-in animation if available
	if has_node("AnimationPlayer"):
		$AnimationPlayer.play("RESET")

func generate_map():
	"""Generate 3-floor dungeon with boss on final floor"""
	map_data = [[], [], []]
	var types = ["combat", "combat", "elite", "rest"]

	# Generate floors 0 and 1 with 3-4 nodes each
	for floor_idx in range(2):
		var node_count = 3 if randf() < 0.5 else 4
		for i in range(node_count):
			var node_type = types[randi() % types.size()]
			map_data[floor_idx].append({
				"type": node_type,
				"id": str(floor_idx) + "_" + str(i)
			})

	# Floor 2: Boss only
	map_data[2].append({"type": "boss", "id": "2_0"})

func render_map():
	"""Render the dungeon map with nodes and connecting paths"""
	var paths_layer = $MapCanvas/PathsLayer
	var nodes_layer = $MapCanvas/NodesLayer

	# Clear existing
	for child in paths_layer.get_children():
		child.queue_free()
	for child in nodes_layer.get_children():
		child.queue_free()
	node_buttons.clear()

	var canvas_width = 900.0
	var canvas_height = 600.0
	var floor_count = map_data.size()
	var floor_height = canvas_height / (floor_count + 1)

	# Render each floor
	for floor_idx in range(floor_count):
		var floor = map_data[floor_idx]
		var y = floor_height * (floor_idx + 1)
		var node_width = canvas_width / (floor.size() + 1)

		# Render nodes
		for node_idx in range(floor.size()):
			var node = floor[node_idx]
			var x = node_width * (node_idx + 1)

			# Draw paths to next floor
			if floor_idx < floor_count - 1:
				var next_floor = map_data[floor_idx + 1]
				for next_idx in range(next_floor.size()):
					var next_x = canvas_width / (next_floor.size() + 1) * (next_idx + 1)
					var next_y = floor_height * (floor_idx + 2)
					_draw_golden_path(paths_layer, Vector2(x, y), Vector2(next_x, next_y))

			# Create node button
			_create_node_button(nodes_layer, node, Vector2(x, y), floor_idx)

func _draw_golden_path(parent: Control, from: Vector2, to: Vector2):
	"""Draw golden connecting line between nodes"""
	var line = Line2D.new()
	line.add_point(from)
	line.add_point(to)
	line.width = 2
	line.default_color = Color(0.831, 0.686, 0.333, 0.4)  # Golden with transparency
	line.z_index = -1
	parent.add_child(line)

func _create_node_button(parent: Control, node_data: Dictionary, pos: Vector2, floor_idx: int):
	"""Create a node button with styling and state"""
	var node_type = node_data.type
	var node_id = node_data.id
	var type_data = NODE_TYPES.get(node_type, {"icon": "?", "label": node_type})

	# Determine node state
	var is_locked = floor_idx > progress.floor or (floor_idx == progress.floor and progress.path.has(node_id))
	var is_current = floor_idx == progress.floor and not progress.path.has(node_id)

	# Create button
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(88, 88)
	btn.position = pos - Vector2(44, 44)  # Center on position

	# Create label with icon and text
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var icon_label = Label.new()
	icon_label.text = type_data.icon
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.add_theme_font_size_override("font_size", 36)
	icon_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var text_label = Label.new()
	text_label.text = type_data.label
	text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text_label.add_theme_font_size_override("font_size", 11)
	text_label.add_theme_color_override("font_color", Color(0.909, 0.862, 0.749))
	text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	vbox.add_child(icon_label)
	vbox.add_child(text_label)
	btn.add_child(vbox)
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)

	# Apply styling based on state
	if is_locked:
		btn.disabled = true
		btn.modulate.a = 0.3
		_apply_node_style(btn, false)
	elif is_current:
		_apply_node_style(btn, true)
		_start_pulse_animation(btn)
	else:
		_apply_node_style(btn, false)

	# Connect signal
	if not is_locked:
		btn.pressed.connect(_on_node_clicked.bind(node_data))

	node_buttons[node_id] = btn
	parent.add_child(btn)

func _apply_node_style(btn: Button, is_current: bool):
	"""Apply StyleBox styling to node button"""
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color(0.957, 0.925, 0.847, 0.12)
	style_normal.border_width_left = 2 if not is_current else 3
	style_normal.border_width_top = 2 if not is_current else 3
	style_normal.border_width_right = 2 if not is_current else 3
	style_normal.border_width_bottom = 2 if not is_current else 3
	style_normal.border_color = Color(0.831, 0.686, 0.333, 1) if not is_current else Color(0.957, 0.816, 0.247, 1)
	style_normal.corner_radius_top_left = 44
	style_normal.corner_radius_top_right = 44
	style_normal.corner_radius_bottom_right = 44
	style_normal.corner_radius_bottom_left = 44
	style_normal.shadow_size = 8 if not is_current else 16
	style_normal.shadow_color = Color(0, 0, 0, 0.5) if not is_current else Color(0.957, 0.816, 0.247, 0.8)
	style_normal.shadow_offset = Vector2(0, 4) if not is_current else Vector2(0, 0)

	btn.add_theme_stylebox_override("normal", style_normal)
	btn.add_theme_stylebox_override("hover", style_normal)
	btn.add_theme_stylebox_override("pressed", style_normal)
	btn.flat = true

func _start_pulse_animation(btn: Button):
	"""Start golden pulse animation on current node"""
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(btn, "modulate", Color(1.3, 1.2, 0.8, 1), 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(btn, "modulate", Color(1, 1, 1, 1), 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _on_node_clicked(node_data: Dictionary):
	"""Handle node selection"""
	progress.path.append(node_data.id)
	node_selected.emit(node_data)

	# Check if we should advance to next floor
	if node_data.type == "combat" or node_data.type == "elite" or node_data.type == "boss":
		# Battle nodes advance floor after completion (handled by battle system)
		pass
	elif node_data.type == "rest":
		# Rest node advances immediately
		advance_floor()

func advance_floor():
	"""Advance to next floor and re-render"""
	progress.floor += 1
	if progress.floor >= map_data.size():
		# Dungeon complete
		print("Dungeon conquered!")
		close_map()
	else:
		render_map()

func close_map():
	"""Close the map and emit signal"""
	hide()
	map_closed.emit()

func _on_close_button_pressed():
	close_map()

func reset_progress():
	"""Reset dungeon progress (for new runs)"""
	map_data.clear()
	progress = {"floor": 0, "path": []}
	node_buttons.clear()
