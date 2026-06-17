class_name LocalMatchFlow
extends RefCounted

const ActionCommand = preload("res://src/core/simulation/action_command.gd")
const CardDatabase = preload("res://src/core/card/card_database.gd")
const DeterministicSimulationCore = preload("res://src/core/simulation/deterministic_simulation_core.gd")
const PlayerDeckLoadout = preload("res://src/core/match_flow/player_deck_loadout.gd")
const LocalMatchRequest = preload("res://src/core/match_flow/local_match_request.gd")
const MatchSetup = preload("res://src/core/simulation/match_setup.gd")
const SimulationResult = preload("res://src/core/simulation/simulation_result.gd")
const CardValidationReport = preload("res://src/core/card/card_validation_report.gd")

## MVP local match orchestrator.
## Owns deck/hand lifecycle, command prevalidation and action-log assembly.
## Core match state and board transitions remain in DeterministicSimulationCore.

const STARTING_HAND_SIZE_MVP: int = 4
const MAX_HAND_SIZE_MVP: int = 10
const END_REASON_DECK_EMPTY: StringName = &"deck_empty_loss"

var _core
var _setup
var _card_database
var _match_id: StringName = &""
var _match_complete: bool = false
var _match_end_reason: StringName = &""
var _winner_player_id: StringName = &""
var _loser_player_id: StringName = &""
var _player_decks: Dictionary = {}
var _player_hands: Dictionary = {}
var _player_ids: Array[StringName] = []
var _accepted_command_ids: Dictionary = {}
var _action_log_entries: Array = []
var _action_log_id: StringName = &""
var _action_log: Dictionary = {}


## Begins a local 2-player match and performs opening hand draws.
func start_match(request, card_database) -> SimulationResult:
	if request == null:
		return SimulationResult.rejected_result(&"missing_request", "LocalMatchRequest is required")
	if card_database == null:
		return SimulationResult.rejected_result(&"missing_card_database", "CardDatabase is required")
	var report: CardValidationReport = card_database.validate()
	if not report.is_valid():
		return SimulationResult.rejected_result(&"invalid_card_database", "; ".join(report.errors))
	var setup_validation: SimulationResult = _validate_request(request, card_database)
	if not setup_validation.accepted:
		return setup_validation

	_card_database = card_database
	_match_id = request.match_id
	_player_ids = request.player_ids.duplicate()
	_setup = _build_setup(request)

	_core = DeterministicSimulationCore.new()
	var init_result: SimulationResult = _core.initialize_match(_setup, _card_database)
	if not init_result.accepted:
		_reset_runtime_state()
		return init_result
	_action_log_entries.clear()

	_player_decks.clear()
	_player_hands.clear()
	for loadout in request.player_loadouts:
		var deck_copy: Array[StringName] = loadout.ordered_card_ids.duplicate()
		var hand: Array[StringName] = []
		_player_decks[loadout.player_id] = deck_copy
		_player_hands[loadout.player_id] = hand

	# Keep request order for player priority and match flow replay.
	if _player_ids.size() != 2:
		# request should already be validated as two players, but guard anyway.
		_reset_runtime_state()
		return SimulationResult.rejected_result(&"invalid_player_count", "Local match requires two players")
	for player_id: StringName in _player_ids:
		if not _draw_cards_to_hand(player_id, STARTING_HAND_SIZE_MVP):
			_reset_runtime_state()
			return SimulationResult.rejected_result(&"opening_draw_failed", "Failed to draw opening hand for %s" % player_id)

	_action_log_id = StringName("local_match_log_%s" % _match_id)
	_action_log = {
		"action_log_id": str(_action_log_id),
		"match_id": str(_match_id),
		"status": "recording",
		"match_setup": _setup.to_canonical_data(),
		"entries": _action_log_entries,
		"event_count": 0,
		"match_complete": false,
		"replay_verified": false,
	}
	_match_complete = false
	_match_end_reason = &""
	_winner_player_id = &""
	_loser_player_id = &""
	_accepted_command_ids.clear()

	_sync_match_completion_from_core()
	if not _match_complete:
		return SimulationResult.accepted_result(_core.get_state_hash(), ["match_initialized"])
	return _build_local_result(_core.get_state_hash())


## Returns legal actions filtered by hand state for card-based commands.
func query_legal_actions(player_id: StringName) -> Array[ActionCommand]:
	var actions: Array[ActionCommand] = []
	if _core == null or _match_complete:
		return actions
	if player_id == &"" or not _player_hands.has(player_id):
		return actions
	var core_actions: Array[ActionCommand] = _core.query_legal_actions(player_id)
	if core_actions.is_empty():
		return core_actions
	for action: ActionCommand in core_actions:
		if _requires_card(action.command_type):
			if action.card_id == &"":
				continue
			if not _player_has_card_in_hand(player_id, action.card_id):
				continue
		actions.append(action)
	return actions


## Submits and routes one command through match-flow checks, deck/hand consumption,
## and core simulation.
func submit_command(command: ActionCommand) -> SimulationResult:
	if _core == null:
		return SimulationResult.rejected_result(&"match_not_started", "start_match must be called first")
	if _match_complete:
		return SimulationResult.rejected_result(&"match_complete", "Match is already complete")
	if command == null:
		return SimulationResult.rejected_result(&"missing_command", "ActionCommand is required", _core.get_state_hash())
	if command.actor_player_id == &"":
		return SimulationResult.rejected_result(&"missing_actor", "actor_player_id is required", _core.get_state_hash())
	if not _player_hands.has(command.actor_player_id):
		return SimulationResult.rejected_result(&"unknown_actor", "Actor is not a participant in this match", _core.get_state_hash())
	if command.command_id == &"":
		return SimulationResult.rejected_result(&"missing_command_id", "command_id is required", _core.get_state_hash())
	if _accepted_command_ids.has(command.command_id):
		return SimulationResult.rejected_result(&"duplicate_command_id", "command_id has already been used", _core.get_state_hash())
	if command.expected_state_hash == "":
		command.expected_state_hash = _core.get_state_hash()
	if _requires_card(command.command_type):
		if command.card_id == &"":
			return SimulationResult.rejected_result(&"missing_card_id", "card_id is required", _core.get_state_hash())
		if not _player_has_card_in_hand(command.actor_player_id, command.card_id):
			return SimulationResult.rejected_result(&"card_not_in_hand", "Card is not in player's hand", _core.get_state_hash())

	var pre_snapshot: Dictionary = _core.get_state_snapshot()
	var pre_active: StringName = _dict_get(pre_snapshot, "active_player_id", &"")
	var state_hash_before: String = _core.get_state_hash()
	var pre_complete: bool = bool(_dict_get(pre_snapshot, "complete", false))
	var result: SimulationResult = _core.submit_command(command)
	if not result.accepted:
		return result

	_accepted_command_ids[command.command_id] = true
	if _requires_card(command.command_type):
		var consumed := _consume_card_from_hand(command.actor_player_id, command.card_id)
		if not consumed:
			# Defensive guard in case hand validation diverges from core.
			return SimulationResult.rejected_result(&"card_not_in_hand", "Card is not in player's hand", state_hash_before)
	var result_events: Array = result.events.duplicate(true)

	var post_snapshot: Dictionary = _core.get_state_snapshot()
	var post_active: StringName = _dict_get(post_snapshot, "active_player_id", &"")
	if pre_active != post_active and not _match_complete:
		var draw_result := _draw_cards_to_hand(post_active, 1)
		if not draw_result:
			var post_active_deck: Array[StringName] = _dict_get(_player_decks, post_active, [])
			if post_active_deck.is_empty():
				_complete_by_deck_empty(post_active)
				# Keep accepted command event + explicit terminal event.
				result_events.append("match_complete:deck_empty_loss:%s" % post_active)
				result.events = result_events
				_append_action_log_entry(state_hash_before, command, result)
				return _build_local_result(result.state_hash, result_events)

	if not pre_complete:
		_sync_match_completion_from_core()
	if _match_complete:
		if _match_end_reason != &"":
			result_events.append("match_complete:%s:%s" % [_winner_player_id, _loser_player_id])
		result.events = result_events
	else:
		result.events = result_events

	_append_action_log_entry(state_hash_before, command, result)
	
	return _build_local_result(result.state_hash, result.events)


## Returns deep copy of tracked deck and hand state.
func get_match_snapshot() -> Dictionary:
	var snapshot: Dictionary = _core.get_state_snapshot() if _core != null else {}
	snapshot["player_hands"] = _snapshot_player_cards(_player_hands)
	snapshot["player_decks_remaining"] = _snapshot_player_cards(_player_decks)
	snapshot["match_complete"] = _match_complete
	snapshot["match_end_reason"] = _match_end_reason
	snapshot["match_winner_player_id"] = _winner_player_id
	snapshot["match_loser_player_id"] = _loser_player_id
	snapshot["match_action_log_id"] = str(_action_log_id)
	return snapshot


func get_action_log() -> Dictionary:
	if _action_log.is_empty():
		return {}
	return _action_log.duplicate(true)


func get_player_hand(player_id: StringName) -> Array[StringName]:
	var hand: Array[StringName] = _dict_get(_player_hands, player_id, [])
	return hand.duplicate(true)


func get_player_deck_size(player_id: StringName) -> int:
	var deck: Array[StringName] = _dict_get(_player_decks, player_id, [])
	return deck.size()


func get_player_hand_size(player_id: StringName) -> int:
	return get_player_hand(player_id).size()


func get_active_player_id() -> StringName:
	if _core == null:
		return &""
	var snapshot: Dictionary = _core.get_state_snapshot()
	return _dict_get(snapshot, "active_player_id", &"")


func get_current_state_hash() -> String:
	if _core == null:
		return ""
	return _core.get_state_hash()


func get_match_result() -> Dictionary:
	if _action_log.is_empty():
		return {}
	var event_count := 0
	for entry: Dictionary in _action_log_entries:
		var entry_events: Array = _dict_get(entry, "events", [])
		event_count += entry_events.size()
	return {
		"match_id": str(_match_id),
		"winner_player_id": str(_winner_player_id),
		"loser_player_id": str(_loser_player_id),
		"end_reason": str(_match_end_reason),
		"final_state_hash": get_current_state_hash(),
		"action_log_id": str(_action_log_id),
		"command_count": _action_log_entries.size(),
		"event_count": event_count,
		"replay_verified": false,
		"match_complete": _match_complete,
	}


func complete_by_deck_empty(loser_player_id: StringName) -> void:
	_complete_by_deck_empty(loser_player_id)


## Manually ends a match; used by tests and debug flows.
func force_complete_match(winner_player_id: StringName, loser_player_id: StringName, end_reason: StringName) -> void:
	_match_complete = true
	_match_end_reason = end_reason
	_winner_player_id = winner_player_id
	_loser_player_id = loser_player_id
	if _action_log.is_empty():
		return
	_action_log["match_complete"] = true
	_action_log["status"] = "finalized"


func _build_setup(request) -> MatchSetup:
	var setup := MatchSetup.new()
	setup.rule_set_version = request.rule_set_version
	setup.card_data_hash = request.card_data_hash
	setup.player_ids = request.player_ids.duplicate()
	setup.initial_seed = request.initial_seed
	setup.format_id = request.format_id
	setup.set("player_deck_loadouts", [])
	for loadout in request.player_loadouts:
		var flow_loadout := PlayerDeckLoadout.new()
		flow_loadout.player_id = loadout.player_id
		flow_loadout.deck_id = loadout.deck_id
		flow_loadout.deck_fingerprint = loadout.deck_fingerprint
		flow_loadout.declared_archetype_tags = loadout.declared_archetype_tags.duplicate()
		flow_loadout.ordered_card_ids = loadout.ordered_card_ids.duplicate()
		var setup_loadouts: Array = setup.get("player_deck_loadouts")
		setup_loadouts.append(flow_loadout)
		setup.set("player_deck_loadouts", setup_loadouts)
	return setup


func _validate_request(request, card_database) -> SimulationResult:
	if request.player_ids.size() != MatchSetup.LOCAL_MATCH_PLAYER_COUNT:
		return SimulationResult.rejected_result(&"invalid_player_count", "Local match request requires exactly two players")
	if request.format_id == &"":
		return SimulationResult.rejected_result(&"invalid_format", "format_id cannot be empty")
	if request.card_data_hash != card_database.get_card_data_hash():
		return SimulationResult.rejected_result(&"card_hash_mismatch", "Local match request card_data_hash does not match CardDatabase")
	if request.player_loadouts.size() != request.player_ids.size():
		return SimulationResult.rejected_result(&"invalid_loadout_count", "Loadout count must match player count")
	var player_ids_seen: Dictionary = {}
	for player_id: StringName in request.player_ids:
		if player_id == &"":
			return SimulationResult.rejected_result(&"invalid_player_id", "player_id cannot be empty")
		if player_ids_seen.has(player_id):
			return SimulationResult.rejected_result(&"duplicate_player_id", "Player ids must be unique")
		player_ids_seen[player_id] = true

	var loadout_by_player: Dictionary = {}
	for loadout in request.player_loadouts:
		if loadout == null:
			return SimulationResult.rejected_result(&"invalid_loadout", "loadout cannot be null")
		if loadout.player_id == &"":
			return SimulationResult.rejected_result(&"invalid_loadout", "loadout.player_id cannot be empty")
		if not player_ids_seen.has(loadout.player_id):
			return SimulationResult.rejected_result(&"invalid_loadout", "loadout has unknown player_id")
		if loadout_by_player.has(loadout.player_id):
			return SimulationResult.rejected_result(&"invalid_loadout", "Each player must have one loadout")
		if loadout.ordered_card_ids.size() < STARTING_HAND_SIZE_MVP:
			return SimulationResult.rejected_result(&"invalid_loadout", "Loadout deck must contain at least starting hand cards")
		if loadout.deck_id == &"":
			return SimulationResult.rejected_result(&"invalid_loadout", "loadout.deck_id cannot be empty")
		loadout_by_player[loadout.player_id] = true
		for card_id: StringName in loadout.ordered_card_ids:
			if card_database.get_card_definition(card_id) == null:
				return SimulationResult.rejected_result(&"invalid_card_in_loadout", "Unknown card_id %s in loadout for %s" % [card_id, loadout.player_id])
	var state_hash: String = _card_database.get_card_data_hash() if _card_database != null else ""
	return SimulationResult.accepted_result(state_hash)


func _draw_cards_to_hand(player_id: StringName, count: int) -> bool:
	if count <= 0:
		return true
	for i in count:
		if not _draw_one_card_to_hand(player_id):
			return false
	return true


func _draw_one_card_to_hand(player_id: StringName) -> bool:
	if not _player_decks.has(player_id) or not _player_hands.has(player_id):
		return false
	var hand: Array[StringName] = _player_hands[player_id]
	if hand.size() >= MAX_HAND_SIZE_MVP:
		return false
	var deck: Array[StringName] = _player_decks[player_id]
	if deck.is_empty():
		return false
	var card_id: StringName = deck.pop_front()
	_player_decks[player_id] = deck
	hand.append(card_id)
	_player_hands[player_id] = hand
	return true


func _player_has_card_in_hand(player_id: StringName, card_id: StringName) -> bool:
	if player_id == &"" or card_id == &"":
		return false
	var hand: Array[StringName] = _dict_get(_player_hands, player_id, [])
	return hand.has(card_id)


func _consume_card_from_hand(player_id: StringName, card_id: StringName) -> bool:
	var hand: Array[StringName] = _dict_get(_player_hands, player_id, [])
	var index: int = hand.find(card_id)
	if index < 0:
		return false
	hand.remove_at(index)
	_player_hands[player_id] = hand
	return true


func _append_action_log_entry(state_hash_before: String, command: ActionCommand, result: SimulationResult) -> void:
	var entry_index: int = _action_log_entries.size()
	var entry := {
		"entry_index": entry_index,
		"command_id": str(command.command_id),
		"actor_player_id": str(command.actor_player_id),
		"actor_sequence_id": command.sequence_id,
		"command_type": str(command.command_type),
		"command_payload": command.to_canonical_data().duplicate(true),
		"state_hash_before": state_hash_before,
		"accepted": result.accepted,
		"events": result.events.duplicate(true),
		"state_hash_after": result.state_hash,
		}
	_action_log_entries.append(entry)
	_action_log["entries"] = _action_log_entries
	_action_log["event_count"] = _compute_event_count()


func _dict_get(container: Dictionary, key: StringName, fallback: Variant):
	if container.has(key):
		return container[key]
	return fallback


func _compute_event_count() -> int:
	var count := 0
	for entry: Dictionary in _action_log_entries:
		var events: Array = _dict_get(entry, "events", [])
		count += events.size()
	return count


func _sync_match_completion_from_core() -> void:
	if _core == null:
		return
	var snapshot: Dictionary = _core.get_state_snapshot()
	_match_complete = _dict_get(snapshot, "complete", false)
	_match_end_reason = _dict_get(snapshot, "end_reason", &"")
	_winner_player_id = _dict_get(snapshot, "winner_player_id", &"")
	_loser_player_id = _dict_get(snapshot, "loser_player_id", &"")
	if _match_complete and _action_log != null and not _action_log.is_empty():
		_action_log["match_complete"] = true
		_action_log["status"] = "finalized"
		_action_log["match_end_reason"] = str(_match_end_reason)
		_action_log["winner_player_id"] = str(_winner_player_id)
		_action_log["loser_player_id"] = str(_loser_player_id)
		_action_log["final_state_hash"] = get_current_state_hash()


func _complete_by_deck_empty(loser_player_id: StringName) -> void:
	if _match_complete:
		return
	var winner := _opponent_player_id(loser_player_id)
	if winner == &"":
		return
	_match_complete = true
	_match_end_reason = END_REASON_DECK_EMPTY
	_winner_player_id = winner
	_loser_player_id = loser_player_id
	if _action_log != null and not _action_log.is_empty():
		_action_log["match_complete"] = true
		_action_log["status"] = "finalized"
		_action_log["match_end_reason"] = str(_match_end_reason)
		_action_log["winner_player_id"] = str(_winner_player_id)
		_action_log["loser_player_id"] = str(_loser_player_id)
		_action_log["final_state_hash"] = get_current_state_hash()


func _build_local_result(state_hash: String, result_events: Array = []) -> SimulationResult:
	if _match_complete and result_events.is_empty():
		var events: Array = ["match_complete:%s" % _match_end_reason]
		return SimulationResult.accepted_result(state_hash, events)
	if not _match_complete:
		return SimulationResult.accepted_result(state_hash, result_events)
	var combined_events: Array = result_events.duplicate(true)
	if _match_end_reason != &"":
		combined_events.append("match_complete:%s" % _match_end_reason)
	return SimulationResult.accepted_result(state_hash, combined_events)


func _requires_card(command_type: StringName) -> bool:
	return command_type == DeterministicSimulationCore.COMMAND_PLAY_UNIT or command_type == DeterministicSimulationCore.COMMAND_PLAY_SPELL or command_type == DeterministicSimulationCore.COMMAND_PLAY_RESPONSE


func _snapshot_player_cards(source: Dictionary) -> Dictionary:
	var result := {}
	for player_id: StringName in _player_ids:
		var cards: Array[StringName] = _dict_get(source, player_id, [])
		result[str(player_id)] = cards.duplicate(true)
	return result


func _opponent_player_id(player_id: StringName) -> StringName:
	for candidate: StringName in _player_ids:
		if candidate != player_id:
			return candidate
	return &""


func _reset_runtime_state() -> void:
	_core = null
	_setup = null
	_card_database = null
	_match_id = &""
	_match_complete = false
	_match_end_reason = &""
	_winner_player_id = &""
	_loser_player_id = &""
	_player_decks.clear()
	_player_hands.clear()
	_player_ids.clear()
	_accepted_command_ids.clear()
	_action_log_entries.clear()
	_action_log = {}
	_action_log_id = &""
