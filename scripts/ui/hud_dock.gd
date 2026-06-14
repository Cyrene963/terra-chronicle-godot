extends Control
## HUD Dock - Bottom inventory display and alchemy button
## Matches original web implementation from index.html lines 1281-1294

## References to UI elements
@onready var wheat_count: Label = %WheatCount
@onready var wood_count: Label = %WoodCount
@onready var cards_count: Label = %CardsCount
@onready var alchemy_button: Button = %AlchemyButton

## Visual state flags
var forge_hot: bool = false

## References to game systems
var game_state: Node = null
var alchemy_panel: Node = null

func _ready() -> void:
	# Connect to GameState singleton
	game_state = get_node_or_null("/root/GameState")
	if game_state == null:
		push_warning("HUDDock: GameState not found")
		return

	# Connect inventory change signals
	if game_state.has_signal("inventory_changed"):
		game_state.inventory_changed.connect(_on_inventory_changed)

	# Find alchemy panel reference (will be set when panel is instanced)
	call_deferred("_find_alchemy_panel")

	# Initial update
	update_dock()

func _find_alchemy_panel() -> void:
	# Search for AlchemyPanel in the scene tree
	alchemy_panel = get_tree().root.find_child("AlchemyPanel", true, false)
	if alchemy_panel == null:
		push_warning("HUDDock: AlchemyPanel not found - alchemy button will not function")

## Updates all dock displays - called after inventory changes
## Corresponds to updateDock() in index.html line 1281
func update_dock() -> void:
	if game_state == null:
		return

	# Get inventory counts
	var wheat: int = _get_wheat_count()
	var wood: int = _get_wood_count()
	var cards: int = _get_cards_count()

	# Update counter displays (lines 1283-1285)
	wheat_count.text = str(wheat)
	wood_count.text = str(wood)
	cards_count.text = str(cards)

	# Update alchemy button state (line 1286)
	var can_craft: bool = wheat >= 3 and wood >= 2
	alchemy_button.disabled = not can_craft

	# Update button text based on forge heat state (line 1287)
	if forge_hot:
		alchemy_button.text = "锻造 · 熔炉灼热 🔥"
	else:
		alchemy_button.text = "炼金 · 炼制卡牌"

## Get wheat count from farm inventory
## Source: (farm.inventory.crops.starwheat || []).length
func _get_wheat_count() -> int:
	if game_state.farm == null or game_state.farm.inventory == null:
		return 0

	var crops = game_state.farm.inventory.get("crops", {})
	var starwheat = crops.get("starwheat", [])

	if starwheat is Array:
		return starwheat.size()
	return 0

## Get wood count from farm inventory
## Source: farm.inventory.materials.wood || 0
func _get_wood_count() -> int:
	if game_state.farm == null or game_state.farm.inventory == null:
		return 0

	var materials = game_state.farm.inventory.get("materials", {})
	return materials.get("wood", 0)

## Get cards count from farm inventory
## Source: farm.inventory.cards.length
func _get_cards_count() -> int:
	if game_state.farm == null or game_state.farm.inventory == null:
		return 0

	var cards = game_state.farm.inventory.get("cards", [])

	if cards is Array:
		return cards.size()
	return 0

## Sets the forge hot state (affects button appearance)
## Called by fire spirit system when forge is active
func set_forge_hot(hot: bool) -> void:
	forge_hot = hot
	update_dock()

## Signal handler for inventory changes
func _on_inventory_changed() -> void:
	update_dock()

## Button click handler - opens alchemy panel
## Corresponds to lines 1289-1291 in index.html
func _on_alchemy_button_pressed() -> void:
	if alchemy_panel != null and alchemy_panel.has_method("open"):
		alchemy_panel.open()
	else:
		push_warning("HUDDock: Cannot open alchemy panel - panel not found or missing open() method")

## Public API for external systems to trigger updates
## Called from various game events (battle victory, harvesting, etc.)
func refresh() -> void:
	update_dock()
