extends Node
class_name EnemyAI

## Enemy AI system with intent display and action patterns
## Handles turn execution, attack patterns, and strategic decisions

signal intent_changed(enemy_id: String, intent_type: String, intent_value: int)
signal action_executed(enemy_id: String, action_data: Dictionary)

enum IntentType {
	ATTACK,      # Basic attack intent
	DEFEND,      # Defensive stance
	BUFF,        # Self-buff
	DEBUFF,      # Enemy debuff
	SPECIAL,     # Special ability
	UNKNOWN      # Hidden intent
}

enum ActionPattern {
	AGGRESSIVE,  # 80% attack, 10% defend, 10% buff
	BALANCED,    # 70% attack, 20% defend, 10% buff (default)
	DEFENSIVE,   # 50% attack, 30% defend, 20% buff
	TACTICAL     # 60% attack, 15% defend, 15% buff, 10% debuff
}

# Enemy data structure
class EnemyData:
	var id: String
	var current_hp: int
	var max_hp: int
	var attack: int
	var defense: int
	var speed: int
	var level: int
	var pattern: ActionPattern = ActionPattern.BALANCED
	var current_intent: IntentType = IntentType.UNKNOWN
	var intent_value: int = 0
	var status_effects: Array[Dictionary] = []
	var turn_count: int = 0

	func _init(_id: String, _max_hp: int, _attack: int, _defense: int, _speed: int, _level: int = 1):
		id = _id
		max_hp = _max_hp
		current_hp = _max_hp
		attack = _attack
		defense = _defense
		speed = _speed
		level = _level

# Active enemies in battle
var enemies: Dictionary = {}  # enemy_id -> EnemyData

# Action weights for each pattern
const PATTERN_WEIGHTS = {
	ActionPattern.AGGRESSIVE: {
		IntentType.ATTACK: 80,
		IntentType.DEFEND: 10,
		IntentType.BUFF: 10
	},
	ActionPattern.BALANCED: {
		IntentType.ATTACK: 70,
		IntentType.DEFEND: 20,
		IntentType.BUFF: 10
	},
	ActionPattern.DEFENSIVE: {
		IntentType.ATTACK: 50,
		IntentType.DEFEND: 30,
		IntentType.BUFF: 20
	},
	ActionPattern.TACTICAL: {
		IntentType.ATTACK: 60,
		IntentType.DEFEND: 15,
		IntentType.BUFF: 15,
		IntentType.DEBUFF: 10
	}
}

# Attack skill database
var attack_skills: Array[Dictionary] = [
	{"name": "斩击", "damage_multiplier": 1.0, "cost": 0},
	{"name": "重击", "damage_multiplier": 1.5, "cost": 0},
	{"name": "连击", "damage_multiplier": 0.7, "hits": 2, "cost": 0},
]

# Buff/debuff database
var buff_skills: Array[Dictionary] = [
	{"name": "攻击强化", "stat": "attack", "multiplier": 1.3, "duration": 2},
	{"name": "防御强化", "stat": "defense", "multiplier": 1.5, "duration": 2},
	{"name": "速度提升", "stat": "speed", "multiplier": 1.2, "duration": 3},
]

var debuff_skills: Array[Dictionary] = [
	{"name": "攻击削弱", "stat": "attack", "multiplier": 0.7, "duration": 2},
	{"name": "防御削弱", "stat": "defense", "multiplier": 0.7, "duration": 2},
]

## Register an enemy in the AI system
func register_enemy(enemy_id: String, max_hp: int, attack: int, defense: int, speed: int, level: int = 1, pattern: ActionPattern = ActionPattern.BALANCED) -> void:
	var enemy = EnemyData.new(enemy_id, max_hp, attack, defense, speed, level)
	enemy.pattern = pattern
	enemies[enemy_id] = enemy
	print("[EnemyAI] Registered enemy: %s (HP: %d, ATK: %d, DEF: %d, SPD: %d)" % [enemy_id, max_hp, attack, defense, speed])

## Unregister an enemy (death, flee, etc.)
func unregister_enemy(enemy_id: String) -> void:
	if enemies.has(enemy_id):
		enemies.erase(enemy_id)
		print("[EnemyAI] Unregistered enemy: %s" % enemy_id)

## Update enemy HP
func update_enemy_hp(enemy_id: String, new_hp: int) -> void:
	if enemies.has(enemy_id):
		enemies[enemy_id].current_hp = clampi(new_hp, 0, enemies[enemy_id].max_hp)

## Get enemy data
func get_enemy(enemy_id: String) -> EnemyData:
	return enemies.get(enemy_id, null)

## Calculate intent for next turn (called at end of player turn)
func calculate_intent(enemy_id: String) -> void:
	if not enemies.has(enemy_id):
		return

	var enemy = enemies[enemy_id]
	enemy.turn_count += 1

	# Determine intent type based on pattern weights
	var intent_type = _weighted_random_intent(enemy.pattern)
	enemy.current_intent = intent_type

	# Calculate intent value (damage preview, block amount, etc.)
	match intent_type:
		IntentType.ATTACK:
			var skill = attack_skills.pick_random()
			var base_damage = enemy.attack * skill.get("damage_multiplier", 1.0)
			var hits = skill.get("hits", 1)
			enemy.intent_value = int(base_damage * hits)

		IntentType.DEFEND:
			enemy.intent_value = int(enemy.defense * 1.5)

		IntentType.BUFF:
			enemy.intent_value = 0  # No numeric preview for buffs

		IntentType.DEBUFF:
			enemy.intent_value = 0  # No numeric preview for debuffs

		IntentType.SPECIAL:
			enemy.intent_value = int(enemy.attack * 2.0)

	# Emit signal for UI update
	intent_changed.emit(enemy_id, IntentType.keys()[intent_type], enemy.intent_value)

	print("[EnemyAI] %s intent: %s (value: %d)" % [enemy_id, IntentType.keys()[intent_type], enemy.intent_value])

## Execute enemy turn based on calculated intent
func execute_turn(enemy_id: String, target_ids: Array[String] = []) -> Dictionary:
	if not enemies.has(enemy_id):
		return {"success": false, "error": "Enemy not found"}

	var enemy = enemies[enemy_id]
	var action_data = {
		"enemy_id": enemy_id,
		"intent": IntentType.keys()[enemy.current_intent],
		"success": true,
		"targets": [],
		"effects": []
	}

	match enemy.current_intent:
		IntentType.ATTACK:
			action_data = _execute_attack(enemy, target_ids)

		IntentType.DEFEND:
			action_data = _execute_defend(enemy)

		IntentType.BUFF:
			action_data = _execute_buff(enemy)

		IntentType.DEBUFF:
			action_data = _execute_debuff(enemy, target_ids)

		IntentType.SPECIAL:
			action_data = _execute_special(enemy, target_ids)

	# Emit action executed signal
	action_executed.emit(enemy_id, action_data)

	return action_data

## Weighted random intent selection
func _weighted_random_intent(pattern: ActionPattern) -> IntentType:
	var weights = PATTERN_WEIGHTS.get(pattern, PATTERN_WEIGHTS[ActionPattern.BALANCED])
	var total_weight = 0

	for weight in weights.values():
		total_weight += weight

	var random_value = randf() * total_weight
	var cumulative = 0.0

	for intent in weights.keys():
		cumulative += weights[intent]
		if random_value <= cumulative:
			return intent

	return IntentType.ATTACK  # Fallback

## Execute attack action
func _execute_attack(enemy: EnemyData, target_ids: Array[String]) -> Dictionary:
	var skill = attack_skills.pick_random()
	var base_damage = enemy.attack * skill.get("damage_multiplier", 1.0)
	var hits = skill.get("hits", 1)

	# Add variance (±10%)
	var variance = randf_range(0.9, 1.1)
	var damage = int(base_damage * variance)

	# Select target (first available or random)
	var target_id = target_ids[0] if target_ids.size() > 0 else "player"

	var action_data = {
		"enemy_id": enemy.id,
		"intent": "ATTACK",
		"skill_name": skill.get("name", "攻击"),
		"success": true,
		"targets": [target_id],
		"effects": []
	}

	for i in range(hits):
		action_data.effects.append({
			"type": "damage",
			"target": target_id,
			"value": damage,
			"hit": i + 1,
			"total_hits": hits
		})

	print("[EnemyAI] %s attacks %s with %s for %dx%d damage" % [enemy.id, target_id, skill.name, damage, hits])

	return action_data

## Execute defend action
func _execute_defend(enemy: EnemyData) -> Dictionary:
	var block_amount = int(enemy.defense * 1.5)

	# Apply temporary defense buff
	enemy.status_effects.append({
		"type": "block",
		"value": block_amount,
		"duration": 1
	})

	var action_data = {
		"enemy_id": enemy.id,
		"intent": "DEFEND",
		"skill_name": "防御",
		"success": true,
		"targets": [enemy.id],
		"effects": [{
			"type": "block",
			"target": enemy.id,
			"value": block_amount
		}]
	}

	print("[EnemyAI] %s defends, gaining %d block" % [enemy.id, block_amount])

	return action_data

## Execute buff action
func _execute_buff(enemy: EnemyData) -> Dictionary:
	var skill = buff_skills.pick_random()

	# Apply buff
	enemy.status_effects.append({
		"type": "buff",
		"stat": skill.stat,
		"multiplier": skill.multiplier,
		"duration": skill.duration
	})

	var action_data = {
		"enemy_id": enemy.id,
		"intent": "BUFF",
		"skill_name": skill.name,
		"success": true,
		"targets": [enemy.id],
		"effects": [{
			"type": "buff",
			"target": enemy.id,
			"stat": skill.stat,
			"multiplier": skill.multiplier,
			"duration": skill.duration
		}]
	}

	print("[EnemyAI] %s uses %s (x%.1f for %d turns)" % [enemy.id, skill.name, skill.multiplier, skill.duration])

	return action_data

## Execute debuff action
func _execute_debuff(enemy: EnemyData, target_ids: Array[String]) -> Dictionary:
	var skill = debuff_skills.pick_random()
	var target_id = target_ids[0] if target_ids.size() > 0 else "player"

	var action_data = {
		"enemy_id": enemy.id,
		"intent": "DEBUFF",
		"skill_name": skill.name,
		"success": true,
		"targets": [target_id],
		"effects": [{
			"type": "debuff",
			"target": target_id,
			"stat": skill.stat,
			"multiplier": skill.multiplier,
			"duration": skill.duration
		}]
	}

	print("[EnemyAI] %s uses %s on %s (x%.1f for %d turns)" % [enemy.id, skill.name, target_id, skill.multiplier, skill.duration])

	return action_data

## Execute special action
func _execute_special(enemy: EnemyData, target_ids: Array[String]) -> Dictionary:
	var damage = int(enemy.attack * 2.0)
	var target_id = target_ids[0] if target_ids.size() > 0 else "player"

	var action_data = {
		"enemy_id": enemy.id,
		"intent": "SPECIAL",
		"skill_name": "必杀技",
		"success": true,
		"targets": [target_id],
		"effects": [{
			"type": "damage",
			"target": target_id,
			"value": damage,
			"is_special": true
		}]
	}

	print("[EnemyAI] %s uses special attack on %s for %d damage" % [enemy.id, target_id, damage])

	return action_data

## Process status effects at turn start
func process_status_effects(enemy_id: String) -> void:
	if not enemies.has(enemy_id):
		return

	var enemy = enemies[enemy_id]
	var expired_effects = []

	for i in range(enemy.status_effects.size()):
		var effect = enemy.status_effects[i]
		effect.duration -= 1

		if effect.duration <= 0:
			expired_effects.append(i)

	# Remove expired effects (reverse order to maintain indices)
	for i in range(expired_effects.size() - 1, -1, -1):
		enemy.status_effects.remove_at(expired_effects[i])

## Get effective stat with modifiers
func get_effective_stat(enemy_id: String, stat_name: String) -> int:
	if not enemies.has(enemy_id):
		return 0

	var enemy = enemies[enemy_id]
	var base_value = 0

	match stat_name:
		"attack":
			base_value = enemy.attack
		"defense":
			base_value = enemy.defense
		"speed":
			base_value = enemy.speed

	# Apply status effect multipliers
	var multiplier = 1.0
	for effect in enemy.status_effects:
		if effect.get("type") in ["buff", "debuff"] and effect.get("stat") == stat_name:
			multiplier *= effect.get("multiplier", 1.0)

	return int(base_value * multiplier)

## Get block value
func get_block_value(enemy_id: String) -> int:
	if not enemies.has(enemy_id):
		return 0

	var enemy = enemies[enemy_id]
	var total_block = 0

	for effect in enemy.status_effects:
		if effect.get("type") == "block":
			total_block += effect.get("value", 0)

	return total_block

## Reset all enemies (for new battle)
func reset_all() -> void:
	enemies.clear()
	print("[EnemyAI] Reset all enemies")

## Get intent display data for UI
func get_intent_display(enemy_id: String) -> Dictionary:
	if not enemies.has(enemy_id):
		return {}

	var enemy = enemies[enemy_id]
	return {
		"intent_type": IntentType.keys()[enemy.current_intent],
		"intent_value": enemy.intent_value,
		"icon": _get_intent_icon(enemy.current_intent),
		"color": _get_intent_color(enemy.current_intent)
	}

## Get intent icon path
func _get_intent_icon(intent: IntentType) -> String:
	match intent:
		IntentType.ATTACK:
			return "res://assets/ui/icons/intent_attack.png"
		IntentType.DEFEND:
			return "res://assets/ui/icons/intent_defend.png"
		IntentType.BUFF:
			return "res://assets/ui/icons/intent_buff.png"
		IntentType.DEBUFF:
			return "res://assets/ui/icons/intent_debuff.png"
		IntentType.SPECIAL:
			return "res://assets/ui/icons/intent_special.png"
		_:
			return "res://assets/ui/icons/intent_unknown.png"

## Get intent color
func _get_intent_color(intent: IntentType) -> Color:
	match intent:
		IntentType.ATTACK:
			return Color(1.0, 0.3, 0.3)  # Red
		IntentType.DEFEND:
			return Color(0.3, 0.7, 1.0)  # Blue
		IntentType.BUFF:
			return Color(0.3, 1.0, 0.3)  # Green
		IntentType.DEBUFF:
			return Color(0.8, 0.3, 1.0)  # Purple
		IntentType.SPECIAL:
			return Color(1.0, 0.8, 0.0)  # Gold
		_:
			return Color(0.5, 0.5, 0.5)  # Gray
