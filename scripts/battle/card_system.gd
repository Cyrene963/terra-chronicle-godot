extends Node
class_name CardSystem

# Signals
signal card_played(card: Card, target)
signal card_drawn(card: Card)
signal energy_changed(current: int, max: int)
signal hand_updated()
signal deck_shuffled()

# Card data structure
class Card:
	var id: String
	var name: String
	var type: String  # "attack", "defend", "heal"
	var cost: int
	var value: int
	var description: String
	var texture: Texture2D

	func _init(p_id: String = "", p_name: String = "", p_type: String = "attack",
			   p_cost: int = 1, p_value: int = 1, p_description: String = ""):
		id = p_id
		name = p_name
		type = p_type
		cost = p_cost
		value = p_value
		description = p_description

# Energy system
var max_energy: int = 3
var current_energy: int = 3

# Card collections
var deck: Array[Card] = []
var hand: Array[Card] = []
var discard_pile: Array[Card] = []
var exhausted_pile: Array[Card] = []

# Configuration
var max_hand_size: int = 10
var cards_per_draw: int = 5

# State
var is_dragging: bool = false
var dragged_card: Card = null
var dragged_card_index: int = -1

func _ready():
	randomize()

# Energy management
func set_max_energy(value: int) -> void:
	max_energy = value
	current_energy = min(current_energy, max_energy)
	energy_changed.emit(current_energy, max_energy)

func refill_energy() -> void:
	current_energy = max_energy
	energy_changed.emit(current_energy, max_energy)

func spend_energy(amount: int) -> bool:
	if current_energy >= amount:
		current_energy -= amount
		energy_changed.emit(current_energy, max_energy)
		return true
	return false

func gain_energy(amount: int) -> void:
	current_energy = min(current_energy + amount, max_energy)
	energy_changed.emit(current_energy, max_energy)

func has_energy(amount: int) -> bool:
	return current_energy >= amount

# Deck management
func add_card_to_deck(card: Card) -> void:
	deck.append(card)

func create_card(card_id: String, card_name: String, card_type: String,
				 cost: int, value: int, desc: String = "") -> Card:
	var card = Card.new(card_id, card_name, card_type, cost, value, desc)
	return card

func shuffle_deck() -> void:
	deck.shuffle()
	deck_shuffled.emit()

func draw_card() -> Card:
	if deck.is_empty():
		if discard_pile.is_empty():
			return null
		# Reshuffle discard into deck
		deck = discard_pile.duplicate()
		discard_pile.clear()
		shuffle_deck()

	if deck.is_empty():
		return null

	var card = deck.pop_front()
	if hand.size() < max_hand_size:
		hand.append(card)
		card_drawn.emit(card)
		hand_updated.emit()
	else:
		# Hand full, send to discard
		discard_pile.append(card)

	return card

func draw_cards(count: int) -> Array[Card]:
	var drawn: Array[Card] = []
	for i in range(count):
		var card = draw_card()
		if card:
			drawn.append(card)
		else:
			break
	return drawn

func discard_card(card: Card) -> void:
	var index = hand.find(card)
	if index != -1:
		hand.remove_at(index)
		discard_pile.append(card)
		hand_updated.emit()

func discard_hand() -> void:
	discard_pile.append_array(hand)
	hand.clear()
	hand_updated.emit()

func exhaust_card(card: Card) -> void:
	var index = hand.find(card)
	if index != -1:
		hand.remove_at(index)
		exhausted_pile.append(card)
		hand_updated.emit()

# Card playing
func can_play_card(card: Card) -> bool:
	return card in hand and has_energy(card.cost)

func play_card(card: Card, target = null) -> bool:
	if not can_play_card(card):
		return false

	if not spend_energy(card.cost):
		return false

	# Apply card effect
	apply_card_effect(card, target)

	# Remove from hand
	var index = hand.find(card)
	if index != -1:
		hand.remove_at(index)

	# Move to discard
	discard_pile.append(card)

	card_played.emit(card, target)
	hand_updated.emit()

	return true

func apply_card_effect(card: Card, target) -> void:
	match card.type:
		"attack":
			if target and target.has_method("take_damage"):
				target.take_damage(card.value)
		"defend":
			if target and target.has_method("gain_block"):
				target.gain_block(card.value)
		"heal":
			if target and target.has_method("heal"):
				target.heal(card.value)

# Dragging system
func start_drag(card: Card) -> bool:
	if not can_play_card(card):
		return false

	var index = hand.find(card)
	if index == -1:
		return false

	is_dragging = true
	dragged_card = card
	dragged_card_index = index
	return true

func cancel_drag() -> void:
	is_dragging = false
	dragged_card = null
	dragged_card_index = -1

func complete_drag(target = null) -> bool:
	if not is_dragging or not dragged_card:
		return false

	var success = play_card(dragged_card, target)
	cancel_drag()
	return success

func get_dragged_card() -> Card:
	return dragged_card

func is_card_being_dragged() -> bool:
	return is_dragging

# Turn management
func start_turn() -> void:
	refill_energy()
	draw_cards(cards_per_draw)

func end_turn() -> void:
	discard_hand()

# Reset/cleanup
func reset_battle() -> void:
	current_energy = max_energy
	hand.clear()
	discard_pile.clear()
	exhausted_pile.clear()
	deck.clear()
	cancel_drag()
	hand_updated.emit()
	energy_changed.emit(current_energy, max_energy)

func reset_to_full_deck() -> void:
	deck.append_array(hand)
	deck.append_array(discard_pile)
	deck.append_array(exhausted_pile)
	hand.clear()
	discard_pile.clear()
	exhausted_pile.clear()
	shuffle_deck()
	hand_updated.emit()

# Utility
func get_hand_size() -> int:
	return hand.size()

func get_deck_size() -> int:
	return deck.size()

func get_discard_size() -> int:
	return discard_pile.size()

func get_card_in_hand(index: int) -> Card:
	if index >= 0 and index < hand.size():
		return hand[index]
	return null

func get_all_cards_count() -> int:
	return deck.size() + hand.size() + discard_pile.size() + exhausted_pile.size()

# Sample cards initialization
func initialize_starter_deck() -> void:
	# Attack cards
	for i in range(5):
		var card = create_card(
			"strike_%d" % i,
			"Strike",
			"attack",
			1,
			6,
			"Deal 6 damage"
		)
		add_card_to_deck(card)

	# Defend cards
	for i in range(4):
		var card = create_card(
			"defend_%d" % i,
			"Defend",
			"defend",
			1,
			5,
			"Gain 5 block"
		)
		add_card_to_deck(card)

	# Heal cards
	for i in range(2):
		var card = create_card(
			"heal_%d" % i,
			"Heal",
			"heal",
			2,
			8,
			"Restore 8 HP"
		)
		add_card_to_deck(card)

	shuffle_deck()
