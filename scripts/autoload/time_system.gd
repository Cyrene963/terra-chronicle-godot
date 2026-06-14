extends Node

## Terra Chronicle — Time System
## 四季昼夜循环系统 (30秒一天, 7天一季)

signal day_changed(day: int)
signal season_changed(season: String)
signal time_of_day_changed(time: float)

# 时间参数
const DAY_DURATION = 30.0  # 30秒一昼夜
const DAYS_PER_SEASON = 7  # 7天一季

var time_of_day: float = 0.0  # 0.0-1.0
var current_day: int = 1
var current_season: String = "spring"
var time_scale: float = 1.0  # 时间流速 (F键加速)

# 四季顺序
const SEASONS = ["spring", "summer", "autumn", "winter"]
const SEASON_NAMES_CN = {
	"spring": "春",
	"summer": "夏",
	"autumn": "秋",
	"winter": "冬"
}
const SEASON_NAMES_LATIN = {
	"spring": "VER",
	"summer": "AEST",
	"autumn": "AUT",
	"winter": "HIE"
}

# 四季色调 (CanvasModulate)
const SEASON_TINTS = {
	"spring": Color(1.0, 1.0, 1.0),
	"summer": Color(1.1, 1.05, 0.95),
	"autumn": Color(1.15, 0.95, 0.85),
	"winter": Color(0.9, 0.95, 1.1)
}

var is_paused: bool = false

func _ready():
	print("[TimeSystem] Initialized")
	# 从 GameState 读取时间
	if GameState.time.has("day"):
		current_day = GameState.time["day"]
	if GameState.time.has("season"):
		current_season = GameState.time["season"]
	if GameState.time.has("time_of_day"):
		time_of_day = GameState.time["time_of_day"]

func _process(delta):
	if is_paused:
		return

	# 时间流逝
	time_of_day += delta * time_scale / DAY_DURATION

	if time_of_day >= 1.0:
		time_of_day -= 1.0
		advance_day()

	# 同步到 GameState
	GameState.time["time_of_day"] = time_of_day
	time_of_day_changed.emit(time_of_day)

func advance_day():
	current_day += 1
	GameState.time["day"] = current_day
	day_changed.emit(current_day)
	print("[TimeSystem] Day ", current_day)

	# 检查是否换季
	if current_day > DAYS_PER_SEASON:
		current_day = 1
		advance_season()

func advance_season():
	var idx = SEASONS.find(current_season)
	idx = (idx + 1) % SEASONS.size()
	current_season = SEASONS[idx]
	GameState.time["season"] = current_season
	season_changed.emit(current_season)
	print("[TimeSystem] Season changed to ", current_season)

func get_season_tint() -> Color:
	return SEASON_TINTS.get(current_season, Color.WHITE)

func get_season_name_cn() -> String:
	return SEASON_NAMES_CN.get(current_season, "春")

func get_season_name_latin() -> String:
	return SEASON_NAMES_LATIN.get(current_season, "VER")

func set_time_scale(scale: float):
	time_scale = scale
	print("[TimeSystem] Time scale set to ", scale)

func pause():
	is_paused = true

func resume():
	is_paused = false
