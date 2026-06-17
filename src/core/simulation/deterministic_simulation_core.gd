class_name DeterministicSimulationCore
extends RefCounted

## Scene-independent deterministic rules core.
## This class owns match state and mutates it only through validated commands.

var _state := MatchState.new()
var _card_database: CardDatabase
var _effect_resolver := CardEffectResolver.new()

const COMMAND_END_TURN: StringName = &"end_turn"
const COMMAND_ATTACK_UNIT: StringName = &"attack_unit"
const END_REASON_LIFE_ZERO: StringName = &"life_zero"
const MAIN_ACTIONS_PER_TURN_MVP: int = 1
const PHASE_MAIN: StringName = &"main"
const PHASE_ATTACK: StringName = &"attack"


## Initializes a deterministic match from setup and validated card data.
func initialize_match(setup: MatchSetup, card_database: CardDatabase) -> SimulationResult:
	if setup == null:
		return SimulationResult.rejected_result(&"missing_setup", "MatchSetup is required")
	if card_database == null:
		return SimulationResult.rejected_result(&"missing_card_database", "CardDatabase is required")
	var report: CardValidationReport = card_database.validate()
	if not report.is_valid():
		return SimulationResult.rejected_result(&"invalid_card_database", "; ".join(report.errors))
	if setup.player_ids.size() != 2:
		return SimulationResult.rejected_result(&"invalid_player_count", "MVP local matches require exactly two players")
	if setup.card_data_hash != card_database.get_card_data_hash():
		return SimulationResult.rejected_result(&"card_hash_mismatch", "MatchSetup card_data_hash does not match CardDatabase")
	_card_database = card_database
	_state.initialize_from_setup(setup)
	return SimulationResult.accepted_result(_state.get_state_hash(), ["match_initialized"])


## Submits a command to the deterministic simulation core.
func submit_command(command: ActionCommand) -> SimulationResult:
	if command == null:
		return SimulationResult.rejected_result(&"missing_command", "ActionCommand is required", _state.get_state_hash())
	if not _state.initialized:
		return SimulationResult.rejected_result(&"match_not_initialized", "Match is not initialized", _state.get_state_hash())
	if _state.complete:
		return SimulationResult.rejected_result(&"match_complete", "Match is complete", _state.get_state_hash())
	if not _state.next_sequence_by_player.has(command.actor_player_id):
		return SimulationResult.rejected_result(&"unknown_actor", "Unknown actor player id", _state.get_state_hash())
	if command.expected_state_hash != "" and command.expected_state_hash != _state.get_state_hash():
		return SimulationResult.rejected_result(&"state_hash_mismatch", "Expected state hash does not match current state", _state.get_state_hash())
	var expected_sequence: int = _state.next_sequence_by_player[command.actor_player_id]
	if command.sequence_id != expected_sequence:
		return SimulationResult.rejected_result(&"sequence_mismatch", "Expected sequence %d for %s" % [expected_sequence, command.actor_player_id], _state.get_state_hash())
	if command.command_id == &"":
		return SimulationResult.rejected_result(&"missing_command_id", "command_id is required", _state.get_state_hash())
	if not _state.complete and command.command_type != &"pass_response" and command.command_type != &"play_response" and command.actor_player_id != _state.active_player_id:
		return SimulationResult.rejected_result(&"wrong_player_turn", "Actor is not the active player", _state.get_state_hash())
	if _state.response_window.is_open():
		if command.command_type == &"pass_response":
			return _submit_pass_response(command)
		if command.command_type == &"play_response":
			return _submit_play_response(command)
		return SimulationResult.rejected_result(&"response_window_open", "Only response or pass commands are legal while a response window is open", _state.get_state_hash())
	if command.command_type == &"noop":
		if _state.turn_phase != PHASE_MAIN:
			return SimulationResult.rejected_result(&"noop_invalid_phase", "noop is only valid in main phase", _state.get_state_hash())
		return _accept_command(command, ["noop_accepted"])
	if command.command_type == COMMAND_END_TURN:
		return _submit_end_turn(command)
	if command.command_type == COMMAND_ATTACK_UNIT:
		return _submit_attack_unit(command)
	if command.command_type == &"play_spell":
		return _submit_play_spell(command)
	if command.command_type == &"play_unit":
		return _submit_play_unit(command)
	return SimulationResult.rejected_result(&"unsupported_command", "Unsupported command type %s" % command.command_type, _state.get_state_hash())


## Returns an immutable canonical state snapshot for UI, tooling, and replay checks.
func get_state_snapshot() -> Dictionary:
	return _state.to_canonical_data().duplicate(true)


## Returns the deterministic hash for the current match state.
func get_state_hash() -> String:
	return _state.get_state_hash()


## Returns MVP legal commands for the player.
func query_legal_actions(player_id: StringName) -> Array[ActionCommand]:
	var actions: Array[ActionCommand] = []
	if not _state.initialized or _state.complete:
		return actions
	if not _state.next_sequence_by_player.has(player_id):
		return actions
	var sequence_id: int = _state.next_sequence_by_player[player_id]
	var preview_prefix := String(player_id)
	if _state.response_window.is_open():
		if _state.response_window.has_priority(player_id):
			var pass_command := ActionCommand.new()
			pass_command.command_id = StringName("preview_pass_response_%s" % preview_prefix)
			pass_command.actor_player_id = player_id
			pass_command.command_type = &"pass_response"
			pass_command.sequence_id = sequence_id
			pass_command.expected_state_hash = _state.get_state_hash()
			actions.append(pass_command)
			for card_id: StringName in _card_database.get_card_ids():
				var definition: CardDefinition = _card_database.get_card_definition(card_id)
				if definition == null:
					continue
				if definition.card_type != CardDefinition.TYPE_RESPONSE or definition.speed != CardDefinition.SPEED_RESPONSE:
					continue
				var response_command := ActionCommand.new()
				response_command.command_id = StringName("preview_play_response_%s_%s" % [card_id, preview_prefix])
				response_command.actor_player_id = player_id
				response_command.command_type = &"play_response"
				response_command.card_id = card_id
				response_command.sequence_id = sequence_id
				response_command.expected_state_hash = _state.get_state_hash()
				actions.append(response_command)
			return actions
	if player_id != _state.active_player_id:
		return actions
	if _state.turn_phase == PHASE_ATTACK:
		if _state.remaining_attack_actions_for_active_player > 0:
			for lane_id: StringName in _state.board.lane_order:
				var lane: LaneState = _state.board.get_lane(lane_id)
				if lane == null:
					continue
				var attacker: UnitInstance = lane.get_unit_for_player(player_id)
				if attacker == null or not attacker.ready:
					continue
				var attack_command := ActionCommand.new()
				attack_command.command_id = StringName("preview_attack_unit_%s_%s" % [attacker.unit_instance_id, lane_id])
				attack_command.actor_player_id = player_id
				attack_command.command_type = COMMAND_ATTACK_UNIT
				attack_command.target_lane = lane_id
				attack_command.target_id = attacker.unit_instance_id
				attack_command.sequence_id = sequence_id
				attack_command.expected_state_hash = _state.get_state_hash()
				actions.append(attack_command)
	var end_turn_command := ActionCommand.new()
	end_turn_command.command_id = StringName("preview_end_turn_%s" % preview_prefix)
	end_turn_command.actor_player_id = player_id
	end_turn_command.command_type = COMMAND_END_TURN
	end_turn_command.sequence_id = sequence_id
	end_turn_command.expected_state_hash = _state.get_state_hash()
	actions.append(end_turn_command)
	if _state.remaining_main_actions_for_active_player <= 0:
		return actions
	if _state.turn_phase != PHASE_MAIN:
		return actions
	var command := ActionCommand.new()
	command.command_id = StringName("preview_noop_%s" % preview_prefix)
	command.actor_player_id = player_id
	command.command_type = &"noop"
	command.sequence_id = sequence_id
	command.expected_state_hash = _state.get_state_hash()
	actions.append(command)

	for card_id: StringName in _card_database.get_card_ids():
		var definition: CardDefinition = _card_database.get_card_definition(card_id)
		if definition == null:
			continue
		if definition.card_type == CardDefinition.TYPE_UNIT and definition.speed == CardDefinition.SPEED_MAIN:
			for lane_id: StringName in _state.board.lane_order:
				if _state.board.can_place_unit(player_id, lane_id):
					var play_unit := ActionCommand.new()
					play_unit.command_id = StringName("preview_play_unit_%s_%s" % [card_id, lane_id])
					play_unit.actor_player_id = player_id
					play_unit.command_type = &"play_unit"
					play_unit.card_id = card_id
					play_unit.target_lane = lane_id
					play_unit.sequence_id = sequence_id
					play_unit.expected_state_hash = _state.get_state_hash()
					actions.append(play_unit)
			continue
		if definition.card_type == CardDefinition.TYPE_SPELL and definition.speed == CardDefinition.SPEED_MAIN:
			var play_spell := ActionCommand.new()
			play_spell.command_id = StringName("preview_play_spell_%s" % card_id)
			play_spell.actor_player_id = player_id
			play_spell.command_type = &"play_spell"
			play_spell.card_id = card_id
			play_spell.sequence_id = sequence_id
			play_spell.expected_state_hash = _state.get_state_hash()
			actions.append(play_spell)
	return actions


func _submit_play_unit(command: ActionCommand) -> SimulationResult:
	if _state.turn_phase != PHASE_MAIN:
		return SimulationResult.rejected_result(&"main_phase_only", "play_unit is only valid in main phase", _state.get_state_hash())
	if command.card_id == &"":
		return SimulationResult.rejected_result(&"missing_card_id", "play_unit requires card_id", _state.get_state_hash())
	if command.target_lane == &"":
		return SimulationResult.rejected_result(&"missing_target_lane", "play_unit requires target_lane", _state.get_state_hash())
	if command.actor_player_id != _state.active_player_id:
		return SimulationResult.rejected_result(&"wrong_player_turn", "Actor is not the active player", _state.get_state_hash())
	var definition: CardDefinition = _card_database.get_card_definition(command.card_id)
	if definition == null:
		return SimulationResult.rejected_result(&"unknown_card", "Unknown card_id %s" % command.card_id, _state.get_state_hash())
	if definition.card_type != CardDefinition.TYPE_UNIT:
		return SimulationResult.rejected_result(&"card_not_unit", "%s is not a unit card" % command.card_id, _state.get_state_hash())
	if not _state.board.can_place_unit(command.actor_player_id, command.target_lane):
		return SimulationResult.rejected_result(&"lane_slot_occupied", "Cannot place unit in lane %s" % command.target_lane, _state.get_state_hash())
	if not _consume_main_action():
		return SimulationResult.rejected_result(&"main_actions_exhausted", "No main actions remain this turn", _state.get_state_hash())
	var defender_id := _get_opponent_player_id(command.actor_player_id)
	if defender_id == &"":
		return SimulationResult.rejected_result(&"missing_defender", "play_unit requires an opposing defender", _state.get_state_hash())
	_state.response_window.open_for_original(_state.next_response_window_index, command, defender_id)
	_state.next_response_window_index += 1
	return _accept_command(command, ["response_window_opened:%s:%s" % [_state.response_window.window_id, command.command_id]])


func _submit_pass_response(command: ActionCommand) -> SimulationResult:
	if not _state.response_window.has_priority(command.actor_player_id):
		return SimulationResult.rejected_result(&"no_response_priority", "Actor does not have response priority", _state.get_state_hash())
	_record_accepted_command(command)
	var events: Array[String] = ["response_passed:%s" % _state.response_window.window_id]
	events.append_array(_resolve_pending_original_after_response())
	_state.event_count += events.size()
	return SimulationResult.accepted_result(_state.get_state_hash(), events)


func _submit_play_response(command: ActionCommand) -> SimulationResult:
	if not _state.response_window.can_accept_response(command.actor_player_id):
		return SimulationResult.rejected_result(&"no_response_priority", "Actor cannot submit a response in this window", _state.get_state_hash())
	if command.card_id == &"":
		return SimulationResult.rejected_result(&"missing_card_id", "play_response requires card_id", _state.get_state_hash())
	if command.actor_player_id != _state.response_window.defender_player_id:
		return SimulationResult.rejected_result(&"no_response_priority", "Actor does not have response priority", _state.get_state_hash())
	var definition: CardDefinition = _card_database.get_card_definition(command.card_id)
	if definition == null:
		return SimulationResult.rejected_result(&"unknown_card", "Unknown card_id %s" % command.card_id, _state.get_state_hash())
	if definition.speed != CardDefinition.SPEED_RESPONSE:
		return SimulationResult.rejected_result(&"card_not_response_speed", "%s is not response speed" % command.card_id, _state.get_state_hash())
	if definition.card_type != CardDefinition.TYPE_RESPONSE:
		return SimulationResult.rejected_result(&"card_not_response_type", "%s is not a response card" % command.card_id, _state.get_state_hash())
	_record_accepted_command(command)
	var response_item := StackItem.from_command(StackItem.KIND_RESPONSE, command)
	_state.response_window.response_item = response_item
	_state.response_window.responses_used += 1
	var events: Array[String] = ["response_played:%s:%s" % [_state.response_window.window_id, command.command_id]]
	events.append_array(_effect_resolver.resolve_card_effects(definition, _state, response_item))
	events.append_array(_resolve_pending_original_after_response())
	_state.event_count += events.size()
	return SimulationResult.accepted_result(_state.get_state_hash(), events)


func _resolve_pending_original_after_response() -> Array[String]:
	var events: Array[String] = []
	_state.response_window.window_state = ResponseWindowState.STATE_RESOLVING
	var original: StackItem = _state.response_window.original_item
	if original == null:
		events.append("original_missing")
		_state.response_window.clear()
		return events
	if original.canceled:
		original.resolved = false
		events.append("original_canceled:%s:%s" % [original.command_id, original.outcome_reason])
		events.append("response_window_closed:%s" % _state.response_window.window_id)
		_state.response_window.clear()
		return events
	if original.command_type == &"play_unit":
		events.append_array(_resolve_original_play_unit(original))
	elif original.command_type == &"play_spell":
		events.append_array(_resolve_original_play_spell(original))
	elif original.command_type == COMMAND_ATTACK_UNIT:
		events.append_array(_resolve_original_attack(original))
	else:
		original.fizzled = true
		original.outcome_reason = &"unsupported_original_command"
		events.append("original_fizzled:%s:%s" % [original.command_id, original.outcome_reason])
	events.append("response_window_closed:%s" % _state.response_window.window_id)
	_state.response_window.clear()
	if not _state.complete:
		events.append_array(_check_match_completion())
	return events


func _resolve_original_play_unit(original: StackItem) -> Array[String]:
	var events: Array[String] = []
	var definition: CardDefinition = _card_database.get_card_definition(original.card_id)
	if definition == null:
		original.fizzled = true
		original.outcome_reason = &"unknown_card"
		events.append("original_fizzled:%s:%s" % [original.command_id, original.outcome_reason])
		return events
	if not _state.board.can_place_unit(original.actor_player_id, original.target_lane):
		original.fizzled = true
		original.outcome_reason = &"lane_slot_occupied"
		events.append("original_fizzled:%s:%s" % [original.command_id, original.outcome_reason])
		return events
	var unit: UnitInstance = _state.board.place_unit(original.actor_player_id, original.target_lane, definition, _state.turn_index)
	if unit == null:
		original.fizzled = true
		original.outcome_reason = &"unit_placement_failed"
		events.append("original_fizzled:%s:%s" % [original.command_id, original.outcome_reason])
		return events
	original.resolved = true
	original.outcome_reason = &"resolved"
	events.append("unit_played:%s:%s" % [unit.unit_instance_id, original.target_lane])
	return events


func _submit_attack_unit(command: ActionCommand) -> SimulationResult:
	if _state.turn_phase != PHASE_ATTACK:
		return SimulationResult.rejected_result(&"attack_phase_only", "attack_unit is only valid in attack phase", _state.get_state_hash())
	if command.actor_player_id != _state.active_player_id:
		return SimulationResult.rejected_result(&"wrong_player_turn", "Actor is not the active player", _state.get_state_hash())
	if command.target_lane == &"":
		return SimulationResult.rejected_result(&"missing_target_lane", "attack_unit requires target_lane", _state.get_state_hash())
	var lane: LaneState = _state.board.get_lane(command.target_lane)
	if lane == null:
		return SimulationResult.rejected_result(&"invalid_target_lane", "Unknown lane %s" % command.target_lane, _state.get_state_hash())
	var attacker: UnitInstance = lane.get_unit_for_player(command.actor_player_id)
	if attacker == null:
		return SimulationResult.rejected_result(&"no_attacker", "No active player's unit in lane %s" % command.target_lane, _state.get_state_hash())
	if not attacker.ready:
		return SimulationResult.rejected_result(&"attacker_not_ready", "Selected unit is not ready to attack", _state.get_state_hash())
	if not _consume_attack_action():
		return SimulationResult.rejected_result(&"attack_actions_exhausted", "No attack actions remain this turn", _state.get_state_hash())
	attacker.ready = false
	var defender_id := _get_opponent_player_id(command.actor_player_id)
	if defender_id == &"":
		return SimulationResult.rejected_result(&"missing_defender", "attack_unit requires an opposing defender", _state.get_state_hash())
	_state.response_window.open_for_original(_state.next_response_window_index, command, defender_id)
	_state.next_response_window_index += 1
	return _accept_command(command, ["attack_declared:%s:%s" % [attacker.unit_instance_id, command.target_lane]])


func _resolve_original_attack(original: StackItem) -> Array[String]:
	var events: Array[String] = []
	if original.target_lane == &"":
		original.fizzled = true
		original.outcome_reason = &"missing_target_lane"
		events.append("original_fizzled:%s:%s" % [original.command_id, original.outcome_reason])
		return events
	var lane: LaneState = _state.board.get_lane(original.target_lane)
	if lane == null:
		original.fizzled = true
		original.outcome_reason = &"invalid_target_lane"
		events.append("original_fizzled:%s:%s" % [original.command_id, original.outcome_reason])
		return events
	var attacker: UnitInstance = lane.get_unit_for_player(original.actor_player_id)
	if attacker == null:
		original.fizzled = true
		original.outcome_reason = &"attacker_missing"
		events.append("original_fizzled:%s:%s" % [original.command_id, original.outcome_reason])
		return events
	var defender_id: StringName = _get_opponent_player_id(original.actor_player_id)
	if defender_id == &"":
		original.fizzled = true
		original.outcome_reason = &"missing_defender"
		events.append("original_fizzled:%s:%s" % [original.command_id, original.outcome_reason])
		return events
	var defender: UnitInstance = lane.get_unit_for_player(defender_id)
	if defender != null:
		defender.health -= attacker.attack
		events.append("unit_attacked_unit:%s:%s:%d" % [attacker.unit_instance_id, defender.unit_instance_id, attacker.attack])
		if defender.health <= 0:
			var removed_defender: UnitInstance = _state.board.remove_unit(defender.unit_instance_id)
			if removed_defender != null:
				events.append("unit_destroyed:%s" % removed_defender.unit_instance_id)
	else:
		var old_life: int = int(_state.board.player_life_by_id.get(defender_id, 0))
		var damage: int = attacker.attack
		_state.board.player_life_by_id[defender_id] = max(0, old_life - damage)
		events.append("player_attacked:%s:%d" % [defender_id, damage])
	original.resolved = true
	original.outcome_reason = &"resolved"
	return events


func _submit_play_spell(command: ActionCommand) -> SimulationResult:
	if _state.turn_phase != PHASE_MAIN:
		return SimulationResult.rejected_result(&"main_phase_only", "play_spell is only valid in main phase", _state.get_state_hash())
	if command.card_id == &"":
		return SimulationResult.rejected_result(&"missing_card_id", "play_spell requires card_id", _state.get_state_hash())
	if command.actor_player_id != _state.active_player_id:
		return SimulationResult.rejected_result(&"wrong_player_turn", "Actor is not the active player", _state.get_state_hash())
	var definition: CardDefinition = _card_database.get_card_definition(command.card_id)
	if definition == null:
		return SimulationResult.rejected_result(&"unknown_card", "Unknown card_id %s" % command.card_id, _state.get_state_hash())
	if definition.card_type != CardDefinition.TYPE_SPELL:
		return SimulationResult.rejected_result(&"card_not_spell", "%s is not a spell card" % command.card_id, _state.get_state_hash())
	if definition.speed != CardDefinition.SPEED_MAIN:
		return SimulationResult.rejected_result(&"card_not_main_speed", "%s is not a main-speed spell" % command.card_id, _state.get_state_hash())
	if not _consume_main_action():
		return SimulationResult.rejected_result(&"main_actions_exhausted", "No main actions remain this turn", _state.get_state_hash())
	var defender_id := _get_opponent_player_id(command.actor_player_id)
	if defender_id == &"":
		return SimulationResult.rejected_result(&"missing_defender", "play_spell requires an opposing defender", _state.get_state_hash())
	_state.response_window.open_for_original(_state.next_response_window_index, command, defender_id)
	_state.next_response_window_index += 1
	return _accept_command(command, ["response_window_opened:%s:%s" % [_state.response_window.window_id, command.command_id]])


func _resolve_original_play_spell(original: StackItem) -> Array[String]:
	var events: Array[String] = []
	var definition: CardDefinition = _card_database.get_card_definition(original.card_id)
	if definition == null:
		original.fizzled = true
		original.outcome_reason = &"unknown_card"
		events.append("original_fizzled:%s:%s" % [original.command_id, original.outcome_reason])
		return events
	events.append("spell_cast:%s:%s" % [original.command_id, definition.card_id])
	events.append_array(_effect_resolver.resolve_card_effects(definition, _state, original))
	original.resolved = true
	original.outcome_reason = &"resolved"
	return events


func _submit_end_turn(command: ActionCommand) -> SimulationResult:
	if command.actor_player_id != _state.active_player_id:
		return SimulationResult.rejected_result(&"wrong_player_turn", "Actor is not the active player", _state.get_state_hash())
	var events: Array[String] = []
	if _state.turn_phase == PHASE_MAIN:
		_state.turn_phase = PHASE_ATTACK
		_state.remaining_main_actions_for_active_player = 0
		_state.board.set_units_ready_for_player(_state.active_player_id, true, _state.turn_index)
		_state.remaining_attack_actions_for_active_player = _state.board.count_ready_units_for_player(_state.active_player_id)
		events.append("attack_phase_started:%s" % _state.active_player_id)
		return _accept_command(command, events)
	if _state.turn_phase != PHASE_ATTACK:
		return SimulationResult.rejected_result(&"invalid_turn_phase", "Cannot end turn in unknown phase %s" % _state.turn_phase, _state.get_state_hash())
	var next_player: StringName = _get_opponent_player_id(_state.active_player_id)
	if next_player == &"":
		return SimulationResult.rejected_result(&"missing_defender", "end_turn requires an opposing player", _state.get_state_hash())
	var previous_player: StringName = _state.active_player_id
	_state.active_player_id = next_player
	_state.turn_phase = PHASE_MAIN
	_state.remaining_main_actions_for_active_player = MAIN_ACTIONS_PER_TURN_MVP
	_state.remaining_attack_actions_for_active_player = 0
	_state.turn_index += 1
	events = ["turn_ended:%s:%s" % [previous_player, _state.active_player_id]]
	events.append_array(_check_match_completion())
	return _accept_command(command, events)


func _accept_command(command: ActionCommand, events: Array[String]) -> SimulationResult:
	_record_accepted_command(command)
	_state.event_count += events.size()
	return SimulationResult.accepted_result(_state.get_state_hash(), events)


func _consume_main_action() -> bool:
	if _state.remaining_main_actions_for_active_player <= 0:
		return false
	_state.remaining_main_actions_for_active_player -= 1
	return true


func _consume_attack_action() -> bool:
	if _state.remaining_attack_actions_for_active_player <= 0:
		return false
	_state.remaining_attack_actions_for_active_player -= 1
	return true


func _check_match_completion() -> Array[String]:
	if _state.complete:
		return []
	var alive_players: Array[StringName] = []
	for player_id: StringName in _state.player_ids:
		var life: int = int(_state.board.player_life_by_id.get(player_id, 0))
		if life > 0:
			alive_players.append(player_id)
	if alive_players.size() == _state.player_ids.size():
		return []
	var dead_players: Array[StringName] = []
	for player_id: StringName in _state.player_ids:
		if not alive_players.has(player_id):
			dead_players.append(player_id)
	_state.complete = true
	_state.end_reason = END_REASON_LIFE_ZERO
	if dead_players.size() == 1:
		_state.winner_player_id = _get_opponent_player_id(dead_players[0])
		_state.loser_player_id = dead_players[0]
		return ["match_complete:win_by_life:%s" % _state.winner_player_id]
	_state.winner_player_id = &""
	_state.loser_player_id = &""
	return ["match_complete:draw_by_life"]


func _record_accepted_command(command: ActionCommand) -> void:
	_state.accepted_command_ids.append(command.command_id)
	_state.next_sequence_by_player[command.actor_player_id] = _state.next_sequence_by_player[command.actor_player_id] + 1


func _get_opponent_player_id(player_id: StringName) -> StringName:
	for candidate_id: StringName in _state.player_ids:
		if candidate_id != player_id:
			return candidate_id
	return &""
