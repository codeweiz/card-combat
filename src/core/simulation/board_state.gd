class_name BoardState
extends RefCounted

## Deterministic lane board and player life state for MVP matches.

const LANE_LEFT: StringName = &"left"
const LANE_CENTER: StringName = &"center"
const LANE_RIGHT: StringName = &"right"
const STARTING_PLAYER_LIFE: int = 20

var lane_order: Array[StringName] = [LANE_LEFT, LANE_CENTER, LANE_RIGHT]
var lanes: Dictionary = {}
var player_life_by_id: Dictionary = {}
var next_unit_index: int = 0


## Initializes default MVP board state.
func initialize(player_ids: Array[StringName]) -> void:
	lanes.clear()
	player_life_by_id.clear()
	next_unit_index = 0
	for lane_id: StringName in lane_order:
		var lane := LaneState.new()
		lane.lane_id = lane_id
		lanes[lane_id] = lane
	for player_id: StringName in player_ids:
		player_life_by_id[player_id] = STARTING_PLAYER_LIFE


## Returns true if the lane id exists.
func has_lane(lane_id: StringName) -> bool:
	return lanes.has(lane_id)


## Returns a lane by id, or null when missing.
func get_lane(lane_id: StringName) -> LaneState:
	return lanes.get(lane_id, null)


## Returns true if this player can place a unit in the lane.
func can_place_unit(owner_player_id: StringName, lane_id: StringName) -> bool:
	if not player_life_by_id.has(owner_player_id):
		return false
	if not has_lane(lane_id):
		return false
	var lane: LaneState = lanes[lane_id]
	return not lane.has_unit_for_player(owner_player_id)


## Creates and places a unit from a definition.
func place_unit(owner_player_id: StringName, lane_id: StringName, definition: CardDefinition, played_turn: int = 0) -> UnitInstance:
	if definition == null:
		return null
	if definition.card_type != CardDefinition.TYPE_UNIT:
		return null
	if not can_place_unit(owner_player_id, lane_id):
		return null
	var instance_id := StringName("%s_unit_%04d" % [owner_player_id, next_unit_index])
	next_unit_index += 1
	var unit := UnitInstance.from_card(instance_id, owner_player_id, definition)
	var lane: LaneState = lanes[lane_id]
	if not lane.add_unit(unit):
		return null
	unit.played_turn = played_turn
	return unit


## Returns the unit with `instance_id`, if present, and its lane id.
func find_unit(instance_id: StringName) -> UnitInstance:
	for lane_id: StringName in lane_order:
		var lane: LaneState = lanes.get(lane_id, null)
		if lane == null:
			continue
		for player_id: StringName in lane.units_by_player.keys():
			var unit: UnitInstance = lane.units_by_player.get(player_id, null)
			if unit != null and unit.unit_instance_id == instance_id:
				return unit
	return null


## Returns the lane id that currently owns a unit instance, or "".
func find_unit_lane(instance_id: StringName) -> StringName:
	for lane_id: StringName in lane_order:
		var lane: LaneState = lanes.get(lane_id, null)
		if lane == null:
			continue
		for player_id: StringName in lane.units_by_player.keys():
			var unit: UnitInstance = lane.units_by_player.get(player_id, null)
			if unit != null and unit.unit_instance_id == instance_id:
				return lane_id
	return &""


## Removes and returns a unit by instance id, or null.
func remove_unit(instance_id: StringName) -> UnitInstance:
	var lane_id: StringName = find_unit_lane(instance_id)
	if lane_id == &"":
		return null
	var lane: LaneState = lanes[lane_id]
	for player_id: StringName in lane.units_by_player.keys():
		var unit: UnitInstance = lane.units_by_player.get(player_id, null)
		if unit != null and unit.unit_instance_id == instance_id:
			lane.units_by_player.erase(player_id)
			return unit
	return null


## Moves a unit between lanes for its owner when destination lane is empty for that owner.
func move_unit(instance_id: StringName, target_lane: StringName) -> bool:
	if not has_lane(target_lane):
		return false
	var from_lane_id: StringName = find_unit_lane(instance_id)
	if from_lane_id == &"":
		return false
	if from_lane_id == target_lane:
		return false
	var unit_owner: StringName = &""
	var unit_to_move: UnitInstance = null
	var from_lane: LaneState = lanes[from_lane_id]
	for player_id: StringName in from_lane.units_by_player.keys():
		var unit: UnitInstance = from_lane.units_by_player.get(player_id, null)
		if unit != null and unit.unit_instance_id == instance_id:
			unit_owner = player_id
			unit_to_move = unit
			break
	if unit_to_move == null:
		return false
	var to_lane: LaneState = lanes[target_lane]
	if to_lane.has_unit_for_player(unit_owner):
		return false
	from_lane.remove_unit_for_player(unit_owner)
	if not to_lane.add_unit(unit_to_move):
		from_lane.add_unit(unit_to_move)
		return false
	return true


## Sets all units for this owner to the requested ready flag.
func set_units_ready_for_player(owner_id: StringName, ready_flag: bool, minimum_turn: int = -1) -> void:
	for lane_id: StringName in lane_order:
		var lane: LaneState = lanes.get(lane_id, null)
		if lane == null:
			continue
		var unit: UnitInstance = lane.get_unit_for_player(owner_id)
		if unit != null:
			if not ready_flag:
				unit.ready = false
			elif minimum_turn < 0:
				unit.ready = true
			else:
				unit.ready = unit.played_turn < minimum_turn


## Counts ready units for this player across all lanes.
func count_ready_units_for_player(owner_id: StringName) -> int:
	var ready_count: int = 0
	for lane_id: StringName in lane_order:
		var lane: LaneState = lanes.get(lane_id, null)
		if lane == null:
			continue
		var unit: UnitInstance = lane.get_unit_for_player(owner_id)
		if unit != null and unit.ready:
			ready_count += 1
	return ready_count


## Counts all units for this player across all lanes.
func count_units_for_player(owner_id: StringName) -> int:
	var unit_count: int = 0
	for lane_id: StringName in lane_order:
		var lane: LaneState = lanes.get(lane_id, null)
		if lane == null:
			continue
		var unit: UnitInstance = lane.get_unit_for_player(owner_id)
		if unit != null:
			unit_count += 1
	return unit_count


## Returns deterministic board data.
func to_canonical_data(player_order: Array[StringName]) -> Dictionary:
	var lane_data: Array = []
	var lane_order_data: Array[String] = []
	for lane_id: StringName in lane_order:
		lane_order_data.append(str(lane_id))
		lane_data.append(lanes[lane_id].to_canonical_data(player_order))
	var life_data: Dictionary = {}
	for player_id: StringName in player_order:
		life_data[str(player_id)] = player_life_by_id.get(player_id, STARTING_PLAYER_LIFE)
	return {
		"lane_order": lane_order_data,
		"lanes": lane_data,
		"next_unit_index": next_unit_index,
		"player_life_by_id": life_data,
	}
