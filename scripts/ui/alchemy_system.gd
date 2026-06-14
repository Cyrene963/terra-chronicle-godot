extends Control

# Alchemy System - Hidden Recipe Discovery
# 6 recipes require exact material combinations to unlock

# Recipe database - each entry defines wheat, wood cost and result card
const RECIPES = [
	{
		"wheat": 3,
		"wood": 1,
		"result": {
			"name": "新芽守卫",
			"atk": 8,
			"def": 18,
			"elem": "wood"
		}
	},
	{
		"wheat": 1,
		"wood": 3,
		"result": {
			"name": "巨盾",
			"atk": 6,
			"def": 28,
			"elem": "earth"
		}
	},
	{
		"wheat": 2,
		"wood": 2,
		"result": {
			"name": "平衡刃",
			"atk": 16,
			"def": 14,
			"elem": "metal"
		}
	},
	{
		"wheat": 4,
		"wood": 0,
		"result": {
			"name": "生命之粮",
			"atk": 0,
			"def": 0,
			"heal": 24,
			"elem": "light"
		}
	},
	{
		"wheat": 0,
		"wood": 4,
		"result": {
			"name": "荆棘壁",
			"atk": 12,
			"def": 22,
			"elem": "earth"
		}
	},
	{
		"wheat": 5,
		"wood": 1,
		"result": {
			"name": "收割镰",
			"atk": 22,
			"def": 8,
			"elem": "fire"
		}
	}
]

# Current materials in cauldron
var cauldron_wheat: int = 0
var cauldron_wood: int = 0

# UI references
@onready var wheat_card = $MaterialsPanel/WheatCard
@onready var wood_card = $MaterialsPanel/WoodCard
@onready var cauldron_display = $CauldronPanel/ContentsLabel
@onready var craft_button = $CauldronPanel/CraftButton
@onready var clear_button = $CauldronPanel/ClearButton
@onready var result_label = $ResultPanel/ResultLabel
@onready var inventory_display = $MaterialsPanel/InventoryLabel

func _ready():
	# Connect button signals
	wheat_card.pressed.connect(_on_wheat_clicked)
	wood_card.pressed.connect(_on_wood_clicked)
	craft_button.pressed.connect(_on_craft_clicked)
	clear_button.pressed.connect(_on_clear_clicked)

	_update_displays()

func _on_wheat_clicked():
	# Check if player has wheat in inventory
	if GameState.farm.inventory.get("wheat", 0) > 0:
		GameState.farm.inventory["wheat"] -= 1
		cauldron_wheat += 1
		_update_displays()
	else:
		_show_message("小麦不足!")

func _on_wood_clicked():
	# Check if player has wood in inventory
	if GameState.farm.inventory.get("wood", 0) > 0:
		GameState.farm.inventory["wood"] -= 1
		cauldron_wood += 1
		_update_displays()
	else:
		_show_message("木材不足!")

func _on_craft_clicked():
	if cauldron_wheat == 0 and cauldron_wood == 0:
		_show_message("坩埚是空的! 请先添加材料。")
		return

	# Try to find matching recipe
	var recipe = _find_recipe(cauldron_wheat, cauldron_wood)

	if recipe:
		_craft_success(recipe)
	else:
		_craft_fail()

func _on_clear_clicked():
	# Return materials to inventory
	if cauldron_wheat > 0:
		GameState.farm.inventory["wheat"] = GameState.farm.inventory.get("wheat", 0) + cauldron_wheat
	if cauldron_wood > 0:
		GameState.farm.inventory["wood"] = GameState.farm.inventory.get("wood", 0) + cauldron_wood

	cauldron_wheat = 0
	cauldron_wood = 0
	_update_displays()
	_show_message("材料已归还。")

func _find_recipe(wheat: int, wood: int):
	# Find exact match in recipe database
	for recipe in RECIPES:
		if recipe["wheat"] == wheat and recipe["wood"] == wood:
			return recipe
	return null

func _craft_success(recipe: Dictionary):
	# Play discovery animation
	_play_discovery_animation()

	# Create card and add to inventory
	var card_data = recipe["result"]
	_add_card_to_inventory(card_data)

	# Clear cauldron
	cauldron_wheat = 0
	cauldron_wood = 0

	_update_displays()
	_show_message("发现新配方! 获得: %s" % card_data["name"])

func _craft_fail():
	# Materials are consumed on failure
	cauldron_wheat = 0
	cauldron_wood = 0

	_update_displays()
	_show_message("配方未知! 继续试验其他比例。")

func _add_card_to_inventory(card_data: Dictionary):
	# Add card to player's card inventory
	if not GameState.has("card_inventory"):
		GameState.card_inventory = []

	GameState.card_inventory.append(card_data)

func _play_discovery_animation():
	# TODO: Implement particle effects, sound, glow animation
	# For now, simple visual feedback
	var tween = create_tween()
	tween.tween_property(result_label, "modulate:a", 1.0, 0.3)
	tween.tween_property(result_label, "scale", Vector2(1.2, 1.2), 0.2)
	tween.tween_property(result_label, "scale", Vector2(1.0, 1.0), 0.2)

func _update_displays():
	# Update cauldron contents display
	cauldron_display.text = "🌾 ×%d  🪵 ×%d" % [cauldron_wheat, cauldron_wood]

	# Update inventory display
	var wheat_count = GameState.farm.inventory.get("wheat", 0)
	var wood_count = GameState.farm.inventory.get("wood", 0)
	inventory_display.text = "库存: 小麦 %d  木材 %d" % [wheat_count, wood_count]

	# Update button states
	craft_button.disabled = (cauldron_wheat == 0 and cauldron_wood == 0)
	clear_button.disabled = (cauldron_wheat == 0 and cauldron_wood == 0)

func _show_message(msg: String):
	result_label.text = msg
	result_label.modulate.a = 1.0

	# Fade out after 3 seconds
	var tween = create_tween()
	tween.tween_interval(3.0)
	tween.tween_property(result_label, "modulate:a", 0.0, 1.0)
