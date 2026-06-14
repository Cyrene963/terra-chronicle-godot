extends Node2D

## Terra Chronicle — Farming System
## 耕地系统: 播种、生长、收获

signal crop_planted(tile_pos: Vector2i, crop_type: String)
signal crop_harvested(tile_pos: Vector2i, crop_type: String, fertility: float)

# 常量配置
const TILE_SIZE = 32
const GROW_SECONDS = 18.0  # DAY_SECONDS(30) * 0.6 = 18秒
const FERTILITY_DECREASE_PER_HARVEST = 12
const PLANT_STAMINA_COST = 1

# 作物视觉配置
const CROP_BASE_SCALE = 0.32
const CROP_GROWTH_SCALE = 0.72
const MATURE_TINT = Color(1.0, 0.914, 0.69)  # 0xffe9b0 泛金色

# 节点引用
@onready var tilemap: TileMap = get_parent().get_node("TileMap")
@onready var crop_container: Node2D = self

# 作物精灵实例 {Vector2i: Sprite2D}
var crop_sprites: Dictionary = {}

# 作物生长加速 (灵兽/技能加成)
var growth_boost: bool = false

func _ready():
	print("[FarmingSystem] Initialized")

	# 恢复已种植作物的视觉
	_restore_planted_crops()

	# 连接时间系统信号
	TimeSystem.day_changed.connect(_on_day_changed)

func _process(delta):
	# 更新所有作物的生长进度
	_update_crop_growth(delta)

func _restore_planted_crops():
	"""从 GameState 恢复已种植作物的视觉"""
	var planted = GameState.map.get("planted", {})

	for key in planted:
		var plot_data = planted[key]
		if plot_data.get("planted", false):
			var tile_pos = _string_to_vector2i(key)
			_spawn_crop_sprite(tile_pos, plot_data.get("crop_type", "wheat"))

func _update_crop_growth(delta):
	"""更新所有作物的生长进度和视觉"""
	var planted = GameState.map.get("planted", {})
	var time_scale = TimeSystem.time_scale
	var boost_multiplier = 1.8 if growth_boost else 1.0

	for key in planted:
		var plot_data = planted[key]
		if not plot_data.get("planted", false):
			continue

		# 累积生长时间
		var grown = plot_data.get("grown", 0.0)
		grown += delta * time_scale * boost_multiplier
		plot_data["grown"] = grown

		# 更新视觉
		var tile_pos = _string_to_vector2i(key)
		_update_crop_visual(tile_pos, grown)

func _update_crop_visual(tile_pos: Vector2i, grown: float):
	"""更新作物精灵的缩放和色调"""
	if not crop_sprites.has(tile_pos):
		return

	var sprite = crop_sprites[tile_pos]
	var growth_progress = clamp(grown / GROW_SECONDS, 0.0, 1.0)

	# 缩放: 0.32 → 1.04 (0.32 + 0.72)
	sprite.scale = Vector2.ONE * (CROP_BASE_SCALE + growth_progress * CROP_GROWTH_SCALE)

	# 成熟时显示金色色调
	if growth_progress >= 1.0:
		sprite.modulate = MATURE_TINT
	else:
		sprite.modulate = Color.WHITE

func handle_click(world_pos: Vector2):
	"""处理玩家点击耕地格子"""
	var tile_x = int(floor(world_pos.x / TILE_SIZE))
	var tile_y = int(floor(world_pos.y / TILE_SIZE))
	var tile_pos = Vector2i(tile_x, tile_y)

	# 检查是否是耕地瓦片 (tile_id == 4)
	var tile_id = tilemap.get_cell_source_id(0, tile_pos)
	if tile_id != 0:  # 不是有效瓦片
		return false

	var atlas_coords = tilemap.get_cell_atlas_coords(0, tile_pos)
	if atlas_coords.x != 4:  # 不是耕地
		return false

	# 交互耕地
	_interact_farm(tile_pos)
	return true

func _interact_farm(tile_pos: Vector2i):
	"""耕地交互逻辑: 空地播种 / 成熟收获"""
	var key = _vector2i_to_string(tile_pos)
	var planted = GameState.map.get("planted", {})

	# 检查是否已种植
	if not planted.has(key) or not planted[key].get("planted", false):
		# 空地 → 播种
		_plant_crop(tile_pos)
	else:
		# 已种植 → 检查是否成熟
		var plot_data = planted[key]
		var grown = plot_data.get("grown", 0.0)

		if grown >= GROW_SECONDS:
			# 成熟 → 收获
			_harvest_crop(tile_pos)
		else:
			# 未成熟，显示提示
			var progress_pct = int((grown / GROW_SECONDS) * 100)
			print("[FarmingSystem] Crop at ", tile_pos, " is ", progress_pct, "% grown")

func _plant_crop(tile_pos: Vector2i):
	"""播种作物"""
	# 检查体力
	if GameState.farm.stamina < PLANT_STAMINA_COST:
		print("[FarmingSystem] Not enough stamina to plant")
		return

	# 消耗体力
	GameState.farm.stamina -= PLANT_STAMINA_COST

	# 初始化耕地数据
	var key = _vector2i_to_string(tile_pos)
	var fertility = _calculate_fertility(tile_pos)

	var plot_data = {
		"planted": true,
		"crop_type": "wheat",  # 目前只有小麦 (starwheat)
		"planted_time": TimeSystem.current_day + TimeSystem.time_of_day,
		"fertility": fertility,
		"grown": 0.0
	}

	if not GameState.map.has("planted"):
		GameState.map["planted"] = {}

	GameState.map.planted[key] = plot_data

	# 生成作物精灵
	_spawn_crop_sprite(tile_pos, "wheat")

	crop_planted.emit(tile_pos, "wheat")
	print("[FarmingSystem] Planted wheat at ", tile_pos, " (fertility: ", fertility, ")")

func _harvest_crop(tile_pos: Vector2i):
	"""收获成熟作物"""
	var key = _vector2i_to_string(tile_pos)
	var planted = GameState.map.get("planted", {})

	if not planted.has(key):
		return

	var plot_data = planted[key]
	var fertility = plot_data.get("fertility", 50.0)
	var crop_type = plot_data.get("crop_type", "wheat")

	# 添加作物到仓库
	GameState.add_wheat(fertility)

	# 降低土地肥力
	var new_fertility = max(0, fertility - FERTILITY_DECREASE_PER_HARVEST)
	plot_data["fertility"] = new_fertility

	# 重置种植状态
	plot_data["planted"] = false
	plot_data["grown"] = 0.0

	# 移除作物精灵
	_remove_crop_sprite(tile_pos)

	crop_harvested.emit(tile_pos, crop_type, fertility)
	print("[FarmingSystem] Harvested ", crop_type, " at ", tile_pos,
		" (quality: ", fertility / 100.0, ", new fertility: ", new_fertility, ")")

func _spawn_crop_sprite(tile_pos: Vector2i, crop_type: String):
	"""生成作物精灵"""
	if crop_sprites.has(tile_pos):
		return  # 已存在

	var sprite = Sprite2D.new()
	sprite.texture = _load_crop_texture(crop_type)
	sprite.position = Vector2(tile_pos.x * TILE_SIZE + TILE_SIZE / 2,
							  tile_pos.y * TILE_SIZE + TILE_SIZE / 2)
	sprite.scale = Vector2.ONE * CROP_BASE_SCALE
	sprite.z_index = 1

	crop_container.add_child(sprite)
	crop_sprites[tile_pos] = sprite

func _remove_crop_sprite(tile_pos: Vector2i):
	"""移除作物精灵"""
	if not crop_sprites.has(tile_pos):
		return

	var sprite = crop_sprites[tile_pos]
	sprite.queue_free()
	crop_sprites.erase(tile_pos)

func _load_crop_texture(crop_type: String) -> Texture2D:
	"""加载作物纹理 (占位符)"""
	# TODO: 替换为实际的作物贴图路径
	# return load("res://assets/crops/wheat.png")

	# 临时: 使用白色方块占位
	var img = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.8, 0.9, 0.5))  # 淡绿色
	return ImageTexture.create_from_image(img)

func _calculate_fertility(tile_pos: Vector2i) -> float:
	"""计算耕地初始肥力 (基于位置/季节)"""
	# 简单实现: 基于位置哈希
	var hash = (tile_pos.x * 73 + tile_pos.y * 179) % 100
	var base_fertility = 50.0 + (hash - 50) * 0.4  # 30-70 范围

	# 季节加成
	var season_bonus = 0.0
	match TimeSystem.current_season:
		"spring":
			season_bonus = 10.0
		"summer":
			season_bonus = 5.0
		"autumn":
			season_bonus = 0.0
		"winter":
			season_bonus = -10.0

	return clamp(base_fertility + season_bonus, 10.0, 100.0)

func _on_day_changed(day: int):
	"""新的一天: 恢复体力"""
	GameState.farm.stamina = GameState.farm.max_stamina
	print("[FarmingSystem] New day! Stamina restored to ", GameState.farm.max_stamina)

func set_growth_boost(enabled: bool):
	"""设置生长加速 (灵兽/技能加成)"""
	growth_boost = enabled
	print("[FarmingSystem] Growth boost ", "enabled" if enabled else "disabled")

# 辅助函数: Vector2i ↔ String 转换 (用于 Dictionary key)
func _vector2i_to_string(v: Vector2i) -> String:
	return str(v.x) + "," + str(v.y)

func _string_to_vector2i(s: String) -> Vector2i:
	var parts = s.split(",")
	if parts.size() == 2:
		return Vector2i(int(parts[0]), int(parts[1]))
	return Vector2i.ZERO
