class_name MatchState
extends RefCounted

## Authoritative deterministic match state for the MVP rules core.

var initialized: bool = false
var complete: bool = false
var rule_set_version: int = 1
var card_data_hash: String = ""
var player_ids: Array[StringName] = []
var next_sequence_by_player: Dictionary = {}
var accepted_command_ids: Array[StringName] = []
var event_count: int = 0
var initial_seed: int = 0
var active_player_id: StringName = &""
var remaining_main_actions_for_active_player: int = 0
var turn_index: int = 0
var winner_player_id: StringName = &""
var loser_player_id: StringName = &""
var end_reason: StringName = &""
var format_id: StringName = &"mvp_local"
var board := BoardState.new()
var response_window := ResponseWindowState.new()
var next_response_window_index: int = 0


## Initializes state from a setup payload.
func initialize_from_setup(setup: MatchSetup) -> void:
	initialized = true
	complete = false
	rule_set_version = setup.rule_set_version
	card_data_hash = setup.card_data_hash
	player_ids = setup.player_ids.duplicate()
	initial_seed = setup.initial_seed
	format_id = setup.format_id
	next_sequence_by_player.clear()
	accepted_command_ids.clear()
	event_count = 0
	next_response_window_index = 0
	active_player_id = player_ids[0] if player_ids.size() > 0 else &""
	remaining_main_actions_for_active_player = 1
	turn_index = 1
	winner_player_id = &""
	loser_player_id = &""
	end_reason = &""
	for player_id: StringName in player_ids:
		next_sequence_by_player[player_id] = 0
	board.initialize(player_ids)
	response_window.clear()


## Returns deterministic state data for hashing and replay checks.
func to_canonical_data() -> Dictionary:
	var players: Array[String] = []
	for player_id: StringName in player_ids:
		players.append(str(player_id))
	var sequences: Dictionary = {}
	var sequence_keys: Array = next_sequence_by_player.keys()
	sequence_keys.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
	for key: Variant in sequence_keys:
		sequences[str(key)] = next_sequence_by_player[key]
	var command_ids: Array[String] = []
	for command_id: StringName in accepted_command_ids:
		command_ids.append(str(command_id))
	return {
		"accepted_command_ids": command_ids,
		"board": board.to_canonical_data(player_ids),
		"card_data_hash": card_data_hash,
		"complete": complete,
		"event_count": event_count,
		"active_player_id": active_player_id,
		"end_reason": end_reason,
		"format_id": format_id,
		"initial_seed": initial_seed,
		"loser_player_id": loser_player_id,
		"initialized": initialized,
		"next_sequence_by_player": sequences,
		"player_ids": players,
		"remaining_main_actions_for_active_player": remaining_main_actions_for_active_player,
		"response_window": response_window.to_canonical_data(),
		"rule_set_version": rule_set_version,
		"next_response_window_index": next_response_window_index,
		"turn_index": turn_index,
		"winner_player_id": winner_player_id,
	}


## Returns a deterministic hash for the current match state.
func get_state_hash() -> String:
	return StableHash.stable_hash(to_canonical_data())
