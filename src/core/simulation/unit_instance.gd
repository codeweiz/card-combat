class_name UnitInstance
extends RefCounted

## Runtime unit state on the deterministic board.

var unit_instance_id: StringName = &""
var owner_player_id: StringName = &""
var card_id: StringName = &""
var attack: int = 0
var health: int = 0
var max_health: int = 0
var ready: bool = false
var played_turn: int = 0


## Creates a runtime unit from a card definition.
static func from_card(instance_id: StringName, owner_id: StringName, definition: CardDefinition) -> UnitInstance:
	var unit := UnitInstance.new()
	unit.unit_instance_id = instance_id
	unit.owner_player_id = owner_id
	unit.card_id = definition.card_id
	unit.attack = definition.unit_attack
	unit.health = definition.unit_health
	unit.max_health = definition.unit_health
	unit.ready = false
	unit.played_turn = 0
	return unit


## Returns true when this unit should leave the board.
func is_destroyed() -> bool:
	return health <= 0


## Returns deterministic data for board hashing.
func to_canonical_data() -> Dictionary:
	return {
		"attack": attack,
		"card_id": card_id,
		"played_turn": played_turn,
		"health": health,
		"max_health": max_health,
		"owner_player_id": owner_player_id,
		"ready": ready,
		"unit_instance_id": unit_instance_id,
	}
