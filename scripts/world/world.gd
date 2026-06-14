extends Node2D

## Terra Chronicle — World Scene
## 主场景：地图生成 + 玩家 + 相机

@onready var tilemap = $TileMap
@onready var player = $YSort/Player
@onready var camera = $Camera2D
@onready var map_generator = $MapGenerator

func _ready():
	print("[World] Initializing...")

	# 生成地图
	var map_data = map_generator.generate_map()

	# 应用瓦片到 TileMap
	_apply_tiles(map_data)

	# 设置玩家碰撞数据
	_setup_player_collision(map_data)

	# 相机跟随玩家
	camera.target = player

	# 应用四季色调
	apply_season_tint()

	print("[World] Ready! Map size: ", map_data.width, "x", map_data.height)

func _apply_tiles(map_data):
	"""应用瓦片数据到 TileMap"""
	var tiles = map_data.tiles

	for pos in tiles:
		var tile_id = tiles[pos]
		tilemap.set_cell(0, Vector2i(pos.x, pos.y), 0, Vector2i(tile_id, 0))

	print("[World] Applied ", tiles.size(), " tiles")

func _setup_player_collision(map_data):
	"""设置玩家碰撞检测"""
	var blocked_tiles = {}

	# 水域和障碍物为阻挡瓦片
	for pos in map_data.tiles:
		var tile_id = map_data.tiles[pos]
		if tile_id == 2 or tile_id >= 5:  # water (2) or diagonal water (5-8)
			blocked_tiles[pos] = true

	player.set_blocked_tiles(blocked_tiles)

	# TODO: 设置树木/岩石等圆形碰撞器
	# var collision_objects = []
	# for structure in map_data.structures:
	#     if structure.type in ["tree", "rock", "house"]:
	#         collision_objects.append({pos: structure.pos, radius: structure.radius})
	# player.set_collision_objects(collision_objects)

func apply_season_tint():
	"""应用当前季节的色调"""
	var modulate_node = CanvasModulate.new()
	modulate_node.color = TimeSystem.get_season_tint()
	add_child(modulate_node)

	# 监听季节变化
	TimeSystem.season_changed.connect(_on_season_changed)

func _on_season_changed(season: String):
	"""季节变化时更新色调"""
	var modulate_node = get_node_or_null("CanvasModulate")
	if modulate_node:
		var tween = create_tween()
		tween.tween_property(modulate_node, "color", TimeSystem.get_season_tint(), 2.0)

	print("[World] Season changed to ", season)
