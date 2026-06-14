extends CanvasLayer

## Terra Chronicle — Dungeon Map UI
## Dark fantasy node-based dungeon progression

signal node_selected(node_id)

const NODE_TYPES = {
	"combat": {"icon": "⚔️", "label": "战斗", "color": Color(0.8, 0.2, 0.2)},
	"elite": {"icon": "👹", "label": "精英", "color": Color(0.6, 0.1, 0.5)},
	"treasure": {"icon": "💎", "label": "宝箱", "color": Color(0.2, 0.6, 0.8)},
	"rest": {"icon": "🛏️", "label": "休息", "color": Color(0.3, 0.7, 0.3)},
	"boss": {"icon": "👑", "label": "首领", "color": Color(0.9, 0.7, 0.2)},
}

var current_floor = 0
var map_nodes = []

func _ready():
	$CloseButton.pressed.connect(_on_close)
	generate_map()

func generate_map():
	# Simple linear path: Combat → Combat → Elite → Rest → Combat → Boss
	var path = ["combat", "combat", "elite", "rest", "combat", "boss"]

	var nodes_container = $MapCanvas/Nodes
	var lines_container = $MapCanvas/Lines

	for i in range(path.size()):
		var node_type = path[i]
		var node_data = NODE_TYPES[node_type]

		# Create node button
		var node = Button.new()
		node.custom_minimum_size = Vector2(88, 88)
		node.text = node_data.icon + "\n" + node_data.label

		# Position vertically with spacing
		var x = 400
		var y = 60 + i * 90
		node.position = Vector2(x, y)

		# Styling
		var style_normal = StyleBoxFlat.new()
		style_normal.bg_color = Color(0.957, 0.925, 0.847, 0.12)
		style_normal.border_color = Color(0.831, 0.686, 0.216, 1)
		style_normal.border_width_all = 2
		style_normal.corner_radius_all = 44
		style_normal.shadow_size = 8
		style_normal.shadow_color = Color(0, 0, 0, 0.5)
		node.add_theme_stylebox_override("normal", style_normal)

		var style_hover = style_normal.duplicate()
		style_hover.border_width_all = 3
		style_hover.shadow_size = 12
		node.add_theme_stylebox_override("hover", style_hover)

		# Node state
		if i == current_floor:
			# Current node - pulsing animation
			var tween = create_tween()
			tween.set_loops()
			tween.tween_property(node, "scale", Vector2(1.15, 1.15), 1.0)
			tween.tween_property(node, "scale", Vector2(1.0, 1.0), 1.0)
		elif i < current_floor:
			node.modulate.a = 0.5  # Completed
		elif i > current_floor:
			node.disabled = true
			node.modulate = Color(0.5, 0.5, 0.5, 0.3)  # Locked

		node.pressed.connect(_on_node_clicked.bind(i))
		nodes_container.add_child(node)
		map_nodes.append(node)

		# Draw connecting line to next node
		if i < path.size() - 1:
			var line = Line2D.new()
			line.add_point(Vector2(x + 44, y + 88))
			line.add_point(Vector2(x + 44, y + 90 + 0))
			line.width = 4
			line.default_color = Color(0.831, 0.686, 0.216, 0.4)
			line.z_index = -1
			lines_container.add_child(line)

func _on_node_clicked(node_id):
	if node_id == current_floor:
		node_selected.emit(node_id)
		current_floor += 1
		# Refresh map state
		generate_map()

func _on_close():
	hide()

func show_map():
	show()
