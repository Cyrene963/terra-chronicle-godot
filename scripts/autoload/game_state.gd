extends Node

## Terra Chronicle — Global Game State
## 全局游戏状态管理 (单例 Autoload)

# 农场状态
var farm = {
	"inventory": {
		"crops": {
			"wheat": []  # [{originFertility: 50, quality: 0.8}, ...]
		},
		"materials": {
			"wood": 0
		},
		"cards": []  # [{id, name, atk, def, element, quality}, ...]
	},
	"stamina": 6,
	"max_stamina": 6,
	"gold": 0
}

# 时间状态 (由 TimeSystem 管理，这里只存储)
var time = {
	"day": 1,
	"season": "spring",  # spring/summer/autumn/winter
	"time_of_day": 0.0  # 0.0-1.0
}

# 地图状态
var map = {
	"size": Vector2i(56, 56),
	"seed": 0,
	"tiles": {},  # {Vector2i: tile_type}
	"planted": {}  # {Vector2i: {crop_type, planted_time, fertility}}
}

# 灵兽状态
var beasts = {
	"water_beast": {
		"position": Vector2.ZERO,
		"level": 1,
		"souls": 0
	},
	"fire_beast": {
		"position": Vector2.ZERO,
		"level": 1,
		"souls": 0
	}
}

# 存档路径
const SAVE_PATH = "user://terra_save.json"

func _ready():
	print("[GameState] Initialized")
	load_game()

func save_game():
	var save_data = {
		"farm": farm,
		"time": time,
		"map": map,
		"beasts": beasts,
		"version": "v10"
	}

	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data, "\t"))
		file.close()
		print("[GameState] Game saved to ", SAVE_PATH)
		return true
	else:
		push_error("[GameState] Failed to save game")
		return false

func load_game():
	if not FileAccess.file_exists(SAVE_PATH):
		print("[GameState] No save file found, starting new game")
		return false

	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		file.close()

		var json = JSON.new()
		var parse_result = json.parse(json_string)
		if parse_result == OK:
			var data = json.data
			farm = data.get("farm", farm)
			time = data.get("time", time)
			map = data.get("map", map)
			beasts = data.get("beasts", beasts)
			print("[GameState] Game loaded from ", SAVE_PATH)
			return true
		else:
			push_error("[GameState] Failed to parse save file")
			return false
	else:
		push_error("[GameState] Failed to open save file")
		return false

func add_wheat(fertility: float = 50.0):
	if not farm.inventory.crops.has("wheat"):
		farm.inventory.crops["wheat"] = []
	farm.inventory.crops["wheat"].append({
		"originFertility": fertility,
		"quality": fertility / 100.0
	})

func add_wood(amount: int = 1):
	farm.inventory.materials["wood"] += amount

func add_card(card_data: Dictionary):
	farm.inventory.cards.append(card_data)

func get_wheat_count() -> int:
	if not farm.inventory.crops.has("wheat"):
		return 0
	return farm.inventory.crops["wheat"].size()

func get_wood_count() -> int:
	return farm.inventory.materials.get("wood", 0)

func get_card_count() -> int:
	return farm.inventory.cards.size()
