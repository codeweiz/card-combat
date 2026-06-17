extends SceneTree

## Headless smoke check for the first deterministic simulation skeleton.
## Run when Godot is installed:
## /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/smoke/smoke_deterministic_core.gd


func _init() -> void:
	var exit_code := _run()
	quit(exit_code)


func _run() -> int:
	var card_database := _build_card_database()
	var report := card_database.validate()
	if not report.is_valid():
		push_error("Card database invalid: %s" % "; ".join(report.errors))
		return 1

	var setup := MatchSetup.new()
	setup.card_data_hash = card_database.get_card_data_hash()
	setup.player_ids = [&"player_a", &"player_b"]
	setup.initial_seed = 12345

	var first_hash := _run_one_sequence(setup, card_database)
	var second_hash := _run_one_sequence(setup, card_database)
	if first_hash == "" or second_hash == "":
		return 1
	if first_hash != second_hash:
		push_error("Determinism smoke failed: %s != %s" % [first_hash, second_hash])
		return 1

	print("deterministic simulation smoke ok: %s" % first_hash)
	return 0


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
	vanguard.status = CardDefinition.STATUS_PROTOTYPE
	vanguard.tags = [&"unit", &"prototype"]
	database.add_definition(vanguard)

	var counter := CardDefinition.new()
	counter.card_id = &"counter_sigil"
	counter.name_key = &"card.counter_sigil.name"
	counter.rules_text_key = &"card.counter_sigil.rules"
	counter.card_type = CardDefinition.TYPE_RESPONSE
	counter.speed = CardDefinition.SPEED_RESPONSE
	counter.base_cost = 1
	counter.targeting_profile_id = &"pending_original_action"
	counter.status = CardDefinition.STATUS_PROTOTYPE
	counter.tags = [&"response", &"counter", &"prototype"]
	var cancel_params := CancelOriginalEffectParams.new()
	cancel_params.allowed_command_types = [&"play_unit"]
	var cancel_effect := EffectRef.new()
	cancel_effect.effect_id = CardEffectResolver.EFFECT_CANCEL_ORIGINAL
	cancel_effect.params = cancel_params
	counter.effect_refs = [cancel_effect]
	database.add_definition(counter)

	return database


func _run_one_sequence(setup: MatchSetup, card_database: CardDatabase) -> String:
	var core := DeterministicSimulationCore.new()
	var init_result := core.initialize_match(setup, card_database)
	if not init_result.accepted:
		push_error("Initialize failed: %s" % init_result.message)
		return ""

	var player_a_seq: int = 0
	var player_b_seq: int = 0

	# 1) A plays a unit and B passes the response window.
	var play_unit := _build_play_unit_command(
		&"player_a",
		player_a_seq,
		&"vanguard",
		BoardState.LANE_CENTER,
		core.get_state_hash(),
		&"p1_play_01"
	)
	var play_result := core.submit_command(play_unit)
	if not play_result.accepted:
		push_error("p1 initial play_unit failed: %s" % play_result.message)
		return ""
	player_a_seq += 1

	if not _response_window_open(core):
		push_error("play_unit should open a response window before resolving")
		return ""

	var noop_blocked := ActionCommand.new()
	noop_blocked.command_id = &"p1_noop_blocked"
	noop_blocked.actor_player_id = &"player_a"
	noop_blocked.command_type = &"noop"
	noop_blocked.sequence_id = player_a_seq
	noop_blocked.expected_state_hash = core.get_state_hash()
	var noop_blocked_result := core.submit_command(noop_blocked)
	if noop_blocked_result.accepted:
		push_error("Active player should not act while defender has response priority")
		return ""

	var pass_response := _build_pass_response_command(
		&"player_b",
		player_b_seq,
		core.get_state_hash()
	)
	var pass_result := core.submit_command(pass_response)
	if not pass_result.accepted:
		push_error("pass_response failed: %s" % pass_result.message)
		return ""
	player_b_seq += 1
	if _response_window_open(core):
		push_error("pass_response should close the response window")
		return ""
	if not _player_has_unit_in_lane(core, BoardState.LANE_CENTER, &"player_a"):
		push_error("Original play_unit should resolve after pass_response")
		return ""
	# Keep the accepted state hash as reference for deterministic replay checks.

	# 2) Main phase has no attack actions yet.
	if not _query_legal_actions_for_type(core, &"player_a", &"attack_unit").is_empty():
		push_error("No attack actions should be available in main phase")
		return ""

	# 1st end-turn enters attack phase; summon-lock should prevent an attack.
	var enter_attack := _build_end_turn_command(
		&"player_a",
		player_a_seq,
		core.get_state_hash(),
		&"p1_end_to_attack"
	)
	var enter_attack_result := core.submit_command(enter_attack)
	if not enter_attack_result.accepted:
		push_error("end_turn to attack failed: %s" % enter_attack_result.message)
		return ""
	player_a_seq += 1
	if _get_turn_phase(core) != _attack_phase_id():
		push_error("Expected A to be in attack phase")
		return ""
	if not _query_legal_actions_for_type(core, &"player_a", &"attack_unit").is_empty():
		push_error("Summon-locked unit should not be attack-ready in same turn")
		return ""

	var illegal_play := _build_play_unit_command(
		&"player_a",
		player_a_seq,
		&"vanguard",
		BoardState.LANE_LEFT,
		core.get_state_hash(),
		&"p1_illegal_play_attack_phase"
	)
	var illegal_play_result := core.submit_command(illegal_play)
	if illegal_play_result.accepted:
		push_error("play_unit should be invalid in attack phase")
		return ""
	var illegal_end_b := _build_end_turn_command(
		&"player_b",
		player_b_seq,
		core.get_state_hash(),
		&"p1_illegal_end_b"
	)
	var illegal_end_b_result := core.submit_command(illegal_end_b)
	if illegal_end_b_result.accepted:
		push_error("Non-active player should not be able to end turn")
		return ""

	# 2) Finish A's turn and let B take a quick turn, so A's unit can become ready.
	var finish_attack := _build_end_turn_command(
		&"player_a",
		player_a_seq,
		core.get_state_hash(),
		&"p1_end_attack"
	)
	var finish_attack_result := core.submit_command(finish_attack)
	if not finish_attack_result.accepted:
		push_error("A failed to end attack phase: %s" % finish_attack_result.message)
		return ""
	player_a_seq += 1
	if _get_active_player(core) != &"player_b":
		push_error("Expected player_b to become active")
		return ""

	var b_to_attack := _build_end_turn_command(
		&"player_b",
		player_b_seq,
		core.get_state_hash(),
		&"p1_b_end_to_attack"
	)
	player_b_seq += 1
	var b_to_attack_result := core.submit_command(b_to_attack)
	if not b_to_attack_result.accepted:
		push_error("B failed to end main phase: %s" % b_to_attack_result.message)
		return ""
	var b_to_next := _build_end_turn_command(
		&"player_b",
		player_b_seq,
		core.get_state_hash(),
		&"p1_b_end_attack"
	)
	player_b_seq += 1
	var b_to_next_result := core.submit_command(b_to_next)
	if not b_to_next_result.accepted:
		push_error("B failed to end attack phase: %s" % b_to_next_result.message)
		return ""
	if _get_active_player(core) != &"player_a":
		push_error("Expected player_a to become active again")
		return ""

	var a_end_to_attack_again := _build_end_turn_command(
		&"player_a",
		player_a_seq,
		core.get_state_hash(),
		&"p1_a_end_to_attack_again"
	)
	var a_end_to_attack_again_result := core.submit_command(a_end_to_attack_again)
	if not a_end_to_attack_again_result.accepted:
		push_error("A could not enter attack phase on second turn: %s" % a_end_to_attack_again_result.message)
		return ""
	player_a_seq += 1
	if _get_turn_phase(core) != _attack_phase_id():
		push_error("Expected attack phase on second round")
		return ""

	# 3) Attack the opponent face.
	var ready_attacks := _query_legal_actions_for_type(core, &"player_a", &"attack_unit")
	if ready_attacks.is_empty():
		push_error("Expected at least one ready attacker on second round")
		return ""
	var attack := ready_attacks[0]
	var pre_attack_life := _get_player_life(core, &"player_b")
	attack.command_id = &"p1_attack_center"
	attack.expected_state_hash = core.get_state_hash()
	attack.sequence_id = player_a_seq
	attack.actor_player_id = &"player_a"
	player_a_seq += 1
	var attack_result := core.submit_command(attack)
	if not attack_result.accepted:
		push_error("Attack command failed: %s" % attack_result.message)
		return ""
	if not _response_window_open(core):
		push_error("Attack should open response window")
		return ""
	var attack_pass := _build_pass_response_command(
		&"player_b",
		player_b_seq,
		core.get_state_hash()
	)
	player_b_seq += 1
	var attack_pass_result := core.submit_command(attack_pass)
	if not attack_pass_result.accepted:
		push_error("Attack pass response failed: %s" % attack_pass_result.message)
		return ""
	if _response_window_open(core):
		push_error("Attack should have resolved after pass response")
		return ""
	var post_attack_life := _get_player_life(core, &"player_b")
	if post_attack_life != pre_attack_life - 2:
		push_error("Expected player_b life to drop by 2, was %d from %d" % [post_attack_life, pre_attack_life])
		return ""
	if not _query_legal_actions_for_type(core, &"player_a", &"attack_unit").is_empty():
		push_error("Attack action should be consumed for this round")
		return ""

	# 4) Rejected action should not mutate state.
	var before_reject := core.get_state_hash()
	var duplicate := _build_play_unit_command(
		&"player_a",
		player_a_seq,
		&"vanguard",
		BoardState.LANE_CENTER,
		core.get_state_hash(),
		&"p1_illegal_duplicate"
	)
	var duplicate_result := core.submit_command(duplicate)
	if duplicate_result.accepted:
		push_error("Duplicate lane placement should be rejected")
		return ""
	if core.get_state_hash() != before_reject:
		push_error("Rejected play_unit mutated match state")
		return ""

	return core.get_state_hash()


func _response_window_open(core: DeterministicSimulationCore) -> bool:
	var snapshot: Dictionary = core.get_state_snapshot()
	var response_window: Dictionary = snapshot.get("response_window", {})
	return response_window.get("window_state", &"") == ResponseWindowState.STATE_OPEN


func _build_play_unit_command(actor_id: StringName, sequence: int, card_id: StringName, lane_id: StringName, state_hash: String, command_id: StringName) -> ActionCommand:
	var command := ActionCommand.new()
	command.command_id = command_id
	command.actor_player_id = actor_id
	command.command_type = &"play_unit"
	command.sequence_id = sequence
	command.expected_state_hash = state_hash
	command.card_id = card_id
	command.target_lane = lane_id
	return command


func _build_end_turn_command(actor_id: StringName, sequence: int, state_hash: String, command_id: StringName) -> ActionCommand:
	var command := ActionCommand.new()
	command.command_id = command_id
	command.actor_player_id = actor_id
	command.command_type = &"end_turn"
	command.sequence_id = sequence
	command.expected_state_hash = state_hash
	return command


func _build_pass_response_command(actor_id: StringName, sequence: int, state_hash: String) -> ActionCommand:
	var command := ActionCommand.new()
	command.command_id = &"pass_%s_%s" % [actor_id, sequence]
	command.actor_player_id = actor_id
	command.command_type = &"pass_response"
	command.sequence_id = sequence
	command.expected_state_hash = state_hash
	return command


func _query_legal_actions_for_type(core: DeterministicSimulationCore, actor: StringName, action_type: StringName) -> Array[ActionCommand]:
	var actions: Array[ActionCommand] = []
	for command: ActionCommand in core.query_legal_actions(actor):
		if command.command_type == action_type:
			actions.append(command)
	return actions


func _get_turn_phase(core: DeterministicSimulationCore) -> StringName:
	var snapshot: Dictionary = core.get_state_snapshot()
	return snapshot.get("turn_phase", &"")


func _get_active_player(core: DeterministicSimulationCore) -> StringName:
	var snapshot: Dictionary = core.get_state_snapshot()
	return snapshot.get("active_player_id", &"")


func _get_player_life(core: DeterministicSimulationCore, player_id: StringName) -> int:
	var snapshot: Dictionary = core.get_state_snapshot()
	var board: Dictionary = snapshot.get("board", {})
	var player_life_by_id: Dictionary = board.get("player_life_by_id", {})
	return int(player_life_by_id.get(str(player_id), 0))


func _attack_phase_id() -> StringName:
	return &"attack"


func _player_has_unit_in_lane(core: DeterministicSimulationCore, lane_id: StringName, player_id: StringName) -> bool:
	var snapshot: Dictionary = core.get_state_snapshot()
	var board: Dictionary = snapshot.get("board", {})
	var lanes: Array = board.get("lanes", [])
	for lane_variant: Variant in lanes:
		var lane: Dictionary = lane_variant
		if lane.get("lane_id", &"") == lane_id:
			var units_by_player: Dictionary = lane.get("units_by_player", {})
			return units_by_player.get(str(player_id), null) != null
	return false
