extends SceneTree

const CardDatabase = preload("res://src/core/card/card_database.gd")
const CardDefinition = preload("res://src/core/card/card_definition.gd")
const CardValidationReport = preload("res://src/core/card/card_validation_report.gd")
const DeterministicSimulationCore = preload("res://src/core/simulation/deterministic_simulation_core.gd")
const ActionCommand = preload("res://src/core/simulation/action_command.gd")
const LocalMatchFlow = preload("res://src/core/match_flow/local_match_flow.gd")
const LocalMatchRequest = preload("res://src/core/match_flow/local_match_request.gd")
const PlayerDeckLoadout = preload("res://src/core/match_flow/player_deck_loadout.gd")
const SimulationResult = preload("res://src/core/simulation/simulation_result.gd")

## Headless smoke for local match orchestration.
## Run when Godot is available:
## /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/smoke/smoke_local_match_flow.gd

const PLAYER_A: StringName = &"player_a"
const PLAYER_B: StringName = &"player_b"


func _init() -> void:
	var exit_code := _run()
	quit(exit_code)


func _run() -> int:
	var card_database: CardDatabase = _build_card_database()
	var report: CardValidationReport = card_database.validate()
	if not report.is_valid():
		push_error("Card database invalid: %s" % "; ".join(report.errors))
		return 1

	var request: LocalMatchRequest = _build_match_request(card_database)
	var flow := LocalMatchFlow.new()
	var start_result: SimulationResult = flow.start_match(request, card_database)
	if not start_result.accepted:
		push_error("start_match failed: %s" % start_result.message)
		return 1

	var match_result: Dictionary = flow.get_match_result()
	var action_log_id: String = _dict_get(match_result, "action_log_id", "")
	if action_log_id == "":
		push_error("Expected action log id after start_match")
		return 1
	if flow.get_player_hand_size(PLAYER_A) != LocalMatchFlow.STARTING_HAND_SIZE_MVP:
		push_error("Expected player_a starting hand size %d, got %d" % [LocalMatchFlow.STARTING_HAND_SIZE_MVP, flow.get_player_hand_size(PLAYER_A)])
		return 1
	if flow.get_player_hand_size(PLAYER_B) != LocalMatchFlow.STARTING_HAND_SIZE_MVP:
		push_error("Expected player_b starting hand size %d, got %d" % [LocalMatchFlow.STARTING_HAND_SIZE_MVP, flow.get_player_hand_size(PLAYER_B)])
		return 1
	if flow.get_player_deck_size(PLAYER_A) != 16:
		push_error("Expected player_a deck size 16 after opening draw, got %d" % flow.get_player_deck_size(PLAYER_A))
		return 1
	if flow.get_player_deck_size(PLAYER_B) != 16:
		push_error("Expected player_b deck size 16 after opening draw, got %d" % flow.get_player_deck_size(PLAYER_B))
		return 1

	var player_a_hand_before: Array[StringName] = flow.get_player_hand(PLAYER_A)
	var play_unit: ActionCommand = _find_command(flow.query_legal_actions(PLAYER_A), DeterministicSimulationCore.COMMAND_PLAY_UNIT)
	if play_unit == null:
		push_error("No legal play_unit command found for player_a")
		return 1
	if not player_a_hand_before.has(play_unit.card_id):
		push_error("Flow legal actions are not filtered to hand (play_unit")
		return 1
	play_unit.command_id = &"smoke_a_play_unit"
	var play_result: SimulationResult = flow.submit_command(play_unit)
	if not play_result.accepted:
		push_error("A play_unit failed: %s" % play_result.message)
		return 1

	var player_a_hand_after_play: Array[StringName] = flow.get_player_hand(PLAYER_A)
	if player_a_hand_after_play.size() != LocalMatchFlow.STARTING_HAND_SIZE_MVP - 1:
		push_error("Expected player_a hand to shrink to %d after spending unit card" % (LocalMatchFlow.STARTING_HAND_SIZE_MVP - 1))
		return 1

	var pass_response: ActionCommand = _find_command(flow.query_legal_actions(PLAYER_B), DeterministicSimulationCore.COMMAND_PASS_RESPONSE)
	if pass_response == null:
		push_error("No legal pass_response command found for player_b")
		return 1
	pass_response.command_id = &"smoke_b_pass"
	var pass_result: SimulationResult = flow.submit_command(pass_response)
	if not pass_result.accepted:
		push_error("B pass_response failed: %s" % pass_result.message)
		return 1

	# Enter attack phase for player_a.
	var a_end_main: ActionCommand = _find_command(flow.query_legal_actions(PLAYER_A), DeterministicSimulationCore.COMMAND_END_TURN)
	if a_end_main == null:
		push_error("No legal end_turn command for player_a main phase")
		return 1
	a_end_main.command_id = &"smoke_a_end_main"
	var a_end_main_result: SimulationResult = flow.submit_command(a_end_main)
	if not a_end_main_result.accepted:
		push_error("A end_turn (main->attack) failed: %s" % a_end_main_result.message)
		return 1

	# A is now in attack phase; turn has not changed yet.
	if flow.get_player_hand_size(PLAYER_B) != LocalMatchFlow.STARTING_HAND_SIZE_MVP:
		push_error("Expected player_b hand size %d before B turn starts" % LocalMatchFlow.STARTING_HAND_SIZE_MVP)
		return 1

	# A ends their attack phase so B receives the turn.
	var a_end_attack: ActionCommand = _find_command(flow.query_legal_actions(PLAYER_A), DeterministicSimulationCore.COMMAND_END_TURN)
	if a_end_attack == null:
		push_error("No legal end_turn command for player_a attack phase")
		return 1
	a_end_attack.command_id = &"smoke_a_end_attack"
	if not flow.submit_command(a_end_attack).accepted:
		push_error("A end_turn (attack->next) failed")
		return 1

	if flow.get_player_hand_size(PLAYER_B) != LocalMatchFlow.STARTING_HAND_SIZE_MVP + 1:
		push_error("Expected player_b hand size %d after entering B turn" % (LocalMatchFlow.STARTING_HAND_SIZE_MVP + 1))
		return 1

	# B moves through main and attack phases.
	var b_end_to_attack: ActionCommand = _find_command(flow.query_legal_actions(PLAYER_B), DeterministicSimulationCore.COMMAND_END_TURN)
	if b_end_to_attack == null:
		push_error("No legal end_turn command for player_b main phase")
		return 1
	b_end_to_attack.command_id = &"smoke_b_end_main"
	if not flow.submit_command(b_end_to_attack).accepted:
		push_error("B end_turn (main->attack) failed")
		return 1

	var b_end_to_next: ActionCommand = _find_command(flow.query_legal_actions(PLAYER_B), DeterministicSimulationCore.COMMAND_END_TURN)
	if b_end_to_next == null:
		push_error("No legal end_turn command for player_b attack phase")
		return 1
	b_end_to_next.command_id = &"smoke_b_end_attack"
	if not flow.submit_command(b_end_to_next).accepted:
		push_error("B end_turn (attack->next) failed")
		return 1

	# player_a should receive one turn card when B turn passed back.
	if flow.get_player_hand_size(PLAYER_A) != LocalMatchFlow.STARTING_HAND_SIZE_MVP:
		# Started with 3 after play_unit +1 after B completes turn.
		push_error("Expected player_a hand to return to %d after turn rollover" % LocalMatchFlow.STARTING_HAND_SIZE_MVP)
		return 1

	# Enter attack phase for player_a again so a unit can attack.
	var a_enter_attack: ActionCommand = _find_command(flow.query_legal_actions(PLAYER_A), DeterministicSimulationCore.COMMAND_END_TURN)
	if a_enter_attack == null:
		push_error("No legal end_turn command for player_a after B returns")
		return 1
	a_enter_attack.command_id = &"smoke_a_end_main_again"
	if not flow.submit_command(a_enter_attack).accepted:
		push_error("A end_turn to second attack phase failed")
		return 1

	var a_attack: ActionCommand = _find_command(flow.query_legal_actions(PLAYER_A), DeterministicSimulationCore.COMMAND_ATTACK_UNIT)
	if a_attack == null:
		push_error("No legal attack_unit command found for player_a")
		return 1
	var before_life: int = _player_life(flow, PLAYER_B)
	a_attack.command_id = &"smoke_a_attack"
	if not flow.submit_command(a_attack).accepted:
		push_error("A attack failed")
		return 1

	var b_pass_after_attack: ActionCommand = _find_command(flow.query_legal_actions(PLAYER_B), DeterministicSimulationCore.COMMAND_PASS_RESPONSE)
	if b_pass_after_attack == null:
		push_error("No legal pass_response for defender after attack")
		return 1
	b_pass_after_attack.command_id = &"smoke_b_defend_pass"
	if not flow.submit_command(b_pass_after_attack).accepted:
		push_error("B pass_response after attack failed")
		return 1

	var after_life: int = _player_life(flow, PLAYER_B)
	if after_life != before_life - 2:
		push_error("Expected player_b life to decrease by 2, got %d -> %d" % [before_life, after_life])
		return 1

	var surrender_request: LocalMatchRequest = _build_surrender_request(card_database)
	var surrender_flow := LocalMatchFlow.new()
	var surrender_start: SimulationResult = surrender_flow.start_match(surrender_request, card_database)
	if not surrender_start.accepted:
		push_error("start_match for surrender smoke failed")
		return 1
	var surrender_command: ActionCommand = _find_command(surrender_flow.query_legal_actions(PLAYER_A), DeterministicSimulationCore.COMMAND_SURRENDER)
	if surrender_command == null:
		push_error("No legal surrender command found")
		return 1
	surrender_command.command_id = &"smoke_surrender"
	var surrender_result: SimulationResult = surrender_flow.submit_command(surrender_command)
	if not surrender_result.accepted:
		push_error("Surrender command failed: %s" % surrender_result.message)
		return 1
	var surrender_match_result: Dictionary = surrender_flow.get_match_result()
	if _dict_get(surrender_match_result, "end_reason", "") != str(DeterministicSimulationCore.END_REASON_SURRENDER):
		push_error("Expected surrender end reason, got %s" % _dict_get(surrender_match_result, "end_reason", ""))
		return 1

	print("local_match_flow smoke ok")
	return 0


func _player_life(flow: LocalMatchFlow, player_id: StringName) -> int:
	var snapshot: Dictionary = flow.get_match_snapshot()
	var board: Dictionary = _dict_get(snapshot, "board", {})
	var life_data: Dictionary = _dict_get(board, "player_life_by_id", {})
	return int(_dict_get(life_data, str(player_id), 0))


func _dict_get(container: Dictionary, key: Variant, fallback: Variant):
	if container.has(key):
		return container[key]
	return fallback


func _build_card_database() -> CardDatabase:
	var database := CardDatabase.new()

	var vanguard := CardDefinition.new()
	vanguard.card_id = &"vanguard"
	vanguard.name_key = &"card.vanguard.name"
	vanguard.rules_text_key = &"card.vanguard.rules"
	vanguard.card_type = CardDefinition.TYPE_UNIT
	vanguard.speed = CardDefinition.SPEED_MAIN
	vanguard.base_cost = 1
	vanguard.unit_attack = 2
	vanguard.unit_health = 2
	vanguard.targeting_profile_id = &"own_empty_lane"
	vanguard.tags = [&"unit", &"prototype"]
	vanguard.status = CardDefinition.STATUS_PROTOTYPE
	database.add_definition(vanguard)

	var sentinel := CardDefinition.new()
	sentinel.card_id = &"sentinel"
	sentinel.name_key = &"card.sentinel.name"
	sentinel.rules_text_key = &"card.sentinel.rules"
	sentinel.card_type = CardDefinition.TYPE_UNIT
	sentinel.speed = CardDefinition.SPEED_MAIN
	sentinel.base_cost = 2
	sentinel.unit_attack = 1
	sentinel.unit_health = 1
	sentinel.targeting_profile_id = &"own_empty_lane"
	sentinel.tags = [&"unit", &"prototype"]
	sentinel.status = CardDefinition.STATUS_PROTOTYPE
	database.add_definition(sentinel)

	var counter_sigil := CardDefinition.new()
	counter_sigil.card_id = &"counter_sigil"
	counter_sigil.name_key = &"card.counter_sigil.name"
	counter_sigil.rules_text_key = &"card.counter_sigil.rules"
	counter_sigil.card_type = CardDefinition.TYPE_RESPONSE
	counter_sigil.speed = CardDefinition.SPEED_RESPONSE
	counter_sigil.base_cost = 1
	counter_sigil.targeting_profile_id = &"pending_original_action"
	counter_sigil.tags = [&"response", &"prototype"]
	counter_sigil.status = CardDefinition.STATUS_PROTOTYPE
	database.add_definition(counter_sigil)

	var fog := CardDefinition.new()
	fog.card_id = &"fog"
	fog.name_key = &"card.fog.name"
	fog.rules_text_key = &"card.fog.rules"
	fog.card_type = CardDefinition.TYPE_SPELL
	fog.speed = CardDefinition.SPEED_MAIN
	fog.base_cost = 1
	fog.targeting_profile_id = &"any"
	fog.tags = [&"spell", &"prototype"]
	fog.status = CardDefinition.STATUS_PROTOTYPE
	database.add_definition(fog)

	return database



func _build_match_request(card_database: CardDatabase) -> LocalMatchRequest:
	var request := LocalMatchRequest.new()
	request.match_id = &"smoke_local_match_flow"
	request.rule_set_version = 1
	request.format_id = LocalMatchRequest.DEFAULT_FORMAT
	request.initial_seed = 20260617
	request.player_ids = [PLAYER_A, PLAYER_B]
	request.card_data_hash = card_database.get_card_data_hash()
	request.player_loadouts = [
		_build_loadout(request.player_ids[0], &"sample_a", request.card_data_hash, &"vanguard"),
		_build_loadout(request.player_ids[1], &"sample_b", request.card_data_hash, &"vanguard"),
	]
	return request



func _build_surrender_request(card_database: CardDatabase) -> LocalMatchRequest:
	return _build_match_request(card_database)


func _build_loadout(player_id: StringName, deck_id: StringName, card_data_hash: String, card_id: StringName = &"vanguard") -> PlayerDeckLoadout:
	var loadout := PlayerDeckLoadout.new()
	loadout.player_id = player_id
	loadout.deck_id = deck_id
	loadout.deck_fingerprint = &"%s:%s" % [deck_id, card_data_hash]
	loadout.ordered_card_ids = []
	loadout.declared_archetype_tags = [&"smoke", &"aggressive"]
	for i in 20:
		loadout.ordered_card_ids.append(card_id)
	return loadout


func _find_command(actions: Array, command_type: StringName) -> ActionCommand:
	for action: ActionCommand in actions:
		if action.command_type == command_type:
			return action
	return null
