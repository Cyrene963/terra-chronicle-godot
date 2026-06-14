extends Node
class_name LoggingSystem

## LoggingSystem
## Tracks and logs player interactions with world objects (trees, rocks, etc.)
## Handles proximity detection, animation triggering, and resource collection

signal tree_chopped(tree_position: Vector2, wood_gained: int)
signal stamina_consumed(amount: int)
signal animation_started(tree_position: Vector2)

## Configuration
const TRIGGER_RADIUS: float = 48.0  # Pixels - distance to start chop animation
const AUTO_CHOP_DISTANCE_SQ: float = 95.0 * 95.0  # Square of pathfinding threshold
const CHOP_INTERVAL: float = 0.5  # Seconds between chop attempts in continuous mode
const SHAKE_DURATION: float = 0.4  # Duration of shake animation
const SHAKE_DECAY_RATE: float = 2.4  # How fast shake effect decays
const SHAKE_ROTATION_DEGREES: float = 5.0  # Max rotation during shake
const SHAKE_SCALE_MULTIPLIER: float = 0.05  # Scale oscillation strength

## Tree properties
const DEFAULT_TREE_HP: int = 2
const WOOD_DROP_AMOUNT: int = 2
const STAMINA_COST: int = 1

## References
var player: Node2D
var farm: Node  # Reference to farm/inventory system
var world: Node  # Reference to world.gd for tree tracking

## Internal state
var active_trees: Array[Dictionary] = []  # [{node, position, hp, felled, shake, chop_cooldown}]
var pending_action: Dictionary = {}  # {type: String, obj: Dictionary}
var chop_loop_active: bool = false
var chop_loop_timer: float = 0.0

## Felled trees queue (cleared daily)
var felled_queue: Array[Vector2] = []


func _ready() -> void:
	set_process(false)  # Enable when player and world are set


func initialize(p_player: Node2D, p_farm: Node, p_world: Node) -> void:
	"""Initialize the logging system with required references"""
	player = p_player
	farm = p_farm
	world = p_world
	set_process(true)
	print("[LoggingSystem] Initialized")


func register_tree(tree_node: Node2D, tree_position: Vector2) -> void:
	"""Register a tree for tracking"""
	var tree_data := {
		"node": tree_node,
		"position": tree_position,
		"hp": DEFAULT_TREE_HP,
		"felled": false,
		"shake": 0.0,
		"chop_cooldown": 0.0
	}
	active_trees.append(tree_data)


func unregister_tree(tree_node: Node2D) -> void:
	"""Remove a tree from tracking"""
	for i in range(active_trees.size() - 1, -1, -1):
		if active_trees[i].node == tree_node:
			active_trees.remove_at(i)
			break


func _process(delta: float) -> void:
	if not player or not is_instance_valid(player):
		return

	var player_pos := player.global_position

	# Update shake animations
	_update_shake_animations(delta)

	# Update chop loop timer
	if chop_loop_active:
		chop_loop_timer -= delta
		if chop_loop_timer <= 0.0:
			chop_loop_timer = CHOP_INTERVAL
			_execute_continuous_chop()

	# Update chop cooldowns
	for tree in active_trees:
		if tree.chop_cooldown > 0.0:
			tree.chop_cooldown -= delta

	# Check proximity to trees
	_check_tree_proximity(player_pos)


func _update_shake_animations(delta: float) -> void:
	"""Update shake effect for all trees"""
	for tree in active_trees:
		if tree.shake > 0.0:
			tree.shake -= delta * SHAKE_DECAY_RATE
			if tree.shake < 0.0:
				tree.shake = 0.0

			# Apply shake to tree node
			if tree.node and is_instance_valid(tree.node):
				var shake_val := tree.shake
				var scale_offset := sin(shake_val * 26.0) * SHAKE_SCALE_MULTIPLIER * shake_val
				tree.node.scale = Vector2(1.0 + scale_offset, 1.0 + scale_offset)

				# Reset scale when shake ends
				if tree.shake <= 0.0:
					tree.node.scale = Vector2.ONE


func _check_tree_proximity(player_pos: Vector2) -> void:
	"""Check if player is close enough to any tree to trigger chopping"""
	if chop_loop_active:
		return  # Already chopping

	var nearest_tree: Dictionary = {}
	var nearest_dist_sq := TRIGGER_RADIUS * TRIGGER_RADIUS

	for tree in active_trees:
		if tree.felled:
			continue

		var dist_sq := player_pos.distance_squared_to(tree.position)
		if dist_sq < nearest_dist_sq:
			nearest_dist_sq = dist_sq
			nearest_tree = tree

	# Auto-start chopping if close enough
	if not nearest_tree.is_empty() and pending_action.is_empty():
		start_chopping(nearest_tree)


func start_chopping(tree: Dictionary) -> void:
	"""Start the chopping sequence for a tree"""
	if tree.felled or tree.chop_cooldown > 0.0:
		return

	pending_action = {"type": "chop", "obj": tree}
	on_arrive()


func on_arrive() -> void:
	"""Called when player arrives at target (or is in range)"""
	if pending_action.is_empty():
		return

	if pending_action.type == "chop":
		var tree: Dictionary = pending_action.obj
		if tree and not tree.felled:
			chop(tree)
			# Start continuous chop loop
			chop_loop_active = true
			chop_loop_timer = CHOP_INTERVAL

	pending_action = {}


func _execute_continuous_chop() -> void:
	"""Execute chop in continuous loop mode"""
	if active_trees.is_empty():
		chop_loop_active = false
		return

	var nearest := _find_nearest_choppable_tree()
	if nearest.is_empty():
		chop_loop_active = false
		return

	chop(nearest)


func _find_nearest_choppable_tree() -> Dictionary:
	"""Find nearest tree within chop range"""
	if not player or not is_instance_valid(player):
		return {}

	var player_pos := player.global_position
	var nearest: Dictionary = {}
	var nearest_dist_sq := AUTO_CHOP_DISTANCE_SQ

	for tree in active_trees:
		if tree.felled or tree.chop_cooldown > 0.0:
			continue

		var dist_sq := player_pos.distance_squared_to(tree.position)
		if dist_sq < nearest_dist_sq:
			nearest_dist_sq = dist_sq
			nearest = tree

	return nearest


func chop(tree: Dictionary) -> void:
	"""Execute a single chop action on a tree"""
	if tree.felled:
		return

	# Check stamina
	if not _has_stamina():
		print("[LoggingSystem] Not enough stamina to chop")
		chop_loop_active = false
		return

	# Trigger shake animation
	tree.shake = 1.0
	tree.chop_cooldown = CHOP_INTERVAL
	animation_started.emit(tree.position)

	# Reduce tree HP
	tree.hp -= 1

	if tree.hp <= 0:
		# Tree is felled
		_fell_tree(tree)
	else:
		print("[LoggingSystem] Tree hit, %d HP remaining" % tree.hp)


func _has_stamina() -> bool:
	"""Check if player has enough stamina"""
	if not farm:
		return true  # No farm system, allow action

	# Check stamina in farm/player stats
	if farm.has_method("get_stamina"):
		return farm.get_stamina() >= STAMINA_COST

	return true


func _consume_stamina() -> void:
	"""Consume stamina for chopping"""
	if farm and farm.has_method("consume_stamina"):
		farm.consume_stamina(STAMINA_COST)
		stamina_consumed.emit(STAMINA_COST)


func _fell_tree(tree: Dictionary) -> void:
	"""Fell a tree and grant resources"""
	tree.felled = true
	felled_queue.append(tree.position)

	# Hide tree node
	if tree.node and is_instance_valid(tree.node):
		tree.node.visible = false

		# Remove colliders if present
		for child in tree.node.get_children():
			if child is CollisionShape2D or child is CollisionPolygon2D:
				child.queue_free()

	# Grant wood
	_grant_wood(WOOD_DROP_AMOUNT)

	# Consume stamina
	_consume_stamina()

	# Emit signal
	tree_chopped.emit(tree.position, WOOD_DROP_AMOUNT)

	print("[LoggingSystem] Tree felled at %v, +%d wood" % [tree.position, WOOD_DROP_AMOUNT])


func _grant_wood(amount: int) -> void:
	"""Add wood to player inventory"""
	if not farm:
		print("[LoggingSystem] Warning: No farm reference, wood not added")
		return

	# Try different inventory access patterns
	if farm.has_method("add_wood"):
		farm.add_wood(amount)
	elif farm.has("inventory"):
		if farm.inventory.has("materials"):
			if farm.inventory.materials.has("wood"):
				farm.inventory.materials.wood += amount
			else:
				farm.inventory.materials["wood"] = amount
	else:
		print("[LoggingSystem] Warning: Could not add wood to inventory")


func stop_chopping() -> void:
	"""Stop the continuous chop loop"""
	chop_loop_active = false
	chop_loop_timer = 0.0
	pending_action = {}


func on_new_day() -> void:
	"""Called when a new day starts - respawn trees"""
	print("[LoggingSystem] New day - respawning %d trees" % felled_queue.size())

	for tree in active_trees:
		if tree.felled:
			tree.felled = false
			tree.hp = DEFAULT_TREE_HP
			tree.shake = 0.0
			tree.chop_cooldown = 0.0

			if tree.node and is_instance_valid(tree.node):
				tree.node.visible = true
				tree.node.scale = Vector2.ONE

	felled_queue.clear()


func get_active_tree_count() -> int:
	"""Get count of non-felled trees"""
	var count := 0
	for tree in active_trees:
		if not tree.felled:
			count += 1
	return count


func get_felled_tree_count() -> int:
	"""Get count of felled trees"""
	return felled_queue.size()


func is_tree_felled_at(pos: Vector2, tolerance: float = 10.0) -> bool:
	"""Check if a tree at given position is felled"""
	for felled_pos in felled_queue:
		if pos.distance_to(felled_pos) < tolerance:
			return true
	return false
