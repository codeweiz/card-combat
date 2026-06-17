class_name ActionCommand
extends RefCounted

## Player or AI intention submitted to the deterministic simulation core.

var command_id: StringName = &""
var actor_player_id: StringName = &""
var command_type: StringName = &"noop"
var sequence_id: int = 0
var expected_state_hash: String = ""
var card_id: StringName = &""
var target_id: StringName = &""
var target_lane: StringName = &""


## Returns a deterministic representation for logging and hashing.
func to_canonical_data() -> Dictionary:
	return {
		"actor_player_id": actor_player_id,
		"card_id": card_id,
		"command_id": command_id,
		"command_type": command_type,
		"expected_state_hash": expected_state_hash,
		"sequence_id": sequence_id,
		"target_id": target_id,
		"target_lane": target_lane,
	}
