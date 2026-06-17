class_name LaneState
extends RefCounted

## Deterministic state for one lane.

var lane_id: StringName = &""
var units_by_player: Dictionary = {}


## Returns true if this owner already has a unit in this lane.
func has_unit_for_player(player_id: StringName) -> bool:
	return units_by_player.has(player_id)


## Returns the unit controlled by the player in this lane, if any.
func get_unit_for_player(player_id: StringName) -> UnitInstance:
	return units_by_player.get(player_id, null)


## Adds a unit if this player slot is empty.
func add_unit(unit: UnitInstance) -> bool:
	if unit == null:
		return false
	if unit.owner_player_id == &"":
		return false
	if has_unit_for_player(unit.owner_player_id):
		return false
	units_by_player[unit.owner_player_id] = unit
	return true


## Removes and returns a player's unit from this lane.
func remove_unit_for_player(player_id: StringName) -> UnitInstance:
	var unit: UnitInstance = units_by_player.get(player_id, null)
	if unit != null:
		units_by_player.erase(player_id)
	return unit


## Returns deterministic lane data.
func to_canonical_data(player_order: Array[StringName]) -> Dictionary:
	var units: Dictionary = {}
	for player_id: StringName in player_order:
		var unit: UnitInstance = get_unit_for_player(player_id)
		units[str(player_id)] = unit.to_canonical_data() if unit != null else null
	return {
		"lane_id": lane_id,
		"units_by_player": units,
	}
