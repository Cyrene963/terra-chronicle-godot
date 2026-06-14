extends Panel

# Alchemy Panel - Warm parchment journal style
# Manages material selection, cauldron state, and crafting

signal crafting_started(materials: Dictionary)
signal panel_closed

# Material tracking
var cauldron_materials := {
	"wheat": 0,
	"wood": 0
}

# Node references
@onready var wheat_button: Button = $MarginContainer/VBoxContainer/IngredientsContainer/WheatButton
@onready var wood_button: Button = $MarginContainer/VBoxContainer/IngredientsContainer/WoodButton
@onready var wheat_counter: Label = $MarginContainer/VBoxContainer/CauldronContainer/CauldronPanel/MaterialsVBox/WheatCount
@onready var wood_counter: Label = $MarginContainer/VBoxContainer/CauldronContainer/CauldronPanel/MaterialsVBox/WoodCount
@onready var clear_button: Button = $MarginContainer/VBoxContainer/ActionButtons/ClearButton
@onready var craft_button: Button = $MarginContainer/VBoxContainer/ActionButtons/CraftButton
@onready var close_button: Button = $CloseButton

func _ready() -> void:
	# Connect button signals
	wheat_button.pressed.connect(_on_wheat_pressed)
	wood_button.pressed.connect(_on_wood_pressed)
	clear_button.pressed.connect(_on_clear_pressed)
	craft_button.pressed.connect(_on_craft_pressed)
	close_button.pressed.connect(_on_close_pressed)

	# Initialize display
	_update_counters()
	_update_craft_button()

func _on_wheat_pressed() -> void:
	cauldron_materials["wheat"] += 1
	_update_counters()
	_update_craft_button()

func _on_wood_pressed() -> void:
	cauldron_materials["wood"] += 1
	_update_counters()
	_update_craft_button()

func _on_clear_pressed() -> void:
	cauldron_materials["wheat"] = 0
	cauldron_materials["wood"] = 0
	_update_counters()
	_update_craft_button()

func _on_craft_pressed() -> void:
	if _has_materials():
		crafting_started.emit(cauldron_materials.duplicate())
		_on_clear_pressed()

func _on_close_pressed() -> void:
	panel_closed.emit()
	hide()

func _update_counters() -> void:
	wheat_counter.text = "🌾 × %d" % cauldron_materials["wheat"]
	wood_counter.text = "🪵 × %d" % cauldron_materials["wood"]

func _update_craft_button() -> void:
	craft_button.disabled = not _has_materials()

func _has_materials() -> bool:
	return cauldron_materials["wheat"] > 0 or cauldron_materials["wood"] > 0

func show_panel() -> void:
	show()
	_on_clear_pressed()
