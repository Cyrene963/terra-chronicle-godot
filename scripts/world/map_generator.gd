extends Node
class_name MapGenerator

## Map Generator for Terra Chronicle
## Generates a 56x56 tile map with river, trees, structures, and plots

const MAP_SIZE = 56
const TILE_SIZE = 64
const WORLD_SIZE = 3584  # 56 * 64

# Tile types
enum TileType {
	GRASS,      # 'g'
	WATER,      # 'w'
	SAND,       # 'b' (bridge)
	DIRT,       # 'd'
	PLOT,       # 'p' (farmland)
	ROAD        # 'r'
}

# Structure types
enum StructureType {
	NONE,
	TREE_OAK,
	TREE_CHERRY,
	HOUSE,
	WINDMILL,
	PORTAL,
	INCUBATOR,
	FURNACE,
	ROCK,
	BUSH,
	FENCE
}

# Map data structure
var tilemap: Array = []  # 2D array of TileType
var structures: Array = []  # Array of {type, x, y}
var plots: Array = []  # Array of plot metadata

# Noise generator for procedural generation
var noise: FastNoiseLite

func _init():
	noise = FastNoiseLite.new()
	noise.seed = randi()
	noise.frequency = 0.05

## Generate the complete map
func generate_map() -> Dictionary:
	_initialize_tilemap()
	_generate_river()
	_place_bridges()
	_place_fixed_structures()
	_place_plots()
	_place_fences()
	_place_trees()
	_place_decorations()

	return {
		"tilemap": tilemap,
		"structures": structures,
		"plots": plots,
		"size": MAP_SIZE,
		"tile_size": TILE_SIZE
	}

## Initialize tilemap with grass
func _initialize_tilemap():
	tilemap.clear()
	structures.clear()
	plots.clear()

	for y in range(MAP_SIZE):
		var row = []
		for x in range(MAP_SIZE):
			row.append(TileType.GRASS)
		tilemap.append(row)

## Generate sinusoidal river: x = 34 + sin(y*0.18)*5.5
func _generate_river():
	for y in range(MAP_SIZE):
		var center_x = 34.0 + sin(y * 0.18) * 5.5
		var river_width = 1.6

		# Mark river tiles
		for x in range(MAP_SIZE):
			var distance = abs(x - center_x)
			if distance <= river_width:
				tilemap[y][x] = TileType.WATER

## Place bridge crossings at y≈26 and y≈44
func _place_bridges():
	var bridge_ys = [26, 44]

	for bridge_y in bridge_ys:
		if bridge_y >= 0 and bridge_y < MAP_SIZE:
			var center_x = 34.0 + sin(bridge_y * 0.18) * 5.5
			var bridge_x = int(round(center_x))

			# Place sand tiles for bridge (width of ~4 tiles)
			for dx in range(-2, 3):
				var x = bridge_x + dx
				if x >= 0 and x < MAP_SIZE:
					tilemap[bridge_y][x] = TileType.SAND

## Place fixed structures
func _place_fixed_structures():
	var fixed_structures = [
		{type = StructureType.HOUSE, x = 20, y = 24},
		{type = StructureType.WINDMILL, x = 16, y = 20},
		{type = StructureType.PORTAL, x = 47, y = 10},
		{type = StructureType.INCUBATOR, x = 17, y = 31},
		{type = StructureType.FURNACE, x = 25, y = 22}
	]

	for structure in fixed_structures:
		structures.append(structure)

## Create plot regions with metadata
func _place_plots():
	# Plot region 1: [22,28,8,5] - x:22-29, y:28-32
	_create_plot_region(22, 28, 8, 5)

	# Plot region 2: [14,36,7,4] - x:14-20, y:36-39
	_create_plot_region(14, 36, 7, 4)

func _create_plot_region(start_x: int, start_y: int, width: int, height: int):
	for dy in range(height):
		for dx in range(width):
			var x = start_x + dx
			var y = start_y + dy

			if x >= 0 and x < MAP_SIZE and y >= 0 and y < MAP_SIZE:
				# Check not overlapping with water
				if tilemap[y][x] != TileType.WATER:
					tilemap[y][x] = TileType.PLOT

					# Generate metadata for this plot tile
					var plot_data = {
						"x": x,
						"y": y,
						"fertility": randf_range(0.5, 1.0),
						"moisture": randf_range(0.3, 0.9),
						"pest": randf_range(0.0, 0.3),
						"mana": randf_range(0.1, 0.8)
					}
					plots.append(plot_data)

## Place fences around plots
func _place_fences():
	# Fence coordinates from spec: x:21-30, y:27.4/33.4
	# Top fence at y≈27
	for x in range(21, 31):
		if x >= 0 and x < MAP_SIZE:
			structures.append({type = StructureType.FENCE, x = x, y = 27})

	# Bottom fence at y≈33
	for x in range(21, 31):
		if x >= 0 and x < MAP_SIZE:
			structures.append({type = StructureType.FENCE, x = x, y = 33})

## Place trees with various rules
func _place_trees():
	for y in range(MAP_SIZE):
		for x in range(MAP_SIZE):
			# Skip if tile is blocked
			if _is_blocked(x, y):
				continue

			var hash_val = _hash_position(x, y)
			var edge = min(x, y, MAP_SIZE - 1 - x, MAP_SIZE - 1 - y)

			# Dense border forest (outer 3-tile margin)
			if edge < 3:
				if hash_val < 0.62:
					structures.append({type = StructureType.TREE_OAK, x = x, y = y})
					continue

			# Cherry orchard grid (42-50x, 36-44y, 3-tile spacing)
			if x >= 42 and x <= 50 and y >= 36 and y <= 44:
				if (x - 42) % 3 == 0 and (y - 36) % 3 == 0:
					structures.append({type = StructureType.TREE_CHERRY, x = x, y = y})
					continue

			# Interior cherry trees (east of river, y:32-48)
			if _is_east_of_river(x, y) and y >= 32 and y <= 48:
				if hash_val > 0.948:
					structures.append({type = StructureType.TREE_CHERRY, x = x, y = y})
					continue

			# Interior scattered oak trees
			if hash_val > 0.965:
				structures.append({type = StructureType.TREE_OAK, x = x, y = y})

## Place rocks and bushes
func _place_decorations():
	for y in range(MAP_SIZE):
		for x in range(MAP_SIZE):
			# Skip if tile is blocked or has structure
			if _is_blocked(x, y) or _has_structure(x, y):
				continue

			var hash_val = _hash_position(x, y)

			# Rocks
			if hash_val > 0.938 and hash_val <= 0.948:
				structures.append({type = StructureType.ROCK, x = x, y = y})
			# Bushes
			elif hash_val > 0.92 and hash_val <= 0.938:
				structures.append({type = StructureType.BUSH, x = x, y = y})

## Check if tile is blocked (water, plot, road)
func _is_blocked(x: int, y: int) -> bool:
	if x < 0 or x >= MAP_SIZE or y < 0 or y >= MAP_SIZE:
		return true

	var tile = tilemap[y][x]
	return tile == TileType.WATER or tile == TileType.PLOT or tile == TileType.ROAD

## Check if position is east of river
func _is_east_of_river(x: int, y: int) -> bool:
	var river_center_x = 34.0 + sin(y * 0.18) * 5.5
	return x > river_center_x

## Check if structure already exists at position
func _has_structure(x: int, y: int) -> bool:
	for structure in structures:
		if structure.x == x and structure.y == y:
			return true
	return false

## Hash function for deterministic pseudo-random placement
func _hash_position(x: int, y: int) -> float:
	# Simple hash based on position
	var seed_val = x * 73856093 + y * 19349663
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_val
	return rng.randf()

## Get tile type at position
func get_tile(x: int, y: int) -> int:
	if x < 0 or x >= MAP_SIZE or y < 0 or y >= MAP_SIZE:
		return TileType.GRASS
	return tilemap[y][x]

## Get structures at position
func get_structures_at(x: int, y: int) -> Array:
	var result = []
	for structure in structures:
		if structure.x == x and structure.y == y:
			result.append(structure)
	return result

## Get plot data at position
func get_plot_at(x: int, y: int) -> Dictionary:
	for plot in plots:
		if plot.x == x and plot.y == y:
			return plot
	return {}

## Convert tile type to character (for debugging)
func tile_to_char(tile_type: int) -> String:
	match tile_type:
		TileType.GRASS: return "g"
		TileType.WATER: return "w"
		TileType.SAND: return "b"
		TileType.DIRT: return "d"
		TileType.PLOT: return "p"
		TileType.ROAD: return "r"
		_: return "?"

## Export map as text (for debugging)
func export_map_text() -> String:
	var text = ""
	for y in range(MAP_SIZE):
		for x in range(MAP_SIZE):
			text += tile_to_char(tilemap[y][x])
		text += "\n"
	return text
