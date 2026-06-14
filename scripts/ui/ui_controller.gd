extends Node
## UIController
## Manages all UI scenes and responds to game state changes
## Autoload singleton that handles scene transitions and UI updates

# UI Scene references
var title_screen: Control
var game_hud: Control
var alchemy_panel: Control
var tile_panel: Control
var season_dial: Control
var clock_display: Control
var inventory_dock: Control

# Scene paths
const TITLE_SCENE = "res://scenes/ui/title_screen.tscn"
const HUD_SCENE = "res://scenes/ui/game_hud.tscn"
const ALCHEMY_SCENE = "res://scenes/ui/alchemy_panel.tscn"
const TILE_PANEL_SCENE = "res://scenes/ui/tile_panel.tscn"

# State
var current_mode: String = "title"  # title, game, battle
var is_alchemy_open: bool = false

func _ready() -> void:
	# Connect to TimeSystem signals
	if TimeSystem:
		TimeSystem.season_changed.connect(_on_season_changed)
		TimeSystem.day_changed.connect(_on_day_changed)
		TimeSystem.tick.connect(_on_time_tick)

	# Connect to GameState signals
	if GameState:
		GameState.inventory_changed.connect(_on_inventory_changed)
		GameState.state_changed.connect(_on_game_state_changed)

	# Initialize UI
	_load_ui_scenes()
	show_title()

func _load_ui_scenes() -> void:
	"""Pre-load and cache UI scenes"""
	# Load title screen
	if ResourceLoader.exists(TITLE_SCENE):
		var title_packed = load(TITLE_SCENE)
		title_screen = title_packed.instantiate()
		add_child(title_screen)
		title_screen.visible = false
		_connect_title_signals()

	# Load game HUD
	if ResourceLoader.exists(HUD_SCENE):
		var hud_packed = load(HUD_SCENE)
		game_hud = hud_packed.instantiate()
		add_child(game_hud)
		game_hud.visible = false
		_find_hud_components()

	# Load alchemy panel
	if ResourceLoader.exists(ALCHEMY_SCENE):
		var alchemy_packed = load(ALCHEMY_SCENE)
		alchemy_panel = alchemy_packed.instantiate()
		add_child(alchemy_panel)
		alchemy_panel.visible = false
		_connect_alchemy_signals()

	# Load tile panel
	if ResourceLoader.exists(TILE_PANEL_SCENE):
		var tile_packed = load(TILE_PANEL_SCENE)
		tile_panel = tile_packed.instantiate()
		add_child(tile_panel)
		tile_panel.visible = false

func _find_hud_components() -> void:
	"""Find references to HUD sub-components"""
	if not game_hud:
		return

	season_dial = game_hud.get_node_or_null("SeasonDial")
	clock_display = game_hud.get_node_or_null("ClockDisplay")
	inventory_dock = game_hud.get_node_or_null("InventoryDock")

func _connect_title_signals() -> void:
	"""Connect title screen button signals"""
	if not title_screen:
		return

	var start_btn = title_screen.get_node_or_null("StartButton")
	if start_btn and not start_btn.pressed.is_connected(_on_start_game):
		start_btn.pressed.connect(_on_start_game)

	var continue_btn = title_screen.get_node_or_null("ContinueButton")
	if continue_btn and not continue_btn.pressed.is_connected(_on_continue_game):
		continue_btn.pressed.connect(_on_continue_game)

	var quit_btn = title_screen.get_node_or_null("QuitButton")
	if quit_btn and not quit_btn.pressed.is_connected(_on_quit_game):
		quit_btn.pressed.connect(_on_quit_game)

func _connect_alchemy_signals() -> void:
	"""Connect alchemy panel signals"""
	if not alchemy_panel:
		return

	var close_btn = alchemy_panel.get_node_or_null("CloseButton")
	if close_btn and not close_btn.pressed.is_connected(_on_close_alchemy):
		close_btn.pressed.connect(_on_close_alchemy)

	# Connect recipe selection if panel has that signal
	if alchemy_panel.has_signal("recipe_selected"):
		if not alchemy_panel.recipe_selected.is_connected(_on_recipe_selected):
			alchemy_panel.recipe_selected.connect(_on_recipe_selected)

# ============================================================================
# Scene Transition Methods
# ============================================================================

func show_title() -> void:
	"""Show title screen, hide everything else"""
	current_mode = "title"
	hide_all()
	if title_screen:
		title_screen.visible = true

func show_game_hud() -> void:
	"""Show game HUD, hide title and alchemy"""
	current_mode = "game"
	if title_screen:
		title_screen.visible = false
	if game_hud:
		game_hud.visible = true
	if alchemy_panel:
		alchemy_panel.visible = false
	is_alchemy_open = false

	# Update HUD with current game state
	_refresh_all_displays()

func show_battle_mode() -> void:
	"""Transition to battle mode UI"""
	current_mode = "battle"
	if game_hud:
		game_hud.visible = true
	if alchemy_panel:
		alchemy_panel.visible = false
	is_alchemy_open = false

	# Battle-specific UI setup could go here
	_set_hud_battle_mode(true)

func hide_all() -> void:
	"""Hide all UI elements"""
	if title_screen:
		title_screen.visible = false
	if game_hud:
		game_hud.visible = false
	if alchemy_panel:
		alchemy_panel.visible = false
	if tile_panel:
		tile_panel.visible = false

func toggle_alchemy() -> void:
	"""Toggle alchemy panel visibility"""
	if current_mode != "game":
		return

	is_alchemy_open = not is_alchemy_open
	if alchemy_panel:
		alchemy_panel.visible = is_alchemy_open
		if is_alchemy_open:
			_refresh_alchemy_panel()

func show_tile_panel(tile_data: Dictionary) -> void:
	"""Show tile info panel with tile data"""
	if not tile_panel:
		return

	tile_panel.visible = true
	if tile_panel.has_method("set_tile_data"):
		tile_panel.set_tile_data(tile_data)

func hide_tile_panel() -> void:
	"""Hide tile info panel"""
	if tile_panel:
		tile_panel.visible = false

# ============================================================================
# Signal Handlers - TimeSystem
# ============================================================================

func _on_season_changed(new_season: String) -> void:
	"""Update season dial when season changes"""
	if not season_dial or not season_dial.visible:
		return

	if season_dial.has_method("set_season"):
		season_dial.set_season(new_season)
	elif season_dial.has_method("update_season"):
		season_dial.update_season(new_season)

func _on_day_changed(day: int) -> void:
	"""Update day display when day advances"""
	if not game_hud or not game_hud.visible:
		return

	var day_label = game_hud.get_node_or_null("DayLabel")
	if day_label and day_label is Label:
		day_label.text = "Day %d" % day

func _on_time_tick(hour: int, minute: int) -> void:
	"""Update clock display on every time tick"""
	if not clock_display or not clock_display.visible:
		return

	if clock_display.has_method("set_time"):
		clock_display.set_time(hour, minute)
	elif clock_display.has_method("update_time"):
		clock_display.update_time(hour, minute)
	else:
		# Fallback: update text directly if it's a label
		if clock_display is Label:
			clock_display.text = "%02d:%02d" % [hour, minute]

# ============================================================================
# Signal Handlers - GameState
# ============================================================================

func _on_inventory_changed(item_id: String, count: int) -> void:
	"""Update inventory display when items change"""
	if not inventory_dock or not inventory_dock.visible:
		return

	if inventory_dock.has_method("update_item"):
		inventory_dock.update_item(item_id, count)
	elif inventory_dock.has_method("refresh"):
		inventory_dock.refresh()

func _on_game_state_changed(state_key: String, value: Variant) -> void:
	"""React to general game state changes"""
	match state_key:
		"energy":
			_update_energy_bar(value)
		"health":
			_update_health_bar(value)
		"experience":
			_update_exp_bar(value)
		"level":
			_update_level_display(value)

# ============================================================================
# Title Screen Button Handlers
# ============================================================================

func _on_start_game() -> void:
	"""Start new game"""
	if GameState and GameState.has_method("new_game"):
		GameState.new_game()
	show_game_hud()
	get_tree().change_scene_to_file("res://scenes/world/main_world.tscn")

func _on_continue_game() -> void:
	"""Continue from saved game"""
	if GameState and GameState.has_method("load_game"):
		GameState.load_game()
	show_game_hud()
	get_tree().change_scene_to_file("res://scenes/world/main_world.tscn")

func _on_quit_game() -> void:
	"""Quit the game"""
	get_tree().quit()

# ============================================================================
# Alchemy Panel Handlers
# ============================================================================

func _on_close_alchemy() -> void:
	"""Close alchemy panel"""
	is_alchemy_open = false
	if alchemy_panel:
		alchemy_panel.visible = false

func _on_recipe_selected(recipe_id: String) -> void:
	"""Handle recipe selection in alchemy panel"""
	if GameState and GameState.has_method("craft_recipe"):
		GameState.craft_recipe(recipe_id)

func _refresh_alchemy_panel() -> void:
	"""Refresh alchemy panel with current inventory"""
	if not alchemy_panel:
		return

	if alchemy_panel.has_method("refresh"):
		alchemy_panel.refresh()

# ============================================================================
# Display Update Helpers
# ============================================================================

func _refresh_all_displays() -> void:
	"""Refresh all HUD displays with current game state"""
	if not GameState:
		return

	# Update season and time
	if TimeSystem:
		_on_season_changed(TimeSystem.get_current_season())
		_on_day_changed(TimeSystem.get_current_day())
		var time = TimeSystem.get_current_time()
		_on_time_tick(time.hour, time.minute)

	# Update inventory
	if inventory_dock and inventory_dock.has_method("refresh"):
		inventory_dock.refresh()

	# Update stats
	_update_energy_bar(GameState.get_energy())
	_update_health_bar(GameState.get_health())
	_update_exp_bar(GameState.get_experience())
	_update_level_display(GameState.get_level())

func _update_energy_bar(value: float) -> void:
	"""Update energy bar display"""
	if not game_hud:
		return

	var energy_bar = game_hud.get_node_or_null("EnergyBar")
	if energy_bar and energy_bar is ProgressBar:
		energy_bar.value = value

func _update_health_bar(value: float) -> void:
	"""Update health bar display"""
	if not game_hud:
		return

	var health_bar = game_hud.get_node_or_null("HealthBar")
	if health_bar and health_bar is ProgressBar:
		health_bar.value = value

func _update_exp_bar(value: float) -> void:
	"""Update experience bar display"""
	if not game_hud:
		return

	var exp_bar = game_hud.get_node_or_null("ExpBar")
	if exp_bar and exp_bar is ProgressBar:
		exp_bar.value = value

func _update_level_display(level: int) -> void:
	"""Update level display"""
	if not game_hud:
		return

	var level_label = game_hud.get_node_or_null("LevelLabel")
	if level_label and level_label is Label:
		level_label.text = "Lv %d" % level

func _set_hud_battle_mode(enabled: bool) -> void:
	"""Toggle battle-specific HUD elements"""
	if not game_hud:
		return

	var battle_ui = game_hud.get_node_or_null("BattleUI")
	if battle_ui:
		battle_ui.visible = enabled

	var exploration_ui = game_hud.get_node_or_null("ExplorationUI")
	if exploration_ui:
		exploration_ui.visible = not enabled

# ============================================================================
# Input Handling
# ============================================================================

func _unhandled_input(event: InputEvent) -> void:
	"""Handle UI-related input"""
	if current_mode != "game":
		return

	# Toggle alchemy with 'A' key
	if event.is_action_pressed("ui_alchemy"):
		toggle_alchemy()
		get_viewport().set_input_as_handled()

	# Close panels with ESC
	if event.is_action_pressed("ui_cancel"):
		if is_alchemy_open:
			_on_close_alchemy()
			get_viewport().set_input_as_handled()
		elif tile_panel and tile_panel.visible:
			hide_tile_panel()
			get_viewport().set_input_as_handled()
